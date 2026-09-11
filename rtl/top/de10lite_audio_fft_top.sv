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
    parameter int FFT_LENGTH = 1024,
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
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS,
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
    logic mfcc_valid_raw, feature_frame_done_raw;
    logic feature_bin_last;
    logic [$clog2(13)-1:0] mfcc_index, mfcc_index_raw;
    logic signed [31:0] mfcc_data, mfcc_data_raw;
    logic [3:0] hex0_value, hex1_value, hex2_value;
    logic pixel_clk, vga_active, vga_frame_start;
    logic [9:0] pixel_x, pixel_y;
    logic [9:0] spectrum_value;
    logic signed [31:0] mfcc_value;
    logic [8:0] spectrum_read_index;
    logic [3:0] mfcc_read_index;
    logic [7:0] dashboard_bfpexp;
    logic dashboard_fft_run, dashboard_fft_done, dashboard_feature_busy;
    logic [2:0] dashboard_fft_status;
    logic [1:0] dashboard_fft_input_status;
    logic [31:0] dashboard_frame_count;
    logic [3:0] dashboard_r, dashboard_g, dashboard_b;

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

    // The DMA reader emits all 1024 FFT bins and asserts fft_tx_last on bin
    // 1023. The feature analyzer intentionally consumes only bins 0..511,
    // so its frame boundary must be generated at the last useful bin.
    assign feature_bin_last = fft_tx_valid &&
                              (fft_tx_last || (fft_tx_index == (FFT_LENGTH / 2 - 1)));

    aces #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV),
        .ENABLE_WINDOW(1'b1),
        .ENABLE_OVERLAP(1'b1),
        .HOP_LENGTH(FFT_LENGTH / 2),
        .WINDOW_COEFF_FILE("../rtl/frontend/hann_window_q15_1024.hex"),
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
        .USEFUL_BINS(FFT_LENGTH / 2),
        .MEL_BANDS(32),
        .MFCC_COUNT(13),
        .USE_MEL_ROM(1'b1),
        .MEL_ROM_FILE("../rtl/analysis/mel_coeffs_1024_q16.hex"),
        .USE_LOG_ROM(1'b1),
        .LOG_ROM_FILE("../rtl/analysis/log_mantissa_q16.hex")
    ) u_feature_analyzer (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .fft_bin_valid_i(fft_tx_valid),
        .fft_bin_index_i(fft_tx_index),
        .fft_bin_real_i(fft_tx_real),
        .fft_bin_imag_i(fft_tx_imag),
        .fft_bfpexp_i(bfpexp),
        .fft_bin_last_i(feature_bin_last),
        .busy_o(feature_busy),
        .result_valid_o(mfcc_valid_raw),
        .result_index_o(mfcc_index_raw),
        .result_data_o(mfcc_data_raw),
        .frame_done_o(feature_frame_done_raw)
    );

    feature_temporal_stabilizer #(
        .MFCC_COUNT(13),
        .DATA_W(32),
        .ALPHA_SHIFT(2),
        .ALPHA_Q(1)
    ) u_feature_stabilizer (
        .clk(MAX10_CLK1_50),
        .rst(rst),
        .result_valid_i(mfcc_valid_raw),
        .result_index_i(mfcc_index_raw),
        .result_data_i(mfcc_data_raw),
        .frame_done_i(feature_frame_done_raw),
        .result_valid_o(mfcc_valid),
        .result_index_o(mfcc_index),
        .result_data_o(mfcc_data),
        .frame_done_o(feature_frame_done)
    );

    vga_pixel_clock_div2 u_vga_clock_div (
        .clk_50(MAX10_CLK1_50), .rst(rst), .pixel_clk(pixel_clk)
    );

    vga_timing u_vga_timing (
        .pixel_clk(pixel_clk), .rst(rst), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .active_video(vga_active), .frame_start(vga_frame_start),
        .hsync(VGA_HS), .vsync(VGA_VS)
    );

    dashboard_data_capture u_dashboard_capture (
        .clk_50(MAX10_CLK1_50), .pixel_clk(pixel_clk), .rst(rst),
        .frame_start_i(vga_frame_start),
        .fft_tx_valid_i(fft_tx_valid), .fft_tx_index_i(fft_tx_index),
        .fft_tx_real_i(fft_tx_real), .fft_tx_imag_i(fft_tx_imag), .bfpexp_i(bfpexp),
        .fft_run_i(fft_run), .fft_done_i(fft_done), .fft_status_i(fft_status),
        .fft_input_status_i(fft_input_status), .feature_busy_i(feature_busy),
        .mfcc_valid_i(mfcc_valid), .mfcc_index_i(mfcc_index), .mfcc_data_i(mfcc_data),
        .feature_frame_done_i(feature_frame_done),
        .spectrum_read_index_i(spectrum_read_index), .mfcc_read_index_i(mfcc_read_index),
        .spectrum_value_o(spectrum_value), .mfcc_value_o(mfcc_value),
        .bfpexp_o(dashboard_bfpexp), .fft_run_o(dashboard_fft_run),
        .fft_done_o(dashboard_fft_done), .fft_status_o(dashboard_fft_status),
        .fft_input_status_o(dashboard_fft_input_status),
        .feature_busy_o(dashboard_feature_busy), .frame_count_o(dashboard_frame_count)
    );

    dashboard_renderer u_dashboard_renderer (
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active_video(vga_active),
        .spectrum_value(spectrum_value), .mfcc_value(mfcc_value), .bfpexp(dashboard_bfpexp),
        .fft_run(dashboard_fft_run), .fft_done(dashboard_fft_done),
        .fft_status(dashboard_fft_status), .fft_input_status(dashboard_fft_input_status),
        .feature_busy(dashboard_feature_busy), .frame_count(dashboard_frame_count),
        .spectrum_read_index(spectrum_read_index), .mfcc_read_index(mfcc_read_index),
        .red(dashboard_r), .green(dashboard_g), .blue(dashboard_b)
    );

    always_ff @(posedge pixel_clk or posedge rst) begin
        if (rst) begin
            VGA_R <= 4'h0;
            VGA_G <= 4'h0;
            VGA_B <= 4'h0;
        end else begin
            VGA_R <= dashboard_r;
            VGA_G <= dashboard_g;
            VGA_B <= dashboard_b;
        end
    end

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
