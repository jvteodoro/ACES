# Verification Methodology

## Philosophy

ACES uses layered verification so failures are localized quickly and full-pipeline confidence is built incrementally.

The strategy is:

1. verify narrow contracts in unit tests,
2. verify boundaries in integration tests,
3. use deterministic stimulus wherever possible,
4. combine HDL assertions with software-side numerical validation,
5. validate host-side protocol handling offline before board bring-up.

## Layered Testing Strategy

### Unit verification
Used for small, local questions such as:

- was a sample reconstructed correctly?
- did truncation produce the expected FFT-width value?
- did a stimulus block emit the right serialized behavior?

### Integration verification
Used for subsystem behavior such as:

- stimulus plus frontend interaction,
- CDC plus ingest interaction,
- ACES plus mock FFT interaction,
- top-level stimulus-to-output behavior.

### Flow-level verification
Used when packaging or real-IP-oriented simulation setup must be checked for structural correctness.

### Host-side offline verification
Used for the Python receiver/analyzer path that consumes the FPGA FFT export stream.

Examples:

- does tagged-word decoding match the RTL packing contract?
- does the receiver re-synchronize correctly after a broken frame?
- do analyzer buffers and event snapshots behave correctly without live hardware?
- does headless plotting keep working in non-GUI environments?

## Assertions in ACES

Assertions are used for two different purposes.

### Functional assertions
These check value correctness.

Examples:

- reconstructed sample equals expected ROM value,
- FFT-side real output equals expected input sample,
- imag output remains zero for real-only stimulus.

### Temporal assertions
These check event timing and protocol shape.

Examples:

- a valid pulse lasts one cycle,
- a sample is counted exactly once,
- output ordering remains monotonic,
- a “last” indicator is only asserted on the final item.

Both are important. A design can be numerically correct but temporally wrong, especially in stream/CDC-heavy hardware.

## Mock vs Real Verification

### Mock flow
Best for:

- quick regression,
- deterministic bring-up,
- development when vendor collateral is unavailable.

### Real-IP-oriented flow
Best for:

- checking repository integration against real vendor-facing wrappers,
- validating environment setup before handoff,
- aligning the testbench structure with the eventual full simulation stack.

## Python Validation Role

The Python utilities and ROM collateral support a second validation axis:

- signal generation,
- ROM-content preparation,
- FFT expectation creation,
- waveform/result comparison outside the HDL simulator.

This is especially valuable for FFT work, where pass/fail is often numerical rather than purely protocol-oriented.

The host-side package under `submodules/ACES-RPi-interface/` now extends that role by providing
offline regression for the transport/parser layer itself, not only numerical post-processing.

## FFT Validation and `fftBfpExp`

When validating FFT outputs, `fftBfpExp` must be handled explicitly.

Conceptually:

```text
X_corrected = (real + j*imag) * 2^fftBfpExp
```

If a comparison script ignores block floating-point exponent correction, the result may look numerically wrong even when the hardware path is correct.

## Recommended Verification Workflow

1. confirm the local module behavior with a unit bench,
2. run the nearest integration bench,
3. inspect waveforms if timing or ordering is suspicious,
4. compare FFT-relevant numerical results with Python-side expectations when applicable,
5. run the host-side offline regression if the change touches stream format, parsing, buffering, plotting, or event comparison,
6. only then move to real-IP-oriented flows or portable handoff or board bring-up.

## What to Update When Behavior Changes

If you change any of the following, update tests and docs together:

- sample width policy,
- CDC event semantics,
- FFT ingest pulse semantics,
- FFT output ordering,
- block floating-point interpretation,
- tagged I2S framing or payload packing,
- host-side receiver assumptions,
- portable simulation expectations.

## Related Reading

- [current_state.md](current_state.md)
- [architecture.md](architecture.md)
- [simulation.md](simulation.md)
- [testbenches.md](testbenches.md)
