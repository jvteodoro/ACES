`timescale 1ns/1ps

module tb_spi_fft_frame_master;

    localparam int FFT_DW           = 18;
    localparam int BFPEXP_W         = 8;
    localparam int BIN_ID_W         = 9;
    localparam int FIFO_DEPTH       = 16;
    localparam int FRAME_FIFO_DEPTH = 4;
    localparam int SPI_CLK_DIV      = 2;
    localparam int WORD_W           = 32;
    localparam int MAX_CAPTURE_WORDS= 32;
    localparam time CLK_HALF        = 5ns;

    localparam logic [15:0] SOF_C        = 16'hA55A;
    localparam logic [7:0]  VERSION_C    = 8'h01;
    localparam logic [7:0]  TYPE_C       = 8'h01;
    localparam logic [15:0] FLAGS_FRAME0 = 16'h1357;

    logic clk;
    logic rst;

    logic fft_valid_i;
    logic [BIN_ID_W-1:0] fft_bin_index_i;
    logic signed [FFT_DW-1:0] fft_real_i;
    logic signed [FFT_DW-1:0] fft_imag_i;
    logic fft_last_i;
    logic signed [BFPEXP_W-1:0] bfpexp_i;

    logic fft_ready_o;
    logic bin_fifo_full_o;
    logic frame_fifo_full_o;
    logic overflow_o;
    logic [$clog2(FIFO_DEPTH+1)-1:0] bin_fifo_level_o;
    logic [$clog2(FRAME_FIFO_DEPTH+1)-1:0] frame_fifo_level_o;
    logic frame_pending_o;
    logic spi_sclk_o;
    logic spi_cs_n_o;
    logic spi_mosi_o;
    logic spi_active_o;

    logic [WORD_W-1:0] captured_words_r [0:MAX_CAPTURE_WORDS-1];
    int captured_word_count_r;

    function automatic logic [WORD_W-1:0] pack_header_word0;
        begin
            pack_header_word0 = {SOF_C, VERSION_C, TYPE_C};
        end
    endfunction

    function automatic logic [WORD_W-1:0] pack_header_word1(
        input logic [15:0] seq_i,
        input logic [15:0] count_i
    );
        begin
            pack_header_word1 = {seq_i, count_i};
        end
    endfunction

    function automatic logic [WORD_W-1:0] pack_header_word2(
        input logic [15:0] flags_i,
        input logic [15:0] exp_i
    );
        begin
            pack_header_word2 = {flags_i, exp_i};
        end
    endfunction

    function automatic logic [WORD_W-1:0] pack_payload_word(
        input logic [8:0] bin_id_i,
        input logic part_i,
        input logic [3:0] flags_local_i,
        input logic signed [FFT_DW-1:0] value_i
    );
        logic signed [17:0] value_ext;
        begin
            value_ext = {{(18-FFT_DW){value_i[FFT_DW-1]}}, value_i};
            pack_payload_word = {bin_id_i, part_i, flags_local_i, value_ext[17:0]};
        end
    endfunction

    task automatic send_bin(
        input logic [BIN_ID_W-1:0] index_i,
        input logic signed [FFT_DW-1:0] real_i,
        input logic signed [FFT_DW-1:0] imag_i,
        input logic signed [BFPEXP_W-1:0] exp_i,
        input logic last_i
    );
        begin
            wait (fft_ready_o === 1'b1);
            @(negedge clk);
            fft_valid_i     = 1'b1;
            fft_bin_index_i = index_i;
            fft_real_i      = real_i;
            fft_imag_i      = imag_i;
            fft_last_i      = last_i;
            bfpexp_i        = exp_i;
            @(posedge clk);
            @(negedge clk);
            fft_valid_i     = 1'b0;
            fft_last_i      = 1'b0;
        end
    endtask

    task automatic capture_word(output logic [WORD_W-1:0] word_o);
        int bit_idx;
        begin
            word_o = '0;
            for (bit_idx = WORD_W-1; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                @(posedge spi_sclk_o);
                #1ps;
                assert (!spi_cs_n_o)
                else $fatal(1, "CS_N subiu no meio da palavra SPI.");
                word_o[bit_idx] = spi_mosi_o;
            end
        end
    endtask

    task automatic capture_frame;
        int payload_count;
        int word_idx;
        logic [WORD_W-1:0] captured_word_v;
        begin
            captured_word_count_r = 0;
            wait (spi_cs_n_o === 1'b0);
            capture_word(captured_word_v);
            captured_words_r[0] = captured_word_v;
            capture_word(captured_word_v);
            captured_words_r[1] = captured_word_v;
            capture_word(captured_word_v);
            captured_words_r[2] = captured_word_v;
            payload_count = captured_words_r[1][15:0];
            captured_word_count_r = 3 + payload_count;

            assert (captured_word_count_r <= MAX_CAPTURE_WORDS)
            else $fatal(1, "MAX_CAPTURE_WORDS insuficiente: %0d", captured_word_count_r);
            for (word_idx = 0; word_idx < payload_count; word_idx = word_idx + 1) begin
                capture_word(captured_word_v);
                captured_words_r[3 + word_idx] = captured_word_v;
            end

            wait (spi_cs_n_o === 1'b1);
        end
    endtask

    task automatic expect_word(
        input int word_index_i,
        input logic [WORD_W-1:0] expected_i
    );
        begin
            assert (captured_words_r[word_index_i] === expected_i)
            else $fatal(1,
                        "Palavra %0d incorreta. exp=0x%08x got=0x%08x",
                        word_index_i,
                        expected_i,
                        captured_words_r[word_index_i]);
        end
    endtask

    always #CLK_HALF clk = ~clk;

    spi_fft_frame_master #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .BIN_ID_W(BIN_ID_W),
        .WORD_W(WORD_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FRAME_FIFO_DEPTH(FRAME_FIFO_DEPTH),
        .SPI_CLK_DIV(SPI_CLK_DIV),
        .DEFAULT_FLAGS(FLAGS_FRAME0)
    ) dut (
        .clk(clk),
        .rst(rst),
        .fft_valid_i(fft_valid_i),
        .fft_bin_index_i(fft_bin_index_i),
        .fft_real_i(fft_real_i),
        .fft_imag_i(fft_imag_i),
        .fft_last_i(fft_last_i),
        .bfpexp_i(bfpexp_i),
        .fft_ready_o(fft_ready_o),
        .bin_fifo_full_o(bin_fifo_full_o),
        .frame_fifo_full_o(frame_fifo_full_o),
        .overflow_o(overflow_o),
        .bin_fifo_level_o(bin_fifo_level_o),
        .frame_fifo_level_o(frame_fifo_level_o),
        .frame_pending_o(frame_pending_o),
        .spi_sclk_o(spi_sclk_o),
        .spi_cs_n_o(spi_cs_n_o),
        .spi_mosi_o(spi_mosi_o),
        .spi_active_o(spi_active_o)
    );

    initial begin
        clk               = 1'b0;
        rst               = 1'b1;
        fft_valid_i       = 1'b0;
        fft_bin_index_i   = '0;
        fft_real_i        = '0;
        fft_imag_i        = '0;
        fft_last_i        = 1'b0;
        bfpexp_i          = '0;
        captured_word_count_r = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        assert (spi_cs_n_o === 1'b1 && spi_sclk_o === 1'b0 && spi_mosi_o === 1'b0)
        else $fatal(1, "Idle SPI deve manter CS_N=1, SCLK=0 e MOSI=0.");

        send_bin(9'd0, 18'sd11, -18'sd12, 8'sd5, 1'b0);
        send_bin(9'd1, -18'sd33, 18'sd44, 8'sd5, 1'b0);
        repeat (20) @(posedge clk);

        assert (!spi_active_o)
        else $fatal(1, "Nao deveria transmitir antes do ultimo bin do frame.");
        assert (!frame_pending_o)
        else $fatal(1, "Frame incompleto nao pode ser marcado como pronto.");
        assert (spi_cs_n_o === 1'b1)
        else $fatal(1, "CS_N deve permanecer alto enquanto o frame esta incompleto.");

        send_bin(9'd2, 18'sd55, -18'sd66, 8'sd5, 1'b0);
        send_bin(9'd3, -18'sd77, 18'sd88, 8'sd5, 1'b1);

        assert (dut.bin_id_mem[0] === 9'd0)
        else $fatal(1, "bin_id_mem[0] incorreto antes da transmissao.");
        assert (dut.bin_real_mem[0] === 18'sd11)
        else $fatal(1, "bin_real_mem[0] incorreto antes da transmissao.");
        assert (dut.bin_imag_mem[0] === -18'sd12)
        else $fatal(1, "bin_imag_mem[0] incorreto antes da transmissao.");

        capture_frame();

        assert (captured_word_count_r == 11)
        else $fatal(1, "Frame 0 deveria ter 11 palavras, obteve %0d.", captured_word_count_r);

        expect_word(0, pack_header_word0());
        expect_word(1, pack_header_word1(16'd0, 16'd8));
        expect_word(2, pack_header_word2(FLAGS_FRAME0, 16'h0005));
        expect_word(3, pack_payload_word(9'd0, 1'b0, 4'h0, 18'sd11));
        expect_word(4, pack_payload_word(9'd0, 1'b1, 4'h0, -18'sd12));
        expect_word(5, pack_payload_word(9'd1, 1'b0, 4'h0, -18'sd33));
        expect_word(6, pack_payload_word(9'd1, 1'b1, 4'h0, 18'sd44));
        expect_word(7, pack_payload_word(9'd2, 1'b0, 4'h0, 18'sd55));
        expect_word(8, pack_payload_word(9'd2, 1'b1, 4'h0, -18'sd66));
        expect_word(9, pack_payload_word(9'd3, 1'b0, 4'h0, -18'sd77));
        expect_word(10, pack_payload_word(9'd3, 1'b1, 4'h0, 18'sd88));

        repeat (10) @(posedge clk);
        assert (!spi_active_o && spi_cs_n_o === 1'b1 && spi_sclk_o === 1'b0 && spi_mosi_o === 1'b0)
        else $fatal(1, "Depois do frame 0 o barramento deve voltar para idle limpo.");

        send_bin(9'd0, -18'sd1, 18'sd2, -8'sd3, 1'b0);
        send_bin(9'd1, 18'sd3, -18'sd4, -8'sd3, 1'b1);

        capture_frame();

        assert (captured_word_count_r == 7)
        else $fatal(1, "Frame 1 deveria ter 7 palavras, obteve %0d.", captured_word_count_r);

        expect_word(0, pack_header_word0());
        expect_word(1, pack_header_word1(16'd1, 16'd4));
        expect_word(2, pack_header_word2(FLAGS_FRAME0, 16'hFFFD));
        expect_word(3, pack_payload_word(9'd0, 1'b0, 4'h0, -18'sd1));
        expect_word(4, pack_payload_word(9'd0, 1'b1, 4'h0, 18'sd2));
        expect_word(5, pack_payload_word(9'd1, 1'b0, 4'h0, 18'sd3));
        expect_word(6, pack_payload_word(9'd1, 1'b1, 4'h0, -18'sd4));

        assert (!overflow_o && !bin_fifo_full_o && !frame_fifo_full_o)
        else $fatal(1, "Nao deveria haver overflow/full no caminho nominal.");

        $display("tb_spi_fft_frame_master PASSED");
        $finish;
    end

endmodule
