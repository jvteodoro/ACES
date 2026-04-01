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
    localparam int SEARCH_PREFIX_COUNT = 4;
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

    logic mon_prev_ws_r;
    logic mon_word_collecting_r;
    logic mon_word_start_next_r;
    logic mon_word_channel_r;
    logic [31:0] mon_word_shift_r;
    int mon_word_count_r;
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

    task automatic wait_for_first_expected_frame;
        bit found;
        bit prefix_matches;
        int timeout_cycles;
        int probe_idx;
        begin
            found = 1'b0;
            timeout_cycles = 0;

            while ((timeout_cycles < 400000) && !found) begin
                if ((captured_write_idx - captured_read_idx) >= SEARCH_PREFIX_COUNT) begin
                    prefix_matches = 1'b1;

                    for (probe_idx = 0; probe_idx < SEARCH_PREFIX_COUNT; probe_idx++) begin
                        if ((captured_tag_mem[captured_read_idx + probe_idx]   !== expected_tag_mem[probe_idx]) ||
                            (captured_left_mem[captured_read_idx + probe_idx]  !== expected_left_mem[probe_idx]) ||
                            (captured_right_mem[captured_read_idx + probe_idx] !== expected_right_mem[probe_idx])) begin
                            prefix_matches = 1'b0;
                        end
                    end

                    if (prefix_matches) begin
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
                else $error("TAG mismatch idx=%0d exp=%0d got=%0d", idx, expected_tag_mem[idx], captured_tag_mem[captured_read_idx]);

                assert (captured_left_mem[captured_read_idx] === expected_left_mem[idx])
                else $error("LEFT mismatch idx=%0d exp=%0d got=%0d", idx, expected_left_mem[idx], captured_left_mem[captured_read_idx]);

                assert (captured_right_mem[captured_read_idx] === expected_right_mem[idx])
                else $error("RIGHT mismatch idx=%0d exp=%0d got=%0d", idx, expected_right_mem[idx], captured_right_mem[captured_read_idx]);

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
        logic ws_changed;
        logic collecting_next;
        logic start_word_next;
        logic word_channel_next;
        logic [31:0] word_shift_next;
        int word_count_next;
        logic completed_word_valid;
        logic completed_word_channel;
        logic [31:0] completed_word;

        if (rst) begin
            mon_prev_ws_r           <= 1'b1;
            mon_word_collecting_r   <= 1'b0;
            mon_word_start_next_r   <= 1'b0;
            mon_word_channel_r      <= 1'b0;
            mon_word_shift_r        <= '0;
            mon_word_count_r        <= 0;
            mon_right_word_r        <= '0;
            mon_have_right_r        <= 1'b0;
            captured_write_idx      <= 0;
        end else begin
            ws_changed = (i2s_ws_o != mon_prev_ws_r);

            collecting_next     = mon_word_collecting_r;
            start_word_next     = mon_word_start_next_r;
            word_channel_next   = mon_word_channel_r;
            word_shift_next     = mon_word_shift_r;
            word_count_next     = mon_word_count_r;
            completed_word_valid = 1'b0;
            completed_word_channel = 1'b0;
            completed_word = '0;

            if (mon_word_start_next_r) begin
                collecting_next   = 1'b1;
                start_word_next   = 1'b0;
                word_channel_next = i2s_ws_o;
                word_shift_next   = {31'd0, i2s_sd_o};
                word_count_next   = 1;
            end else if (mon_word_collecting_r) begin
                word_shift_next = {mon_word_shift_r[30:0], i2s_sd_o};
                word_count_next = mon_word_count_r + 1;
            end

            if (ws_changed)
                start_word_next = 1'b1;

            if (collecting_next && (word_count_next == SLOT_W)) begin
                completed_word_valid = 1'b1;
                completed_word_channel = word_channel_next;
                completed_word = word_shift_next;
                collecting_next = 1'b0;
                word_count_next = 0;
                word_shift_next = '0;
            end

            mon_prev_ws_r         <= i2s_ws_o;
            mon_word_collecting_r <= collecting_next;
            mon_word_start_next_r <= start_word_next;
            mon_word_channel_r    <= word_channel_next;
            mon_word_shift_r      <= word_shift_next;
            mon_word_count_r      <= word_count_next;

            if (completed_word_valid) begin
`ifdef TRACE_I2S_MONITOR
                $display(
                    "word channel=%0d tag=%0d payload=0x%08h time=%0t",
                    completed_word_channel,
                    decode_tag(completed_word),
                    completed_word,
                    $time
                );
`endif
                if (completed_word_channel) begin
                    mon_right_word_r <= completed_word;
                    mon_have_right_r <= 1'b1;
                end else if (mon_have_right_r) begin
                    if (captured_write_idx >= CAPTURE_DEPTH) begin
                        $fatal(1, "CAPTURE_DEPTH insuficiente no monitor I2S.");
                    end else begin
                        captured_tag_mem[captured_write_idx]   <= decode_tag(completed_word);
                        captured_left_mem[captured_write_idx]  <= decode_payload(completed_word);
                        captured_right_mem[captured_write_idx] <= decode_payload(mon_right_word_r);
                        captured_write_idx                     <= captured_write_idx + 1;
                        mon_have_right_r                      <= 1'b0;

                        // O protocolo tagged usa o mesmo tipo em ambos os canais de um frame.
                        assert (decode_tag(completed_word) == decode_tag(mon_right_word_r))
                        else $error("Tags diferentes entre canais no frame idx=%0d", captured_write_idx);

`ifdef TRACE_I2S_MONITOR
                        $display(
                            "frame idx=%0d left_tag=%0d right_tag=%0d left=%0d right=%0d time=%0t",
                            captured_write_idx,
                            decode_tag(completed_word),
                            decode_tag(mon_right_word_r),
                            decode_payload(completed_word),
                            decode_payload(mon_right_word_r),
                            $time
                        );
`endif
                    end
                end
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
        else $error("overflow_o nao deveria ter sido ativado.");

        wait (fifo_empty_o == 1'b1);
        repeat (4) @(posedge clk);

        $display("tb_i2s_fft_tx_adapter PASSED");
        $finish;
    end

endmodule
