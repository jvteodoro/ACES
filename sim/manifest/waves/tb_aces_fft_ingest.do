quietly WaveActivateNextPane {} 0
view wave

add wave sim:/tb_aces_fft_ingest/clk
add wave sim:/tb_aces_fft_ingest/rst
add wave sim:/tb_aces_fft_ingest/fft_sample_valid_i
add wave -radix decimal sim:/tb_aces_fft_ingest/fft_sample_i
add wave sim:/tb_aces_fft_ingest/sact_istream_o
add wave -radix decimal sim:/tb_aces_fft_ingest/sdw_istream_real_o
add wave -radix decimal sim:/tb_aces_fft_ingest/sdw_istream_imag_o

update
