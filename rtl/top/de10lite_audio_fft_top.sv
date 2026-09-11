// DE10-Lite top-level for the complete audio -> FFT -> FPGA feature path.
//
// GPIO contract (3.3 V LVTTL, relative to the DE10-Lite header numbering):
//   GPIO[0] input  : external I2S microphone serial data
//   GPIO[1] output : microphone SCK
//   GPIO[2] output : microphone WS/LRCLK
//   GPIO[3] output : microphone L/R select
//   GPIO[4] output : optional tagged FFT I2S clock
//   GPIO[5] output : optional tagged FFT I2S WS
//   GPIO[6] output : optional tagged FFT I2S data
//   GPIO[7] output : MFCC result valid
//   GPIO[8] output : MFCC frame done
//
// SW[0] selects the microphone left/right channel. KEY[0] is the active-low
// reset. The latest MFCC result is shown as hexadecimal Q16.16 low bits on
// HEX2..HEX0 (HEX0 also shows the coefficient index).

module de10lite_audio_fft_top #(
    parameter int FFT_LENGTH = 512,
    parameter int FFT_DW = 18,
    parameter int I2S_CLOCK_DIV = 8,
    parameter int TX_BRIDGE_FIFO_DEPTH = 2048
) (
    input  logic MAX10_CLK1_50,
    input  logic [1:0] KEY,
    input  logic [9:0] SW,
    output logic [9:0] LEDR,
    output logic [7:0] HEX0,
    output logic [7:0] HEX1,
    output logic [7:0] HEX2,
    inout logic [35:0] GPIO
);

    logic rst;
    logic mic_sd;
    logic mic_sck, mic_ws, mic_chipen, mic_lr;
    logic tx_i2s_sck, tx_i2s_ws, tx_i2s_sd;
    logic tx_overflow;

    logic sample_valid, fft_sample_valid;
    logic signed [FFT_DW-1:0] sample_mic, fft_sample;
    logic signed [23:0] sample_24;
    logic sact_istream;
    logic signed [FFT_DW-1:0] istream_real, istream_imag;
    logic fft_run, fft_done;
    logic [1:0] fft_input_status;
    logic [2:0] fft_status;
    logic signed [7:0] bfpexp;
    logic fft_tx_valid, fft_tx_last;
    logic [$clog2(FFT_LENGTH)-1:0] fft_tx_index;
    logic signed [FFT_DW-1:0] fft_tx_real, fft_tx_imag;

    logic feature_busy, mfcc_valid, feature_frame_done;
    logic [$clog2(13)-1:0] mfcc_index;
    logic signed [31:0] mfcc_data;
    logic [3:0] hex0_value, hex1_value, hex2_value;

    assign rst = ~KEY[0];
    assign mic_sd = GPIO[0];

    assign GPIO[1] = mic_sck;
    assign GPIO[2] = mic_ws;
    assign GPIO[3] = mic_lr;
    assign GPIO[4] = tx_i2s_sck;
    assign GPIO[5] = tx_i2s_ws;
    assign GPIO[6] = tx_i2s_sd;
    assign GPIO[7] = mfcc_valid;
    assign GPIO[8] = feature_frame_done;

    aces #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV),
        .ENABLE_WINDOW(1'b1),
        .WINDOW_COEFF_FILE("../rtl/frontend/hann_window_q15.hex"),
        .TX_BRIDGE_FIFO_DEPTH(TX_BRIDGE_FIFO_DEPTH)
    ) u_aces (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .mic_sd_i(mic_sd),
        .mic_lr_sel_i(SW[0]),
        .mic_sck_o(mic_sck),
        .mic_ws_o(mic_ws),
        .mic_chipen_o(mic_chipen),
        .mic_lr_sel_o(mic_lr),
        .sample_valid_mic_o(sample_valid),
        .sample_mic_o(sample_mic),
        .sample_24_dbg_o(sample_24),
        .fft_sample_valid_o(fft_sample_valid),
        .fft_sample_o(fft_sample),
        .sact_istream_o(sact_istream),
        .sdw_istream_real_o(istream_real),
        .sdw_istream_imag_o(istream_imag),
        .fft_run_o(fft_run),
        .fft_input_buffer_status_o(fft_input_status),
        .fft_status_o(fft_status),
        .fft_done_o(fft_done),
        .bfpexp_o(bfpexp),
        .fft_tx_valid_o(fft_tx_valid),
        .fft_tx_index_o(fft_tx_index),
        .fft_tx_real_o(fft_tx_real),
        .fft_tx_imag_o(fft_tx_imag),
        .fft_tx_last_o(fft_tx_last),
        .tx_i2s_sck_o(tx_i2s_sck),
        .tx_i2s_ws_o(tx_i2s_ws),
        .tx_i2s_sd_o(tx_i2s_sd),
        .tx_overflow_o(tx_overflow)
    );

    fft_feature_analyzer #(
        .FFT_LENGTH(FFT_LENGTH),
        .USEFUL_BINS(256),
        .MEL_BANDS(32),
        .MFCC_COUNT(13)
    ) u_feature_analyzer (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .fft_bin_valid_i(fft_tx_valid),
        .fft_bin_index_i(fft_tx_index),
        .fft_bin_real_i(fft_tx_real),
        .fft_bin_imag_i(fft_tx_imag),
        .fft_bin_last_i(fft_tx_last),
        .busy_o(feature_busy),
        .result_valid_o(mfcc_valid),
        .result_index_o(mfcc_index),
        .result_data_o(mfcc_data),
        .frame_done_o(feature_frame_done)
    );

    always_comb begin
        LEDR = '0;
        LEDR[0] = feature_busy;
        LEDR[1] = mfcc_valid;
        LEDR[2] = feature_frame_done;
        LEDR[3] = fft_tx_valid;
        LEDR[4] = fft_done;
        LEDR[5] = sample_valid;
        LEDR[6] = fft_run;
        LEDR[7] = fft_input_status[0];
        LEDR[8] = fft_input_status[1];
        LEDR[9] = mfcc_data[31];
    end

    always_ff @(posedge MAX10_CLK1_50 or posedge rst) begin
        if (rst) begin
            hex0_value <= 0;
            hex1_value <= 0;
            hex2_value <= 0;
        end else if (mfcc_valid) begin
            hex0_value <= mfcc_index;
            hex1_value <= mfcc_data[3:0];
            hex2_value <= mfcc_data[7:4];
        end
    end

    hexa7seg u_hex0(hex0_value, HEX0[6:0]);
    hexa7seg u_hex1(hex1_value, HEX1[6:0]);
    hexa7seg u_hex2(hex2_value, HEX2[6:0]);
    assign HEX0[7] = 1'b1;
    assign HEX1[7] = 1'b1;
    assign HEX2[7] = 1'b1;

    // Prevent unused expansion pins from floating during bring-up.
    assign GPIO[35:9] = 27'bz;
endmodule
