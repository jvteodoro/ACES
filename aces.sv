module aces(input clk, input rst);


    logic run, ifft;
    logic done_o, [2:0] status_o, [1:0] input_buffer_status_o, [7:0] bfpexp_o;
    // input stream
    logic sact_istream_i, [FFT_DW-1:0]  sdw_istream_real_i, [FFT_DW-1:0]  sdw_istream_imag_i;
    // output stream
    logic dmaact_i, [FFT_N-1:0] dmaa_i, [FFT_DW-1:0] dmadr_real_o, [FFT_DW-1:0] dmadr_imag_o;

    r2fft_tribuf_impl
  #(
    .FFT_LENGTH(512), // FFT Frame Length, 2^N
    .FFT_DW(18),       // Data Bitwidth
    .PL_DEPTH(3),      // Pipeline Stage Depth Configuration (0 - 3)
    )
    r2fft
  (

   .clk,
   .rst_i(rst),
   .run_i(run),
   .ifft_i(ifft),

   .done_o,
   .status_o,
   .input_buffer_status_o,
   .bfpexp_o,

   // input stream
   .sact_istream_i,
   .sdw_istream_real_i,
   .sdw_istream_imag_i,

    // output / DMA bus
   .dmaact_i,
   .dmaa_i,
   .dmadr_real_o,
   .dmadr_imag_o
   
   );

endmodule