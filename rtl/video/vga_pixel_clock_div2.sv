module vga_pixel_clock_div2 (
    input  logic clk_50,
    input  logic rst,
    output logic pixel_clk
);
    // 25 MHz is within the tolerance of the first 640x480 VGA mode and keeps
    // the clock generation reproducible without a Quartus-generated IP.
    always_ff @(posedge clk_50 or posedge rst) begin
        if (rst)
            pixel_clk <= 1'b0;
        else
            pixel_clk <= ~pixel_clk;
    end
endmodule
