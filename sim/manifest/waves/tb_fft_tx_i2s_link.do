quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 340
configure wave -valuecolwidth 140

add wave -divider {Verification checkpoints}
add wave sim:/tb_fft_tx_i2s_link/clk
add wave sim:/tb_fft_tx_i2s_link/rst
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/max_fifo_level_r
add wave sim:/tb_fft_tx_i2s_link/saw_fifo_overflow_r
add wave sim:/tb_fft_tx_i2s_link/saw_adapter_overflow_r
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/sck_toggle_count
add wave sim:/tb_fft_tx_i2s_link/sck_timing_armed_r
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/captured_write_idx
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/captured_read_idx

add wave -divider {FIFO stimulus and handshake}
add wave sim:/tb_fft_tx_i2s_link/push_i
add wave sim:/tb_fft_tx_i2s_link/bridge_pop_i
add wave sim:/tb_fft_tx_i2s_link/adapter_ready_o
add wave sim:/tb_fft_tx_i2s_link/fifo_valid_o
add wave sim:/tb_fft_tx_i2s_link/fifo_full_o
add wave sim:/tb_fft_tx_i2s_link/fifo_empty_o
add wave sim:/tb_fft_tx_i2s_link/fifo_overflow_o
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/fifo_level_o
add wave -radix decimal sim:/tb_fft_tx_i2s_link/fft_real_i
add wave -radix decimal sim:/tb_fft_tx_i2s_link/fft_imag_i
add wave sim:/tb_fft_tx_i2s_link/fft_last_i
add wave -radix decimal sim:/tb_fft_tx_i2s_link/bfpexp_i
add wave -radix decimal sim:/tb_fft_tx_i2s_link/fifo_real_o
add wave -radix decimal sim:/tb_fft_tx_i2s_link/fifo_imag_o
add wave sim:/tb_fft_tx_i2s_link/fifo_last_o
add wave -radix decimal sim:/tb_fft_tx_i2s_link/fifo_bfpexp_o

add wave -divider {Adapter status and serial output}
add wave sim:/tb_fft_tx_i2s_link/adapter_fifo_full_o
add wave sim:/tb_fft_tx_i2s_link/adapter_fifo_empty_o
add wave sim:/tb_fft_tx_i2s_link/adapter_overflow_o
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/adapter_fifo_level_o
add wave sim:/tb_fft_tx_i2s_link/i2s_sck_o
add wave sim:/tb_fft_tx_i2s_link/i2s_ws_o
add wave sim:/tb_fft_tx_i2s_link/i2s_sd_o

add wave -divider {Monitor / scoreboard}
add wave sim:/tb_fft_tx_i2s_link/mon_slot_ws_r
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/mon_slot_count_r
add wave -radix hex sim:/tb_fft_tx_i2s_link/mon_slot_shift_r
add wave sim:/tb_fft_tx_i2s_link/mon_prev_slot_valid_r
add wave sim:/tb_fft_tx_i2s_link/mon_prev_slot_ws_r
add wave -radix hex sim:/tb_fft_tx_i2s_link/mon_right_word_r
add wave sim:/tb_fft_tx_i2s_link/mon_have_right_r
add wave -radix binary sim:/tb_fft_tx_i2s_link/captured_tag_mem
add wave -radix decimal sim:/tb_fft_tx_i2s_link/captured_left_mem
add wave -radix decimal sim:/tb_fft_tx_i2s_link/captured_right_mem
add wave -radix binary sim:/tb_fft_tx_i2s_link/expected_tag_mem
add wave -radix decimal sim:/tb_fft_tx_i2s_link/expected_left_mem
add wave -radix decimal sim:/tb_fft_tx_i2s_link/expected_right_mem

add wave -divider {FIFO internals}
add wave -radix binary sim:/tb_fft_tx_i2s_link/u_fifo/fifo_mem
add wave -radix hex sim:/tb_fft_tx_i2s_link/u_fifo/head_word
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/u_fifo/wptr_r
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/u_fifo/rptr_r

add wave -divider {Adapter internals}
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/u_adapter/div_cnt_r
add wave sim:/tb_fft_tx_i2s_link/u_adapter/channel_r
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/u_adapter/slot_bit_r
add wave sim:/tb_fft_tx_i2s_link/u_adapter/input_window_in_progress_r
add wave sim:/tb_fft_tx_i2s_link/u_adapter/active_valid_r
add wave -radix binary sim:/tb_fft_tx_i2s_link/u_adapter/active_tag_r
add wave -radix decimal sim:/tb_fft_tx_i2s_link/u_adapter/active_left_r
add wave -radix decimal sim:/tb_fft_tx_i2s_link/u_adapter/active_right_r
add wave -radix unsigned sim:/tb_fft_tx_i2s_link/u_adapter/active_hold_frames_r
add wave sim:/tb_fft_tx_i2s_link/u_adapter/pending_valid_r
add wave -radix decimal sim:/tb_fft_tx_i2s_link/u_adapter/pending_real_r
add wave -radix decimal sim:/tb_fft_tx_i2s_link/u_adapter/pending_imag_r
add wave sim:/tb_fft_tx_i2s_link/u_adapter/pending_last_r
add wave -radix decimal sim:/tb_fft_tx_i2s_link/u_adapter/pending_bfpexp_r

update
