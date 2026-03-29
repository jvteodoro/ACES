`timescale 1ns/1ps

module tb_i2s_fft_tx_adapter;

    localparam int FFT_DW             = 18;
    localparam int BFPEXP_W           = 8;
    localparam int I2S_SAMPLE_W       = 18;
    localparam int CLOCK_DIV          = 2;
    localparam int FIFO_DEPTH         = 32;
    localparam int BFPEXP_HOLD_FRAMES = 3;
    localparam int SLOT_W             = 32;
    localparam int TAG_W              = 2;
    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;
    localparam int EXPECTED_COUNT     = 11;
    localparam int CAPTURE_DEPTH      = 64;
    localparam time CLK_HALF          = 5ns;

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

    logic i2s_sck_o;
    logic i2s_ws_o;
    logic i2s_sd_o;

    logic mon_slot_ws_r;
    logic [31:0] mon_slot_shift_r;
    int mon_slot_count_r;
    logic [31:0] mon_right_word_r;
    bit mon_have_right_r;

    logic [TAG_W-1:0] captured_tag_mem [0:CAPTURE_DEPTH-1];
    logic signed [I2S_SAMPLE_W-1:0] captured_left_mem [0:CAPTURE_DEPTH-1];
    logic signed [I2S_SAMPLE_W-1:0] captured_right_mem [0:CAPTURE_DEPTH-1];
    int captured_write_idx;
    int captured_read_idx;

    logic [TAG_W-1:0] expected_tag_mem [0:EXPECTED_COUNT-1];
    logic signed [I2S_SAMPLE_W-1:0] expected_left_mem [0:EXPECTED_COUNT-1];
    logic signed [I2S_SAMPLE_W-1:0] expected_right_mem [0:EXPECTED_COUNT-1];

    function automatic logic [TAG_W-1:0] decode_tag(
        input logic [31:0] word_i
    );
        begin
            decode_tag = word_i[31 -: TAG_W];
        end
    endfunction

    function automatic logic signed [I2S_SAMPLE_W-1:0] decode_payload(
        input logic [31:0] word_i
    );
        begin
            decode_payload = $signed(word_i[I2S_SAMPLE_W-1:0]);
        end
    endfunction

    always #CLK_HALF clk = ~clk;

    i2s_fft_tx_adapter #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .I2S_SAMPLE_W(I2S_SAMPLE_W),
        .CLOCK_DIV(CLOCK_DIV),
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
        .i2s_sck_o(i2s_sck_o),
        .i2s_ws_o(i2s_ws_o),
        .i2s_sd_o(i2s_sd_o)
    );

    task automatic send_fft_bin(
        input logic signed [FFT_DW-1:0] real_i,
        input logic signed [FFT_DW-1:0] imag_i,
        input logic signed [BFPEXP_W-1:0] bfpexp_i_t,
        input logic last_i
    );
        begin
            wait (fft_ready_o === 1'b1);
            fft_valid_i = 1'b1;
            fft_real_i  = real_i;
            fft_imag_i  = imag_i;
            fft_last_i  = last_i;
            bfpexp_i    = bfpexp_i_t;
            @(posedge clk);
            fft_valid_i = 1'b0;
            fft_last_i  = 1'b0;
        end
    endtask

    task automatic wait_for_first_expected_frame;
        bit found;
        int timeout_cycles;
        begin
            found = 1'b0;
            timeout_cycles = 0;

            while ((timeout_cycles < 400000) && !found) begin
                if (captured_read_idx < captured_write_idx) begin
                    if ((captured_tag_mem[captured_read_idx]   === expected_tag_mem[0]) &&
                        (captured_left_mem[captured_read_idx]  === expected_left_mem[0]) &&
                        (captured_right_mem[captured_read_idx] === expected_right_mem[0])) begin
                        found = 1'b1;
                    end else begin
                        captured_read_idx = captured_read_idx + 1;
                    end
                end

                if (!found) begin
                    @(posedge clk);
                    timeout_cycles = timeout_cycles + 1;
                end
            end

            if (!found)
                $fatal(1, "Nao foi encontrado o primeiro frame esperado.");
        end
    endtask

    task automatic check_expected_sequence;
        int idx;
        int timeout_cycles;
        begin
            for (idx = 0; idx < EXPECTED_COUNT; idx++) begin
                timeout_cycles = 0;
                while ((captured_read_idx >= captured_write_idx) && (timeout_cycles < 400000)) begin
                    @(posedge clk);
                    timeout_cycles = timeout_cycles + 1;
                end

                if (captured_read_idx >= captured_write_idx)
                    $fatal(1, "Timeout esperando frame idx=%0d", idx);

                assert (captured_tag_mem[captured_read_idx] === expected_tag_mem[idx])
                else $fatal(1, "TAG mismatch idx=%0d exp=%0d got=%0d", idx, expected_tag_mem[idx], captured_tag_mem[captured_read_idx]);

                assert (captured_left_mem[captured_read_idx] === expected_left_mem[idx])
                else $fatal(1, "LEFT mismatch idx=%0d exp=%0d got=%0d", idx, expected_left_mem[idx], captured_left_mem[captured_read_idx]);

                assert (captured_right_mem[captured_read_idx] === expected_right_mem[idx])
                else $fatal(1, "RIGHT mismatch idx=%0d exp=%0d got=%0d", idx, expected_right_mem[idx], captured_right_mem[captured_read_idx]);

                captured_read_idx = captured_read_idx + 1;
            end
        end
    endtask

    task automatic set_expected_frame(
        input int idx_i,
        input logic [TAG_W-1:0] tag_i,
        input logic signed [I2S_SAMPLE_W-1:0] left_i,
        input logic signed [I2S_SAMPLE_W-1:0] right_i
    );
        begin
            expected_tag_mem[idx_i]   = tag_i;
            expected_left_mem[idx_i]  = left_i;
            expected_right_mem[idx_i] = right_i;
        end
    endtask

    always @(posedge i2s_sck_o or posedge rst) begin
        logic slot_ws;
        logic [31:0] next_shift;
        int next_count;
        logic [31:0] decoded_word;

        if (rst) begin
            mon_slot_ws_r       <= 1'b1;
            mon_slot_shift_r    <= '0;
            mon_slot_count_r    <= 0;
            mon_right_word_r    <= '0;
            mon_have_right_r    <= 1'b0;
            captured_write_idx  <= 0;
        end else begin
            if ((mon_slot_count_r == 0) || (i2s_ws_o != mon_slot_ws_r)) begin
                slot_ws    = i2s_ws_o;
                next_shift = {31'd0, i2s_sd_o};
                next_count = 1;
            end else begin
                slot_ws    = mon_slot_ws_r;
                next_shift = {mon_slot_shift_r[30:0], i2s_sd_o};
                next_count = mon_slot_count_r + 1;
            end

            mon_slot_ws_r    <= slot_ws;
            mon_slot_shift_r <= next_shift;

            if (next_count == SLOT_W) begin
                decoded_word = next_shift;

                if (slot_ws) begin
                    mon_right_word_r   <= decoded_word;
                    mon_have_right_r   <= 1'b1;
                end else if (mon_have_right_r) begin
                    if (captured_write_idx >= CAPTURE_DEPTH) begin
                        $fatal(1, "CAPTURE_DEPTH insuficiente no monitor I2S.");
                    end else begin
                        captured_tag_mem[captured_write_idx]   <= decode_tag(decoded_word);
                        captured_left_mem[captured_write_idx]  <= decode_payload(decoded_word);
                        captured_right_mem[captured_write_idx] <= decode_payload(mon_right_word_r);
                        captured_write_idx                     <= captured_write_idx + 1;
                        mon_have_right_r                      <= 1'b0;

                        // O protocolo tagged usa o mesmo tipo em ambos os canais de um frame.
                        assert (decode_tag(decoded_word) == decode_tag(mon_right_word_r))
                        else $fatal(1, "Tags diferentes entre canais no frame idx=%0d", captured_write_idx);
                    end
                end

                mon_slot_count_r <= 0;
            end else begin
                mon_slot_count_r <= next_count;
            end
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
        captured_read_idx = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        send_fft_bin(18'sd10,  -18'sd10,  8'sd5, 1'b0);
        send_fft_bin(18'sd20,  -18'sd20,  8'sd5, 1'b0);
        send_fft_bin(18'sd30,  -18'sd30,  8'sd5, 1'b1);
        send_fft_bin(18'sd40,  -18'sd40, -8'sd3, 1'b0);
        send_fft_bin(18'sd50,  -18'sd50, -8'sd3, 1'b1);

        repeat (2) @(posedge clk);
        // O serializador pode comecar a drenar a FIFO assim que os bins chegam.
        // A verificacao robusta deste bench eh a sequencia I2S capturada abaixo,
        // nao um snapshot instantaneo do nivel da FIFO.

        set_expected_frame(0,  TAG_BFPEXP_C,  18'sd5,   18'sd5);
        set_expected_frame(1,  TAG_BFPEXP_C,  18'sd5,   18'sd5);
        set_expected_frame(2,  TAG_BFPEXP_C,  18'sd5,   18'sd5);
        set_expected_frame(3,  TAG_FFT_C,     18'sd10, -18'sd10);
        set_expected_frame(4,  TAG_FFT_C,     18'sd20, -18'sd20);
        set_expected_frame(5,  TAG_FFT_C,     18'sd30, -18'sd30);
        set_expected_frame(6,  TAG_BFPEXP_C, -18'sd3,  -18'sd3);
        set_expected_frame(7,  TAG_BFPEXP_C, -18'sd3,  -18'sd3);
        set_expected_frame(8,  TAG_BFPEXP_C, -18'sd3,  -18'sd3);
        set_expected_frame(9,  TAG_FFT_C,     18'sd40, -18'sd40);
        set_expected_frame(10, TAG_FFT_C,     18'sd50, -18'sd50);

        wait_for_first_expected_frame();
        check_expected_sequence();

        assert (overflow_o == 1'b0)
        else $fatal(1, "overflow_o nao deveria ter sido ativado.");

        wait (fifo_empty_o == 1'b1);
        repeat (4) @(posedge clk);

        $display("tb_i2s_fft_tx_adapter PASSED");
        $finish;
    end

endmodule
