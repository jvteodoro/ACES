quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 240
configure wave -valuecolwidth 120

add wave -divider {TB}
add wave sim:/tb_i2s_master_clock_gen/clk
add wave sim:/tb_i2s_master_clock_gen/rst
add wave -radix unsigned sim:/tb_i2s_master_clock_gen/clk_edges_since_toggle
add wave -radix unsigned sim:/tb_i2s_master_clock_gen/sck_toggle_count
add wave -radix unsigned sim:/tb_i2s_master_clock_gen/ws_transition_count

add wave -divider {DUT}
add wave sim:/tb_i2s_master_clock_gen/dut/sck_o
add wave sim:/tb_i2s_master_clock_gen/dut/ws_o
add wave -radix unsigned sim:/tb_i2s_master_clock_gen/dut/div_cnt
add wave -radix unsigned sim:/tb_i2s_master_clock_gen/dut/frame_bit_cnt

update
