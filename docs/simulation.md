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

### Waveform setups
Waveform `.do` files live under `sim/manifest/waves/`.

These are checked in so that waveform review can be shared instead of recreated manually.

## Running a Testbench in Batch Mode

From the repository root:

```bash
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
sim/manifest/scripts/run_questa.sh top_level_test mock
sim/manifest/scripts/run_questa.sh top_level_test
```

Windows PowerShell equivalents:

```powershell
.\sim\manifest\scripts\run_questa.ps1 hexa7seg
.\sim\manifest\scripts\run_questa.ps1 i2s_rx_adapter_24
.\sim\manifest\scripts\run_questa.ps1 fft_control
.\sim\manifest\scripts\run_questa.ps1 fft_dma_reader
.\sim\manifest\scripts\run_questa.ps1 sample_bridge_and_ingest
.\sim\manifest\scripts\run_questa.ps1 aces_audio_to_fft_pipeline
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
.\sim\manifest\scripts\run_questa.ps1 top_level_test
```

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

For unit and integration tests, substitute the matching filelist and wave file.

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
