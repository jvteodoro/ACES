# Development Guide

## Purpose

This guide describes the expected workflow for extending ACES without breaking the simulation architecture that was introduced in the refactor.

## Adding a New RTL Module

### Step 1: choose the correct directory
Place the module according to its responsibility:

- `rtl/common/` for shared logic,
- `rtl/frontend/` for receive-side microphone/I2S logic,
- `rtl/stimulus/` for deterministic stimulus generation,
- `rtl/core/` for top-level composition and pipeline integration,
- `rtl/ip/` only for vendor/IP-facing collateral.

### Step 2: define a narrow interface
Prefer small, stage-oriented module boundaries over wide monolithic interfaces.

### Step 3: document assumptions
If the module introduces any non-obvious timing, width, or control rule, update:

- [architecture.md](architecture.md),
- [coding_guidelines.md](coding_guidelines.md),
- and the relevant testbench documentation if it changes how users run the repo.

## Integrating a Module into ACES

When connecting a new block into the pipeline:

1. identify the upstream/downstream contract,
2. preserve existing invariants unless the change is intentional,
3. update the nearest integration wrapper,
4. ensure the testbench scope still makes sense.

Common integration points:

- between width adaptation and CDC,
- between CDC and FFT ingest,
- downstream of FFT DMA readout,
- alongside stimulus/control infrastructure.

## Creating a New Testbench

### Unit testbench flow
1. add the bench to `tb/unit/`,
2. keep dependencies minimal,
3. add focused assertions,
4. create a dedicated filelist if needed.

### Integration testbench flow
1. add the bench to `tb/integration/`,
2. decide whether it is mock or real-IP-oriented,
3. include only the dependencies needed for the scenario,
4. create/update wave setup if GUI review is useful.

## Registering the Testbench in Filelists

Create or update a filelist under `sim/manifest/filelists/`.

Checklist:

- include the active RTL dependencies,
- include mocks only if the flow is intentionally mock-based,
- confirm the top-level bench name matches the launcher mapping,
- keep comments in real-IP filelists when extra collateral is expected.

## Creating Wave Scripts

After running the bench interactively in Questa:

1. add signals by function,
2. keep the hierarchy readable,
3. save the `.do` file in `sim/manifest/waves/`,
4. name it so reviewers can identify the scenario quickly.

## Running Simulation During Development

Recommended order:

1. run the smallest unit test first,
2. run the nearest integration test,
3. inspect waves only when needed,
4. regenerate the portable package only after the flow is stable.

## Best Practices

- Keep mock and real-IP flows separate at the filelist level.
- Do not store generated simulator output in versioned directories.
- Keep testbenches deterministic unless randomness is specifically justified and controlled.
- Update documentation when you add a new supported workflow.
- Preserve backward-readable signal naming so waveform debugging remains efficient.

## Checklist for a Typical Change

- [ ] RTL module added in the correct directory.
- [ ] Unit or integration testbench added/updated.
- [ ] Filelist updated.
- [ ] Wave setup updated if useful.
- [ ] Docs updated if the public workflow changed.
- [ ] Portable packaging still makes sense after the change.

## Related Reading

- [simulation.md](simulation.md)
- [testbenches.md](testbenches.md)
- [coding_guidelines.md](coding_guidelines.md)
- [verification_methodology.md](verification_methodology.md)
