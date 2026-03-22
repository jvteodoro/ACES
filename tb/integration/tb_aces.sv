`timescale 1ns/1ps

module tb_aces;

    localparam int FFT_LENGTH = 4;
    localparam int FFT_DW     = 18;
    localparam int N_POINTS   = 8;
    localparam int N_EXAMPLES = 4;
    localparam time CLK_HALF  = 5ns;
    localparam int EXAMPLE_SEL_W = (N_EXAMPLES <= 1) ? 1 : $clog2(N_EXAMPLES);

    logic clk;
    logic rst;
    tri   sd_i;

    logic mic_sck_o;
    logic mic_ws_o;
    logic mic_chipen_o;
    logic mic_lr_sel_o;

    logic sample_valid_mic_o;
    logic signed [FFT_DW-1:0] sample_mic_o;
    logic signed [23:0] sample_24_dbg_o;
    logic fft_sample_valid_o;
    logic signed [FFT_DW-1:0] fft_sample_o;
    logic sact_istream_o;

    logic fft_run_o;
    logic [1:0] fft_input_buffer_status_o;
    logic [2:0] fft_status_o;
    logic fft_done_o;

    logic fft_tx_valid_o;
    logic [$clog2(FFT_LENGTH)-1:0] fft_tx_index_o;
    logic signed [FFT_DW-1:0] fft_tx_real_o;
    logic signed [FFT_DW-1:0] fft_tx_imag_o;
    logic fft_tx_last_o;

    logic start_i;
    logic [EXAMPLE_SEL_W-1:0] example_sel_i;
    logic [1:0] loop_mode_i;
    logic stim_busy_o;
    logic stim_done_o;
    logic stim_ready_o;
    logic stim_window_done_o;
    logic [EXAMPLE_SEL_W-1:0] stim_current_example_o;
    logic [$clog2(N_POINTS)-1:0] stim_current_point_o;
    logic [$clog2(N_POINTS*N_EXAMPLES)-1:0] stim_rom_addr_dbg_o;
    logic signed [23:0] stim_current_sample_dbg_o;
    logic [5:0] stim_bit_index_o;
    logic [2:0] stim_state_dbg_o;

    logic signed [FFT_DW-1:0] expected18 [0:FFT_LENGTH-1];

    int mic_count;
    int fft_bin_count;

    always #CLK_HALF clk = ~clk;

    initial begin
        expected18[0] = 24'h000001[23:6];
        expected18[1] = 24'h000002[23:6];
        expected18[2] = 24'h000003[23:6];
        expected18[3] = 24'h000004[23:6];
    end

    i2s_stimulus_manager_rom #(
        .SAMPLE_BITS(24),
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
        .STARTUP_SCK_CYCLES(8),
        .INACTIVE_ZERO_SYNTH(0)
    ) u_stim (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .example_sel_i(example_sel_i),
        .loop_mode_i(loop_mode_i),
        .chipen_i(mic_chipen_o),
        .lr_i(1'b0),
        .sck_i(mic_sck_o),
        .ws_i(mic_ws_o),
        .sd_o(sd_i),
        .ready_o(stim_ready_o),
        .busy_o(stim_busy_o),
        .done_o(stim_done_o),
        .window_done_o(stim_window_done_o),
        .current_example_o(stim_current_example_o),
        .current_point_o(stim_current_point_o),
        .rom_addr_dbg_o(stim_rom_addr_dbg_o),
        .current_sample_dbg_o(stim_current_sample_dbg_o),
        .bit_index_o(stim_bit_index_o),
        .state_dbg_o(stim_state_dbg_o)
    );

    aces #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mic_sd_i(sd_i),
        .mic_lr_sel_i(1'b0),
        .mic_sck_o(mic_sck_o),
        .mic_ws_o(mic_ws_o),
        .mic_chipen_o(mic_chipen_o),
        .mic_lr_sel_o(mic_lr_sel_o),
        .sample_valid_mic_o(sample_valid_mic_o),
        .sample_mic_o(sample_mic_o),
        .sample_24_dbg_o(sample_24_dbg_o),
        .fft_sample_valid_o(fft_sample_valid_o),
        .fft_sample_o(fft_sample_o),
        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(),
        .sdw_istream_imag_o(),
        .fft_run_o(fft_run_o),
        .fft_input_buffer_status_o(fft_input_buffer_status_o),
        .fft_status_o(fft_status_o),
        .fft_done_o(fft_done_o),
        .bfpexp_o(),
        .fft_tx_valid_o(fft_tx_valid_o),
        .fft_tx_index_o(fft_tx_index_o),
        .fft_tx_real_o(fft_tx_real_o),
        .fft_tx_imag_o(fft_tx_imag_o),
        .fft_tx_last_o(fft_tx_last_o)
    );

    always @(posedge sample_valid_mic_o) begin
        assert (mic_count < FFT_LENGTH)
        else $error("ACES recebeu mais amostras do que o esperado");

        assert (sample_mic_o === expected18[mic_count])
        else $error("ACES mic sample mismatch idx=%0d exp=0x%05h got=0x%05h",
                    mic_count, expected18[mic_count], sample_mic_o);

        mic_count = mic_count + 1;
    end

    always @(posedge clk) begin
        if (fft_tx_valid_o) begin
            assert (fft_tx_index_o == fft_bin_count[$clog2(FFT_LENGTH)-1:0])
            else $error("FFT tx index mismatch idx=%0d got=%0d", fft_bin_count, fft_tx_index_o);

            assert (fft_tx_real_o == fft_bin_count + 1)
            else $error("FFT tx real mismatch idx=%0d got=%0d", fft_bin_count, fft_tx_real_o);

            assert (fft_tx_imag_o == -fft_bin_count)
            else $error("FFT tx imag mismatch idx=%0d got=%0d", fft_bin_count, fft_tx_imag_o);

            assert (fft_tx_last_o == (fft_bin_count == FFT_LENGTH-1))
            else $error("FFT tx last mismatch idx=%0d", fft_bin_count);

            fft_bin_count = fft_bin_count + 1;
        end
    end

    initial begin
        clk           = 1'b0;
        rst           = 1'b1;
        start_i       = 1'b0;
        example_sel_i = '0;
        loop_mode_i   = 2'b00;
        mic_count     = 0;
        fft_bin_count = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        wait (stim_ready_o == 1'b1);
        repeat (2) @(posedge clk);

        start_i = 1'b1;
        @(posedge clk);
        start_i = 1'b0;

        wait (fft_bin_count == FFT_LENGTH);
        repeat (10) @(posedge clk);

        assert (mic_count == FFT_LENGTH)
        else $error("ACES expected %0d mic samples got %0d", FFT_LENGTH, mic_count);

        assert (fft_bin_count == FFT_LENGTH)
        else $error("ACES expected %0d fft bins got %0d", FFT_LENGTH, fft_bin_count);

        $display("tb_aces PASSED");
        $finish;
    end

endmodule
