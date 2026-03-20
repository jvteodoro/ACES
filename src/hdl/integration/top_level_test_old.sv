module top_level_test #(
    parameter int FFT_LENGTH    = 512,
    parameter int FFT_DW        = 18,
    parameter int N_POINTS      = 512,
    parameter int N_EXAMPLES    = 8,
    parameter int I2S_CLOCK_DIV = 16,
    parameter ROM_ADDR_W = 16,
    parameter CLOCK_DIV = 16
)(
    input  logic clk,
    input  logic rst,

    // -----------------------------------------
    // interface Input FPGA
    // -----------------------------------------
    input logic key0, //PIN_U7
    input logic key1, //PIN_W9
    input logic key2, //PIN_M7
    input logic key3, //PIN_M6

    input logic sw0, //PIN_U13
    input logic sw1, //PIN_V13
    input logic sw2, //PIN_T13
    input logic sw3, //PIN_T12
    input logic sw4, //PIN_AA15
    input logic sw5, //PIN_AB15
    input logic sw6, //PIN_AA14
    input logic sw7, //PIN_AA13
    input logic sw8, //PIN_AB13
    input logic sw9, //PIN_AB12

    input logic clock_50,  //PIN_M9 (Bank 3B)
    input logic clock2_50, //PIN_H13 (Bank 7A)
    input logic clock3_50, //PIN_E10 (Bank 8A)
    input logic clock4_50, //PIN_V15 (Bank 4A)


    // -----------------------------------------
    // interface Output FPGA
    // -----------------------------------------
    output logic ledr0, //PIN_AA2
    output logic ledr1, //PIN_AA1
    output logic ledr2, //PIN_W2
    output logic ledr3, //PIN_Y3
    output logic ledr4, //PIN_N2
    output logic ledr5, //PIN_N1
    output logic ledr6, //PIN_U2
    output logic ledr7, //PIN_U1
    output logic ledr8, //PIN_L2
    output logic ledr9, //PIN_L1

    output logic [6:0] hex0_o,
    output logic [6:0] hex1_o,
    output logic [6:0] hex2_o,
    output logic [6:0] hex3_o,
    output logic [6:0] hex4_o,
    output logic [6:0] hex5_o

    



);
    // -----------------------------------------
    // controle do gerador de estímulos via I/O
    // -----------------------------------------
    logic stim_start_i;
    logic [$clog2(N_EXAMPLES)-1:0] stim_example_sel_i;
    logic [1:0] stim_loop_mode_i;
    logic stim_lr_sel_i;

    assign stim_start_i = sw2;
    assign stim_example_sel_i = sw3;
    assign stim_loop_mode_i = sw4;
    assign stim_lr_sel_i = sw5;

    // -----------------------------------------
    // debug do gerador
    // -----------------------------------------
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

    // -----------------------------------------
    // debug dos sinais I2S
    // -----------------------------------------
    logic i2s_sck_o;
    logic i2s_ws_o;
    logic mic_chipen_o;
    logic mic_lr_sel_o;
    logic i2s_sd_o;

    assign ledr0 = mic_chipen_o;
    assign ledr1 = mic_lr_sel_o;
    assign ledr2 = i2s_ws_o; 

    // -----------------------------------------
    // debug do ACES
    // -----------------------------------------
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

    // -----------------------------------------
    // interface pronta para futura placa serial
    // -----------------------------------------
    logic fft_tx_valid_o;
    logic [$clog2(FFT_LENGTH)-1:0] fft_tx_index_o;
    logic signed [FFT_DW-1:0] fft_tx_real_o;
    logic signed [FFT_DW-1:0] fft_tx_imag_o;
    logic fft_tx_last_o;


    logic mic_sd_internal;

    
    // -----------------------------------------
    // 7seg debug
    // -----------------------------------------
    logic [1:0] hex_sel;
	 assign hex_sel = {sw1, sw0};
    
    logic [3:0] hex0_i;
    logic [3:0] hex1_i;
    logic [3:0] hex2_i;
    logic [3:0] hex3_i;
    logic [3:0] hex4_i;
    logic [3:0] hex5_i;

    assign hex0_i =     (hex_sel == 0) ? sample_24_dbg_o[3:0]: 
                        (hex_sel == 1) ? fft_tx_real_o[3:0]: 
                        (hex_sel == 2) ? fft_tx_imag_o[3:0]: 4'd0;

    assign hex1_i =     (hex_sel == 0) ? sample_24_dbg_o[7:4]: 
                        (hex_sel == 1) ? fft_tx_real_o[7:4]: 
                        (hex_sel == 2) ? fft_tx_imag_o[7:4]: 4'd0;

    assign hex2_i =     (hex_sel == 0) ? sample_24_dbg_o[11:8]: 
                        (hex_sel == 1) ? fft_tx_real_o[11:8]: 
                        (hex_sel == 2) ? fft_tx_imag_o[11:8]: 4'd0;

    assign hex3_i =     (hex_sel == 0) ? sample_24_dbg_o[15:12]: 
                        (hex_sel == 1) ? fft_tx_real_o[15:12]: 
                        (hex_sel == 2) ? fft_tx_imag_o[15:12]: 4'd0;
                            
    assign hex4_i =     (hex_sel == 0) ? sample_24_dbg_o[19:16]: 
                        (hex_sel == 1) ? {1'b0,fft_tx_real_o[17:16]}: 
                        (hex_sel == 2) ?{1'b0,fft_tx_imag_o[17:16]}: 4'd0;

    assign hex5_i = (hex_sel == 0) ? sample_24_dbg_o[23:20]: 4'd0;

    hexa7seg hex0(hex0_i, hex0_o);
    hexa7seg hex1(hex1_i, hex1_o);
    hexa7seg hex2(hex2_i, hex2_o);
    hexa7seg hex3(hex3_i, hex3_o);
    hexa7seg hex4(hex4_i, hex4_o);
    hexa7seg hex5(hex5_i, hex5_o);


    // -----------------------------------------
    // ACES
    // -----------------------------------------
    aces #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV)
    ) u_aces (
        .clk(clk),
        .rst(rst),

        .mic_sd_i(mic_sd_internal),
        .mic_lr_sel_i(stim_lr_sel_i),

        .mic_sck_o(i2s_sck_o),
        .mic_ws_o(i2s_ws_o),
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

    // -----------------------------------------
    // gerador de estímulo com ROM interna
    // -----------------------------------------
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
        .sck_i(i2s_sck_o),
        .ws_i(i2s_ws_o),
        .sd_o(mic_sd_internal),

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

    assign i2s_sd_o = mic_sd_internal;

endmodule