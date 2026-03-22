# ACES

ACES is an FPGA audio/DSP repository organized around reproducible simulation, portable Questa packaging, and a clean separation between active RTL, testbenches, manifest data, and generated simulator artifacts.

## Quick Start

If you are new to the repository, read these first:

1. [Project overview](docs/overview.md)
2. [Repository structure](docs/repository_structure.md)
3. [Simulation guide](docs/simulation.md)
4. [Portable flow guide](docs/portable_flow.md)

## Repository layout

```text
rtl/
  common/      Shared glue logic: width adaptation, CDC bridge, FFT control, DMA readout, display helpers.
  frontend/    I2S clocking and receive-side logic.
  stimulus/    Deterministic I2S stimulus generators and ROM-backed playback control.
  core/        ACES pipeline assemblies and simulation-oriented top-level wrappers.
  ip/
    fft/       Quartus/Altera FFT-facing helper IP collateral.
    rom/       Quartus/Altera ROM IP wrappers.

tb/
  unit/        Narrow-scope module tests.
  integration/ End-to-end and subsystem pipeline tests.
  mocks/       Mock models used to keep local simulation self-contained.

tools/         ROM-generation artifacts and utility inputs/outputs.
utils/         Python scripts for generating ROM contents and validating FFT behavior.
docs/          Modular project documentation and legacy reference material.

sim/
  manifest/    Versioned source-of-truth filelists, scripts, and wave setups.
  local/       Non-versioned machine-local simulator outputs.
  portable/    Generated redistribution packages and ZIPs.
```

## Simulation philosophy

ACES supports two complementary simulation flows:

1. **Mock flow**
   - self-contained,
   - intended for local bring-up and regression,
   - uses repository-provided mock FFT and ROM models.

2. **Real-IP-oriented flow**
   - uses the checked-in Quartus ROM wrapper,
   - leaves room for attaching the real FFT implementation through an extra filelist,
   - keeps the external dependency explicit instead of silently mixing mock and real assets.

## Local Questa usage

From the repository root:

```bash
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24
sim/manifest/scripts/run_questa.sh fft_dma_reader
sim/manifest/scripts/run_questa.sh sample_bridge_and_ingest
sim/manifest/scripts/run_questa.sh aces_audio_to_fft_pipeline
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test_mux_clear_hex_based_on_uploaded
```

For a real-IP-oriented top-level run:

```bash
EXTRA_FILELIST=/abs/path/to/r2fft_real.f sim/manifest/scripts/run_questa.sh top_level_test real
```

For a mock regression pass:

```bash
sim/manifest/scripts/regression_mock.sh
```

Windows PowerShell equivalents:

```powershell
.\sim\manifest\scripts\run_questa.ps1 i2s_rx_adapter_24
.\sim\manifest\scripts\run_questa.ps1 fft_dma_reader
.\sim\manifest\scripts\regression_mock.ps1
$env:EXTRA_FILELIST='C:\path\to\r2fft_real.f'; .\sim\manifest\scripts\run_questa.ps1 top_level_test real
```

For an interactive GUI bring-up using a specific filelist and top module:

```bash
sim/manifest/scripts/open_questa_gui.sh sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test_real
```

PowerShell:

```powershell
.\sim\manifest\scripts\open_questa_gui.ps1 sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test_real
```

## Portable package workflow

Generate the portable package with:

```bash
sim/manifest/scripts/package_portable.sh
```

PowerShell:

```powershell
.\sim\manifest\scripts\package_portable.ps1
```

That populates `sim/portable/questa_package/` and produces `sim/portable/aces_questa_portable.zip`.

## Documentation

- [Overview](docs/overview.md)
- [Architecture](docs/architecture.md)
- [Repository structure](docs/repository_structure.md)
- [Simulation guide](docs/simulation.md)
- [Testbench guide](docs/testbenches.md)
- [Portable flow](docs/portable_flow.md)
- [Development guide](docs/development_guide.md)
- [Coding guidelines](docs/coding_guidelines.md)
- [Verification methodology](docs/verification_methodology.md)
- [FAQ](docs/faq.md)
- [Legacy reference material](docs/legacy/)

## Legacy material

Historical board-oriented and stale top-level variants were moved under `docs/legacy/` so active source trees stay focused on reproducible simulation and extension work.
