# Simulation Guide

## Main Commands

From the repository root:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
sim/manifest/scripts/run_questa.sh aces
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test real
```

PowerShell:

```powershell
.\sim\manifest\scripts\run_questa.ps1 spi_fft_tx_adapter
.\sim\manifest\scripts\run_questa.ps1 fft_tx_spi_link
.\sim\manifest\scripts\run_questa.ps1 top_level_spi_fft_tx_diag
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
.\sim\manifest\scripts\run_questa.ps1 top_level_test real
```

## Mock Regression

```bash
sim/manifest/scripts/regression_mock.sh
```

## Relevant Filelists

- `mock_unit_spi_fft_tx_adapter.f`
- `mock_integration_fft_tx_spi_link.f`
- `mock_integration_aces.f`
- `mock_integration_top_level_spi_fft_tx_diag.f`
- `mock_integration_top_level_test.f`
- `real_ip_top_level_test.f`

## GUI

Supported GUI launches use the same target names:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter gui
sim/manifest/scripts/run_questa.sh fft_tx_spi_link gui
sim/manifest/scripts/run_questa.sh top_level_test mock gui
```

## Quartus

The board project entry point remains:

```text
quartus/top_level_test.qpf
```

The active source manifest is:

```text
quartus/top_level_test_sources.tcl
```

For the SPI-only diagnostic top, use:

```text
quartus/top_level_spi_fft_tx_diag_sources.tcl
```

## Notes

- The main TX transport benches now target SPI, not the legacy tagged-I2S serializer.
- `top_level_test` mock flow is still the quickest board-oriented smoke test.
- The real flow remains focused on `top_level_test` and `top_level_fft_isolated`.
