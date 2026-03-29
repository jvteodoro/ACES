`timescale 1ns/1ps

module tb_aces_audio_to_fft_pipeline;

    localparam int SAMPLE_W = 18;
    localparam time CLK_HALF = 5ns;
    localparam time SCK_HALF = 20ns;

    logic rst;
    logic mic_sck_i;
    logic mic_ws_i;
    logic mic_sd_i;
    logic clk;

    logic sample_valid_mic_o;
    logic signed [SAMPLE_W-1:0] sample_mic_o;
    logic signed [23:0] sample_24_dbg_o;
    logic fft_sample_valid_o;
    logic signed [SAMPLE_W-1:0] fft_sample_o;
    logic sact_istream_o;
    logic signed [SAMPLE_W-1:0] sdw_istream_real_o;
    logic signed [SAMPLE_W-1:0] sdw_istream_imag_o;

    logic signed [23:0] vectors [0:2];
    int capture_count;

    always #CLK_HALF clk = ~clk;

    task automatic sck_pulse;
        begin
            #SCK_HALF mic_sck_i = 1'b1;
            #SCK_HALF mic_sck_i = 1'b0;
        end
    endtask

    task automatic send_left_sample(input logic signed [23:0] sample_in);
        integer bit_idx;
        begin
            mic_ws_i = 1'b1;
            repeat (32) begin
                mic_sd_i = 1'b0;
                sck_pulse();
            end

            mic_ws_i = 1'b0;
            mic_sd_i = 1'b0;
            sck_pulse();

            for (bit_idx = 23; bit_idx >= 0; bit_idx--) begin
                mic_sd_i = sample_in[bit_idx];
                sck_pulse();
            end

            repeat (7) begin
                mic_sd_i = 1'b0;
                sck_pulse();
            end
        end
    endtask

    aces_audio_to_fft_pipeline #(
        .SAMPLE_W(SAMPLE_W)
    ) dut (
        .rst(rst),
        .mic_sck_i(mic_sck_i),
        .mic_ws_i(mic_ws_i),
        .mic_sd_i(mic_sd_i),
        .clk(clk),
        .sample_valid_mic_o(sample_valid_mic_o),
        .sample_mic_o(sample_mic_o),
        .sample_24_dbg_o(sample_24_dbg_o),
        .fft_sample_valid_o(fft_sample_valid_o),
        .fft_sample_o(fft_sample_o),
        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o)
    );

    always @(posedge clk) begin
        if (sact_istream_o) begin
            assert (sample_mic_o == vectors[capture_count][23:6])
            else $fatal(1, "sample_mic mismatch idx=%0d", capture_count);

            assert (fft_sample_valid_o == 1'b1)
            else $fatal(1, "fft_sample_valid_o deveria acompanhar a amostra");

            assert (fft_sample_o == vectors[capture_count][23:6])
            else $fatal(1, "fft_sample mismatch idx=%0d", capture_count);

            assert (sdw_istream_real_o == vectors[capture_count][23:6])
            else $fatal(1, "real stream mismatch idx=%0d", capture_count);

            assert (sdw_istream_imag_o == '0)
            else $fatal(1, "imag stream deveria ser zero");

            capture_count = capture_count + 1;
        end
    end

    initial begin
        vectors[0] = 24'h000120;
        vectors[1] = -24'sh000240;
        vectors[2] = 24'h123456;

        clk         = 1'b0;
        rst         = 1'b1;
        mic_sck_i   = 1'b0;
        mic_ws_i    = 1'b1;
        mic_sd_i    = 1'b0;
        capture_count = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        send_left_sample(vectors[0]);
        send_left_sample(vectors[1]);
        send_left_sample(vectors[2]);

        repeat (10) @(posedge clk);
        assert (capture_count == 3)
        else $fatal(1, "Esperadas 3 capturas, obtidas %0d", capture_count);

        $display("tb_aces_audio_to_fft_pipeline PASSED");
        $finish;
    end

endmodule
