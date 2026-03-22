# ACES simulation manifest

`sim/manifest/` is the repository-owned source of truth for reproducible simulation.

## Layers

- `filelists/`: versioned compile manifests for supported testbenches.
- `scripts/`: repository-owned launch, GUI, regression, and packaging scripts.
- `waves/`: checked-in Questa wave setups.
- `../local/`: machine-local outputs such as `work/`, logs, and transcript files.
- `../portable/`: generated redistribution artifacts.

## Supported mock-flow tests

- `i2s_rx_adapter_24`
- `sample_width_adapter_24_to_18`
- `i2s_master_clock_gen`
- `i2s_stimulus_manager`
- `i2s_stimulus_manager_rom`
- `fft_control`
- `fft_dma_reader`
- `aces_fft_ingest`
- `sample_bridge_and_ingest`
- `aces_audio_to_fft_pipeline`
- `aces`
- `aces_stimulus_manager`
- `top_level_test`

## Primary scripts

- `scripts/run_questa.sh` / `scripts/run_questa.ps1`: batch entry points for named tests.
- `scripts/open_questa_gui.sh` / `scripts/open_questa_gui.ps1`: convenience helpers for interactive GUI launches.
- `scripts/regression_mock.sh` / `scripts/regression_mock.ps1`: batch mock regression helpers.
- `scripts/package_portable.sh` / `scripts/package_portable.ps1`: portable package generators.

## Running locally with Questa

```bash
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24
sim/manifest/scripts/run_questa.sh fft_dma_reader
sim/manifest/scripts/run_questa.sh aces_audio_to_fft_pipeline
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test
sim/manifest/scripts/regression_mock.sh
```

Windows PowerShell:

```powershell
.\sim\manifest\scripts\run_questa.ps1 fft_dma_reader
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
.\sim\manifest\scripts\run_questa.ps1 top_level_test
.\sim\manifest\scripts\regression_mock.ps1
```

## Real-IP-oriented flow

The repository includes the real Quartus ROM/twiddle/DPRAM IP wrappers under `rtl/ip/rom/` and `rtl/ip/fft/`, but the true `r2fft_tribuf_impl` implementation is still expected from external collateral. The Questa launcher stages the required `.mif` memory files into the local run directory automatically. Use:

```bash
EXTRA_FILELIST=/abs/path/to/r2fft_real.f sim/manifest/scripts/run_questa.sh top_level_test real
```

PowerShell:

```powershell
$env:EXTRA_FILELIST = 'C:\path\to\r2fft_real.f'
.\sim\manifest\scripts\run_questa.ps1 top_level_test real
```

That keeps the mock and real flows explicit and reproducible.
