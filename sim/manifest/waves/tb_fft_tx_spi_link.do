quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 340
configure wave -valuecolwidth 140

add wave -divider {Verification checkpoints}
add wave sim:/tb_fft_tx_spi_link/clk
add wave sim:/tb_fft_tx_spi_link/rst
add wave -radix unsigned sim:/tb_fft_tx_spi_link/max_fifo_level_r
add wave sim:/tb_fft_tx_spi_link/saw_fifo_overflow_r
add wave sim:/tb_fft_tx_spi_link/saw_adapter_overflow_r

add wave -divider {FIFO stimulus and handshake}
add wave sim:/tb_fft_tx_spi_link/push_i
add wave sim:/tb_fft_tx_spi_link/bridge_pop_i
add wave sim:/tb_fft_tx_spi_link/adapter_ready_o
add wave sim:/tb_fft_tx_spi_link/fifo_valid_o
add wave sim:/tb_fft_tx_spi_link/fifo_full_o
add wave sim:/tb_fft_tx_spi_link/fifo_empty_o
add wave sim:/tb_fft_tx_spi_link/fifo_overflow_o
add wave -radix unsigned sim:/tb_fft_tx_spi_link/fifo_level_o
add wave -radix decimal sim:/tb_fft_tx_spi_link/fft_real_i
add wave -radix decimal sim:/tb_fft_tx_spi_link/fft_imag_i
add wave sim:/tb_fft_tx_spi_link/fft_last_i
add wave -radix decimal sim:/tb_fft_tx_spi_link/bfpexp_i
add wave -radix decimal sim:/tb_fft_tx_spi_link/fifo_real_o
add wave -radix decimal sim:/tb_fft_tx_spi_link/fifo_imag_o
add wave sim:/tb_fft_tx_spi_link/fifo_last_o
add wave -radix decimal sim:/tb_fft_tx_spi_link/fifo_bfpexp_o

add wave -divider {SPI adapter}
add wave sim:/tb_fft_tx_spi_link/spi_sclk_i
add wave sim:/tb_fft_tx_spi_link/spi_cs_n_i
add wave sim:/tb_fft_tx_spi_link/spi_miso_o
add wave sim:/tb_fft_tx_spi_link/window_ready_o
add wave sim:/tb_fft_tx_spi_link/spi_active_o
add wave sim:/tb_fft_tx_spi_link/adapter_fifo_full_o
add wave sim:/tb_fft_tx_spi_link/adapter_fifo_empty_o
add wave sim:/tb_fft_tx_spi_link/adapter_overflow_o
add wave -radix unsigned sim:/tb_fft_tx_spi_link/adapter_fifo_level_o

add wave -divider {FIFO internals}
add wave -radix binary sim:/tb_fft_tx_spi_link/u_fifo/fifo_mem
add wave -radix hex sim:/tb_fft_tx_spi_link/u_fifo/head_word
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_fifo/wptr_r
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_fifo/rptr_r

add wave -divider {Adapter internals}
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_adapter/complete_windows_r
add wave sim:/tb_fft_tx_spi_link/u_adapter/spi_transaction_active_r
add wave sim:/tb_fft_tx_spi_link/u_adapter/tx_window_in_progress_r
add wave sim:/tb_fft_tx_spi_link/u_adapter/wait_next_fft_pair_r
add wave sim:/tb_fft_tx_spi_link/u_adapter/wait_fifo_refresh_r
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_adapter/bfpexp_hold_remaining_r
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_adapter/active_pair_kind_r
add wave -radix hex sim:/tb_fft_tx_spi_link/u_adapter/active_left_word_r
add wave -radix hex sim:/tb_fft_tx_spi_link/u_adapter/active_right_word_r
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_adapter/pair_byte_idx_r
add wave -radix hex sim:/tb_fft_tx_spi_link/u_adapter/current_byte_r
add wave -radix unsigned sim:/tb_fft_tx_spi_link/u_adapter/current_bit_idx_r

update
