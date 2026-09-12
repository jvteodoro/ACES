// First-order digital high-pass filter for microphone DC/infra-sound removal.
//
// H(z) = (1 - z^-1) / (1 - alpha*z^-1)
//
// At Fs=48 kHz, alpha=65109/65536 gives a -3 dB corner of approximately
// 50 Hz. The filter is intentionally placed after the I2S sample CDC and
// before overlap buffering, so both FFT and MFCC receive the filtered stream.
module audio_dc_blocker #(
    parameter int SAMPLE_W = 18,
    parameter int ALPHA_Q = 16,
    parameter logic signed [ALPHA_Q-1:0] ALPHA = 16'sd65109
) (
    input  logic clk,
    input  logic rst,
    input  logic sample_valid_i,
    input  logic signed [SAMPLE_W-1:0] sample_i,
    output logic sample_valid_o,
    output logic signed [SAMPLE_W-1:0] sample_o
);
    localparam logic signed [SAMPLE_W-1:0] MAX_SAMPLE = {1'b0, {(SAMPLE_W-1){1'b1}}};
    localparam logic signed [SAMPLE_W-1:0] MIN_SAMPLE = {1'b1, {(SAMPLE_W-1){1'b0}}};

    logic signed [SAMPLE_W-1:0] x_delay;
    logic signed [SAMPLE_W-1:0] y_delay;
    logic signed [SAMPLE_W:0] sample_delta;
    logic signed [SAMPLE_W+ALPHA_Q-1:0] feedback_product;
    logic signed [SAMPLE_W+ALPHA_Q:0] feedback;
    logic signed [SAMPLE_W+ALPHA_Q:0] candidate;
    logic signed [SAMPLE_W-1:0] candidate_saturated;

    always_comb begin
        sample_delta = $signed({sample_i[SAMPLE_W-1], sample_i}) -
                       $signed({x_delay[SAMPLE_W-1], x_delay});
        feedback_product = y_delay * ALPHA;
        feedback = feedback_product >>> ALPHA_Q;
        candidate = $signed(sample_delta) + feedback;

        if (candidate > MAX_SAMPLE)
            candidate_saturated = MAX_SAMPLE;
        else if (candidate < MIN_SAMPLE)
            candidate_saturated = MIN_SAMPLE;
        else
            candidate_saturated = candidate[SAMPLE_W-1:0];
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            x_delay <= '0;
            y_delay <= '0;
            sample_valid_o <= 1'b0;
            sample_o <= '0;
        end else begin
            sample_valid_o <= sample_valid_i;
            if (sample_valid_i) begin
                x_delay <= sample_i;
                y_delay <= candidate_saturated;
                sample_o <= candidate_saturated;
            end
        end
    end
endmodule
