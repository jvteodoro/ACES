# Current State

This page is the status snapshot for the active branch. It is meant to answer
"what is true right now?" without repeating the full architectural story.

## Transport Status

The active FFT export path is SPI slave TX from FPGA to Raspberry Pi.

- FPGA role: SPI slave
- Raspberry Pi role: SPI master
- framing unit: one SPI transaction per FFT window
- logical payload contract: unchanged tagged 32-bit words
- microphone/frontend side: still I2S

## Authoritative RTL Files

These are the files that define the active transport behavior:

- `rtl/core/aces.sv`
  Main core boundary that exposes the SPI transport ports.
- `rtl/frontend/spi_fft_tx_adapter.sv`
  Source of truth for buffering, framing, and serialization.
- `rtl/common/fft_tx_bridge_fifo.sv`
  Reusable FIFO implementation used by the adapter.
- `rtl/top/top_level_test.sv`
  Full board top-level used for integrated bring-up.
- `rtl/top/top_level_spi_fft_tx_diag.sv`
  Deterministic diagnostic top-level for transport-only validation.

## Host-Side Files To Keep In Sync

When the host submodule is present, the active package directory is
`rpi3b_spi_fft`, especially:

- `fpga_fft_adapter.py`
- `spi_stream.py`
- `analyzer_from_fpga_fft.py`

These files must stay aligned with:

- word width,
- tag meanings,
- `BFPEXP_HOLD_FRAMES`,
- number of bins per window,
- expected byte ordering.

## Pin Mapping

The full top-level currently exports the SPI transport through:

- `GPIO_1_D27`: SPI `SCLK`
- `GPIO_1_D29`: SPI `CS_N`
- `GPIO_1_D31`: SPI `MISO`
- `GPIO_1_D25`: `window_ready`
- `GPIO_1_D23`: `tx_overflow_o` debug

## Active Simulation Targets

The main maintained SPI-related targets are:

- `spi_fft_tx_adapter`
- `fft_tx_spi_link`
- `aces`
- `top_level_spi_fft_tx_diag`
- `top_level_test`

## Recommended Entry Point By Task

- Understanding the transport:
  [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
- Modifying packing or framing:
  [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- Board bring-up or scope validation:
  [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
- Running or extending verification:
  [testbenches.md](testbenches.md) and [simulation.md](simulation.md)

## Legacy Note

The old tagged-I2S export collateral is not the active path on this branch.
When there is any disagreement between older notes and the current SPI transport,
trust these sources first:

1. `rtl/frontend/spi_fft_tx_adapter.sv`
2. `tb/unit/tb_spi_fft_tx_adapter.sv`
3. [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
4. [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
