quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 320
configure wave -valuecolwidth 140

add wave -divider {Verification checkpoints}
add wave sim:/tb_i2s_fft_tx_adapter/clk
add wave sim:/tb_i2s_fft_tx_adapter/rst
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/sck_toggle_count
add wave sim:/tb_i2s_fft_tx_adapter/sck_timing_armed_r
add wave sim:/tb_i2s_fft_tx_adapter/saw_overflow_r
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/captured_write_idx
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/captured_read_idx

add wave -divider {FFT source stimulus}
add wave sim:/tb_i2s_fft_tx_adapter/fft_valid_i
add wave sim:/tb_i2s_fft_tx_adapter/fft_ready_o
add wave sim:/tb_i2s_fft_tx_adapter/fifo_full_o
add wave sim:/tb_i2s_fft_tx_adapter/fifo_empty_o
add wave sim:/tb_i2s_fft_tx_adapter/overflow_o
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/fifo_level_o
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/fft_real_i
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/fft_imag_i
add wave sim:/tb_i2s_fft_tx_adapter/fft_last_i
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/bfpexp_i

add wave -divider {I2S serialized output}
add wave sim:/tb_i2s_fft_tx_adapter/i2s_sck_o
add wave sim:/tb_i2s_fft_tx_adapter/i2s_ws_o
add wave sim:/tb_i2s_fft_tx_adapter/i2s_sd_o

add wave -divider {Monitor / scoreboard}
add wave sim:/tb_i2s_fft_tx_adapter/mon_slot_ws_r
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/mon_slot_count_r
add wave -radix hex sim:/tb_i2s_fft_tx_adapter/mon_slot_shift_r
add wave sim:/tb_i2s_fft_tx_adapter/mon_prev_slot_valid_r
add wave sim:/tb_i2s_fft_tx_adapter/mon_prev_slot_ws_r
add wave -radix hex sim:/tb_i2s_fft_tx_adapter/mon_right_word_r
add wave sim:/tb_i2s_fft_tx_adapter/mon_have_right_r
add wave -radix binary sim:/tb_i2s_fft_tx_adapter/captured_tag_mem
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/captured_left_mem
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/captured_right_mem
add wave -radix binary sim:/tb_i2s_fft_tx_adapter/expected_tag_mem
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/expected_left_mem
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/expected_right_mem

add wave -divider {DUT internals}
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/dut/div_cnt_r
add wave sim:/tb_i2s_fft_tx_adapter/dut/channel_r
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/dut/slot_bit_r
add wave sim:/tb_i2s_fft_tx_adapter/dut/input_window_in_progress_r
add wave sim:/tb_i2s_fft_tx_adapter/dut/active_valid_r
add wave -radix binary sim:/tb_i2s_fft_tx_adapter/dut/active_tag_r
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/dut/active_left_r
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/dut/active_right_r
add wave -radix unsigned sim:/tb_i2s_fft_tx_adapter/dut/active_hold_frames_r
add wave sim:/tb_i2s_fft_tx_adapter/dut/pending_valid_r
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/dut/pending_real_r
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/dut/pending_imag_r
add wave sim:/tb_i2s_fft_tx_adapter/dut/pending_last_r
add wave -radix decimal sim:/tb_i2s_fft_tx_adapter/dut/pending_bfpexp_r

update
