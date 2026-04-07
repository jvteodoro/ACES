module aces #(
    parameter int FFT_LENGTH    = 512,
    parameter int FFT_DW        = 18,
    parameter int I2S_CLOCK_DIV = 16
) (
    input  logic clk,
    input  logic rst,

    // -----------------------------
    // interface fisica do microfone
    // -----------------------------
    input  logic mic_sd_i,
    input  logic mic_lr_sel_i,

    output logic mic_sck_o,
    output logic mic_ws_o,
    output logic mic_chipen_o,
    output logic mic_lr_sel_o,

    // -----------------------------
    // debug do frontend / ingestao
    // -----------------------------
    output logic sample_valid_mic_o,
    output logic signed [FFT_DW-1:0] sample_mic_o,
    output logic signed [23:0] sample_24_dbg_o,

    output logic fft_sample_valid_o,
    output logic signed [FFT_DW-1:0] fft_sample_o,

    output logic sact_istream_o,
    output logic signed [FFT_DW-1:0] sdw_istream_real_o,
    output logic signed [FFT_DW-1:0] sdw_istream_imag_o,

    // -----------------------------
    // estado da FFT
    // -----------------------------
    output logic fft_run_o,
    output logic [1:0] fft_input_buffer_status_o,
    output logic [2:0] fft_status_o,
    output logic fft_done_o,
    output logic signed [7:0] bfpexp_o,

    // -----------------------------
    // bins lidos da FFT para debug
    // -----------------------------
    output logic fft_bin_valid_o,
    output logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_o,
    output logic signed [FFT_DW-1:0] fft_bin_real_o,
    output logic signed [FFT_DW-1:0] fft_bin_imag_o,
    output logic fft_bin_last_o
);

    localparam int FFT_N = $clog2(FFT_LENGTH);

    logic dmaact_i;
    logic [FFT_N-1:0] dmaa_i;
    logic signed [FFT_DW-1:0] dmadr_real_o;
    logic signed [FFT_DW-1:0] dmadr_imag_o;

    assign mic_chipen_o = 1'b1;
    assign mic_lr_sel_o = mic_lr_sel_i;

    i2s_master_clock_gen #(
        .CLOCK_DIV(I2S_CLOCK_DIV)
    ) u_i2s_master_clock_gen (
        .clk(clk),
        .rst(rst),
        .sck_o(mic_sck_o),
        .ws_o(mic_ws_o)
    );

    aces_audio_to_fft_pipeline #(
        .SAMPLE_W(FFT_DW)
    ) u_audio_to_fft_pipeline (
        .rst(rst),
        .mic_sck_i(mic_sck_o),
        .mic_ws_i(mic_ws_o),
        .mic_sd_i(mic_sd_i),
        .mic_lr_i(mic_lr_sel_i),
        .clk(clk),
        .sample_valid_mic_o(sample_valid_mic_o),
        .sample_mic_o(sample_mic_o),
        .sample_24_dbg_o(sample_24_dbg_o),
        .fft_sample_valid_o(fft_sample_valid_o),
        .fft_sample_o(fft_sample_o),
        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o)
    );

    fft_control u_fft_control (
        .clk(clk),
        .rst(rst),
        .status(fft_input_buffer_status_o),
        .sact_istream_i(sact_istream_o),
        .run(fft_run_o)
    );

    r2fft_tribuf_impl #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .PL_DEPTH(3)
    ) u_r2fft_tribuf_impl (
        .clk(clk),
        .rst_i(rst),
        .run_i(fft_run_o),
        .ifft_i(1'b0),
        .done_o(fft_done_o),
        .status_o(fft_status_o),
        .input_buffer_status_o(fft_input_buffer_status_o),
        .bfpexp_o(bfpexp_o),
        .sact_istream_i(sact_istream_o),
        .sdw_istream_real_i(sdw_istream_real_o),
        .sdw_istream_imag_i(sdw_istream_imag_o),
        .dmaact_i(dmaact_i),
        .dmaa_i(dmaa_i),
        .dmadr_real_o(dmadr_real_o),
        .dmadr_imag_o(dmadr_imag_o)
    );

    fft_dma_reader #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .READ_LATENCY(2)
    ) u_fft_dma_reader (
        .clk(clk),
        .rst(rst),
        .done_i(fft_done_o),
        .run_i(fft_run_o),
        .dmaact_o(dmaact_i),
        .dmaa_o(dmaa_i),
        .dmadr_real_i(dmadr_real_o),
        .dmadr_imag_i(dmadr_imag_o),
        .fft_bin_valid_o(fft_bin_valid_o),
        .fft_bin_index_o(fft_bin_index_o),
        .fft_bin_real_o(fft_bin_real_o),
        .fft_bin_imag_o(fft_bin_imag_o),
        .fft_bin_last_o(fft_bin_last_o)
    );

endmodule
