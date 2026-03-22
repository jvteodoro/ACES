quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 360
configure wave -valuecolwidth 120

add wave -divider {Board Pins}
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/tb_clk_drive
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/tb_rst_drive
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/gpio_1_d0
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/gpio_1_d1
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/gpio_1_d2
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/gpio_1_d3
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/gpio_1_d4
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/ledr0
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/ledr1
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/ledr2
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/hex0_o
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/hex1_o

add wave -divider {Internal Top}
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/dut/sample_valid_mic_o
add wave -radix decimal sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/dut/sample_mic_o
add wave -radix hex sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/dut/sample_24_dbg_o
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/dut/fft_tx_valid_o
add wave sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/dut/fft_tx_last_o
add wave -radix unsigned sim:/tb_top_level_test_mux_clear_hex_based_on_uploaded/dut/fft_tx_index_o

update
