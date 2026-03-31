module aces_audio_to_fft_pipeline #(
    parameter int SAMPLE_W = 18
)(
    input  logic rst,

    // I2S
    input  logic mic_sck_i,
    input  logic mic_ws_i,
    input  logic mic_sd_i,

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

    //-----------------------------------------
    // sinais internos
    //-----------------------------------------

    logic signed [23:0] sample_24;
    logic sample_valid_24;

    logic signed [SAMPLE_W-1:0] sample_18;
    logic sample_valid_18;

    logic signed [SAMPLE_W-1:0] sample_reg;
    logic valid_reg;

    logic valid_d;

    //-----------------------------------------
    // I2S receiver
    //-----------------------------------------

    i2s_rx_adapter_24 u_i2s_rx (
        .rst(rst),
        .sck_i(mic_sck_i),
        .ws_i(mic_ws_i),
        .sd_i(mic_sd_i),

        .sample_24_o(sample_24),
        .sample_valid_o(sample_valid_24)
    );

    assign sample_24_dbg_o = sample_24;

    //-----------------------------------------
    // width adapter 24 → 18
    //-----------------------------------------

    sample_width_adapter_24_to_18 u_width_adapter (
        .sample_24_i(sample_24),
        .valid_24_i(sample_valid_24),

        .sample_18_o(sample_18),
        .valid_18_o(sample_valid_18)
    );

    //-----------------------------------------
    // sincronização com clock do sistema
    //-----------------------------------------

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_reg <= '0;
            valid_reg  <= 1'b0;
        end
        else begin
            valid_reg <= sample_valid_18;

            if (sample_valid_18)
                sample_reg <= sample_18;
        end
    end

    //-----------------------------------------
    // geração de pulso de 1 ciclo
    //-----------------------------------------

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            valid_d <= 1'b0;
        else
            valid_d <= valid_reg;
    end

    wire valid_pulse;

    assign valid_pulse = valid_reg & ~valid_d;

    //-----------------------------------------
    // saídas debug
    //-----------------------------------------

    assign sample_valid_mic_o = valid_reg;
    assign sample_mic_o       = sample_reg;

    assign fft_sample_valid_o = valid_reg;
    assign fft_sample_o       = sample_reg;

    //-----------------------------------------
    // interface FFT
    //-----------------------------------------

    assign sact_istream_o     = valid_pulse;

    assign sdw_istream_real_o = sample_reg;
    assign sdw_istream_imag_o = '0;

endmodule