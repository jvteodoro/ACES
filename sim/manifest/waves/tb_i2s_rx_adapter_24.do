onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider TB
add wave -noupdate -color White /tb_i2s_rx_adapter_24/rst
add wave -noupdate -color White /tb_i2s_rx_adapter_24/sck_i
add wave -noupdate -color White /tb_i2s_rx_adapter_24/ws_i
add wave -noupdate -color Yellow /tb_i2s_rx_adapter_24/sd_i
add wave -noupdate -color Yellow /tb_i2s_rx_adapter_24/sample_valid_o
add wave -noupdate -color {Violet Red} -radix hexadecimal /tb_i2s_rx_adapter_24/sample_24_o
add wave -noupdate -divider DUT
add wave -noupdate /tb_i2s_rx_adapter_24/dut/ws_prev
add wave -noupdate /tb_i2s_rx_adapter_24/dut/capturing
add wave -noupdate /tb_i2s_rx_adapter_24/dut/skip_bit
add wave -noupdate -radix unsigned /tb_i2s_rx_adapter_24/dut/bit_count
add wave -noupdate -color Yellow /tb_i2s_rx_adapter_24/dut/sample_valid_o
add wave -noupdate -color {Violet Red} -radix hexadecimal /tb_i2s_rx_adapter_24/dut/sample_24_o
add wave -noupdate /tb_i2s_rx_adapter_24/dut/shift_reg
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 240
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {55965 ns}
