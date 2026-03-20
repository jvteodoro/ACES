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

## I get an IP-not-found or module-not-found error

### Likely causes
- mock filelist used without the required mock file,
- real-IP filelist used without extra FFT collateral,
- vendor/IP wrapper expected but not compiled.

### What to do
- for self-contained runs, use a mock-flow filelist,
- for real-IP-oriented top-level runs, provide `EXTRA_FILELIST=/path/to/r2fft_real.f` on POSIX shells or `$env:EXTRA_FILELIST='C:\path\to\r2fft_real.f'` on PowerShell,
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
- if they need real-IP-oriented simulation, send the extra FFT collateral instructions explicitly.

## Which docs should a new engineer read first?

Recommended order:

1. [overview.md](overview.md)
2. [repository_structure.md](repository_structure.md)
3. [simulation.md](simulation.md)
4. [testbenches.md](testbenches.md)
5. [development_guide.md](development_guide.md)
