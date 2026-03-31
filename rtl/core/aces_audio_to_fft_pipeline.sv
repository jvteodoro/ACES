module aces_audio_to_fft_pipeline #(
    parameter int SAMPLE_W = 18
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

    wire new_sample_clk;
    assign new_sample_clk = (toggle_sync_2 != toggle_seen_clk);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            toggle_sync_1  <= 1'b0;
            toggle_sync_2  <= 1'b0;
            toggle_seen_clk <= 1'b0;
            sample_reg     <= '0;
            sample_pulse_clk <= 1'b0;
        end else begin
            toggle_sync_1   <= sample_toggle_mic;
            toggle_sync_2   <= toggle_sync_1;
            sample_pulse_clk <= 1'b0;

            if (new_sample_clk) begin
                sample_reg      <= sample_hold_mic;
                sample_pulse_clk <= 1'b1;
                toggle_seen_clk <= toggle_sync_2;
            end
        end
    end

    // -------------------------------------------------------------------------
    // saídas
    // -------------------------------------------------------------------------

    assign sample_valid_mic_o = sample_pulse_clk;
    assign sample_mic_o       = sample_reg;

    assign fft_sample_valid_o = sample_pulse_clk;
    assign fft_sample_o       = sample_reg;

    assign sact_istream_o     = sample_pulse_clk;
    assign sdw_istream_real_o = sample_reg;
    assign sdw_istream_imag_o = '0;

endmodule
