`timescale 1ns/1ps
module tb_dashboard_data_capture;
    logic clk50 = 0, pclk = 0, rst = 1, frame_start = 0;
    always #10 clk50 = ~clk50;
    always #17 pclk = ~pclk;
    logic fft_valid, frame_done, fft_run, fft_done, feature_busy, mfcc_valid;
    logic [9:0] fft_index; logic signed [17:0] re, im;
    logic signed [7:0] expn; logic [2:0] fft_status; logic [1:0] input_status;
    logic [3:0] mfcc_index; logic signed [31:0] mfcc_data;
    logic [8:0] spectrum_index; logic [3:0] read_mfcc_index;
    logic [9:0] spectrum; logic signed [31:0] read_mfcc;
    logic [7:0] out_exp; logic out_run, out_done, out_busy;
    logic [2:0] out_status; logic [1:0] out_input_status; logic [31:0] frame_count;

    dashboard_data_capture #(.FFT_BINS(4), .MFCC_COUNT(2)) dut (
        .clk_50(clk50), .pixel_clk(pclk), .rst(rst), .frame_start_i(frame_start),
        .fft_tx_valid_i(fft_valid), .fft_tx_index_i(fft_index),
        .fft_tx_real_i(re), .fft_tx_imag_i(im), .bfpexp_i(expn),
        .fft_run_i(fft_run), .fft_done_i(fft_done), .fft_status_i(fft_status),
        .fft_input_status_i(input_status), .feature_busy_i(feature_busy),
        .mfcc_valid_i(mfcc_valid), .mfcc_index_i(mfcc_index), .mfcc_data_i(mfcc_data),
        .feature_frame_done_i(frame_done), .spectrum_read_index_i(spectrum_index),
        .mfcc_read_index_i(read_mfcc_index), .spectrum_value_o(spectrum),
        .mfcc_value_o(read_mfcc), .bfpexp_o(out_exp), .fft_run_o(out_run),
        .fft_done_o(out_done), .fft_status_o(out_status),
        .fft_input_status_o(out_input_status), .feature_busy_o(out_busy),
        .frame_count_o(frame_count));

    task automatic write_frame(input integer base);
        begin
            @(negedge clk50); fft_index=0; re=base; im=0; fft_valid=1;
            @(negedge clk50); fft_index=1; re=base+1;
            @(negedge clk50); fft_valid=0; mfcc_index=0; mfcc_data=base*100; mfcc_valid=1;
            @(negedge clk50); mfcc_valid=0; frame_done=1;
            @(negedge clk50); frame_done=0;
        end
    endtask

    initial begin
        fft_valid=0; frame_done=0; fft_run=1; fft_done=0; feature_busy=0;
        mfcc_valid=0; fft_index=0; re=0; im=0; expn=0; fft_status=0;
        input_status=0; mfcc_index=0; mfcc_data=0; spectrum_index=0; read_mfcc_index=0;
        expn=4;
        #50 rst=0;
        write_frame(10);
        repeat (3) @(posedge pclk);
        @(negedge pclk); frame_start=1;
        @(negedge pclk); frame_start=0; spectrum_index=0; read_mfcc_index=0;
        @(posedge pclk);
        #1;
        if (spectrum < 10'd512 || read_mfcc !== 1000 || frame_count !== 1)
            $fatal(1, "incomplete frame A: spectrum=%0d mfcc=%0d frame=%0d", spectrum, read_mfcc, frame_count);
        write_frame(30);
        repeat (3) @(posedge pclk);
        // Before the next swap, bank A remains visible and cannot be mixed.
        #1;
        if (spectrum < 10'd512 || spectrum >= 10'd900 || read_mfcc !== 1000)
            $fatal(1, "tearing before swap");
        @(negedge pclk); frame_start=1;
        @(negedge pclk); frame_start=0; @(posedge pclk); @(posedge pclk); #1;
        if (spectrum < 10'd512 || read_mfcc !== 3000 || frame_count !== 2)
            $fatal(1, "incomplete frame B: spectrum=%0d mfcc=%0d frame=%0d", spectrum, read_mfcc, frame_count);
        write_frame(5);
        repeat (3) @(posedge pclk);
        @(negedge pclk); frame_start=1;
        @(negedge pclk); frame_start=0; @(posedge pclk); @(posedge pclk); #1;
        if (spectrum >= 10'd512)
            $fatal(1, "peak hold rescaled a quieter frame: spectrum=%0d", spectrum);
        $display("PASS: dashboard double-buffer snapshot isolation");
        $finish;
    end
endmodule
