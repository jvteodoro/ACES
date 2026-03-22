quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 260
configure wave -valuecolwidth 100

add wave -divider {Inputs}
add wave sim:/tb_fft_dma_reader/clk
add wave sim:/tb_fft_dma_reader/rst
add wave sim:/tb_fft_dma_reader/done_i

add wave -divider {DMA}
add wave sim:/tb_fft_dma_reader/dmaact_o
add wave -radix unsigned sim:/tb_fft_dma_reader/dmaa_o
add wave -radix decimal sim:/tb_fft_dma_reader/dmadr_real_i
add wave -radix decimal sim:/tb_fft_dma_reader/dmadr_imag_i

add wave -divider {Outputs}
add wave sim:/tb_fft_dma_reader/fft_bin_valid_o
add wave -radix unsigned sim:/tb_fft_dma_reader/fft_bin_index_o
add wave -radix decimal sim:/tb_fft_dma_reader/fft_bin_real_o
add wave -radix decimal sim:/tb_fft_dma_reader/fft_bin_imag_o
add wave sim:/tb_fft_dma_reader/fft_bin_last_o

add wave -divider {Internal}
add wave sim:/tb_fft_dma_reader/dut/state
add wave -radix unsigned sim:/tb_fft_dma_reader/dut/addr
add wave -radix unsigned sim:/tb_fft_dma_reader/dut/lat_cnt

update
