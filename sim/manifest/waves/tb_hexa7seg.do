quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 220
configure wave -valuecolwidth 100

add wave -divider {Verification checkpoints}
add wave -radix unsigned sim:/tb_hexa7seg/idx
add wave -radix hex sim:/tb_hexa7seg/hexa
add wave -radix binary sim:/tb_hexa7seg/display

add wave -divider {Expected decode table}
add wave -radix binary sim:/tb_hexa7seg/expected

add wave -divider {DUT}
add wave -radix hex sim:/tb_hexa7seg/dut/hexa
add wave -radix binary sim:/tb_hexa7seg/dut/display

update
