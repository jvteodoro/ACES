`timescale 1ns/1ps

module tb_mel_coeff_rom;
    logic clk = 1'b0, rst = 1'b1;
    logic valid = 1'b0, last = 1'b0;
    logic [9:0] index = '0;
    logic signed [17:0] real_i = '0, imag_i = '0;
    logic signed [7:0] bfpexp_i = '0;
    logic busy, result_valid, frame_done;
    logic [3:0] result_index;
    logic signed [31:0] result_data;

    always #5 clk = ~clk;

    fft_feature_analyzer #(
        .FFT_LENGTH(1024), .USEFUL_BINS(512), .USE_MEL_ROM(1'b1),
        .MEL_ROM_FILE("rtl/analysis/mel_coeffs_1024_q16.hex"),
        .USE_LOG_ROM(1'b1), .LOG_ROM_FILE("rtl/analysis/log_mantissa_q16.hex")
    ) dut (
        .clk(clk), .rst(rst), .fft_bin_valid_i(valid),
        .fft_bin_index_i(index), .fft_bin_real_i(real_i),
        .fft_bin_imag_i(imag_i), .fft_bfpexp_i(bfpexp_i),
        .fft_bin_last_i(last), .busy_o(busy),
        .result_valid_o(result_valid), .result_index_o(result_index),
        .result_data_o(result_data), .frame_done_o(frame_done)
    );

    initial begin
        #1;
        assert (dut.mel_coeff_rom[0] == 17'h00000)
            else $fatal(1, "Mel ROM band 0/bin 0 should be zero");
        assert (dut.mel_coeff_rom[1] > 0)
            else $fatal(1, "Mel ROM rising edge missing");
        assert (dut.mel_coeff_rom[31*512 + 256] >= 0)
            else $fatal(1, "Mel ROM contains invalid sign");
        assert (dut.natural_log_q16(48'd1) == 0)
            else $fatal(1, "log ROM ln(1) mismatch");
        assert ((dut.natural_log_q16(48'd2) > 45420) &&
                (dut.natural_log_q16(48'd2) < 45432))
            else $fatal(1, "log ROM ln(2) mismatch");
        $display("tb_mel_coeff_rom PASSED");
        $finish;
    end
endmodule
