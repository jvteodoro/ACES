`timescale 1ns/1ps

module tb_i2s_rx_adapter_24;

    localparam int  MAX_CAPTURES = 8;
    localparam time SCK_HALF     = 40ns;

    logic rst;
    logic sck_i;
    logic ws_i;
    logic sd_i;
    logic lr_i;

    logic               sample_valid_o;
    logic signed [23:0] sample_24_o;
    logic               frame_error_o;
    logic               active_o;

    logic signed [23:0] captured_samples [0:MAX_CAPTURES-1];
    int                 capture_count;
    bit                 saw_active;

    i2s_rx_adapter_24 dut (
        .rst(rst),
        .sck_i(sck_i),
        .ws_i(ws_i),
        .sd_i(sd_i),
        .lr_i(lr_i),
        .sample_valid_o(sample_valid_o),
        .sample_24_o(sample_24_o),
        .frame_error_o(frame_error_o),
        .active_o(active_o)
    );

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
            ws_i = ws_val;
            sd_i = sd_val;

            #(SCK_HALF - drive_delay);
            sck_i = 1'b1;
            #SCK_HALF;
            sck_i = 1'b0;
        end
    endtask

    task automatic send_slot(
        input logic               slot_ws,
        input logic signed [23:0] sample_in,
        input time                drive_delay
    );
        integer bit_idx;
        begin
            sck_cycle(drive_delay, slot_ws, 1'b0);

            for (bit_idx = 23; bit_idx >= 0; bit_idx--) begin
                sck_cycle(drive_delay, slot_ws, sample_in[bit_idx]);
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

    task automatic reset_dut(input logic lr_sel);
        integer idx;
        begin
            rst   = 1'b1;
            sck_i = 1'b0;
            ws_i  = 1'b1;
            sd_i  = 1'b0;
            lr_i  = lr_sel;

            capture_count = 0;
            saw_active    = 1'b0;

            for (idx = 0; idx < MAX_CAPTURES; idx++) begin
                captured_samples[idx] = '0;
            end

            #200ns;
            rst = 1'b0;
            #100ns;
        end
    endtask

    task automatic expect_capture_count(input int expected_count);
        begin
            assert (capture_count == expected_count)
            else $fatal(1, "Esperado %0d captures, obtido %0d",
                        expected_count, capture_count);
        end
    endtask

    task automatic expect_sample(
        input int                 idx,
        input logic signed [23:0] expected_sample
    );
        begin
            assert (captured_samples[idx] === expected_sample)
            else $fatal(1, "Mismatch idx=%0d exp=0x%06h got=0x%06h",
                        idx, expected_sample[23:0], captured_samples[idx][23:0]);
        end
    endtask

    task automatic expect_no_error;
        begin
            assert (!frame_error_o)
            else $fatal(1, "frame_error_o nao deveria ter sido acionado");

            assert (saw_active)
            else $fatal(1, "active_o nunca ficou alto durante a captura");
        end
    endtask

    task automatic send_broken_left_slot(
        input logic signed [23:0] sample_in,
        input int                 valid_bits,
        input time                drive_delay
    );
        integer bit_idx;
        begin
            send_slot(1'b1, 24'sd0, drive_delay);

            sck_cycle(drive_delay, 1'b0, 1'b0);

            for (bit_idx = 23; bit_idx > 23 - valid_bits; bit_idx--) begin
                sck_cycle(drive_delay, 1'b0, sample_in[bit_idx]);
            end

            repeat (4) begin
                sck_cycle(drive_delay, 1'b1, 1'b0);
            end
        end
    endtask

    always @(negedge sck_i or posedge rst) begin
        if (rst) begin
            capture_count = 0;
            saw_active    = 1'b0;
        end else begin
            if (active_o) begin
                saw_active = 1'b1;
            end

            if (sample_valid_o) begin
                assert (capture_count < MAX_CAPTURES)
                else $fatal(1, "Mais captures do que o limite do TB");

                captured_samples[capture_count] = sample_24_o;
                capture_count = capture_count + 1;
            end
        end
    end

    initial begin
        $display("==== INICIO DO TESTE I2S RX ADAPTER 24 ====");

        reset_dut(1'b0);

        send_stereo_frame(24'sh123456, 24'sh654321, 0ns, 11ns);
        send_stereo_frame(-24'sh000240, 24'sh040302, 13ns, 5ns);
        send_stereo_frame(24'sh7ABCDE, -24'sh000001, 31ns, 7ns);

        expect_capture_count(3);
        expect_sample(0, 24'sh123456);
        expect_sample(1, -24'sh000240);
        expect_sample(2, 24'sh7ABCDE);
        expect_no_error();

        reset_dut(1'b1);

        send_stereo_frame(24'sh111111, -24'sh100000, 7ns, 0ns);
        send_stereo_frame(24'sh222222, 24'sh000123, 9ns, 17ns);
        send_stereo_frame(-24'sh000321, -24'sh345678, 5ns, 29ns);

        expect_capture_count(3);
        expect_sample(0, -24'sh100000);
        expect_sample(1, 24'sh000123);
        expect_sample(2, -24'sh345678);
        expect_no_error();

        reset_dut(1'b0);
        send_broken_left_slot(24'sh456789, 8, 13ns);

        assert (capture_count == 0)
        else $fatal(1, "Slot quebrado nao deveria gerar sample_valid_o");

        assert (frame_error_o)
        else $fatal(1, "frame_error_o deveria indicar slot interrompido");

        $display("tb_i2s_rx_adapter_24 PASSED");
        #200ns;
        $finish;
    end

endmodule
