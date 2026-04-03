# Current State

## Transport Status

The active FFT export path is SPI.

- The FPGA is the SPI slave.
- The Raspberry Pi is the SPI master.
- The logical tagged word format is preserved.
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

- `GPIO_1_D27`: SPI `SCLK`
- `GPIO_1_D29`: SPI `CS_N`
- `GPIO_1_D31`: SPI `MISO`
- `GPIO_1_D25`: `window_ready`
- `GPIO_1_D23`: `tx_overflow_o` debug

## Simulation Targets

- `spi_fft_tx_adapter`
- `fft_tx_spi_link`
- `aces`
- `top_level_spi_fft_tx_diag`
- `top_level_test`

## Host Package

The active host package directory is `rpi3b_spi_fft`.

## Transport Notes

The previous tagged-I2S FFT export collateral was removed from this branch. For the current transport contract, use:

- [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
