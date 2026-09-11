`timescale 1ns/1ps

module tb_aces_audio_to_fft_pipeline_overlap;
    logic clk = 1'b0, rst = 1'b1;
    logic mic_sck = 1'b0, mic_ws = 1'b1, mic_sd = 1'b0, mic_lr = 1'b0;
    logic sample_valid, fft_valid, sact;
    logic signed [17:0] sample, fft_sample, real_sample, imag_sample;
    logic signed [23:0] sample24;

    always #5 clk = ~clk;

    aces_audio_to_fft_pipeline #(
        .SAMPLE_W(18), .FRAME_LENGTH(1024), .HOP_LENGTH(512),
        .ENABLE_WINDOW(1'b1), .ENABLE_OVERLAP(1'b1),
        .WINDOW_COEFF_FILE("rtl/frontend/hann_window_q15_1024.hex")
    ) dut (
        .rst(rst), .mic_sck_i(mic_sck), .mic_ws_i(mic_ws), .mic_sd_i(mic_sd),
        .mic_lr_i(mic_lr), .clk(clk), .sample_valid_mic_o(sample_valid),
        .sample_mic_o(sample), .sample_24_dbg_o(sample24),
        .fft_sample_valid_o(fft_valid), .fft_sample_o(fft_sample),
        .sact_istream_o(sact), .sdw_istream_real_o(real_sample),
        .sdw_istream_imag_o(imag_sample)
    );

    initial begin
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);
        assert (!fft_valid && !sact) else $fatal(1, "pipeline overlap emitiu sem amostras");
        $display("tb_aces_audio_to_fft_pipeline_overlap PASSED");
        $finish;
    end
endmodule
