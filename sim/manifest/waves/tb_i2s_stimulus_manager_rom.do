quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 240
configure wave -valuecolwidth 120
configure wave -signalnamewidth 1

log -r sim:/tb_i2s_stimulus_manager_rom/*
log -r sim:/tb_i2s_stimulus_manager_rom/dut/*
log -r sim:/tb_i2s_stimulus_manager_rom/u_rx/*

add wave -divider {Control}
add wave sim:/tb_i2s_stimulus_manager_rom/clk
add wave sim:/tb_i2s_stimulus_manager_rom/rst
add wave sim:/tb_i2s_stimulus_manager_rom/start_i
add wave -radix unsigned sim:/tb_i2s_stimulus_manager_rom/example_sel_i
add wave -radix binary sim:/tb_i2s_stimulus_manager_rom/loop_mode_i

add wave -divider {I2S Interface}
add wave sim:/tb_i2s_stimulus_manager_rom/chipen_i
add wave sim:/tb_i2s_stimulus_manager_rom/lr_i
add wave sim:/tb_i2s_stimulus_manager_rom/sck_i
add wave sim:/tb_i2s_stimulus_manager_rom/ws_i
add wave sim:/tb_i2s_stimulus_manager_rom/sd_o

add wave -divider {Stimulus Status}
add wave sim:/tb_i2s_stimulus_manager_rom/ready_o
add wave sim:/tb_i2s_stimulus_manager_rom/busy_o
add wave sim:/tb_i2s_stimulus_manager_rom/done_o
add wave sim:/tb_i2s_stimulus_manager_rom/window_done_o
add wave -radix unsigned sim:/tb_i2s_stimulus_manager_rom/current_example_o
add wave -radix unsigned sim:/tb_i2s_stimulus_manager_rom/current_point_o

add wave -divider {ROM / Serialization Debug}
add wave -radix unsigned sim:/tb_i2s_stimulus_manager_rom/rom_addr_dbg_o
add wave -radix hex sim:/tb_i2s_stimulus_manager_rom/current_sample_dbg_o
add wave -radix unsigned sim:/tb_i2s_stimulus_manager_rom/bit_index_o
add wave -radix unsigned sim:/tb_i2s_stimulus_manager_rom/state_dbg_o

add wave -divider {Receiver Check}
add wave sim:/tb_i2s_stimulus_manager_rom/rx_valid
add wave -radix hex sim:/tb_i2s_stimulus_manager_rom/rx_sample

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
update
