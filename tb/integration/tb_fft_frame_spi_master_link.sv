`timescale 1ns/1ps

module tb_fft_frame_spi_master_link;

    localparam int FFT_LENGTH       = 4;
    localparam int FFT_DW           = 18;
    localparam int BIN_ID_W         = 9;
    localparam int BFPEXP_W         = 8;
    localparam int READ_LATENCY     = 2;
    localparam int FIFO_DEPTH       = 16;
    localparam int FRAME_FIFO_DEPTH = 4;
    localparam int SPI_CLK_DIV      = 2;
    localparam int WORD_W           = 32;
    localparam int MAX_CAPTURE_WORDS= 16;
    localparam time CLK_HALF        = 5ns;

    localparam logic [15:0] SOF_C     = 16'hA55A;
    localparam logic [7:0]  VERSION_C = 8'h01;
    localparam logic [7:0]  TYPE_C    = 8'h01;
    localparam logic [15:0] FLAGS_C   = 16'h0246;

    logic clk;
    logic rst;
    logic done_i;
    logic run_i;
    logic dmaact_o;
    logic [$clog2(FFT_LENGTH)-1:0] dmaa_o;
    logic signed [FFT_DW-1:0] dmadr_real_i;
    logic signed [FFT_DW-1:0] dmadr_imag_i;
    logic fft_bin_valid_o;
    logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_o;
    logic signed [FFT_DW-1:0] fft_bin_real_o;
    logic signed [FFT_DW-1:0] fft_bin_imag_o;
    logic fft_bin_last_o;

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

    logic signed [FFT_DW-1:0] real_mem [0:FFT_LENGTH-1];
    logic signed [FFT_DW-1:0] imag_mem [0:FFT_LENGTH-1];
    int seen_bins_r;

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

    task automatic capture_word(output logic [WORD_W-1:0] word_o);
        int bit_idx;
        begin
            word_o = '0;
            for (bit_idx = WORD_W-1; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                @(posedge spi_sclk_o);
                #1ps;
                assert (!spi_cs_n_o)
                else $fatal(1, "CS_N subiu no meio da palavra capturada.");
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
            else $fatal(1, "MAX_CAPTURE_WORDS insuficiente: %0d.", captured_word_count_r);

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

    always_comb begin
        dmadr_real_i = real_mem[dmaa_o];
        dmadr_imag_i = imag_mem[dmaa_o];
    end

    fft_dma_reader #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .READ_LATENCY(READ_LATENCY)
    ) u_fft_dma_reader (
        .clk(clk),
        .rst(rst),
        .done_i(done_i),
        .run_i(run_i),
        .dmaact_o(dmaact_o),
        .dmaa_o(dmaa_o),
        .dmadr_real_i(dmadr_real_i),
        .dmadr_imag_i(dmadr_imag_i),
        .fft_bin_valid_o(fft_bin_valid_o),
        .fft_bin_index_o(fft_bin_index_o),
        .fft_bin_real_o(fft_bin_real_o),
        .fft_bin_imag_o(fft_bin_imag_o),
        .fft_bin_last_o(fft_bin_last_o)
    );

    spi_fft_frame_master #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .BIN_ID_W(BIN_ID_W),
        .WORD_W(WORD_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FRAME_FIFO_DEPTH(FRAME_FIFO_DEPTH),
        .SPI_CLK_DIV(SPI_CLK_DIV),
        .DEFAULT_FLAGS(FLAGS_C)
    ) u_master (
        .clk(clk),
        .rst(rst),
        .fft_valid_i(fft_bin_valid_o),
        .fft_bin_index_i({{(BIN_ID_W-$clog2(FFT_LENGTH)){1'b0}}, fft_bin_index_o}),
        .fft_real_i(fft_bin_real_o),
        .fft_imag_i(fft_bin_imag_o),
        .fft_last_i(fft_bin_last_o),
        .bfpexp_i(8'sd9),
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

    always @(posedge clk) begin
        if (rst) begin
            seen_bins_r <= 0;
        end else if (fft_bin_valid_o) begin
            assert (fft_bin_index_o == seen_bins_r[$clog2(FFT_LENGTH)-1:0])
            else $fatal(1, "fft_dma_reader produziu BIN_ID inesperado: exp=%0d got=%0d", seen_bins_r, fft_bin_index_o);
            seen_bins_r <= seen_bins_r + 1;
        end
    end

    initial begin
        real_mem[0] = 18'sd101; imag_mem[0] = -18'sd201;
        real_mem[1] = -18'sd102; imag_mem[1] = 18'sd202;
        real_mem[2] = 18'sd103; imag_mem[2] = -18'sd203;
        real_mem[3] = -18'sd104; imag_mem[3] = 18'sd204;

        clk = 1'b0;
        rst = 1'b1;
        done_i = 1'b0;
        run_i = 1'b0;
        captured_word_count_r = 0;
        seen_bins_r = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        assert (spi_cs_n_o === 1'b1 && spi_sclk_o === 1'b0 && !spi_active_o)
        else $fatal(1, "Barramento SPI deveria iniciar em idle.");

        @(negedge clk);
        done_i = 1'b1;
        @(negedge clk);
        done_i = 1'b0;

        repeat (2) @(posedge clk);
        assert (!spi_active_o && !frame_pending_o)
        else $fatal(1, "Nao pode transmitir antes do pulso de run e da coleta completa.");

        @(negedge clk);
        run_i = 1'b1;
        @(negedge clk);
        run_i = 1'b0;

        fork
            begin : wait_bins_done
                wait (seen_bins_r == FFT_LENGTH);
            end
            begin : wait_bins_timeout
                repeat (5000) @(posedge clk);
                $fatal(1, "Timeout esperando bins do fft_dma_reader.");
            end
        join_any
        disable fork;

        fork
            begin : wait_spi_start
                wait (spi_active_o || frame_pending_o);
            end
            begin : wait_spi_start_timeout
                repeat (5000) @(posedge clk);
                $fatal(1,
                       "Timeout esperando inicio do frame SPI. seen_bins=%0d frame_fifo_level=%0d bin_fifo_level=%0d",
                       seen_bins_r,
                       frame_fifo_level_o,
                       bin_fifo_level_o);
            end
        join_any
        disable fork;

        capture_frame();

        assert (seen_bins_r == FFT_LENGTH)
        else $fatal(1, "Esperava %0d bins do fft_dma_reader, obteve %0d.", FFT_LENGTH, seen_bins_r);

        expect_word(0, pack_header_word0());
        expect_word(1, pack_header_word1(16'd0, 16'd8));
        expect_word(2, pack_header_word2(FLAGS_C, 16'h0009));
        expect_word(3, pack_payload_word(9'd0, 1'b0, 4'h0, real_mem[0]));
        expect_word(4, pack_payload_word(9'd0, 1'b1, 4'h0, imag_mem[0]));
        expect_word(5, pack_payload_word(9'd1, 1'b0, 4'h0, real_mem[1]));
        expect_word(6, pack_payload_word(9'd1, 1'b1, 4'h0, imag_mem[1]));
        expect_word(7, pack_payload_word(9'd2, 1'b0, 4'h0, real_mem[2]));
        expect_word(8, pack_payload_word(9'd2, 1'b1, 4'h0, imag_mem[2]));
        expect_word(9, pack_payload_word(9'd3, 1'b0, 4'h0, real_mem[3]));
        expect_word(10, pack_payload_word(9'd3, 1'b1, 4'h0, imag_mem[3]));

        assert (!overflow_o && !bin_fifo_full_o && !frame_fifo_full_o)
        else $fatal(1, "Caminho integrado nao deveria overflowar.");

        repeat (8) @(posedge clk);
        assert (spi_cs_n_o === 1'b1 && spi_sclk_o === 1'b0 && !spi_active_o)
        else $fatal(1, "Barramento SPI deveria retornar a idle apos o frame.");

        $display("tb_fft_frame_spi_master_link PASSED");
        $finish;
    end

endmodule
