onerror {resume}
quietly WaveActivateNextPane {} 0

add wave sim:/tb_top_level_fft_isolated/tb_clk_drive
add wave sim:/tb_top_level_fft_isolated/tb_rst_drive
add wave sim:/tb_top_level_fft_isolated/forced_sact_r
add wave -radix decimal sim:/tb_top_level_fft_isolated/forced_real_r
add wave -radix decimal sim:/tb_top_level_fft_isolated/forced_imag_r
add wave sim:/tb_top_level_fft_isolated/manual_dmaact_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/manual_dmaa_r

add wave -radix unsigned sim:/tb_top_level_fft_isolated/input_sample_count_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/auto_fft_bin_count_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/run_rise_count_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/done_rise_count_r
add wave sim:/tb_top_level_fft_isolated/input_buffer_full_seen_r
add wave sim:/tb_top_level_fft_isolated/fft_status_run_seen_r
add wave sim:/tb_top_level_fft_isolated/fft_status_done_seen_r
add wave sim:/tb_top_level_fft_isolated/sb_done_seen_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dma_auto_burst_count_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dma_auto_max_burst_len_r
add wave -radix unsigned sim:/tb_top_level_fft_isolated/fft_stage_max_r

add wave sim:/tb_top_level_fft_isolated/dut/fft_run_o
add wave sim:/tb_top_level_fft_isolated/dut/fft_done_o
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/fft_input_buffer_status_o
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/fft_status_o
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/bfpexp_o

add wave sim:/tb_top_level_fft_isolated/dut/u_aces/sact_istream_o
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/u_aces/sdw_istream_real_o
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/u_aces/sdw_istream_imag_o
add wave sim:/tb_top_level_fft_isolated/dut/u_aces/u_fft_control/run
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_fft_control/state

add wave sim:/tb_top_level_fft_isolated/dut/u_aces/dmaact_i
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/dmaa_i
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/u_aces/dmadr_real_o
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/u_aces/dmadr_imag_o
add wave sim:/tb_top_level_fft_isolated/dut/u_aces/fft_tx_valid_o
add wave sim:/tb_top_level_fft_isolated/dut/u_aces/fft_tx_last_o
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/fft_tx_index_o
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/u_aces/fft_tx_real_o
add wave -radix decimal sim:/tb_top_level_fft_isolated/dut/u_aces/fft_tx_imag_o

add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_fft_dma_reader/state
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_fft_dma_reader/addr
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_fft_dma_reader/lat_cnt

add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/tribuf_status
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/ibuf_status_f
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/status_f
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/sb_state_f
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/fftStageCount
add wave sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/iteratorDone
add wave sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/oactFftUnit
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/istreamAddr
add wave -radix unsigned sim:/tb_top_level_fft_isolated/dut/u_aces/u_r2fft_tribuf_impl/uR2FFT_tribuf/dmaa_lsb

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 320
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
