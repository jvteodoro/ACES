quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 260
configure wave -valuecolwidth 120

add wave -divider {Verification checkpoints}
add wave -radix decimal sim:/tb_sample_width_adapter_24_to_18/sample_24_i
add wave sim:/tb_sample_width_adapter_24_to_18/valid_24_i
add wave -radix decimal sim:/tb_sample_width_adapter_24_to_18/sample_18_o
add wave sim:/tb_sample_width_adapter_24_to_18/valid_18_o

add wave -divider {DUT}
add wave -radix decimal sim:/tb_sample_width_adapter_24_to_18/dut/sample_24_i
add wave sim:/tb_sample_width_adapter_24_to_18/dut/valid_24_i
add wave -radix decimal sim:/tb_sample_width_adapter_24_to_18/dut/sample_18_o
add wave sim:/tb_sample_width_adapter_24_to_18/dut/valid_18_o

update
