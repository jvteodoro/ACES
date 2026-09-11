`timescale 1ns/1ps
module tb_vga_timing;
    logic clk = 0, rst = 1;
    logic [9:0] x, y;
    logic active, frame_start, hsync, vsync;
    vga_timing dut (.pixel_clk(clk), .rst(rst), .pixel_x(x), .pixel_y(y),
                    .active_video(active), .frame_start(frame_start),
                    .hsync(hsync), .vsync(vsync));
    always #5 clk = ~clk;
    integer i, active_count, hlow_count, frame_count;
    initial begin
        repeat (2) @(posedge clk); @(negedge clk); rst = 0;
        active_count = 0; hlow_count = 0; frame_count = 0;
        for (i = 0; i < 800*525; i = i + 1) begin
            @(negedge clk);
            if (active) active_count = active_count + 1;
            if (!hsync) hlow_count = hlow_count + 1;
            if (frame_start) frame_count = frame_count + 1;
        end
        if (active_count != 640*480) $fatal(1, "active pixels=%0d", active_count);
        if (hlow_count != 96*525) $fatal(1, "hsync low clocks=%0d", hlow_count);
        if (frame_count != 1) $fatal(1, "frame_start count=%0d", frame_count);
        $display("PASS: VGA 640x480 timing, active=%0d hsync_low=%0d", active_count, hlow_count);
        $finish;
    end
endmodule
