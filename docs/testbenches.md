# Testbenches

## Testbench Layers

ACES uses layered verification assets under `tb/`.

| Directory | Intent |
| --- | --- |
| `tb/unit/` | Verify one module or a very tight contract. |
| `tb/integration/` | Verify composition across module boundaries. |
| `tb/mocks/` | Provide simulation-only mock implementations for self-contained flows. |

## Unit Testbenches

Unit benches should answer questions such as:

- does the receiver reconstruct samples correctly?
- does a width adapter preserve the expected truncation policy?
- does a stimulus block drive the expected I2S behavior?

Characteristics:

- narrow compile set,
- minimal dependencies,
- direct assertions close to the behavior being tested,
- fast debug turnaround.

Current examples in this repository:

- `tb_fft_tx_bridge_fifo` verifies aligned FIFO semantics for `(real, imag, last, bfpexp)`.
- `tb_i2s_fft_tx_adapter` verifies tagged I2S framing, hold frames, and serializer timing.

## Integration Testbenches

Integration benches should verify behavior across boundaries such as:

- stimulus generation plus receive-side reconstruction,
- CDC bridge plus FFT ingest,
- full ACES integration with a mock FFT model,
- top-level simulation wrapper plus ROM stimulus flow.

These tests validate contracts between modules rather than just local combinational correctness.

Current examples in this repository:

- `tb_aces_audio_to_fft_pipeline` verifies receive-side frontend composition.
- `tb_fft_tx_i2s_link` verifies burst-to-serial behavior across `fft_tx_bridge_fifo` and `i2s_fft_tx_adapter`.
- `tb_top_level_fft_isolated` verifies the real FFT control/readout path inside the top-level wrapper while isolating it from the rest of the end-to-end bench.

## Mock vs Real-IP Testbenches

### Mock flow
Use mock flow when you want:

- repository-contained simulation,
- reproducible bring-up,
- no dependency on external FFT collateral.

Mock flow typically compiles:

- `tb/mocks/r2fft_tribuf_impl_mock.sv`
- `tb/mocks/signals_rom_ip_mock.sv`

### Real-IP-oriented flow
Use real-IP-oriented flow when you want:

- the checked-in Quartus ROM wrapper,
- explicit binding to the checked-in `submodules/R2FFT` implementation,
- a stronger approximation of the vendor-IP-facing simulation environment.

The main real-IP-oriented debug bench currently used for FFT bring-up is:

- `tb_top_level_fft_isolated`

## Naming Conventions

Recommended conventions:

- unit benches: `tb_<module_name>.sv`
- integration benches: `tb_<subsystem_or_flow_name>.sv`
- mocks: `<module_name>_mock.sv` when the mock is intentionally distinct

Even when a mock binds the same module name as the real design block, keep the file name explicit so reviewers know it is simulation-only collateral.

## How to Create a New Testbench

1. Decide whether the scope is **unit** or **integration**.
2. Place the file in `tb/unit/` or `tb/integration/`.
3. Keep stimulus deterministic.
4. Prefer assertions over manual waveform-only checking.
5. Add a manifest filelist entry.
6. Add or update a waveform `.do` file if the test benefits from GUI review.
7. Update documentation if the new bench becomes part of the supported workflow.

## How to Add a Testbench to Filelists

Create or extend a filelist under `sim/manifest/filelists/`.

Guidelines:

- keep dependencies minimal,
- include mocks only when the flow is intended to be mock-based,
- keep real-IP flows in distinct filelists,
- avoid “kitchen sink” filelists that compile unrelated collateral.

## How to Create a Wave `.do` File

1. Compile and launch the test in Questa.
2. Add the signals that matter for debugging.
3. Organize them by hierarchy or function.
4. Save the wave setup into `sim/manifest/waves/`.
5. Give it a name that clearly matches the bench or debug scenario.

Good wave files reduce rework during collaborative debug because everyone starts from the same signal view.

## Testbench Authoring Best Practices

- Keep clocks explicit and easy to identify.
- Use readable localparams for widths, depths, and timing constants.
- Assert structural contracts, not just final outputs.
- When checking serialized interfaces, verify both data and framing behavior.
- Prefer deterministic ROM-backed or local-array-backed stimulus over opaque random behavior.
- Make failure messages specific enough that a headless run is still useful.
- Prefer fail-fast checks for manifest-supported regression benches so `run_questa.sh` can stop immediately on a real mismatch.
- Expose checkpoint counters or scoreboard state as plain testbench signals when possible so the matching wave `.do` file can show where each verification step occurs.
- Keep a bench-specific wave `.do` file under `sim/manifest/waves/` for supported tests, and organize it around verification checkpoints rather than raw hierarchy dumps.

## Related Reading

- [simulation.md](simulation.md)
- [verification_methodology.md](verification_methodology.md)
- [coding_guidelines.md](coding_guidelines.md)
- [testbench_report_tables.md](testbench_report_tables.md)
- [top_level_fft_diagnosis.md](top_level_fft_diagnosis.md)
