quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 360
configure wave -valuecolwidth 140
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

add wave -divider {Lab stimulus / board controls}
add wave sim:/tb_top_level_test/tb_clk_drive
add wave sim:/tb_top_level_test/tb_rst_drive
add wave sim:/tb_top_level_test/tb_capture_leds_drive
add wave sim:/tb_top_level_test/tb_capture_hex_drive
add wave sim:/tb_top_level_test/tb_capture_gpio_drive
add wave sim:/tb_top_level_test/tb_capture_clear_drive
add wave sim:/tb_top_level_test/sw0
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_example_sel_i
add wave -radix unsigned sim:/tb_top_level_test/dut/stim_loop_mode_i
add wave sim:/tb_top_level_test/dut/stim_lr_sel_i
add wave -radix binary sim:/tb_top_level_test/dut/dbg_stage_sel
add wave -radix binary sim:/tb_top_level_test/dut/dbg_page_sel

add wave -divider {Board-visible captured outputs}
add wave -radix binary sim:/tb_top_level_test/dut/dbg_led_capture_r
add wave -radix hex sim:/tb_top_level_test/dut/dbg_hex_capture_r
add wave -radix binary sim:/tb_top_level_test/dut/dbg_gpio_capture_r
add wave sim:/tb_top_level_test/ledr0
add wave sim:/tb_top_level_test/ledr1
add wave sim:/tb_top_level_test/ledr2
add wave sim:/tb_top_level_test/ledr3
add wave sim:/tb_top_level_test/ledr4
add wave sim:/tb_top_level_test/ledr5
add wave sim:/tb_top_level_test/ledr6
add wave sim:/tb_top_level_test/ledr7
add wave sim:/tb_top_level_test/ledr8
add wave sim:/tb_top_level_test/ledr9
add wave sim:/tb_top_level_test/hex0_o
add wave sim:/tb_top_level_test/hex1_o
add wave sim:/tb_top_level_test/hex2_o
add wave sim:/tb_top_level_test/hex3_o
add wave sim:/tb_top_level_test/hex4_o
add wave sim:/tb_top_level_test/hex5_o
add wave sim:/tb_top_level_test/gpio_0_d3
add wave sim:/tb_top_level_test/gpio_1_d2
add wave sim:/tb_top_level_test/gpio_1_d3
add wave sim:/tb_top_level_test/gpio_1_d4

add wave -divider {Live debug mux before capture}
add wave -radix binary sim:/tb_top_level_test/dut/dbg_led_live
add wave -radix hex sim:/tb_top_level_test/dut/dbg_hex_live
add wave -radix binary sim:/tb_top_level_test/dut/dbg_gpio_live
add wave -radix hex sim:/tb_top_level_test/dut/hex0_i
add wave -radix hex sim:/tb_top_level_test/dut/hex1_i
add wave -radix hex sim:/tb_top_level_test/dut/hex2_i
add wave -radix hex sim:/tb_top_level_test/dut/hex3_i
add wave -radix hex sim:/tb_top_level_test/dut/hex4_i
add wave -radix hex sim:/tb_top_level_test/dut/hex5_i

add wave -divider {Stage 0 - stimulus manager}
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
add wave sim:/tb_top_level_test/dut/mic_sd_internal

add wave -divider {Stage 1 - I2S and sample reconstruction}
add wave sim:/tb_top_level_test/dut/i2s_sck_o
add wave sim:/tb_top_level_test/dut/i2s_ws_o
add wave sim:/tb_top_level_test/dut/mic_chipen_o
add wave sim:/tb_top_level_test/dut/mic_lr_sel_o
add wave sim:/tb_top_level_test/dut/i2s_sd_o
add wave sim:/tb_top_level_test/dut/sample_valid_mic_o
add wave -radix decimal sim:/tb_top_level_test/dut/sample_24_dbg_o
add wave -radix decimal sim:/tb_top_level_test/dut/sample_mic_o
add wave -radix decimal sim:/tb_top_level_test/dut/fft_sample_o
add wave sim:/tb_top_level_test/dut/fft_sample_valid_o
add wave sim:/tb_top_level_test/dut/sact_istream_o

add wave -divider {Stage 2 - FFT ingest / control}
add wave sim:/tb_top_level_test/dut/fft_run_o
add wave sim:/tb_top_level_test/dut/fft_done_o
add wave -radix unsigned sim:/tb_top_level_test/dut/fft_input_buffer_status_o
add wave -radix unsigned sim:/tb_top_level_test/dut/fft_status_o
add wave -radix decimal sim:/tb_top_level_test/dut/sdw_istream_real_o
add wave -radix decimal sim:/tb_top_level_test/dut/sdw_istream_imag_o
add wave -radix decimal sim:/tb_top_level_test/dut/bfpexp_o

add wave -divider {Stage 3 - FFT bin output / serialisation}
add wave sim:/tb_top_level_test/dut/fft_tx_valid_o
add wave sim:/tb_top_level_test/dut/fft_tx_last_o
add wave -radix unsigned sim:/tb_top_level_test/dut/fft_tx_index_o
add wave -radix decimal sim:/tb_top_level_test/dut/fft_tx_real_o
add wave -radix decimal sim:/tb_top_level_test/dut/fft_tx_imag_o

wave zoom full
update
