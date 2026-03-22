quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 240
configure wave -valuecolwidth 120
configure wave -signalnamewidth 1

log -r sim:/tb_i2s_rx_adapter_24/*
log -r sim:/tb_i2s_rx_adapter_24/dut/*

add wave -divider {TB}
add wave sim:/tb_i2s_rx_adapter_24/rst
add wave sim:/tb_i2s_rx_adapter_24/sck_i
add wave sim:/tb_i2s_rx_adapter_24/ws_i
add wave sim:/tb_i2s_rx_adapter_24/sd_i
add wave sim:/tb_i2s_rx_adapter_24/sample_valid_o
add wave -radix hex sim:/tb_i2s_rx_adapter_24/sample_24_o

add wave -divider {DUT}
add wave sim:/tb_i2s_rx_adapter_24/dut/ws_prev
add wave sim:/tb_i2s_rx_adapter_24/dut/capturing
add wave sim:/tb_i2s_rx_adapter_24/dut/skip_bit
add wave -radix unsigned sim:/tb_i2s_rx_adapter_24/dut/bit_count
add wave -radix hex sim:/tb_i2s_rx_adapter_24/dut/shift_reg
add wave -radix hex sim:/tb_i2s_rx_adapter_24/dut/sample_24_o
add wave sim:/tb_i2s_rx_adapter_24/dut/sample_valid_o

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
update
