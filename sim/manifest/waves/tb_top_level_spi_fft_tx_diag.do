quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 360
configure wave -valuecolwidth 140

add wave -divider {Board pins}
add wave sim:/tb_top_level_spi_fft_tx_diag/clock_50
add wave sim:/tb_top_level_spi_fft_tx_diag/gpio_1_d1
add wave sim:/tb_top_level_spi_fft_tx_diag/gpio_1_d27
add wave sim:/tb_top_level_spi_fft_tx_diag/gpio_1_d29
add wave sim:/tb_top_level_spi_fft_tx_diag/gpio_1_d31
add wave sim:/tb_top_level_spi_fft_tx_diag/gpio_1_d25

add wave -divider {Diagnostic top outputs}
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/tx_spi_window_ready_o
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/tx_spi_miso_o
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/tx_spi_active_o
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/diag_fft_valid_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/diag_fft_last_r
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/diag_bin_index_r
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/diag_window_count_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/diag_window_in_progress_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/diag_overflow_latched_r

add wave -divider {SPI adapter internals}
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/complete_windows_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/spi_transaction_active_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/tx_window_in_progress_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/wait_next_fft_pair_r
add wave sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/wait_fifo_refresh_r
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/bfpexp_hold_remaining_r
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/active_pair_kind_r
add wave -radix hex sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/active_left_word_r
add wave -radix hex sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/active_right_word_r
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/pair_byte_idx_r
add wave -radix hex sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/current_byte_r
add wave -radix unsigned sim:/tb_top_level_spi_fft_tx_diag/dut/u_spi_fft_tx_adapter/current_bit_idx_r

update
