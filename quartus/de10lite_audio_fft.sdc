# DE10-Lite system clock: onboard 50 MHz oscillator.
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]

# The microphone clock is generated synchronously from the system clock.
derive_clock_uncertainty
