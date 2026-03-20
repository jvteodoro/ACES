module r2fft_tribuf_impl #(
    parameter int FFT_LENGTH = 8,
    parameter int FFT_DW = 18,
    parameter int PL_DEPTH = 3,
    parameter int FFT_N = $clog2(FFT_LENGTH)
)(
    input  logic clk,
    input  logic rst_i,
    input  logic run_i,
    input  logic ifft_i,

    output logic done_o,
    output logic [2:0] status_o,
    output logic [1:0] input_buffer_status_o,
    output logic signed [7:0] bfpexp_o,

    input  logic sact_istream_i,
    input  logic signed [FFT_DW-1:0] sdw_istream_real_i,
    input  logic signed [FFT_DW-1:0] sdw_istream_imag_i,

    input  logic dmaact_i,
    input  logic [FFT_N-1:0] dmaa_i,
    output logic signed [FFT_DW-1:0] dmadr_real_o,
    output logic signed [FFT_DW-1:0] dmadr_imag_o
);

    logic [FFT_N:0] sample_count;
    logic [1:0] run_pipe;

    always_ff @(posedge clk or posedge rst_i) begin
        if (rst_i) begin
            sample_count           <= '0;
            done_o                 <= 1'b0;
            status_o               <= 3'd0;
            input_buffer_status_o  <= 2'd0;
            bfpexp_o               <= '0;
            run_pipe               <= '0;
        end else begin
            done_o <= 1'b0;

            if (sact_istream_i && sample_count < FFT_LENGTH)
                sample_count <= sample_count + 1'b1;

            if (sample_count == 0)
                input_buffer_status_o <= 2'd0;
            else if (sample_count < FFT_LENGTH)
                input_buffer_status_o <= 2'd1;
            else
                input_buffer_status_o <= 2'd2;

            run_pipe <= {run_pipe[0], run_i};

            if (run_pipe[1]) begin
                done_o   <= 1'b1;
                status_o <= 3'd5;
            end
        end
    end

    always_comb begin
        dmadr_real_o = dmaa_i + 1;
        dmadr_imag_o = -$signed(dmaa_i);
    end

endmodule

module r2fft_tribuf_impl_mock #(parameter int FFT_LENGTH = 8, parameter int FFT_DW = 18, parameter int PL_DEPTH = 3, parameter int FFT_N = $clog2(FFT_LENGTH)) (
    input logic clk, input logic rst_i, input logic run_i, input logic ifft_i,
    output logic done_o, output logic [2:0] status_o, output logic [1:0] input_buffer_status_o, output logic signed [7:0] bfpexp_o,
    input logic sact_istream_i, input logic signed [FFT_DW-1:0] sdw_istream_real_i, input logic signed [FFT_DW-1:0] sdw_istream_imag_i,
    input logic dmaact_i, input logic [FFT_N-1:0] dmaa_i, output logic signed [FFT_DW-1:0] dmadr_real_o, output logic signed [FFT_DW-1:0] dmadr_imag_o
);
    r2fft_tribuf_impl #(
        .FFT_LENGTH(FFT_LENGTH), .FFT_DW(FFT_DW), .PL_DEPTH(PL_DEPTH), .FFT_N(FFT_N)
    ) impl (.*);
endmodule
