`timescale 1ns/1ps

module tb_top_level_test;

    localparam int FFT_LENGTH             = 512;
    localparam int FFT_DW                 = 18;
    localparam int N_POINTS               = 512;
    localparam int N_EXAMPLES             = 8;
    localparam int I2S_CLOCK_DIV          = 4;
    localparam int BFPEXP_W               = 8;
    localparam int WORD_W                 = 32;
    localparam int I2S_SAMPLE_W           = 18;
    localparam int TAG_W                  = 2;
    localparam int BFPEXP_HOLD_FRAMES     = 1;
    localparam int TOTAL_SAMPLES          = N_EXAMPLES * N_POINTS;
    localparam int TOTAL_BINS             = N_EXAMPLES * FFT_LENGTH;
    localparam int SERIAL_FRAMES_PER_EX   = BFPEXP_HOLD_FRAMES + FFT_LENGTH;
    localparam int SERIAL_EXPECT_DEPTH    = SERIAL_FRAMES_PER_EX + 16;
    localparam int EXAMPLE_SEL_W          = (N_EXAMPLES <= 1) ? 1 : $clog2(N_EXAMPLES);
    localparam int FFT_N                  = $clog2(FFT_LENGTH);
    localparam time CLK_HALF              = 5ns;
    localparam int SPI_HALF_CYCLES        = 4;
    localparam int MAX_SAMPLE_SLACK       = 4;
    localparam int MAX_EXAMPLE_CYCLES     = 1_000_000;

`ifdef TB_TOP_LEVEL_REAL_FLOW
    localparam bit REAL_FLOW              = 1'b1;
    localparam int EXAMPLES_TO_RUN        = N_EXAMPLES;
    localparam real FFT_MAX_ABS_ERR_TOL   = 100_000.0;
    localparam real FFT_RMSE_ERR_TOL      = 12_000.0;
`else
    localparam bit REAL_FLOW              = 1'b0;
    localparam int EXAMPLES_TO_RUN        = 1;
    localparam real FFT_MAX_ABS_ERR_TOL   = 0.0;
    localparam real FFT_RMSE_ERR_TOL      = 0.0;
`endif

    localparam logic [TAG_W-1:0] TAG_IDLE_C   = 2'd0;
    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

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
    logic tb_dbg_stage0_drive;
    logic tb_dbg_stage1_drive;
    logic tb_dbg_page0_drive;
    logic tb_dbg_page1_drive;
    logic tb_spi_sclk_drive;
    logic tb_spi_cs_n_drive;

    int expected_sample24_mem [0:TOTAL_SAMPLES-1];
    int expected_sample18_mem [0:TOTAL_SAMPLES-1];
    real expected_fft_real_mem [0:TOTAL_BINS-1];
    real expected_fft_imag_mem [0:TOTAL_BINS-1];

    real measured_fft_real_mem [0:FFT_LENGTH-1];
    real measured_fft_imag_mem [0:FFT_LENGTH-1];

    logic [TAG_W-1:0] expected_tag_mem [0:SERIAL_EXPECT_DEPTH-1];
    logic signed [I2S_SAMPLE_W-1:0] expected_left_mem [0:SERIAL_EXPECT_DEPTH-1];
    logic signed [I2S_SAMPLE_W-1:0] expected_right_mem [0:SERIAL_EXPECT_DEPTH-1];

    int active_example_r;
    bit example_in_progress_r;
    int sample24_count_r;
    int sample18_count_r;
    int extra_sample24_count_r;
    int extra_sample18_count_r;
    int fft_bin_count_r;
    int extra_fft_bin_count_r;
    int serial_expected_write_idx_r;
    int serial_expected_read_idx_r;
    int serial_frames_seen_r;
    int extra_serial_frames_r;
    int fft_run_count_r;

    logic signed [BFPEXP_W-1:0] frame_bfpexp_r;
    bit frame_bfpexp_valid_r;
    bit serial_bfpexp_enqueued_r;
    bit stim_done_seen_r;
    bit fft_done_seen_r;
    bit tx_overflow_seen_r;
    bit fft_frame_done_r;
    bit sact_prev_r;
    bit fft_run_seen_r;
    bit fft_ingest_gated_r;
    bit fft_ingest_gate_pending_r;

    integer dump_sample24_fd_r;
    integer dump_fft_input_fd_r;
    integer dump_fft_output_fd_r;
    integer dump_tx_frames_fd_r;
    bit dump_files_open_r;

    function automatic int flat_sample_idx(input int example_idx, input int sample_idx);
        flat_sample_idx = example_idx * N_POINTS + sample_idx;
    endfunction

    function automatic int flat_fft_idx(input int example_idx, input int bin_idx);
        flat_fft_idx = example_idx * FFT_LENGTH + bin_idx;
    endfunction

    function automatic logic [TAG_W-1:0] decode_tag(
        input logic [WORD_W-1:0] word_i
    );
        begin
            decode_tag = word_i[WORD_W-1 -: TAG_W];
        end
    endfunction

    function automatic logic signed [I2S_SAMPLE_W-1:0] decode_payload(
        input logic [WORD_W-1:0] word_i
    );
        begin
            decode_payload = $signed(word_i[I2S_SAMPLE_W-1:0]);
        end
    endfunction

    function automatic logic signed [I2S_SAMPLE_W-1:0] extend_bfpexp_payload(
        input logic signed [BFPEXP_W-1:0] bfpexp_i
    );
        begin
            extend_bfpexp_payload = {{(I2S_SAMPLE_W-BFPEXP_W){bfpexp_i[BFPEXP_W-1]}}, bfpexp_i};
        end
    endfunction

    function automatic logic signed [FFT_DW-1:0] expected_mock_imag(
        input int idx_i
    );
        logic signed [FFT_N-1:0] addr_s;
        begin
            addr_s = idx_i[FFT_N-1:0];
            expected_mock_imag = -addr_s;
        end
    endfunction

    function automatic real apply_bfpexp(
        input logic signed [FFT_DW-1:0] sample_i,
        input logic signed [BFPEXP_W-1:0] bfpexp_i
    );
        real value_r;
        int shift_i;
        begin
            value_r = $itor(sample_i);
            if (bfpexp_i >= 0) begin
                for (shift_i = 0; shift_i < bfpexp_i; shift_i++)
                    value_r = value_r * 2.0;
            end else begin
                for (shift_i = 0; shift_i < -bfpexp_i; shift_i++)
                    value_r = value_r / 2.0;
            end
            apply_bfpexp = value_r;
        end
    endfunction

    task automatic enqueue_expected_frame(
        input logic [TAG_W-1:0] tag_i,
        input logic signed [I2S_SAMPLE_W-1:0] left_i,
        input logic signed [I2S_SAMPLE_W-1:0] right_i
    );
        begin
            if (serial_expected_write_idx_r >= SERIAL_EXPECT_DEPTH)
                $fatal(1, "SERIAL_EXPECT_DEPTH insuficiente no scoreboard do top-level.");

            expected_tag_mem[serial_expected_write_idx_r]   = tag_i;
            expected_left_mem[serial_expected_write_idx_r]  = left_i;
            expected_right_mem[serial_expected_write_idx_r] = right_i;
            serial_expected_write_idx_r                     = serial_expected_write_idx_r + 1;
        end
    endtask

    task automatic close_diag_files;
        begin
            if (dump_sample24_fd_r != 0) begin
                $fclose(dump_sample24_fd_r);
                dump_sample24_fd_r = 0;
            end
            if (dump_fft_input_fd_r != 0) begin
                $fclose(dump_fft_input_fd_r);
                dump_fft_input_fd_r = 0;
            end
            if (dump_fft_output_fd_r != 0) begin
                $fclose(dump_fft_output_fd_r);
                dump_fft_output_fd_r = 0;
            end
            if (dump_tx_frames_fd_r != 0) begin
                $fclose(dump_tx_frames_fd_r);
                dump_tx_frames_fd_r = 0;
            end
            dump_files_open_r = 1'b0;
        end
    endtask

    task automatic open_diag_files(input int example_idx);
        string path_s;
        begin
            close_diag_files();
            if (REAL_FLOW) begin
                path_s = $sformatf("top_level_test_example_%0d_sample24.csv", example_idx);
                dump_sample24_fd_r = $fopen(path_s, "w");
                if (dump_sample24_fd_r == 0)
                    $fatal(1, "Nao foi possivel abrir %s para dump diagnostico", path_s);
                $fdisplay(dump_sample24_fd_r,
                          "sample24_idx,stim_point,stim_rom_addr,stim_state,stim_sample_dbg,got_sample24,expected_sample24,in_expected_window");

                path_s = $sformatf("top_level_test_example_%0d_fft_input.csv", example_idx);
                dump_fft_input_fd_r = $fopen(path_s, "w");
                if (dump_fft_input_fd_r == 0)
                    $fatal(1, "Nao foi possivel abrir %s para dump diagnostico", path_s);
                $fdisplay(dump_fft_input_fd_r,
                          "sample18_idx,got_sample18,expected_sample18,sdw_real,sdw_imag,fft_run,fft_status,in_expected_window");

                path_s = $sformatf("top_level_test_example_%0d_fft_output.csv", example_idx);
                dump_fft_output_fd_r = $fopen(path_s, "w");
                if (dump_fft_output_fd_r == 0)
                    $fatal(1, "Nao foi possivel abrir %s para dump diagnostico", path_s);
                $fdisplay(dump_fft_output_fd_r,
                          "bin_seq,tx_index,tx_real_raw,tx_imag_raw,bfpexp,corrected_real,corrected_imag,expected_real,expected_imag,abs_err,last,in_expected_window");

                path_s = $sformatf("top_level_test_example_%0d_tx_frames.csv", example_idx);
                dump_tx_frames_fd_r = $fopen(path_s, "w");
                if (dump_tx_frames_fd_r == 0)
                    $fatal(1, "Nao foi possivel abrir %s para dump diagnostico", path_s);
                $fdisplay(dump_tx_frames_fd_r,
                          "frame_seq,event,actual_tag,actual_left,actual_right,expected_idx,expected_tag,expected_left,expected_right,left_word_hex,right_word_hex");

                dump_files_open_r = 1'b1;
            end
        end
    endtask

    task automatic reset_example_scoreboard(input int example_idx);
        int bin_idx;
        begin
            active_example_r             = example_idx;
            example_in_progress_r        = 1'b1;
            sample24_count_r             = 0;
            sample18_count_r             = 0;
            extra_sample24_count_r       = 0;
            extra_sample18_count_r       = 0;
            fft_bin_count_r              = 0;
            extra_fft_bin_count_r        = 0;
            serial_expected_write_idx_r  = 0;
            serial_expected_read_idx_r   = 0;
            serial_frames_seen_r         = 0;
            extra_serial_frames_r        = 0;
            fft_run_count_r              = 0;
            frame_bfpexp_r               = '0;
            frame_bfpexp_valid_r         = 1'b0;
            serial_bfpexp_enqueued_r     = 1'b0;
            stim_done_seen_r             = 1'b0;
            fft_done_seen_r              = 1'b0;
            tx_overflow_seen_r           = 1'b0;
            fft_frame_done_r             = 1'b0;
            fft_run_seen_r               = 1'b0;
            fft_ingest_gated_r           = 1'b0;
            fft_ingest_gate_pending_r    = 1'b0;

            for (bin_idx = 0; bin_idx < FFT_LENGTH; bin_idx++) begin
                measured_fft_real_mem[bin_idx] = 0.0;
                measured_fft_imag_mem[bin_idx] = 0.0;
            end

            open_diag_files(example_idx);
        end
    endtask

    task automatic gate_fft_ingest_after_window;
        begin
            force dut.u_aces.u_audio_to_fft_pipeline.sample_pulse_clk = 1'b0;
            fft_ingest_gated_r = 1'b1;
        end
    endtask

    task automatic release_fft_ingest_gate;
        begin
            if (fft_ingest_gated_r) begin
                release dut.u_aces.u_audio_to_fft_pipeline.sample_pulse_clk;
                fft_ingest_gated_r = 1'b0;
            end
        end
    endtask

    task automatic apply_reset_sequence;
        begin
            release_fft_ingest_gate();
            tb_rst_drive = 1'b1;
            repeat (8) @(posedge tb_clk_drive);
            tb_rst_drive = 1'b0;
            repeat (8) @(posedge tb_clk_drive);
        end
    endtask

    task automatic load_expected_samples;
        string path_s;
        reg [2047:0] header_s;
        int fd_i;
        int ex_idx;
        int sample_idx;
        int sample24_i;
        int sample18_i;
        int scan_count;
        begin
            path_s = "../../../../tb/data/top_level_test_expected_samples.csv";
            fd_i = $fopen(path_s, "r");
            if (fd_i == 0)
                $fatal(1, "Nao foi possivel abrir %s", path_s);

            void'($fgets(header_s, fd_i));
            scan_count = 0;
            while (!$feof(fd_i)) begin
                if ($fscanf(fd_i, "%d,%d,%d,%d\n", ex_idx, sample_idx, sample24_i, sample18_i) == 4) begin
                    expected_sample24_mem[flat_sample_idx(ex_idx, sample_idx)] = sample24_i;
                    expected_sample18_mem[flat_sample_idx(ex_idx, sample_idx)] = sample18_i;
                    scan_count = scan_count + 1;
                end else begin
                    void'($fgets(header_s, fd_i));
                end
            end

            $fclose(fd_i);

            assert (scan_count == TOTAL_SAMPLES)
            else $fatal(1, "Arquivo de samples esperados incompleto. exp=%0d got=%0d", TOTAL_SAMPLES, scan_count);
        end
    endtask

    task automatic load_expected_fft;
        string path_s;
        reg [2047:0] header_s;
        int fd_i;
        int ex_idx;
        int bin_idx;
        real real_r;
        real imag_r;
        int scan_count;
        begin
            path_s = "../../../../tb/data/top_level_test_expected_fft.csv";
            fd_i = $fopen(path_s, "r");
            if (fd_i == 0)
                $fatal(1, "Nao foi possivel abrir %s", path_s);

            void'($fgets(header_s, fd_i));
            scan_count = 0;
            while (!$feof(fd_i)) begin
                if ($fscanf(fd_i, "%d,%d,%f,%f\n", ex_idx, bin_idx, real_r, imag_r) == 4) begin
                    expected_fft_real_mem[flat_fft_idx(ex_idx, bin_idx)] = real_r;
                    expected_fft_imag_mem[flat_fft_idx(ex_idx, bin_idx)] = imag_r;
                    scan_count = scan_count + 1;
                end else begin
                    void'($fgets(header_s, fd_i));
                end
            end

            $fclose(fd_i);

            assert (scan_count == TOTAL_BINS)
            else $fatal(1, "Arquivo de FFT esperada incompleto. exp=%0d got=%0d", TOTAL_BINS, scan_count);
        end
    endtask

    task automatic start_example(input int example_idx);
        logic [EXAMPLE_SEL_W-1:0] example_bits;
        begin
            example_bits = example_idx[EXAMPLE_SEL_W-1:0];

            wait (dut.stim_ready_o == 1'b1);
            @(posedge tb_clk_drive);

            reset_example_scoreboard(example_idx);

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
            else $fatal(1, "Stimulus manager iniciou exemplo errado. exp=%0d got=%0d",
                        example_idx, dut.stim_current_example_o);

            $display("[%0t] top_level_test: iniciando exemplo %0d", $time, example_idx);
        end
    endtask

    task automatic check_fft_against_expected(input int example_idx);
        int bin_idx;
        real diff_real_r;
        real diff_imag_r;
        real abs_err_r;
        real max_abs_err_r;
        real mse_r;
        real rmse_r;
        begin
            max_abs_err_r = 0.0;
            mse_r         = 0.0;

            for (bin_idx = 0; bin_idx < FFT_LENGTH; bin_idx++) begin
                diff_real_r = measured_fft_real_mem[bin_idx] - expected_fft_real_mem[flat_fft_idx(example_idx, bin_idx)];
                diff_imag_r = measured_fft_imag_mem[bin_idx] - expected_fft_imag_mem[flat_fft_idx(example_idx, bin_idx)];

                abs_err_r = $sqrt((diff_real_r * diff_real_r) + (diff_imag_r * diff_imag_r));
                mse_r = mse_r + (abs_err_r * abs_err_r);

                if (abs_err_r > max_abs_err_r)
                    max_abs_err_r = abs_err_r;
            end

            rmse_r = $sqrt(mse_r / $itor(FFT_LENGTH));

            $display("[%0t] top_level_test: exemplo %0d FFT rmse=%0f max_abs=%0f bfpexp=%0d",
                     $time, example_idx, rmse_r, max_abs_err_r, frame_bfpexp_r);
            for (bin_idx = 0; bin_idx < 8; bin_idx = bin_idx + 1)
                $display("  bin %0d: measured=(%0f,%0f) expected=(%0f,%0f)",
                         bin_idx,
                         measured_fft_real_mem[bin_idx],
                         measured_fft_imag_mem[bin_idx],
                         expected_fft_real_mem[flat_fft_idx(example_idx, bin_idx)],
                         expected_fft_imag_mem[flat_fft_idx(example_idx, bin_idx)]);

            assert (max_abs_err_r <= FFT_MAX_ABS_ERR_TOL)
            else $fatal(1, "FFT max_abs_err fora da tolerancia no exemplo %0d: got=%0f tol=%0f",
                        example_idx, max_abs_err_r, FFT_MAX_ABS_ERR_TOL);

            assert (rmse_r <= FFT_RMSE_ERR_TOL)
            else $fatal(1, "FFT rmse fora da tolerancia no exemplo %0d: got=%0f tol=%0f",
                        example_idx, rmse_r, FFT_RMSE_ERR_TOL);
        end
    endtask

    task automatic wait_for_example_completion(input int example_idx);
        int timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((timeout_cycles < MAX_EXAMPLE_CYCLES) &&
                   !(fft_frame_done_r &&
                     (serial_expected_read_idx_r == serial_expected_write_idx_r) &&
                     (sample18_count_r >= N_POINTS) &&
                     dut.stim_ready_o)) begin
                @(posedge tb_clk_drive);
                timeout_cycles = timeout_cycles + 1;
            end

            if (timeout_cycles >= MAX_EXAMPLE_CYCLES)
                $fatal(1,
                       "Timeout esperando conclusao do exemplo %0d: fft_run_seen=%0b fft_frame_done=%0b serial_rd=%0d serial_wr=%0d sample18=%0d stim_ready=%0b extra_fft=%0d extra_serial=%0d gated=%0b gate_pending=%0b",
                       example_idx,
                       fft_run_seen_r,
                       fft_frame_done_r,
                       serial_expected_read_idx_r,
                       serial_expected_write_idx_r,
                       sample18_count_r,
                       dut.stim_ready_o,
                       extra_fft_bin_count_r,
                       extra_serial_frames_r,
                       fft_ingest_gated_r,
                       fft_ingest_gate_pending_r);
        end
    endtask

    task automatic check_example_summary(input int example_idx);
        begin
            if (REAL_FLOW) begin
                assert (sample24_count_r == N_POINTS)
                else $fatal(1, "Exemplo %0d deveria ter %0d amostras 24b, obteve %0d",
                            example_idx, N_POINTS, sample24_count_r);

                assert (sample18_count_r >= N_POINTS)
                else $fatal(1, "Exemplo %0d deveria ter pelo menos %0d amostras 18b, obteve %0d",
                            example_idx, N_POINTS, sample18_count_r);

                assert (stim_done_seen_r)
                else $fatal(1, "Exemplo %0d nao observou pulso de stim_done_o", example_idx);

                assert (fft_done_seen_r)
                else $fatal(1, "Exemplo %0d nao observou pulso de fft_done_o", example_idx);
            end else begin
                assert (sample18_count_r > 0)
                else $fatal(1, "Mock flow nao observou amostras ingeridas.");
            end

            assert (fft_bin_count_r == FFT_LENGTH)
            else $fatal(1, "Exemplo %0d deveria ter %0d bins FFT, obteve %0d",
                        example_idx, FFT_LENGTH, fft_bin_count_r);

            assert (serial_frames_seen_r == SERIAL_FRAMES_PER_EX)
            else $fatal(1, "Exemplo %0d deveria ter %0d frames I2S tagged, obteve %0d",
                        example_idx, SERIAL_FRAMES_PER_EX, serial_frames_seen_r);

            assert (!tx_overflow_seen_r)
            else $fatal(1, "Exemplo %0d ativou tx_overflow_o", example_idx);

            if (REAL_FLOW)
                check_fft_against_expected(example_idx);

            $display("[%0t] top_level_test: exemplo %0d concluido. sample24=%0d sample18=%0d fft_bins=%0d serial_frames=%0d extra_fft=%0d extra_serial=%0d",
                     $time, example_idx, sample24_count_r, sample18_count_r, fft_bin_count_r, serial_frames_seen_r,
                     extra_fft_bin_count_r, extra_serial_frames_r);
        end
    endtask

    task automatic run_example_and_check(input int example_idx);
        begin
            start_example(example_idx);
            wait_for_example_completion(example_idx);
            check_example_summary(example_idx);
            close_diag_files();
            example_in_progress_r = 1'b0;
            apply_reset_sequence();
        end
    endtask

    task automatic check_decoded_frame(
        input logic [WORD_W-1:0] left_word_i,
        input logic [WORD_W-1:0] right_word_i
    );
        logic [TAG_W-1:0] left_tag;
        logic [TAG_W-1:0] right_tag;
        logic signed [I2S_SAMPLE_W-1:0] left_payload;
        logic signed [I2S_SAMPLE_W-1:0] right_payload;
        int expected_idx_i;
        int frame_seq_i;
        logic [TAG_W-1:0] expected_tag_i;
        logic signed [I2S_SAMPLE_W-1:0] expected_left_i;
        logic signed [I2S_SAMPLE_W-1:0] expected_right_i;
        string event_s;
        begin
            left_tag      = decode_tag(left_word_i);
            right_tag     = decode_tag(right_word_i);
            left_payload  = decode_payload(left_word_i);
            right_payload = decode_payload(right_word_i);
            expected_idx_i   = -1;
            frame_seq_i      = serial_frames_seen_r + extra_serial_frames_r;
            expected_tag_i   = '0;
            expected_left_i  = '0;
            expected_right_i = '0;
            event_s          = "unclassified";

            if (serial_expected_read_idx_r < serial_expected_write_idx_r) begin
                expected_idx_i   = serial_expected_read_idx_r;
                expected_tag_i   = expected_tag_mem[serial_expected_read_idx_r];
                expected_left_i  = expected_left_mem[serial_expected_read_idx_r];
                expected_right_i = expected_right_mem[serial_expected_read_idx_r];
            end

            if (serial_expected_read_idx_r >= serial_expected_write_idx_r) begin
                if (REAL_FLOW && fft_frame_done_r)
                    event_s = "extra_after_done";
                else if (REAL_FLOW)
                    event_s = "unexpected_before_done";
                else
                    event_s = "no_expectation";
            end else if ((serial_frames_seen_r == 0) && (left_tag == TAG_IDLE_C)) begin
                event_s = "initial_idle";
            end else begin
                event_s = "matched";
            end

            if (dump_files_open_r) begin
                $fdisplay(dump_tx_frames_fd_r,
                          "%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%08x,%08x",
                          frame_seq_i,
                          event_s,
                          left_tag,
                          $signed(left_payload),
                          $signed(right_payload),
                          expected_idx_i,
                          expected_tag_i,
                          $signed(expected_left_i),
                          $signed(expected_right_i),
                          left_word_i,
                          right_word_i);
            end

            assert (left_tag == right_tag)
            else $fatal(1, "Tags diferentes entre canais do stream TX: left=%0d right=%0d", left_tag, right_tag);

            if (serial_expected_read_idx_r >= serial_expected_write_idx_r) begin
                if (REAL_FLOW && fft_frame_done_r) begin
                    event_s = "extra_after_done";
                    extra_serial_frames_r = extra_serial_frames_r + 1;
                end else if (REAL_FLOW) begin
                    event_s = "unexpected_before_done";
                    assert (left_tag == TAG_IDLE_C)
                    else $fatal(1, "Frame tagged inesperado no stream TX. tag=%0d left=%0d right=%0d",
                                left_tag, left_payload, right_payload);
                end
            end else begin
                if ((serial_frames_seen_r == 0) && (left_tag == TAG_IDLE_C)) begin
                    event_s = "initial_idle";
                    assert (left_payload == '0 && right_payload == '0)
                    else $fatal(1, "Frame IDLE inicial do stream TX deveria carregar zeros. left=%0d right=%0d",
                                left_payload, right_payload);
                end else begin
                    event_s = "matched";
                    assert (left_tag === expected_tag_mem[serial_expected_read_idx_r])
                    else $fatal(1, "TAG do stream TX mismatch idx=%0d exp=%0d got=%0d",
                                serial_expected_read_idx_r, expected_tag_mem[serial_expected_read_idx_r], left_tag);

                    assert (left_payload === expected_left_mem[serial_expected_read_idx_r])
                    else $fatal(1, "LEFT do stream TX mismatch idx=%0d exp=%0d got=%0d",
                                serial_expected_read_idx_r, expected_left_mem[serial_expected_read_idx_r], left_payload);

                    assert (right_payload === expected_right_mem[serial_expected_read_idx_r])
                    else $fatal(1, "RIGHT do stream TX mismatch idx=%0d exp=%0d got=%0d",
                                serial_expected_read_idx_r, expected_right_mem[serial_expected_read_idx_r], right_payload);

                    serial_expected_read_idx_r = serial_expected_read_idx_r + 1;
                    serial_frames_seen_r       = serial_frames_seen_r + 1;
                end
            end

        end
    endtask

    task automatic spi_wait_half_period;
        begin
            repeat (SPI_HALF_CYCLES) @(posedge tb_clk_drive);
        end
    endtask

    task automatic spi_read_byte(output logic [7:0] byte_o);
        int bit_idx;
        begin
            byte_o = '0;
            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                spi_wait_half_period();
                tb_spi_sclk_drive = 1'b1;
                spi_wait_half_period();
                byte_o[bit_idx] = gpio_1_d31;
                tb_spi_sclk_drive = 1'b0;
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
            tb_spi_sclk_drive = 1'b0;
            tb_spi_cs_n_drive = 1'b0;
            repeat (4) @(posedge tb_clk_drive);
        end
    endtask

    task automatic spi_end_transaction;
        begin
            repeat (4) @(posedge tb_clk_drive);
            tb_spi_sclk_drive = 1'b0;
            tb_spi_cs_n_drive = 1'b1;
            repeat (4) @(posedge tb_clk_drive);
        end
    endtask

    task automatic spi_drain_expected_window;
        int pair_idx;
        logic [WORD_W-1:0] left_word;
        logic [WORD_W-1:0] right_word;
        begin
            spi_begin_transaction();
            for (pair_idx = 0; pair_idx < SERIAL_FRAMES_PER_EX; pair_idx = pair_idx + 1) begin
                spi_read_word(left_word);
                spi_read_word(right_word);
                check_decoded_frame(left_word, right_word);
            end
            spi_end_transaction();
        end
    endtask

    assign clock_50   = tb_clk_drive;
    assign reset_n    = ~tb_rst_drive;
    assign gpio_1_d1  = tb_rst_drive;
    assign gpio_1_d5  = tb_capture_leds_drive;
    assign gpio_1_d7  = tb_capture_hex_drive;
    assign gpio_1_d9  = tb_capture_gpio_drive;
    assign gpio_1_d11 = tb_capture_clear_drive;
    assign gpio_1_d13 = tb_dbg_stage1_drive;
    assign gpio_1_d15 = tb_dbg_stage0_drive;
    assign gpio_1_d17 = tb_dbg_page1_drive;
    assign gpio_1_d19 = tb_dbg_page0_drive;
    assign gpio_1_d27 = tb_spi_sclk_drive;
    assign gpio_1_d29 = tb_spi_cs_n_drive;

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

    always @(dut.tx_spi_miso_o or gpio_1_d31 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d31 === dut.tx_spi_miso_o)
            else $fatal(1, "GPIO_1_D31 nao reflete tx_spi_miso_o. pin=%0b dut=%0b", gpio_1_d31, dut.tx_spi_miso_o);
        end
    end

    always @(dut.tx_spi_window_ready_o or gpio_1_d25 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d25 === dut.tx_spi_window_ready_o)
            else $fatal(1, "GPIO_1_D25 nao reflete tx_spi_window_ready_o. pin=%0b dut=%0b", gpio_1_d25, dut.tx_spi_window_ready_o);
        end
    end

    always @(dut.tx_spi_window_ready_o or gpio_1_d21 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d21 === dut.tx_spi_window_ready_o)
            else $fatal(1,
                        "GPIO_1_D21 nao reflete tx_spi_window_ready_o. pin=%0b dut=%0b",
                        gpio_1_d21,
                        dut.tx_spi_window_ready_o);
        end
    end

    always @(dut.tx_overflow_o or gpio_1_d23 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d23 === dut.tx_overflow_o)
            else $fatal(1,
                        "GPIO_1_D23 nao reflete tx_overflow_o. pin=%0b dut=%0b",
                        gpio_1_d23,
                        dut.tx_overflow_o);
        end
    end

    always @(dut.tx_spi_window_ready_o or gpio_1_d30 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d30 === dut.tx_spi_window_ready_o)
            else $fatal(1,
                        "GPIO_1_D30 nao reflete tx_spi_window_ready_o. pin=%0b dut=%0b",
                        gpio_1_d30,
                        dut.tx_spi_window_ready_o);
        end
    end

    always @(dut.tx_overflow_o or gpio_1_d32 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d32 === dut.tx_overflow_o)
            else $fatal(1,
                        "GPIO_1_D32 nao reflete tx_overflow_o. pin=%0b dut=%0b",
                        gpio_1_d32,
                        dut.tx_overflow_o);
        end
    end

    always @(dut.tx_spi_miso_o or gpio_1_d34 or tb_rst_drive) begin
        if (!tb_rst_drive) begin
            assert (gpio_1_d34 === dut.tx_spi_miso_o)
            else $fatal(1,
                        "GPIO_1_D34 nao reflete tx_spi_miso_o. pin=%0b dut=%0b",
                        gpio_1_d34,
                        dut.tx_spi_miso_o);
        end
    end

    always @(posedge dut.u_aces.u_audio_to_fft_pipeline.sample_valid_24 or posedge tb_rst_drive) begin
        if (tb_rst_drive) begin
            sample24_count_r       <= 0;
            extra_sample24_count_r <= 0;
        end else if (example_in_progress_r) begin
            if (REAL_FLOW && (sample24_count_r < N_POINTS)) begin
                if (dump_files_open_r) begin
                    $fdisplay(dump_sample24_fd_r,
                              "%0d,%0d,%0d,%0d,%0d,%0d,%0d,1",
                              sample24_count_r,
                              dut.stim_current_point_o,
                              dut.stim_rom_addr_dbg_o,
                              dut.stim_state_dbg_o,
                              $signed(dut.stim_current_sample_dbg_o),
                              $signed(dut.sample_24_dbg_o),
                              expected_sample24_mem[flat_sample_idx(active_example_r, sample24_count_r)]);
                end

                if (sample24_count_r < 8)
                    $display("[%0t] sample24 idx=%0d got=%0d exp=%0d stim_point=%0d stim_sample=%0d",
                             $time,
                             sample24_count_r,
                             $signed(dut.sample_24_dbg_o),
                             expected_sample24_mem[flat_sample_idx(active_example_r, sample24_count_r)],
                             dut.stim_current_point_o,
                             $signed(dut.stim_current_sample_dbg_o));

                assert ($signed(dut.sample_24_dbg_o) == expected_sample24_mem[flat_sample_idx(active_example_r, sample24_count_r)])
                else $fatal(1,
                            "sample_24 mismatch exemplo=%0d idx=%0d exp=%0d got=%0d stim_point=%0d stim_sample=%0d stim_state=%0d bit_index=%0d ws=%0b sck=%0b sd=%0b",
                            active_example_r, sample24_count_r,
                            expected_sample24_mem[flat_sample_idx(active_example_r, sample24_count_r)],
                            $signed(dut.sample_24_dbg_o),
                            dut.stim_current_point_o,
                            $signed(dut.stim_current_sample_dbg_o),
                            dut.stim_state_dbg_o,
                            dut.stim_bit_index_o,
                            dut.i2s_ws_o,
                            dut.i2s_sck_o,
                            dut.stim_sd_o);
                sample24_count_r <= sample24_count_r + 1;
            end else if (REAL_FLOW) begin
                if (dump_files_open_r) begin
                    $fdisplay(dump_sample24_fd_r,
                              "%0d,%0d,%0d,%0d,%0d,%0d,%0d,0",
                              sample24_count_r + extra_sample24_count_r,
                              dut.stim_current_point_o,
                              dut.stim_rom_addr_dbg_o,
                              dut.stim_state_dbg_o,
                              $signed(dut.stim_current_sample_dbg_o),
                              $signed(dut.sample_24_dbg_o),
                              0);
                end
                extra_sample24_count_r <= extra_sample24_count_r + 1;
            end
        end
    end

    always @(posedge tb_clk_drive or posedge tb_rst_drive) begin
        int hold_idx;
        logic signed [I2S_SAMPLE_W-1:0] bfpexp_payload;
        real corrected_real_r;
        real corrected_imag_r;
        real expected_real_r;
        real expected_imag_r;
        real abs_err_r;

        if (tb_rst_drive) begin
            sample18_count_r             <= 0;
            extra_sample18_count_r       <= 0;
            fft_bin_count_r              <= 0;
            extra_fft_bin_count_r        <= 0;
            serial_expected_write_idx_r  <= 0;
            serial_expected_read_idx_r   <= 0;
            serial_frames_seen_r         <= 0;
            extra_serial_frames_r        <= 0;
            fft_run_count_r              <= 0;
            frame_bfpexp_valid_r         <= 1'b0;
            serial_bfpexp_enqueued_r     <= 1'b0;
            stim_done_seen_r             <= 1'b0;
            fft_done_seen_r              <= 1'b0;
            tx_overflow_seen_r           <= 1'b0;
            fft_frame_done_r             <= 1'b0;
            sact_prev_r                  <= 1'b0;
            fft_run_seen_r               <= 1'b0;
            fft_ingest_gate_pending_r    <= 1'b0;
            release_fft_ingest_gate();
        end else begin
            if (dut.fft_run_o) begin
                fft_run_seen_r <= 1'b1;
                fft_run_count_r <= fft_run_count_r + 1;

                if (!fft_ingest_gated_r && !fft_ingest_gate_pending_r && (fft_run_count_r == 1))
                    fft_ingest_gate_pending_r <= 1'b1;
            end

            if (dut.stim_done_o)
                stim_done_seen_r <= 1'b1;

            if (dut.fft_done_o)
                fft_done_seen_r <= 1'b1;

            if (dut.tx_overflow_o) begin
                tx_overflow_seen_r <= 1'b1;
                $display("[%0t] tx_overflow debug: bridge_level=%0d adapter_level=%0d complete_windows=%0d spi_active=%0b serial_rd=%0d serial_wr=%0d fft_bins=%0d extra_fft=%0d",
                         $time,
                         dut.u_aces.u_spi_fft_tx_adapter.fifo_level_o,
                         dut.u_aces.u_spi_fft_tx_adapter.fifo_level_o,
                         dut.u_aces.u_spi_fft_tx_adapter.complete_windows_r,
                         dut.u_aces.u_spi_fft_tx_adapter.spi_active_o,
                         serial_expected_read_idx_r,
                         serial_expected_write_idx_r,
                         fft_bin_count_r,
                         extra_fft_bin_count_r);
                $fatal(1, "tx_overflow_o nao deveria ativar durante o top-level test.");
            end

            if (example_in_progress_r && dut.sact_istream_o && !sact_prev_r) begin
                if (REAL_FLOW && (sample18_count_r < N_POINTS)) begin
                    if (dump_files_open_r) begin
                        $fdisplay(dump_fft_input_fd_r,
                                  "%0d,%0d,%0d,%0d,%0d,%0b,%0d,1",
                                  sample18_count_r,
                                  $signed(dut.sample_mic_o),
                                  expected_sample18_mem[flat_sample_idx(active_example_r, sample18_count_r)],
                                  $signed(dut.sdw_istream_real_o),
                                  $signed(dut.sdw_istream_imag_o),
                                  dut.fft_run_o,
                                  dut.fft_status_o);
                    end

                    assert ($signed(dut.sample_mic_o) == expected_sample18_mem[flat_sample_idx(active_example_r, sample18_count_r)])
                    else $fatal(1, "sample_mic mismatch exemplo=%0d idx=%0d exp=%0d got=%0d",
                                active_example_r, sample18_count_r,
                                expected_sample18_mem[flat_sample_idx(active_example_r, sample18_count_r)],
                                $signed(dut.sample_mic_o));

                    assert ($signed(dut.sdw_istream_real_o) == expected_sample18_mem[flat_sample_idx(active_example_r, sample18_count_r)])
                    else $fatal(1, "sdw_istream_real mismatch exemplo=%0d idx=%0d exp=%0d got=%0d",
                                active_example_r, sample18_count_r,
                                expected_sample18_mem[flat_sample_idx(active_example_r, sample18_count_r)],
                                $signed(dut.sdw_istream_real_o));

                    assert ($signed(dut.sdw_istream_imag_o) == 0)
                    else $fatal(1, "sdw_istream_imag deveria ser zero. got=%0d", $signed(dut.sdw_istream_imag_o));

                    sample18_count_r <= sample18_count_r + 1;
                end else if (REAL_FLOW) begin
                    if (dump_files_open_r) begin
                        $fdisplay(dump_fft_input_fd_r,
                                  "%0d,%0d,%0d,%0d,%0d,%0b,%0d,0",
                                  sample18_count_r,
                                  $signed(dut.sample_mic_o),
                                  0,
                                  $signed(dut.sdw_istream_real_o),
                                  $signed(dut.sdw_istream_imag_o),
                                  dut.fft_run_o,
                                  dut.fft_status_o);
                    end

                    extra_sample18_count_r <= extra_sample18_count_r + 1;
                    sample18_count_r       <= sample18_count_r + 1;
                end else begin
                    sample18_count_r <= sample18_count_r + 1;
                end
            end

            if (fft_ingest_gate_pending_r && !fft_ingest_gated_r) begin
                gate_fft_ingest_after_window();
                fft_ingest_gate_pending_r <= 1'b0;
            end

            sact_prev_r <= dut.sact_istream_o;

            if (example_in_progress_r && dut.fft_tx_valid_o) begin
                if (fft_bin_count_r < FFT_LENGTH) begin
                    assert (dut.fft_tx_index_o == fft_bin_count_r[FFT_N-1:0])
                    else $fatal(1, "fft_tx_index_o mismatch exemplo=%0d exp=%0d got=%0d",
                                active_example_r, fft_bin_count_r, dut.fft_tx_index_o);

                    if (!frame_bfpexp_valid_r) begin
                        frame_bfpexp_r       <= dut.bfpexp_o;
                        frame_bfpexp_valid_r <= 1'b1;
                    end else begin
                        assert (dut.bfpexp_o == frame_bfpexp_r)
                        else $fatal(1, "bfpexp mudou durante a janela FFT. exp=%0d got=%0d",
                                    frame_bfpexp_r, dut.bfpexp_o);
                    end

                    corrected_real_r = apply_bfpexp(dut.fft_tx_real_o, dut.bfpexp_o);
                    corrected_imag_r = apply_bfpexp(dut.fft_tx_imag_o, dut.bfpexp_o);
                    expected_real_r   = expected_fft_real_mem[flat_fft_idx(active_example_r, fft_bin_count_r)];
                    expected_imag_r   = expected_fft_imag_mem[flat_fft_idx(active_example_r, fft_bin_count_r)];
                    abs_err_r         = $sqrt(((corrected_real_r - expected_real_r) * (corrected_real_r - expected_real_r)) +
                                              ((corrected_imag_r - expected_imag_r) * (corrected_imag_r - expected_imag_r)));
                    measured_fft_real_mem[fft_bin_count_r] = corrected_real_r;
                    measured_fft_imag_mem[fft_bin_count_r] = corrected_imag_r;

                    if (dump_files_open_r) begin
                        $fdisplay(dump_fft_output_fd_r,
                                  "%0d,%0d,%0d,%0d,%0d,%0f,%0f,%0f,%0f,%0f,%0b,1",
                                  fft_bin_count_r,
                                  dut.fft_tx_index_o,
                                  $signed(dut.fft_tx_real_o),
                                  $signed(dut.fft_tx_imag_o),
                                  $signed(dut.bfpexp_o),
                                  corrected_real_r,
                                  corrected_imag_r,
                                  expected_real_r,
                                  expected_imag_r,
                                  abs_err_r,
                                  dut.fft_tx_last_o);
                    end

                    if (!REAL_FLOW) begin
                        assert ($signed(dut.fft_tx_real_o) == (fft_bin_count_r + 1))
                        else $fatal(1, "Mock FFT real mismatch idx=%0d exp=%0d got=%0d",
                                    fft_bin_count_r, fft_bin_count_r + 1, $signed(dut.fft_tx_real_o));

                        assert ($signed(dut.fft_tx_imag_o) == expected_mock_imag(fft_bin_count_r))
                        else $fatal(1, "Mock FFT imag mismatch idx=%0d exp=%0d got=%0d",
                                    fft_bin_count_r, expected_mock_imag(fft_bin_count_r), $signed(dut.fft_tx_imag_o));
                    end

                    assert (dut.fft_tx_last_o == (fft_bin_count_r == FFT_LENGTH-1))
                    else $fatal(1, "fft_tx_last_o mismatch idx=%0d got=%0b",
                                fft_bin_count_r, dut.fft_tx_last_o);

                    fft_bin_count_r <= fft_bin_count_r + 1;

                    if (fft_bin_count_r == FFT_LENGTH-1)
                        fft_frame_done_r <= 1'b1;
                end else if (REAL_FLOW) begin
                    if (dump_files_open_r) begin
                        $fdisplay(dump_fft_output_fd_r,
                                  "%0d,%0d,%0d,%0d,%0d,%0f,%0f,%0f,%0f,%0f,%0b,0",
                                  fft_bin_count_r + extra_fft_bin_count_r,
                                  dut.fft_tx_index_o,
                                  $signed(dut.fft_tx_real_o),
                                  $signed(dut.fft_tx_imag_o),
                                  $signed(dut.bfpexp_o),
                                  apply_bfpexp(dut.fft_tx_real_o, dut.bfpexp_o),
                                  apply_bfpexp(dut.fft_tx_imag_o, dut.bfpexp_o),
                                  0.0,
                                  0.0,
                                  0.0,
                                  dut.fft_tx_last_o);
                    end
                    extra_fft_bin_count_r <= extra_fft_bin_count_r + 1;
                end
            end
        end
    end

    always @(posedge tb_clk_drive or posedge tb_rst_drive) begin
        logic signed [I2S_SAMPLE_W-1:0] bfpexp_payload;
        int hold_idx;
        begin
            if (tb_rst_drive) begin
                // Nada a fazer: o estado do scoreboard e resetado por
                // reset_example_scoreboard/apply_reset_sequence.
            end else if (example_in_progress_r && dut.fft_tx_valid_o && dut.u_aces.u_spi_fft_tx_adapter.fft_ready_o) begin
                if (!serial_bfpexp_enqueued_r) begin
                    bfpexp_payload = extend_bfpexp_payload(dut.bfpexp_o);
                    for (hold_idx = 0; hold_idx < BFPEXP_HOLD_FRAMES; hold_idx++)
                        enqueue_expected_frame(TAG_BFPEXP_C, bfpexp_payload, bfpexp_payload);
                    serial_bfpexp_enqueued_r <= 1'b1;
                end

                if (serial_expected_write_idx_r < SERIAL_FRAMES_PER_EX)
                    enqueue_expected_frame(TAG_FFT_C, dut.fft_tx_real_o, dut.fft_tx_imag_o);
            end
        end
    end

    always @(posedge gpio_1_d25) begin
        if (!tb_rst_drive && example_in_progress_r)
            spi_drain_expected_window();
    end

    initial begin
        int first_example_idx;
        int last_example_idx;
        int selected_example_idx;
        bit selected_example_valid;

        key0 = 1'b1; key1 = 1'b1; key2 = 1'b1; key3 = 1'b1;
        sw0 = 1'b0; sw1 = 1'b0; sw2 = 1'b0; sw3 = 1'b0; sw4 = 1'b0; sw5 = 1'b0; sw6 = 1'b0; sw7 = 1'b1; sw8 = 1'b0; sw9 = 1'b0;
        clock2_50 = 1'b0; clock3_50 = 1'b0; clock4_50 = 1'b0;

        tb_clk_drive           = 1'b0;
        tb_rst_drive           = 1'b1;
        tb_capture_leds_drive  = 1'b0;
        tb_capture_hex_drive   = 1'b0;
        tb_capture_gpio_drive  = 1'b0;
        tb_capture_clear_drive = 1'b0;
        tb_dbg_stage0_drive    = 1'b0;
        tb_dbg_stage1_drive    = 1'b0;
        tb_dbg_page0_drive     = 1'b0;
        tb_dbg_page1_drive     = 1'b0;

        active_example_r            = 0;
        example_in_progress_r       = 1'b0;
        sample24_count_r            = 0;
        sample18_count_r            = 0;
        extra_sample24_count_r      = 0;
        extra_sample18_count_r      = 0;
        fft_bin_count_r             = 0;
        extra_fft_bin_count_r       = 0;
        serial_expected_write_idx_r = 0;
        serial_expected_read_idx_r  = 0;
        serial_frames_seen_r        = 0;
        extra_serial_frames_r       = 0;
        fft_run_count_r             = 0;
        frame_bfpexp_r              = '0;
        frame_bfpexp_valid_r        = 1'b0;
        serial_bfpexp_enqueued_r    = 1'b0;
        stim_done_seen_r            = 1'b0;
        fft_done_seen_r             = 1'b0;
        tx_overflow_seen_r          = 1'b0;
        fft_frame_done_r            = 1'b0;
        sact_prev_r                 = 1'b0;
        fft_ingest_gated_r          = 1'b0;
        fft_ingest_gate_pending_r   = 1'b0;
        tb_spi_sclk_drive           = 1'b0;
        tb_spi_cs_n_drive           = 1'b1;
        dump_sample24_fd_r          = 0;
        dump_fft_input_fd_r         = 0;
        dump_fft_output_fd_r        = 0;
        dump_tx_frames_fd_r         = 0;
        dump_files_open_r           = 1'b0;

`ifdef TB_TOP_LEVEL_REAL_FLOW
        load_expected_samples();
        load_expected_fft();
`endif

        selected_example_valid = $value$plusargs("TOP_LEVEL_TEST_EXAMPLE=%d", selected_example_idx);
        if (selected_example_valid) begin
            assert ((selected_example_idx >= 0) && (selected_example_idx < N_EXAMPLES))
            else $fatal(1, "TOP_LEVEL_TEST_EXAMPLE fora da faixa: %0d", selected_example_idx);
            first_example_idx = selected_example_idx;
            last_example_idx  = selected_example_idx;
            $display("tb_top_level_test: executando somente o exemplo %0d via plusarg", selected_example_idx);
        end else begin
            first_example_idx = 0;
            last_example_idx  = EXAMPLES_TO_RUN - 1;
        end

        repeat (8) @(posedge tb_clk_drive);
        tb_rst_drive = 1'b0;
        repeat (8) @(posedge tb_clk_drive);

        for (int example_idx = first_example_idx; example_idx <= last_example_idx; example_idx++) begin
            run_example_and_check(example_idx);
            wait (dut.stim_ready_o == 1'b1);
            repeat (16) @(posedge tb_clk_drive);
        end

`ifdef TB_TOP_LEVEL_REAL_FLOW
        $display("tb_top_level_test PASSED no fluxo real com exemplos [%0d:%0d] e comparacao FFT vs Python",
                 first_example_idx, last_example_idx);
`else
        $display("tb_top_level_test PASSED no fluxo mock com smoke/protocolo do stream TX");
`endif
        close_diag_files();
        $finish;
    end

endmodule
