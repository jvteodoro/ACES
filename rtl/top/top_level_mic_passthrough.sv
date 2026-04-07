module top_level_mic_passthrough #(
    parameter int FFT_LENGTH    = 512,
    parameter int FFT_DW        = 18,
    parameter int N_POINTS      = 512,
    parameter int N_EXAMPLES    = 8,
    parameter int I2S_CLOCK_DIV = 8
) (
    input logic key0,
    input logic key1,
    input logic key2,
    input logic key3,
    input logic reset_n,

    input logic sw0,
    input logic sw1,
    input logic sw2,
    input logic sw3,
    input logic sw4,
    input logic sw5,
    input logic sw6,
    input logic sw7,
    input logic sw8,
    input logic sw9,

    input logic clock_50,
    input logic clock2_50,
    input logic clock3_50,
    input logic clock4_50,

    output logic ledr0,
    output logic ledr1,
    output logic ledr2,
    output logic ledr3,
    output logic ledr4,
    output logic ledr5,
    output logic ledr6,
    output logic ledr7,
    output logic ledr8,
    output logic ledr9,

    output logic [6:0] hex0_o,
    output logic [6:0] hex1_o,
    output logic [6:0] hex2_o,
    output logic [6:0] hex3_o,
    output logic [6:0] hex4_o,
    output logic [6:0] hex5_o,

    inout logic gpio_0_d0,
    inout logic gpio_0_d1,
    inout logic gpio_0_d2,
    inout logic gpio_0_d3,
    inout logic gpio_0_d4,
    input logic gpio_0_d5,
    inout logic gpio_0_d6,
    input logic gpio_0_d7,
    inout logic gpio_0_d8,
    input logic gpio_0_d9,
    inout logic gpio_0_d10,
    input logic gpio_0_d11,
    output logic gpio_0_d12,
    input logic gpio_0_d13,
    output logic gpio_0_d14,
    input logic gpio_0_d15,
    output logic gpio_0_d16,
    input logic gpio_0_d17,
    output logic gpio_0_d18,
    input logic gpio_0_d19,
    inout logic gpio_0_d20,
    inout logic gpio_0_d21,
    inout logic gpio_0_d22,
    inout logic gpio_0_d23,
    inout logic gpio_0_d24,
    inout logic gpio_0_d25,
    inout logic gpio_0_d26,
    inout logic gpio_0_d27,
    inout logic gpio_0_d28,
    inout logic gpio_0_d29,
    inout logic gpio_0_d30,
    inout logic gpio_0_d31,
    inout logic gpio_0_d32,
    inout logic gpio_0_d33,
    inout logic gpio_0_d34,
    input logic gpio_0_d35,

    output logic gpio_1_d0,
    inout logic gpio_1_d1,
    output logic gpio_1_d2,
    inout logic gpio_1_d3,
    output logic gpio_1_d4,
    inout logic gpio_1_d5,
    input logic gpio_1_d6,
    inout logic gpio_1_d7,
    inout logic gpio_1_d8,
    inout logic gpio_1_d9,
    inout logic gpio_1_d10,
    inout logic gpio_1_d11,
    inout logic gpio_1_d12,
    inout logic gpio_1_d13,
    inout logic gpio_1_d14,
    inout logic gpio_1_d15,
    inout logic gpio_1_d16,
    inout logic gpio_1_d17,
    inout logic gpio_1_d18,
    inout logic gpio_1_d19,
    inout logic gpio_1_d20,
    output logic gpio_1_d21,
    inout logic gpio_1_d22,
    output logic gpio_1_d23,
    inout logic gpio_1_d24,
    output logic gpio_1_d25,
    inout logic gpio_1_d26,
    output logic gpio_1_d27,
    inout logic gpio_1_d28,
    output logic gpio_1_d29,
    output logic gpio_1_d30,
    output logic gpio_1_d31,
    output logic gpio_1_d32,
    inout logic gpio_1_d33,
    output logic gpio_1_d34,
    inout logic gpio_1_d35
);

    logic clk;
    logic rst;

    logic stim_start_i;
    logic [$clog2(N_EXAMPLES)-1:0] stim_example_sel_i;
    logic [1:0] stim_loop_mode_i;
    logic stim_lr_sel_i;
    logic select_audio_source_i;

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
    logic stim_sd_o;

    logic mic_sd_internal;

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
    logic fft_bin_valid_o;
    logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_o;
    logic signed [FFT_DW-1:0] fft_bin_real_o;
    logic signed [FFT_DW-1:0] fft_bin_imag_o;
    logic fft_bin_last_o;
    logic mic_sck_o;
    logic mic_ws_o;
    logic mic_chipen_o;
    logic mic_lr_sel_o;

    logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_latched_r;
    logic signed [FFT_DW-1:0] fft_bin_real_latched_r;
    logic signed [FFT_DW-1:0] fft_bin_imag_latched_r;
    logic fft_bin_valid_latched_r;
    logic fft_bin_last_latched_r;

    logic [23:0] display_word;
    logic [3:0] hex0_i;
    logic [3:0] hex1_i;
    logic [3:0] hex2_i;
    logic [3:0] hex3_i;
    logic [3:0] hex4_i;
    logic [3:0] hex5_i;

    assign stim_start_i         = sw0;
    assign stim_example_sel_i   = {sw3, sw2, sw1};
    assign stim_loop_mode_i     = {sw5, sw4};
    assign stim_lr_sel_i        = sw6;
    assign select_audio_source_i = sw7;

    // Preserva o fluxo de laboratorio em que clock e reset chegam pelo header.
    assign clk = gpio_0_d0;
    assign rst = gpio_0_d1;

    assign mic_sd_internal = select_audio_source_i ? stim_sd_o : gpio_1_d6;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fft_bin_index_latched_r <= '0;
            fft_bin_real_latched_r  <= '0;
            fft_bin_imag_latched_r  <= '0;
            fft_bin_valid_latched_r <= 1'b0;
            fft_bin_last_latched_r  <= 1'b0;
        end else if (fft_bin_valid_o) begin
            fft_bin_index_latched_r <= fft_bin_index_o;
            fft_bin_real_latched_r  <= fft_bin_real_o;
            fft_bin_imag_latched_r  <= fft_bin_imag_o;
            fft_bin_valid_latched_r <= 1'b1;
            fft_bin_last_latched_r  <= fft_bin_last_o;
        end
    end

    always_comb begin
        display_word = '0;
        unique case ({sw9, sw8})
            2'b00: display_word = sample_24_dbg_o;
            2'b01: display_word = {{(24-FFT_DW){fft_bin_real_latched_r[FFT_DW-1]}}, fft_bin_real_latched_r};
            2'b10: display_word = {{(24-FFT_DW){fft_bin_imag_latched_r[FFT_DW-1]}}, fft_bin_imag_latched_r};
            2'b11: begin
                display_word[7:0]   = bfpexp_o;
                display_word[10:8]  = fft_status_o;
                display_word[12:11] = fft_input_buffer_status_o;
                display_word[21:13] = fft_bin_index_latched_r;
                display_word[22]    = fft_bin_last_latched_r;
                display_word[23]    = fft_bin_valid_latched_r;
            end
        endcase
    end

    assign ledr0 = sample_valid_mic_o;
    assign ledr1 = fft_sample_valid_o;
    assign ledr2 = sact_istream_o;
    assign ledr3 = fft_run_o;
    assign ledr4 = fft_done_o;
    assign ledr5 = fft_bin_valid_latched_r;
    assign ledr6 = fft_bin_last_latched_r;
    assign ledr7 = select_audio_source_i;
    assign ledr8 = mic_ws_o;
    assign ledr9 = mic_sck_o;

    assign hex0_i = display_word[3:0];
    assign hex1_i = display_word[7:4];
    assign hex2_i = display_word[11:8];
    assign hex3_i = display_word[15:12];
    assign hex4_i = display_word[19:16];
    assign hex5_i = display_word[23:20];

    hexa7seg hex0(hex0_i, hex0_o);
    hexa7seg hex1(hex1_i, hex1_o);
    hexa7seg hex2(hex2_i, hex2_o);
    hexa7seg hex3(hex3_i, hex3_o);
    hexa7seg hex4(hex4_i, hex4_o);
    hexa7seg hex5(hex5_i, hex5_o);

    aces #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV)
    ) u_aces (
        .clk(clk),
        .rst(rst),
        .mic_sd_i(mic_sd_internal),
        .mic_lr_sel_i(stim_lr_sel_i),
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
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o),
        .fft_run_o(fft_run_o),
        .fft_input_buffer_status_o(fft_input_buffer_status_o),
        .fft_status_o(fft_status_o),
        .fft_done_o(fft_done_o),
        .bfpexp_o(bfpexp_o),
        .fft_bin_valid_o(fft_bin_valid_o),
        .fft_bin_index_o(fft_bin_index_o),
        .fft_bin_real_o(fft_bin_real_o),
        .fft_bin_imag_o(fft_bin_imag_o),
        .fft_bin_last_o(fft_bin_last_o)
    );

    i2s_stimulus_manager_rom #(
        .SAMPLE_BITS(24),
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
        .STARTUP_SCK_CYCLES(8),
        .INACTIVE_ZERO_SYNTH(0)
    ) u_i2s_stimulus_manager_rom (
        .clk(clk),
        .rst(rst),
        .start_i(stim_start_i),
        .example_sel_i(stim_example_sel_i),
        .loop_mode_i(stim_loop_mode_i),
        .chipen_i(mic_chipen_o),
        .lr_i(mic_lr_sel_o),
        .sck_i(mic_sck_o),
        .ws_i(mic_ws_o),
        .sd_o(stim_sd_o),
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

    // Espelho bruto do I2S recebido pelo FPGA para o Raspberry Pi.
    assign gpio_1_d21 = mic_sck_o;
    assign gpio_1_d23 = mic_ws_o;
    assign gpio_1_d25 = mic_sd_internal;
    assign gpio_1_d27 = mic_sck_o;
    assign gpio_1_d29 = mic_ws_o;
    assign gpio_1_d31 = mic_sd_internal;
    assign gpio_1_d30 = mic_sck_o;
    assign gpio_1_d32 = mic_ws_o;
    assign gpio_1_d34 = mic_sd_internal;

    assign gpio_1_d0 = mic_lr_sel_o;
    assign gpio_1_d2 = mic_ws_o;
    assign gpio_1_d4 = mic_sck_o;

    assign gpio_0_d12 = 1'b0;
    assign gpio_0_d14 = 1'b0;
    assign gpio_0_d16 = 1'b0;
    assign gpio_0_d18 = 1'b0;

    assign gpio_0_d2  = 1'bz;
    assign gpio_0_d3  = 1'bz;
    assign gpio_0_d4  = 1'bz;
    assign gpio_0_d6  = 1'bz;
    assign gpio_0_d8  = 1'bz;
    assign gpio_0_d10 = 1'bz;
    assign gpio_0_d20 = 1'bz;
    assign gpio_0_d21 = 1'bz;
    assign gpio_0_d22 = 1'bz;
    assign gpio_0_d23 = 1'bz;
    assign gpio_0_d24 = 1'bz;
    assign gpio_0_d25 = 1'bz;
    assign gpio_0_d26 = 1'bz;
    assign gpio_0_d27 = 1'bz;
    assign gpio_0_d28 = 1'bz;
    assign gpio_0_d29 = 1'bz;
    assign gpio_0_d30 = 1'bz;
    assign gpio_0_d31 = 1'bz;
    assign gpio_0_d32 = 1'bz;
    assign gpio_0_d33 = 1'bz;
    assign gpio_0_d34 = 1'bz;

    assign gpio_1_d1  = 1'bz;
    assign gpio_1_d3  = 1'bz;
    assign gpio_1_d5  = 1'bz;
    assign gpio_1_d7  = 1'bz;
    assign gpio_1_d8  = 1'bz;
    assign gpio_1_d9  = 1'bz;
    assign gpio_1_d10 = 1'bz;
    assign gpio_1_d11 = 1'bz;
    assign gpio_1_d12 = 1'bz;
    assign gpio_1_d13 = 1'bz;
    assign gpio_1_d14 = 1'bz;
    assign gpio_1_d15 = 1'bz;
    assign gpio_1_d16 = 1'bz;
    assign gpio_1_d17 = 1'bz;
    assign gpio_1_d18 = 1'bz;
    assign gpio_1_d19 = 1'bz;
    assign gpio_1_d20 = 1'bz;
    assign gpio_1_d22 = 1'bz;
    assign gpio_1_d24 = 1'bz;
    assign gpio_1_d26 = 1'bz;
    assign gpio_1_d28 = 1'bz;
    assign gpio_1_d33 = 1'bz;
    assign gpio_1_d35 = 1'bz;

    // Mantem entradas opcionais visiveis para evitar podas agressivas.
    logic unused_inputs_probe;
    assign unused_inputs_probe = ^{
        key0, key1, key2, key3, reset_n,
        clock_50, clock2_50, clock3_50, clock4_50,
        gpio_0_d5, gpio_0_d7, gpio_0_d9, gpio_0_d11,
        gpio_0_d13, gpio_0_d15, gpio_0_d17, gpio_0_d19, gpio_0_d35,
        gpio_1_d6,
        stim_ready_o, stim_busy_o, stim_done_o, stim_window_done_o,
        stim_current_example_o, stim_current_point_o, stim_rom_addr_dbg_o,
        stim_current_sample_dbg_o, stim_bit_index_o, stim_state_dbg_o,
        sample_mic_o, fft_sample_o, sdw_istream_real_o, sdw_istream_imag_o
    };

endmodule
