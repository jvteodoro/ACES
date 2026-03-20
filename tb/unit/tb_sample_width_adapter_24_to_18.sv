`timescale 1ns/1ps

module tb_sample_width_adapter_24_to_18;
    logic signed [23:0] sample_24_i;
    logic signed [17:0] sample_18_o;

    sample_width_adapter_24_to_18 dut (
        .sample_24_i(sample_24_i),
        .sample_18_o(sample_18_o)
    );

    task check(input logic signed [23:0] x, input logic signed [17:0] expected);
        begin
            sample_24_i = x;
            #1;
            if (sample_18_o !== expected) begin
                $error("adapter mismatch: in=%0d out=%0d expected=%0d", x, sample_18_o, expected);
            end
        end
    endtask

    initial begin
        check(24'sd0,        18'sd0);
        check(24'sd64,       18'sd1);
        check(24'sd128,      18'sd2);
        check(-24'sd64,      -18'sd1);
        check(-24'sd128,     -18'sd2);
        check(24'sd8388480,  18'sd131070);
        check(-24'sd8388480, -18'sd131070);
        $display("tb_sample_width_adapter_24_to_18 PASSED");
        $finish;
    end
endmodule
