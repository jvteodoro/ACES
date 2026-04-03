# ACES Architecture

## System View

```text
I2S mic or ROM stimulus
    -> i2s_rx_adapter_24
    -> sample_width_adapter_24_to_18
    -> aces_audio_to_fft_pipeline
    -> FFT control + r2fft_tribuf_impl
    -> fft_dma_reader
    -> fft_tx_bridge_fifo
    -> spi_fft_tx_adapter
    -> Raspberry Pi SPI host tools
```

## Major Blocks

### I2S frontend

- `i2s_master_clock_gen`
- `i2s_rx_adapter_24`
- `aces_audio_to_fft_pipeline`

This side still reconstructs microphone samples exactly as before.

### FFT execution

- `fft_control`
- `r2fft_tribuf_impl`
- `fft_dma_reader`

This stage is unchanged by the SPI migration. It still emits:

- `fft_tx_valid_o`
- `fft_tx_index_o`
- `fft_tx_real_o`
- `fft_tx_imag_o`
- `fft_tx_last_o`
- `bfpexp_o`

### TX bridge

`fft_tx_bridge_fifo` decouples FFT DMA readout from the physical transport.

Each entry keeps these fields aligned:

- `real`
- `imag`
- `last`
- `bfpexp`

### SPI FFT transport

`spi_fft_tx_adapter` is the active export backend.

Responsibilities:

- buffer FFT bins until a full window is available
- act as SPI slave to the Raspberry Pi
- preserve the same 32-bit tagged word format used by the host parser
- emit `window_ready_o` when a complete transaction can be read

Transaction format:

```text
BFPEXP tagged pair repeated bfpexp_hold_frames times
then
frame_bins FFT tagged pairs
```

Word format:

```text
[ tag(2) | reserved(12) | signed payload(18) ]
```

Tags:

- `0`: idle
- `1`: BFPEXP
- `2`: FFT

### Top-level board mapping

`rtl/top/top_level_test.sv` keeps the transport on the same GPIO neighborhood used previously:

- `GPIO_1_D27`: SPI `SCLK`
- `GPIO_1_D29`: SPI `CS_N`
- `GPIO_1_D31`: SPI `MISO`
- `GPIO_1_D25`: `window_ready`
- `GPIO_1_D23`: overflow debug

## Host Path

The Raspberry Pi package under `submodules/ACES-RPi-interface/rpi3b_spi_fft/` now:

- opens `/dev/spidevX.Y`
- optionally waits for `window_ready`
- reads one full tagged transaction per FFT window
- reconstructs FFT bins and MFCC features
- writes `fft.npy`, `evento.npy`, JSONL debug logs, and CSV/raw captures

## Invariants

- The microphone-side I2S capture path is unchanged.
- The host-visible tagged word layout is unchanged.
- `bfpexp_hold_frames` must match between FPGA and Raspberry Pi tools.
- SPI is master-driven by the Raspberry Pi; the FPGA is always the slave.
- `window_ready` is recommended for reliable framing and to avoid idle polling.
