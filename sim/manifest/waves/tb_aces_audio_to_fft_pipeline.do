quietly WaveActivateNextPane {} 0
view wave

configure wave -namecolwidth 300
configure wave -valuecolwidth 120

add wave -divider {I2S Input}
add wave sim:/tb_aces_audio_to_fft_pipeline/rst
add wave sim:/tb_aces_audio_to_fft_pipeline/clk
add wave sim:/tb_aces_audio_to_fft_pipeline/mic_sck_i
add wave sim:/tb_aces_audio_to_fft_pipeline/mic_ws_i
add wave sim:/tb_aces_audio_to_fft_pipeline/mic_sd_i

add wave -divider {Pipeline Outputs}
add wave sim:/tb_aces_audio_to_fft_pipeline/sample_valid_mic_o
add wave -radix hex sim:/tb_aces_audio_to_fft_pipeline/sample_24_dbg_o
add wave -radix decimal sim:/tb_aces_audio_to_fft_pipeline/sample_mic_o
add wave sim:/tb_aces_audio_to_fft_pipeline/fft_sample_valid_o
add wave -radix decimal sim:/tb_aces_audio_to_fft_pipeline/fft_sample_o
add wave sim:/tb_aces_audio_to_fft_pipeline/sact_istream_o
add wave -radix decimal sim:/tb_aces_audio_to_fft_pipeline/sdw_istream_real_o
add wave -radix decimal sim:/tb_aces_audio_to_fft_pipeline/sdw_istream_imag_o

add wave -divider {Internal}
add wave sim:/tb_aces_audio_to_fft_pipeline/dut/sample_24
add wave sim:/tb_aces_audio_to_fft_pipeline/dut/sample_valid_24
add wave sim:/tb_aces_audio_to_fft_pipeline/dut/sample_18
add wave sim:/tb_aces_audio_to_fft_pipeline/dut/sample_valid_18
add wave sim:/tb_aces_audio_to_fft_pipeline/dut/valid_reg
add wave sim:/tb_aces_audio_to_fft_pipeline/dut/valid_d

update
