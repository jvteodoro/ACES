module aces #(
    parameter int FFT_LENGTH   = 1024,
    parameter int FFT_DW       = 18,
    parameter int I2S_CLOCK_DIV = 16,
    parameter bit USE_FRACTIONAL_AUDIO_CLOCK = 1'b1,
    parameter int SYSTEM_CLOCK_HZ = 50_000_000,
    parameter int AUDIO_SAMPLE_RATE_HZ = 48_000,
    parameter bit ENABLE_WINDOW = 1'b0,
    parameter int HOP_LENGTH = FFT_LENGTH / 2,
    parameter bit ENABLE_OVERLAP = 1'b0,
    parameter WINDOW_COEFF_FILE = "rtl/frontend/hann_window_q15.hex",
    parameter int TX_BRIDGE_FIFO_DEPTH = 2048
)(
    input  logic clk,
    input  logic rst,

    // -----------------------------
    // interface física do microfone
    // -----------------------------
    input  logic mic_sd_i,
    input  logic mic_lr_sel_i,   // valor a ser enviado ao pino L/R do microfone

    output logic mic_sck_o,
    output logic mic_ws_o,
    output logic mic_chipen_o,
    output logic mic_lr_sel_o,

    // -----------------------------
    // debug do frontend / ingestão
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
    // interface pronta para bloco serial futuro
    // -----------------------------
    output logic fft_tx_valid_o,
    output logic [$clog2(FFT_LENGTH)-1:0] fft_tx_index_o,
    output logic signed [FFT_DW-1:0] fft_tx_real_o,
    output logic signed [FFT_DW-1:0] fft_tx_imag_o,
    output logic fft_tx_last_o,

    // -----------------------------
    // transmissao serial FFT tagged
    // -----------------------------
    output logic tx_i2s_sck_o,
    output logic tx_i2s_ws_o,
    output logic tx_i2s_sd_o,
    output logic tx_overflow_o
);


    localparam int FFT_N = $clog2(FFT_LENGTH);
    // FFT data remains local; no external transport width is needed.

    logic dmaact_i;
    logic [FFT_N-1:0] dmaa_i;
    logic signed [FFT_DW-1:0] dmadr_real_o;
    logic signed [FFT_DW-1:0] dmadr_imag_o;

    // Legacy transport pins are kept quiet; local feature processing uses the
    // DMA stream directly below.
    assign tx_i2s_sck_o = 1'b0;
    assign tx_i2s_ws_o  = 1'b0;
    assign tx_i2s_sd_o  = 1'b0;
    assign tx_overflow_o = 1'b0;

    // Mantido apenas para compatibilidade de interface externa.
    initial begin
        if (FFT_DW != 18)
            $error("aces: FFT_DW deve ser 18 para casar com o núcleo FFT atual.");
    end

    // -----------------------------
    // controle físico do microfone
    // -----------------------------
    assign mic_chipen_o = 1'b1;
    assign mic_lr_sel_o = mic_lr_sel_i;

    // -----------------------------
    // gerador SCK / WS
    // -----------------------------
    i2s_master_clock_gen #(
        .CLOCK_DIV(I2S_CLOCK_DIV),
        .USE_FRACTIONAL_CLOCK(USE_FRACTIONAL_AUDIO_CLOCK),
        .SYSTEM_CLOCK_HZ(SYSTEM_CLOCK_HZ),
        .AUDIO_SAMPLE_RATE_HZ(AUDIO_SAMPLE_RATE_HZ)
    ) u_i2s_master_clock_gen (
        .clk(clk),
        .rst(rst),
        .sck_o(mic_sck_o),
        .ws_o(mic_ws_o)
    );

    // -----------------------------
    // pipeline microfone -> FFT stream
    // -----------------------------
    aces_audio_to_fft_pipeline #(
        .SAMPLE_W(FFT_DW),
        .FRAME_LENGTH(FFT_LENGTH),
        .HOP_LENGTH(HOP_LENGTH),
        .ENABLE_OVERLAP(ENABLE_OVERLAP),
        .ENABLE_WINDOW(ENABLE_WINDOW),
        .WINDOW_COEFF_FILE(WINDOW_COEFF_FILE)
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

    // -----------------------------
    // controle de run da FFT
    // -----------------------------
    fft_control u_fft_control (
        .clk(clk),
        .rst(rst),
        .status(fft_input_buffer_status_o),
        .sact_istream_i(sact_istream_o),
        .run(fft_run_o)
    );

    // -----------------------------
    // núcleo FFT
    // -----------------------------
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

    // -----------------------------
    // leitor DMA da FFT
    // -----------------------------
    fft_dma_reader #(
        .FFT_LENGTH(FFT_LENGTH),
        .OUTPUT_BINS(FFT_LENGTH),
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

        .fft_bin_valid_o(fft_tx_valid_o),
        .fft_bin_index_o(fft_tx_index_o),
        .fft_bin_real_o(fft_tx_real_o),
        .fft_bin_imag_o(fft_tx_imag_o),
        .fft_bin_last_o(fft_tx_last_o)
    );

endmodule
