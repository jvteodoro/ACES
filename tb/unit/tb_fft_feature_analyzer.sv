`timescale 1ns/1ps

module tb_fft_feature_analyzer;
    logic clk = 0, rst = 1;
    logic valid = 0, last = 0;
    logic [8:0] index = 0;
    logic signed [17:0] real_i = 0, imag_i = 0;
    logic busy, result_valid, frame_done;
    logic [3:0] result_index;
    logic signed [31:0] result_data;
    integer result_count;

    always #5 clk = ~clk;

    fft_feature_analyzer dut (
        .clk(clk), .rst(rst),
        .fft_bin_valid_i(valid), .fft_bin_index_i(index),
        .fft_bin_real_i(real_i), .fft_bin_imag_i(imag_i),
        .fft_bin_last_i(last), .busy_o(busy),
        .result_valid_o(result_valid), .result_index_o(result_index),
        .result_data_o(result_data), .frame_done_o(frame_done)
    );

    always @(posedge clk) begin
        if (result_valid) begin
            if (result_index !== result_count[3:0]) $fatal(1, "MFCC index out of order");
            result_count = result_count + 1;
        end
        if (frame_done && result_count != 13) $fatal(1, "frame_done before 13 results");
    end

    initial begin
        result_count = 0;
        repeat (3) @(posedge clk);
        rst <= 0;
        // Constant frame: exercises every RAM write, Mel pass, log and DCT.
        for (integer i = 0; i < 512; i = i + 1) begin
            @(negedge clk);
            valid <= 1; index <= i[8:0]; real_i <= 18'sd1000; imag_i <= 18'sd0;
            last <= (i == 511);
        end
        @(negedge clk); valid <= 0; last <= 0;
        wait (frame_done);
        #1;
        if (result_count != 12 || !result_valid || result_index != 12)
            $fatal(1, "expected final MFCC result, got count=%0d index=%0d valid=%0d", result_count, result_index, result_valid);
        $display("PASS: 13 MFCC results emitted");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "timeout");
    end
endmodule
