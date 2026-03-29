module fft_tx_bridge_fifo #(
    parameter int FFT_DW     = 18,
    parameter int BFPEXP_W   = 8,
    parameter int FIFO_DEPTH = 2048
)(
    input  logic clk,
    input  logic rst,

    input  logic push_i,
    input  logic signed [FFT_DW-1:0] fft_real_i,
    input  logic signed [FFT_DW-1:0] fft_imag_i,
    input  logic fft_last_i,
    input  logic signed [BFPEXP_W-1:0] bfpexp_i,

    input  logic pop_i,

    output logic valid_o,
    output logic signed [FFT_DW-1:0] fft_real_o,
    output logic signed [FFT_DW-1:0] fft_imag_o,
    output logic fft_last_o,
    output logic signed [BFPEXP_W-1:0] bfpexp_o,

    output logic full_o,
    output logic empty_o,
    output logic overflow_o,
    output logic [$clog2(FIFO_DEPTH+1)-1:0] level_o
);

    // FIFO RTL removida intencionalmente para migracao para FIFO IP externa.
    logic unused_inputs_sink;
    assign unused_inputs_sink = clk ^ rst ^ push_i ^ pop_i ^ fft_last_i ^
                                fft_real_i[0] ^ fft_imag_i[0] ^ bfpexp_i[0];

    assign valid_o    = 1'b0 & unused_inputs_sink;
    assign fft_real_o = '0;
    assign fft_imag_o = '0;
    assign fft_last_o = 1'b0;
    assign bfpexp_o   = '0;
    assign full_o     = 1'b0;
    assign empty_o    = 1'b1;
    assign overflow_o = 1'b0;
    assign level_o    = '0;

endmodule
