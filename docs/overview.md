# ACES Overview

ACES is an FPGA audio capture and FFT analysis workspace with three concerns that
are intentionally kept separate:

- audio ingress and FFT execution in SystemVerilog RTL,
- reproducible simulation and board-facing top-levels,
- Raspberry Pi host tooling that consumes tagged FFT windows.

For the current branch, the important architectural fact is this: the
microphone-facing side is still I2S, but the FPGA-to-host export path is now
SPI slave TX.

## What A New Contributor Should Know First

- The transport changed, but the host-visible FFT word format did not.
- The Raspberry Pi is always the SPI master and the FPGA is always the SPI slave.
- A host transaction reads one complete FFT window at a time.
- `window_ready` is the coarse-grain handshake that tells the host a full window
  is buffered and safe to read.
- The SPI path is easiest to understand if you start from the transport docs
  before reading the full board top-level.

## End-To-End Data Path

```text
I2S microphone or ROM stimulus
    -> sample reconstruction
    -> 24b to 18b adaptation
    -> FFT ingest pipeline
    -> FFT core
    -> fft_dma_reader
    -> spi_fft_tx_adapter
        -> internal fft_tx_bridge_fifo
        -> tagged 32-bit word packing
        -> SPI byte serializer
    -> FPGA GPIO pins
    -> Raspberry Pi SPI master
```

Two details matter here:

1. `fft_dma_reader` still produces bins as an internal streaming-style interface.
2. `spi_fft_tx_adapter` is the boundary where that stream becomes transaction-
   based host traffic.

## Why The SPI Refactor Was Done This Way

The project intentionally preserved the logical transport contract so that the
host parser did not need a semantic rewrite. The SPI backend therefore reuses
the same tagged 32-bit words that the previous serializer exposed:

```text
[ tag(2) | reserved zeros | signed payload ]
```

This keeps the meaning of BFPEXP and FFT payloads stable across transport
changes. The physical wire protocol changed; the logical content did not.

## Main Files And Why They Matter

| File | Why you care |
| --- | --- |
| `rtl/core/aces.sv` | Main ACES pipeline and the point where SPI TX ports become part of the core interface. |
| `rtl/frontend/spi_fft_tx_adapter.sv` | Main SPI transport block. This is the best place to study framing, buffering, and serialization behavior. |
| `rtl/common/fft_tx_bridge_fifo.sv` | Reusable FIFO that keeps `real/imag/last/bfpexp` aligned while decoupling producer and consumer timing. |
| `rtl/top/top_level_spi_fft_tx_diag.sv` | Small deterministic top-level for bring-up and host validation without microphone or FFT dependencies. |
| `rtl/top/top_level_test.sv` | Full board-facing top-level used when the whole ACES path is under test. |
| `tb/unit/tb_spi_fft_tx_adapter.sv` | Fastest executable spec for the adapter contract. |
| `tb/integration/tb_fft_tx_spi_link.sv` | Shows how FIFO semantics and SPI drain interact over multiple windows. |

## Board-Facing SPI Pins

The active Pi-facing transport uses this pin neighborhood:

- `GPIO_1_D27`: SPI `SCLK` input to FPGA
- `GPIO_1_D29`: SPI `CS_N` input to FPGA
- `GPIO_1_D31`: SPI `MISO` output from FPGA
- `GPIO_1_D25`: `window_ready` output from FPGA
- `GPIO_1_D23`: overflow/debug output in the full top-level

## Recommended Reading Order

If you are entering the project specifically to understand the SPI export path,
read in this order:

1. [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
2. [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
3. [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
4. [architecture.md](architecture.md)
5. [simulation.md](simulation.md)
6. [testbenches.md](testbenches.md)

If you are entering to understand the whole repository layout, read
[repository_structure.md](repository_structure.md) right after this file.

## Supported Simulation Targets

The main SPI-related targets you will use most often are:

- `spi_fft_tx_adapter`
- `fft_tx_spi_link`
- `aces`
- `top_level_spi_fft_tx_diag`
- `top_level_test`

## Related Docs

- [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
- [architecture.md](architecture.md)
- [current_state.md](current_state.md)
- [simulation.md](simulation.md)
- [testbenches.md](testbenches.md)
- [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- [top_level_spi_fft_tx_diag.md](top_level_spi_fft_tx_diag.md)
