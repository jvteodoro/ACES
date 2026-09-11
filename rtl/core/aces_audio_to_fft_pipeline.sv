module aces_audio_to_fft_pipeline #(
    parameter int SAMPLE_W = 18,
    parameter int FRAME_LENGTH = 512,
    parameter int HOP_LENGTH = FRAME_LENGTH / 2,
    parameter bit ENABLE_OVERLAP = 1'b0,
    parameter bit ENABLE_WINDOW = 1'b0,
    // Untyped string parameter keeps compatibility with Quartus and Icarus;
    // both tools accept the path literal while elaborating the ROM instance.
    parameter WINDOW_COEFF_FILE = "rtl/frontend/hann_window_q15.hex"
)(
    input  logic rst,

    // I2S
    input  logic mic_sck_i,
    input  logic mic_ws_i,
    input  logic mic_sd_i,
    input  logic mic_lr_i,

    // clock sistema
    input  logic clk,

    // debug mic
    output logic sample_valid_mic_o,
    output logic signed [SAMPLE_W-1:0] sample_mic_o,
    output logic signed [23:0] sample_24_dbg_o,

    // debug pipeline
    output logic fft_sample_valid_o,
    output logic signed [SAMPLE_W-1:0] fft_sample_o,

    // interface FFT
    output logic sact_istream_o,
    output logic signed [SAMPLE_W-1:0] sdw_istream_real_o,
    output logic signed [SAMPLE_W-1:0] sdw_istream_imag_o
);

    // -------------------------------------------------------------------------
    // domínio mic_sck_i
    // -------------------------------------------------------------------------

    logic signed [23:0] sample_24;
    logic               sample_valid_24;

    logic signed [SAMPLE_W-1:0] sample_18;
    logic                       sample_valid_18;

    logic signed [SAMPLE_W-1:0] sample_hold_mic;
    logic                       sample_toggle_mic;

    i2s_rx_adapter_24 u_i2s_rx (
        .rst(rst),
        .sck_i(mic_sck_i),
        .ws_i(mic_ws_i),
        .sd_i(mic_sd_i),
        .lr_i(mic_lr_i),
        .sample_valid_o(sample_valid_24),
        .sample_24_o(sample_24)
    );

    assign sample_24_dbg_o = sample_24;

    sample_width_adapter_24_to_18 u_width_adapter (
        .sample_24_i(sample_24),
        .valid_24_i(sample_valid_24),
        .sample_18_o(sample_18),
        .valid_18_o(sample_valid_18)
    );

    always_ff @(posedge mic_sck_i or posedge rst) begin
        if (rst) begin
            sample_hold_mic  <= '0;
            sample_toggle_mic <= 1'b0;
        end else begin
            if (sample_valid_18) begin
                sample_hold_mic  <= sample_18;
                sample_toggle_mic <= ~sample_toggle_mic;
            end
        end
    end

    // -------------------------------------------------------------------------
    // CDC para domínio clk
    // -------------------------------------------------------------------------

    logic toggle_sync_1, toggle_sync_2, toggle_seen_clk;
    logic signed [SAMPLE_W-1:0] sample_reg;
    logic                       sample_pulse_clk;
    logic [$clog2(FRAME_LENGTH)-1:0] frame_sample_index;
    logic [$clog2(FRAME_LENGTH)-1:0] window_sample_index;
    logic signed [SAMPLE_W-1:0] windowed_sample;
    logic windowed_valid;
    logic analysis_sample_valid;
    logic signed [SAMPLE_W-1:0] analysis_sample;
    logic [$clog2(FRAME_LENGTH)-1:0] analysis_sample_index;
    logic overlap_sample_valid;
    logic signed [SAMPLE_W-1:0] overlap_sample;
    logic overlap_frame_start;
    logic overlap_frame_last;
    logic [$clog2(FRAME_LENGTH)-1:0] overlap_sample_index;

    wire new_sample_clk;
    assign new_sample_clk = (toggle_sync_2 != toggle_seen_clk);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            toggle_sync_1  <= 1'b0;
            toggle_sync_2  <= 1'b0;
            toggle_seen_clk <= 1'b0;
            sample_reg     <= '0;
            sample_pulse_clk <= 1'b0;
            frame_sample_index <= '0;
            window_sample_index <= '0;
        end else begin
            toggle_sync_1   <= sample_toggle_mic;
            toggle_sync_2   <= toggle_sync_1;
            sample_pulse_clk <= 1'b0;

            if (new_sample_clk) begin
                sample_reg      <= sample_hold_mic;
                sample_pulse_clk <= 1'b1;
                toggle_seen_clk <= toggle_sync_2;
                // Keep the index aligned with sample_reg/sample_pulse_clk;
                // the window block consumes these registered values one
                // system-clock later.
                window_sample_index <= frame_sample_index;
                if (frame_sample_index == FRAME_LENGTH-1)
                    frame_sample_index <= '0;
                else
                    frame_sample_index <= frame_sample_index + 1'b1;
            end
        end
    end

    generate
        if (ENABLE_OVERLAP) begin : gen_overlap
            audio_overlap_frame_buffer #(
                .SAMPLE_W(SAMPLE_W),
                .FRAME_LENGTH(FRAME_LENGTH),
                .HOP_LENGTH(HOP_LENGTH)
            ) u_overlap_buffer (
                .clk(clk),
                .rst(rst),
                .sample_valid_i(sample_pulse_clk),
                .sample_i(sample_reg),
                .frame_sample_valid_o(overlap_sample_valid),
                .frame_sample_o(overlap_sample),
                .frame_start_o(overlap_frame_start),
                .frame_last_o(overlap_frame_last)
            );

            always_ff @(posedge clk or posedge rst) begin
                if (rst)
                    overlap_sample_index <= '0;
                else if (overlap_sample_valid) begin
                    if (overlap_sample_index == FRAME_LENGTH-1)
                        overlap_sample_index <= '0;
                    else
                        overlap_sample_index <= overlap_sample_index + 1'b1;
                end
            end

            always_comb begin
                analysis_sample_valid = overlap_sample_valid;
                analysis_sample = overlap_sample;
                analysis_sample_index = overlap_sample_index;
            end
        end else begin : gen_no_overlap
            always_comb begin
                analysis_sample_valid = sample_pulse_clk;
                analysis_sample = sample_reg;
                analysis_sample_index = window_sample_index;
            end
        end
    endgenerate

    generate
        if (ENABLE_WINDOW) begin : gen_window
            fft_window_multiplier #(
                .SAMPLE_W(SAMPLE_W),
                .FRAME_LENGTH(FRAME_LENGTH),
                .COEFF_FILE(WINDOW_COEFF_FILE)
            ) u_window (
                .clk(clk),
                .rst(rst),
                .sample_valid_i(analysis_sample_valid),
                .sample_index_i(analysis_sample_index),
                .sample_i(analysis_sample),
                .sample_valid_o(windowed_valid),
                .sample_o(windowed_sample)
            );
        end else begin : gen_no_window
            always_comb begin
                windowed_valid = analysis_sample_valid;
                windowed_sample = analysis_sample;
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // saídas
    // -------------------------------------------------------------------------

    assign sample_valid_mic_o = sample_pulse_clk;
    assign sample_mic_o       = sample_reg;

    assign fft_sample_valid_o = windowed_valid;
    assign fft_sample_o       = windowed_sample;

    assign sact_istream_o     = windowed_valid;
    assign sdw_istream_real_o = windowed_sample;
    assign sdw_istream_imag_o = '0;

endmodule
