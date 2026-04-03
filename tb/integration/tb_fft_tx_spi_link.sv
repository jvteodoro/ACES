`timescale 1ns/1ps

module tb_fft_tx_spi_link;

    localparam int FFT_DW              = 18;
    localparam int BFPEXP_W            = 8;
    localparam int FIFO_DEPTH          = 8;
    localparam int WORD_W              = 32;
    localparam int BFPEXP_HOLD_FRAMES  = 2;
    localparam int TAG_W               = 2;
    localparam int SPI_HALF_CYCLES     = 4;
    localparam time CLK_HALF           = 5ns;

    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

    logic clk;
    logic rst;

    logic push_i;
    logic signed [FFT_DW-1:0] fft_real_i;
    logic signed [FFT_DW-1:0] fft_imag_i;
    logic fft_last_i;
    logic signed [BFPEXP_W-1:0] bfpexp_i;

    logic fifo_valid_o;
    logic signed [FFT_DW-1:0] fifo_real_o;
    logic signed [FFT_DW-1:0] fifo_imag_o;
    logic fifo_last_o;
    logic signed [BFPEXP_W-1:0] fifo_bfpexp_o;
    logic fifo_full_o;
    logic fifo_empty_o;
    logic fifo_overflow_o;
    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_level_o;

    logic bridge_pop_i;
    logic adapter_ready_o;
    logic adapter_fifo_full_o;
    logic adapter_fifo_empty_o;
    logic adapter_overflow_o;
    logic [$clog2(FIFO_DEPTH+1)-1:0] adapter_fifo_level_o;

    logic spi_sclk_i;
    logic spi_cs_n_i;
    logic spi_miso_o;
    logic window_ready_o;
    logic spi_active_o;

    bit saw_fifo_overflow_r;
    bit saw_adapter_overflow_r;
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
            else $fatal(1, "left tag mismatch exp=%0d got=%0d", exp_tag_i, decode_tag(left_word));

            assert (decode_tag(right_word) == exp_tag_i)
            else $fatal(1, "right tag mismatch exp=%0d got=%0d", exp_tag_i, decode_tag(right_word));

            assert (decode_payload(left_word) == exp_left_i)
            else $fatal(1, "left payload mismatch exp=%0d got=%0d", exp_left_i, decode_payload(left_word));

            assert (decode_payload(right_word) == exp_right_i)
            else $fatal(1, "right payload mismatch exp=%0d got=%0d", exp_right_i, decode_payload(right_word));
        end
    endtask

    task automatic push_fft_bin(
        input logic signed [FFT_DW-1:0] real_i,
        input logic signed [FFT_DW-1:0] imag_i,
        input logic signed [BFPEXP_W-1:0] bfpexp_i_t,
        input logic last_i
    );
        begin
            @(negedge clk);
            push_i      = 1'b1;
            fft_real_i  = real_i;
            fft_imag_i  = imag_i;
            fft_last_i  = last_i;
            bfpexp_i    = bfpexp_i_t;
            @(posedge clk);
            @(negedge clk);
            push_i      = 1'b0;
            fft_last_i  = 1'b0;
        end
    endtask

    always #CLK_HALF clk = ~clk;

    assign bridge_pop_i = fifo_valid_o && adapter_ready_o;

    fft_tx_bridge_fifo #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo (
        .clk(clk),
        .rst(rst),
        .push_i(push_i),
        .fft_real_i(fft_real_i),
        .fft_imag_i(fft_imag_i),
        .fft_last_i(fft_last_i),
        .bfpexp_i(bfpexp_i),
        .pop_i(bridge_pop_i),
        .valid_o(fifo_valid_o),
        .fft_real_o(fifo_real_o),
        .fft_imag_o(fifo_imag_o),
        .fft_last_o(fifo_last_o),
        .bfpexp_o(fifo_bfpexp_o),
        .full_o(fifo_full_o),
        .empty_o(fifo_empty_o),
        .overflow_o(fifo_overflow_o),
        .level_o(fifo_level_o)
    );

    spi_fft_tx_adapter #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .PAYLOAD_W(FFT_DW),
        .WORD_W(WORD_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .BFPEXP_HOLD_FRAMES(BFPEXP_HOLD_FRAMES)
    ) u_adapter (
        .clk(clk),
        .rst(rst),
        .fft_valid_i(fifo_valid_o),
        .fft_real_i(fifo_real_o),
        .fft_imag_i(fifo_imag_o),
        .fft_last_i(fifo_last_o),
        .bfpexp_i(fifo_bfpexp_o),
        .fft_ready_o(adapter_ready_o),
        .fifo_full_o(adapter_fifo_full_o),
        .fifo_empty_o(adapter_fifo_empty_o),
        .overflow_o(adapter_overflow_o),
        .fifo_level_o(adapter_fifo_level_o),
        .spi_sclk_i(spi_sclk_i),
        .spi_cs_n_i(spi_cs_n_i),
        .spi_miso_o(spi_miso_o),
        .window_ready_o(window_ready_o),
        .spi_active_o(spi_active_o)
    );

    always @(posedge clk) begin
        if (rst) begin
            saw_fifo_overflow_r    <= 1'b0;
            saw_adapter_overflow_r <= 1'b0;
            max_fifo_level_r       <= 0;
        end else begin
            if (fifo_overflow_o)
                saw_fifo_overflow_r <= 1'b1;

            if (adapter_overflow_o)
                saw_adapter_overflow_r <= 1'b1;

            if (fifo_level_o > max_fifo_level_r)
                max_fifo_level_r <= fifo_level_o;

            assert (bridge_pop_i == (fifo_valid_o && adapter_ready_o))
            else $fatal(1, "bridge_pop_i incoerente com valid/ready.");
        end
    end

    initial begin
        clk       = 1'b0;
        rst       = 1'b1;
        push_i    = 1'b0;
        fft_real_i = '0;
        fft_imag_i = '0;
        fft_last_i = 1'b0;
        bfpexp_i   = '0;
        spi_sclk_i = 1'b0;
        spi_cs_n_i = 1'b1;
        saw_fifo_overflow_r = 1'b0;
        saw_adapter_overflow_r = 1'b0;
        max_fifo_level_r = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        push_fft_bin(18'sd3, 18'sd4, 8'sd7, 1'b0);
        push_fft_bin(18'sd5, 18'sd6, 8'sd7, 1'b0);
        push_fft_bin(18'sd7, 18'sd8, 8'sd7, 1'b1);
        push_fft_bin(-18'sd9, -18'sd10, -8'sd1, 1'b0);
        push_fft_bin(-18'sd11, -18'sd12, -8'sd1, 1'b0);
        push_fft_bin(-18'sd13, -18'sd14, -8'sd1, 1'b1);

        wait (window_ready_o === 1'b1);
        spi_begin_transaction();
        repeat (BFPEXP_HOLD_FRAMES)
            spi_expect_pair(TAG_BFPEXP_C, extend_bfpexp_payload(8'sd7), extend_bfpexp_payload(8'sd7));
        spi_expect_pair(TAG_FFT_C, 18'sd3, 18'sd4);
        spi_expect_pair(TAG_FFT_C, 18'sd5, 18'sd6);
        spi_expect_pair(TAG_FFT_C, 18'sd7, 18'sd8);
        spi_end_transaction();

        wait (window_ready_o === 1'b1);
        spi_begin_transaction();
        repeat (BFPEXP_HOLD_FRAMES)
            spi_expect_pair(TAG_BFPEXP_C, extend_bfpexp_payload(-8'sd1), extend_bfpexp_payload(-8'sd1));
        spi_expect_pair(TAG_FFT_C, -18'sd9, -18'sd10);
        spi_expect_pair(TAG_FFT_C, -18'sd11, -18'sd12);
        spi_expect_pair(TAG_FFT_C, -18'sd13, -18'sd14);
        spi_end_transaction();

        repeat (8) @(posedge clk);

        assert (!saw_fifo_overflow_r)
        else $fatal(1, "fft_tx_bridge_fifo nao deveria overflowar.");

        assert (!saw_adapter_overflow_r)
        else $fatal(1, "spi_fft_tx_adapter nao deveria overflowar.");

        assert (max_fifo_level_r >= 1)
        else $fatal(1, "FIFO nunca acumulou bins suficientes. max_fifo_level=%0d", max_fifo_level_r);

        assert (fifo_empty_o)
        else $fatal(1, "FIFO deveria estar vazio ao final.");

        assert (adapter_fifo_empty_o)
        else $fatal(1, "FIFO interna do adapter deveria estar vazia ao final.");

        assert (!spi_active_o)
        else $fatal(1, "spi_active_o deveria estar em zero ao final.");

        $display("tb_fft_tx_spi_link PASSED");
        $finish;
    end

endmodule
