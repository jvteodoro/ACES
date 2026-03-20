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

## Cross-References

- See [overview.md](overview.md) for the project-level purpose.
- See [verification_methodology.md](verification_methodology.md) for how these invariants are checked.
- See [development_guide.md](development_guide.md) for how to extend the architecture safely.
