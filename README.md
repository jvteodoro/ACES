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
   - uses the checked-in `submodules/R2FFT` implementation together with the repository-owned ROM/IP collateral,
   - keeps the external dependency explicit instead of silently mixing mock and real assets.

## Local Questa usage

From the repository root:

```bash
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24
sim/manifest/scripts/run_questa.sh fft_dma_reader
sim/manifest/scripts/run_questa.sh sample_bridge_and_ingest
sim/manifest/scripts/run_questa.sh aces_audio_to_fft_pipeline
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test
```

For a real-IP-oriented top-level run:

```bash
sim/manifest/scripts/run_questa.sh top_level_test real
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
.\sim\manifest\scripts\run_questa.ps1 top_level_test real
```

If you work from VS Code Remote WSL but have Questa and Quartus installed only on Windows, keep using the POSIX wrappers from the WSL terminal:

```bash
sim/manifest/scripts/run_questa.sh hexa7seg
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/open_questa_gui.sh sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

When `vsim` is not present in the Linux `PATH`, these `.sh` wrappers now auto-forward to the matching PowerShell script through `powershell.exe`.

The batch launchers also stop existing `vsim`/`vsimk` sessions before starting a new run, which avoids single-seat Questa license conflicts on Windows installs commonly used from WSL.

The equivalent manual WSL-to-Windows invocation pattern is:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& './sim/manifest/scripts/run_questa.ps1' 'top_level_test' 'mock'"
```

To preserve an already-open simulator session, pass `-KeepExistingSessions` to the PowerShell launcher instead of using the default cleanup behavior.

To open the supported testbenches directly in GUI mode from the main launcher and load the matching checked-in wave setup:

```bash
sim/manifest/scripts/run_questa.sh hexa7seg gui
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24 gui
sim/manifest/scripts/run_questa.sh top_level_test mock gui
```

For the supported manifest targets, the launcher looks for the corresponding `tb_<name>.do` file under `sim/manifest/waves/` and opens the verification-oriented signal set automatically.

For an interactive GUI bring-up using a specific filelist and top module:

```bash
sim/manifest/scripts/open_questa_gui.sh sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

PowerShell:

```powershell
.\sim\manifest\scripts\open_questa_gui.ps1 sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

For Quartus commands from WSL, invoke the Windows executable through PowerShell in the same way:

```bash
powershell.exe -NoProfile -Command "& 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe' --version"
```

For Quartus project bring-up of the active board top-level, open `quartus/top_level_test.qpf`. The companion `quartus/top_level_test.qsf` loads `quartus/top_level_test_sources.tcl`, which adds the RTL, the checked-in R2FFT submodule sources, the required IP `.qip` files, and the ROM/twiddle memory assignments for `top_level_test`.

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
