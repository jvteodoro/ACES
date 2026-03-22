`timescale 1ns/1ps

module tb_aces;

    localparam int FFT_LENGTH = 4;
    localparam int FFT_DW     = 18;
    localparam int ROM_ADDR_W = 4;
    localparam time CLK_HALF  = 5ns;
    localparam time SCK_HALF  = 20ns;

    logic clk;
    logic rst;
    logic sck_i;
    logic ws_i;
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
    logic loop_enable_i;
    logic [ROM_ADDR_W-1:0] base_addr_i;
    logic [ROM_ADDR_W-1:0] signal_length_i;
    logic [ROM_ADDR_W-1:0] rom_addr_o;
    logic signed [23:0] rom_data_i;
    logic stim_busy_o;
    logic stim_done_o;
    logic stim_ready_o;

    logic signed [23:0] rom_mem [0:FFT_LENGTH-1];
    logic signed [FFT_DW-1:0] expected18 [0:FFT_LENGTH-1];

    int mic_count;
    int fft_bin_count;

    always #CLK_HALF clk = ~clk;
    always #SCK_HALF sck_i = ~sck_i;

    initial begin
        ws_i = 1'b1;
        forever begin
            repeat (32) @(negedge sck_i);
            ws_i = ~ws_i;
        end
    end

    initial begin
        rom_mem[0] = 24'h000001;
        rom_mem[1] = 24'h123456;
        rom_mem[2] = -24'sh400000;
        rom_mem[3] = 24'h7ABCDE;

        expected18[0] = rom_mem[0][23:6];
        expected18[1] = rom_mem[1][23:6];
        expected18[2] = rom_mem[2][23:6];
        expected18[3] = rom_mem[3][23:6];
    end

    always_ff @(posedge clk) begin
        rom_data_i <= rom_mem[rom_addr_o];
    end

    i2s_stimulus_manager #(
        .SAMPLE_BITS(24),
        .ROM_ADDR_W(ROM_ADDR_W),
        .GENERATE_CLOCKS(0),
        .STARTUP_SCK_CYCLES(8),
        .INACTIVE_ZERO_SYNTH(0)
    ) u_stim (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .loop_enable_i(loop_enable_i),
        .base_addr_i(base_addr_i),
        .signal_length_i(signal_length_i),
        .chipen_i(mic_chipen_o),
        .lr_i(1'b0),
        .sck_i(sck_i),
        .ws_i(ws_i),
        .sck_o(),
        .ws_o(),
        .sd_o(sd_i),
        .rom_addr_o(rom_addr_o),
        .rom_data_i(rom_data_i),
        .busy_o(stim_busy_o),
        .done_o(stim_done_o),
        .ready_o(stim_ready_o),
        .sample_index_o(),
        .bit_index_o(),
        .current_sample_dbg_o()
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
        clk             = 1'b0;
        sck_i           = 1'b0;
        rst             = 1'b1;
        start_i         = 1'b0;
        loop_enable_i   = 1'b0;
        base_addr_i     = '0;
        signal_length_i = FFT_LENGTH;
        rom_data_i      = '0;
        mic_count       = 0;
        fft_bin_count   = 0;

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
