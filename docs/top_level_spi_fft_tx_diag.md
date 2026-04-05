# Top-Level SPI FFT TX Diagnostic

`top_level_spi_fft_tx_diag` is the smallest board-facing top-level that still
exercises the real SPI transport behavior.

Its purpose is not to prove the FFT algorithm. Its purpose is to make SPI bring-
up, host decoder validation, and board wiring checks simple and deterministic.

## File

- `rtl/top/top_level_spi_fft_tx_diag.sv`

## Why This Top-Level Exists

Debugging the full stack all at once is expensive because there are many moving
parts:

- microphone clocks and pin wiring,
- sample reconstruction,
- FFT scheduling,
- FFT core behavior,
- FFT readout,
- SPI transport,
- host-side parsing.

This diagnostic top-level intentionally removes everything except the transport
question. It replaces the upstream data path with a fixed-pattern source and
drives `spi_fft_tx_adapter` directly.

## What Is Real And What Is Synthetic

Real in this top-level:

- the actual SPI transport RTL,
- the same pin behavior seen by the host,
- the same word packing and transaction framing.

Synthetic in this top-level:

- FFT source data,
- BFPEXP source,
- window progression.

That is why the module is so useful for lab bring-up: transport bugs can be
isolated from signal-processing bugs.

## Fixed Diagnostic Pattern

The generated source is constant inside each synthetic bin:

- `real = 18'sh15555`
- `imag = 18'sh0AAAB`
- `bfpexp = 8'sh12`

These values were chosen because they are:

- non-zero,
- easy to distinguish from each other,
- easy to spot in waveforms and host dumps,
- stable across every generated window.

## How The Synthetic Source Works

The top-level ties:

```text
diag_fft_valid_i = diag_fft_ready_o
```

This means it behaves like an always-ready producer that immediately presents the
next synthetic bin whenever the adapter can accept one.

That has two benefits:

- it stress-tests the path at the highest sustainable rate allowed by the
  adapter,
- it stays deterministic because the payload values never change.

`diag_bin_index_r` counts bins inside the current synthetic window, and
`diag_fft_last_i` asserts on the final bin so the adapter sees normal window
boundaries.

## Exported Pin Use

The primary transport pins are:

- `GPIO_1_D27`: SPI `SCLK` input
- `GPIO_1_D29`: SPI `CS_N` input
- `GPIO_1_D31`: SPI `MISO` output
- `GPIO_1_D25`: `window_ready` output

The module also mirrors useful status signals to additional GPIO and LED outputs
so that a scope, logic analyzer, or simple visual inspection can confirm that
the transport is alive.

## LED And HEX Meaning

### LEDs

The LEDs provide a quick board-side summary:

- ready/accept behavior on the synthetic producer side,
- internal FIFO full/empty state,
- latched overflow status,
- `window_ready`,
- live SPI activity clues such as `CS_N`, `SCLK`, and `MISO`,
- a heartbeat that toggles whenever the source advances.

### HEX displays

`sw1:sw0` select which internal information is shown on HEX displays:

- BFPEXP constant,
- real constant,
- imaginary constant,
- status page with counters and flags.

This makes it possible to confirm both payload constants and live state without
opening a waveform viewer.

## Typical Bring-Up Flow

For a new board or wiring harness, the recommended order is:

1. build or simulate this top-level,
2. confirm `window_ready` becomes active,
3. probe `SCLK`, `CS_N`, and `MISO`,
4. perform one SPI transaction from the host,
5. verify the repeated BFPEXP pair and constant FFT pairs,
6. only after that move to the full `top_level_test`.

If this top-level works but the full top-level fails, the bug is probably not in
the SPI transport itself.

## Why It Is Better Than Testing `top_level_test` First

`top_level_test` is the correct integration target, but it is not the fastest
transport-debug target. `top_level_spi_fft_tx_diag` is better when:

- the Raspberry Pi sees no valid data,
- the pin mapping is under suspicion,
- the host parser may be wrong,
- the FFT core or microphone side is not yet trusted,
- you want a deterministic waveform for comparison.

## Simulation

Run from the repository root:

```bash
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
```

Associated filelist:

- `sim/manifest/filelists/mock_integration_top_level_spi_fft_tx_diag.f`

## Related Reading

- [spi_transport_walkthrough.md](spi_transport_walkthrough.md)
- [spi_fft_tx_adapter.md](spi_fft_tx_adapter.md)
- [simulation.md](simulation.md)
- [testbenches.md](testbenches.md)
