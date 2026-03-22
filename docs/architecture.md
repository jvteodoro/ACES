# ACES Architecture

## System View

ACES is built as a staged audio-to-FFT pipeline. Each stage has a deliberately narrow contract so that verification can focus on data correctness, pulse timing, and domain boundaries instead of debugging a monolithic top-level.

```text
I2S source (real mic or stimulus ROM)
    -> I2S reconstruction
    -> width adaptation
    -> CDC / event transfer
    -> FFT ingest stream
    -> FFT core integration
    -> DMA-style FFT readout
```

## Major Blocks

### 1. I2S frontend
Primary frontend logic lives under `rtl/frontend/`.

Responsibilities:

- generate or receive I2S framing signals,
- sample serial microphone data at the correct edge,
- identify the active channel slot,
- rebuild 24-bit signed samples.

Relevant modules:

- `i2s_master_clock_gen`
- `i2s_rx_adapter_24`

### 2. Sample reconstruction
`i2s_rx_adapter_24` reconstructs a signed 24-bit sample from serial I2S data.

Expected behavior:

- sample only on the intended slot transition,
- respect the one-bit I2S delay,
- shift MSB-first,
- emit exactly one sample-valid event per complete sample.

### 3. 24-bit to 18-bit truncation
`sample_width_adapter_24_to_18` adapts the audio-width frontend result into the FFT-width datapath.

Current design rule:

```text
sample_18 = sample_24[23:6]
```

This is a truncation policy, not a rounding policy.

### 4. CDC bridge / event transfer
ACES contains explicit bridge logic for transferring sample events into the FFT/system clock domain.

Key concerns:

- sample data must not be counted twice,
- destination-domain valid pulses must be one-shot pulses,
- source-domain activity must remain inspectable in simulation.

Relevant modules:

- `sample_bridge_to_fft_clk`
- `aces_audio_to_fft_pipeline`
- `aces_fft_ingest`

### 5. FFT ingest
The FFT ingest layer converts received sample events into the stream-style interface expected by the FFT integration logic.

Responsibilities:

- align valid and data,
- drive real data with the sampled value,
- drive imaginary data to zero unless a more complex source is introduced later,
- enforce one-cycle ingest strobes.

### 6. FFT core integration
The repository supports two conceptual FFT execution modes:

- **mock FFT flow** for local reproducible simulation,
- **real-IP-oriented flow** where the real FFT implementation is supplied explicitly.

The active ACES integration module instantiates `r2fft_tribuf_impl`, but the repository intentionally treats the actual FFT implementation as swappable collateral depending on the simulation flow.

### 7. DMA-style FFT reader
`fft_dma_reader` converts FFT completion into a structured bin-readout sequence.

Responsibilities:

- trigger DMA-style address stepping after FFT completion,
- capture returned real/imaginary data,
- emit bin-valid/index/last information,
- provide a clean handoff point for future serial streaming or file logging.

## Data Flow in More Detail

### Frontend path
1. The I2S source provides `SCK`, `WS`, and `SD` behavior.
2. `i2s_rx_adapter_24` reconstructs a signed 24-bit sample.
3. `sample_width_adapter_24_to_18` truncates the sample to FFT width.
4. Pipeline logic synchronizes the event into the FFT-side domain.
5. `aces_fft_ingest` or equivalent logic presents a one-cycle valid strobe to the FFT input.

### FFT/output path
1. FFT control logic observes ingest status.
2. The FFT core fills its input buffer and processes the transform.
3. Completion triggers `fft_dma_reader`.
4. Bins are read sequentially and exposed with index/valid metadata.

## Timing Considerations

### I2S timing
The I2S side is edge-sensitive. Verification must care about:

- `WS` transitions that identify the correct slot,
- the one-bit I2S delay,
- bit ordering,
- the relationship between serial clocks and the system clock used elsewhere.

### CDC timing
Where the source domain and FFT/system domain differ, the repository treats event transfer explicitly. Tests should verify that:

- a source event produces at most one destination event,
- destination pulses do not stretch across multiple cycles,
- sample data remains coherent with the valid pulse.

### FFT ingest timing
The FFT-side stream interface is timing-sensitive because each asserted valid pulse is interpreted as a new sample. A duplicated or stretched pulse is therefore a functional bug, not a cosmetic issue.

## Design Invariants

These invariants are critical and should be preserved in future changes.

### Invariant 1: exactly one sample-valid event per fully reconstructed sample
If the receiver emits extra valids, downstream FFT ingest will over-count input samples.

### Invariant 2: truncation policy is stable and intentional
If the 24-to-18-bit mapping changes, all downstream numerical expectations, Python validation, and FFT reference comparisons must be re-reviewed.

### Invariant 3: CDC events must not duplicate
One microphone-side sample must correspond to at most one FFT-side ingest event.

### Invariant 4: FFT ingest strobes are one-cycle events
A high pulse spanning multiple FFT clock cycles changes stream semantics and invalidates transform input framing.

### Invariant 5: FFT DMA ordering must remain monotonic
Readout ordering must match the published bin-index contract used by validation scripts and downstream consumers.

### Invariant 6: mock and real-IP flows must stay explicit
The repository should never silently mix a mock FFT path with a real-IP expectation or vice versa. The manifest/filelist boundary is part of the architecture.

### Invariant 7: generated artifacts do not become source of truth
`sim/local/` and generated portable outputs must remain disposable; the versioned truth lives in `rtl/`, `tb/`, `docs/`, and `sim/manifest/`.

## Extension Guidance

When adding or changing blocks:

- preserve stage-local responsibilities,
- keep domain crossings explicit,
- update both docs and filelists,
- add or extend testbenches at the smallest sensible scope,
- document any change to timing, width, or control contracts.

## Top-Level Debug Strategy

The active board-oriented top-level, `top_level_test_mux_clear_hex_based_on_uploaded`, now uses a staged debug strategy with three ideas:

1. **separate control from observation**, so stimulus-manager controls do not fight with debug selection,
2. **group debug by pipeline stage**, so each selection exposes a coherent subset of signals,
3. **capture outputs into registers**, so fast internal events can be snapshotted onto LEDs, HEX displays, and GPIO debug pins with external enable pulses.

### Control Inputs

#### Switches (`SW`)

| Control | Meaning |
| --- | --- |
| `SW0` | `stim_start_i`: starts the stimulus manager. |
| `SW3:SW1` | `stim_example_sel_i[2:0]`: selects which ROM example is played. |
| `SW5:SW4` | `stim_loop_mode_i[1:0]`: selects stimulus looping mode. |
| `SW6` | `stim_lr_sel_i`: selects the LR channel presented to ACES. |
| `SW9:SW7` | currently reserved for future top-level control expansion. |

#### Keys (`KEY`)

The keys are used only for debug multiplexing.

Because the DE0-CV keys are active-low on hardware, the top-level interprets **pressed = 1** after inversion.

| Key field | Meaning |
| --- | --- |
| `KEY3:KEY2` | debug stage selector (`dbg_stage_sel`). |
| `KEY1:KEY0` | page selector inside the chosen stage (`dbg_page_sel`). |

### GPIO Capture Enables

The displayed outputs are not purely live wires anymore. They are captured into output registers when an external enable pulse arrives on GPIO.

| GPIO input | Function |
| --- | --- |
| `GPIO_0_D0` | system clock input used by the top-level test wrapper. |
| `GPIO_0_D1` | reset input used by the top-level test wrapper. |
| `GPIO_0_D2` | capture-enable for the LED snapshot register. |
| `GPIO_0_D4` | capture-enable for the HEX snapshot register. |
| `GPIO_0_D5` | capture-enable for the GPIO debug snapshot register. |
| `GPIO_0_D6` | clears all captured debug registers. |

This means the workflow is:

1. choose the stage/page with `KEY[3:0]`,
2. wait for the internal event of interest,
3. pulse the matching GPIO capture enable,
4. inspect the captured values at human-speed on LEDs/HEX/GPIO outputs.

### Debug Stage/Page Matrix

#### Stage `00` — Stimulus manager

| `KEY1:KEY0` page | LEDs | HEX | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | `ready`, `busy`, `done`, `window_done`, selected example, loop mode, LR select | current example, current point, ROM address | `{window_done, done, busy, ready}` |
| `01` | same stage status | bit index, FSM state, loop mode, selected example, LR select | `{state[0], state[1], state[2], mic_sd_internal}` |
| `10` or `11` | same stage status | current 24-bit stimulus sample | sample bits `[23:20]` |

#### Stage `01` — I2S pins and recovered samples

| `KEY1:KEY0` page | LEDs | HEX | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | `sck`, `ws`, `chipen`, `lr_sel`, `sd`, `sample_valid`, `fft_sample_valid`, `sact`, `fft_run`, `fft_done` | reconstructed 24-bit sample (`sample_24_dbg_o`) | `{lr_sel, chipen, ws, sck}` |
| `01` | same stage status | 18-bit microphone sample (`sample_mic_o`) | `{sample_valid, sd, ws, sck}` |
| `10` or `11` | same stage status | FFT-width sample (`fft_sample_o`) | `{sact, fft_sample_valid, ws, sck}` |

#### Stage `10` — FFT ingest/control

| `KEY1:KEY0` page | LEDs | HEX | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | sample-valid, FFT-sample-valid, ingest strobe, `run`, `done`, input-buffer status, FFT status | `sdw_istream_real_o` | `{fft_done, fft_run, fft_sample_valid, sact}` |
| `01` | same stage status | `sdw_istream_imag_o` | `{fft_done, fft_run, fft_sample_valid, sact}` |
| `10` or `11` | same stage status | `bfpexp`, FFT status, input-buffer status | `{status[0], status[1], status[2], fft_done}` |

#### Stage `11` — FFT output bins

| `KEY1:KEY0` page | LEDs | HEX | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | `fft_tx_valid`, `fft_tx_last`, `fft_done`, `fft_run` | `fft_tx_index_o` | `{fft_tx_last, fft_tx_valid, fft_done, fft_run}` |
| `01` | same stage status | `fft_tx_real_o` | `{fft_tx_real_o[17], fft_tx_valid, fft_tx_last, fft_done}` |
| `10` or `11` | same stage status | `fft_tx_imag_o` | `{fft_tx_imag_o[17], fft_tx_valid, fft_tx_last, fft_done}` |

### Physical Output Mapping

The selected-and-captured debug information is routed to these board-visible devices:

| Device | Source |
| --- | --- |
| `LEDR9:0` | LED snapshot register loaded from the currently selected stage/page. |
| `HEX5..HEX0` | 24-bit HEX snapshot register, four bits per display. |
| `GPIO_0_D3` | GPIO debug snapshot bit `0`. |
| `GPIO_1_D2` | GPIO debug snapshot bit `1`. |
| `GPIO_1_D3` | GPIO debug snapshot bit `2`. |
| `GPIO_1_D4` | GPIO debug snapshot bit `3`. |

This organization makes the top-level debug less confusing because the operator always answers the same questions in the same order:

- which stage am I looking at?
- which page of that stage is selected?
- did I capture LEDs, HEX, or GPIO outputs yet?
- which physical device should now contain the snapshot?

## Cross-References

- See [overview.md](overview.md) for the project-level purpose.
- See [verification_methodology.md](verification_methodology.md) for how these invariants are checked.
- See [development_guide.md](development_guide.md) for how to extend the architecture safely.
