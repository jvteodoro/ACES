`timescale 1ns/1ps

module tb_aces_fft_ingest;

    localparam int FFT_DW = 18;

    logic clk;
    logic rst;
    logic fft_sample_valid_i;
    logic signed [FFT_DW-1:0] fft_sample_i;
    logic sact_istream_o;
    logic signed [FFT_DW-1:0] sdw_istream_real_o;
    logic signed [FFT_DW-1:0] sdw_istream_imag_o;

    always #5 clk = ~clk;

    aces_fft_ingest #(
        .FFT_DW(FFT_DW)
    ) dut (
        .clk(clk),
        .rst(rst),
        .fft_sample_valid_i(fft_sample_valid_i),
        .fft_sample_i(fft_sample_i),
        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o)
    );

    initial begin
        clk                = 1'b0;
        rst                = 1'b1;
        fft_sample_valid_i = 1'b0;
        fft_sample_i       = '0;

        repeat (2) @(posedge clk);
        rst = 1'b0;

        @(posedge clk);
        fft_sample_valid_i = 1'b1;
        fft_sample_i       = 18'sd1234;
        @(posedge clk);
        assert (sact_istream_o == 1'b1) else $error("sact deveria pulsar com sample valido");
        assert (sdw_istream_real_o == 18'sd1234) else $error("real incorreto");
        assert (sdw_istream_imag_o == '0) else $error("imag deveria ser zero");

        fft_sample_valid_i = 1'b0;
        @(posedge clk);
        assert (sact_istream_o == 1'b0) else $error("sact deveria durar um ciclo");

        $display("tb_aces_fft_ingest PASSED");
        $finish;
    end

endmodule
