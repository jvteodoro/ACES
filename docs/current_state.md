# ACES Current State and Rationale

## Why this document exists

ACES changed substantially from an earlier "board bring-up first" codebase into a repository that is organized around explicit contracts, reproducible verification, and a documented host-side integration path.

This document is not a commit-by-commit changelog. Instead, it records the major architectural and workflow changes that define the current repository state, why they were made, and what they imply for future work.

## The current repository model

The repository now treats ACES as a full signal-path project with 3 equally important parts:

1. synthesizable RTL and board-facing top-level logic,
2. reproducible simulation and verification assets, and
3. host-side software that consumes the FPGA FFT stream.

That shift matters because the project is no longer "just the FPGA design." The hardware, the simulation environment, and the host receiver now form a single documented system.

## Major changes and rationale

### 1. The repository was reorganized around intent

Current layout is centered on:

- `rtl/` for active maintained RTL,
- `tb/` for executable verification assets,
- `sim/manifest/` for versioned simulation control data,
- `docs/` for human and AI orientation,
- `submodules/` for explicit external dependencies and related host-side components.

Rationale:

- active design files should not be mixed with generated simulator output,
- collaborators need a stable source of truth for simulation,
- packaging and review are safer when path intent is obvious,
- AI-assisted maintenance becomes far less error-prone when active versus generated material is explicit.

### 2. Mock and real-IP-oriented FFT flows became explicit first-class modes

The project now distinguishes clearly between:

- a self-contained mock verification flow, and
- a real-IP-oriented flow using checked-in `submodules/R2FFT` sources plus repository-owned Quartus collateral.

Rationale:

- the previous style of silently mixing assumptions from mock and real setups made failures difficult to interpret,
- contributors need a fast local loop that works without vendor collateral,
- handoff and integration work still need a path that reflects the real FFT stack.

### 3. The FFT output path was promoted into a documented protocol

The transmit side now has an explicit architecture:

```text
FFT core
  -> fft_dma_reader
  -> TX FIFO / bridge bookkeeping
  -> i2s_fft_tx_adapter
  -> tagged I2S stream for external host
```

Important protocol properties:

- FFT output is exported as left=`real`, right=`imag`,
- a `BFPEXP` announcement precedes each FFT window,
- payload type is encoded in-band with tags,
- the serializer is intentionally lightweight and relies on upstream buffering.

Rationale:

- the host side cannot be robust unless the FPGA stream contract is explicit,
- transport framing had to become part of the design, not an implicit waveform convention,
- the serializer and the buffering boundary needed separate verification targets.

### 4. The DMA/readout behavior was aligned with the real FFT core contract

The integration now reflects the actual triple-buffered read visibility of `R2FFT_tribuf`.

Rationale:

- readout timing assumptions that seem harmless in a mock model can be wrong against the real FFT implementation,
- failures in the full top-level bench were traced to integration assumptions rather than the FFT core itself,
- the project needed benches and docs that describe the real "done then next run" visibility pattern.

### 5. `top_level_test` became the maintained board-oriented integration wrapper

The active top-level is no longer just a convenient wrapper. It is the board-facing integration point for:

- stimulus/debug control,
- FFT pipeline observation,
- tagged I2S export to an external host,
- GPIO-based debug selection and output capture.

Rationale:

- top-level debug had to become scriptable and externally observable,
- the same top-level needs to support simulation diagnosis and board-oriented wiring,
- the debug strategy had to move away from ad hoc local assumptions and into documented stage/page selection.

### 6. Host-side FFT reception on Raspberry Pi became a maintained interface

The `submodules/ACES-RPi-interface/rpi3b_i2s_fft/` package is now part of the supported system story.

Current role:

- receive the FPGA I2S FFT stream,
- decode tagged or raw framing modes,
- derive FFT magnitude and MFCC-like features,
- save reference windows,
- compare live history against a recorded event,
- visualize saved FFT history.

Rationale:

- a hardware stream is only useful if there is a maintained consumer contract,
- the old host scripts were too tied to ad hoc execution and difficult to validate without hardware,
- the repository needed a bridge between "serializer works in sim" and "system works on a host."

### 7. Offline Python regression was added so host behavior can be validated without Pi + FPGA

The host-side package now includes an offline regression suite under `submodules/ACES-RPi-interface/tests/`.

Covered areas include:

- tagged I2S word decoding,
- frame start and re-synchronization behavior,
- raw frame extraction,
- analyzer buffer and snapshot logic,
- CSV logger formatting,
- headless plotting,
- comparison helper math.

Rationale:

- hardware-only validation is too slow for parser and buffer logic changes,
- protocol bugs should be caught before board bring-up,
- the host receiver needed a testable contract that mirrors the RTL framing model.

## Current source of truth by concern

### Hardware protocol

Primary references:

- `rtl/frontend/i2s_fft_tx_adapter.sv`
- `rtl/core/aces.sv`
- `docs/i2s_fft_tx_adapter.md`
- `docs/architecture.md`

### Simulation control

Primary references:

- `sim/manifest/filelists/`
- `sim/manifest/scripts/`
- `docs/simulation.md`
- `docs/testbenches.md`

### Host-side receiver and analysis

Primary references:

- `submodules/ACES-RPi-interface/rpi3b_i2s_fft/README.md`
- `submodules/ACES-RPi-interface/rpi3b_i2s_fft/fpga_fft_adapter.py`
- `submodules/ACES-RPi-interface/tests/`

### Historical context for recent FFT-path fixes

Primary references:

- `docs/top_level_fft_diagnosis.md`
- `docs/quartus_root_project_sync.md`

## What changed in day-to-day development workflow

### Before

Typical workflow depended heavily on:

- manually reasoning from board behavior,
- debugging broad top-level failures,
- inferring protocol details from RTL or waveforms,
- validating host scripts mainly on live hardware.

### Now

Recommended workflow is:

1. change the smallest relevant RTL or Python unit,
2. run the nearest HDL bench or offline Python regression,
3. check protocol docs if framing or timing changed,
4. run top-level or real-IP-oriented simulation if the change crosses boundaries,
5. use Raspberry Pi + FPGA only after the offline/simulation path is green.

## Design consequences for future contributors

### If you change the tagged stream format

You must review all of the following together:

- `rtl/frontend/i2s_fft_tx_adapter.sv`,
- `docs/i2s_fft_tx_adapter.md`,
- `submodules/ACES-RPi-interface/rpi3b_i2s_fft/fpga_fft_adapter.py`,
- the offline receiver tests under `submodules/ACES-RPi-interface/tests/`.

### If you change FFT width, ordering, or exponent handling

You must review:

- FFT readout path docs,
- Python-side magnitude/exponent interpretation,
- any numerical validation logic that assumes the current payload layout.

### If you change repository structure

You must review:

- `README.md`,
- `docs/repository_structure.md`,
- `docs/overview.md`,
- any simulation/package docs that reference the moved paths.

## What is still intentionally not solved purely offline

Even with the new regression coverage, some questions still require hardware or full HDL simulation:

- real ALSA buffering and timing behavior on Raspberry Pi,
- GPIO electrical timing and level behavior,
- final Quartus image wiring and board pinout,
- cross-checking serializer behavior against the real external clocking environment.

That is intentional. The goal is not to replace board bring-up entirely; it is to move as much correctness checking as possible earlier in the workflow.

## Recommended reading order for the current repository

1. `README.md`
2. `docs/current_state.md`
3. `docs/overview.md`
4. `docs/architecture.md`
5. `docs/i2s_fft_tx_adapter.md`
6. `submodules/ACES-RPi-interface/rpi3b_i2s_fft/README.md`

