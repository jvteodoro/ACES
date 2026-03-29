# FFT TX Bridge FIFO

## Purpose

`fft_tx_bridge_fifo` is the explicit buffering stage between FFT bin production and the slower I2S transmit backend.

It keeps the per-bin fields aligned while decoupling bursty FFT readout from serial transmission latency.

## Module location

- `rtl/common/fft_tx_bridge_fifo.sv`
- `tb/unit/tb_fft_tx_bridge_fifo.sv`
- `tb/integration/tb_fft_tx_i2s_link.sv`

## Stored entry format

Each FIFO entry carries one complete FFT bin context:

- `fft_real`
- `fft_imag`
- `fft_last`
- `bfpexp`

The invariant is that these fields never separate while inside the FIFO.

## Behavioral contract

### Push side

- `push_i = 1` requests insertion of the current input tuple.
- If the FIFO is not full, the tuple is written.
- If the FIFO is full and no simultaneous pop happens, the write is rejected and `overflow_o` pulses.

### Pop side

- `pop_i = 1` removes the current head entry when the FIFO is not empty.
- The FIFO is show-ahead: the current head is visible on the outputs whenever `valid_o = 1`.

### Simultaneous push and pop

The FIFO supports push and pop in the same cycle.

That keeps throughput high at the bridge boundary and is particularly useful when the serializer is draining continuously while the FFT reader is still producing bins.

## Status outputs

- `valid_o`: high when an entry is available at the head,
- `empty_o`: high when the FIFO contains no entries,
- `full_o`: high when `level_o == FIFO_DEPTH`,
- `level_o`: current occupancy,
- `overflow_o`: one-cycle pulse on rejected write attempts.

## Verification

### Unit verification: `tb_fft_tx_bridge_fifo`

The unit bench checks:

- reset state,
- ordered push/pop behavior,
- preservation of `real/imag/last/bfpexp` alignment,
- full detection,
- overflow pulse on write while full,
- simultaneous push/pop without order corruption.

### Integration verification: `tb_fft_tx_i2s_link`

The integration bench proves that the FIFO fulfills its decoupling role when connected directly to `i2s_fft_tx_adapter`:

- the FIFO occupancy grows during a burst,
- the downstream serializer drains at its own pace,
- the serialized output still matches the expected FFT-window framing.
