# SPI Transport Walkthrough

This document is the onboarding guide for the active FPGA-to-host transport.
Read it when you want to answer any of these questions:

- Where does the FFT window leave the FPGA?
- Why is the SPI backend transaction-based instead of free-running?
- Which state in the RTL actually decides that a window is ready?
- Why are BFPEXP words repeated before FFT bins?
- Which code sections matter when changing the transport?

## Code Map

The SPI export path is spread across a small set of files with clear roles:

- `rtl/core/aces.sv`
  Exposes the SPI transport ports on the main ACES core.
- `rtl/frontend/spi_fft_tx_adapter.sv`
  Owns buffering, transaction framing, word packing, and byte serialization.
- `rtl/common/fft_tx_bridge_fifo.sv`
  Reusable show-ahead FIFO used by the adapter to keep bin metadata aligned.
- `rtl/top/top_level_spi_fft_tx_diag.sv`
  Deterministic lab top-level for validating the transport in isolation.
- `rtl/top/top_level_test.sv`
  Full board top-level that connects the ACES pipeline to the same SPI pins.

## One Window From Start To Finish

The easiest way to understand the adapter is to follow a single FFT window.

### 1. `fft_dma_reader` emits bins

The FFT core eventually produces a burst of bins. Each accepted bin carries:

- `fft_real_i`
- `fft_imag_i`
- `fft_last_i`
- `bfpexp_i`

`fft_last_i` marks the final bin of one logical window.

### 2. The adapter stores bins in its internal FIFO

`spi_fft_tx_adapter` instantiates `fft_tx_bridge_fifo` internally. The FIFO is
there for one reason: FFT production is clocked by the FPGA, while SPI drain is
clocked by the host. Those rates are unrelated.

The FIFO stores one aligned tuple per entry:

```text
{ real, imag, last, bfpexp }
```

Keeping these four fields together prevents subtle framing bugs where the host
would see the wrong exponent paired with a bin.

### 3. `complete_windows_r` counts windows, not just entries

The adapter does not declare a window ready simply because the FIFO is non-empty.
Instead, it increments `complete_windows_r` only when a bin is both:

- accepted into the FIFO, and
- marked with `fft_last_i = 1`.

That distinction matters. The host should only start a transaction when a whole
window is buffered, not when the first few bins happen to have arrived.

### 4. `window_ready_o` tells the host when to begin

`window_ready_o` goes high when:

- `complete_windows_r != 0`, and
- no SPI transaction is currently active.

This makes `window_ready_o` a clean coarse-grain handshake:

- high: there is at least one full window buffered and available,
- low: either no complete window exists yet, or a transaction is already in
  progress.

### 5. The host pulls `CS_N` low to begin a transaction

The Raspberry Pi is the SPI master. The FPGA never starts a transfer on its own.
When `CS_N` falls:

- if a complete window is ready, the adapter loads the first BFPEXP pair,
- otherwise it loads an IDLE pair of zero words.

Returning IDLE instead of random data makes early polling safe and easy to debug.

## Transaction Format

One SPI transaction returns exactly one logical FFT window.

### Word format

Each logical 32-bit word is packed as:

```text
[ tag(2) | reserved zeros | signed payload ]
```

Current tags are:

- `0`: IDLE
- `1`: BFPEXP
- `2`: FFT

### Pair format

The host always consumes words in left/right pairs:

- BFPEXP pair: `{bfpexp, bfpexp}`
- FFT pair: `{real, imag}`

### Window format

The full transaction is:

```text
BFPEXP pair repeated BFPEXP_HOLD_FRAMES times
then
one FFT pair per bin in the window
```

The repeated BFPEXP is deliberate. The host-side tooling already expects that
framing, so the SPI backend keeps it.

## Byte And Bit Order On The Wire

This part often confuses new readers because there are two orderings involved.

### Byte order inside a 32-bit word

Bytes are emitted little-endian by word:

```text
byte 0 = word[7:0]
byte 1 = word[15:8]
byte 2 = word[23:16]
byte 3 = word[31:24]
```

The adapter sends the four bytes of the left word first and the four bytes of
the right word second.

### Bit order inside each byte

Within each byte, bits are shifted out MSB-first.

This matches the benches, which reconstruct each byte bit-by-bit and then
rebuild the original 32-bit word as `{byte3, byte2, byte1, byte0}`.

## Why SPI Inputs Are Synchronized

`spi_sclk_i` and `spi_cs_n_i` are external signals driven by the Raspberry Pi,
so they are asynchronous to the FPGA `clk` domain used by the adapter logic.

The adapter therefore:

- samples each input through a simple synchronizer,
- keeps a delayed copy,
- derives rise/fall events from the synchronized versions.

This is not fancy CDC machinery; it is the minimum safe structure needed to keep
the serializer state machine deterministic in the internal clock domain.

## Why MISO Changes On The Falling Edge

The module assumes SPI mode 0:

- CPOL = 0
- CPHA = 0

In that mode, the master samples data on the rising edge. The adapter therefore
updates the next output bit on the falling edge. That gives the line half a SPI
cycle to settle before the next sample point.

## Why `wait_fifo_refresh_r` Exists

This is one of the least obvious pieces of the adapter.

The FIFO is show-ahead: after a pop, the next head entry becomes visible without
an explicit read command. But that new head is not valid in the exact same cycle
that the pop is issued.

The adapter therefore does this after finishing an FFT pair:

1. assert `fifo_pop_r`,
2. wait one internal clock for the FIFO head to refresh,
3. load the next FFT pair from the new head.

That is the purpose of:

- `wait_next_fft_pair_r`
- `wait_fifo_refresh_r`

Without that delay, the adapter could accidentally reserialize stale data.

## Why The Last Bin Is Special

When the active FFT pair corresponds to the last bin of a window:

- the adapter pops it from the FIFO,
- decrements `complete_windows_r`,
- loads IDLE words,
- keeps driving IDLE until the host releases `CS_N`.

That behavior makes the end-of-window boundary explicit and prevents the next
window from leaking into the current transaction if the master clocks too far.

## Diagnostic Top-Level And Why It Matters

`top_level_spi_fft_tx_diag.sv` exists to validate the transport without the rest
of the signal-processing chain.

It drives the adapter with a deterministic source:

- constant real pattern,
- constant imaginary pattern,
- constant BFPEXP,
- a programmable window length.

That gives you a predictable transaction stream for:

- board wiring checks,
- scope or logic analyzer capture,
- host decoder validation,
- bring-up when the microphone/FFT path is not trusted yet.

## Verification Strategy

The transport is intentionally covered at several layers:

- `tb_spi_fft_tx_adapter`
  Unit-level contract for packing, BFPEXP hold behavior, byte order, and
  multi-window sequencing.
- `tb_fft_tx_spi_link`
  Integration of the reusable FIFO behavior with the adapter drain behavior.
- `tb_top_level_spi_fft_tx_diag`
  Board-facing proof that the deterministic top-level exposes the expected SPI
  stream on its pins.
- `tb_top_level_test`
  Full-path integration using the real ACES top-level signals.

If you are changing transport behavior, these are the first benches to revisit.

## Practical Reading Advice

If you open `rtl/frontend/spi_fft_tx_adapter.sv`, read it in this order:

1. the header block comment,
2. the helper functions `pack_word`, `pair_byte`, and `load_pair_words`,
3. the `window_ready_o` assignment,
4. the `spi_cs_fall_w` and `spi_cs_rise_w` branches,
5. the `PAIR_BFPEXP` and `PAIR_FFT` cases.

That path mirrors the actual transaction lifecycle and is much easier than
trying to understand the file top-to-bottom in one pass.
