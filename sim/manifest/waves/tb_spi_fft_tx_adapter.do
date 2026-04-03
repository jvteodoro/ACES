quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 320
configure wave -valuecolwidth 120

add wave -divider {Stimulus}
add wave sim:/tb_spi_fft_tx_adapter/clk
add wave sim:/tb_spi_fft_tx_adapter/rst
add wave sim:/tb_spi_fft_tx_adapter/fft_valid_i
add wave -radix decimal sim:/tb_spi_fft_tx_adapter/fft_real_i
add wave -radix decimal sim:/tb_spi_fft_tx_adapter/fft_imag_i
add wave sim:/tb_spi_fft_tx_adapter/fft_last_i
add wave -radix decimal sim:/tb_spi_fft_tx_adapter/bfpexp_i

add wave -divider {SPI Pins}
add wave sim:/tb_spi_fft_tx_adapter/spi_sclk_i
add wave sim:/tb_spi_fft_tx_adapter/spi_cs_n_i
add wave sim:/tb_spi_fft_tx_adapter/spi_miso_o
add wave sim:/tb_spi_fft_tx_adapter/window_ready_o
add wave sim:/tb_spi_fft_tx_adapter/spi_active_o

add wave -divider {Adapter status}
add wave sim:/tb_spi_fft_tx_adapter/fft_ready_o
add wave sim:/tb_spi_fft_tx_adapter/fifo_full_o
add wave sim:/tb_spi_fft_tx_adapter/fifo_empty_o
add wave sim:/tb_spi_fft_tx_adapter/overflow_o
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/fifo_level_o
add wave sim:/tb_spi_fft_tx_adapter/saw_overflow_r
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/max_fifo_level_r

add wave -divider {DUT internals}
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/dut/complete_windows_r
add wave sim:/tb_spi_fft_tx_adapter/dut/spi_transaction_active_r
add wave sim:/tb_spi_fft_tx_adapter/dut/tx_window_in_progress_r
add wave sim:/tb_spi_fft_tx_adapter/dut/wait_next_fft_pair_r
add wave sim:/tb_spi_fft_tx_adapter/dut/wait_fifo_refresh_r
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/dut/bfpexp_hold_remaining_r
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/dut/active_pair_kind_r
add wave -radix hex sim:/tb_spi_fft_tx_adapter/dut/active_left_word_r
add wave -radix hex sim:/tb_spi_fft_tx_adapter/dut/active_right_word_r
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/dut/pair_byte_idx_r
add wave -radix hex sim:/tb_spi_fft_tx_adapter/dut/current_byte_r
add wave -radix unsigned sim:/tb_spi_fft_tx_adapter/dut/current_bit_idx_r
add wave sim:/tb_spi_fft_tx_adapter/dut/fifo_valid_w
add wave sim:/tb_spi_fft_tx_adapter/dut/fifo_last_w
add wave -radix decimal sim:/tb_spi_fft_tx_adapter/dut/fifo_real_w
add wave -radix decimal sim:/tb_spi_fft_tx_adapter/dut/fifo_imag_w
add wave -radix decimal sim:/tb_spi_fft_tx_adapter/dut/fifo_bfpexp_w

update
