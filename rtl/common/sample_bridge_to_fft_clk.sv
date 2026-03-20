module sample_bridge_to_fft_clk #(
    parameter int SAMPLE_W = 18
)(
    input  logic rst,

    // source domain
    input  logic mic_sck_i,
    input  logic sample_valid_i,
    input  logic signed [SAMPLE_W-1:0] sample_i,

    // destination domain
    input  logic clk,

    output logic fft_sample_valid_o,
    output logic signed [SAMPLE_W-1:0] fft_sample_o
);

    logic signed [SAMPLE_W-1:0] sample_hold;
    logic sample_toggle;

    logic toggle_sync_0, toggle_sync_1, toggle_sync_2;

    // Hold latest sample and toggle event flag in source domain
    always_ff @(posedge mic_sck_i or posedge rst) begin
        if (rst) begin
            sample_hold   <= '0;
            sample_toggle <= 1'b0;
        end else if (sample_valid_i) begin
            sample_hold   <= sample_i;
            sample_toggle <= ~sample_toggle;
        end
    end

    // Synchronize event toggle into FFT clock domain
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            toggle_sync_0 <= 1'b0;
            toggle_sync_1 <= 1'b0;
            toggle_sync_2 <= 1'b0;
        end else begin
            toggle_sync_0 <= sample_toggle;
            toggle_sync_1 <= toggle_sync_0;
            toggle_sync_2 <= toggle_sync_1;
        end
    end

    // Emit exactly one pulse in destination domain
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fft_sample_valid_o <= 1'b0;
            fft_sample_o       <= '0;
        end else begin
            fft_sample_valid_o <= 1'b0;
            if (toggle_sync_1 ^ toggle_sync_2) begin
                fft_sample_o       <= sample_hold;
                fft_sample_valid_o <= 1'b1;
            end
        end
    end

endmodule
