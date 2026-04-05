# FFT TX Bridge FIFO

`fft_tx_bridge_fifo` is the reusable buffering primitive behind the SPI export
path. It is small, but it carries an important architectural guarantee: the
fields that define one FFT bin stay together while timing is being decoupled.

## Module Location

- `rtl/common/fft_tx_bridge_fifo.sv`
- `tb/unit/tb_fft_tx_bridge_fifo.sv`
- `tb/integration/tb_fft_tx_spi_link.sv`

## Why This FIFO Matters

The FFT producer and the SPI consumer do not move at the same pace:

- FFT readout can generate bursts,
- SPI drain depends on when the host decides to clock data out.

That alone would justify buffering, but this FIFO solves a second problem too:
it preserves metadata alignment. Each entry keeps these fields as one atomic
bundle:

- `fft_real`
- `fft_imag`
- `fft_last`
- `bfpexp`

If those signals ever got buffered independently, the host could receive a valid-
looking but semantically incorrect window.

## Relationship To `spi_fft_tx_adapter`

This FIFO is a standalone module because it is useful to verify in isolation, but
the active transport path uses it from inside `spi_fft_tx_adapter`.

That means:

- you can reason about FIFO behavior separately,
- the adapter remains the transport owner,
- the FIFO is not a second alternative transport block.

## Stored Entry Format

One FIFO entry is effectively:

```text
{ fft_real, fft_imag, fft_last, bfpexp }
```

`fft_last` is stored with the payload because the adapter needs to know exactly
which serialized FFT pair closes the logical window.

## Behavioral Contract

### Push side

- `push_i = 1` requests insertion of the current tuple.
- If the FIFO is not full, the tuple is written.
- If the FIFO is full and no simultaneous pop occurs, the write is rejected and
  `overflow_o` pulses.

### Pop side

- `pop_i = 1` removes the current head entry when the FIFO is not empty.
- The FIFO is show-ahead: when `valid_o = 1`, the current head entry is already
  visible on the outputs before a pop.

### Simultaneous push and pop

Push and pop in the same cycle are allowed. This is useful because it lets the
buffer sustain one element per cycle when upstream and downstream are both active.

In practice, that helps the adapter drain windows without unnecessarily stalling
the producer.

## Status Outputs

- `valid_o`: head entry contains valid data
- `empty_o`: no entries are stored
- `full_o`: occupancy reached `FIFO_DEPTH`
- `level_o`: current occupancy
- `overflow_o`: one-cycle pulse on rejected push

The status outputs are intentionally simple because they are used both for RTL
control and for debug visibility in benches and top-levels.

## Why Show-Ahead Behavior Matters

The adapter looks at the FIFO head to precompute the next BFPEXP or FFT pair. A
show-ahead FIFO lets it do that without an extra read command or sub-state.

The trade-off is that after a pop, the adapter must wait one internal clock for
the new head to appear cleanly. That is why the adapter contains explicit
post-pop refresh state.

## Verification

### Unit verification: `tb_fft_tx_bridge_fifo`

The unit bench checks:

- reset state,
- ordered push/pop behavior,
- preservation of `real/imag/last/bfpexp` alignment,
- full detection,
- overflow pulse on writes while full,
- simultaneous push/pop without corruption.

### Integration verification: `tb_fft_tx_spi_link`

The integration bench proves that the FIFO behavior remains correct once the
adapter consumes it:

- occupancy grows during a burst,
- the adapter drains at host-controlled pace,
- transaction payload remains identical to the expected FFT framing.

## Related Reading

- [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
- [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- [testbenches.md](testbenches.md)
