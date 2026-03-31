`timescale 1ns/1ps

module tb_aces_audio_to_fft_pipeline;

    localparam int  SAMPLE_W      = 18;
    localparam int  MAX_EXPECTED  = 8;
    localparam time CLK_HALF      = 5ns;
    localparam time SCK_HALF      = 37ns;

    logic rst;
    logic mic_sck_i;
    logic mic_ws_i;
    logic mic_sd_i;
    logic mic_lr_i;
    logic clk;

    logic sample_valid_mic_o;
    logic signed [SAMPLE_W-1:0] sample_mic_o;
    logic signed [23:0] sample_24_dbg_o;
    logic fft_sample_valid_o;
    logic signed [SAMPLE_W-1:0] fft_sample_o;
    logic sact_istream_o;
    logic signed [SAMPLE_W-1:0] sdw_istream_real_o;
    logic signed [SAMPLE_W-1:0] sdw_istream_imag_o;

    logic signed [23:0] expected24 [0:MAX_EXPECTED-1];
    logic signed [17:0] expected18 [0:MAX_EXPECTED-1];

    int expected_total;
    int observed_count;
    bit sact_prev;
    bit saw_sample_pulse;

    always #CLK_HALF clk = ~clk;

    function automatic logic signed [17:0] trunc_24_to_18(
        input logic signed [23:0] sample_i
    );
        trunc_24_to_18 = sample_i[23:6];
    endfunction

    task automatic load_expected(
        input int                 idx,
        input logic signed [23:0] sample_i
    );
        begin
            expected24[idx] = sample_i;
            expected18[idx] = trunc_24_to_18(sample_i);
        end
    endtask

    task automatic sck_cycle(
        input time  drive_delay,
        input logic ws_val,
        input logic sd_val
    );
        begin
            assert (drive_delay < SCK_HALF)
            else $fatal(1, "drive_delay=%0t precisa ser menor que SCK_HALF=%0t",
                        drive_delay, SCK_HALF);

            #drive_delay;
            mic_ws_i = ws_val;
            mic_sd_i = sd_val;

            #(SCK_HALF - drive_delay);
            mic_sck_i = 1'b1;
            #SCK_HALF;
            mic_sck_i = 1'b0;
        end
    endtask

    task automatic send_slot(
        input logic               slot_ws,
        input logic signed [23:0] sample_i,
        input time                drive_delay
    );
        integer bit_idx;
        begin
            sck_cycle(drive_delay, slot_ws, 1'b0);

            for (bit_idx = 23; bit_idx >= 0; bit_idx--) begin
                sck_cycle(drive_delay, slot_ws, sample_i[bit_idx]);
            end

            repeat (7) begin
                sck_cycle(drive_delay, slot_ws, 1'b0);
            end
        end
    endtask

    task automatic send_stereo_frame(
        input logic signed [23:0] left_sample,
        input logic signed [23:0] right_sample,
        input time                left_delay,
        input time                right_delay
    );
        begin
            send_slot(1'b1, right_sample, right_delay);
            send_slot(1'b0, left_sample,  left_delay);
        end
    endtask

    task automatic start_scenario(
        input logic lr_sel,
        input int   sample_count
    );
        begin
            rst       = 1'b1;
            mic_sck_i = 1'b0;
            mic_ws_i  = 1'b1;
            mic_sd_i  = 1'b0;
            mic_lr_i  = lr_sel;

            expected_total = sample_count;

            repeat (4) @(posedge clk);
            rst = 1'b0;
            repeat (6) @(posedge clk);
        end
    endtask

    task automatic finish_scenario;
        begin
            repeat (40) @(posedge clk);

            assert (observed_count == expected_total)
            else $fatal(1, "Esperadas %0d amostras, obtidas %0d",
                        expected_total, observed_count);

            assert (saw_sample_pulse)
            else $fatal(1, "Nenhum pulso de stream foi observado");
        end
    endtask

    aces_audio_to_fft_pipeline #(
        .SAMPLE_W(SAMPLE_W)
    ) dut (
        .rst(rst),
        .mic_sck_i(mic_sck_i),
        .mic_ws_i(mic_ws_i),
        .mic_sd_i(mic_sd_i),
        .mic_lr_i(mic_lr_i),
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

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            observed_count   = 0;
            sact_prev        = 1'b0;
            saw_sample_pulse = 1'b0;
        end else begin
            assert (sample_valid_mic_o === fft_sample_valid_o)
            else $fatal(1, "sample_valid_mic_o e fft_sample_valid_o divergem");

            assert (fft_sample_valid_o === sact_istream_o)
            else $fatal(1, "fft_sample_valid_o e sact_istream_o divergem");

            if (sact_prev && sact_istream_o) begin
                $fatal(1, "sact_istream_o permaneceu alto por mais de 1 ciclo");
            end

            if (sact_istream_o) begin
                assert (observed_count < expected_total)
                else $fatal(1, "Mais amostras observadas do que o esperado");

                assert (sample_24_dbg_o === expected24[observed_count])
                else $fatal(1, "sample_24_dbg_o mismatch idx=%0d exp=0x%06h got=0x%06h",
                            observed_count, expected24[observed_count][23:0], sample_24_dbg_o[23:0]);

                assert (sample_mic_o === expected18[observed_count])
                else $fatal(1, "sample_mic_o mismatch idx=%0d exp=0x%05h got=0x%05h",
                            observed_count, expected18[observed_count], sample_mic_o);

                assert (fft_sample_o === expected18[observed_count])
                else $fatal(1, "fft_sample_o mismatch idx=%0d exp=0x%05h got=0x%05h",
                            observed_count, expected18[observed_count], fft_sample_o);

                assert (sdw_istream_real_o === expected18[observed_count])
                else $fatal(1, "sdw_istream_real_o mismatch idx=%0d exp=0x%05h got=0x%05h",
                            observed_count, expected18[observed_count], sdw_istream_real_o);

                assert (sdw_istream_imag_o === '0)
                else $fatal(1, "sdw_istream_imag_o deveria ser zero");

                observed_count   = observed_count + 1;
                saw_sample_pulse = 1'b1;
            end

            sact_prev = sact_istream_o;
        end
    end

    initial begin
        clk = 1'b0;

        load_expected(0, 24'h000120);
        load_expected(1, -24'sh000240);
        load_expected(2, 24'h123456);

        start_scenario(1'b0, 3);

        send_stereo_frame(expected24[0], 24'h765432, 0ns, 9ns);
        send_stereo_frame(expected24[1], 24'h654321, 13ns, 5ns);
        send_stereo_frame(expected24[2], -24'sh000001, 29ns, 7ns);

        finish_scenario();

        load_expected(0, -24'sh100000);
        load_expected(1, 24'h000321);

        start_scenario(1'b1, 2);

        send_stereo_frame(24'h111111, expected24[0], 7ns, 0ns);
        send_stereo_frame(-24'sh000321, expected24[1], 11ns, 23ns);

        finish_scenario();

        $display("tb_aces_audio_to_fft_pipeline PASSED");
        $finish;
    end

endmodule
