`timescale 1ns/1ps

module tb_audio_clock_fractional;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic sck, ws;
    integer toggles;
    integer cycles;
    logic previous_sck;

    always #5 clk = ~clk;

    i2s_master_clock_gen #(
        .USE_FRACTIONAL_CLOCK(1'b1),
        .SYSTEM_CLOCK_HZ(50_000_000),
        .AUDIO_SAMPLE_RATE_HZ(48_000)
    ) dut (
        .clk(clk), .rst(rst), .sck_o(sck), .ws_o(ws)
    );

    always @(posedge clk) begin
        if (rst) begin
            toggles <= 0;
            previous_sck <= 1'b0;
        end else if (sck != previous_sck) begin
            toggles <= toggles + 1;
            previous_sck <= sck;
        end
    end

    initial begin
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (50_000) @(posedge clk);
        // 50 MHz / 3.072 MHz = 16276.041 system clocks per transition.
        // The NCO must stay within one transition of the ideal count.
        if ((toggles < 3069) || (toggles > 3075))
            $fatal(1, "fractional BCLK toggle count out of range: %0d", toggles);
        $display("tb_audio_clock_fractional PASSED toggles=%0d", toggles);
        $finish;
    end
endmodule
