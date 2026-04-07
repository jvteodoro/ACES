`timescale 1ns/1ps

module tb_top_level_i2s_fft_tx_diag;

    localparam int FFT_DW                    = 18;
    localparam int I2S_SLOT_W                = 32;
    localparam int I2S_CLOCK_DIV             = 2;
    localparam int DIAG_WINDOW_BINS          = 4;
    localparam int DIAG_BFPEXP_HOLD_FRAMES   = 1;
    localparam int CAPTURE_DEPTH             = 128;
    localparam int EXPECTED_COUNT            = 10;
    localparam int PACKET_INDEX_W            = 10;
    localparam int TAG_W                     = 2;
    localparam int RESERVED_W                = I2S_SLOT_W - FFT_DW - TAG_W - PACKET_INDEX_W;
    localparam int TAG_LSB                   = FFT_DW + RESERVED_W;
    localparam int PACKET_INDEX_LSB          = TAG_LSB + TAG_W;
    localparam time CLK_HALF                 = 5ns;

    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;
    localparam logic [PACKET_INDEX_W-1:0] FFT_PACKET_INDEX_BASE_C = PACKET_INDEX_W'(1 << (PACKET_INDEX_W-1));

    localparam logic signed [FFT_DW-1:0] DIAG_FFT_REAL_C = 18'sh15555;
    localparam logic signed [FFT_DW-1:0] DIAG_FFT_IMAG_C = 18'sh0AAAB;
    localparam logic signed [FFT_DW-1:0] DIAG_BFPEXP_EXT_C = 18'sd18;

    function automatic logic [I2S_SLOT_W-1:0] pack_slot_word(
        input logic [PACKET_INDEX_W-1:0] packet_index_i,
        input logic [TAG_W-1:0] tag_i,
        input logic signed [FFT_DW-1:0] payload_i
    );
        begin
            pack_slot_word = {packet_index_i, tag_i, {RESERVED_W{1'b0}}, payload_i};
        end
    endfunction

    logic gpio_0_d0;
    logic gpio_0_d1;
    logic gpio_1_d27;
    logic gpio_1_d29;
    logic gpio_1_d31;
    bit sd_phase_checks_armed_r;
    bit ws_phase_checks_armed_r;

    int sck_toggle_count;

    logic mon_slot_ws_r;
    logic [I2S_SLOT_W-1:0] mon_slot_shift_r;
    int mon_slot_count_r;
    logic mon_prev_slot_valid_r;
    logic mon_prev_slot_ws_r;
    logic [I2S_SLOT_W-1:0] mon_left_word_r;
    logic [I2S_SLOT_W-1:0] mon_right_word_r;
    logic mon_pending_ws_r;
    bit mon_have_right_r;
    bit mon_have_left_r;
    bit mon_pending_start_r;

    logic [I2S_SLOT_W-1:0] captured_left_word_mem [0:CAPTURE_DEPTH-1];
    logic [I2S_SLOT_W-1:0] captured_right_word_mem [0:CAPTURE_DEPTH-1];
    logic [I2S_SLOT_W-1:0] expected_left_word_mem [0:EXPECTED_COUNT-1];
    logic [I2S_SLOT_W-1:0] expected_right_word_mem [0:EXPECTED_COUNT-1];
    int captured_write_idx;
    int captured_read_idx;

    function automatic logic [TAG_W-1:0] decode_tag(
        input logic [I2S_SLOT_W-1:0] word_i
    );
        begin
            decode_tag = word_i[TAG_LSB +: TAG_W];
        end
    endfunction

    function automatic logic [PACKET_INDEX_W-1:0] decode_packet_index(
        input logic [I2S_SLOT_W-1:0] word_i
    );
        begin
            decode_packet_index = word_i[PACKET_INDEX_LSB +: PACKET_INDEX_W];
        end
    endfunction

    function automatic logic signed [FFT_DW-1:0] decode_payload(
        input logic [I2S_SLOT_W-1:0] word_i
    );
        begin
            decode_payload = $signed(word_i[FFT_DW-1:0]);
        end
    endfunction

    task automatic set_expected_frame(
        input int idx_i,
        input logic [I2S_SLOT_W-1:0] left_i,
        input logic [I2S_SLOT_W-1:0] right_i
    );
        begin
            expected_left_word_mem[idx_i] = left_i;
            expected_right_word_mem[idx_i] = right_i;
        end
    endtask

    task automatic wait_for_first_expected_frame;
        bit found;
        int timeout_cycles;
        int dump_idx;
        begin
            found = 1'b0;
            timeout_cycles = 0;

            while ((timeout_cycles < 200000) && !found) begin
                if (captured_read_idx < captured_write_idx) begin
                    if ((captured_left_word_mem[captured_read_idx] === expected_left_word_mem[0]) &&
                        (captured_right_word_mem[captured_read_idx] === expected_right_word_mem[0])) begin
                        found = 1'b1;
                    end else begin
                        captured_read_idx = captured_read_idx + 1;
                    end
                end

                if (!found) begin
                    @(posedge gpio_0_d0);
                    timeout_cycles = timeout_cycles + 1;
                end
            end

            if (!found) begin
                $display("Captured frames before timeout: %0d", captured_write_idx);
                for (dump_idx = 0; dump_idx < captured_write_idx && dump_idx < 8; dump_idx++) begin
                    $display("captured[%0d] left=%08x right=%08x pkt=%0d tag=%0d payload_l=%0d payload_r=%0d",
                             dump_idx,
                             captured_left_word_mem[dump_idx],
                             captured_right_word_mem[dump_idx],
                             decode_packet_index(captured_left_word_mem[dump_idx]),
                             decode_tag(captured_left_word_mem[dump_idx]),
                             decode_payload(captured_left_word_mem[dump_idx]),
                             decode_payload(captured_right_word_mem[dump_idx]));
                end
                $fatal(1, "Nao foi encontrado o primeiro frame BFPEXP esperado.");
            end
        end
    endtask

    task automatic check_expected_sequence;
        int idx;
        int timeout_cycles;
        begin
            for (idx = 0; idx < EXPECTED_COUNT; idx++) begin
                timeout_cycles = 0;
                while ((captured_read_idx >= captured_write_idx) && (timeout_cycles < 200000)) begin
                    @(posedge gpio_0_d0);
                    timeout_cycles = timeout_cycles + 1;
                end

                if (captured_read_idx >= captured_write_idx)
                    $fatal(1, "Timeout esperando frame idx=%0d", idx);

                assert (captured_left_word_mem[captured_read_idx] === expected_left_word_mem[idx])
                else $fatal(
                    1,
                    "LEFT word mismatch idx=%0d exp=%h got=%h exp_pkt=%0d got_pkt=%0d exp_tag=%0d got_tag=%0d exp_payload=%0d got_payload=%0d",
                    idx,
                    expected_left_word_mem[idx],
                    captured_left_word_mem[captured_read_idx],
                    decode_packet_index(expected_left_word_mem[idx]),
                    decode_packet_index(captured_left_word_mem[captured_read_idx]),
                    decode_tag(expected_left_word_mem[idx]),
                    decode_tag(captured_left_word_mem[captured_read_idx]),
                    decode_payload(expected_left_word_mem[idx]),
                    decode_payload(captured_left_word_mem[captured_read_idx])
                );

                assert (captured_right_word_mem[captured_read_idx] === expected_right_word_mem[idx])
                else $fatal(
                    1,
                    "RIGHT word mismatch idx=%0d exp=%h got=%h exp_pkt=%0d got_pkt=%0d exp_tag=%0d got_tag=%0d exp_payload=%0d got_payload=%0d",
                    idx,
                    expected_right_word_mem[idx],
                    captured_right_word_mem[captured_read_idx],
                    decode_packet_index(expected_right_word_mem[idx]),
                    decode_packet_index(captured_right_word_mem[captured_read_idx]),
                    decode_tag(expected_right_word_mem[idx]),
                    decode_tag(captured_right_word_mem[captured_read_idx]),
                    decode_payload(expected_right_word_mem[idx]),
                    decode_payload(captured_right_word_mem[captured_read_idx])
                );

                captured_read_idx = captured_read_idx + 1;
            end
        end
    endtask

    always #CLK_HALF gpio_0_d0 = ~gpio_0_d0;

    top_level_i2s_fft_tx_diag #(
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV),
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
        .clock_50(gpio_0_d0),
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
        .gpio_0_d0(gpio_0_d0),
        .gpio_0_d1(gpio_0_d1),
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
        .gpio_1_d1(),
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
        .gpio_1_d21(1'b0),
        .gpio_1_d22(1'b0),
        .gpio_1_d23(1'b0),
        .gpio_1_d24(1'b0),
        .gpio_1_d25(1'b0),
        .gpio_1_d26(1'b0),
        .gpio_1_d27(gpio_1_d27),
        .gpio_1_d28(1'b0),
        .gpio_1_d29(gpio_1_d29),
        .gpio_1_d30(1'b0),
        .gpio_1_d31(gpio_1_d31),
        .gpio_1_d32(1'b0),
        .gpio_1_d33(1'b0),
        .gpio_1_d34(1'b0),
        .gpio_1_d35(1'b0)
    );

    always @(posedge gpio_1_d27 or negedge gpio_1_d27 or posedge gpio_0_d1) begin
        if (gpio_0_d1)
            sck_toggle_count <= 0;
        else
            sck_toggle_count <= sck_toggle_count + 1;
    end

    always @(gpio_1_d31 or posedge gpio_0_d1) begin
        if (gpio_0_d1) begin
            sd_phase_checks_armed_r <= 1'b0;
        end else if (!sd_phase_checks_armed_r) begin
            sd_phase_checks_armed_r <= 1'b1;
        end else begin
            assert (gpio_1_d27 == 1'b0)
            else $fatal(1, "SD exportado pelo topo mudou fora da fase baixa do BCLK.");
        end
    end

    always @(gpio_1_d29 or posedge gpio_0_d1) begin
        if (gpio_0_d1) begin
            ws_phase_checks_armed_r <= 1'b0;
        end else if (!ws_phase_checks_armed_r) begin
            ws_phase_checks_armed_r <= 1'b1;
        end else begin
            assert ((gpio_1_d27 == 1'b1) &&
                    (dut.u_i2s_fft_tx_adapter.div_cnt_r == I2S_CLOCK_DIV-1) &&
                    (dut.u_i2s_fft_tx_adapter.slot_bit_r == I2S_SLOT_W-2))
            else $fatal(1,
                        "WS exportado pelo topo mudou fora da janela antecipada antes do falling edge final do slot. sck=%0b div=%0d slot=%0d",
                        gpio_1_d27, dut.u_i2s_fft_tx_adapter.div_cnt_r, dut.u_i2s_fft_tx_adapter.slot_bit_r);
        end
    end

    always @(posedge gpio_1_d27 or posedge gpio_0_d1) begin
        logic ws_changed;
        logic [I2S_SLOT_W-1:0] completed_word;

        if (gpio_0_d1) begin
            mon_slot_ws_r         <= 1'b0;
            mon_slot_shift_r      <= '0;
            mon_slot_count_r      <= 0;
            mon_prev_slot_valid_r <= 1'b0;
            mon_prev_slot_ws_r    <= 1'b0;
            mon_left_word_r       <= '0;
            mon_right_word_r      <= '0;
            mon_pending_ws_r      <= 1'b0;
            mon_have_right_r      <= 1'b0;
            mon_have_left_r       <= 1'b0;
            mon_pending_start_r   <= 1'b0;
            captured_write_idx    <= 0;
        end else begin
            ws_changed = mon_prev_slot_valid_r && (gpio_1_d29 != mon_prev_slot_ws_r);

            if (mon_pending_start_r) begin
                assert (!ws_changed)
                else $fatal(1, "WS alternou novamente antes do MSB esperado.");

                assert (gpio_1_d29 == mon_pending_ws_r)
                else $fatal(1, "WS nao permaneceu estavel entre a borda de alinhamento e o MSB.");

                mon_slot_ws_r       <= mon_pending_ws_r;
                mon_slot_shift_r    <= {{(I2S_SLOT_W-1){1'b0}}, gpio_1_d31};
                mon_slot_count_r    <= 1;
                mon_pending_start_r <= 1'b0;
            end else if (mon_slot_count_r != 0) begin
                completed_word = {mon_slot_shift_r[I2S_SLOT_W-2:0], gpio_1_d31};

                if (mon_slot_count_r == I2S_SLOT_W-1) begin
                    assert (ws_changed)
                    else $fatal(1, "WS nao antecipou o ultimo bit do slot I2S.");

                    mon_slot_count_r <= 0;
                    mon_slot_shift_r <= '0;

                    if (mon_slot_ws_r) begin
                        assert (!mon_have_right_r)
                        else $fatal(1, "Dois slots direitos consecutivos sem slot esquerdo correspondente.");

                        mon_right_word_r <= completed_word;
                        mon_have_right_r <= 1'b1;
                        mon_have_left_r  <= 1'b0;
                    end else begin
                        if (mon_have_right_r) begin
                            assert (decode_tag(completed_word) == decode_tag(mon_right_word_r))
                            else $fatal(1, "Tags diferentes entre canais no frame idx=%0d", captured_write_idx);

                            assert (decode_packet_index(completed_word) == decode_packet_index(mon_right_word_r))
                            else $fatal(1, "Packet index diferente entre canais no frame idx=%0d", captured_write_idx);

                            if (captured_write_idx >= CAPTURE_DEPTH) begin
                                $fatal(1, "CAPTURE_DEPTH insuficiente no monitor I2S.");
                            end else begin
                                captured_left_word_mem[captured_write_idx]  <= completed_word;
                                captured_right_word_mem[captured_write_idx] <= mon_right_word_r;
                                captured_write_idx                          <= captured_write_idx + 1;
                                mon_have_right_r                           <= 1'b0;
                            end
                        end else begin
                            mon_left_word_r <= completed_word;
                            mon_have_left_r <= 1'b1;
                        end
                    end
                end else begin
                    assert (!ws_changed)
                    else $fatal(1, "WS alternou antes do ultimo bit do slot I2S.");

                    mon_slot_shift_r <= completed_word;
                    mon_slot_count_r <= mon_slot_count_r + 1;
                end
            end

            if (ws_changed) begin
                assert (!mon_pending_start_r)
                else $fatal(1, "Borda de WS chegou enquanto um novo slot ja estava pendente.");

                mon_pending_start_r <= 1'b1;
                mon_pending_ws_r    <= gpio_1_d29;
            end

            mon_prev_slot_valid_r <= 1'b1;
            mon_prev_slot_ws_r    <= gpio_1_d29;
        end
    end

    initial begin
        gpio_0_d0        = 1'b0;
        gpio_0_d1        = 1'b1;
        captured_read_idx = 0;

        set_expected_frame(0,
                           pack_slot_word(10'd0, TAG_BFPEXP_C, DIAG_BFPEXP_EXT_C),
                           pack_slot_word(10'd0, TAG_BFPEXP_C, DIAG_BFPEXP_EXT_C));
        set_expected_frame(1,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd0, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd0, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(2,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd1, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd1, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(3,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd2, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd2, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(4,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd3, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd3, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(5,
                           pack_slot_word(10'd0, TAG_BFPEXP_C, DIAG_BFPEXP_EXT_C),
                           pack_slot_word(10'd0, TAG_BFPEXP_C, DIAG_BFPEXP_EXT_C));
        set_expected_frame(6,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd0, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd0, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(7,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd1, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd1, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(8,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd2, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd2, TAG_FFT_C, DIAG_FFT_IMAG_C));
        set_expected_frame(9,
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd3, TAG_FFT_C, DIAG_FFT_REAL_C),
                           pack_slot_word(FFT_PACKET_INDEX_BASE_C + 10'd3, TAG_FFT_C, DIAG_FFT_IMAG_C));

        repeat (4) @(posedge gpio_0_d0);
        gpio_0_d1 = 1'b0;

        wait_for_first_expected_frame();
        check_expected_sequence();

        assert (sck_toggle_count > 64)
        else $fatal(1, "Poucos toggles de SCK observados: %0d", sck_toggle_count);

        assert (!dut.diag_overflow_latched_r)
        else $fatal(1, "O topo de diagnostico nao deveria acionar overflow.");

        assert (dut.diag_window_count_r >= 2)
        else $fatal(1, "Esperado observar pelo menos duas janelas completas.");

        repeat (8) @(posedge gpio_0_d0);

        $display("tb_top_level_i2s_fft_tx_diag PASSED");
        $finish;
    end

endmodule
