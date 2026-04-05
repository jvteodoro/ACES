# ACES Architecture

This document explains the active architecture with emphasis on the SPI export
path. The short version is:

- acquisition and FFT execution remain FPGA-driven,
- export is now host-driven over SPI,
- the host-visible meaning of each FFT word was intentionally preserved.

## System View

```text
I2S mic or ROM stimulus
    -> i2s_rx_adapter_24
    -> sample_width_adapter_24_to_18
    -> aces_audio_to_fft_pipeline
    -> fft_control
    -> r2fft_tribuf_impl
    -> fft_dma_reader
    -> spi_fft_tx_adapter
        -> internal fft_tx_bridge_fifo
        -> tagged 32-bit word packer
        -> SPI mode-0 serializer
    -> FPGA GPIO SPI slave pins
    -> Raspberry Pi SPI master tools
```

The SPI refactor changed only the export backend. The microphone-side I2S path,
FFT control logic, and FFT execution model remain conceptually the same.

## Architectural Layers

### 1. Audio ingress and sample preparation

Main blocks:

- `i2s_master_clock_gen`
- `i2s_rx_adapter_24`
- `sample_width_adapter_24_to_18`
- `aces_audio_to_fft_pipeline`

Responsibility:

- recover samples from the microphone or ROM-driven stimulus,
- normalize them to the FFT data width,
- present a clean stream to the FFT subsystem.

This layer does not know or care that the downstream export path is SPI.

### 2. FFT execution and readout

Main blocks:

- `fft_control`
- `r2fft_tribuf_impl`
- `fft_dma_reader`

Responsibility:

- trigger FFT runs,
- read completed FFT bins back out of the core,
- expose one bin at a time together with `bfpexp` and `last` metadata.

The key exported signals are still:

- `fft_tx_valid_o`
- `fft_tx_index_o`
- `fft_tx_real_o`
- `fft_tx_imag_o`
- `fft_tx_last_o`
- `bfpexp_o`

That interface is the logical boundary between FFT computation and transport.

### 3. Transport adaptation

Main block:

- `spi_fft_tx_adapter`

Responsibility:

- accept bins in the FPGA clock domain,
- hold them until a complete window is available,
- preserve the existing 32-bit tagged contract,
- serialize the window only when the host clocks it out.

This is where the architecture changes from stream-oriented producer behavior to
transaction-oriented consumer behavior.

## Why The Adapter Owns A FIFO

SPI is host-paced. The FFT path is FPGA-paced. The adapter therefore owns the
buffer that separates those timing domains.

Internally it uses `fft_tx_bridge_fifo`, which keeps these fields aligned:

- `real`
- `imag`
- `last`
- `bfpexp`

This alignment is important because the host reconstructs meaning from the pair
structure. If `bfpexp` ever drifted relative to `real/imag`, the payload would
still look syntactically valid while being semantically wrong.

## Transport Contract

### Logical 32-bit word

Every logical word sent to the host uses this layout:

```text
[ tag(2) | reserved zeros | signed payload ]
```

In the current configuration, `WORD_W = 32` and `PAYLOAD_W = 18`.

### Tag meanings

- `0`: IDLE
- `1`: BFPEXP
- `2`: FFT

### Logical pair meanings

- BFPEXP pair:
  both words carry the same sign-extended exponent
- FFT pair:
  left word is the real component, right word is the imaginary component

### Window transaction

One SPI transaction is one FFT window:

```text
BFPEXP pair repeated BFPEXP_HOLD_FRAMES times
then
one FFT pair per bin
```

The repetition of BFPEXP is not accidental. It preserves the framing already
assumed by the host-side software.

## Window Readiness Model

The adapter does not simply expose FIFO non-empty as readiness. Instead it tracks
the number of complete windows buffered.

Why:

- one accepted bin is not enough for a safe host read,
- a full window exists only after the accepted bin tagged with `last`,
- the host should not need to infer end-of-window boundaries from partial data.

The public result is `window_ready_o`, which means:

- at least one complete window is buffered,
- no SPI transaction is currently active.

## SPI Timing Model

The active assumptions are:

- SPI mode 0,
- Raspberry Pi drives `SCLK` and `CS_N`,
- FPGA drives only `MISO`.

The adapter synchronizes `SCLK` and `CS_N` into the internal `clk` domain and
advances serializer state from those synchronized edges. New data is presented on
falling edges so that the master can sample on rising edges.

## Top-Level Mapping

`rtl/top/top_level_test.sv` preserves the Pi-facing signal neighborhood used in
previous work so board wiring and existing harnesses remain familiar:

- `GPIO_1_D27`: SPI `SCLK`
- `GPIO_1_D29`: SPI `CS_N`
- `GPIO_1_D31`: SPI `MISO`
- `GPIO_1_D25`: `window_ready`
- `GPIO_1_D23`: overflow/debug

For isolated lab work, `rtl/top/top_level_spi_fft_tx_diag.sv` exposes the same
transport behavior without depending on microphone capture or FFT execution.

## Host Path

When the Raspberry Pi host package is initialized, it is expected to:

- open a Linux spidev device,
- optionally wait for `window_ready`,
- perform one SPI transaction per FFT window,
- decode tagged words back into BFPEXP and complex bins,
- hand the reconstructed window to analysis or logging tools.

The crucial architectural point is that the host contract is window-based, not
stream-without-boundaries based.

## Invariants You Should Preserve

- The microphone-side I2S capture path is unchanged by transport work.
- The host-visible tagged word layout must remain stable unless the host package
  changes in lockstep.
- `BFPEXP_HOLD_FRAMES` must match on FPGA and host.
- The Raspberry Pi is always the SPI master.
- `window_ready` is the intended framing handshake for production use.
- A partial or premature host read must never cause random payload leakage; the
  adapter should return IDLE when no full window is ready.
