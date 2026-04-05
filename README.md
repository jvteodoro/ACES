# ACES

ACES is an FPGA audio/FFT workspace with reproducible RTL simulation, board-oriented top-levels, and a maintained Raspberry Pi host package.

The current branch exports FFT windows to the Raspberry Pi through SPI slave TX on the FPGA side while keeping the microphone/frontend path in I2S.

Both interface possibilities (SPI and I2S host-capture flow) are documented in:

- `docs/interface_and_pin_guide.md`

## Current Data Path

```text
I2S mic or ROM stimulus
    -> sample reconstruction
    -> 24b to 18b adaptation
    -> FFT ingest
    -> FFT core
    -> fft_dma_reader
    -> fft_tx_bridge_fifo
    -> spi_fft_tx_adapter
    -> Raspberry Pi SPI master + Python analysis
```

## Board Pin Map

`rtl/top/top_level_test.sv` keeps the Pi-facing FFT export on the same GPIO neighborhood used before:

- `GPIO_1_D27`: SPI `SCLK` input from Raspberry Pi
- `GPIO_1_D29`: SPI `CS_N` input from Raspberry Pi
- `GPIO_1_D31`: SPI `MISO` output to Raspberry Pi
- `GPIO_1_D25`: `window_ready` output to Raspberry Pi
- `GPIO_1_D23`: `tx_overflow_o` debug output

The microphone-side I2S pins are unchanged.

## Main RTL Files

- `rtl/core/aces.sv`: main ACES pipeline, now exposing SPI TX ports
- `rtl/frontend/spi_fft_tx_adapter.sv`: tagged FFT SPI slave backend
- `rtl/common/fft_tx_bridge_fifo.sv`: bridge FIFO between DMA readout and serial transport
- `rtl/top/top_level_test.sv`: board top-level
- `rtl/top/top_level_spi_fft_tx_diag.sv`: deterministic SPI TX diagnostic top-level

## Main Host Files

The Raspberry Pi SPI host package lives under `submodules/ACES-RPi-interface/rpi3b_spi_fft/`:

- `fpga_fft_adapter.py`
- `spi_stream.py`
- `analyzer_from_fpga_fft.py`
- `fft_spi_logger.py`
- `setup_rpi_spi_fft.sh`

For the I2S-based Raspberry Pi tooling currently present in this repository, see:

- `submodules/ACES-RPi-interface/rpi3b_i2s_fft/`

## Simulation

Run the supported mock benches from the repo root:

```bash
sim/manifest/scripts/run_questa.sh spi_fft_tx_adapter
sim/manifest/scripts/run_questa.sh fft_tx_spi_link
sim/manifest/scripts/run_questa.sh aces
sim/manifest/scripts/run_questa.sh top_level_spi_fft_tx_diag
sim/manifest/scripts/run_questa.sh top_level_test mock
```

PowerShell equivalents:

```powershell
.\sim\manifest\scripts\run_questa.ps1 spi_fft_tx_adapter
.\sim\manifest\scripts\run_questa.ps1 fft_tx_spi_link
.\sim\manifest\scripts\run_questa.ps1 top_level_spi_fft_tx_diag
.\sim\manifest\scripts\run_questa.ps1 top_level_test mock
```

Mock regression:

```bash
sim/manifest/scripts/regression_mock.sh
```

## Raspberry Pi Bring-Up

From `submodules/ACES-RPi-interface/rpi3b_spi_fft/`:

```bash
sudo ./setup_rpi_spi_fft.sh
```

After reboot:

```bash
ls -l /dev/spidev*
.venv/bin/python analyzer_from_fpga_fft.py \
  -D /dev/spidev0.0 \
  --spi-max-speed-hz 8000000 \
  --spi-mode 0 \
  --window-ready-line 23 \
  -r 48000 \
  --frame-bins 512 \
  --useful-bins 256 \
  --bfpexp-hold-frames 1
```

## Docs

- `docs/overview.md`
- `docs/spi_transport_walkthrough.md`
- `docs/architecture.md`
- `docs/simulation.md`
- `docs/testbenches.md`
- `docs/spi_fft_tx_adapter.md`
- `docs/top_level_spi_fft_tx_diag.md`
- `submodules/ACES-RPi-interface/rpi3b_spi_fft/README.md`
