`timescale 1ns/1ps

module tb_top_level_spi_fft_tx_diag;

    localparam int FFT_DW                   = 18;
    localparam int WORD_W                   = 32;
    localparam int DIAG_WINDOW_BINS         = 4;
    localparam int DIAG_BFPEXP_HOLD_FRAMES  = 1;
    localparam int SPI_HALF_CYCLES          = 4;
    localparam int TAG_W                    = 2;
    localparam time CLK_HALF                = 5ns;

    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

    localparam logic signed [FFT_DW-1:0] DIAG_FFT_REAL_C   = 18'sh15555;
    localparam logic signed [FFT_DW-1:0] DIAG_FFT_IMAG_C   = 18'sh0AAAB;
    localparam logic signed [FFT_DW-1:0] DIAG_BFPEXP_EXT_C = 18'sd18;

    logic clock_50;
    logic gpio_1_d1;
    logic gpio_1_d27;
    logic gpio_1_d29;
    logic gpio_1_d31;
    logic gpio_1_d25;

    function automatic logic [TAG_W-1:0] decode_tag(
        input logic [WORD_W-1:0] word_i
    );
        begin
            decode_tag = word_i[WORD_W-1 -: TAG_W];
        end
    endfunction

    function automatic logic signed [FFT_DW-1:0] decode_payload(
        input logic [WORD_W-1:0] word_i
    );
        begin
            decode_payload = $signed(word_i[FFT_DW-1:0]);
        end
    endfunction

    task automatic spi_wait_half_period;
        begin
            repeat (SPI_HALF_CYCLES) @(posedge clock_50);
        end
    endtask

    task automatic spi_read_byte(output logic [7:0] byte_o);
        int bit_idx;
        begin
            byte_o = '0;
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                spi_wait_half_period();
                gpio_1_d27 = 1'b1;
                spi_wait_half_period();
                byte_o[bit_idx] = gpio_1_d31;
                gpio_1_d27 = 1'b0;
            end
        end
    endtask

    task automatic spi_read_word(output logic [WORD_W-1:0] word_o);
        logic [7:0] byte0;
        logic [7:0] byte1;
        logic [7:0] byte2;
        logic [7:0] byte3;
        begin
            spi_read_byte(byte0);
            spi_read_byte(byte1);
            spi_read_byte(byte2);
            spi_read_byte(byte3);
            word_o = {byte3, byte2, byte1, byte0};
        end
    endtask

    task automatic spi_expect_pair(
        input logic [TAG_W-1:0] exp_tag_i,
        input logic signed [FFT_DW-1:0] exp_left_i,
        input logic signed [FFT_DW-1:0] exp_right_i
    );
        logic [WORD_W-1:0] left_word;
        logic [WORD_W-1:0] right_word;
        begin
            spi_read_word(left_word);
            spi_read_word(right_word);

            assert (decode_tag(left_word) == exp_tag_i)
            else $fatal(1, "left tag mismatch exp=%0d got=%0d", exp_tag_i, decode_tag(left_word));

            assert (decode_tag(right_word) == exp_tag_i)
            else $fatal(1, "right tag mismatch exp=%0d got=%0d", exp_tag_i, decode_tag(right_word));

            assert (decode_payload(left_word) == exp_left_i)
            else $fatal(1, "left payload mismatch exp=%0d got=%0d", exp_left_i, decode_payload(left_word));

            assert (decode_payload(right_word) == exp_right_i)
            else $fatal(1, "right payload mismatch exp=%0d got=%0d", exp_right_i, decode_payload(right_word));
        end
    endtask

    task automatic spi_read_diag_window;
        int bin_idx;
        begin
            gpio_1_d27 = 1'b0;
            gpio_1_d29 = 1'b0;
            repeat (4) @(posedge clock_50);

            repeat (DIAG_BFPEXP_HOLD_FRAMES)
                spi_expect_pair(TAG_BFPEXP_C, DIAG_BFPEXP_EXT_C, DIAG_BFPEXP_EXT_C);

            for (bin_idx = 0; bin_idx < DIAG_WINDOW_BINS; bin_idx = bin_idx + 1)
                spi_expect_pair(TAG_FFT_C, DIAG_FFT_REAL_C, DIAG_FFT_IMAG_C);

            repeat (4) @(posedge clock_50);
            gpio_1_d27 = 1'b0;
            gpio_1_d29 = 1'b1;
            repeat (4) @(posedge clock_50);
        end
    endtask

    always #CLK_HALF clock_50 = ~clock_50;

    top_level_spi_fft_tx_diag #(
        .FFT_DW(FFT_DW),
        .DIAG_WINDOW_BINS(DIAG_WINDOW_BINS),
        .DIAG_BFPEXP_HOLD_FRAMES(DIAG_BFPEXP_HOLD_FRAMES)
    ) dut (
        .key0(1'b0),
        .key1(1'b0),
        .key2(1'b0),
        .key3(1'b0),
        .reset_n(1'b1),
        .sw0(1'b0),
        .sw1(1'b0),
        .sw2(1'b0),
        .sw3(1'b0),
        .sw4(1'b0),
        .sw5(1'b0),
        .sw6(1'b0),
        .sw7(1'b0),
        .sw8(1'b0),
        .sw9(1'b0),
        .clock_50(clock_50),
        .clock2_50(1'b0),
        .clock3_50(1'b0),
        .clock4_50(1'b0),
        .ledr0(),
        .ledr1(),
        .ledr2(),
        .ledr3(),
        .ledr4(),
        .ledr5(),
        .ledr6(),
        .ledr7(),
        .ledr8(),
        .ledr9(),
        .hex0_o(),
        .hex1_o(),
        .hex2_o(),
        .hex3_o(),
        .hex4_o(),
        .hex5_o(),
        .gpio_0_d0(1'b0),
        .gpio_0_d1(1'b0),
        .gpio_0_d2(1'b0),
        .gpio_0_d3(),
        .gpio_0_d4(1'b0),
        .gpio_0_d5(1'b0),
        .gpio_0_d6(1'b0),
        .gpio_0_d7(1'b0),
        .gpio_0_d8(1'b0),
        .gpio_0_d9(1'b0),
        .gpio_0_d10(1'b0),
        .gpio_0_d11(),
        .gpio_0_d12(),
        .gpio_0_d13(),
        .gpio_0_d14(),
        .gpio_0_d15(1'b0),
        .gpio_0_d16(1'b0),
        .gpio_0_d17(),
        .gpio_0_d18(1'b0),
        .gpio_0_d19(),
        .gpio_0_d20(1'b0),
        .gpio_0_d21(1'b0),
        .gpio_0_d22(1'b0),
        .gpio_0_d23(1'b0),
        .gpio_0_d24(1'b0),
        .gpio_0_d25(1'b0),
        .gpio_0_d26(1'b0),
        .gpio_0_d27(),
        .gpio_0_d28(),
        .gpio_0_d29(),
        .gpio_0_d30(),
        .gpio_0_d31(),
        .gpio_0_d32(),
        .gpio_0_d33(1'b0),
        .gpio_0_d34(),
        .gpio_0_d35(1'b0),
        .gpio_1_d0(),
        .gpio_1_d1(gpio_1_d1),
        .gpio_1_d2(),
        .gpio_1_d3(),
        .gpio_1_d4(),
        .gpio_1_d5(),
        .gpio_1_d6(1'b0),
        .gpio_1_d7(1'b0),
        .gpio_1_d8(1'b0),
        .gpio_1_d9(1'b0),
        .gpio_1_d10(1'b0),
        .gpio_1_d11(1'b0),
        .gpio_1_d12(1'b0),
        .gpio_1_d13(1'b0),
        .gpio_1_d14(1'b0),
        .gpio_1_d15(1'b0),
        .gpio_1_d16(1'b0),
        .gpio_1_d17(),
        .gpio_1_d18(1'b0),
        .gpio_1_d19(),
        .gpio_1_d20(),
        .gpio_1_d21(),
        .gpio_1_d22(1'b0),
        .gpio_1_d23(),
        .gpio_1_d24(1'b0),
        .gpio_1_d25(gpio_1_d25),
        .gpio_1_d26(1'b0),
        .gpio_1_d27(gpio_1_d27),
        .gpio_1_d28(1'b0),
        .gpio_1_d29(gpio_1_d29),
        .gpio_1_d30(),
        .gpio_1_d31(gpio_1_d31),
        .gpio_1_d32(),
        .gpio_1_d33(1'b0),
        .gpio_1_d34(),
        .gpio_1_d35(1'b0)
    );

    initial begin
        clock_50  = 1'b0;
        gpio_1_d1 = 1'b1;
        gpio_1_d27 = 1'b0;
        gpio_1_d29 = 1'b1;

        repeat (4) @(posedge clock_50);
        gpio_1_d1 = 1'b0;

        wait (gpio_1_d25 === 1'b1);
        spi_read_diag_window();

        wait (gpio_1_d25 === 1'b1);
        spi_read_diag_window();

        assert (!dut.diag_overflow_latched_r)
        else $fatal(1, "O topo de diagnostico SPI nao deveria overflowar.");

        assert (dut.diag_window_count_r >= 2)
        else $fatal(1, "Esperado observar pelo menos duas janelas completas.");

        $display("tb_top_level_spi_fft_tx_diag PASSED");
        $finish;
    end

endmodule
