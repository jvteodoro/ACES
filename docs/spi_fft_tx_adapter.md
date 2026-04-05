# SPI FFT TX Adapter

`spi_fft_tx_adapter` is the active transport boundary between the internal FFT
readout stream and the external Raspberry Pi host.

If you want one sentence that captures the module: it accepts bins in the FPGA
clock domain, waits until a full window is buffered, then serves that window as
a host-driven SPI transaction without changing the logical 32-bit word contract.

## File

- `rtl/frontend/spi_fft_tx_adapter.sv`

## Why This Module Exists

The FFT readout side and the SPI drain side have incompatible timing models:

- FFT bins arrive in bursts under FPGA control,
- SPI bytes leave only when the host toggles `SCLK` with `CS_N` asserted.

The adapter exists to bridge those worlds while keeping host software stable.

## Upstream And Downstream Contracts

### Upstream view

Inputs from the FFT path:

- `fft_valid_i`
- `fft_real_i`
- `fft_imag_i`
- `fft_last_i`
- `bfpexp_i`

The adapter behaves like a sink with backpressure:

- `fft_ready_o = 1` means a bin may be accepted this cycle,
- accepted bins are stored internally,
- a complete window is recognized only when an accepted bin carries
  `fft_last_i = 1`.

### Downstream view

Outputs to the host-facing transport:

- `spi_miso_o`
- `window_ready_o`
- `spi_active_o`

The host owns:

- `spi_sclk_i`
- `spi_cs_n_i`

The FPGA never starts a transfer by itself.

## Public Status Signals

### `window_ready_o`

High only when:

- at least one complete window is buffered, and
- no SPI transaction is already in progress.

This is the signal the host should use as "safe to start a read now".

### `spi_active_o`

High while `CS_N` is asserted and the adapter considers the transaction active.

### FIFO debug outputs

The module also exposes:

- `fifo_full_o`
- `fifo_empty_o`
- `overflow_o`
- `fifo_level_o`

These are primarily for observability and verification.

## Transport Contract

### Logical word

Each 32-bit word is packed as:

```text
[ tag(2) | reserved zeros | signed payload ]
```

Current tags:

- `0`: IDLE
- `1`: BFPEXP
- `2`: FFT

### Logical pair

The host consumes two 32-bit words at a time:

- BFPEXP pair:
  both words carry the same sign-extended exponent
- FFT pair:
  left word is real, right word is imaginary

### Full transaction

Each SPI transaction returns:

```text
BFPEXP pair repeated BFPEXP_HOLD_FRAMES times
then
one FFT pair per accepted FFT bin in the window
```

If the host starts a transaction before a full window is ready, the adapter
returns IDLE zeros instead of arbitrary data.

## Internal Structure

The module is easiest to read as four sub-blocks.

### 1. Word helpers

The helper functions:

- `extend_fft_sample`
- `extend_bfpexp`
- `pack_word`
- `pair_byte`
- `load_pair_words`

convert FIFO data into the exact host-visible format and control how that format
is serialized into bytes and bits.

### 2. Internal FIFO

The adapter instantiates `fft_tx_bridge_fifo` internally so that FFT production
does not need to stall just because the host has not started clocking a read yet.

This is an important design choice: the adapter is not just a serializer. It is
also the place where transport pacing is absorbed.

### 3. Window accounting

`complete_windows_r` tracks how many full windows are buffered. This is separate
from raw FIFO occupancy because:

- FIFO occupancy counts bins,
- `complete_windows_r` counts completed windows.

That distinction is what makes `window_ready_o` trustworthy.

### 4. Transaction and serializer state

The remaining state tracks:

- synchronized SPI inputs,
- whether a transaction is active,
- whether BFPEXP copies are still being emitted,
- which pair is currently staged,
- which byte and bit are currently on `spi_miso_o`.

## Timing And Ordering Details

### SPI mode

The module assumes SPI mode 0.

That means:

- the master samples on rising edges,
- the adapter updates the next bit on falling edges.

### Byte order

Bytes are emitted little-endian within each 32-bit word:

```text
word[7:0], word[15:8], word[23:16], word[31:24]
```

The four bytes of the left word are emitted before the four bytes of the right
word.

### Bit order

Within each byte, bits are emitted MSB-first.

## Less Obvious Design Decisions

### Why keep `WORD_W = 32`?

Because the host tooling already reconstructs 32-bit tagged words. Keeping the
same width avoids changing every downstream parser and logger.

### Why repeat BFPEXP?

Because the host-side framing already expects it. The adapter preserves behavior
instead of forcing the host to infer exponent scope in a new way.

### Why synchronize `SCLK` and `CS_N`?

Those pins are asynchronous to the internal FPGA clock. The adapter samples them
into the `clk` domain before deriving edge events so the serializer state machine
remains deterministic.

### Why wait one cycle after popping the FIFO?

The FIFO is show-ahead, so the next head entry becomes visible after the pop
updates the read pointer. The adapter therefore uses a one-cycle refresh wait
before loading the next FFT pair. That is why `wait_next_fft_pair_r` and
`wait_fifo_refresh_r` exist.

### Why return IDLE after the last FFT pair?

If the host clocks too far or keeps `CS_N` low longer than necessary, the module
should not leak into the next window. Returning IDLE makes the boundary explicit.

## Reading The RTL Efficiently

A good reading sequence for the source file is:

1. header block comment,
2. helper functions and `load_pair_words`,
3. `window_ready_o` assignment,
4. `spi_cs_fall_w` transaction start handling,
5. `PAIR_BFPEXP` and `PAIR_FFT` cases in the main `always_ff`.

That order mirrors the runtime behavior and is much easier than reading the file
as one monolithic state machine.

## Verification

### `tb_spi_fft_tx_adapter`

Unit-level contract check for:

- idle response before any window is ready,
- BFPEXP hold behavior,
- byte/word ordering,
- multiple windows in sequence,
- nominal no-overflow behavior.

### `tb_fft_tx_spi_link`

Integration check that combines FIFO behavior and SPI drain behavior over more
than one window.

### `tb_top_level_spi_fft_tx_diag`

Board-facing transport check using the diagnostic top-level and fixed-pattern
data source.

## Related Reading

- [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
- [fft_tx_bridge_fifo.md](fft_tx_bridge_fifo.md)
- [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
- [testbenches.md](testbenches.md)
