module top_level_test #(
    parameter int FFT_LENGTH    = 512,
    parameter int FFT_DW        = 18,
    parameter int N_POINTS      = 512,
    parameter int N_EXAMPLES    = 8,
    parameter int I2S_CLOCK_DIV = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic stim_start_i,
    input  logic [$clog2(N_EXAMPLES)-1:0] stim_example_sel_i,
    input  logic [1:0] stim_loop_mode_i,
    input  logic stim_lr_sel_i,

    output logic stim_ready_o,
    output logic stim_busy_o,
    output logic stim_done_o,
    output logic stim_window_done_o,
    output logic [$clog2(N_EXAMPLES)-1:0] stim_current_example_o,
    output logic [$clog2(N_POINTS)-1:0] stim_current_point_o,
    output logic [$clog2(N_POINTS*N_EXAMPLES)-1:0] stim_rom_addr_dbg_o,
    output logic signed [23:0] stim_current_sample_dbg_o,
    output logic [5:0] stim_bit_index_o,
    output logic [2:0] stim_state_dbg_o,

    output logic i2s_sck_o,
    output logic i2s_ws_o,
    output logic i2s_sd_o,
    output logic mic_chipen_o,
    output logic mic_lr_sel_o,

    output logic sample_valid_mic_o,
    output logic signed [FFT_DW-1:0] sample_mic_o,
    output logic signed [23:0] sample_24_dbg_o,

    output logic fft_sample_valid_o,
    output logic signed [FFT_DW-1:0] fft_sample_o,

    output logic sact_istream_o,
    output logic signed [FFT_DW-1:0] sdw_istream_real_o,
    output logic signed [FFT_DW-1:0] sdw_istream_imag_o,

    output logic fft_run_o,
    output logic [1:0] fft_input_buffer_status_o,
    output logic [2:0] fft_status_o,
    output logic fft_done_o,
    output logic signed [7:0] bfpexp_o,

    output logic fft_tx_valid_o,
    output logic [$clog2(FFT_LENGTH)-1:0] fft_tx_index_o,
    output logic signed [FFT_DW-1:0] fft_tx_real_o,
    output logic signed [FFT_DW-1:0] fft_tx_imag_o,
    output logic fft_tx_last_o
);

    aces #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV)
    ) u_aces (
        .clk(clk),
        .rst(rst),
        .mic_sd_i(i2s_sd_o),
        .mic_lr_sel_i(stim_lr_sel_i),
        .mic_sck_o(i2s_sck_o),
        .mic_ws_o(i2s_ws_o),
        .mic_chipen_o(mic_chipen_o),
        .mic_lr_sel_o(mic_lr_sel_o),
        .sample_valid_mic_o(sample_valid_mic_o),
        .sample_mic_o(sample_mic_o),
        .sample_24_dbg_o(sample_24_dbg_o),
        .fft_sample_valid_o(fft_sample_valid_o),
        .fft_sample_o(fft_sample_o),
        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o),
        .fft_run_o(fft_run_o),
        .fft_input_buffer_status_o(fft_input_buffer_status_o),
        .fft_status_o(fft_status_o),
        .fft_done_o(fft_done_o),
        .bfpexp_o(bfpexp_o),
        .fft_tx_valid_o(fft_tx_valid_o),
        .fft_tx_index_o(fft_tx_index_o),
        .fft_tx_real_o(fft_tx_real_o),
        .fft_tx_imag_o(fft_tx_imag_o),
        .fft_tx_last_o(fft_tx_last_o)
    );

    i2s_stimulus_manager_rom #(
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
        .STARTUP_SCK_CYCLES(8),
        .INACTIVE_ZERO_SYNTH(0)
    ) u_stimulus (
        .clk(clk),
        .rst(rst),
        .start_i(stim_start_i),
        .example_sel_i(stim_example_sel_i),
        .loop_mode_i(stim_loop_mode_i),
        .chipen_i(mic_chipen_o),
        .lr_i(stim_lr_sel_i),
        .sck_i(i2s_sck_o),
        .ws_i(i2s_ws_o),
        .sd_o(i2s_sd_o),
        .ready_o(stim_ready_o),
        .busy_o(stim_busy_o),
        .done_o(stim_done_o),
        .window_done_o(stim_window_done_o),
        .current_example_o(stim_current_example_o),
        .current_point_o(stim_current_point_o),
        .rom_addr_dbg_o(stim_rom_addr_dbg_o),
        .current_sample_dbg_o(stim_current_sample_dbg_o),
        .bit_index_o(stim_bit_index_o),
        .state_dbg_o(stim_state_dbg_o)
    );

endmodule
