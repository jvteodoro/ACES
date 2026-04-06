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
    input logic gpio_0_d5,  //PIN_K20
    inout logic gpio_0_d6,  //PIN_K21
    input logic gpio_0_d7,  //PIN_K22
    inout logic gpio_0_d8,  //PIN_M20
    input logic gpio_0_d9,  //PIN_M21
    inout logic gpio_0_d10, //PIN_N21
    input logic gpio_0_d11, //PIN_R22
    output logic gpio_0_d12, //PIN_R21
    input logic gpio_0_d13, //PIN_T22
    output logic gpio_0_d14, //PIN_N20
    input logic gpio_0_d15, //PIN_N19
    output logic gpio_0_d16, //PIN_M22
    input logic gpio_0_d17, //PIN_P19
    output logic gpio_0_d18, //PIN_L22
    input logic gpio_0_d19, //PIN_P17
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
    input logic gpio_0_d35, //PIN_T15

    output logic gpio_1_d0,  //PIN_H16 I2S_MIC_LR
    input logic gpio_1_d1,  //PIN_A12 reset (DIO:0)
    output logic gpio_1_d2,  //PIN_H15 I2S_MIC_WS
    inout logic gpio_1_d3,  //PIN_B12
    output logic gpio_1_d4,  //PIN_A13 I2S_MIC_SCK
    input logic gpio_1_d5,  //PIN_B13 dbg_capture_leds (DIO:1)
    input logic gpio_1_d6,  //PIN_C13 I2S_MIC_SD
    input logic gpio_1_d7,  //PIN_D13 dbg_capture_hex (DIO:2)
    inout logic gpio_1_d8,  //PIN_G18
    input logic gpio_1_d9,  //PIN_G17 dbg_capture_gpio (DIO:3)
    inout logic gpio_1_d10, //PIN_H18
    input logic gpio_1_d11, //PIN_J18 dbg_capture_clear (DIO:4)
    inout logic gpio_1_d12, //PIN_J19
    input logic gpio_1_d13, //PIN_G11 stage_1 (DIO:5)
    inout logic gpio_1_d14, //PIN_H10
    input logic gpio_1_d15, //PIN_J11 stage_0 (DIO:6)
    inout logic gpio_1_d16, //PIN_H14
    input logic gpio_1_d17, //PIN_A15 page_1 (DIO:7)
    inout logic gpio_1_d18, //PIN_J13
    input logic gpio_1_d19, //PIN_L8 page_0 (DIO:8)
    inout logic gpio_1_d20, //PIN_A14
    output logic gpio_1_d21, //PIN_B15 SPI_window_ready_mirror (DIO:9)
    inout logic gpio_1_d22, //PIN_C15
    output logic gpio_1_d23, //PIN_E14 SPI_overflow (DIO:10)
    inout logic gpio_1_d24, //PIN_E15
    output logic gpio_1_d25, //PIN_E16 SPI_window_ready (RPi: GPIO23)
    inout logic gpio_1_d26, //PIN_F14
    input logic gpio_1_d27, //PIN_F15 SPI_SCLK (RPi: GPIO11)
    inout logic gpio_1_d28, //PIN_F13
    input logic gpio_1_d29, //PIN_F12 SPI_CS_N (RPi: GPIO8)
    output logic gpio_1_d30, //PIN_G16 SPI_window_ready_mirror
    output logic gpio_1_d31, //PIN_G15 SPI_MISO (RPi: GPIO9)
    output logic gpio_1_d32, //PIN_G13 SPI_overflow_mirror
    inout logic gpio_1_d33, //PIN_G12
    output logic gpio_1_d34, //PIN_J17 SPI_MISO_mirror (DIO:11)
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
    assign stim_example_sel_i = {sw3, sw2, sw1};
    assign stim_loop_mode_i = {sw5, sw4};
    assign stim_lr_sel_i = sw6;
	 

    logic clk;
    logic rst;

    assign clk = clock_50;
    // With the onboard 50 MHz clock selected, keep reset on a stable onboard source
    // instead of an external GPIO that may now be left floating.
    assign rst = gpio_1_d1;

    logic dbg_capture_leds_i;
    logic dbg_capture_hex_i;
    logic dbg_capture_gpio_i;
    logic dbg_capture_clear_i;

    assign dbg_capture_leds_i  = gpio_1_d5;
    assign dbg_capture_hex_i   = gpio_1_d7;
    assign dbg_capture_gpio_i  = gpio_1_d9;
    assign dbg_capture_clear_i = gpio_1_d11;

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
	 logic stim_sd_o;

    // -----------------------------------------
    // debug dos sinais I2S
    // -----------------------------------------
    logic i2s_sck_o;
    logic i2s_ws_o;
    logic mic_chipen_o;
    logic mic_lr_sel_o;
    logic i2s_sd_o;
	 logic mic_sd_o;

	 assign gpio_1_d0 = mic_lr_sel_o;
	 assign gpio_1_d2 = i2s_ws_o;
	 assign gpio_1_d4 = i2s_sck_o;
	 //assign i2s_sd_o = gpio_1_d7;
	 assign mic_sd_o = gpio_1_d6;


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
    logic tx_spi_sclk_i;
    logic tx_spi_cs_n_i;
    logic tx_spi_miso_o;
    logic tx_spi_window_ready_o;
    logic tx_overflow_o;
    logic tx_spi_master_sclk_o;
    logic tx_spi_master_cs_n_o;
    logic tx_spi_master_mosi_o;
    logic tx_spi_master_frame_pending_o;
    logic tx_spi_master_active_o;
    logic tx_master_overflow_o;
	
	 logic select_audio_source;
	 assign select_audio_source = sw7;
    logic mic_sd_internal;
	 assign mic_sd_internal = (select_audio_source) ? stim_sd_o: mic_sd_o;
    assign tx_spi_sclk_i = gpio_1_d27;
    assign tx_spi_cs_n_i = gpio_1_d29;
	 
    // -----------------------------------------
    // multiplexação de debug
    // chaves:
    //   key3:key2 -> estágio de debug
    //   key1:key0 -> página dentro do estágio
    //   sw0       -> start do stimulus manager
    //   sw3:sw1   -> seleção do exemplo
    //   sw5:sw4   -> loop mode
    //   sw6       -> seleção do canal LR
    //
    // saídas físicas:
    //   LEDs / HEX / GPIO de debug recebem snapshots registradas
    //   quando os enables vindos dos GPIOs são pulsados
    // -----------------------------------------
    logic [1:0] dbg_stage_sel;
    logic [1:0] dbg_page_sel;

    logic [9:0] dbg_led_live;
    logic [23:0] dbg_hex_live;
    logic [3:0] dbg_gpio_live;
    logic unused_inputs_probe;

    logic [9:0] dbg_led_capture_r;
    logic [23:0] dbg_hex_capture_r;
    logic [3:0] dbg_gpio_capture_r;

    logic [3:0] hex0_i;
    logic [3:0] hex1_i;
    logic [3:0] hex2_i;
    logic [3:0] hex3_i;
    logic [3:0] hex4_i;
    logic [3:0] hex5_i;

    assign dbg_stage_sel = {gpio_1_d13, gpio_1_d15};
    assign dbg_page_sel  = {gpio_1_d17, gpio_1_d19};
    // Keep the selector inputs dedicated to reads; mirror them on separate spare GPIOs.
	 assign gpio_0_d12 = dbg_stage_sel[0];
	 assign gpio_0_d14 = dbg_stage_sel[1];
	 assign gpio_0_d16 = dbg_page_sel[0];
	 assign gpio_0_d18 = dbg_page_sel[1];

    // Keep optional board pins observable by synthesis so Quartus does not
    // prune them as completely unused top-level inputs.
//    assign unused_inputs_probe = ^{
//        key0, key1, key2, key3, reset_n,
//        sw8, sw9,
//        clock_50, clock2_50, clock3_50, clock4_50,
//        gpio_0_d15, gpio_0_d16, gpio_0_d18,
//        gpio_0_d21, gpio_0_d22, gpio_0_d23, gpio_0_d24, gpio_0_d25,
//        gpio_0_d26, gpio_0_d27, gpio_0_d28, gpio_0_d29, gpio_0_d30,
//        gpio_0_d31, gpio_0_d32, gpio_0_d33, gpio_0_d34, gpio_0_d35,
//        gpio_1_d0, gpio_1_d6, gpio_1_d7, gpio_1_d8, gpio_1_d9,
//        gpio_1_d10, gpio_1_d11, gpio_1_d12, gpio_1_d13, gpio_1_d14,
//        gpio_1_d15, gpio_1_d16, gpio_1_d17, gpio_1_d18, gpio_1_d19, gpio_1_d20,
//        gpio_1_d21, gpio_1_d22, gpio_1_d23, gpio_1_d24, gpio_1_d25,
//        gpio_1_d26, gpio_1_d28, gpio_1_d30, gpio_1_d32, gpio_1_d33, gpio_1_d34, gpio_1_d35
//    };

	 

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dbg_led_capture_r  <= '0;
            dbg_hex_capture_r  <= '0;
            dbg_gpio_capture_r <= '0;
        end
        else if (dbg_capture_clear_i) begin
            dbg_led_capture_r  <= '0;
            dbg_hex_capture_r  <= '0;
            dbg_gpio_capture_r <= '0;
        end
        else begin
            if (dbg_capture_leds_i)
                dbg_led_capture_r <= dbg_led_live;

            if (dbg_capture_hex_i)
                dbg_hex_capture_r <= dbg_hex_live;

            if (dbg_capture_gpio_i)
                dbg_gpio_capture_r <= dbg_gpio_live;
        end
    end

    always_comb begin
        dbg_led_live  = '0;
        dbg_hex_live  = '0;
        dbg_gpio_live = '0;

        unique case (dbg_stage_sel)
            2'b00: begin
                // Stimulus manager
                dbg_led_live[0] = stim_ready_o;
                dbg_led_live[1] = stim_busy_o;
                dbg_led_live[2] = stim_done_o;
                dbg_led_live[3] = stim_window_done_o;
                dbg_led_live[6:4] = stim_example_sel_i[2:0];
                dbg_led_live[8:7] = stim_loop_mode_i;
                dbg_led_live[9] = stim_lr_sel_i;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[3:0]    = {1'b0, stim_current_example_o};
                        dbg_hex_live[7:4]    = stim_current_point_o[3:0];
                        dbg_hex_live[11:8]   = stim_current_point_o[7:4];
                        dbg_hex_live[15:12]  = {3'b000, stim_current_point_o[8]};
                        dbg_hex_live[19:16]  = stim_rom_addr_dbg_o[3:0];
                        dbg_hex_live[23:20]  = stim_rom_addr_dbg_o[7:4];
                        dbg_gpio_live        = {
                            stim_window_done_o,
                            stim_done_o,
                            stim_busy_o,
                            stim_ready_o
                        };
                    end

                    2'b01: begin
                        dbg_hex_live[3:0]    = stim_bit_index_o[3:0];
                        dbg_hex_live[7:4]    = {2'b00, stim_bit_index_o[5:4]};
                        dbg_hex_live[11:8]   = {1'b0, stim_state_dbg_o};
                        dbg_hex_live[15:12]  = {2'b00, stim_loop_mode_i};
                        dbg_hex_live[19:16]  = {1'b0, stim_example_sel_i[2:0]};
                        dbg_hex_live[23:20]  = {3'b000, stim_lr_sel_i};
                        dbg_gpio_live        = {
                            stim_state_dbg_o[0],
                            stim_state_dbg_o[1],
                            stim_state_dbg_o[2],
                            mic_sd_internal
                        };
                    end

                    2'b10,
                    2'b11: begin
                        dbg_hex_live = stim_current_sample_dbg_o;
                        dbg_gpio_live = {
                            stim_current_sample_dbg_o[23],
                            stim_current_sample_dbg_o[22],
                            stim_current_sample_dbg_o[21],
                            stim_current_sample_dbg_o[20]
                        };
                    end
                endcase
            end

            2'b01: begin
                // Interface I2S
                dbg_led_live[0] = i2s_sck_o;
                dbg_led_live[1] = i2s_ws_o;
                dbg_led_live[2] = mic_chipen_o;
                dbg_led_live[3] = mic_lr_sel_o;
                dbg_led_live[4] = i2s_sd_o;
                dbg_led_live[5] = sample_valid_mic_o;
                dbg_led_live[6] = fft_sample_valid_o;
                dbg_led_live[7] = sact_istream_o;
                dbg_led_live[8] = fft_run_o;
                dbg_led_live[9] = fft_done_o;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[3:0]   = sample_24_dbg_o[3:0];
                        dbg_hex_live[7:4]   = sample_24_dbg_o[7:4];
                        dbg_hex_live[11:8]  = sample_24_dbg_o[11:8];
                        dbg_hex_live[15:12] = sample_24_dbg_o[15:12];
                        dbg_hex_live[19:16] = sample_24_dbg_o[19:16];
                        dbg_hex_live[23:20] = sample_24_dbg_o[23:20];
                        dbg_gpio_live       = {
                            mic_lr_sel_o,
                            mic_chipen_o,
                            i2s_ws_o,
                            i2s_sck_o
                        };
                    end

                    2'b01: begin
                        dbg_hex_live[17:0]  = sample_mic_o;
                        dbg_gpio_live       = {
                            sample_valid_mic_o,
                            i2s_sd_o,
                            i2s_ws_o,
                            i2s_sck_o
                        };
                    end

                    2'b10,
                    2'b11: begin
                        dbg_hex_live[17:0]  = fft_sample_o;
                        dbg_gpio_live       = {
                            sact_istream_o,
                            fft_sample_valid_o,
                            i2s_ws_o,
                            i2s_sck_o
                        };
                    end
                endcase
            end

            2'b10: begin
                // Ingest / controle da FFT
                dbg_led_live[0] = sample_valid_mic_o;
                dbg_led_live[1] = fft_sample_valid_o;
                dbg_led_live[2] = sact_istream_o;
                dbg_led_live[3] = fft_run_o;
                dbg_led_live[4] = fft_done_o;
                dbg_led_live[6:5] = fft_input_buffer_status_o;
                dbg_led_live[9:7] = fft_status_o;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[17:0]  = sdw_istream_real_o;
                        dbg_gpio_live       = {
                            fft_done_o,
                            fft_run_o,
                            fft_sample_valid_o,
                            sact_istream_o
                        };
                    end

                    2'b01: begin
                        dbg_hex_live[17:0]  = sdw_istream_imag_o;
                        dbg_gpio_live       = {
                            fft_done_o,
                            fft_run_o,
                            fft_sample_valid_o,
                            sact_istream_o
                        };
                    end

                    2'b10,
                    2'b11: begin
                        dbg_hex_live[3:0]   = bfpexp_o[3:0];
                        dbg_hex_live[7:4]   = bfpexp_o[7:4];
                        dbg_hex_live[11:8]  = {1'b0, fft_status_o};
                        dbg_hex_live[15:12] = {2'b00, fft_input_buffer_status_o};
                        dbg_gpio_live       = {
                            fft_status_o[0],
                            fft_status_o[1],
                            fft_status_o[2],
                            fft_done_o
                        };
                    end
                endcase
            end

            2'b11: begin
                // Saída serial / bins da FFT
                dbg_led_live[0] = fft_tx_valid_o;
                dbg_led_live[1] = fft_tx_last_o;
                dbg_led_live[2] = fft_done_o;
                dbg_led_live[3] = fft_run_o;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[$clog2(FFT_LENGTH)-1:0] = fft_tx_index_o;
                        dbg_gpio_live = {
                            fft_tx_last_o,
                            fft_tx_valid_o,
                            fft_done_o,
                            fft_run_o
                        };
                    end

                    2'b01: begin
                        dbg_hex_live[17:0] = fft_tx_real_o;
                        dbg_gpio_live = {
                            fft_tx_real_o[17],
                            fft_tx_valid_o,
                            fft_tx_last_o,
                            fft_done_o
                        };
                    end

                    2'b10,
                    2'b11: begin
                        dbg_hex_live[17:0] = fft_tx_imag_o;
                        dbg_gpio_live = {
                            fft_tx_imag_o[17],
                            fft_tx_valid_o,
                            fft_tx_last_o,
                            fft_done_o
                        };
                    end
                endcase
            end
        endcase

        ledr0 = dbg_led_capture_r[0];
        ledr1 = dbg_led_capture_r[1];
        ledr2 = dbg_led_capture_r[2];
        ledr3 = dbg_led_capture_r[3];
        ledr4 = dbg_led_capture_r[4];
        ledr5 = dbg_led_capture_r[5];
        ledr6 = dbg_led_capture_r[6];
        ledr7 = dbg_led_capture_r[7];
        ledr8 = dbg_led_capture_r[8];
        ledr9 = dbg_led_capture_r[9];

        hex0_i = dbg_hex_capture_r[3:0];
        hex1_i = dbg_hex_capture_r[7:4];
        hex2_i = dbg_hex_capture_r[11:8];
        hex3_i = dbg_hex_capture_r[15:12];
        hex4_i = dbg_hex_capture_r[19:16];
        hex5_i = dbg_hex_capture_r[23:20];
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
        .fft_tx_last_o(fft_tx_last_o),
        .tx_spi_sclk_i(tx_spi_sclk_i),
        .tx_spi_cs_n_i(tx_spi_cs_n_i),
        .tx_spi_miso_o(tx_spi_miso_o),
        .tx_spi_window_ready_o(tx_spi_window_ready_o),
        .tx_overflow_o(tx_overflow_o),
        .tx_spi_master_sclk_o(tx_spi_master_sclk_o),
        .tx_spi_master_cs_n_o(tx_spi_master_cs_n_o),
        .tx_spi_master_mosi_o(tx_spi_master_mosi_o),
        .tx_spi_master_frame_pending_o(tx_spi_master_frame_pending_o),
        .tx_spi_master_active_o(tx_spi_master_active_o),
        .tx_master_overflow_o(tx_master_overflow_o)
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
        .sd_o(stim_sd_o),//mic_sd_internal),

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
//    assign gpio_1_d17 = tx_i2s_sck_o;
//    assign gpio_1_d19 = tx_i2s_ws_o;
//    assign gpio_1_d20 = tx_i2s_sd_o;
//    assign gpio_0_d3 = dbg_gpio_capture_r[0];
//    assign gpio_1_d2 = dbg_gpio_capture_r[1];
//    assign gpio_1_d3 = dbg_gpio_capture_r[2];
//    assign gpio_1_d4 = dbg_gpio_capture_r[3] ^ (sw9 & unused_inputs_probe);
    
    // JP2 segue o pinout da bancada atual:
    // D27/D29 entram com SCLK/CS_N do host, D31 leva MISO ao host
    // e D21/D23/D30/D32/D34 espelham sinais de status/retorno em DIO.
	 assign gpio_1_d21 = tx_spi_window_ready_o;
	 assign gpio_1_d23 = tx_overflow_o;
	 assign gpio_1_d25 = tx_spi_window_ready_o;
	 assign gpio_1_d30 = tx_spi_window_ready_o;
	 assign gpio_1_d31 = tx_spi_miso_o;
	 assign gpio_1_d32 = tx_overflow_o;
	 assign gpio_1_d34 = tx_spi_miso_o;

endmodule
