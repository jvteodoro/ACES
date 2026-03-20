`timescale 1ns/1ps

module tb_top_level_test_real;

    localparam int FFT_LENGTH    = 512;
    localparam int FFT_DW        = 18;
    localparam int N_POINTS      = 512;
    localparam int N_EXAMPLES    = 6;
    localparam int I2S_CLOCK_DIV = 16;

    localparam int EXAMPLE_SEL_W = (N_EXAMPLES <= 1) ? 1 : $clog2(N_EXAMPLES);

    localparam time CLK_HALF = 10ns; // 50 MHz

    logic clk;
    logic rst;

    logic stim_start_i;
    logic [EXAMPLE_SEL_W-1:0] stim_example_sel_i;
    logic [1:0] stim_loop_mode_i;
    logic stim_lr_sel_i;

    logic stim_ready_o;
    logic stim_busy_o;
    logic stim_done_o;
    logic stim_window_done_o;
    logic [$clog2(N_EXAMPLES)-1:0] stim_current_example_o;
    logic [$clog2(N_POINTS)-1:0] stim_current_point_o;
    logic [$clog2(N_POINTS*N_EXAMPLES)-1:0] stim_rom_addr_dbg_o;
    logic signed [23:0] stim_current_sample_dbg_o;
    logic [5:0] stim_bit_index_o;
    logic [2:0] stim_state_dbg_o;

    logic i2s_sck_o;
    logic i2s_ws_o;
    logic i2s_sd_o;
    logic mic_chipen_o;
    logic mic_lr_sel_o;

    logic sample_valid_mic_o;
    logic signed [FFT_DW-1:0] sample_mic_o;
    logic signed [23:0] sample_24_dbg_o;

    logic fft_sample_valid_o;
    logic signed [FFT_DW-1:0] fft_sample_o;

    logic sact_istream_o;
    logic signed [FFT_DW-1:0] sdw_istream_real_o;
    logic signed [FFT_DW-1:0] sdw_istream_imag_o;

    logic fft_run_o;
    logic [1:0] fft_input_buffer_status_o;
    logic [2:0] fft_status_o;
    logic fft_done_o;
    logic signed [7:0] bfpexp_o;

    logic fft_tx_valid_o;
    logic [$clog2(FFT_LENGTH)-1:0] fft_tx_index_o;
    logic signed [FFT_DW-1:0] fft_tx_real_o;
    logic signed [FFT_DW-1:0] fft_tx_imag_o;
    logic fft_tx_last_o;

    integer sample_count;
    integer tx_count;
    integer fp_tx_file;
    integer fp_sample_file;

    // ------------------------------------------------------------
    // clock
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #CLK_HALF clk = ~clk;
    end

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    top_level_test #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV)
    ) dut (
        .clk(clk),
        .rst(rst),

        .stim_start_i(stim_start_i),
        .stim_example_sel_i(stim_example_sel_i),
        .stim_loop_mode_i(stim_loop_mode_i),
        .stim_lr_sel_i(stim_lr_sel_i),

        .stim_ready_o(stim_ready_o),
        .stim_busy_o(stim_busy_o),
        .stim_done_o(stim_done_o),
        .stim_window_done_o(stim_window_done_o),
        .stim_current_example_o(stim_current_example_o),
        .stim_current_point_o(stim_current_point_o),
        .stim_rom_addr_dbg_o(stim_rom_addr_dbg_o),
        .stim_current_sample_dbg_o(stim_current_sample_dbg_o),
        .stim_bit_index_o(stim_bit_index_o),
        .stim_state_dbg_o(stim_state_dbg_o),

        .i2s_sck_o(i2s_sck_o),
        .i2s_ws_o(i2s_ws_o),
        .i2s_sd_o(i2s_sd_o),
        .mic_chipen_o(mic_chipen_o),
        .mic_lr_sel_o(mic_lr_sel_o),

        .sample_valid_mic_o(sample_valid_mic_o),
        .sample_mic_o(sample_mic_o),
        .sample_24_dbg_o(sample_24_dbg_o),

        .fft_sample_valid_o(fft_sample_valid_o),
        .fft_sample_o(fft_sample_o),

        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o),

        .fft_run_o(fft_run_o),
        .fft_input_buffer_status_o(fft_input_buffer_status_o),
        .fft_status_o(fft_status_o),
        .fft_done_o(fft_done_o),
        .bfpexp_o(bfpexp_o),

        .fft_tx_valid_o(fft_tx_valid_o),
        .fft_tx_index_o(fft_tx_index_o),
        .fft_tx_real_o(fft_tx_real_o),
        .fft_tx_imag_o(fft_tx_imag_o),
        .fft_tx_last_o(fft_tx_last_o)
    );

    // ------------------------------------------------------------
    // captura de amostras no frontend
    // ------------------------------------------------------------
    always @(posedge sample_valid_mic_o) begin
        sample_count = sample_count + 1;
        $fwrite(fp_sample_file, "%0d,%0d,%0d\n",
            sample_count-1,
            sample_mic_o,
            sample_24_dbg_o
        );
    end

    // ------------------------------------------------------------
    // captura da "interface serial futura"
    // formato CSV:
    // index,real,imag,last,fftBfpExp
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (fft_tx_valid_o) begin
            tx_count = tx_count + 1;
            $fwrite(fp_tx_file, "%0d,%0d,%0d,%0d,%0d\n",
                fft_tx_index_o,
                fft_tx_real_o,
                fft_tx_imag_o,
                fft_tx_last_o,
                bfpexp_o
            );
        end
    end

    // ------------------------------------------------------------
    // assertions estruturais
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (fft_tx_valid_o && (fft_tx_index_o == FFT_LENGTH-1)) begin
            assert(fft_tx_last_o == 1'b1)
            else $error("fft_tx_last_o deveria estar alto no último bin");
        end

        if (fft_tx_valid_o && (fft_tx_index_o != FFT_LENGTH-1)) begin
            assert(fft_tx_last_o == 1'b0)
            else $error("fft_tx_last_o só pode ficar alto no último bin");
        end
    end

    // ------------------------------------------------------------
    // estímulo principal
    // ------------------------------------------------------------
    initial begin
        sample_count       = 0;
        tx_count           = 0;

        fp_tx_file     = $fopen("fft_tx_output.csv", "w");
        fp_sample_file = $fopen("frontend_samples.csv", "w");

        if (fp_tx_file == 0) begin
            $error("Nao foi possivel abrir fft_tx_output.csv");
            $finish;
        end

        if (fp_sample_file == 0) begin
            $error("Nao foi possivel abrir frontend_samples.csv");
            $finish;
        end

        $fwrite(fp_tx_file, "index,real,imag,last,fftBfpExp\n");
        $fwrite(fp_sample_file, "sample_idx,sample_18,sample_24\n");

        rst               = 1'b1;
        stim_start_i      = 1'b0;
        stim_example_sel_i= '0;
        stim_loop_mode_i  = 2'b00; // sem loop
        stim_lr_sel_i     = 1'b0;  // usa slot esquerdo

        repeat (10) @(posedge clk);
        rst = 1'b0;

        // espera sistema estabilizar
        repeat (50) @(posedge clk);

        wait(stim_ready_o == 1'b1)
        assert(stim_ready_o == 1'b1)
        else $error("stim_ready_o deveria estar alto antes do start");

        // escolha do exemplo
        stim_example_sel_i = 0;
        stim_loop_mode_i   = 2'b00;

        // start
        stim_start_i = 1'b1;
        @(posedge clk);
        stim_start_i = 1'b0;

        // espera fim da FFT
        wait (fft_done_o == 1'b1);

        // espera leitor DMA terminar de mandar todos os bins
        wait (fft_tx_valid_o && fft_tx_last_o);
        repeat (20) @(posedge clk);

        assert(sample_count > 0)
        else $error("Nenhuma amostra foi capturada no frontend");

        assert(tx_count == FFT_LENGTH)
        else $error("Esperado %0d bins de FFT, obtido %0d", FFT_LENGTH, tx_count);

        $fclose(fp_tx_file);
        $fclose(fp_sample_file);

        $display("tb_top_level_test_real PASSED");
        $finish;
    end

endmodule