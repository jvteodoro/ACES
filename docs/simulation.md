# Simulation Guide

This guide is organized around the most common contributor question:
"which simulation target should I run for the part I just changed?"

## Quick Start

From the repository root, these are the primary commands:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
sim/manifest/scripts/run_questa.sh aces
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test real
```

PowerShell equivalents:

```powershell
.\sim\manifest\scripts\run_questa.ps1 spi_fft_tx_adapter
.\sim\manifest\scripts\run_questa.ps1 fft_tx_spi_link
.\sim\manifest\scripts\run_questa.ps1 top_level_spi_fft_tx_diag
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
.\sim\manifest\scripts\run_questa.ps1 top_level_test real
```

## Recommended Run Order For SPI Work

When changing the SPI transport, use this escalation path:

1. `spi_fft_tx_adapter`
   Fastest proof that packing and serialization still match the contract.
2. `fft_tx_spi_link`
   Confirms buffering and drain behavior together.
3. `top_level_spi_fft_tx_diag`
   Confirms the board-facing transport in isolation.
4. `top_level_test mock`
   Confirms full-path integration in the active top-level.

This order saves time and narrows failures faster than jumping straight into the
largest integration bench.

## Mock Regression

Run the maintained mock regression set with:

```bash
sim/manifest/scripts/regression_mock.sh
```

Use this when you want a broader confidence pass after transport work, not as a
replacement for the smaller targeted benches during development.

## Relevant Filelists

The main manifests involved in the SPI path are:

- `mock_unit_spi_fft_tx_adapter.f`
- `mock_integration_fft_tx_spi_link.f`
- `mock_integration_aces.f`
- `mock_integration_top_level_spi_fft_tx_diag.f`
- `mock_integration_top_level_test.f`
- `real_ip_top_level_test.f`

The filelist names reflect scope:

- `unit`: one module contract,
- `integration`: interaction between multiple maintained modules,
- `real_ip`: flow that depends on vendor or external IP collateral.

## GUI Runs

Use the same target names with `gui` appended:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter gui
sim/manifest/scripts/run_questa.sh fft_tx_spi_link gui
sim/manifest/scripts/run_questa.sh top_level_test mock gui
```

Waveform viewing is especially helpful for:

- byte/bit ordering confusion,
- SPI edge timing questions,
- confirming when `window_ready` drops and rises,
- following the transition from BFPEXP pairs to FFT pairs.

## Quartus Entry Points

Board project entry point:

```text
quartus/top_level_test.qpf
```

Active full-top source manifest:

```text
quartus/top_level_test_sources.tcl
```

SPI-only diagnostic top source manifest:

```text
quartus/top_level_spi_fft_tx_diag_sources.tcl
```

## Common Workflows

### I changed only comments or docs

No simulation is logically required, but running `spi_fft_tx_adapter` is still a
good sanity check if you touched RTL comments near active logic.

### I changed SPI packing or serializer behavior

Run:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
```

### I changed diagnostic top-level wiring or observability

Run:

```bash
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
```

### I changed ACES integration or board-facing SPI mapping

Run:

```bash
sim/manifest/scripts/run_questa.sh top_level_test mock
```

## Notes

- The active export benches target SPI, not the old tagged-I2S transport.
- `top_level_spi_fft_tx_diag` is the best board-facing transport sanity target.
- `top_level_test mock` is still the quickest full-top smoke test.
- The real-IP flow remains focused on `top_level_test` and
  `top_level_fft_isolated`.
