`timescale 1ns/1ps

module tb_top_level_test;

    localparam int FFT_LENGTH   = 512;
    localparam int FFT_DW       = 18;
    localparam int N_POINTS     = 512;
    localparam int N_EXAMPLES   = 8;
    localparam int EXAMPLE_SEL_W = (N_EXAMPLES <= 1) ? 1 : $clog2(N_EXAMPLES);

    typedef struct packed {
        logic [9:0]  leds;
        logic [23:0] hex;
        logic [3:0]  gpio;
    } snapshot_t;

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

    int sample_count;
    int fft_bin_count;

    assign gpio_0_d0 = tb_clk_drive;
    assign gpio_0_d1 = tb_rst_drive;
    assign gpio_0_d2 = tb_capture_leds_drive;
    assign gpio_0_d4 = tb_capture_hex_drive;
    assign gpio_0_d5 = tb_capture_gpio_drive;
    assign gpio_0_d6 = tb_capture_clear_drive;

    always #5 tb_clk_drive = ~tb_clk_drive;

    top_level_test #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
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

    always @(posedge dut.sample_valid_mic_o) sample_count <= sample_count + 1;
    always @(posedge tb_clk_drive) begin
        if (dut.fft_tx_valid_o)
            fft_bin_count <= fft_bin_count + 1;
    end

    task automatic set_stage_page(input logic [1:0] stage_sel, input logic [1:0] page_sel);
        begin
            key3 = ~stage_sel[1];
            key2 = ~stage_sel[0];
            key1 = ~page_sel[1];
            key0 = ~page_sel[0];
            @(posedge tb_clk_drive);
        end
    endtask

    task automatic clear_capture_regs;
        begin
            tb_capture_clear_drive = 1'b1;
            @(posedge tb_clk_drive);
            tb_capture_clear_drive = 1'b0;
            @(posedge tb_clk_drive);
        end
    endtask

    task automatic pulse_capture_all;
        begin
            tb_capture_leds_drive = 1'b1;
            tb_capture_hex_drive  = 1'b1;
            tb_capture_gpio_drive = 1'b1;
            @(posedge tb_clk_drive);
            tb_capture_leds_drive = 1'b0;
            tb_capture_hex_drive  = 1'b0;
            tb_capture_gpio_drive = 1'b0;
            @(posedge tb_clk_drive);
        end
    endtask

    function automatic snapshot_t get_live_snapshot;
        snapshot_t snap;
        begin
            snap.leds = dut.dbg_led_live;
            snap.hex  = dut.dbg_hex_live;
            snap.gpio = dut.dbg_gpio_live;
            return snap;
        end
    endfunction

    function automatic snapshot_t get_capture_snapshot;
        snapshot_t snap;
        begin
            snap.leds = {ledr9, ledr8, ledr7, ledr6, ledr5, ledr4, ledr3, ledr2, ledr1, ledr0};
            snap.hex  = dut.dbg_hex_capture_r;
            snap.gpio = {gpio_1_d4, gpio_1_d3, gpio_1_d2, gpio_0_d3};
            return snap;
        end
    endfunction

    task automatic capture_and_check(
        input logic [1:0] stage_sel,
        input logic [1:0] page_sel,
        input string label
    );
        snapshot_t live;
        snapshot_t captured;
        begin
            set_stage_page(stage_sel, page_sel);
            live = get_live_snapshot();
            pulse_capture_all();
            captured = get_capture_snapshot();

            assert (captured.leds === live.leds)
            else $error("%s LEDs capturados nao batem. exp=%b got=%b", label, live.leds, captured.leds);

            assert (captured.hex === live.hex)
            else $error("%s HEX capturado nao bate. exp=0x%06h got=0x%06h", label, live.hex, captured.hex);

            assert (captured.gpio === live.gpio)
            else $error("%s GPIO capturado nao bate. exp=%b got=%b", label, live.gpio, captured.gpio);

            $display("[%0t] %s | stage=%0d page=%0d | leds=%b hex=0x%06h gpio=%b | sample_count=%0d fft_bin_count=%0d current_example=%0d current_point=%0d",
                     $time, label, stage_sel, page_sel, live.leds, live.hex, live.gpio,
                     sample_count, fft_bin_count, dut.stim_current_example_o, dut.stim_current_point_o);
        end
    endtask

    task automatic start_example(input int example_idx);
        logic [EXAMPLE_SEL_W-1:0] example_bits;
        begin
            example_bits = example_idx[EXAMPLE_SEL_W-1:0];
            wait (dut.stim_ready_o == 1'b1);
            sw3 = example_bits[2];
            sw2 = example_bits[1];
            sw1 = example_bits[0];
            sw4 = 1'b0;
            sw5 = 1'b0;
            sw6 = 1'b0;
            @(posedge tb_clk_drive);
            sw0 = 1'b1;
            @(posedge tb_clk_drive);
            sw0 = 1'b0;

            wait (dut.stim_busy_o == 1'b1);
            assert (dut.stim_current_example_o == example_bits)
            else $error("Stimulus manager iniciou exemplo errado. exp=%0d got=%0d", example_idx, dut.stim_current_example_o);

            $display("[%0t] Iniciando exemplo %0d/%0d", $time, example_idx, N_EXAMPLES-1);
        end
    endtask

    task automatic wait_for_first_sample_of_example(input int previous_sample_count, input int example_idx);
        begin
            wait (sample_count > previous_sample_count);
            assert (dut.stim_current_example_o == example_idx[EXAMPLE_SEL_W-1:0])
            else $error("A primeira amostra nao pertence ao exemplo esperado. exp=%0d got=%0d", example_idx, dut.stim_current_example_o);
        end
    endtask

    task automatic run_example_and_capture(input int example_idx);
        int sample_base;
        int fft_base;
        begin
            sample_base = sample_count;
            fft_base    = fft_bin_count;

            start_example(example_idx);

            capture_and_check(2'b00, 2'b00, $sformatf("ex%0d stim overview apos start", example_idx));
            capture_and_check(2'b00, 2'b01, $sformatf("ex%0d stim estado/bit index", example_idx));
            capture_and_check(2'b00, 2'b10, $sformatf("ex%0d stim amostra ROM", example_idx));

            wait_for_first_sample_of_example(sample_base, example_idx);
            capture_and_check(2'b01, 2'b00, $sformatf("ex%0d i2s amostra24", example_idx));
            capture_and_check(2'b01, 2'b01, $sformatf("ex%0d i2s sample18", example_idx));
            capture_and_check(2'b01, 2'b10, $sformatf("ex%0d i2s fft_sample", example_idx));

            wait (dut.fft_run_o == 1'b1);
            capture_and_check(2'b10, 2'b00, $sformatf("ex%0d ingest real", example_idx));
            capture_and_check(2'b10, 2'b01, $sformatf("ex%0d ingest imag", example_idx));
            capture_and_check(2'b10, 2'b10, $sformatf("ex%0d ingest status", example_idx));

            wait (dut.fft_tx_valid_o == 1'b1);
            capture_and_check(2'b11, 2'b00, $sformatf("ex%0d fft tx index", example_idx));
            capture_and_check(2'b11, 2'b01, $sformatf("ex%0d fft tx real", example_idx));
            capture_and_check(2'b11, 2'b10, $sformatf("ex%0d fft tx imag", example_idx));

            wait (dut.stim_done_o == 1'b1);
            capture_and_check(2'b00, 2'b00, $sformatf("ex%0d stim done", example_idx));

            assert ((sample_count - sample_base) == N_POINTS)
            else $error("Exemplo %0d deveria gerar %0d amostras, gerou %0d", example_idx, N_POINTS, sample_count - sample_base);

            assert ((fft_bin_count - fft_base) == FFT_LENGTH)
            else $error("Exemplo %0d deveria gerar %0d bins FFT, gerou %0d", example_idx, FFT_LENGTH, fft_bin_count - fft_base);

            assert (dut.stim_current_example_o == example_idx[EXAMPLE_SEL_W-1:0])
            else $error("Stimulus manager terminou em exemplo inesperado. exp=%0d got=%0d", example_idx, dut.stim_current_example_o);

            assert (dut.stim_current_point_o == N_POINTS-1)
            else $error("Stimulus manager terminou em ponto inesperado. exp=%0d got=%0d", N_POINTS-1, dut.stim_current_point_o);

            $display("[%0t] Exemplo %0d concluido com %0d amostras e %0d bins FFT", $time, example_idx, sample_count - sample_base, fft_bin_count - fft_base);
        end
    endtask

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
        sample_count = 0;
        fft_bin_count = 0;

        repeat (8) @(posedge tb_clk_drive);
        tb_rst_drive = 1'b0;
        clear_capture_regs();

        for (int example_idx = 0; example_idx < N_EXAMPLES; example_idx++) begin
            run_example_and_capture(example_idx);
            wait (dut.stim_ready_o == 1'b1);
            repeat (8) @(posedge tb_clk_drive);
        end

        assert (sample_count == (N_EXAMPLES * N_POINTS))
        else $error("Esperadas %0d amostras no total, obtidas %0d", N_EXAMPLES * N_POINTS, sample_count);

        assert (fft_bin_count == (N_EXAMPLES * FFT_LENGTH))
        else $error("Esperados %0d bins FFT no total, obtidos %0d", N_EXAMPLES * FFT_LENGTH, fft_bin_count);

        $display("tb_top_level_test PASSED com %0d exemplos reais do signal_rom_generator", N_EXAMPLES);
        $finish;
    end

endmodule
