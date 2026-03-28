module aces #(
    parameter int FFT_LENGTH   = 512,
    parameter int FFT_DW       = 18,
    parameter int I2S_CLOCK_DIV = 16,
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

    logic dmaact_i;
    logic [FFT_N-1:0] dmaa_i;
    logic signed [FFT_DW-1:0] dmadr_real_o;
    logic signed [FFT_DW-1:0] dmadr_imag_o;

    logic tx_bridge_valid_o;
    logic tx_bridge_full_o;
    logic tx_bridge_empty_o;
    logic tx_bridge_overflow_o;
    logic tx_fft_ready_o;
    logic tx_overflow_from_adapter_o;

    logic tx_fft_valid_i;
    logic signed [FFT_DW-1:0] tx_fft_real_i;
    logic signed [FFT_DW-1:0] tx_fft_imag_i;
    logic tx_fft_last_i;
    logic signed [7:0] tx_bfpexp_i;

    assign tx_fft_valid_i = tx_bridge_valid_o && tx_fft_ready_o;
    assign tx_overflow_o  = tx_bridge_overflow_o || tx_overflow_from_adapter_o;

    // -----------------------------
    // controle físico do microfone
    // -----------------------------
    assign mic_chipen_o = 1'b1;
    assign mic_lr_sel_o = mic_lr_sel_i;

    // -----------------------------
    // gerador SCK / WS
    // -----------------------------
    i2s_master_clock_gen #(
        .CLOCK_DIV(I2S_CLOCK_DIV)
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
        .SAMPLE_W(FFT_DW)
    ) u_audio_to_fft_pipeline (
        .rst(rst),
        .mic_sck_i(mic_sck_o),
        .mic_ws_i(mic_ws_o),
        .mic_sd_i(mic_sd_i),
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
        .FFT_DW(FFT_DW),
        .READ_LATENCY(1)
    ) u_fft_dma_reader (
        .clk(clk),
        .rst(rst),
        .done_i(fft_done_o),

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

    // FIFO intermediaria entre leitura DMA da FFT e transmissao serial.
    // Guarda bin + bfpexp para desacoplar a rajada de leitura da taxa I2S.
    fft_tx_bridge_fifo #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(8),
        .FIFO_DEPTH(TX_BRIDGE_FIFO_DEPTH)
    ) u_fft_tx_bridge_fifo (
        .clk(clk),
        .rst(rst),
        .push_i(fft_tx_valid_o),
        .fft_real_i(fft_tx_real_o),
        .fft_imag_i(fft_tx_imag_o),
        .fft_last_i(fft_tx_last_o),
        .bfpexp_i(bfpexp_o),
        .pop_i(tx_fft_valid_i),
        .valid_o(tx_bridge_valid_o),
        .fft_real_o(tx_fft_real_i),
        .fft_imag_o(tx_fft_imag_i),
        .fft_last_o(tx_fft_last_i),
        .bfpexp_o(tx_bfpexp_i),
        .full_o(tx_bridge_full_o),
        .empty_o(tx_bridge_empty_o),
        .overflow_o(tx_bridge_overflow_o),
        .level_o()
    );

    // -----------------------------
    // transmissor I2S tagged para host externo
    // -----------------------------
    i2s_fft_tx_adapter #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(8),
        .I2S_SAMPLE_W(FFT_DW),
        .I2S_SLOT_W(32),
        .CLOCK_DIV(I2S_CLOCK_DIV),
        .FIFO_DEPTH(FFT_LENGTH + 1),
        .BFPEXP_HOLD_FRAMES(128)
    ) u_i2s_fft_tx_adapter (
        .clk(clk),
        .rst(rst),
        .fft_valid_i(tx_fft_valid_i),
        .fft_real_i(tx_fft_real_i),
        .fft_imag_i(tx_fft_imag_i),
        .fft_last_i(tx_fft_last_i),
        .bfpexp_i(tx_bfpexp_i),
        .fft_ready_o(tx_fft_ready_o),
        .fifo_full_o(),
        .fifo_empty_o(),
        .overflow_o(tx_overflow_from_adapter_o),
        .fifo_level_o(),
        .i2s_sck_o(tx_i2s_sck_o),
        .i2s_ws_o(tx_i2s_ws_o),
        .i2s_sd_o(tx_i2s_sd_o)
    );

endmodule