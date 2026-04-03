# ACES simulation manifest

`sim/manifest/` is the repository-owned source of truth for reproducible simulation.

## Layers

- `filelists/`: versioned compile manifests for supported testbenches.
- `scripts/`: repository-owned launch, GUI, regression, and packaging scripts.
- `waves/`: checked-in Questa wave setups.
- `../local/`: machine-local outputs such as `work/`, logs, and transcript files.
- `../portable/`: generated redistribution artifacts.

## Supported mock-flow tests

- `hexa7seg`
- `i2s_rx_adapter_24`
- `sample_width_adapter_24_to_18`
- `i2s_master_clock_gen`
- `i2s_stimulus_manager_rom`
- `fft_control`
- `fft_dma_reader`
- `fft_tx_bridge_fifo`
- `spi_fft_tx_adapter`
- `fft_tx_spi_link`
- `aces_audio_to_fft_pipeline`
- `aces`
- `top_level_spi_fft_tx_diag`
- `top_level_test`

The obsolete tagged-I2S FFT transport manifests were removed from this branch. The maintained launch targets are SPI-oriented.

## Supported real-IP-oriented tests

- `top_level_test`
- `top_level_fft_isolated`

## Primary scripts

- `scripts/run_questa.sh` / `scripts/run_questa.ps1`: batch entry points for named tests.
- `scripts/open_questa_gui.sh` / `scripts/open_questa_gui.ps1`: convenience helpers for interactive GUI launches.
- `scripts/run_modelsim.sh` / `scripts/run_modelsim.ps1`: batch entry points mirroring Questa flow for ModelSim users.
- `scripts/open_modelsim_gui.sh` / `scripts/open_modelsim_gui.ps1`: interactive GUI launch helpers for ModelSim users.
- `scripts/regression_mock.sh` / `scripts/regression_mock.ps1`: batch mock regression helpers.
- `scripts/package_portable.sh` / `scripts/package_portable.ps1`: portable package generators.

## Running locally with Questa

```bash
sim/manifest/scripts/run_questa.sh fft_tx_bridge_fifo
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24
sim/manifest/scripts/run_questa.sh fft_dma_reader
sim/manifest/scripts/run_questa.sh aces_audio_to_fft_pipeline
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test
sim/manifest/scripts/run_questa.sh top_level_fft_isolated real
sim/manifest/scripts/regression_mock.sh
```

Windows PowerShell:

```powershell
.\sim\manifest\scripts\run_questa.ps1 fft_tx_bridge_fifo
.\sim\manifest\scripts\run_questa.ps1 spi_fft_tx_adapter
.\sim\manifest\scripts\run_questa.ps1 fft_tx_spi_link
.\sim\manifest\scripts\run_questa.ps1 fft_dma_reader
.\sim\manifest\scripts\run_questa.ps1 top_level_spi_fft_tx_diag
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
.\sim\manifest\scripts\run_questa.ps1 top_level_test
.\sim\manifest\scripts\run_questa.ps1 top_level_fft_isolated real
.\sim\manifest\scripts\regression_mock.ps1
```

## Running locally with ModelSim

```bash
sim/manifest/scripts/run_modelsim.sh fft_dma_reader
sim/manifest/scripts/run_modelsim.sh top_level_test mock
sim/manifest/scripts/run_modelsim.sh top_level_test real
```

Windows PowerShell:

```powershell
.\sim\manifest\scripts\run_modelsim.ps1 fft_dma_reader
.\sim\manifest\scripts\run_modelsim.ps1 top_level_test mock
.\sim\manifest\scripts\run_modelsim.ps1 top_level_test real
```

## Real-IP-oriented flow

The repository includes the real Quartus ROM wrapper under `rtl/ip/rom/` plus the checked-in `submodules/R2FFT` sources for the true FFT implementation. The Questa launcher stages the required `.mif` memory files into the local run directory automatically. Use:

```bash
sim/manifest/scripts/run_questa.sh top_level_test real
sim/manifest/scripts/run_questa.sh top_level_fft_isolated real
```

PowerShell:

```powershell
.\sim\manifest\scripts\run_questa.ps1 top_level_test real
.\sim\manifest\scripts\run_questa.ps1 top_level_fft_isolated real
```

That keeps the mock and real flows explicit and reproducible.
