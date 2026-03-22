`timescale 1ns/1ps

module tb_top_level_test;

    localparam int FFT_LENGTH = 4;
    localparam int FFT_DW     = 18;

    logic key0, key1, key2, key3, reset_n;
    logic sw0, sw1, sw2, sw3, sw4, sw5, sw6, sw7, sw8, sw9;
    logic clock_50, clock2_50, clock3_50, clock4_50;

    logic ledr0, ledr1, ledr2, ledr3, ledr4, ledr5, ledr6, ledr7, ledr8, ledr9;
    logic [6:0] hex0_o, hex1_o, hex2_o, hex3_o, hex4_o, hex5_o;

    tri gpio_0_d0, gpio_0_d1, gpio_0_d2, gpio_0_d3, gpio_0_d4, gpio_0_d5, gpio_0_d6, gpio_0_d7,
        gpio_0_d8, gpio_0_d9, gpio_0_d10, gpio_0_d11, gpio_0_d12, gpio_0_d13, gpio_0_d14, gpio_0_d15,
        gpio_0_d16, gpio_0_d17, gpio_0_d18, gpio_0_d19, gpio_0_d20, gpio_0_d21, gpio_0_d22, gpio_0_d23,
        gpio_0_d24, gpio_0_d25, gpio_0_d26, gpio_0_d27, gpio_0_d28, gpio_0_d29, gpio_0_d30, gpio_0_d31,
        gpio_0_d32, gpio_0_d33, gpio_0_d34, gpio_0_d35;

    tri gpio_1_d0, gpio_1_d1, gpio_1_d2, gpio_1_d3, gpio_1_d5, gpio_1_d6, gpio_1_d7, gpio_1_d8, gpio_1_d9,
        gpio_1_d10, gpio_1_d11, gpio_1_d12, gpio_1_d13, gpio_1_d14, gpio_1_d15, gpio_1_d16, gpio_1_d17,
        gpio_1_d18, gpio_1_d19, gpio_1_d20, gpio_1_d21, gpio_1_d22, gpio_1_d23, gpio_1_d24, gpio_1_d25,
        gpio_1_d26, gpio_1_d27, gpio_1_d28, gpio_1_d29, gpio_1_d30, gpio_1_d31, gpio_1_d32, gpio_1_d33,
        gpio_1_d34, gpio_1_d35;
    logic gpio_1_d4;

    logic tb_clk_drive;
    logic tb_rst_drive;
    logic tb_capture_leds_drive;
    logic tb_capture_hex_drive;
    logic tb_capture_gpio_drive;
    logic tb_capture_clear_drive;
    assign gpio_0_d0 = tb_clk_drive;
    assign gpio_0_d1 = tb_rst_drive;
    assign gpio_0_d2 = tb_capture_leds_drive;
    assign gpio_0_d4 = tb_capture_hex_drive;
    assign gpio_0_d5 = tb_capture_gpio_drive;
    assign gpio_0_d6 = tb_capture_clear_drive;

    always #5 tb_clk_drive = ~tb_clk_drive;

    task automatic pulse_capture_all;
        begin
            tb_capture_leds_drive = 1'b1;
            tb_capture_hex_drive  = 1'b1;
            tb_capture_gpio_drive = 1'b1;
            @(posedge tb_clk_drive);
            tb_capture_leds_drive = 1'b0;
            tb_capture_hex_drive  = 1'b0;
            tb_capture_gpio_drive = 1'b0;
        end
    endtask

    top_level_test #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .N_POINTS(512),
        .N_EXAMPLES(8),
        .I2S_CLOCK_DIV(4)
    ) dut (
        .key0(key0), .key1(key1), .key2(key2), .key3(key3), .reset_n(reset_n),
        .sw0(sw0), .sw1(sw1), .sw2(sw2), .sw3(sw3), .sw4(sw4), .sw5(sw5), .sw6(sw6), .sw7(sw7), .sw8(sw8), .sw9(sw9),
        .clock_50(clock_50), .clock2_50(clock2_50), .clock3_50(clock3_50), .clock4_50(clock4_50),
        .ledr0(ledr0), .ledr1(ledr1), .ledr2(ledr2), .ledr3(ledr3), .ledr4(ledr4), .ledr5(ledr5),
        .ledr6(ledr6), .ledr7(ledr7), .ledr8(ledr8), .ledr9(ledr9),
        .hex0_o(hex0_o), .hex1_o(hex1_o), .hex2_o(hex2_o), .hex3_o(hex3_o), .hex4_o(hex4_o), .hex5_o(hex5_o),
        .gpio_0_d0(gpio_0_d0), .gpio_0_d1(gpio_0_d1), .gpio_0_d2(gpio_0_d2), .gpio_0_d3(gpio_0_d3),
        .gpio_0_d4(gpio_0_d4), .gpio_0_d5(gpio_0_d5), .gpio_0_d6(gpio_0_d6), .gpio_0_d7(gpio_0_d7),
        .gpio_0_d8(gpio_0_d8), .gpio_0_d9(gpio_0_d9), .gpio_0_d10(gpio_0_d10), .gpio_0_d11(gpio_0_d11),
        .gpio_0_d12(gpio_0_d12), .gpio_0_d13(gpio_0_d13), .gpio_0_d14(gpio_0_d14), .gpio_0_d15(gpio_0_d15),
        .gpio_0_d16(gpio_0_d16), .gpio_0_d17(gpio_0_d17), .gpio_0_d18(gpio_0_d18), .gpio_0_d19(gpio_0_d19),
        .gpio_0_d20(gpio_0_d20), .gpio_0_d21(gpio_0_d21), .gpio_0_d22(gpio_0_d22), .gpio_0_d23(gpio_0_d23),
        .gpio_0_d24(gpio_0_d24), .gpio_0_d25(gpio_0_d25), .gpio_0_d26(gpio_0_d26), .gpio_0_d27(gpio_0_d27),
        .gpio_0_d28(gpio_0_d28), .gpio_0_d29(gpio_0_d29), .gpio_0_d30(gpio_0_d30), .gpio_0_d31(gpio_0_d31),
        .gpio_0_d32(gpio_0_d32), .gpio_0_d33(gpio_0_d33), .gpio_0_d34(gpio_0_d34), .gpio_0_d35(gpio_0_d35),
        .gpio_1_d0(gpio_1_d0), .gpio_1_d1(gpio_1_d1), .gpio_1_d2(gpio_1_d2), .gpio_1_d3(gpio_1_d3), .gpio_1_d4(gpio_1_d4),
        .gpio_1_d5(gpio_1_d5), .gpio_1_d6(gpio_1_d6), .gpio_1_d7(gpio_1_d7), .gpio_1_d8(gpio_1_d8), .gpio_1_d9(gpio_1_d9),
        .gpio_1_d10(gpio_1_d10), .gpio_1_d11(gpio_1_d11), .gpio_1_d12(gpio_1_d12), .gpio_1_d13(gpio_1_d13), .gpio_1_d14(gpio_1_d14),
        .gpio_1_d15(gpio_1_d15), .gpio_1_d16(gpio_1_d16), .gpio_1_d17(gpio_1_d17), .gpio_1_d18(gpio_1_d18), .gpio_1_d19(gpio_1_d19),
        .gpio_1_d20(gpio_1_d20), .gpio_1_d21(gpio_1_d21), .gpio_1_d22(gpio_1_d22), .gpio_1_d23(gpio_1_d23), .gpio_1_d24(gpio_1_d24),
        .gpio_1_d25(gpio_1_d25), .gpio_1_d26(gpio_1_d26), .gpio_1_d27(gpio_1_d27), .gpio_1_d28(gpio_1_d28), .gpio_1_d29(gpio_1_d29),
        .gpio_1_d30(gpio_1_d30), .gpio_1_d31(gpio_1_d31), .gpio_1_d32(gpio_1_d32), .gpio_1_d33(gpio_1_d33), .gpio_1_d34(gpio_1_d34),
        .gpio_1_d35(gpio_1_d35)
    );

    initial begin
        key0 = 1'b1; key1 = 1'b1; key2 = 1'b1; key3 = 1'b1; reset_n = 1'b1;
        sw0 = 1'b0; sw1 = 1'b0; sw2 = 1'b0; sw3 = 1'b0; sw4 = 1'b0; sw5 = 1'b0; sw6 = 1'b0; sw7 = 1'b0; sw8 = 1'b0; sw9 = 1'b0;
        clock_50 = 1'b0; clock2_50 = 1'b0; clock3_50 = 1'b0; clock4_50 = 1'b0;
        tb_clk_drive = 1'b0;
        tb_rst_drive = 1'b1;
        tb_capture_leds_drive = 1'b0;
        tb_capture_hex_drive  = 1'b0;
        tb_capture_gpio_drive = 1'b0;
        tb_capture_clear_drive = 1'b0;

        repeat (8) @(posedge tb_clk_drive);
        tb_rst_drive = 1'b0;

        tb_capture_clear_drive = 1'b1;
        @(posedge tb_clk_drive);
        tb_capture_clear_drive = 1'b0;

        wait (dut.stim_ready_o == 1'b1);
        sw0 = 1'b1;
        @(posedge tb_clk_drive);
        sw0 = 1'b0;

        wait (dut.sample_valid_mic_o == 1'b1);
        repeat (16) @(posedge tb_clk_drive);

        // Stage 0 / page 0 = stimulus manager overview
        key3 = 1'b1; key2 = 1'b1; key1 = 1'b1; key0 = 1'b1;
        pulse_capture_all();
        @(posedge tb_clk_drive);

        assert (dut.stim_busy_o == 1'b1 || dut.stim_done_o == 1'b1)
        else $error("Top-level nao iniciou o stimulus manager ROM");

        assert ({ledr3, ledr2, ledr1, ledr0} ==
                {dut.stim_window_done_o, dut.stim_done_o, dut.stim_busy_o, dut.stim_ready_o})
        else $error("Snapshot dos LEDs do stimulus manager nao bate com o DUT");

        assert ({gpio_1_d4, gpio_1_d3, gpio_1_d2, gpio_0_d3} ==
                {dut.stim_window_done_o, dut.stim_done_o, dut.stim_busy_o, dut.stim_ready_o})
        else $error("Snapshot GPIO do stimulus manager nao bate com o DUT");

        assert (hex0_o !== 7'bxxxxxxx)
        else $error("HEX0 nao deveria ficar indefinido");

        // Stage 1 / page 0 = I2S live pins
        key2 = 1'b0; key3 = 1'b1; // stage 01
        key1 = 1'b1; key0 = 1'b1; // page 00
        pulse_capture_all();
        @(posedge tb_clk_drive);

        assert ({gpio_1_d4, gpio_1_d3, gpio_1_d2, gpio_0_d3} ==
                {dut.mic_lr_sel_o, dut.mic_chipen_o, dut.i2s_ws_o, dut.i2s_sck_o})
        else $error("Snapshot GPIO da pagina I2S nao bate com o DUT");

        $display("tb_top_level_test PASSED");
        $finish;
    end

endmodule
