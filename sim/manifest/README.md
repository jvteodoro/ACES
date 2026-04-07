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
- `aces_audio_to_fft_pipeline`

The obsolete FPGA FFT/SPI transport manifests were removed from this branch.
The maintained launch targets now focus only on the raw-audio capture path.

## Primary scripts

- `scripts/run_questa.sh` / `scripts/run_questa.ps1`: batch entry points for named tests.
- `scripts/open_questa_gui.sh` / `scripts/open_questa_gui.ps1`: convenience helpers for interactive GUI launches.
- `scripts/run_modelsim.sh` / `scripts/run_modelsim.ps1`: batch entry points mirroring Questa flow for ModelSim users.
- `scripts/open_modelsim_gui.sh` / `scripts/open_modelsim_gui.ps1`: interactive GUI launch helpers for ModelSim users.
- `scripts/regression_mock.sh` / `scripts/regression_mock.ps1`: batch mock regression helpers.
- `scripts/package_portable.sh` / `scripts/package_portable.ps1`: portable package generators.

## Running locally with Questa

```bash
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24
sim/manifest/scripts/run_questa.sh aces_audio_to_fft_pipeline
sim/manifest/scripts/regression_mock.sh
```

Windows PowerShell:

```powershell
.\sim\manifest\scripts\run_questa.ps1 i2s_rx_adapter_24
.\sim\manifest\scripts\run_questa.ps1 aces_audio_to_fft_pipeline
.\sim\manifest\scripts\regression_mock.ps1
```

## Running locally with ModelSim

```bash
sim/manifest/scripts/run_modelsim.sh i2s_rx_adapter_24
sim/manifest/scripts/run_modelsim.sh aces_audio_to_fft_pipeline
```

Windows PowerShell:

```powershell
.\sim\manifest\scripts\run_modelsim.ps1 i2s_rx_adapter_24
.\sim\manifest\scripts\run_modelsim.ps1 aces_audio_to_fft_pipeline
```
