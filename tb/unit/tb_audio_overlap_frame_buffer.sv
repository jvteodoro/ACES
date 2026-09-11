`timescale 1ns/1ps

module tb_audio_overlap_frame_buffer;
    localparam int N = 8;
    localparam int HOP = 4;
    logic clk = 1'b0, rst = 1'b1, sample_valid = 1'b0;
    logic signed [15:0] sample = '0;
    logic out_valid, out_start, out_last;
    logic signed [15:0] out_sample;
    integer input_count = 0, output_count = 0, frame_count = 0;

    always #5 clk = ~clk;

    audio_overlap_frame_buffer #(.SAMPLE_W(16), .FRAME_LENGTH(N), .HOP_LENGTH(HOP)) dut (
        .clk(clk), .rst(rst), .sample_valid_i(sample_valid), .sample_i(sample),
        .frame_sample_valid_o(out_valid), .frame_sample_o(out_sample),
        .frame_start_o(out_start), .frame_last_o(out_last)
    );

    always @(posedge clk) begin
        if (!rst && out_valid) begin
            assert (out_sample == ((frame_count * HOP) + output_count % N))
                else $fatal(1, "sample mismatch frame=%0d pos=%0d got=%0d",
                            frame_count, output_count % N, out_sample);
            if (output_count % N == 0) begin
                assert (out_start) else $fatal(1, "frame start missing");
            end else assert (!out_start) else $fatal(1, "spurious frame start");
            if (output_count % N == N-1) begin
                assert (out_last) else $fatal(1, "frame last missing");
                frame_count = frame_count + 1;
            end
            output_count = output_count + 1;
        end
    end

    initial begin
        repeat (2) @(posedge clk);
        rst = 1'b0;
        for (input_count = 0; input_count < 16; input_count = input_count + 1) begin
            @(negedge clk);
            sample <= input_count;
            sample_valid <= 1'b1;
            @(negedge clk);
            sample_valid <= 1'b0;
            repeat (2) @(negedge clk);
        end
        repeat (40) @(posedge clk);
        assert (output_count == 24)
            else $fatal(1, "expected 24 output samples, got %0d", output_count);
        assert (frame_count == 3)
            else $fatal(1, "expected three frames, got %0d", frame_count);
        $display("tb_audio_overlap_frame_buffer PASSED");
        $finish;
    end
endmodule
