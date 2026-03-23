onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -color White /tb_fft_control/clk
add wave -noupdate -color White /tb_fft_control/rst
add wave -noupdate /tb_fft_control/sact_istream_i
add wave -noupdate /tb_fft_control/status
add wave -noupdate -color Magenta /tb_fft_control/run
add wave -noupdate -color Cyan /tb_fft_control/dut/state
add wave -noupdate /tb_fft_control/dut/state_n
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {96031 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {0 ps} {99750 ps}
