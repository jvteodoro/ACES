quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 380
configure wave -valuecolwidth 140
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

add wave -divider {TB Control}
add wave sim:/tb_top_level_test/tb_clk_drive
add wave sim:/tb_top_level_test/tb_rst_drive
add wave sim:/tb_top_level_test/sw0
add wave sim:/tb_top_level_test/sw1
add wave sim:/tb_top_level_test/sw2
add wave sim:/tb_top_level_test/sw3
add wave sim:/tb_top_level_test/sw4
add wave sim:/tb_top_level_test/sw5
add wave sim:/tb_top_level_test/sw6
add wave sim:/tb_top_level_test/sw7
add wave -radix unsigned sim:/tb_top_level_test/active_example_r
add wave sim:/tb_top_level_test/example_in_progress_r

add wave -divider {TB Scoreboard}
add wave -radix unsigned sim:/tb_top_level_test/sample24_count_r
add wave -radix unsigned sim:/tb_top_level_test/sample18_count_r
add wave -radix unsigned sim:/tb_top_level_test/fft_bin_count_r
add wave -radix unsigned sim:/tb_top_level_test/serial_expected_write_idx_r
add wave -radix unsigned sim:/tb_top_level_test/serial_expected_read_idx_r
add wave -radix unsigned sim:/tb_top_level_test/serial_frames_seen_r
add wave -radix unsigned sim:/tb_top_level_test/extra_sample24_count_r
add wave -radix unsigned sim:/tb_top_level_test/extra_sample18_count_r
add wave -radix unsigned sim:/tb_top_level_test/extra_fft_bin_count_r
add wave -radix unsigned sim:/tb_top_level_test/extra_serial_frames_r
add wave sim:/tb_top_level_test/frame_bfpexp_valid_r
add wave -radix decimal sim:/tb_top_level_test/frame_bfpexp_r
add wave sim:/tb_top_level_test/stim_done_seen_r
add wave sim:/tb_top_level_test/fft_done_seen_r
add wave sim:/tb_top_level_test/fft_frame_done_r
add wave sim:/tb_top_level_test/tx_overflow_seen_r

add wave -divider {Stimulus Manager}
add wave sim:/tb_top_level_test/dut/stim_ready_o
add wave sim:/tb_top_level_test/dut/stim_busy_o
add wave sim:/tb_top_level_test/dut/stim_done_o
add wave sim:/tb_top_level_test/dut/stim_window_done_o
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_current_example_o
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_current_point_o
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_rom_addr_dbg_o
add wave -radix decimal sim:/tb_top_level_test/dut/stim_current_sample_dbg_o
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_bit_index_o
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_state_dbg_o
add wave sim:/tb_top_level_test/dut/stim_sd_o
add wave sim:/tb_top_level_test/dut/mic_sd_internal

add wave -divider {Frontend I2S}
add wave sim:/tb_top_level_test/dut/i2s_sck_o
add wave sim:/tb_top_level_test/dut/i2s_ws_o
add wave sim:/tb_top_level_test/dut/mic_chipen_o
add wave sim:/tb_top_level_test/dut/mic_lr_sel_o
add wave sim:/tb_top_level_test/dut/sample_valid_mic_o
add wave -radix decimal sim:/tb_top_level_test/dut/sample_24_dbg_o
add wave -radix decimal sim:/tb_top_level_test/dut/sample_mic_o
add wave sim:/tb_top_level_test/dut/fft_sample_valid_o
add wave -radix decimal sim:/tb_top_level_test/dut/fft_sample_o
add wave sim:/tb_top_level_test/dut/sact_istream_o
add wave -radix decimal sim:/tb_top_level_test/dut/sdw_istream_real_o
add wave -radix decimal sim:/tb_top_level_test/dut/sdw_istream_imag_o

add wave -divider {Frontend Internals}
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/u_i2s_rx/sample_valid_o
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/u_i2s_rx/sample_24_o
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_valid_24
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_24
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_valid_18
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_18
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_toggle_mic
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/toggle_sync_1
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/toggle_sync_2
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/toggle_seen_clk
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/new_sample_clk
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_pulse_clk
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/sample_reg

add wave -divider {FFT Control And DMA}
add wave sim:/tb_top_level_test/dut/fft_run_o
add wave sim:/tb_top_level_test/dut/fft_done_o
add wave -radix unsigned sim:/tb_top_level_test/dut/fft_input_buffer_status_o
add wave -radix unsigned sim:/tb_top_level_test/dut/fft_status_o
add wave -radix decimal sim:/tb_top_level_test/dut/bfpexp_o
add wave sim:/tb_top_level_test/dut/u_aces/dmaact_i
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/dmaa_i
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/dmadr_real_o
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/dmadr_imag_o
add wave sim:/tb_top_level_test/dut/fft_tx_valid_o
add wave sim:/tb_top_level_test/dut/fft_tx_last_o
add wave -radix unsigned sim:/tb_top_level_test/dut/fft_tx_index_o
add wave -radix decimal sim:/tb_top_level_test/dut/fft_tx_real_o
add wave -radix decimal sim:/tb_top_level_test/dut/fft_tx_imag_o

add wave -divider {TX FIFO Path}
add wave sim:/tb_top_level_test/dut/u_aces/tx_fifo_wrreq
add wave sim:/tb_top_level_test/dut/u_aces/tx_fifo_rdreq
add wave sim:/tb_top_level_test/dut/u_aces/tx_fifo_wrfull
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/tx_fifo_level_r
add wave sim:/tb_top_level_test/dut/u_aces/tx_fifo_word_valid_r
add wave sim:/tb_top_level_test/dut/u_aces/tx_fifo_read_inflight_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/tx_fft_read_index_r
add wave sim:/tb_top_level_test/dut/u_aces/tx_fft_valid_i
add wave sim:/tb_top_level_test/dut/u_aces/tx_fft_ready_o
add wave sim:/tb_top_level_test/dut/tx_overflow_o
add wave sim:/tb_top_level_test/dut/u_aces/tx_overflow_from_adapter_o
add wave sim:/tb_top_level_test/dut/u_aces/tx_fifo_overflow_o
add wave -radix hex sim:/tb_top_level_test/dut/u_aces/tx_fifo_word_r
add wave -radix hex sim:/tb_top_level_test/dut/u_aces/tx_fifo_rdata

add wave -divider {I2S FFT TX Adapter}
add wave sim:/tb_top_level_test/dut/tx_i2s_sck_o
add wave sim:/tb_top_level_test/dut/tx_i2s_ws_o
add wave sim:/tb_top_level_test/dut/tx_i2s_sd_o
add wave sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/active_valid_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/active_tag_r
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/active_left_r
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/active_right_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/active_hold_frames_r
add wave sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/pending_valid_r
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/pending_real_r
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/pending_imag_r
add wave sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/pending_last_r
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/pending_bfpexp_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/channel_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_i2s_fft_tx_adapter/slot_bit_r

add wave -divider {TX Serial Decoder}
add wave sim:/tb_top_level_test/tx_mon_slot_ws_r
add wave -radix unsigned sim:/tb_top_level_test/tx_mon_slot_count_r
add wave -radix hex sim:/tb_top_level_test/tx_mon_slot_shift_r
add wave sim:/tb_top_level_test/tx_mon_prev_slot_valid_r
add wave sim:/tb_top_level_test/tx_mon_prev_slot_ws_r
add wave sim:/tb_top_level_test/tx_mon_have_right_r
add wave -radix hex sim:/tb_top_level_test/tx_mon_right_word_r
add wave -radix unsigned sim:/tb_top_level_test/tx_sck_toggle_count_r
add wave sim:/tb_top_level_test/tx_sck_timing_armed_r

wave zoom full
update
