`timescale 1ns/1ps
module tb_audio_dc_blocker;
    logic clk = 0, rst = 1, valid = 0;
    logic signed [17:0] sample_i;
    logic sample_valid_o;
    logic signed [17:0] sample_o;
    integer i;
    integer max_dc_tail;
    integer max_tone;

    always #5 clk = ~clk;

    audio_dc_blocker dut (
        .clk(clk), .rst(rst), .sample_valid_i(valid), .sample_i(sample_i),
        .sample_valid_o(sample_valid_o), .sample_o(sample_o)
    );

    initial begin
        sample_i = 18'sd0;
        repeat (3) @(posedge clk);
        rst = 0;

        // A constant microphone offset must decay close to zero.
        max_dc_tail = 0;
        for (i = 0; i < 3000; i = i + 1) begin
            @(negedge clk); valid = 1; sample_i = 18'sd12000;
            @(posedge clk); #1;
            if (i > 2500 && (sample_o < 0 ? -sample_o : sample_o) > max_dc_tail)
                max_dc_tail = (sample_o < 0) ? -sample_o : sample_o;
        end
        if (max_dc_tail > 100)
            $fatal(1, "DC blocker residual too large: %0d", max_dc_tail);

        // A 4 kHz tone must remain clearly nonzero.
        max_tone = 0;
        for (i = 0; i < 96; i = i + 1) begin
            @(negedge clk); sample_i = (i % 4 == 0) ? 18'sd10000 :
                                        (i % 4 == 2) ? -18'sd10000 : 18'sd0;
            @(posedge clk); #1;
            if ((sample_o < 0 ? -sample_o : sample_o) > max_tone)
                max_tone = (sample_o < 0) ? -sample_o : sample_o;
        end
        if (max_tone < 7000)
            $fatal(1, "4 kHz signal was attenuated excessively: %0d", max_tone);

        $display("PASS: 50 Hz audio DC blocker, residual=%0d tone_peak=%0d", max_dc_tail, max_tone);
        $finish;
    end
endmodule
