# Simulation Guide

## Purpose

This guide explains how ACES is simulated with the refactored Questa-oriented workflow.

The repository is organized so that simulation is driven from `sim/manifest/`, not from ad hoc command history. That means:

- filelists define compile inputs,
- scripts define repeatable invocation patterns,
- wave `.do` files define review setup,
- local artifacts go under `sim/local/`.

## Simulation Inputs

### Filelists
Filelists live under `sim/manifest/filelists/`.

They define which RTL, testbench, and mock files are compiled for each supported flow.

Examples:

- `mock_unit_i2s_rx_adapter_24.f`
- `mock_integration_top_level_test.f`
- `real_ip_top_level_test.f`

### Tcl launch logic
`sim/manifest/scripts/run_questa.tcl` maps a named test target to the correct filelist and top module.

### Shell and PowerShell launch entry points
`sim/manifest/scripts/run_questa.sh` and `sim/manifest/scripts/run_questa.ps1` are the main local batch entry points. They:

- locate the repository root,
- create a local run directory under `sim/local/questa/`,
- export environment variables used by the Tcl launcher,
- launch Questa in batch mode.

When these scripts are run from a WSL terminal and `vsim` is not available in the Linux `PATH`, `run_questa.sh` now auto-forwards to `run_questa.ps1` through `powershell.exe`, so the same repository command still works from VS Code Remote WSL when the simulator itself is installed only on Windows.

Before each batch launch, the PowerShell wrappers also stop any existing `vsim`/`vsimk` processes by default so a node-locked Questa seat is released before the new run starts.

ModelSim users can run the mirrored wrappers `sim/manifest/scripts/run_modelsim.sh` and `sim/manifest/scripts/run_modelsim.ps1`, which use the same Tcl launcher and filelist mapping.

### Waveform setups
Waveform `.do` files live under `sim/manifest/waves/`.

These are checked in so that waveform review can be shared instead of recreated manually.

## Running a Testbench in Batch Mode

From the repository root:

```bash
sim/manifest/scripts/run_questa.sh fft_tx_bridge_fifo
sim/manifest/scripts/run_questa.sh i2s_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_i2s_link
sim/manifest/scripts/run_questa.sh hexa7seg
sim/manifest/scripts/run_questa.sh i2s_rx_adapter_24
sim/manifest/scripts/run_questa.sh i2s_master_clock_gen
sim/manifest/scripts/run_questa.sh fft_control
sim/manifest/scripts/run_questa.sh fft_dma_reader
sim/manifest/scripts/run_questa.sh aces_fft_ingest
sim/manifest/scripts/run_questa.sh i2s_stimulus_manager
sim/manifest/scripts/run_questa.sh sample_bridge_and_ingest
sim/manifest/scripts/run_questa.sh aces_audio_to_fft_pipeline
sim/manifest/scripts/run_questa.sh aces
sim/manifest/scripts/run_questa.sh top_level_i2s_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test
```

To open the same supported targets in GUI mode and auto-load the matching checked-in wave file:

```bash
sim/manifest/scripts/run_questa.sh i2s_fft_tx_adapter gui
sim/manifest/scripts/run_questa.sh fft_tx_i2s_link gui
sim/manifest/scripts/run_questa.sh hexa7seg gui
sim/manifest/scripts/run_questa.sh fft_dma_reader gui
sim/manifest/scripts/run_questa.sh top_level_test mock gui
```

Windows PowerShell equivalents:

```powershell
.\sim\manifest\scripts\run_questa.ps1 fft_tx_bridge_fifo
.\sim\manifest\scripts\run_questa.ps1 i2s_fft_tx_adapter
.\sim\manifest\scripts\run_questa.ps1 fft_tx_i2s_link
.\sim\manifest\scripts\run_questa.ps1 hexa7seg
.\sim\manifest\scripts\run_questa.ps1 i2s_rx_adapter_24
.\sim\manifest\scripts\run_questa.ps1 fft_control
.\sim\manifest\scripts\run_questa.ps1 fft_dma_reader
.\sim\manifest\scripts\run_questa.ps1 sample_bridge_and_ingest
.\sim\manifest\scripts\run_questa.ps1 aces_audio_to_fft_pipeline
.\sim\manifest\scripts\run_questa.ps1 top_level_i2s_fft_tx_diag
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
.\sim\manifest\scripts\run_questa.ps1 top_level_test
```

PowerShell GUI equivalents:

```powershell
.\sim\manifest\scripts\run_questa.ps1 i2s_fft_tx_adapter -Gui
.\sim\manifest\scripts\run_questa.ps1 fft_tx_i2s_link -Gui
.\sim\manifest\scripts\run_questa.ps1 hexa7seg -Gui
.\sim\manifest\scripts\run_questa.ps1 fft_dma_reader -Gui
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock -Gui
```

### Running from VS Code Remote WSL with Windows-installed tools

If your editor is attached to WSL but the actual Questa or ModelSim executables are installed only on Windows, run the usual POSIX wrappers from the WSL terminal:

```bash
sim/manifest/scripts/run_questa.sh hexa7seg
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/open_questa_gui.sh sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

On WSL, these `.sh` wrappers detect the missing Linux-side simulator binaries and forward to the matching `.ps1` launcher with:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& './sim/manifest/scripts/run_questa.ps1' 'top_level_test' 'mock'"
```

The same bridging pattern works for direct Quartus checks from the WSL terminal:

```bash
powershell.exe -NoProfile -Command "& 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe' --version"
```

If you need to force the Windows PowerShell path even when a Linux-side simulator is installed, export `ACES_USE_WINDOWS_POWERSHELL=1` before invoking the wrapper.

If you intentionally want to keep an existing simulator session open, call the PowerShell launcher directly with `-KeepExistingSessions`.

## Real-IP-Oriented Top-Level Run

The real-IP-oriented flow is currently defined for `top_level_test` and consumes the checked-in `submodules/R2FFT` sources directly, without requiring an extra FFT filelist command.

Example:

```bash
sim/manifest/scripts/run_questa.sh top_level_test real
```

PowerShell:

```powershell
.\sim\manifest\scripts\run_questa.ps1 top_level_test real
```

Use this when:

- you want the checked-in Quartus ROM wrapper,
- you want to exercise the checked-in `submodules/R2FFT` implementation,
- you want to keep the same repository-level testbench and packaging structure.

## Opening Questa GUI with Waves

The checked-in launcher is batch-oriented, but GUI review is still straightforward.

Typical manual flow:

```bash
mkdir -p sim/local/questa/manual_top_level
cd sim/local/questa/manual_top_level
vlib work
vmap work work
vlog -sv -f ../../../manifest/filelists/mock_integration_top_level_test.f
vsim work.tb_top_level_test
```

Then load a wave file from the Questa console, for example:

```tcl
do ../../../manifest/waves/tb_audio_frontend_integration
run -all
```

Convenience wrappers:

```bash
sim/manifest/scripts/open_questa_gui.sh sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

```powershell
.\sim\manifest\scripts\open_questa_gui.ps1 sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

From WSL, the same `open_questa_gui.sh` wrapper can be used; it forwards to `open_questa_gui.ps1` automatically when the GUI tools are available only on Windows.

For the supported manifest-driven tests, `run_questa.sh ... gui` is now the preferred path because it reuses the same compile flow, opens the correct top module, and auto-loads the matching wave `.do` file with the checkpoint signals used by the testbench assertions.

For unit and integration tests, substitute the matching filelist and wave file.

Equivalent ModelSim GUI wrappers are available:

```bash
sim/manifest/scripts/open_modelsim_gui.sh sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

```powershell
.\sim\manifest\scripts\open_modelsim_gui.ps1 sim/manifest/filelists/mock_integration_top_level_test.f tb_top_level_test
```

For FPGA build bring-up, the repository also includes a Quartus project entry point at `quartus/top_level_test.qpf`; its companion source manifest `quartus/top_level_test_sources.tcl` adds the active top-level RTL, the checked-in R2FFT submodule sources, and the required ROM/FFT `.qip` files and memory assignments.

## How Regression Works

In ACES, “regression” means running a defined set of named test targets from the manifest layer so that results are reproducible and share the same compile inputs.

A practical regression pattern is:

1. select the supported mock-flow tests,
2. run each through `run_questa.sh` or `run_questa.ps1`,
3. review failures by test name and run directory under `sim/local/questa/`.

Because all compile inputs are versioned, a regression failure should be attributable to source changes rather than hidden simulator state.

## Recommended Daily Workflow

1. Modify RTL or testbench code.
2. Run the smallest relevant unit test first.
3. Run the nearest integration test.
4. Open GUI and inspect waves only when the textual/pass-fail result is insufficient.
5. If sharing with others, regenerate the portable package after the flow is stable.

## Common Pitfalls

- Running `vlog` from arbitrary directories instead of from a manifest-driven flow.
- Mixing mock and real-IP files without an explicit filelist boundary.
- Treating `sim/local/` as source-controlled state.
- Forgetting to add a new testbench to a filelist.
- Loading the wrong wave `.do` file for the top-level under inspection.

## Related Reading

- [testbenches.md](testbenches.md)
- [portable_flow.md](portable_flow.md)
- [verification_methodology.md](verification_methodology.md)
- [faq.md](faq.md)
