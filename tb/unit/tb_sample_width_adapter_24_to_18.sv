`timescale 1ns/1ps

module tb_sample_width_adapter_24_to_18;

    logic signed [23:0] sample_24_i;
    logic               valid_24_i;
    logic signed [17:0] sample_18_o;
    logic               valid_18_o;

    sample_width_adapter_24_to_18 dut (
        .sample_24_i(sample_24_i),
        .valid_24_i(valid_24_i),
        .sample_18_o(sample_18_o),
        .valid_18_o(valid_18_o)
    );

    task automatic check(
        input logic signed [23:0] sample_in,
        input logic               valid_in,
        input logic signed [17:0] expected_sample,
        input logic               expected_valid
    );
        begin
            sample_24_i = sample_in;
            valid_24_i  = valid_in;
            #1;

            assert (sample_18_o === expected_sample)
            else $fatal(1, "adapter mismatch: in=%0d out=%0d expected=%0d",
                        sample_in, sample_18_o, expected_sample);

            assert (valid_18_o === expected_valid)
            else $fatal(1, "valid mismatch: in=%0b out=%0b expected=%0b",
                        valid_in, valid_18_o, expected_valid);
        end
    endtask

    initial begin
        check(24'sd0,         1'b0, 18'sd0,      1'b0);
        check(24'sd63,        1'b1, 18'sd0,      1'b1);
        check(24'sd64,        1'b1, 18'sd1,      1'b1);
        check(24'sd128,       1'b1, 18'sd2,      1'b1);
        check(-24'sd1,        1'b1, -18'sd1,     1'b1);
        check(-24'sd64,       1'b1, -18'sd1,     1'b1);
        check(-24'sd65,       1'b1, -18'sd2,     1'b1);
        check(-24'sd128,      1'b1, -18'sd2,     1'b1);
        check(24'sh7FFFFF,    1'b1, 18'sh1FFFF,  1'b1);
        check(24'sh800000,    1'b1, -18'sd131072,1'b1);
        check(24'sd8388480,   1'b1, 18'sd131070, 1'b1);
        check(-24'sd8388480,  1'b1, -18'sd131070,1'b1);

        $display("tb_sample_width_adapter_24_to_18 PASSED");
        $finish;
    end

endmodule
