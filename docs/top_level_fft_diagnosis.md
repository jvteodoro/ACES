# Top-Level FFT Integration Diagnosis

## Why this document exists

The real-IP-oriented `top_level_test` flow exposed FFT-side integration failures even though `i2s_rx_adapter_24` had already been validated on hardware and was therefore treated as correct.

This document captures what was wrong, what was changed, what evidence was gathered, and what verification work still remains so contributors do not have to rediscover the same integration details.

## Scope boundary

The receive-side I2S reconstruction block was intentionally **not** changed during this investigation:

- `rtl/frontend/i2s_rx_adapter_24.sv`

The working assumption, backed by board validation, is that any mismatch observed in the real top-level flow should first be explained by the testbench, control logic, DMA readout, or transmit-side integration before touching `i2s_rx_adapter_24`.

## Initial symptoms

The first symptoms observed during the real-IP-oriented top-level bring-up were:

- `top_level_test real` compiled, but FFT bins read from the integrated path were zero or numerically wrong.
- Earlier top-level checks counted FFT output using assumptions that did not match the real `i2s_fft_tx_adapter` contract.
- The original failing behavior was hard to localize because receive, FFT, DMA, FIFO, and tagged I2S TX were all active in the same bench.
- After the FFT-side fixes, the full-system bench still failed later in the run with `tx_overflow_o`, even though the isolated FFT path was already producing correct bins.

## Root causes that were identified

### 1. `fft_control` assumed a continuous stream-valid level

The ACES receive pipeline does **not** hold `sact_istream_o` high for an entire FFT frame. It emits a one-cycle pulse per accepted sample.

The previous `fft_control` behavior only worked reliably when `sact_istream_i` stayed asserted long enough to carry state implicitly. In the real flow, that assumption was wrong. Once a frame had started, the controller needed to stay in the ingest state until the FFT input buffer reported full.

What changed:

- `rtl/common/fft_control.sv` now remains in `FFT_ISTREAM` until `status == S_FBUFFER`.
- `run` is produced as a single-cycle consequence of the explicit `FFT_FULL` state.
- `tb/unit/tb_fft_control.sv` was updated to check the pulse-based contract.

### 2. `fft_dma_reader` used the wrong read protocol for `R2FFT_tribuf`

The checked-in `submodules/R2FFT` implementation uses triple buffering. The important consequence is that the FFT result for frame `N` is not immediately readable when `done` for frame `N` rises. The output becomes DMA-visible only after the next `run` rotates the buffers.

The previous DMA reader was therefore wrong in two ways:

- it started reading on the `done` pulse of the same frame,
- it held `dmaact` high continuously instead of issuing address-by-address pulses with read latency.

What changed:

- `rtl/common/fft_dma_reader.sv` now arms on `done_i`,
- it waits for the next `run_i` pulse before starting the readout,
- it issues pulsed DMA requests and waits `READ_LATENCY` cycles before capture,
- `tb/unit/tb_fft_dma_reader.sv` was updated to reflect the real timing contract.

### 3. The diagnosis needed a bench that isolated the FFT path

The full `top_level_test` bench was too broad to answer a simple question: "is the FFT path itself wrong, or is the failure caused elsewhere in the top-level composition?"

To answer that, a new integration bench was added:

- `tb/integration/tb_top_level_fft_isolated.sv`

This bench:

- instantiates the real top-level wrapper,
- forces samples directly into the FFT ingress path,
- observes `fft_control`, `run`, `done`, DMA activity, and intermediate status signals,
- performs both the automatic top-level DMA read and a manual DMA read that mimics the usage pattern from the original R2FFT author testbenches,
- compares both readout paths against expected FFT results.

### 4. The expected FFT data needed to come from the same ROM-generation flow used by the project

To avoid checking the hardware against stale or hand-built vectors, the expected data was tied back to the repository's Python generation flow.

Artifacts added for this purpose:

- `utils/export_top_level_test_expectations.py`
- `tb/data/top_level_test_expected_samples.csv`
- `tb/data/top_level_test_expected_fft.csv`
- `tb/data/top_level_test_expected_meta.txt`

The expectation exporter uses the same signal-generation configuration as the current ROM flow, models the RTL I2S loopback path, performs the same `24 -> 18` truncation used before the FFT, and writes reproducible CSVs for the benches to consume.

That gives contributors traceability from:

1. Python stimulus generation,
2. current ROM contents,
3. expected time-domain samples at the FFT input,
4. expected frequency-domain bins.

### 5. The full-system top-level bench was still allowing extra FFT windows after the intended check window

Once the FFT control path and DMA reader were corrected, the remaining end-to-end failure moved to the transmit side of the full `top_level_test` bench.

The problem was not in the production RTL. The bench kept feeding additional audio windows after the scoreboard had already committed to checking a bounded number of FFT frames. In the real triple-buffer contract, the first completed FFT frame only becomes readable after the next `run`, so stopping stimulus too early breaks the readout, but allowing it to run forever eventually overfills the transmit path.

What changed in the bench:

- `tb/integration/tb_top_level_test.sv` now counts `fft_run_o` pulses per example.
- The bench waits until the **second** `fft_run_o` before suppressing additional ingest windows.
- The suppression is applied at the ACES audio-to-FFT pipeline boundary used by the testbench, instead of changing the FFT core behavior.
- The tagged-I2S checks were aligned with the real `i2s_fft_tx_adapter` contract, and the final TX clock activity check now counts toggles across the whole test instead of just the final reset interval.

This was the missing piece that allowed the integrated real-IP flow to finish cleanly.

## Files changed during this diagnosis

Core fixes:

- `rtl/common/fft_control.sv`
- `rtl/common/fft_dma_reader.sv`
- `rtl/core/aces.sv`

Updated or new verification collateral:

- `tb/unit/tb_fft_control.sv`
- `tb/unit/tb_fft_dma_reader.sv`
- `tb/integration/tb_top_level_fft_isolated.sv`
- `sim/manifest/filelists/real_ip_top_level_fft_isolated.f`
- `sim/manifest/waves/tb_top_level_fft_isolated.do`
- `sim/manifest/scripts/run_questa.tcl`

Expectation-generation support:

- `utils/export_top_level_test_expectations.py`
- `tb/data/top_level_test_expected_samples.csv`
- `tb/data/top_level_test_expected_fft.csv`
- `tb/data/top_level_test_expected_meta.txt`

## Evidence collected so far

The following commands were used as checkpoints:

```bash
sim/manifest/scripts/run_questa.sh fft_control mock
sim/manifest/scripts/run_questa.sh fft_dma_reader mock
sim/manifest/scripts/run_questa.sh top_level_fft_isolated real
sim/manifest/scripts/run_questa.sh top_level_test real
```

Observed status after the FFT-path fixes and the final top-level bench correction:

- `fft_control mock`: passes with the pulse-based ingest behavior.
- `fft_dma_reader mock`: passes with the "done then next run" read protocol.
- `top_level_fft_isolated real`: passes and shows that the corrected automatic DMA path matches the manual readout pattern and the expected FFT within the bench tolerances.
- `top_level_test real`: passes with 8 checked examples, FFT-vs-Python comparison enabled, and no extra FFT or serial frames beyond the intended scoreboarding window.
- `top_level_test mock`: passes as a smoke/protocol check for the repository-contained flow.

The isolated bench was the key proof point: it showed that the corrected FFT control and DMA integration were functional before the full-system bench was tightened around the real TX/readout contract.

## Current project status

What is considered understood:

- `i2s_rx_adapter_24` remains outside the scope of the fix and is still treated as trusted.
- The main "FFT returns zeros" issue was caused by ACES-side integration logic, not by the R2FFT core itself.
- The real triple-buffer timing of `R2FFT_tribuf` is now reflected in the ACES DMA readout logic.
- The project now has a dedicated real-IP-oriented FFT isolation bench and matching wave setup.
- The project now also has a full `top_level_test` bench that passes in both `real` and `mock` modes using the checked-in expectation data derived from the Python stimulus generation flow.

What is still open:

- The broader regression picture still needs to be kept up to date as individual module benches evolve.
- At least one existing unit bench, `tb_i2s_rx_adapter_24`, can still report mismatches against its current checker even though the module is treated as trusted from hardware validation.
- Contributors should therefore distinguish carefully between "module bug" and "bench/checker mismatch" when expanding the regression set.

## Current verification checkpoint

At the end of this investigation, the high-value end-to-end checks are:

- `top_level_test mock`: passing
- `top_level_test real`: passing
- `top_level_fft_isolated real`: passing
- `fft_control mock`: passing
- `fft_dma_reader mock`: passing

This means the top-level FFT ingest, control, DMA readout, and tagged-I2S transmit path are now covered by both isolated and end-to-end benches.

That does **not** yet mean every repository bench is clean. The remaining task is broader regression hygiene across all supported module benches, especially older tests whose assumptions may predate the current integrated flow.

## Mock regression snapshot

The supported `sim/manifest/scripts/regression_mock.sh` sweep was rerun after the top-level fixes. The current snapshot is:

Passing benches:

- `hexa7seg`
- `sample_width_adapter_24_to_18`
- `fft_control`
- `fft_dma_reader`
- `fft_tx_bridge_fifo`
- `i2s_fft_tx_adapter`
- `fft_tx_i2s_link`
- `aces`
- `top_level_test` in `mock` mode

Failing benches that still need triage:

- `i2s_rx_adapter_24`: the checker currently reports `idx=3 esperado=0x400000 obtido=0xc00000`
- `i2s_master_clock_gen`: the checker reports `SCK mudou fora do divisor esperado: 3`
- `i2s_stimulus_manager_rom`: the checker reports `addr=11 exp=0x123453 got=0x923453`
- `aces_audio_to_fft_pipeline`: the checker reports `sample_mic mismatch idx=1`

The first and fourth failures should be interpreted carefully because they exercise logic downstream of the receive-side path that was intentionally treated as trusted from board validation. A failing bench in that area does not automatically imply a defect in the production RTL.

## Recommended next steps

1. Run the supported mock regression regularly and record which failures are true RTL issues versus outdated bench assumptions.
2. Review `tb_i2s_rx_adapter_24`, `tb_i2s_stimulus_manager_rom`, and `tb_aces_audio_to_fft_pipeline` together, because they likely share assumptions about signed sample reconstruction and serialized receive-side expectations.
3. Review `tb_i2s_master_clock_gen` against the current divider contract before changing the RTL, because its failure may also be a stale expectation rather than a hardware bug.
4. Keep `tb_top_level_fft_isolated` in the regression toolbox so future contributors can tell quickly whether a failure belongs to the FFT path or to the surrounding top-level glue.
5. Regenerate the expectation CSVs whenever the ROM-generation flow changes, so the benches continue to compare against the actual repository stimulus set.
6. Preserve the "second `run` before gate-off" rule in `tb_top_level_test`; removing it reintroduces a false failure against the real triple-buffer timing contract.

## Related reading

- [Simulation guide](simulation.md)
- [Testbench guide](testbenches.md)
- [Verification methodology](verification_methodology.md)
- [I2S FFT TX adapter](i2s_fft_tx_adapter.md)
