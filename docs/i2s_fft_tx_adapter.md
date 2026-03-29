# I2S FFT TX Adapter

## Purpose

`i2s_fft_tx_adapter` is the transmit-side serializer that turns FFT output bins into a tagged I2S stream suitable for an external reader, such as a Raspberry Pi connected to FPGA GPIO pins.

The block is intentionally lightweight. It does not try to absorb an FFT burst by itself; that decoupling is the job of the external bridge FIFO.

## Module location

- `rtl/frontend/i2s_fft_tx_adapter.sv`
- `rtl/common/fft_tx_bridge_fifo.sv`
- `tb/unit/tb_i2s_fft_tx_adapter.sv`
- `tb/integration/tb_fft_tx_i2s_link.sv`

## Input contract

For each accepted FFT bin, the adapter samples:

- `fft_real_i`
- `fft_imag_i`
- `fft_last_i`
- `bfpexp_i`

Acceptance happens only when `fft_valid_i && fft_ready_o`.

The intended window-level contract is:

1. the first accepted bin of a window carries the `bfpexp_i` that should be announced to software,
2. bins remain ordered,
3. `fft_last_i` marks the last accepted bin of the current FFT window.

## Output framing

At the start of each FFT window, the adapter emits a special `BFPEXP` frame before any FFT bins of that window.

That metadata frame is repeated for `BFPEXP_HOLD_FRAMES` complete I2S frames so the software reader has multiple chances to lock onto the exponent.

After that, each accepted FFT bin is serialized as one I2S frame:

- left channel: real part
- right channel: imaginary part

## I2S slot format

Each slot has `I2S_SLOT_W` bits and carries:

```text
[2-bit tag][reserved zero bits][I2S_SAMPLE_W signed payload bits]
```

Tag values:

- `0 = idle`
- `1 = bfpexp`
- `2 = fft`

The payload is sent MSB-first.

## Flow control and buffering

The adapter contains only a one-entry pending register. That staging register lets the serializer handshake cleanly with an upstream FIFO, but it is not meant to replace burst buffering.

Meaningful status outputs are therefore:

- `fft_ready_o = 1`: the pending register is free and a new bin may be accepted,
- `fifo_full_o = 1`: the pending register is occupied,
- `fifo_empty_o = 1`: the pending register is empty,
- `fifo_level_o`: `0` or `1`, reflecting that single-entry staging buffer.

## Overflow semantics

`overflow_o` is not a “FIFO full” flag in the deep-buffer sense.

Instead, it is a protocol checker for backpressure:

- when `fft_ready_o = 0`, the producer must keep the presented bin stable,
- if the producer changes the bin fields while the adapter is stalled, `overflow_o` pulses.

Keeping `fft_valid_i` asserted with the same stable data while `fft_ready_o = 0` is legal and expected in ready/valid-style integration.

## Synthesizability

The RTL is synthesizable and uses:

- fixed-width registers and counters,
- no dynamic data structures,
- no testbench-only constructs in the datapath.

## Verification

### Unit verification: `tb_i2s_fft_tx_adapter`

The unit testbench validates:

- the `SCK` divider period,
- `WS` stability within each 32-bit slot,
- alternating slot/channel structure,
- insertion and repetition of `BFPEXP` frames,
- correct tagged payload sequence across two FFT windows,
- consistency between `fft_ready_o` and the adapter's one-entry pending buffer.

### Integration verification: `tb_fft_tx_i2s_link`

The subsystem integration testbench connects:

```text
fft_tx_bridge_fifo -> i2s_fft_tx_adapter
```

and validates:

- burst writes into the FIFO while the serializer drains slowly,
- preservation of bin order through the FIFO/adapter boundary,
- absence of bridge overflow and adapter backpressure violations,
- correct serialized I2S sequence at the subsystem output.
