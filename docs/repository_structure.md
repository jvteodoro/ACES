# Repository Structure

## Why the Repository Is Split This Way

The ACES repository is intentionally divided into active source, executable verification assets, versioned simulation control data, and generated outputs. This keeps the project usable for daily development, easier to package, and safer for AI agents to modify.

## Top-Level Directories

| Path | Purpose | Versioned? |
| --- | --- | --- |
| `rtl/` | Active RTL modules and IP wrappers used by the maintained design/simulation flows. | Yes |
| `tb/` | Testbenches and simulation-only mock models. | Yes |
| `tools/` | Generated ROM collateral and other checked-in support artifacts needed by flows/documents. | Yes |
| `utils/` | Python utilities for signal generation and validation. | Yes |
| `docs/` | Human- and AI-facing project documentation. | Yes |
| `sim/manifest/` | Source-of-truth simulation manifests, scripts, and wave setups. | Yes |
| `sim/local/` | Disposable machine-local simulator outputs. | No, except placeholder keep file |
| `sim/portable/` | Generated redistribution packages and ZIP outputs. | No |

## `rtl/`

### `rtl/common/`
Shared reusable logic that is not specific to a single domain partition.

Examples:

- width adaptation,
- bridge logic,
- FFT control,
- DMA readout,
- display helpers.

### `rtl/frontend/`
Capture-side logic tied to the microphone/I2S interface.

Examples:

- I2S clock generation,
- I2S receive-side sample reconstruction.

### `rtl/stimulus/`
Stimulus-generation logic used to emulate microphone behavior deterministically during simulation.

Examples:

- generic ROM-backed I2S playback manager,
- ROM-IP-backed multi-example stimulus generator.

### `rtl/core/`
Higher-level assemblies and integration wrappers.

Examples:

- the ACES integration itself,
- pipeline composition,
- simulation-oriented top-level wrappers.

### `rtl/ip/`
Vendor/IP-facing wrappers and collateral that belong to the repository.

- `rtl/ip/fft/`: FFT-adjacent helper IP collateral.
- `rtl/ip/rom/`: Quartus-generated ROM wrappers and related files.

## `tb/`

### `tb/unit/`
Small-scope tests for one module or one narrowly scoped contract.

### `tb/integration/`
Subsystem and end-to-end tests that exercise multiple modules together.

### `tb/mocks/`
Mock implementations that keep local simulation self-contained.

This split matters because contributors should not have to guess whether a file is production RTL or simulation scaffolding.

## `sim/`

### `sim/manifest/`
This is the versioned simulation control plane.

Contents:

- `filelists/`: named compile manifests,
- `scripts/`: launcher, batch, GUI, packaging, or regression helpers,
- `waves/`: checked-in waveform `.do` files.

### `sim/local/`
This directory is intentionally disposable.

Examples of what belongs here:

- Questa `work/` libraries,
- `transcript` files,
- WLF databases,
- temporary compile or run directories.

Do not treat anything under `sim/local/` as source of truth.

### `sim/portable/`
This directory is for generated handoff artifacts.

Typical contents:

- an assembled package directory,
- a ZIP file for redistribution.

The portable directory is generated from the manifest, not edited manually.

## Why the Separation Exists

### Reproducibility
A checked-in filelist or Tcl script is reviewable and deterministic. A local `work/` library is not.

### Clean collaboration
New engineers and AI agents can find active design files without sorting through stale simulator outputs.

### Safe packaging
A portable package should be generated from known sources, not by copying a developer’s ad hoc working directory.

### Explicit mock/real boundaries
The split between manifest and generated outputs makes it clearer which simulation assets are authoritative and which are just runtime products.

## Related Reading

- [overview.md](overview.md)
- [simulation.md](simulation.md)
- [portable_flow.md](portable_flow.md)
- [development_guide.md](development_guide.md)
