// Applies a Q1.15 Hann window to one sample per valid clock.
// The coefficient file is generated deterministically from the reference
// profile and is inferred as ROM by Quartus.
module fft_window_multiplier #(
    parameter int SAMPLE_W = 18,
    parameter int FRAME_LENGTH = 512,
    parameter COEFF_FILE = "rtl/frontend/hann_window_q15.hex"
) (
    input logic clk,
    input logic rst,
    input logic sample_valid_i,
    input logic [$clog2(FRAME_LENGTH)-1:0] sample_index_i,
    input logic signed [SAMPLE_W-1:0] sample_i,
    output logic sample_valid_o,
    output logic signed [SAMPLE_W-1:0] sample_o
);
    (* romstyle = "M9K" *) logic [15:0] coeff_rom [0:FRAME_LENGTH-1];
    logic signed [SAMPLE_W+15:0] product;

    initial $readmemh(COEFF_FILE, coeff_rom);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_valid_o <= 1'b0;
            sample_o <= '0;
        end else begin
            sample_valid_o <= sample_valid_i;
            if (sample_valid_i) begin
                product = sample_i * $signed({1'b0, coeff_rom[sample_index_i]});
                sample_o <= product >>> 15;
            end
        end
    end
endmodule
