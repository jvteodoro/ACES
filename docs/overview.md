# ACES Overview

ACES is an FPGA-oriented audio capture and FFT analysis workspace with:

- SystemVerilog RTL for microphone ingest, FFT control, DMA-style readout, and board top-levels
- deterministic stimulus and mock flows for reproducible simulation
- Raspberry Pi host tooling for live capture, event comparison, and offline protocol replay

## Current Transport

The active FFT export path is now:

```text
fft_dma_reader
    -> fft_tx_bridge_fifo
    -> spi_fft_tx_adapter
    -> FPGA GPIO SPI slave pins
    -> Raspberry Pi SPI master
```

The microphone/frontend side remains I2S.

## Key Goals

- validate the full sample-to-FFT path before lab bring-up
- keep mock and real-IP-oriented simulation flows explicit
- preserve the same logical FFT word format between RTL and Python
- make board wiring and host capture reproducible

## Main Entry Points

- RTL top-level: `rtl/top/top_level_test.sv`
- SPI diagnostic top: `rtl/top/top_level_spi_fft_tx_diag.sv`
- Main pipeline: `rtl/core/aces.sv`
- SPI transport: `rtl/frontend/spi_fft_tx_adapter.sv`
- Host analyzer: `submodules/ACES-RPi-interface/rpi3b_spi_fft/analyzer_from_fpga_fft.py`

## Raspberry Pi Wiring

- `GPIO_1_D27`: SPI `SCLK` input to FPGA
- `GPIO_1_D29`: SPI `CS_N` input to FPGA
- `GPIO_1_D31`: SPI `MISO` output from FPGA
- `GPIO_1_D25`: `window_ready` output from FPGA

## Supported Simulation Targets

- `spi_fft_tx_adapter`
- `fft_tx_spi_link`
- `aces`
- `top_level_spi_fft_tx_diag`
- `top_level_test`

## Related Docs

- [architecture.md](architecture.md)
- [simulation.md](simulation.md)
- [testbenches.md](testbenches.md)
- [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
