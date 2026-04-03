# Testbenches

## Supported TX-Path Benches

The active FFT export benches after the SPI refactor are:

- `tb_spi_fft_tx_adapter`
- `tb_fft_tx_spi_link`
- `tb_top_level_spi_fft_tx_diag`
- `tb_top_level_test`

## Bench Roles

### `tb_spi_fft_tx_adapter`

Unit bench for `rtl/frontend/spi_fft_tx_adapter.sv`.

Checks:

- tagged word packing
- BFPEXP hold frames
- SPI byte ordering
- multi-window sequencing
- no unexpected overflow on a nominal path

### `tb_fft_tx_spi_link`

Integration bench for:

```text
fft_tx_bridge_fifo -> spi_fft_tx_adapter
```

Checks:

- bridge FIFO alignment
- valid/ready to SPI drain behavior
- multi-window handoff
- no overflow in a nominal burst

### `tb_top_level_spi_fft_tx_diag`

Board-facing diagnostic bench for `rtl/top/top_level_spi_fft_tx_diag.sv`.

Checks:

- fixed-pattern SPI output visible on the top-level pins
- deterministic BFPEXP + FFT payload sequence
- `window_ready` behavior

### `tb_top_level_test`

Main board-oriented integration bench.

Checks:

- sample ingest path
- FFT output stream
- SPI export path using the same expected tagged pairs
- mock-flow smoke on the active top-level

## Other Supported Benches

- `tb_fft_tx_bridge_fifo`
- `tb_fft_dma_reader`
- `tb_aces_audio_to_fft_pipeline`
- `tb_aces`
- `tb_top_level_fft_isolated`

## Filelists

The current SPI-related manifest filelists are:

- `sim/manifest/filelists/mock_unit_spi_fft_tx_adapter.f`
- `sim/manifest/filelists/mock_integration_fft_tx_spi_link.f`
- `sim/manifest/filelists/mock_integration_top_level_spi_fft_tx_diag.f`
- `sim/manifest/filelists/mock_integration_top_level_test.f`

## Running

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
```
