`timescale 1ns/1ps
module tb_dashboard_renderer;
    logic [9:0] x, y;
    logic active = 1'b1;
    logic [9:0] spectrum;
    logic signed [31:0] mfcc;
    logic [7:0] bfp;
    logic fft_run, fft_done, busy;
    logic [2:0] fft_status;
    logic [1:0] input_status;
    logic [31:0] frame;
    logic [8:0] spectrum_index;
    logic [3:0] mfcc_index;
    logic [3:0] r, g, b;

    dashboard_renderer dut (
        .pixel_x(x), .pixel_y(y), .active_video(active), .spectrum_value(spectrum),
        .mfcc_value(mfcc), .bfpexp(bfp), .fft_run(fft_run), .fft_done(fft_done),
        .fft_status(fft_status), .fft_input_status(input_status),
        .feature_busy(busy), .frame_count(frame), .spectrum_read_index(spectrum_index),
        .mfcc_read_index(mfcc_index), .red(r), .green(g), .blue(b));

    initial begin
        spectrum = 10'd255; mfcc = 32'sd0; bfp = 0;
        fft_run = 1; fft_done = 0; busy = 0; fft_status = 0;
        input_status = 0; frame = 32'd7;
        // Bin 100 maps to x=64+100 and a nonzero bar reaches the graph bottom.
        x = 10'd164; y = 10'd280; #1;
        if (b != 4'hf || g != 4'hc) $fatal(1, "spectrum pixel missing: %h%h%h", r,g,b);
        if (spectrum_index != 9'd100) $fatal(1, "wrong bin index=%0d", spectrum_index);
        // Positive Q16.16 MFCC produces a bar above the zero line.
        mfcc = 32'sh0010_0000; x = 10'd70; y = 10'd404; #1;
        if (r != 4'hf || g != 4'hf) $fatal(1, "MFCC pixel missing: %h%h%h", r,g,b);
        if (mfcc_index != 0) $fatal(1, "wrong MFCC index=%0d", mfcc_index);
        $display("PASS: dashboard renderer synthetic FFT/MFCC pixels");
        $finish;
    end
endmodule
