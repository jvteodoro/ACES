# Coding Guidelines

## Goals

These guidelines are intended to keep ACES readable, maintainable, and simulation-friendly for both engineers and AI agents.

## SystemVerilog Style

### Prefer small modules with explicit contracts
A module should have one primary responsibility. Avoid mixing capture logic, CDC logic, control, and packaging behavior in one block unless there is a strong reason.

### Use `logic` and typed params consistently
Prefer explicit width declarations and typed parameters so interface intent is visible in code review.

### Keep clock/reset style obvious
- Name clocks by domain when possible.
- Make reset polarity explicit in signal names or module comments.
- Avoid ambiguous multi-domain always blocks.

### Use `localparam` for internal protocol constants
Protocol state names, width-derived constants, and finite-state-machine literals should be expressed clearly.

## Naming Conventions

### Module names
Use descriptive snake_case names matching function, for example:

- `i2s_rx_adapter_24`
- `sample_bridge_to_fft_clk`
- `fft_dma_reader`

### Signal names
Use suffixes to communicate role:

- `_i` for input,
- `_o` for output,
- `_dbg_o` for debug outputs,
- `_valid` or `_valid_o` for event/data validity,
- `_real` / `_imag` for complex datapaths.

### Domain-aware signal naming
For DSP pipelines, domain names matter. Prefer names that reveal origin or destination where ambiguity exists, such as:

- `mic_sck_i`
- `fft_sample_valid_o`
- `sact_istream_o`

## Module Boundary Guidelines

- Keep CDC boundaries explicit.
- Keep width adaptation separate from reconstruction logic.
- Keep FFT-control decisions separate from ingest data formatting where practical.
- Do not hide simulation-only behavior inside active production modules unless it is clearly documented.

## Testbench Style

- Put unit benches in `tb/unit/` and integration benches in `tb/integration/`.
- Use deterministic clocks and deterministic stimulus.
- Prefer scoreboard-style checks and assertions over manual inspection.
- Print failure messages that identify the violated contract clearly.

## Assertions

Assertions are strongly encouraged for:

- one-cycle pulse requirements,
- ordering constraints,
- range or count limits,
- interface contract violations,
- sample/value mismatches.

Good assertions should explain:

- what failed,
- which index/cycle/condition was involved,
- why the failure matters.

## Filelist and Flow Hygiene

- Keep filelists narrow and intentional.
- Do not add unrelated source files “just to make compile pass.”
- Keep mock and real-IP flows distinct.
- If a module requires vendor collateral, document it in the relevant filelist and docs.

## Documentation Expectations

When a change affects public workflow or core architecture, update the corresponding doc pages under `docs/`.

## Related Reading

- [development_guide.md](development_guide.md)
- [architecture.md](architecture.md)
- [verification_methodology.md](verification_methodology.md)
