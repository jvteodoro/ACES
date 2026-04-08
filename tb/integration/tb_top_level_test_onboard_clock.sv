`timescale 1ns/1ps

module tb_top_level_test_onboard_clock;

    localparam int FFT_LENGTH          = 16;
    localparam int FFT_DW              = 18;
    localparam int N_POINTS            = 32;
    localparam int N_EXAMPLES          = 8;
    localparam int I2S_CLOCK_DIV       = 2;
    localparam time CLK_HALF           = 5ns;
    localparam int LONG_RESET_CYCLES   = 256;
    localparam int START_TIMEOUT_CYCLES = 20_000;
    localparam int STREAM_TIMEOUT_CYCLES = 200_000;

    logic key0, key1, key2, key3, reset_n;
    logic sw0, sw1, sw2, sw3, sw4, sw5, sw6, sw7, sw8, sw9;
    logic clock_50, clock2_50, clock3_50, clock4_50;

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

    int mic_sck_toggle_count_r;
    int tx_sck_toggle_count_r;
    int tx_sd_transition_count_r;
    int fft_run_count_r;
    int fft_tx_valid_count_r;
    int sact_count_r;

    logic tx_sd_seen_r;
    logic last_tx_sd_r;

    task automatic wait_clk_cycles(input int count_i);
        int idx;
        begin
            for (idx = 0; idx < count_i; idx = idx + 1)
                @(posedge tb_clk_drive);
        end
    endtask

    assign clock_50   = tb_clk_drive;
    assign clock2_50  = 1'b0;
    assign clock3_50  = 1'b0;
    assign clock4_50  = 1'b0;
    assign reset_n    = ~tb_rst_drive;

    assign gpio_0_d0  = 1'b0;
    assign gpio_0_d1  = tb_rst_drive;
    assign gpio_1_d1  = tb_rst_drive;
    assign gpio_1_d5  = 1'b0;
    assign gpio_1_d6  = 1'b0;
    assign gpio_1_d7  = 1'b0;
    assign gpio_1_d9  = 1'b0;
    assign gpio_1_d11 = 1'b0;
    assign gpio_1_d13 = 1'b0;
    assign gpio_1_d15 = 1'b0;
    assign gpio_1_d17 = 1'b0;
    assign gpio_1_d19 = 1'b0;

    always #CLK_HALF tb_clk_drive = ~tb_clk_drive;

    top_level_test #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV)
    ) dut (
        .key0(key0), .key1(key1), .key2(key2), .key3(key3), .reset_n(reset_n),
        .sw0(sw0), .sw1(sw1), .sw2(sw2), .sw3(sw3), .sw4(sw4), .sw5(sw5), .sw6(sw6), .sw7(sw7), .sw8(sw8), .sw9(sw9),
        .clock_50(clock_50), .clock2_50(clock2_50), .clock3_50(clock3_50), .clock4_50(clock4_50),
        .ledr0(), .ledr1(), .ledr2(), .ledr3(), .ledr4(), .ledr5(), .ledr6(), .ledr7(), .ledr8(), .ledr9(),
        .hex0_o(), .hex1_o(), .hex2_o(), .hex3_o(), .hex4_o(), .hex5_o(),
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

    always @(posedge dut.i2s_sck_o or posedge tb_rst_drive) begin
        if (tb_rst_drive)
            mic_sck_toggle_count_r <= 0;
        else
            mic_sck_toggle_count_r <= mic_sck_toggle_count_r + 1;
    end

    always @(posedge dut.tx_i2s_sck_o or posedge tb_rst_drive) begin
        if (tb_rst_drive)
            tx_sck_toggle_count_r <= 0;
        else
            tx_sck_toggle_count_r <= tx_sck_toggle_count_r + 1;
    end

    always @(dut.tx_i2s_sd_o or posedge tb_rst_drive) begin
        if (tb_rst_drive) begin
            tx_sd_transition_count_r <= 0;
            tx_sd_seen_r             <= 1'b0;
            last_tx_sd_r             <= 1'b0;
        end else if (!tx_sd_seen_r) begin
            tx_sd_seen_r <= 1'b1;
            last_tx_sd_r <= dut.tx_i2s_sd_o;
        end else if (dut.tx_i2s_sd_o !== last_tx_sd_r) begin
            tx_sd_transition_count_r <= tx_sd_transition_count_r + 1;
            last_tx_sd_r             <= dut.tx_i2s_sd_o;
        end
    end

    always @(posedge tb_clk_drive or posedge tb_rst_drive) begin
        if (tb_rst_drive) begin
            fft_run_count_r      <= 0;
            fft_tx_valid_count_r <= 0;
            sact_count_r         <= 0;
        end else begin
            if (dut.fft_run_o)
                fft_run_count_r <= fft_run_count_r + 1;
            if (dut.fft_tx_valid_o)
                fft_tx_valid_count_r <= fft_tx_valid_count_r + 1;
            if (dut.sact_istream_o)
                sact_count_r <= sact_count_r + 1;
        end
    end

    initial begin
        int timeout_cycles;

        key0 = 1'b0;
        key1 = 1'b0;
        key2 = 1'b0;
        key3 = 1'b0;

        sw0 = 1'b1;
        sw1 = 1'b0;
        sw2 = 1'b0;
        sw3 = 1'b0;
        sw4 = 1'b0;
        sw5 = 1'b0;
        sw6 = 1'b0;
        sw7 = 1'b1;
        sw8 = 1'b0;
        sw9 = 1'b0;

        tb_clk_drive = 1'b0;
        tb_rst_drive = 1'b1;

        wait_clk_cycles(LONG_RESET_CYCLES);
        tb_rst_drive = 1'b0;

        timeout_cycles = 0;
        while (!dut.stim_busy_o && (timeout_cycles < START_TIMEOUT_CYCLES)) begin
            @(posedge tb_clk_drive);
            timeout_cycles = timeout_cycles + 1;
        end

        assert (dut.stim_busy_o)
        else $fatal(1, "Stimulus manager nao saiu do idle usando apenas clock_50. gpio_0_d0=%0b", gpio_0_d0);

        timeout_cycles = 0;
        while (((sact_count_r == 0) ||
                (fft_run_count_r < 2) ||
                (fft_tx_valid_count_r == 0) ||
                (tx_sck_toggle_count_r < 16) ||
                (tx_sd_transition_count_r == 0)) &&
               (timeout_cycles < STREAM_TIMEOUT_CYCLES)) begin
            @(posedge tb_clk_drive);
            timeout_cycles = timeout_cycles + 1;
        end

        assert (sact_count_r > 0)
        else $fatal(1, "Nao houve ingestao de amostras apos reset longo.");
        assert (mic_sck_toggle_count_r > 16)
        else $fatal(1, "Clock I2S do frontend nao alternou o suficiente: %0d", mic_sck_toggle_count_r);
        assert (fft_run_count_r >= 2)
        else $fatal(1, "Esperado observar pelo menos dois pulsos de fft_run_o, mas so houve %0d.", fft_run_count_r);
        assert (fft_tx_valid_count_r > 0)
        else $fatal(1, "Nenhum bin FFT chegou ao transmissor apos reset longo.");
        assert (tx_sck_toggle_count_r > 16)
        else $fatal(1, "Clock I2S tagged nao alternou o suficiente: %0d", tx_sck_toggle_count_r);
        assert (tx_sd_transition_count_r > 0)
        else $fatal(1, "SD tagged permaneceu parado apos reset longo.");

        $display("tb_top_level_test_onboard_clock PASSED: sact=%0d fft_run=%0d fft_tx_valid=%0d tx_sck=%0d tx_sd_transitions=%0d",
                 sact_count_r,
                 fft_run_count_r,
                 fft_tx_valid_count_r,
                 tx_sck_toggle_count_r,
                 tx_sd_transition_count_r);
        $finish;
    end

endmodule
