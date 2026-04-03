`timescale 1ns/1ps

module tb_spi_fft_tx_adapter;

    localparam int FFT_DW              = 18;
    localparam int BFPEXP_W            = 8;
    localparam int WORD_W              = 32;
    localparam int FIFO_DEPTH          = 32;
    localparam int BFPEXP_HOLD_FRAMES  = 3;
    localparam int TAG_W               = 2;
    localparam int WINDOW0_BINS        = 4;
    localparam int WINDOW1_BINS        = 4;
    localparam int SPI_HALF_CYCLES     = 4;
    localparam time CLK_HALF           = 5ns;

    localparam logic [TAG_W-1:0] TAG_IDLE_C   = 2'd0;
    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

    logic clk;
    logic rst;

    logic fft_valid_i;
    logic signed [FFT_DW-1:0] fft_real_i;
    logic signed [FFT_DW-1:0] fft_imag_i;
    logic fft_last_i;
    logic signed [BFPEXP_W-1:0] bfpexp_i;

    logic fft_ready_o;
    logic fifo_full_o;
    logic fifo_empty_o;
    logic overflow_o;
    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_level_o;

    logic spi_sclk_i;
    logic spi_cs_n_i;
    logic spi_miso_o;
    logic window_ready_o;
    logic spi_active_o;

    bit saw_overflow_r;
    int max_fifo_level_r;

    function automatic logic signed [FFT_DW-1:0] extend_bfpexp_payload(
        input logic signed [BFPEXP_W-1:0] bfpexp_i_t
    );
        begin
            extend_bfpexp_payload = {{(FFT_DW-BFPEXP_W){bfpexp_i_t[BFPEXP_W-1]}}, bfpexp_i_t};
        end
    endfunction

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
            repeat (SPI_HALF_CYCLES) @(posedge clk);
        end
    endtask

    task automatic spi_read_byte(output logic [7:0] byte_o);
        int bit_idx;
        begin
            byte_o = '0;
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                spi_wait_half_period();
                spi_sclk_i = 1'b1;
                spi_wait_half_period();
                byte_o[bit_idx] = spi_miso_o;
                spi_sclk_i = 1'b0;
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

    task automatic spi_begin_transaction;
        begin
            spi_sclk_i = 1'b0;
            spi_cs_n_i = 1'b0;
            repeat (4) @(posedge clk);
        end
    endtask

    task automatic spi_end_transaction;
        begin
            repeat (4) @(posedge clk);
            spi_sclk_i = 1'b0;
            spi_cs_n_i = 1'b1;
            repeat (4) @(posedge clk);
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
            else $fatal(1, "left tag mismatch exp=%0d got=%0d word=%08x", exp_tag_i, decode_tag(left_word), left_word);

            assert (decode_tag(right_word) == exp_tag_i)
            else $fatal(1, "right tag mismatch exp=%0d got=%0d word=%08x", exp_tag_i, decode_tag(right_word), right_word);

            assert (decode_payload(left_word) == exp_left_i)
            else $fatal(1, "left payload mismatch exp=%0d got=%0d", exp_left_i, decode_payload(left_word));

            assert (decode_payload(right_word) == exp_right_i)
            else $fatal(1, "right payload mismatch exp=%0d got=%0d", exp_right_i, decode_payload(right_word));
        end
    endtask

    task automatic send_fft_bin(
        input logic signed [FFT_DW-1:0] real_i,
        input logic signed [FFT_DW-1:0] imag_i,
        input logic signed [BFPEXP_W-1:0] bfpexp_i_t,
        input logic last_i
    );
        begin
            wait (fft_ready_o === 1'b1);
            @(negedge clk);
            fft_valid_i = 1'b1;
            fft_real_i  = real_i;
            fft_imag_i  = imag_i;
            fft_last_i  = last_i;
            bfpexp_i    = bfpexp_i_t;
            @(posedge clk);
            @(negedge clk);
            fft_valid_i = 1'b0;
            fft_last_i  = 1'b0;
        end
    endtask

    always #CLK_HALF clk = ~clk;

    spi_fft_tx_adapter #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .PAYLOAD_W(FFT_DW),
        .WORD_W(WORD_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .BFPEXP_HOLD_FRAMES(BFPEXP_HOLD_FRAMES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .fft_valid_i(fft_valid_i),
        .fft_real_i(fft_real_i),
        .fft_imag_i(fft_imag_i),
        .fft_last_i(fft_last_i),
        .bfpexp_i(bfpexp_i),
        .fft_ready_o(fft_ready_o),
        .fifo_full_o(fifo_full_o),
        .fifo_empty_o(fifo_empty_o),
        .overflow_o(overflow_o),
        .fifo_level_o(fifo_level_o),
        .spi_sclk_i(spi_sclk_i),
        .spi_cs_n_i(spi_cs_n_i),
        .spi_miso_o(spi_miso_o),
        .window_ready_o(window_ready_o),
        .spi_active_o(spi_active_o)
    );

    always @(posedge clk) begin
        if (rst) begin
            saw_overflow_r  <= 1'b0;
            max_fifo_level_r <= 0;
        end else begin
            if (overflow_o)
                saw_overflow_r <= 1'b1;

            if (fifo_level_o > max_fifo_level_r)
                max_fifo_level_r <= fifo_level_o;

            assert (fifo_empty_o == (fifo_level_o == 0))
            else $fatal(1, "fifo_empty_o incoerente com fifo_level_o.");

            assert (fifo_full_o == (fifo_level_o == FIFO_DEPTH))
            else $fatal(1, "fifo_full_o incoerente com fifo_level_o.");
        end
    end

    initial begin
        clk        = 1'b0;
        rst        = 1'b1;
        fft_valid_i = 1'b0;
        fft_real_i  = '0;
        fft_imag_i  = '0;
        fft_last_i  = 1'b0;
        bfpexp_i    = '0;
        spi_sclk_i  = 1'b0;
        spi_cs_n_i  = 1'b1;
        saw_overflow_r = 1'b0;
        max_fifo_level_r = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        spi_begin_transaction();
        spi_expect_pair(TAG_IDLE_C, '0, '0);
        spi_end_transaction();

        send_fft_bin(18'sd11, -18'sd12, 8'sd5, 1'b0);
        send_fft_bin(18'sd13, -18'sd14, 8'sd5, 1'b0);
        send_fft_bin(18'sd15, -18'sd16, 8'sd5, 1'b0);
        send_fft_bin(18'sd17, -18'sd18, 8'sd5, 1'b1);

        wait (window_ready_o === 1'b1);
        spi_begin_transaction();
        repeat (BFPEXP_HOLD_FRAMES)
            spi_expect_pair(TAG_BFPEXP_C, extend_bfpexp_payload(8'sd5), extend_bfpexp_payload(8'sd5));
        spi_expect_pair(TAG_FFT_C, 18'sd11, -18'sd12);
        spi_expect_pair(TAG_FFT_C, 18'sd13, -18'sd14);
        spi_expect_pair(TAG_FFT_C, 18'sd15, -18'sd16);
        spi_expect_pair(TAG_FFT_C, 18'sd17, -18'sd18);
        spi_end_transaction();

        send_fft_bin(-18'sd21, 18'sd22, -8'sd2, 1'b0);
        send_fft_bin(-18'sd23, 18'sd24, -8'sd2, 1'b0);
        send_fft_bin(-18'sd25, 18'sd26, -8'sd2, 1'b0);
        send_fft_bin(-18'sd27, 18'sd28, -8'sd2, 1'b1);

        wait (window_ready_o === 1'b1);
        spi_begin_transaction();
        repeat (BFPEXP_HOLD_FRAMES)
            spi_expect_pair(TAG_BFPEXP_C, extend_bfpexp_payload(-8'sd2), extend_bfpexp_payload(-8'sd2));
        spi_expect_pair(TAG_FFT_C, -18'sd21, 18'sd22);
        spi_expect_pair(TAG_FFT_C, -18'sd23, 18'sd24);
        spi_expect_pair(TAG_FFT_C, -18'sd25, 18'sd26);
        spi_expect_pair(TAG_FFT_C, -18'sd27, 18'sd28);
        spi_end_transaction();

        repeat (8) @(posedge clk);

        assert (!saw_overflow_r)
        else $fatal(1, "overflow_o nao deveria ocorrer no teste unitario SPI.");

        assert (max_fifo_level_r >= WINDOW0_BINS)
        else $fatal(1, "FIFO nunca acumulou uma janela completa. max_fifo_level=%0d", max_fifo_level_r);

        assert (fifo_level_o == 0)
        else $fatal(1, "FIFO deveria estar vazio ao final. fifo_level_o=%0d", fifo_level_o);

        assert (!spi_active_o)
        else $fatal(1, "spi_active_o deveria voltar a zero ao final.");

        $display("tb_spi_fft_tx_adapter PASSED");
        $finish;
    end

endmodule
