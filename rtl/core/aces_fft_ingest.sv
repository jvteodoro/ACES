module aces_fft_ingest #(
    parameter int FFT_DW = 18
)(
    input  logic clk,
    input  logic rst,

    input  logic fft_sample_valid_i,
    input  logic signed [FFT_DW-1:0] fft_sample_i,

    output logic sact_istream_o,
    output logic signed [FFT_DW-1:0] sdw_istream_real_o,
    output logic signed [FFT_DW-1:0] sdw_istream_imag_o
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sact_istream_o     <= 1'b0;
            sdw_istream_real_o <= '0;
            sdw_istream_imag_o <= '0;
        end else begin
            sact_istream_o <= 1'b0; // one-shot pulse only

            if (fft_sample_valid_i) begin
                sact_istream_o     <= 1'b1;
                sdw_istream_real_o <= fft_sample_i;
                sdw_istream_imag_o <= '0;
            end
        end
    end

endmodule
