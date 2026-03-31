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
    -> tagged I2S transmit path
    -> host-side FFT receiver / analysis
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
- `i2s_fft_tx_adapter`

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
- **real-IP-oriented flow** where the checked-in `submodules/R2FFT` implementation is used.

The active ACES integration module instantiates `r2fft_tribuf_impl`; in the real flow that implementation is resolved from the checked-in `submodules/R2FFT` sources, while the mock flow binds the local mock implementation.

### 7. DMA-style FFT reader
`fft_dma_reader` converts FFT completion into a structured bin-readout sequence.

Responsibilities:

- trigger DMA-style address stepping after FFT completion,
- capture returned real/imaginary data,
- emit bin-valid/index/last information.

### 8. TX bridge FIFO
`fft_tx_bridge_fifo` is an explicit buffering stage between `fft_dma_reader` and `i2s_fft_tx_adapter`.

Responsibilities:

- decouple FFT DMA burst output from I2S transmit consumption,
- keep `(real, imag, last, bfpexp)` aligned per bin entry,
- provide a standard push/pop pipeline boundary,
- flag bridge overflow when producer throughput exceeds consumer throughput.

The dedicated FIFO module is in `rtl/common/fft_tx_bridge_fifo.sv`, and the focused subsystem verification of this boundary is `tb/integration/tb_fft_tx_i2s_link.sv`.

### 9. I2S transmit backend for FFT export
`i2s_fft_tx_adapter` serializes FFT output for an external reader over I2S.

Responsibilities:

- consume bins from the bridge FIFO or equivalent staged source at `fft_ready_o` pace,
- insert `bfpexp` metadata at the start of each FFT window,
- repeat `bfpexp` long enough for a slower external host to detect it,
- encode metadata/data type in-band via tagged I2S words,
- serialize `real` and `imag` as left/right I2S channels.

See `docs/i2s_fft_tx_adapter.md` for the detailed contract.

### 10. Host-side FFT receiver and analysis
The maintained host-side consumer lives under `submodules/ACES-RPi-interface/rpi3b_i2s_fft/`.

Responsibilities:

- decode raw or tagged I2S FFT transport,
- reconstruct FFT windows from `(real, imag)` pairs,
- derive magnitude and MFCC-like features for event comparison,
- save reference events and visualize saved FFT history,
- provide offline regression that checks protocol handling without Raspberry Pi + FPGA hardware.

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
5. `fft_tx_bridge_fifo` buffers `(real, imag, last, bfpexp)` entries.
6. `i2s_fft_tx_adapter` emits tagged I2S words and inserts BFPEXP-tagged frames at each FFT-window start.

### Host path
1. The external host samples the continuous I2S stream exported by ACES.
2. In tagged mode, software waits for `BFPEXP` then counts FFT-tagged pairs.
3. In raw mode, framing may be inferred from GPIO handshake or an external framing convention.
4. Software converts `(real, imag)` pairs into magnitude bins and feature vectors.
5. Analyzer logic compares live history against saved reference events.

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

### Invariant 6: bridge FIFO entry alignment must be preserved
`real`, `imag`, `last`, and `bfpexp` for a given bin must always share the same FIFO entry from push to pop.

### Invariant 7: mock and real-IP flows must stay explicit
The repository should never silently mix a mock FFT path with a real-IP expectation or vice versa. The manifest/filelist boundary is part of the architecture.

### Invariant 8: generated artifacts do not become source of truth
`sim/local/` and generated portable outputs must remain disposable; the versioned truth lives in `rtl/`, `tb/`, `docs/`, and `sim/manifest/`.

### Invariant 9: FPGA/host framing must stay documented on both sides
If the tagged word format, BFPEXP behavior, or raw framing assumptions change, both RTL-side and Python-side documentation/tests must be updated together.

### Invariant 10: host-side offline regression must reflect the real framing contract
Offline tests are not allowed to drift into a mock protocol unrelated to the actual serializer contract. They should validate the same tag/payload assumptions the RTL exports.

## Extension Guidance

When adding or changing blocks:

- preserve stage-local responsibilities,
- keep domain crossings explicit,
- update both docs and filelists,
- add or extend testbenches at the smallest sensible scope,
- document any change to timing, width, or control contracts.

## Top-Level Debug Strategy

The active board-oriented top-level, `top_level_test`, uses a staged debug strategy with three ideas:

1. **separate control from observation**, so stimulus-manager controls do not fight with debug selection,
2. **group debug by pipeline stage**, so each selection exposes a coherent subset of signals,
3. **capture outputs into registers**, so fast internal events can be snapshotted onto LEDs, HEX displays, and GPIO debug pins with external enable pulses.

The intended operator flow is now centered on the external GPIO header instead of the on-board FPGA keys. This allows an Analog Discovery or similar logic tool to both select the debug view and generate precise capture pulses.

### Control Inputs

#### Switches (`SW`)

| Control | Meaning |
| --- | --- |
| `SW0` | `stim_start_i`: starts the stimulus manager. |
| `SW3:SW1` | `stim_example_sel_i[2:0]`: selects which ROM example is played. |
| `SW5:SW4` | `stim_loop_mode_i[1:0]`: selects stimulus looping mode. |
| `SW6` | `stim_lr_sel_i`: selects the LR channel presented to ACES. |
| `SW9:SW7` | currently reserved for future top-level control expansion. |

#### GPIO-based debug selection

The debug selector should no longer depend on the DE0-CV push-buttons. Instead, the stage/page selection is expected to come from GPIO pins driven by the Analog Discovery.

Recommended logical mapping:

| GPIO input | Meaning |
| --- | --- |
| `GPIO_DBG_STAGE0` | debug stage selector bit 0. |
| `GPIO_DBG_STAGE1` | debug stage selector bit 1. |
| `GPIO_DBG_PAGE0` | page selector bit 0 inside the chosen stage. |
| `GPIO_DBG_PAGE1` | page selector bit 1 inside the chosen stage. |

With that mapping, the active selector fields are:

- `dbg_stage_sel = {GPIO_DBG_STAGE1, GPIO_DBG_STAGE0}`
- `dbg_page_sel  = {GPIO_DBG_PAGE1, GPIO_DBG_PAGE0}`

This keeps the whole debug flow scriptable from the external instrument: select a stage, select a page, wait for the internal event, then pulse the capture line that corresponds to the physical output of interest.

The `tb_top_level_test` wave setup is intended to mirror that laboratory flow: it shows the external control inputs, the live muxed debug buses, the captured board-facing outputs, and the internal signals that feed each stage/page selection.

### GPIO capture and external control pins

The displayed outputs are not purely live wires anymore. They are captured into output registers when an external enable pulse arrives on GPIO.

| GPIO input | Function |
| --- | --- |
| `GPIO_0_D0` | system clock input used by the top-level test wrapper. |
| `GPIO_0_D1` | reset input used by the top-level test wrapper. |
| `GPIO_0_D2` | capture-enable for the LED snapshot register. |
| `GPIO_0_D4` | capture-enable for the HEX snapshot register. |
| `GPIO_0_D5` | capture-enable for the GPIO debug snapshot register. |
| `GPIO_0_D6` | clears all captured debug registers. |

If a concrete pinout is defined for the four selector bits, it should be documented next to the capture pins above so the Analog Discovery wiring is fully explicit.

This means the workflow is:

1. choose the stage/page with the dedicated GPIO debug-select pins,
2. wait for the internal event of interest,
3. pulse the matching GPIO capture enable,
4. inspect the captured values at human-speed on LEDs/HEX/GPIO outputs.

### Debug Stage/Page Matrix

#### Stage `00` — Stimulus manager

| Page | LEDs | HEX display mapping | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | `ready`, `busy`, `done`, `window_done`, selected example, loop mode, LR select | `HEX0`=`stim_current_example_o[2:0]`; `HEX1`=`stim_current_point_o[3:0]`; `HEX2`=`stim_current_point_o[7:4]`; `HEX3`=`stim_current_point_o[8]`; `HEX4`=`stim_rom_addr_dbg_o[3:0]`; `HEX5`=`stim_rom_addr_dbg_o[7:4]` | `{window_done, done, busy, ready}` |
| `01` | same stage status | `HEX0`=`stim_bit_index_o[3:0]`; `HEX1`=`stim_bit_index_o[5:4]`; `HEX2`=`stim_state_dbg_o`; `HEX3`=`stim_loop_mode_i`; `HEX4`=`stim_example_sel_i`; `HEX5`=`stim_lr_sel_i` | `{state[0], state[1], state[2], mic_sd_internal}` |
| `10` or `11` | same stage status | `HEX0`=`stim_current_sample_dbg_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[19:16]`; `HEX5`=`[23:20]` | sample bits `[23:20]` |

#### Stage `01` — I2S pins and recovered samples

| Page | LEDs | HEX display mapping | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | `sck`, `ws`, `chipen`, `lr_sel`, `sd`, `sample_valid`, `fft_sample_valid`, `sact`, `fft_run`, `fft_done` | `HEX0`=`sample_24_dbg_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[19:16]`; `HEX5`=`[23:20]` | `{lr_sel, chipen, ws, sck}` |
| `01` | same stage status | `HEX0`=`sample_mic_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[17:16]`; `HEX5`=`0` | `{sample_valid, sd, ws, sck}` |
| `10` or `11` | same stage status | `HEX0`=`fft_sample_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[17:16]`; `HEX5`=`0` | `{sact, fft_sample_valid, ws, sck}` |

#### Stage `10` — FFT ingest/control

| Page | LEDs | HEX display mapping | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | sample-valid, FFT-sample-valid, ingest strobe, `run`, `done`, input-buffer status, FFT status | `HEX0`=`sdw_istream_real_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[17:16]`; `HEX5`=`0` | `{fft_done, fft_run, fft_sample_valid, sact}` |
| `01` | same stage status | `HEX0`=`sdw_istream_imag_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[17:16]`; `HEX5`=`0` | `{fft_done, fft_run, fft_sample_valid, sact}` |
| `10` or `11` | same stage status | `HEX0`=`bfpexp_o[3:0]`; `HEX1`=`bfpexp_o[7:4]`; `HEX2`=`fft_status_o`; `HEX3`=`fft_input_buffer_status_o`; `HEX4`=`0`; `HEX5`=`0` | `{status[0], status[1], status[2], fft_done}` |

#### Stage `11` — FFT output bins

| Page | LEDs | HEX display mapping | GPIO debug outputs |
| --- | --- | --- | --- |
| `00` | `fft_tx_valid`, `fft_tx_last`, `fft_done`, `fft_run` | `HEX0`=`fft_tx_index_o[3:0]`; `HEX1`=`fft_tx_index_o[7:4]`; `HEX2`=`fft_tx_index_o[8]`; `HEX3`=`0`; `HEX4`=`0`; `HEX5`=`0` | `{fft_tx_last, fft_tx_valid, fft_done, fft_run}` |
| `01` | same stage status | `HEX0`=`fft_tx_real_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[17:16]`; `HEX5`=`0` | `{fft_tx_real_o[17], fft_tx_valid, fft_tx_last, fft_done}` |
| `10` or `11` | same stage status | `HEX0`=`fft_tx_imag_o[3:0]`; `HEX1`=`[7:4]`; `HEX2`=`[11:8]`; `HEX3`=`[15:12]`; `HEX4`=`[17:16]`; `HEX5`=`0` | `{fft_tx_imag_o[17], fft_tx_valid, fft_tx_last, fft_done}` |

### Physical Output Mapping

The selected-and-captured debug information is routed to these board-visible devices:

| Device | Source |
| --- | --- |
| `LEDR9:0` | LED snapshot register loaded from the currently selected stage/page. |
| `HEX0` | `dbg_hex_capture_r[3:0]` (least-significant nibble of the captured HEX payload). |
| `HEX1` | `dbg_hex_capture_r[7:4]`. |
| `HEX2` | `dbg_hex_capture_r[11:8]`. |
| `HEX3` | `dbg_hex_capture_r[15:12]`. |
| `HEX4` | `dbg_hex_capture_r[19:16]`. |
| `HEX5` | `dbg_hex_capture_r[23:20]` (most-significant nibble of the captured HEX payload). |
| `GPIO_0_D3` | GPIO debug snapshot bit `0`. |
| `GPIO_1_D2` | GPIO debug snapshot bit `1`. |
| `GPIO_1_D3` | GPIO debug snapshot bit `2`. |
| `GPIO_1_D4` | GPIO debug snapshot bit `3`. |
| `GPIO_1_D17` | tagged TX I2S SCK output from ACES (`tx_i2s_sck_o`). |
| `GPIO_1_D19` | tagged TX I2S WS output from ACES (`tx_i2s_ws_o`). |
| `GPIO_1_D20` | tagged TX I2S SD output from ACES (`tx_i2s_sd_o`). |

That explicit nibble ordering is important when the Analog Discovery script reconstructs a multi-digit value from the seven-segment displays: `HEX0` is always the least-significant nibble and `HEX5` is always the most-significant nibble.

This organization makes the top-level debug less confusing because the operator always answers the same questions in the same order:

- which stage am I looking at?
- which page of that stage is selected?
- did I capture LEDs, HEX, or GPIO outputs yet?
- which physical device should now contain the snapshot?


## Cross-References

- See [overview.md](overview.md) for the project-level purpose.
- See [verification_methodology.md](verification_methodology.md) for how these invariants are checked.
- See [development_guide.md](development_guide.md) for how to extend the architecture safely.
