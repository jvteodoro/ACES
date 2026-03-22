# Real-IP-oriented manifest for the board top-level.
# Provide the true FFT implementation in an extra filelist, for example:
#   EXTRA_FILELIST=/path/to/r2fft_real.f sim/manifest/scripts/run_questa.sh top_level_test real
# The repository already contributes the support IP wrappers and memory tables
# needed by the real `r2fft_tribuf_impl` flow (signals ROM, twiddle ROM, DPRAM).
rtl/ip/rom/signals_rom_ip.v
rtl/ip/fft/twrom.v
rtl/ip/fft/dpram.v
rtl/common/hexa7seg.v
rtl/frontend/i2s_master_clock_gen.sv
rtl/frontend/i2s_rx_adapter_24.sv
rtl/common/sample_width_adapter_24_to_18.sv
rtl/common/fft_control.sv
rtl/common/fft_dma_reader.sv
rtl/core/aces_audio_to_fft_pipeline.sv
rtl/core/aces.sv
rtl/stimulus/i2s_stimulus_manager_rom.sv
rtl/top/top_level_test.sv
tb/integration/tb_top_level_test.sv
