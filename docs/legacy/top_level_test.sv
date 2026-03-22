module top_level_test #(
    parameter int FFT_LENGTH    = 512,
    parameter int FFT_DW        = 18,
    parameter int N_POINTS      = 512,
    parameter int N_EXAMPLES    = 8,
    parameter int I2S_CLOCK_DIV = 8,
    parameter ROM_ADDR_W = 16,
    parameter CLOCK_DIV = 16
)(

    // -----------------------------------------
    // interface Input FPGA
    // -----------------------------------------
    input logic key0, //PIN_U7
    input logic key1, //PIN_W9
    input logic key2, //PIN_M7
    input logic key3, //PIN_M6
    input logic reset_n, //PIN_P22

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

    output logic [6:0] hex5_o,

    // -----------------------------------------
    // expansion headers GPIO_0 / GPIO_1
    // -----------------------------------------
    inout logic gpio_0_d0,  //PIN_N16
    inout logic gpio_0_d1,  //PIN_B16
    inout logic gpio_0_d2,  //PIN_M16
    inout logic gpio_0_d3,  //PIN_C16
    inout logic gpio_0_d4,  //PIN_D17
    inout logic gpio_0_d5,  //PIN_K20
    inout logic gpio_0_d6,  //PIN_K21
    inout logic gpio_0_d7,  //PIN_K22
    inout logic gpio_0_d8,  //PIN_M20
    inout logic gpio_0_d9,  //PIN_M21
    inout logic gpio_0_d10, //PIN_N21
    inout logic gpio_0_d11, //PIN_R22
    inout logic gpio_0_d12, //PIN_R21
    inout logic gpio_0_d13, //PIN_T22
    inout logic gpio_0_d14, //PIN_N20
    inout logic gpio_0_d15, //PIN_N19
    inout logic gpio_0_d16, //PIN_M22
    inout logic gpio_0_d17, //PIN_P19
    inout logic gpio_0_d18, //PIN_L22
    inout logic gpio_0_d19, //PIN_P17
    inout logic gpio_0_d20, //PIN_P16
    inout logic gpio_0_d21, //PIN_M18
    inout logic gpio_0_d22, //PIN_L18
    inout logic gpio_0_d23, //PIN_L17
    inout logic gpio_0_d24, //PIN_L19
    inout logic gpio_0_d25, //PIN_K17
    inout logic gpio_0_d26, //PIN_K19
    inout logic gpio_0_d27, //PIN_P18
    inout logic gpio_0_d28, //PIN_R15
    inout logic gpio_0_d29, //PIN_R17
    inout logic gpio_0_d30, //PIN_R16
    inout logic gpio_0_d31, //PIN_T20
    inout logic gpio_0_d32, //PIN_T19
    inout logic gpio_0_d33, //PIN_T18
    inout logic gpio_0_d34, //PIN_T17
    inout logic gpio_0_d35, //PIN_T15

    inout logic gpio_1_d0,  //PIN_H16
    inout logic gpio_1_d1,  //PIN_A12
    inout logic gpio_1_d2,  //PIN_H15
    inout logic gpio_1_d3,  //PIN_B12
    output logic gpio_1_d4,  //PIN_A13
    inout logic gpio_1_d5,  //PIN_B13
    inout logic gpio_1_d6,  //PIN_C13
    inout logic gpio_1_d7,  //PIN_D13
    inout logic gpio_1_d8,  //PIN_G18
    inout logic gpio_1_d9,  //PIN_G17
    inout logic gpio_1_d10, //PIN_H18
    inout logic gpio_1_d11, //PIN_J18
    inout logic gpio_1_d12, //PIN_J19
    inout logic gpio_1_d13, //PIN_G11
    inout logic gpio_1_d14, //PIN_H10
    inout logic gpio_1_d15, //PIN_J11
    inout logic gpio_1_d16, //PIN_H14
    inout logic gpio_1_d17, //PIN_A15
    inout logic gpio_1_d18, //PIN_J13
    inout logic gpio_1_d19, //PIN_L8
    inout logic gpio_1_d20, //PIN_A14
    inout logic gpio_1_d21, //PIN_B15
    inout logic gpio_1_d22, //PIN_C15
    inout logic gpio_1_d23, //PIN_E14
    inout logic gpio_1_d24, //PIN_E15
    inout logic gpio_1_d25, //PIN_E16
    inout logic gpio_1_d26, //PIN_F14
    inout logic gpio_1_d27, //PIN_F15
    inout logic gpio_1_d28, //PIN_F13
    inout logic gpio_1_d29, //PIN_F12
    inout logic gpio_1_d30, //PIN_G16
    inout logic gpio_1_d31, //PIN_G15
    inout logic gpio_1_d32, //PIN_G13
    inout logic gpio_1_d33, //PIN_G12
    inout logic gpio_1_d34, //PIN_J17
    inout logic gpio_1_d35  //PIN_K16


);
    // -----------------------------------------
    // controle do gerador de estímulos via I/O
    // -----------------------------------------
    logic stim_start_i;
    logic [$clog2(N_EXAMPLES)-1:0] stim_example_sel_i;
    logic [1:0] stim_loop_mode_i;
    logic stim_lr_sel_i;

    assign stim_start_i = sw0;
    assign stim_example_sel_i = sw1;
    assign stim_loop_mode_i = sw3;
    assign stim_lr_sel_i = sw4;

    logic clk;
    logic rst;

    assign clk = gpio_0_d0;
    assign rst = gpio_0_d1; 

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

    assign gpio_0_d3 = i2s_sd_o;


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
    // multiplexação de debug
    // sw2..sw5 continuam reservadas ao stimulus manager
    // sw7:sw6 -> classe de debug
    //   2'b01 = Stimulus Generator
    //   2'b10 = I2S
    //   2'b11 = ACES / Serial
    // sw9:sw8:sw1 -> subgrupo dentro da classe
    // sw0 fica livre para expansão futura
    // -----------------------------------------
    logic [1:0] dbg_mux1_sel;
    logic [2:0] dbg_mux2_sel;

    logic [3:0] hex0_i;
    logic [3:0] hex1_i;
    logic [3:0] hex2_i;
    logic [3:0] hex3_i;
    logic [3:0] hex4_i;
    logic [3:0] hex5_i;

    assign dbg_mux1_sel = {sw6, sw5};
    assign dbg_mux2_sel = {sw9, sw8, sw7};

    always_comb begin
        ledr0 = 1'b0;
        ledr1 = 1'b0;
        ledr2 = 1'b0;
        ledr3 = 1'b0;
        ledr4 = 1'b0;
        ledr5 = 1'b0;
        ledr6 = 1'b0;
        ledr7 = 1'b0;
        ledr8 = 1'b0;
        ledr9 = 1'b0;

        hex0_i = 4'd0;
        hex1_i = 4'd0;
        hex2_i = 4'd0;
        hex3_i = 4'd0;
        hex4_i = 4'd0;
        hex5_i = 4'd0;

        unique case (dbg_mux1_sel)
            2'b01: begin
                ledr0 = stim_ready_o;
                ledr1 = stim_busy_o;
                ledr2 = stim_done_o;
                ledr3 = stim_window_done_o;

                unique case (dbg_mux2_sel)
                    3'd0: begin
                        // HEX0 = stim_current_example_o[2:0]
                        // HEX1..HEX3 = stim_current_point_o
                        // HEX4..HEX5 = stim_rom_addr_dbg_o[7:0]
                        hex0_i = {1'b0, stim_current_example_o};
                        hex1_i = stim_current_point_o[3:0];
                        hex2_i = stim_current_point_o[7:4];
                        hex3_i = {3'b000, stim_current_point_o[8]};
                        hex4_i = stim_rom_addr_dbg_o[3:0];
                        hex5_i = stim_rom_addr_dbg_o[7:4];
                    end

                    3'd1: begin
                        // HEX0..HEX1 = stim_bit_index_o
                        // HEX2 = stim_state_dbg_o
                        hex0_i = stim_bit_index_o[3:0];
                        hex1_i = {2'b00, stim_bit_index_o[5:4]};
                        hex2_i = {1'b0, stim_state_dbg_o};
                    end

                    3'd2: begin
                        // HEX0..HEX5 = stim_current_sample_dbg_o
                        hex0_i = stim_current_sample_dbg_o[3:0];
                        hex1_i = stim_current_sample_dbg_o[7:4];
                        hex2_i = stim_current_sample_dbg_o[11:8];
                        hex3_i = stim_current_sample_dbg_o[15:12];
                        hex4_i = stim_current_sample_dbg_o[19:16];
                        hex5_i = stim_current_sample_dbg_o[23:20];
                    end

                    default: begin
                    end
                endcase
            end

            2'b10: begin
                ledr0 = i2s_sck_o;
                ledr1 = i2s_ws_o;
                ledr2 = mic_chipen_o;
                ledr3 = mic_lr_sel_o;
                ledr4 = i2s_sd_o;

                // classe I2S: LEDs concentram o debug principal
            end

            2'b11: begin
                unique case (dbg_mux2_sel)
                    3'd0: begin
                        // LED0 = sample_valid_mic_o
                        // HEX0..HEX4 = sample_mic_o
                        ledr0 = sample_valid_mic_o;
                        hex0_i = sample_mic_o[3:0];
                        hex1_i = sample_mic_o[7:4];
                        hex2_i = sample_mic_o[11:8];
                        hex3_i = sample_mic_o[15:12];
                        hex4_i = {2'b00, sample_mic_o[17:16]};
                    end

                    3'd1: begin
                        // LED0 = sample_valid_mic_o
                        // HEX0..HEX5 = sample_24_dbg_o
                        ledr0 = sample_valid_mic_o;
                        hex0_i = sample_24_dbg_o[3:0];
                        hex1_i = sample_24_dbg_o[7:4];
                        hex2_i = sample_24_dbg_o[11:8];
                        hex3_i = sample_24_dbg_o[15:12];
                        hex4_i = sample_24_dbg_o[19:16];
                        hex5_i = sample_24_dbg_o[23:20];
                    end

                    3'd2: begin
                        // LED1 = fft_sample_valid_o
                        // HEX0..HEX4 = fft_sample_o
                        ledr1 = fft_sample_valid_o;
                        hex0_i = fft_sample_o[3:0];
                        hex1_i = fft_sample_o[7:4];
                        hex2_i = fft_sample_o[11:8];
                        hex3_i = fft_sample_o[15:12];
                        hex4_i = {2'b00, fft_sample_o[17:16]};
                    end

                    3'd3: begin
                        // LED2 = sact_istream_o
                        // HEX0..HEX4 = sdw_istream_real_o
                        ledr2 = sact_istream_o;
                        hex0_i = sdw_istream_real_o[3:0];
                        hex1_i = sdw_istream_real_o[7:4];
                        hex2_i = sdw_istream_real_o[11:8];
                        hex3_i = sdw_istream_real_o[15:12];
                        hex4_i = {2'b00, sdw_istream_real_o[17:16]};
                    end

                    3'd4: begin
                        // LED2 = sact_istream_o
                        // HEX0..HEX4 = sdw_istream_imag_o
                        ledr2 = sact_istream_o;
                        hex0_i = sdw_istream_imag_o[3:0];
                        hex1_i = sdw_istream_imag_o[7:4];
                        hex2_i = sdw_istream_imag_o[11:8];
                        hex3_i = sdw_istream_imag_o[15:12];
                        hex4_i = {2'b00, sdw_istream_imag_o[17:16]};
                    end

                    3'd5: begin
                        // LED3 = fft_run_o
                        // LED4 = fft_done_o
                        // HEX0 = fft_input_buffer_status_o
                        // HEX1 = fft_status_o
                        // HEX2..HEX3 = bfpexp_o
                        ledr3 = fft_run_o;
                        ledr4 = fft_done_o;
                        hex0_i = {2'b00, fft_input_buffer_status_o};
                        hex1_i = {1'b0, fft_status_o};
                        hex2_i = bfpexp_o[3:0];
                        hex3_i = bfpexp_o[7:4];
                    end

                    3'd6: begin
                        // LED0 = fft_tx_valid_o
                        // LED1 = fft_tx_last_o
                        // HEX0..HEX2 = fft_tx_index_o
                        ledr0 = fft_tx_valid_o;
                        ledr1 = fft_tx_last_o;
                        hex0_i = fft_tx_index_o[3:0];
                        hex1_i = fft_tx_index_o[7:4];
                        hex2_i = {3'b000, fft_tx_index_o[8]};
                    end

                    3'd7: begin
                        // LED0 = fft_tx_valid_o
                        // LED1 = fft_tx_last_o
                        // HEX0..HEX4 = fft_tx_real_o
                        ledr0 = fft_tx_valid_o;
                        ledr1 = fft_tx_last_o;
                        hex0_i = fft_tx_real_o[3:0];
                        hex1_i = fft_tx_real_o[7:4];
                        hex2_i = fft_tx_real_o[11:8];
                        hex3_i = fft_tx_real_o[15:12];
                        hex4_i = {2'b00, fft_tx_real_o[17:16]};
                    end

                    default: begin
                        // LED0 = fft_tx_valid_o
                        // LED1 = fft_tx_last_o
                        // HEX0..HEX4 = fft_tx_imag_o
                        ledr0 = fft_tx_valid_o;
                        ledr1 = fft_tx_last_o;
                        hex0_i = fft_tx_imag_o[3:0];
                        hex1_i = fft_tx_imag_o[7:4];
                        hex2_i = fft_tx_imag_o[11:8];
                        hex3_i = fft_tx_imag_o[15:12];
                        hex4_i = {2'b00, fft_tx_imag_o[17:16]};
                    end
                endcase
            end

            default: begin
            end
        endcase
    end

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

        .mic_sd_i(gpio_1_d0),//mic_sd_internal),
        .mic_lr_sel_i(gpio_1_d1),//stim_lr_sel_i),

        .mic_sck_o(gpio_1_d2),//i2s_sck_o),

        .mic_ws_o(gpio_1_d3),//i2s_ws_o),
        .mic_chipen_o(),//mic_chipen_o),
        .mic_lr_sel_o(gpio_1_d4),//mic_lr_sel_o),


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
    // i2s_stimulus_manager_rom #(
    //     .SAMPLE_BITS(24),
    //     .N_POINTS(N_POINTS),
    //     .N_EXAMPLES(N_EXAMPLES),
    //     .STARTUP_SCK_CYCLES(8),
    //     .INACTIVE_ZERO_SYNTH(0)
    // ) u_i2s_stimulus_manager_rom (
    //     .clk(clk),
    //     .rst(rst),

    //     .start_i(stim_start_i),
    //     .example_sel_i(stim_example_sel_i),
    //     .loop_mode_i(stim_loop_mode_i),

    //     .chipen_i(mic_chipen_o),
    //     .lr_i(mic_lr_sel_o),
    //     .sck_i(i2s_sck_o),
    //     .ws_i(i2s_ws_o),
    //     .sd_o(mic_sd_internal),

    //     .ready_o(stim_ready_o),
    //     .busy_o(stim_busy_o),
    //     .done_o(stim_done_o),
    //     .window_done_o(stim_window_done_o),
    //     .current_example_o(stim_current_example_o),
    //     .current_point_o(stim_current_point_o),
    //     .rom_addr_dbg_o(stim_rom_addr_dbg_o),
    //     .current_sample_dbg_o(stim_current_sample_dbg_o),
    //     .bit_index_o(stim_bit_index_o),
    //     .state_dbg_o(stim_state_dbg_o)
    // );

    assign i2s_sd_o = mic_sd_internal;

endmodule
