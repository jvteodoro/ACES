# Current State

## Transport Status

The workspace currently carries two SPI export paths in parallel.

- Legacy path:
  - the FPGA is the SPI slave
  - the Raspberry Pi is the SPI master
  - the tagged-word format is preserved for compatibility
- New path:
  - the FPGA is the SPI master
  - the Analog Discovery is the passive receiver / logic capture target
  - the formal frame protocol is `header0, header1, header2, payload...`
- The microphone/frontend side is still I2S.

## Active Files

- `rtl/core/aces.sv`
- `rtl/frontend/spi_fft_tx_adapter.sv`
- `rtl/common/fft_tx_bridge_fifo.sv`
- `rtl/top/top_level_test.sv`
- `rtl/top/top_level_spi_fft_tx_diag.sv`
- `submodules/ACES-RPi-interface/rpi3b_spi_fft/fpga_fft_adapter.py`
- `submodules/ACES-RPi-interface/rpi3b_spi_fft/spi_stream.py`
- `submodules/ACES-RPi-interface/rpi3b_spi_fft/analyzer_from_fpga_fft.py`

## Pin Mapping

- Host SPI path on JP2:
  - `GPIO_1_D27`: SPI `SCLK` input
  - `GPIO_1_D29`: SPI `CS_N` input
  - `GPIO_1_D31`: SPI `MISO` output
  - `GPIO_1_D25`: `window_ready`
- Mirrored observability pins on JP2:
  - `GPIO_1_D21`: `window_ready` mirror
  - `GPIO_1_D23`: SPI overflow
  - `GPIO_1_D30`: `window_ready` mirror
  - `GPIO_1_D32`: SPI overflow mirror
  - `GPIO_1_D34`: SPI `MISO` mirror

## Simulation Targets

- `spi_fft_tx_adapter`
- `spi_fft_frame_master`
- `fft_tx_spi_link`
- `fft_frame_spi_master_link`
- `aces`
- `top_level_spi_fft_tx_diag`
- `top_level_test`

## Host Package

The active host package directory is `rpi3b_spi_fft`.

## Transport Notes

The previous tagged-I2S FFT export collateral was removed from this branch. For the current transport contract, use:

- [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- [spi_fft_frame_master_protocol.md](spi_fft_frame_master_protocol.md)
- [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
