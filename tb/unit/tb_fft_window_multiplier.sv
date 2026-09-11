`timescale 1ns/1ps

module tb_fft_window_multiplier;
    logic clk = 1'b0, rst = 1'b1, valid = 1'b0;
    logic [8:0] index = '0;
    logic signed [17:0] sample = '0;
    logic out_valid;
    logic signed [17:0] out_sample;

    always #5 clk = ~clk;

    fft_window_multiplier #(.COEFF_FILE("rtl/frontend/hann_window_q15.hex")) dut (
        .clk(clk), .rst(rst), .sample_valid_i(valid), .sample_index_i(index),
        .sample_i(sample), .sample_valid_o(out_valid), .sample_o(out_sample)
    );

    task automatic apply_and_check(input integer sample_index, input integer expected);
        begin
            @(negedge clk);
            valid <= 1'b1;
            index <= sample_index[8:0];
            sample <= 18'sd1000;
            @(posedge clk);
            #1;
            if (!out_valid || (out_sample < expected-2) || (out_sample > expected+2))
                $fatal(1, "window mismatch index=%0d expected=%0d got=%0d valid=%0d",
                       sample_index, expected, out_sample, out_valid);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk); rst <= 1'b0;
        apply_and_check(0, 0);
        apply_and_check(256, 1000);
        apply_and_check(511, 0);
        @(negedge clk); valid <= 1'b0;
        $display("tb_fft_window_multiplier PASSED");
        $finish;
    end
endmodule
