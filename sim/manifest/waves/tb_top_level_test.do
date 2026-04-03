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
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/valid_reg
add wave sim:/tb_top_level_test/dut/u_aces/u_audio_to_fft_pipeline/valid_d
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

add wave -divider {SPI Host Drive}
add wave sim:/tb_top_level_test/tb_spi_sclk_drive
add wave sim:/tb_top_level_test/tb_spi_cs_n_drive
add wave sim:/tb_top_level_test/gpio_1_d27
add wave sim:/tb_top_level_test/gpio_1_d29
add wave sim:/tb_top_level_test/gpio_1_d31
add wave sim:/tb_top_level_test/gpio_1_d25

add wave -divider {SPI FFT TX Adapter}
add wave sim:/tb_top_level_test/dut/tx_spi_sclk_i
add wave sim:/tb_top_level_test/dut/tx_spi_cs_n_i
add wave sim:/tb_top_level_test/dut/tx_spi_miso_o
add wave sim:/tb_top_level_test/dut/tx_spi_window_ready_o
add wave sim:/tb_top_level_test/dut/tx_overflow_o
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fft_ready_o
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_full_o
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_empty_o
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/overflow_o
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_level_o
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/window_ready_o
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/spi_active_o

add wave -divider {SPI TX Internals}
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/complete_windows_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/spi_transaction_active_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/tx_window_in_progress_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/wait_next_fft_pair_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/wait_fifo_refresh_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/byte_complete_pending_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/bfpexp_hold_remaining_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/active_pair_kind_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/active_fft_last_r
add wave -radix hex sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/active_left_word_r
add wave -radix hex sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/active_right_word_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/pair_byte_idx_r
add wave -radix hex sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/current_byte_r
add wave -radix unsigned sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/current_bit_idx_r
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_valid_w
add wave sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_last_w
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_real_w
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_imag_w
add wave -radix decimal sim:/tb_top_level_test/dut/u_aces/u_spi_fft_tx_adapter/fifo_bfpexp_w

wave zoom full
update
