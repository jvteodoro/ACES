# ACES

ACES is now a raw-audio FPGA/Raspberry Pi workspace.

The FPGA no longer computes FFT. It only:

- generates the microphone I2S clocks,
- selects microphone or ROM stimulus at the serial-data pin,
- forwards the raw I2S stream to the Raspberry Pi.

The Raspberry Pi now does:

- FFT,
- MFCC,
- event recording,
- comparison against the saved reference.

## Current Data Path

```text
microphone
  -> FPGA clock generation + raw I2S pass-through
  -> Raspberry Pi ALSA capture
  -> FFT on Raspberry Pi
  -> MFCC on Raspberry Pi
  -> event comparison
```

## Board Link To Raspberry Pi

In [`rtl/top/top_level_test.sv`](rtl/top/top_level_test.sv) the active FPGA-to-Pi
audio link is:

- `GPIO_1_D17`: `BCLK`
- `GPIO_1_D19`: `LRCLK / WS`
- `GPIO_1_D20`: `SD`

Additional debug mirrors remain on nearby GPIOs and are documented in
`docs/interface_and_pin_guide.md`.

## Main RTL Files

- `rtl/core/aces.sv`
- `rtl/frontend/i2s_master_clock_gen.sv`
- `rtl/stimulus/i2s_stimulus_manager_rom.sv`
- `rtl/top/top_level_test.sv`

The legacy FPGA FFT/SPI transport modules, diagnostic top-levels, and unused IP
wrappers were removed from the active project.

## Raspberry Pi Package

The maintained host package lives in
`submodules/ACES-RPi-interface/rpi3b_spi_fft/` and now centers on:

- `i2s_stream.py`
- `fpga_audio_adapter.py`
- `analyzer_from_fpga_fft.py`
- `live_spectrogram.py`
- `compararEvento.py`

More details and usage examples are in
`submodules/ACES-RPi-interface/rpi3b_spi_fft/README.md`.

## Simulation

The repository still keeps standalone mock benches for helper blocks such as:

- `hexa7seg`
- `i2s_master_clock_gen`
- `i2s_stimulus_manager_rom`

Example:

```bash
sim/manifest/scripts/run_questa.sh i2s_master_clock_gen
sim/manifest/scripts/run_questa.sh i2s_stimulus_manager_rom
sim/manifest/scripts/regression_mock.sh
```

## Raspberry Pi Bring-Up

See:

- `submodules/ACES-RPi-interface/rpi3b_spi_fft/README.md`
- `docs/interface_and_pin_guide.md`

The active flow uses ALSA/I2S capture, not `spidev`.
