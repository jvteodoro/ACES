# Top-Level SPI FFT TX Diagnostic

`top_level_spi_fft_tx_diag` is a board-facing diagnostic top-level that isolates only the SPI FFT export path.

## File

- `rtl/top/top_level_spi_fft_tx_diag.sv`

## Purpose

It replaces the full ACES datapath with a deterministic fixed-pattern FFT source so the board wiring and SPI host capture can be verified without depending on microphone ingest or FFT execution.

## Exported Pin Use

- `GPIO_1_D27`: SPI `SCLK` input
- `GPIO_1_D29`: SPI `CS_N` input
- `GPIO_1_D31`: SPI `MISO` output
- `GPIO_1_D25`: `window_ready` output

## Fixed Pattern

- `real = 18'sh15555`
- `imag = 18'sh0AAAB`
- `bfpexp = 8'sh12`

## Simulation

```bash
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
```

The associated manifest filelist is:

- `sim/manifest/filelists/mock_integration_top_level_spi_fft_tx_diag.f`
