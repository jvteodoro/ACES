# I2S FFT TX Adapter

## Purpose

`i2s_fft_tx_adapter` is the transmit-side serializer that turns FFT output bins into a tagged I2S stream suitable for an external reader, such as a Raspberry Pi connected to FPGA GPIO pins.

The block is intentionally lightweight. It does not try to absorb an FFT burst by itself; that decoupling is the job of the external bridge FIFO.

## Relevant files

- `rtl/frontend/i2s_fft_tx_adapter.sv`
- `rtl/core/aces.sv`
- `rtl/common/fft_dma_reader.sv`
- `tb/unit/tb_i2s_fft_tx_adapter.sv`
- `tb/integration/tb_fft_tx_i2s_link.sv`
- `tb/integration/tb_top_level_test.sv`

## Position in the top-level path

Inside `aces`, the transmit path is:

```text
FFT core
  -> fft_dma_reader
  -> TX FIFO bookkeeping in aces
  -> i2s_fft_tx_adapter
  -> tx_i2s_sck_o / tx_i2s_ws_o / tx_i2s_sd_o
```

Important consequence:

- `i2s_fft_tx_adapter` does not see microphone samples directly.
- It only starts serializing after the FFT output path has produced at least one bin and that bin has reached the adapter handshake.

In `aces`, the adapter input valid is `tx_fft_valid_i = tx_fifo_word_valid_r`, so the serializer remains logically idle until the FIFO side has a word ready to present.

## Input contract

For each accepted FFT bin, the adapter samples:

- `fft_real_i`
- `fft_imag_i`
- `fft_last_i`
- `bfpexp_i`

Acceptance happens only when `fft_valid_i && fft_ready_o`.

The intended window-level contract is:

1. The first accepted bin of a window carries the `bfpexp_i` that should be announced to software.
2. Bins remain ordered.
3. `fft_last_i` marks the last accepted bin of the current FFT window.

## Internal model

The adapter has two important storage layers.

### 1. Pending register

The pending register captures one FFT bin from the upstream source:

- `pending_valid_r`
- `pending_real_r`
- `pending_imag_r`
- `pending_last_r`
- `pending_bfpexp_r`

This register is loaded as soon as `fft_valid_i` is seen while `pending_valid_r == 0`.

### 2. Active frame register

The active register is what is actually being serialized out on `i2s_sd_o`:

- `active_valid_r`
- `active_tag_r`
- `active_left_r`
- `active_right_r`
- `active_hold_frames_r`

`i2s_sd_o` is driven directly from the active register:

```text
if active_valid_r == 1 -> serialize active slot bit
if active_valid_r == 0 -> drive 0
```

That means having data in `pending_*` is not enough by itself to toggle `i2s_sd_o`. The pending word must first be promoted into the active register.

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

## When the adapter changes state

The serializer clock runs continuously, but the payload only changes at a frame boundary. In this RTL, that boundary occurs after a complete I2S frame has finished, not immediately when `pending_valid_r` rises.

Operationally, the adapter behaves like this:

1. **Reset/idle**
   - `active_valid_r = 0`
   - `pending_valid_r = 0`
   - `i2s_sd_o = 0`

2. **First bin arrives**
   - `pending_valid_r` becomes `1`
   - the first bin is stored in `pending_*`
   - `i2s_sd_o` can still remain `0` until the next frame boundary

3. **Window start**
   - if `input_window_in_progress_r == 0` and `pending_valid_r == 1`, the adapter loads a `BFPEXP` frame into `active_*`
   - `active_tag_r` becomes `TAG_BFPEXP_C`
   - `input_window_in_progress_r` becomes `1`

4. **BFPEXP hold**
   - the same BFPEXP frame is repeated for `BFPEXP_HOLD_FRAMES`

5. **FFT payload frames**
   - once the hold count expires, each frame boundary consumes one pending FFT bin
   - `active_tag_r` becomes `TAG_FFT_C`
   - `active_left_r` gets the real part
   - `active_right_r` gets the imaginary part

6. **End of window**
   - when a consumed pending bin has `pending_last_r = 1`, `input_window_in_progress_r` is cleared
   - if no new pending bin exists at the next boundary, the adapter returns to `IDLE`

## Why `i2s_sd_o` stays at zero in `tb_top_level_test`

This is the behavior that usually looks suspicious in the waveform, but it is expected.

### Immediate cause inside `i2s_fft_tx_adapter`

The direct reason is simple:

- `i2s_sd_o` is hard-wired to `0` whenever `active_valid_r == 0`.
- `active_valid_r` only becomes `1` on a frame boundary when a pending word is already available.

So there are two gates before serial activity appears:

1. some FFT output must have reached `pending_*`,
2. the adapter must hit the next I2S frame boundary and move that data into `active_*`.

### Upstream cause in `tb_top_level_test`

In the top-level bench, the first pending word can only exist after the full processing chain has advanced far enough:

```text
stimulus I2S
  -> sample reconstruction
  -> 24b to 18b path
  -> FFT ingest
  -> FFT execution
  -> DMA readout
  -> ACES TX FIFO bookkeeping
  -> adapter pending register
```

In the real FFT flow, `fft_dma_reader` waits for `done_i` and only starts readout on the next `run_i` pulse. That means the first completed FFT frame is not immediately visible to the TX path when the FFT finishes; it becomes readable only after the next run event rotates the FFT buffers.

This is why a long initial region of zero on `i2s_sd_o` is normal in `tb_top_level_test real`.

### Why the screenshot starts transmitting exactly at that point

The transition seen in the waveform typically corresponds to this sequence:

1. `pending_valid_r` becomes `1`, meaning the first FFT bin has finally reached the adapter.
2. `pending_real_r`, `pending_imag_r`, and `pending_bfpexp_r` stop being zero.
3. At the next frame boundary, `active_valid_r` goes high.
4. The adapter first emits `TAG_BFPEXP_C` frames.
5. After the BFPEXP hold expires, it starts emitting `TAG_FFT_C` frames with real and imaginary payloads.

In other words, the waveform is not showing a spontaneous start of transmission. It is showing the exact moment when the adapter finally has permission and aligned timing to leave `IDLE`.

## Why the initial zeros are also expected by the bench

`tb_top_level_test` explicitly models this behavior.

The bench only enqueues expected serial frames once the adapter-side handshake occurs:

```text
dut.u_aces.tx_fft_valid_i && dut.u_aces.tx_fft_ready_o
```

Before that, the expected queue is empty and the checker accepts `TAG_IDLE_C` frames. The checker also allows the first observed frame to be an all-zero idle frame before the BFPEXP/FFT sequence starts.

So the bench is intentionally written to treat the initial zero region on `i2s_sd_o` as valid protocol behavior, not as a bug.

## Timing intuition for the default top-level bench

For `tb_top_level_test`, the default parameters are:

- `clk = 100 MHz`
- `I2S_CLOCK_DIV = 4`
- TX and RX `SCK` toggle every `40 ns`
- one full I2S bit period is `80 ns`
- one 64-bit I2S frame takes `5.12 us`

With `512` input samples per FFT window, one captured audio window already takes about `2.62 ms` on the receive side. In the real flow, because FFT readout becomes visible only after the next `run`, the first transmitted data naturally appears much later than reset release. A first visible non-zero TX region around the millisecond range is therefore consistent with the architecture.

## Flow control and buffering

The adapter contains only a one-entry pending register. That staging register lets the serializer handshake cleanly with an upstream FIFO, but it is not meant to replace burst buffering.

Meaningful status outputs are therefore:

- `fft_ready_o = 1`: the pending register is free and a new bin may be accepted
- `fifo_full_o = 1`: the pending register is occupied
- `fifo_empty_o = 1`: the pending register is empty
- `fifo_level_o`: `0` or `1`, reflecting that single-entry staging buffer

## Overflow semantics

`overflow_o` is not a “FIFO full” flag in the deep-buffer sense.

Instead, it is a protocol checker for backpressure:

- when `fft_ready_o = 0`, the producer must keep the presented bin stable
- if the producer changes the bin fields while the adapter is stalled, `overflow_o` pulses

Keeping `fft_valid_i` asserted with the same stable data while `fft_ready_o = 0` is legal and expected in ready/valid-style integration.

## Synthesizability

The RTL is synthesizable and uses:

- fixed-width registers and counters
- no dynamic data structures
- no testbench-only constructs in the datapath

## Verification

### Unit verification: `tb_i2s_fft_tx_adapter`

The unit testbench validates:

- the `SCK` divider period
- `WS` stability within each 32-bit slot
- alternating slot/channel structure
- insertion and repetition of `BFPEXP` frames
- correct tagged payload sequence across two FFT windows
- consistency between `fft_ready_o` and the adapter's one-entry pending buffer

### Integration verification: `tb_fft_tx_i2s_link`

The subsystem integration testbench connects:

```text
fft_tx_bridge_fifo -> i2s_fft_tx_adapter
```

and validates:

- burst writes into the FIFO while the serializer drains slowly
- preservation of bin order through the FIFO/adapter boundary
- absence of bridge overflow and adapter backpressure violations
- correct serialized I2S sequence at the subsystem output
