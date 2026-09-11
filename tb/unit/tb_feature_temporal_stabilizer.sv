`timescale 1ns/1ps

module tb_feature_temporal_stabilizer;
    logic clk = 1'b0, rst = 1'b1, valid = 1'b0, done = 1'b0;
    logic [3:0] index = '0;
    logic signed [31:0] data = '0;
    logic out_valid, out_done;
    logic [3:0] out_index;
    logic signed [31:0] out_data;

    always #5 clk = ~clk;

    feature_temporal_stabilizer dut (
        .clk(clk), .rst(rst), .result_valid_i(valid), .result_index_i(index),
        .result_data_i(data), .frame_done_i(done), .result_valid_o(out_valid),
        .result_index_o(out_index), .result_data_o(out_data), .frame_done_o(out_done)
    );

    task automatic send(input integer value, input integer expected);
        begin
            @(negedge clk); valid <= 1'b1; index <= 0; data <= value;
            @(posedge clk); #1;
            assert (out_valid && out_data == expected)
                else $fatal(1, "EMA expected=%0d got=%0d", expected, out_data);
            @(negedge clk); valid <= 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(posedge clk); rst <= 1'b0;
        send(100, 100);
        send(300, 150);
        send(100, 137);
        $display("tb_feature_temporal_stabilizer PASSED");
        $finish;
    end
endmodule
