quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 280
configure wave -valuecolwidth 120

add wave -divider {Verification checkpoints}
add wave sim:/tb_fft_tx_bridge_fifo/clk
add wave sim:/tb_fft_tx_bridge_fifo/rst
add wave sim:/tb_fft_tx_bridge_fifo/push_i
add wave sim:/tb_fft_tx_bridge_fifo/pop_i
add wave -radix unsigned sim:/tb_fft_tx_bridge_fifo/level_o
add wave sim:/tb_fft_tx_bridge_fifo/overflow_o

add wave -divider {FIFO input}
add wave -radix decimal sim:/tb_fft_tx_bridge_fifo/fft_real_i
add wave -radix decimal sim:/tb_fft_tx_bridge_fifo/fft_imag_i
add wave sim:/tb_fft_tx_bridge_fifo/fft_last_i
add wave -radix decimal sim:/tb_fft_tx_bridge_fifo/bfpexp_i

add wave -divider {FIFO output}
add wave sim:/tb_fft_tx_bridge_fifo/valid_o
add wave -radix decimal sim:/tb_fft_tx_bridge_fifo/fft_real_o
add wave -radix decimal sim:/tb_fft_tx_bridge_fifo/fft_imag_o
add wave sim:/tb_fft_tx_bridge_fifo/fft_last_o
add wave -radix decimal sim:/tb_fft_tx_bridge_fifo/bfpexp_o
add wave sim:/tb_fft_tx_bridge_fifo/full_o
add wave sim:/tb_fft_tx_bridge_fifo/empty_o

add wave -divider {DUT internals}
add wave -radix binary sim:/tb_fft_tx_bridge_fifo/dut/fifo_mem
add wave -radix unsigned sim:/tb_fft_tx_bridge_fifo/dut/wptr_r
add wave -radix unsigned sim:/tb_fft_tx_bridge_fifo/dut/rptr_r

update
