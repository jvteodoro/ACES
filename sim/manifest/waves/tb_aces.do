quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 320
configure wave -valuecolwidth 120

add wave -divider {Stimulus}
add wave sim:/tb_aces/clk
add wave sim:/tb_aces/rst
add wave sim:/tb_aces/start_i
add wave sim:/tb_aces/stim_ready_o
add wave sim:/tb_aces/stim_busy_o
add wave sim:/tb_aces/stim_done_o
add wave -radix unsigned sim:/tb_aces/rom_addr_o
add wave -radix hex sim:/tb_aces/rom_data_i
add wave sim:/tb_aces/sck_i
add wave sim:/tb_aces/ws_i
add wave sim:/tb_aces/sd_i

add wave -divider {ACES}
add wave sim:/tb_aces/mic_chipen_o
add wave sim:/tb_aces/mic_sck_o
add wave sim:/tb_aces/mic_ws_o
add wave sim:/tb_aces/sample_valid_mic_o
add wave -radix decimal sim:/tb_aces/sample_mic_o
add wave -radix hex sim:/tb_aces/sample_24_dbg_o
add wave sim:/tb_aces/fft_sample_valid_o
add wave -radix decimal sim:/tb_aces/fft_sample_o
add wave sim:/tb_aces/sact_istream_o
add wave sim:/tb_aces/fft_run_o
add wave sim:/tb_aces/fft_done_o

add wave -divider {FFT TX}
add wave sim:/tb_aces/fft_tx_valid_o
add wave -radix unsigned sim:/tb_aces/fft_tx_index_o
add wave -radix decimal sim:/tb_aces/fft_tx_real_o
add wave -radix decimal sim:/tb_aces/fft_tx_imag_o
add wave sim:/tb_aces/fft_tx_last_o

update
