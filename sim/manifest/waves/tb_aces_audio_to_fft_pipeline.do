onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {I2S Input}
add wave -noupdate -color Gold /tb_aces_audio_to_fft_pipeline/rst
add wave -noupdate -color Gold /tb_aces_audio_to_fft_pipeline/clk
add wave -noupdate -color Gold /tb_aces_audio_to_fft_pipeline/mic_sck_i
add wave -noupdate -color Gold /tb_aces_audio_to_fft_pipeline/mic_ws_i
add wave -noupdate -color Gold /tb_aces_audio_to_fft_pipeline/mic_sd_i
add wave -noupdate -divider {Pipeline Outputs}
add wave -noupdate -color {Spring Green} /tb_aces_audio_to_fft_pipeline/sample_valid_mic_o
add wave -noupdate -color {Spring Green} -radix hexadecimal -childformat {{{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[23]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[22]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[21]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[20]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[19]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[18]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[17]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[16]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[15]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[14]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[13]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[12]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[11]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[10]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[9]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[8]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[7]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[6]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[5]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[4]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[3]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[2]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[1]} -radix hexadecimal} {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[0]} -radix hexadecimal}} -subitemconfig {{/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[23]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[22]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[21]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[20]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[19]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[18]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[17]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[16]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[15]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[14]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[13]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[12]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[11]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[10]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[9]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[8]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[7]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[6]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[5]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[4]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[3]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[2]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[1]} {-color {Spring Green} -radix hexadecimal} {/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o[0]} {-color {Spring Green} -radix hexadecimal}} /tb_aces_audio_to_fft_pipeline/sample_24_dbg_o
add wave -noupdate -color {Spring Green} -radix decimal /tb_aces_audio_to_fft_pipeline/sample_mic_o
add wave -noupdate -color {Spring Green} /tb_aces_audio_to_fft_pipeline/fft_sample_valid_o
add wave -noupdate -color {Spring Green} -radix decimal /tb_aces_audio_to_fft_pipeline/fft_sample_o
add wave -noupdate -divider {To FFT Input}
add wave -noupdate -color {Spring Green} /tb_aces_audio_to_fft_pipeline/sact_istream_o
add wave -noupdate -color {Spring Green} -radix decimal /tb_aces_audio_to_fft_pipeline/sdw_istream_real_o
add wave -noupdate -color {Spring Green} -radix decimal /tb_aces_audio_to_fft_pipeline/sdw_istream_imag_o
add wave -noupdate -divider Internal
add wave -noupdate -color {Light Steel Blue} /tb_aces_audio_to_fft_pipeline/dut/sample_24
add wave -noupdate -color {Light Steel Blue} /tb_aces_audio_to_fft_pipeline/dut/sample_valid_24
add wave -noupdate -color {Light Steel Blue} /tb_aces_audio_to_fft_pipeline/dut/sample_18
add wave -noupdate -color {Light Steel Blue} /tb_aces_audio_to_fft_pipeline/dut/sample_valid_18
add wave -noupdate -color {Light Steel Blue} /tb_aces_audio_to_fft_pipeline/dut/valid_d
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 156
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
WaveRestoreZoom {0 ps} {9673319 ps}
