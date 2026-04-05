# FAQ

## Questa says files cannot be found during compile

### Likely causes
- running from the wrong working directory,
- using a manual `vlog` command that does not match the manifest,
- filelist paths not matching the package/repo root you are using.

### What to do
- prefer `sim/manifest/scripts/run_questa.sh <test> [mock|real]` on POSIX shells or `sim/manifest/scripts/run_questa.ps1 <test> [mock|real]` on PowerShell,
- if using a portable package, run from the package root and use either `scripts/run_questa.sh ...` or `.\scripts\run_questa.ps1 ...`,
- verify the filelist path you selected matches the intended flow.

## I am in VS Code WSL, but Questa or Quartus is installed only on Windows

### What to do
- keep using the checked-in `.sh` wrappers from the WSL terminal,
- `run_questa.sh`, `run_modelsim.sh`, `open_questa_gui.sh`, and `open_modelsim_gui.sh` auto-forward to the matching `.ps1` launcher through `powershell.exe` when the Linux-side simulator binaries are absent,
- if needed, you can invoke the PowerShell entry point manually with `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& './sim/manifest/scripts/run_questa.ps1' 'top_level_test' 'mock'"`,
- for direct Quartus checks from WSL, invoke the Windows executable through PowerShell, for example `powershell.exe -NoProfile -Command "& 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe' --version"`,
- if both Linux and Windows tool installs exist and you want to force the Windows route, export `ACES_USE_WINDOWS_POWERSHELL=1` before running the wrapper,
- batch PowerShell launchers stop existing `vsim` and `vsimk` processes before starting a new run so a single-seat license can be reused,
- if you need to keep a simulator session open intentionally, launch the PowerShell wrapper with `-KeepExistingSessions`.

## I get an IP-not-found or module-not-found error

### Likely causes
- mock filelist used without the required mock file,
- real-IP filelist used without the `submodules/R2FFT` checkout initialized,
- vendor/IP wrapper expected but not compiled.

### What to do
- for self-contained runs, use a mock-flow filelist,
- for real-IP-oriented top-level runs, make sure `submodules/R2FFT` is initialized and then run the standard `top_level_test real` launcher,
- verify that the ROM or FFT module name being bound matches the chosen flow.

## What about `msim_setup.tcl`?

This repository does not currently rely on a checked-in Quartus-generated `msim_setup.tcl` as the primary simulation control plane.

Instead, the maintained source of truth is:

- `sim/manifest/filelists/`
- `sim/manifest/scripts/`
- `sim/manifest/waves/`

If you receive vendor-generated helper Tcl from outside the repo, treat it as external collateral and document how it interacts with the real-IP flow before depending on it.

## Simulation runs but does not progress

### Likely causes
- testbench start signal was never asserted,
- clock generation did not start,
- the wrong top-level bench was launched,
- the DUT is waiting on startup or framing conditions that were never met.

### What to do
- confirm the selected test target maps to the expected top module,
- inspect clocks and reset first,
- verify any stimulus manager startup conditions and `chipen`/`ws`/`sck` behavior,
- load the corresponding wave `.do` file for quick inspection.

## The waveforms look wrong

### Likely causes
- wrong wave `.do` loaded for the current test,
- mock flow vs real-IP-oriented flow mismatch,
- sample-framing or CDC contract violation.

### What to do
- load the wave file that matches the active bench,
- confirm the expected top-level hierarchy name,
- inspect valid pulses, framing signals, and address/index sequencing before chasing numerical output.

## I see timing-style mismatches in simulation

ACES uses event-sensitive interfaces where pulse width and ordering matter. A timing mismatch may actually be a functional bug.

Check:

- one-cycle valid pulses,
- `WS` transition handling,
- CDC duplication or lost-event behavior,
- FFT bin ordering and `last` signaling.

## The portable package does not run on another machine

### Likely causes
- Questa is not installed,
- the recipient used the wrong package root,
- a real FFT filelist was required but not supplied.

### What to do
- confirm the recipient is running from the unpacked package root,
- have them try a mock-flow test first,
- if they need real-IP-oriented simulation, make sure the package includes the initialized `submodules/R2FFT` checkout.

## Which docs should a new engineer read first?

Recommended order:

1. [overview.md](overview.md)
2. [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
3. [repository_structure.md](repository_structure.md)
4. [simulation.md](simulation.md)
5. [testbenches.md](testbenches.md)
6. [development_guide.md](development_guide.md)
