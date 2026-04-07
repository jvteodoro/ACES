# FPGA <-> Raspberry Pi Interface And Pin Guide

This guide documents the active project path now:

1. The FPGA only generates the I2S clocks and forwards the raw serial stream.
2. The Raspberry Pi receives raw audio over I2S and computes FFT/MFCC locally.

## 1) Active I2S Audio Link

Raspberry Pi capture tooling expects:

- `GPIO18` (pin 12): `PCM_CLK` / I2S `BCLK`
- `GPIO19` (pin 35): `PCM_FS` / I2S `LRCLK/WS`
- `GPIO20` (pin 38): `PCM_DIN` / I2S serial data input
- `GPIO21` (pin 40): `PCM_DOUT` (typically unused for capture-only)

No SPI transport or FFT-side handshake is used anymore.

## 2) External Button And LED On Raspberry Pi

`rpi3b_spi_fft/codigo.py` (button bridge, polling):

- Uses polling, not interrupts.
- Evidence in code: loop with `read_active()` + `time.sleep(args.poll_seconds)`.
- GPIO is runtime-configurable with required `--button-line`.

`rpi3b_spi_fft/gpio_button_bridge_with_interrupt.py` (button bridge, interrupt mode):

- Uses GPIO edge events (interrupt-style) via `gpiod` event APIs.
- Keeps the same trigger-file behavior and debounce parameter.

`rpi3b_spi_fft/led_sinal_igual.py` (LED monitor):

- Also runtime-configurable with required `--led-line`.
- Reads similarity state file and drives a selected GPIO line.

## 3) Active `top_level_test` Pins (only signals actually used)

### FPGA on-board pins used by logic

| Pin | Net | Direction | Used as |
| --- | --- | --- | --- |
| `PIN_U13` | `sw0` | Input | Stimulus start (`stim_start_i`) |
| `PIN_V13` | `sw1` | Input | Stimulus example select bit 0 |
| `PIN_T13` | `sw2` | Input | Stimulus example select bit 1 |
| `PIN_T12` | `sw3` | Input | Stimulus example select bit 2 |
| `PIN_AA15` | `sw4` | Input | Stimulus loop mode bit 0 |
| `PIN_AB15` | `sw5` | Input | Stimulus loop mode bit 1 |
| `PIN_AA14` | `sw6` | Input | Stimulus LR select |
| `PIN_AA13` | `sw7` | Input | Audio source select (`stim_sd_o` vs `mic_sd_o`) |
| `PIN_M9` | `clock_50` | Input | Main FPGA clock (`clk`) |
| `PIN_AA2` | `ledr0` | Output | `dbg_led_capture_r[0]` |
| `PIN_AA1` | `ledr1` | Output | `dbg_led_capture_r[1]` |
| `PIN_W2` | `ledr2` | Output | `dbg_led_capture_r[2]` |
| `PIN_Y3` | `ledr3` | Output | `dbg_led_capture_r[3]` |
| `PIN_N2` | `ledr4` | Output | `dbg_led_capture_r[4]` |
| `PIN_N1` | `ledr5` | Output | `dbg_led_capture_r[5]` |
| `PIN_U2` | `ledr6` | Output | `dbg_led_capture_r[6]` |
| `PIN_U1` | `ledr7` | Output | `dbg_led_capture_r[7]` |
| `PIN_L2` | `ledr8` | Output | `dbg_led_capture_r[8]` |
| `PIN_L1` | `ledr9` | Output | `dbg_led_capture_r[9]` |
| `PIN_U21` | `hex0_o[0]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_V21` | `hex0_o[1]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_W22` | `hex0_o[2]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_W21` | `hex0_o[3]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_Y22` | `hex0_o[4]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_Y21` | `hex0_o[5]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_AA22` | `hex0_o[6]` | Output | 7-seg segment from `hex0_i` (`dbg_hex_capture_r[3:0]`) |
| `PIN_AA20` | `hex1_o[0]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_AB20` | `hex1_o[1]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_AA19` | `hex1_o[2]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_AA18` | `hex1_o[3]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_AB18` | `hex1_o[4]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_AA17` | `hex1_o[5]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_U22` | `hex1_o[6]` | Output | 7-seg segment from `hex1_i` (`dbg_hex_capture_r[7:4]`) |
| `PIN_Y19` | `hex2_o[0]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_AB17` | `hex2_o[1]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_AA10` | `hex2_o[2]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_Y14` | `hex2_o[3]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_V14` | `hex2_o[4]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_AB22` | `hex2_o[5]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_AB21` | `hex2_o[6]` | Output | 7-seg segment from `hex2_i` (`dbg_hex_capture_r[11:8]`) |
| `PIN_Y16` | `hex3_o[0]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_W16` | `hex3_o[1]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_Y17` | `hex3_o[2]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_V16` | `hex3_o[3]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_U17` | `hex3_o[4]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_V18` | `hex3_o[5]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_V19` | `hex3_o[6]` | Output | 7-seg segment from `hex3_i` (`dbg_hex_capture_r[15:12]`) |
| `PIN_U20` | `hex4_o[0]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_Y20` | `hex4_o[1]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_V20` | `hex4_o[2]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_U16` | `hex4_o[3]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_U15` | `hex4_o[4]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_Y15` | `hex4_o[5]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_P9` | `hex4_o[6]` | Output | 7-seg segment from `hex4_i` (`dbg_hex_capture_r[19:16]`) |
| `PIN_N9` | `hex5_o[0]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |
| `PIN_M8` | `hex5_o[1]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |
| `PIN_T14` | `hex5_o[2]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |
| `PIN_P14` | `hex5_o[3]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |
| `PIN_C1` | `hex5_o[4]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |
| `PIN_C2` | `hex5_o[5]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |
| `PIN_W19` | `hex5_o[6]` | Output | 7-seg segment from `hex5_i` (`dbg_hex_capture_r[23:20]`) |

Unused on-board nets in current logic path: `reset_n`, `clock2_50`, `clock3_50`, `clock4_50`.

### FPGA header pins used by logic (`top_level_test.sv`)

| Pin | GPIO | Direction | Signal/function |
| --- | --- | --- | --- |
| `PIN_A12` | `gpio_1_d1` | Input | Internal reset source (`rst`) |
| `PIN_B13` | `gpio_1_d5` | Input | Debug capture pulse for LEDs (`dbg_capture_leds_i`) |
| `PIN_D13` | `gpio_1_d7` | Input | Debug capture pulse for HEX (`dbg_capture_hex_i`) |
| `PIN_G17` | `gpio_1_d9` | Input | Debug capture pulse for GPIO snapshot (`dbg_capture_gpio_i`) |
| `PIN_J18` | `gpio_1_d11` | Input | Debug capture clear (`dbg_capture_clear_i`) |
| `PIN_C13` | `gpio_1_d6` | Input | External microphone serial data (`mic_sd_o`) |
| `PIN_U7` | `key0` | Input | Debug page select bit 0 |
| `PIN_W9` | `key1` | Input | Debug page select bit 1 |
| `PIN_M7` | `key2` | Input | Debug stage select bit 0 |
| `PIN_M6` | `key3` | Input | Debug stage select bit 1 |
| `PIN_F15` | `gpio_1_d27` | Input | Declared in board envelope, unused in active logic |
| `PIN_F12` | `gpio_1_d29` | Input | Declared in board envelope, unused in active logic |
| `PIN_H16` | `gpio_1_d0` | Output | I2S LR select from ACES (`mic_lr_sel_o`) |
| `PIN_H15` | `gpio_1_d2` | Output | I2S `WS/LRCLK` from ACES (`i2s_ws_o`) |
| `PIN_A13` | `gpio_1_d4` | Output | I2S `SCK/BCLK` from ACES (`i2s_sck_o`) |
| `PIN_A15` | `gpio_1_d17` | Output | I2S `BCLK` mirrored to Raspberry Pi |
| `PIN_L8` | `gpio_1_d19` | Output | I2S `LRCLK/WS` mirrored to Raspberry Pi |
| `PIN_A14` | `gpio_1_d20` | Output | I2S serial data mirrored to Raspberry Pi |
| `PIN_B15` | `gpio_1_d21` | Output | Raw microphone serial data before source select |
| `PIN_E14` | `gpio_1_d23` | Output | ROM stimulus serial data |
| `PIN_E16` | `gpio_1_d25` | Output | Source-select flag (`0` = mic, `1` = stimulus) |
| `PIN_G16` | `gpio_1_d30` | Output | `mic_chipen_o` |
| `PIN_G15` | `gpio_1_d31` | Output | `mic_lr_sel_o` |
| `PIN_G13` | `gpio_1_d32` | Output | `stim_busy_o` |
| `PIN_J17` | `gpio_1_d34` | Output | `stim_window_done_o` |
| `PIN_R21` | `gpio_0_d12` | Output | Mirror of debug stage select bit 0 (`gpio_1_d15`) |
| `PIN_N20` | `gpio_0_d14` | Output | Mirror of debug stage select bit 1 (`gpio_1_d13`) |
| `PIN_M22` | `gpio_0_d16` | Output | Mirror of debug page select bit 0 (`gpio_1_d19`) |
| `PIN_L22` | `gpio_0_d18` | Output | Mirror of debug page select bit 1 (`gpio_1_d17`) |

The active Raspberry Pi audio link uses `gpio_1_d17`, `gpio_1_d19`, and
`gpio_1_d20` as the raw I2S bridge from FPGA to host, with no sample
reconstruction inside the FPGA.

All other header GPIO lines are currently declared but not driven/read by active logic in `top_level_test.sv`.
