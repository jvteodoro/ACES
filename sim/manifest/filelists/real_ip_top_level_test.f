# Real-IP-oriented manifest.
# This file includes the Quartus ROM IP and the ACES integration path.
# Provide the real FFT implementation in an extra filelist, for example:
#   EXTRA_FILELIST=/path/to/r2fft_real.f sim/manifest/scripts/run_questa.sh top_level_test real
rtl/ip/rom/signals_rom_ip.v
rtl/frontend/i2s_master_clock_gen.sv
rtl/frontend/i2s_rx_adapter_24.sv
rtl/common/sample_width_adapter_24_to_18.sv
rtl/common/fft_control.sv
rtl/common/fft_dma_reader.sv
rtl/core/aces_audio_to_fft_pipeline.sv
rtl/core/aces.sv
rtl/stimulus/i2s_stimulus_manager_rom.sv
rtl/core/top_level_test.sv
tb/integration/tb_top_level_test_real.sv
