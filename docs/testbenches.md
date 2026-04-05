# Testbenches

This page explains the intent of the maintained benches, especially the ones you
should trust first when working on the SPI export path.

## Supported SPI-Path Benches

The main benches that exercise the active FFT export path are:

- `tb_spi_fft_tx_adapter`
- `tb_fft_tx_spi_link`
- `tb_top_level_spi_fft_tx_diag`
- `tb_top_level_test`

These are not redundant copies of the same idea. Each one validates a different
layer of the transport stack.

## Which Bench To Run First

- Changing word packing, tag meaning, BFPEXP repetition, or serializer logic:
  run `tb_spi_fft_tx_adapter` first.
- Changing FIFO timing assumptions or valid/ready interaction:
  run `tb_fft_tx_spi_link` first.
- Changing board-facing diagnostic behavior or pin mirroring:
  run `tb_top_level_spi_fft_tx_diag` first.
- Changing system integration in the real top-level:
  run `tb_top_level_test`.

## Bench Roles

### `tb_spi_fft_tx_adapter`

Scope:

- unit bench for `rtl/frontend/spi_fft_tx_adapter.sv`

Why it matters:

- this is the fastest executable spec for the transport contract,
- it reconstructs words exactly as a host would,
- it catches most regressions before full integration benches are needed.

What it checks:

- tagged word packing,
- BFPEXP hold behavior,
- SPI byte ordering,
- multiple windows in sequence,
- idle response before a window is ready,
- nominal no-overflow behavior.

### `tb_fft_tx_spi_link`

Scope:

```text
fft_tx_bridge_fifo -> spi_fft_tx_adapter
```

Why it matters:

- it validates the timing boundary between reusable FIFO behavior and adapter
  consumption,
- it proves that buffering semantics do not corrupt the transaction contract.

What it checks:

- FIFO alignment,
- valid/ready to drain behavior,
- multi-window handoff,
- nominal no-overflow behavior in both FIFO and adapter.

### `tb_top_level_spi_fft_tx_diag`

Scope:

- board-facing diagnostic top-level using deterministic synthetic data

Why it matters:

- it verifies the real SPI transport in a simplified top-level,
- it is the closest simulation match to lab bring-up before the full ACES
  datapath is involved.

What it checks:

- fixed-pattern payload visibility on top-level pins,
- deterministic BFPEXP and FFT sequence,
- `window_ready` behavior,
- repeatability across multiple reads.

### `tb_top_level_test`

Scope:

- main board-oriented integration bench

Why it matters:

- it proves that the full ACES datapath still reaches the host through the
  active SPI transport.

What it checks:

- sample ingest path,
- FFT output stream,
- SPI export path using the expected tagged pairs,
- top-level pin reflection,
- mock-flow smoke on the active board top-level.

## Other Supported Benches

These are not transport-only benches, but they remain useful when debugging the
upstream side of a suspected SPI issue:

- `tb_fft_tx_bridge_fifo`
- `tb_fft_dma_reader`
- `tb_aces_audio_to_fft_pipeline`
- `tb_aces`
- `tb_top_level_fft_isolated`

## Filelists

The current SPI-related manifest filelists are:

- `sim/manifest/filelists/mock_unit_spi_fft_tx_adapter.f`
- `sim/manifest/filelists/mock_integration_fft_tx_spi_link.f`
- `sim/manifest/filelists/mock_integration_top_level_spi_fft_tx_diag.f`
- `sim/manifest/filelists/mock_integration_top_level_test.f`

## Running

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
```

## Practical Advice

If you are unsure where a failure belongs, start from the smallest bench that
still observes the symptom:

- wrong tag or wrong payload:
  start with `tb_spi_fft_tx_adapter`
- correct unit behavior but broken drain timing:
  move to `tb_fft_tx_spi_link`
- correct transport but bad board-facing behavior:
  move to `tb_top_level_spi_fft_tx_diag`
- correct diagnostic top but broken full system:
  move to `tb_top_level_test`
