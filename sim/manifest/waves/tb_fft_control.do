quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 220
configure wave -valuecolwidth 100

add wave sim:/tb_fft_control/clk
add wave sim:/tb_fft_control/rst
add wave sim:/tb_fft_control/sact_istream_i
add wave sim:/tb_fft_control/status
add wave sim:/tb_fft_control/run
add wave sim:/tb_fft_control/dut/state
add wave sim:/tb_fft_control/dut/state_n

update
