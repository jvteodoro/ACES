`timescale 1ns/1ps

module tb_top_level_fft_isolated;

    localparam int FFT_LENGTH           = 512;
    localparam int FFT_DW               = 18;
    localparam int N_POINTS             = 512;
    localparam int N_EXAMPLES           = 8;
    localparam int I2S_CLOCK_DIV        = 4;
    localparam int FFT_N                = $clog2(FFT_LENGTH);
    localparam int TOTAL_SAMPLES        = N_EXAMPLES * N_POINTS;
    localparam int TOTAL_BINS           = N_EXAMPLES * FFT_LENGTH;
    localparam int FRAME0_IDX           = 0;
    localparam int FRAME1_IDX           = 1;
    localparam int INPUT_GAP_CYCLES     = 2;
    localparam int MANUAL_DMA_WAIT      = 2;
    localparam int MAX_RUN_WAIT_CYCLES  = 128;
    localparam int MAX_DONE_WAIT_CYCLES = 200_000;
    localparam int MAX_TX_WAIT_CYCLES   = 200_000;
    localparam int BFPEXP_W             = 8;
    localparam time CLK_HALF            = 5ns;
    localparam real FFT_MAX_ABS_ERR_TOL = 100_000.0;
    localparam real FFT_RMSE_ERR_TOL    = 12_000.0;

    localparam int FFT_IBUF_IDLE_C        = 2'd0;
    localparam int FFT_IBUF_INPUT_C       = 2'd1;
    localparam int FFT_IBUF_FULL_C        = 2'd2;
    localparam int FFT_STATUS_IDLE_C      = 3'd0;
    localparam int FFT_STATUS_RUN_C       = 3'd3;
    localparam int FFT_STATUS_DONE_C      = 3'd4;
    localparam int CTRL_IDLE_C            = 2'd0;
    localparam int CTRL_ISTREAM_C         = 2'd1;
    localparam int CTRL_FULL_C            = 2'd2;
    localparam int SB_DONE_C              = 5;
    localparam int TRIBUF_PHASE_0_C       = 0;
    localparam int TRIBUF_PHASE_1_C       = 1;
    localparam int TRIBUF_PHASE_2_C       = 2;

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

    logic forced_sact_r;
    logic signed [FFT_DW-1:0] forced_real_r;
    logic signed [FFT_DW-1:0] forced_imag_r;
    logic manual_dmaact_r;
    logic [FFT_N-1:0] manual_dmaa_r;

    int expected_sample18_mem [0:TOTAL_SAMPLES-1];
    real expected_fft_real_mem [0:TOTAL_BINS-1];
    real expected_fft_imag_mem [0:TOTAL_BINS-1];

    real auto_fft_real_mem [0:FFT_LENGTH-1];
    real auto_fft_imag_mem [0:FFT_LENGTH-1];
    real manual_fft_real_mem [0:FFT_LENGTH-1];
    real manual_fft_imag_mem [0:FFT_LENGTH-1];

    int input_sample_count_r;
    int auto_fft_bin_count_r;
    int run_rise_count_r;
    int done_rise_count_r;
    int dma_auto_burst_count_r;
    int dma_auto_burst_len_r;
    int dma_auto_max_burst_len_r;
    int fft_stage_max_r;
    int observed_tribuf_phase_r;

    bit run_seen_r;
    bit done_seen_r;
    bit input_buffer_full_seen_r;
    bit fft_status_run_seen_r;
    bit fft_status_done_seen_r;
    bit sb_done_seen_r;
    bit manual_dma_override_active_r;

    logic fft_run_prev_r;
    logic fft_done_prev_r;
    logic dmaact_prev_r;

    function automatic int flat_sample_idx(input int example_idx, input int sample_idx);
        flat_sample_idx = example_idx * N_POINTS + sample_idx;
    endfunction

    function automatic int flat_fft_idx(input int example_idx, input int bin_idx);
        flat_fft_idx = example_idx * FFT_LENGTH + bin_idx;
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
                for (shift_i = 0; shift_i < bfpexp_i; shift_i = shift_i + 1)
                    value_r = value_r * 2.0;
            end else begin
                for (shift_i = 0; shift_i < -bfpexp_i; shift_i = shift_i + 1)
                    value_r = value_r / 2.0;
            end
            apply_bfpexp = value_r;
        end
    endfunction

    task automatic apply_reset_sequence;
        begin
            tb_rst_drive = 1'b1;
            repeat (8) @(posedge tb_clk_drive);
            tb_rst_drive = 1'b0;
            repeat (8) @(posedge tb_clk_drive);
        end
    endtask

    task automatic load_expected_samples;
        string path_s;
        string header_s;
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
                    expected_sample18_mem[flat_sample_idx(ex_idx, sample_idx)] = sample18_i;
                    scan_count = scan_count + 1;
                end else begin
                    void'($fgets(header_s, fd_i));
                end
            end

            $fclose(fd_i);

            assert (scan_count == TOTAL_SAMPLES)
            else $fatal(1, "Arquivo de samples esperado incompleto. exp=%0d got=%0d", TOTAL_SAMPLES, scan_count);
        end
    endtask

    task automatic load_expected_fft;
        string path_s;
        string header_s;
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
            else $fatal(1, "Arquivo de FFT esperado incompleto. exp=%0d got=%0d", TOTAL_BINS, scan_count);
        end
    endtask

    task automatic force_fft_stream_inputs;
        begin
            force dut.u_aces.sact_istream_o = forced_sact_r;
            force dut.u_aces.sdw_istream_real_o = forced_real_r;
            force dut.u_aces.sdw_istream_imag_o = forced_imag_r;
            force dut.u_aces.u_fft_control.sact_istream_i = forced_sact_r;
            force dut.u_aces.u_r2fft_tribuf_impl.sact_istream_i = forced_sact_r;
            force dut.u_aces.u_r2fft_tribuf_impl.sdw_istream_real_i = forced_real_r;
            force dut.u_aces.u_r2fft_tribuf_impl.sdw_istream_imag_i = forced_imag_r;
        end
    endtask

    task automatic force_manual_dma_inputs;
        begin
            force dut.u_aces.dmaact_i = manual_dmaact_r;
            force dut.u_aces.dmaa_i = manual_dmaa_r;
            manual_dma_override_active_r = 1'b1;
        end
    endtask

    task automatic release_manual_dma_inputs;
        begin
            release dut.u_aces.dmaact_i;
            release dut.u_aces.dmaa_i;
            manual_dma_override_active_r = 1'b0;
        end
    endtask

    task automatic reset_scoreboard;
        int idx;
        begin
            input_sample_count_r        = 0;
            auto_fft_bin_count_r        = 0;
            run_rise_count_r            = 0;
            done_rise_count_r           = 0;
            dma_auto_burst_count_r      = 0;
            dma_auto_burst_len_r        = 0;
            dma_auto_max_burst_len_r    = 0;
            fft_stage_max_r             = 0;
            observed_tribuf_phase_r     = TRIBUF_PHASE_0_C;
            run_seen_r                  = 1'b0;
            done_seen_r                 = 1'b0;
            input_buffer_full_seen_r    = 1'b0;
            fft_status_run_seen_r       = 1'b0;
            fft_status_done_seen_r      = 1'b0;
            sb_done_seen_r              = 1'b0;
            fft_run_prev_r              = 1'b0;
            fft_done_prev_r             = 1'b0;
            dmaact_prev_r               = 1'b0;
            manual_dma_override_active_r = 1'b0;

            forced_sact_r = 1'b0;
            forced_real_r = '0;
            forced_imag_r = '0;
            manual_dmaact_r = 1'b0;
            manual_dmaa_r = '0;

            for (idx = 0; idx < FFT_LENGTH; idx = idx + 1) begin
                auto_fft_real_mem[idx] = 0.0;
                auto_fft_imag_mem[idx] = 0.0;
                manual_fft_real_mem[idx] = 0.0;
                manual_fft_imag_mem[idx] = 0.0;
            end
        end
    endtask

    task automatic drive_fft_input_sample(
        input int example_idx,
        input int sample_idx
    );
        begin
            forced_real_r = expected_sample18_mem[flat_sample_idx(example_idx, sample_idx)];
            forced_imag_r = '0;
            forced_sact_r = 1'b1;
            @(posedge tb_clk_drive);
            forced_sact_r = 1'b0;
            repeat (INPUT_GAP_CYCLES) @(posedge tb_clk_drive);
        end
    endtask

    task automatic feed_fft_frame(input int example_idx);
        int sample_idx;
        begin
            for (sample_idx = 0; sample_idx < N_POINTS; sample_idx = sample_idx + 1)
                drive_fft_input_sample(example_idx, sample_idx);
        end
    endtask

    task automatic wait_for_run_count(input int target_run_count);
        int timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((timeout_cycles < MAX_RUN_WAIT_CYCLES) && (run_rise_count_r < target_run_count)) begin
                @(posedge tb_clk_drive);
                timeout_cycles = timeout_cycles + 1;
            end

            assert (run_rise_count_r >= target_run_count)
            else $fatal(1,
                        "FFT control nao gerou run esperado. target=%0d got=%0d ctrl_state=%0d ibuf_status=%0d fft_status=%0d ptr=%0d countFull=%0b sact_i=%0b sact_reg=%0b",
                        target_run_count,
                        run_rise_count_r,
                        dut.u_aces.u_fft_control.state,
                        dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.ibuf_status_f,
                        dut.u_aces.u_r2fft_tribuf_impl.status_o,
                        dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.ubitReverseCounter.ptr_f,
                        dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.ubitReverseCounter.countFull,
                        dut.u_aces.u_r2fft_tribuf_impl.sact_istream_i,
                        dut.u_aces.u_r2fft_tribuf_impl.sact_istream);
        end
    endtask

    task automatic wait_for_done_count(input int target_done_count);
        int timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((timeout_cycles < MAX_DONE_WAIT_CYCLES) && (done_rise_count_r < target_done_count)) begin
                @(posedge tb_clk_drive);
                timeout_cycles = timeout_cycles + 1;
            end

            assert (done_rise_count_r >= target_done_count)
            else $fatal(1, "FFT nao concluiu processamento dentro do timeout. target=%0d got=%0d",
                        target_done_count, done_rise_count_r);
        end
    endtask

    task automatic wait_for_auto_dma_capture;
        int timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((timeout_cycles < MAX_TX_WAIT_CYCLES) && (auto_fft_bin_count_r < FFT_LENGTH)) begin
                @(posedge tb_clk_drive);
                timeout_cycles = timeout_cycles + 1;
            end

            assert (auto_fft_bin_count_r == FFT_LENGTH)
            else $fatal(1, "Leitor DMA integrado nao entregou %0d bins. got=%0d",
                        FFT_LENGTH, auto_fft_bin_count_r);
        end
    endtask

    task automatic manual_dma_dump;
        int bin_idx;
        begin
            force_manual_dma_inputs();
            manual_dmaact_r = 1'b0;
            manual_dmaa_r = '0;
            @(posedge tb_clk_drive);

            for (bin_idx = 0; bin_idx < FFT_LENGTH; bin_idx = bin_idx + 1) begin
                manual_dmaa_r = bin_idx[FFT_N-1:0];
                manual_dmaact_r = 1'b1;
                @(posedge tb_clk_drive);
                manual_dmaact_r = 1'b0;
                repeat (MANUAL_DMA_WAIT) @(posedge tb_clk_drive);
                @(posedge tb_clk_drive);

                manual_fft_real_mem[bin_idx] = apply_bfpexp(dut.u_aces.dmadr_real_o, dut.bfpexp_o);
                manual_fft_imag_mem[bin_idx] = apply_bfpexp(dut.u_aces.dmadr_imag_o, dut.bfpexp_o);
            end

            manual_dmaact_r = 1'b0;
            release_manual_dma_inputs();
            @(posedge tb_clk_drive);
        end
    endtask

    task automatic compute_fft_metrics(
        input bit use_manual_i,
        input int example_idx,
        output real rmse_r,
        output real max_abs_err_r
    );
        int bin_idx;
        real diff_real_r;
        real diff_imag_r;
        real abs_err_r;
        real mse_r;
        real actual_real_r;
        real actual_imag_r;
        begin
            mse_r = 0.0;
            max_abs_err_r = 0.0;

            for (bin_idx = 0; bin_idx < FFT_LENGTH; bin_idx = bin_idx + 1) begin
                actual_real_r = use_manual_i ? manual_fft_real_mem[bin_idx] : auto_fft_real_mem[bin_idx];
                actual_imag_r = use_manual_i ? manual_fft_imag_mem[bin_idx] : auto_fft_imag_mem[bin_idx];

                diff_real_r = actual_real_r - expected_fft_real_mem[flat_fft_idx(example_idx, bin_idx)];
                diff_imag_r = actual_imag_r - expected_fft_imag_mem[flat_fft_idx(example_idx, bin_idx)];

                abs_err_r = $sqrt((diff_real_r * diff_real_r) + (diff_imag_r * diff_imag_r));
                mse_r = mse_r + (abs_err_r * abs_err_r);

                if (abs_err_r > max_abs_err_r)
                    max_abs_err_r = abs_err_r;
            end

            rmse_r = $sqrt(mse_r / $itor(FFT_LENGTH));
        end
    endtask

    task automatic display_fft_preview(
        input bit use_manual_i,
        input int example_idx
    );
        int bin_idx;
        begin
            for (bin_idx = 0; bin_idx < 8; bin_idx = bin_idx + 1) begin
                $display("  %s bin %0d: measured=(%0f,%0f) expected=(%0f,%0f)",
                         use_manual_i ? "manual" : "auto",
                         bin_idx,
                         use_manual_i ? manual_fft_real_mem[bin_idx] : auto_fft_real_mem[bin_idx],
                         use_manual_i ? manual_fft_imag_mem[bin_idx] : auto_fft_imag_mem[bin_idx],
                         expected_fft_real_mem[flat_fft_idx(example_idx, bin_idx)],
                         expected_fft_imag_mem[flat_fft_idx(example_idx, bin_idx)]);
            end
        end
    endtask

    task automatic compare_auto_vs_manual;
        int bin_idx;
        real diff_real_r;
        real diff_imag_r;
        real max_abs_err_r;
        real abs_err_r;
        begin
            max_abs_err_r = 0.0;
            for (bin_idx = 0; bin_idx < FFT_LENGTH; bin_idx = bin_idx + 1) begin
                diff_real_r = auto_fft_real_mem[bin_idx] - manual_fft_real_mem[bin_idx];
                diff_imag_r = auto_fft_imag_mem[bin_idx] - manual_fft_imag_mem[bin_idx];
                abs_err_r = $sqrt((diff_real_r * diff_real_r) + (diff_imag_r * diff_imag_r));
                if (abs_err_r > max_abs_err_r)
                    max_abs_err_r = abs_err_r;
            end

            $display("[%0t] top_level_fft_isolated: max_abs(auto-manual)=%0f", $time, max_abs_err_r);
        end
    endtask

    property p_fft_run_single_cycle;
        @(posedge tb_clk_drive) disable iff (tb_rst_drive)
            dut.fft_run_o |=> !dut.fft_run_o;
    endproperty

    property p_fft_run_requires_full_buffer;
        @(posedge tb_clk_drive) disable iff (tb_rst_drive)
            $rose(dut.fft_run_o) |-> ($past(dut.fft_input_buffer_status_o) == FFT_IBUF_FULL_C ||
                                      dut.fft_input_buffer_status_o == FFT_IBUF_FULL_C);
    endproperty

    property p_fft_done_after_run;
        @(posedge tb_clk_drive) disable iff (tb_rst_drive)
            $rose(dut.fft_run_o) |-> ##[1:MAX_DONE_WAIT_CYCLES] dut.fft_done_o;
    endproperty

    property p_fft_status_done_matches_done;
        @(posedge tb_clk_drive) disable iff (tb_rst_drive)
            dut.fft_done_o |-> dut.fft_status_o == FFT_STATUS_DONE_C;
    endproperty

    assert property (p_fft_run_single_cycle)
    else $fatal(1, "fft_run_o deveria ser pulso de 1 ciclo.");

    assert property (p_fft_run_requires_full_buffer)
    else $fatal(1, "fft_run_o ocorreu sem buffer de entrada cheio.");

    assert property (p_fft_done_after_run)
    else $fatal(1, "fft_done_o nao ocorreu apos fft_run_o.");

    assert property (p_fft_status_done_matches_done)
    else $fatal(1, "fft_done_o ativo com fft_status_o diferente de DONE.");

    assign clock_50   = tb_clk_drive;
    assign gpio_0_d0  = tb_clk_drive;
    assign gpio_0_d1  = tb_rst_drive;
    assign gpio_0_d2  = tb_capture_leds_drive;
    assign gpio_0_d4  = tb_capture_hex_drive;
    assign gpio_0_d5  = tb_capture_gpio_drive;
    assign gpio_0_d6  = tb_capture_clear_drive;
    assign gpio_0_d7  = tb_dbg_stage0_drive;
    assign gpio_0_d8  = tb_dbg_stage1_drive;
    assign gpio_0_d9  = tb_dbg_page0_drive;
    assign gpio_0_d10 = tb_dbg_page1_drive;

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

    always @(posedge tb_clk_drive or posedge tb_rst_drive) begin
        if (tb_rst_drive) begin
            fft_run_prev_r           <= 1'b0;
            fft_done_prev_r          <= 1'b0;
            dmaact_prev_r            <= 1'b0;
            dma_auto_burst_len_r     <= 0;
            dma_auto_max_burst_len_r <= 0;
        end else begin
            if (dut.fft_input_buffer_status_o == FFT_IBUF_FULL_C)
                input_buffer_full_seen_r <= 1'b1;

            if (dut.fft_status_o == FFT_STATUS_RUN_C)
                fft_status_run_seen_r <= 1'b1;

            if (dut.fft_status_o == FFT_STATUS_DONE_C)
                fft_status_done_seen_r <= 1'b1;

            if (dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.sb_state_f == SB_DONE_C)
                sb_done_seen_r <= 1'b1;

            if (dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.fftStageCount > fft_stage_max_r)
                fft_stage_max_r <= dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.fftStageCount;

            observed_tribuf_phase_r <= dut.u_aces.u_r2fft_tribuf_impl.uR2FFT_tribuf.tribuf_status;

            if (dut.fft_run_o && !fft_run_prev_r) begin
                run_rise_count_r <= run_rise_count_r + 1;
                run_seen_r <= 1'b1;
                assert (dut.u_aces.u_fft_control.state == CTRL_FULL_C)
                else $fatal(1, "fft_control nao estava no estado FULL ao gerar run.");
            end

            if (dut.fft_done_o && !fft_done_prev_r) begin
                done_rise_count_r <= done_rise_count_r + 1;
                done_seen_r <= 1'b1;
            end

            if (!manual_dma_override_active_r) begin
                if (dut.u_aces.dmaact_i) begin
                    if (!dmaact_prev_r)
                        dma_auto_burst_count_r <= dma_auto_burst_count_r + 1;
                    dma_auto_burst_len_r <= dma_auto_burst_len_r + 1;
                    if ((dma_auto_burst_len_r + 1) > dma_auto_max_burst_len_r)
                        dma_auto_max_burst_len_r <= dma_auto_burst_len_r + 1;
                end else begin
                    dma_auto_burst_len_r <= 0;
                end
            end

            fft_run_prev_r <= dut.fft_run_o;
            fft_done_prev_r <= dut.fft_done_o;
            dmaact_prev_r <= dut.u_aces.dmaact_i;
        end
    end

    always @(posedge dut.u_aces.u_r2fft_tribuf_impl.sact_istream_i or posedge tb_rst_drive) begin
        int example_idx;
        int sample_idx;
        if (tb_rst_drive) begin
            input_sample_count_r <= 0;
        end else begin
            example_idx = (input_sample_count_r < N_POINTS) ? FRAME0_IDX : FRAME1_IDX;
            sample_idx = input_sample_count_r % N_POINTS;

            assert (input_sample_count_r < (2 * N_POINTS))
            else $fatal(1, "Mais de %0d amostras foram injetadas no frame isolado.", 2 * N_POINTS);

            assert ($signed(dut.u_aces.u_r2fft_tribuf_impl.sdw_istream_real_i) ==
                    expected_sample18_mem[flat_sample_idx(example_idx, sample_idx)])
            else $fatal(1, "Amostra FFT mismatch idx=%0d exp=%0d got=%0d",
                        input_sample_count_r,
                        expected_sample18_mem[flat_sample_idx(example_idx, sample_idx)],
                        $signed(dut.u_aces.u_r2fft_tribuf_impl.sdw_istream_real_i));

            assert ($signed(dut.u_aces.u_r2fft_tribuf_impl.sdw_istream_imag_i) == 0)
            else $fatal(1, "Canal imag de entrada deveria ser zero. got=%0d",
                        $signed(dut.u_aces.u_r2fft_tribuf_impl.sdw_istream_imag_i));

            input_sample_count_r <= input_sample_count_r + 1;
        end
    end

    always @(posedge tb_clk_drive) begin
        real corrected_real_r;
        real corrected_imag_r;
        if (!tb_rst_drive && dut.fft_tx_valid_o) begin
            assert (auto_fft_bin_count_r < FFT_LENGTH)
            else $fatal(1, "Mais de %0d bins produzidos pelo caminho integrado.", FFT_LENGTH);

            assert (dut.fft_tx_index_o == auto_fft_bin_count_r[FFT_N-1:0])
            else $fatal(1, "fft_tx_index_o mismatch idx=%0d got=%0d",
                        auto_fft_bin_count_r, dut.fft_tx_index_o);

            corrected_real_r = apply_bfpexp(dut.fft_tx_real_o, dut.bfpexp_o);
            corrected_imag_r = apply_bfpexp(dut.fft_tx_imag_o, dut.bfpexp_o);

            auto_fft_real_mem[auto_fft_bin_count_r] = corrected_real_r;
            auto_fft_imag_mem[auto_fft_bin_count_r] = corrected_imag_r;

            assert (dut.fft_tx_last_o == (auto_fft_bin_count_r == FFT_LENGTH-1))
            else $fatal(1, "fft_tx_last_o mismatch idx=%0d got=%0b",
                        auto_fft_bin_count_r, dut.fft_tx_last_o);

            auto_fft_bin_count_r = auto_fft_bin_count_r + 1;
        end
    end

    initial begin
        real auto_rmse_r;
        real auto_max_abs_r;
        real manual_rmse_r;
        real manual_max_abs_r;

        key0 = 1'b1; key1 = 1'b1; key2 = 1'b1; key3 = 1'b1; reset_n = 1'b1;
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

        reset_scoreboard();
        load_expected_samples();
        load_expected_fft();

        force_fft_stream_inputs();
        apply_reset_sequence();

        feed_fft_frame(FRAME0_IDX);
        wait_for_run_count(1);
        wait_for_done_count(1);

        feed_fft_frame(FRAME1_IDX);
        wait_for_run_count(2);
        wait_for_auto_dma_capture();
        manual_dma_dump();

        compute_fft_metrics(1'b0, FRAME0_IDX, auto_rmse_r, auto_max_abs_r);
        compute_fft_metrics(1'b1, FRAME0_IDX, manual_rmse_r, manual_max_abs_r);

        $display("[%0t] top_level_fft_isolated: auto   rmse=%0f max_abs=%0f", $time, auto_rmse_r, auto_max_abs_r);
        $display("[%0t] top_level_fft_isolated: manual rmse=%0f max_abs=%0f", $time, manual_rmse_r, manual_max_abs_r);
        display_fft_preview(1'b0, FRAME0_IDX);
        display_fft_preview(1'b1, FRAME0_IDX);
        compare_auto_vs_manual();

        assert (input_sample_count_r == (2 * N_POINTS))
        else $fatal(1, "Frames isolados deveriam ter %0d amostras, obtiveram %0d.",
                    2 * N_POINTS, input_sample_count_r);

        assert (run_rise_count_r == 2)
        else $fatal(1, "Esperados 2 pulsos de run, obtidos %0d", run_rise_count_r);

        assert (done_rise_count_r >= 1)
        else $fatal(1, "Esperado ao menos 1 pulso de done, obtido %0d", done_rise_count_r);

        assert (input_buffer_full_seen_r)
        else $fatal(1, "input_buffer_status_o nunca indicou buffer cheio.");

        assert (fft_status_run_seen_r)
        else $fatal(1, "fft_status_o nunca entrou em RUN.");

        assert (fft_status_done_seen_r)
        else $fatal(1, "fft_status_o nunca entrou em DONE.");

        assert (sb_done_seen_r)
        else $fatal(1, "Subsequencer interno da FFT nao chegou em SB_DONE.");

        assert (fft_stage_max_r >= (FFT_N-1))
        else $fatal(1, "fftStageCount max incorreto. exp>=%0d got=%0d", FFT_N-1, fft_stage_max_r);

        assert ((observed_tribuf_phase_r == TRIBUF_PHASE_1_C) ||
                (observed_tribuf_phase_r == TRIBUF_PHASE_2_C) ||
                (observed_tribuf_phase_r == TRIBUF_PHASE_0_C))
        else $fatal(1, "tribuf_status observado invalido: %0d", observed_tribuf_phase_r);

        assert (manual_max_abs_r <= FFT_MAX_ABS_ERR_TOL)
        else $fatal(1,
                    "Leitura manual DMA ainda nao bate a FFT esperada. Isso indica problema antes do fft_dma_reader. max_abs=%0f tol=%0f",
                    manual_max_abs_r, FFT_MAX_ABS_ERR_TOL);

        assert (manual_rmse_r <= FFT_RMSE_ERR_TOL)
        else $fatal(1,
                    "Leitura manual DMA ainda nao bate a FFT esperada. rmse=%0f tol=%0f",
                    manual_rmse_r, FFT_RMSE_ERR_TOL);

        if ((auto_max_abs_r > FFT_MAX_ABS_ERR_TOL) || (auto_rmse_r > FFT_RMSE_ERR_TOL)) begin
            $display("Diagnostico: FFT interna e unidade de controle estao corretas, mas o caminho integrado de leitura DMA nao reproduz o protocolo do autor.");
            $display("Diagnostico: dma_auto_burst_count=%0d dma_auto_max_burst_len=%0d",
                     dma_auto_burst_count_r, dma_auto_max_burst_len_r);
        end

        assert (auto_max_abs_r <= FFT_MAX_ABS_ERR_TOL)
        else $fatal(1,
                    "Leitura automatica FFT divergente. Como a leitura manual passou, o problema esta no leitor DMA integrado. max_abs=%0f tol=%0f",
                    auto_max_abs_r, FFT_MAX_ABS_ERR_TOL);

        assert (auto_rmse_r <= FFT_RMSE_ERR_TOL)
        else $fatal(1,
                    "Leitura automatica FFT divergente. Como a leitura manual passou, o problema esta no leitor DMA integrado. rmse=%0f tol=%0f",
                    auto_rmse_r, FFT_RMSE_ERR_TOL);

        $display("tb_top_level_fft_isolated PASSED");
        $finish;
    end

endmodule
