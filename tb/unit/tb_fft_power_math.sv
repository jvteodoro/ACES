`timescale 1ns/1ps

module tb_fft_power_math;
    logic clk = 1'b0, rst = 1'b1;
    logic valid = 1'b0, last = 1'b0;
    logic [8:0] index = '0;
    logic signed [17:0] real_i = '0, imag_i = '0;
    logic signed [7:0] bfpexp_i = '0;
    logic busy, result_valid, frame_done;
    logic [3:0] result_index;
    logic signed [31:0] result_data;

    always #5 clk = ~clk;

    fft_feature_analyzer dut (
        .clk(clk), .rst(rst), .fft_bin_valid_i(valid),
        .fft_bin_index_i(index), .fft_bin_real_i(real_i),
        .fft_bin_imag_i(imag_i), .fft_bfpexp_i(bfpexp_i),
        .fft_bin_last_i(last), .busy_o(busy),
        .result_valid_o(result_valid), .result_index_o(result_index),
        .result_data_o(result_data), .frame_done_o(frame_done)
    );

    initial begin
        #1;
        assert (dut.power_spectrum(18'sd1000, 18'sd0, 8'sd0) == 48'd1000000)
            else $fatal(1, "power base scale incorrect");
        assert (dut.power_spectrum(18'sd500, 18'sd0, 8'sd1) == 48'd1000000)
            else $fatal(1, "bfpexp reconstruction incorrect");
        assert (dut.power_spectrum(18'sh1ffff, 18'sh1ffff, 8'sd127) == {48{1'b1}})
            else $fatal(1, "power saturation incorrect");
        $display("tb_fft_power_math PASSED");
        $finish;
    end
endmodule
