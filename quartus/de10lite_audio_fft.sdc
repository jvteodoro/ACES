# DE10-Lite system clock: onboard 50 MHz oscillator.
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]

# The microphone bit clock is generated synchronously from the 50 MHz clock.
# The fractional NCO averages 3.072 MHz (48 kHz * 64 I2S slots). Quartus
# requires an integer divide_by for generated clocks, so use divide-by-16
# (3.125 MHz), which is the conservative constraint for setup analysis.
create_generated_clock -name I2S_SCK \
    -source [get_ports {MAX10_CLK1_50}] \
    -divide_by 16 \
    [get_registers {aces:u_aces|i2s_master_clock_gen:u_i2s_master_clock_gen|sck_o}]

# VGA pixel domain: deterministic divide-by-2 clock from the 50 MHz source.
create_generated_clock -name VGA_PIXEL_CLK \
    -source [get_ports {MAX10_CLK1_50}] \
    -divide_by 2 \
    [get_registers {vga_pixel_clock_div2:u_vga_clock_div|pixel_clk}]

derive_clock_uncertainty
