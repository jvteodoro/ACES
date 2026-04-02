module top_level_i2s_fft_tx_diag #(
    parameter int FFT_DW                    = 18,
    parameter int I2S_CLOCK_DIV            = 8,
    parameter int I2S_SAMPLE_W             = 18,
    parameter int I2S_SLOT_W               = 32,
    parameter int DIAG_WINDOW_BINS         = 512,
    parameter int DIAG_BFPEXP_HOLD_FRAMES  = 1
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
    input logic gpio_0_d0,  //PIN_N16
    input logic gpio_0_d1,  //PIN_B16
    input logic gpio_0_d2,  //PIN_M16
    output logic gpio_0_d3,  //PIN_C16
    input logic gpio_0_d4,  //PIN_D17
    input logic gpio_0_d5,  //PIN_K20
    input logic gpio_0_d6,  //PIN_K21
    input logic gpio_0_d7,  //PIN_K22
    input logic gpio_0_d8,  //PIN_M20
    input logic gpio_0_d9,  //PIN_M21
    input logic gpio_0_d10, //PIN_N21
    output logic gpio_0_d11, //PIN_R22
    output logic gpio_0_d12, //PIN_R21
    output logic gpio_0_d13, //PIN_T22
    output logic gpio_0_d14, //PIN_N20
    input logic gpio_0_d15, //PIN_N19
    input logic gpio_0_d16, //PIN_M22
    output logic gpio_0_d17, //PIN_P19
    input logic gpio_0_d18, //PIN_L22
    output logic gpio_0_d19, //PIN_P17
    input logic gpio_0_d20, //PIN_P16
    input logic gpio_0_d21, //PIN_M18
    input logic gpio_0_d22, //PIN_L18
    input logic gpio_0_d23, //PIN_L17
    input logic gpio_0_d24, //PIN_L19
    input logic gpio_0_d25, //PIN_K17
    input logic gpio_0_d26, //PIN_K19
    output logic gpio_0_d27, //PIN_P18
    output logic gpio_0_d28, //PIN_R15
    output logic gpio_0_d29, //PIN_R17
    output logic gpio_0_d30, //PIN_R16
    output logic gpio_0_d31, //PIN_T20
    output logic gpio_0_d32, //PIN_T19
    input logic gpio_0_d33, //PIN_T18
    output logic gpio_0_d34, //PIN_T17
    input logic gpio_0_d35, //PIN_T15

    output logic gpio_1_d0,  //PIN_H16
    output logic gpio_1_d1,  //PIN_A12
    output logic gpio_1_d2,  //PIN_H15
    output logic gpio_1_d3,  //PIN_B12
    output logic gpio_1_d4,  //PIN_A13
    output logic gpio_1_d5,  //PIN_B13
    input logic gpio_1_d6,  //PIN_C13
    input logic gpio_1_d7,  //PIN_D13
    input logic gpio_1_d8,  //PIN_G18
    input logic gpio_1_d9,  //PIN_G17
    input logic gpio_1_d10, //PIN_H18
    input logic gpio_1_d11, //PIN_J18
    input logic gpio_1_d12, //PIN_J19
    input logic gpio_1_d13, //PIN_G11
    input logic gpio_1_d14, //PIN_H10
    input logic gpio_1_d15, //PIN_J11
    input logic gpio_1_d16, //PIN_H14
    output logic gpio_1_d17, //PIN_A15
    input logic gpio_1_d18, //PIN_J13
    output logic gpio_1_d19, //PIN_L8
    output logic gpio_1_d20, //PIN_A14
    input logic gpio_1_d21, //PIN_B15
    input logic gpio_1_d22, //PIN_C15
    input logic gpio_1_d23, //PIN_E14
    input logic gpio_1_d24, //PIN_E15
    input logic gpio_1_d25, //PIN_E16
    input logic gpio_1_d26, //PIN_F14
    output logic gpio_1_d27, //PIN_F15
    input logic gpio_1_d28, //PIN_F13
    output logic gpio_1_d29, //PIN_F12
    input logic gpio_1_d30, //PIN_G16
    output logic gpio_1_d31, //PIN_G15
    input logic gpio_1_d32, //PIN_G13
    input logic gpio_1_d33, //PIN_G12
    input logic gpio_1_d34, //PIN_J17
    input logic gpio_1_d35  //PIN_K16
);

    localparam int BFPEXP_W = 8;
    localparam int BIN_IDX_W = (DIAG_WINDOW_BINS <= 1) ? 1 : $clog2(DIAG_WINDOW_BINS);
    localparam logic signed [FFT_DW-1:0] DIAG_FFT_REAL_C = 18'sh15555;
    localparam logic signed [FFT_DW-1:0] DIAG_FFT_IMAG_C = 18'sh0AAAB;
    localparam logic signed [BFPEXP_W-1:0] DIAG_BFPEXP_C = 8'sh12;

    logic clk;
    logic rst;

    logic diag_fft_valid_i;
    logic signed [FFT_DW-1:0] diag_fft_real_i;
    logic signed [FFT_DW-1:0] diag_fft_imag_i;
    logic diag_fft_last_i;
    logic signed [BFPEXP_W-1:0] diag_bfpexp_i;

    logic diag_fft_ready_o;
    logic diag_fifo_full_o;
    logic diag_fifo_empty_o;
    logic diag_overflow_o;
    logic [$clog2(DIAG_WINDOW_BINS + 2)-1:0] diag_fifo_level_o;

    logic tx_i2s_sck_o;
    logic tx_i2s_ws_o;
    logic tx_i2s_sd_o;

    logic [BIN_IDX_W-1:0] diag_bin_index_r;
    logic [15:0] diag_accept_count_r;
    logic [15:0] diag_window_count_r;
    logic diag_overflow_latched_r;
    logic diag_heartbeat_r;

    logic [23:0] dbg_word;
    logic [3:0] hex0_i;
    logic [3:0] hex1_i;
    logic [3:0] hex2_i;
    logic [3:0] hex3_i;
    logic [3:0] hex4_i;
    logic [3:0] hex5_i;

    logic unused_inputs_probe;
    logic diag_accept_w;
    logic diag_window_done_w;

    assign clk = clock_50;
    assign rst = gpio_1_d1;

    assign diag_fft_valid_i = diag_fft_ready_o;
    assign diag_fft_real_i  = DIAG_FFT_REAL_C;
    assign diag_fft_imag_i  = DIAG_FFT_IMAG_C;
    assign diag_fft_last_i  = (diag_bin_index_r == BIN_IDX_W'(DIAG_WINDOW_BINS-1));
    assign diag_bfpexp_i    = DIAG_BFPEXP_C;

    assign diag_accept_w     = diag_fft_valid_i && diag_fft_ready_o;
    assign diag_window_done_w = diag_accept_w && diag_fft_last_i;

    initial begin
        if (FFT_DW != 18)
            $error("top_level_i2s_fft_tx_diag: FFT_DW deve permanecer em 18 para casar com o contrato do host.");
        if (DIAG_WINDOW_BINS < 1)
            $error("top_level_i2s_fft_tx_diag: DIAG_WINDOW_BINS deve ser >= 1.");
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            diag_bin_index_r         <= '0;
            diag_accept_count_r      <= '0;
            diag_window_count_r      <= '0;
            diag_overflow_latched_r  <= 1'b0;
            diag_heartbeat_r         <= 1'b0;
        end else begin
            if (diag_overflow_o)
                diag_overflow_latched_r <= 1'b1;

            if (diag_accept_w) begin
                diag_accept_count_r <= diag_accept_count_r + 1'b1;
                diag_heartbeat_r    <= ~diag_heartbeat_r;

                if (diag_fft_last_i) begin
                    diag_bin_index_r    <= '0;
                    diag_window_count_r <= diag_window_count_r + 1'b1;
                end else begin
                    diag_bin_index_r <= diag_bin_index_r + 1'b1;
                end
            end
        end
    end

    always_comb begin
        dbg_word = '0;

        unique case ({sw1, sw0})
            2'b00: dbg_word = {{16{DIAG_BFPEXP_C[BFPEXP_W-1]}}, DIAG_BFPEXP_C};
            2'b01: dbg_word = {{(24-FFT_DW){DIAG_FFT_REAL_C[FFT_DW-1]}}, DIAG_FFT_REAL_C};
            2'b10: dbg_word = {{(24-FFT_DW){DIAG_FFT_IMAG_C[FFT_DW-1]}}, DIAG_FFT_IMAG_C};
            2'b11: begin
                dbg_word[7:0]   = 8'(diag_bin_index_r);
                dbg_word[15:8]  = 8'(diag_window_count_r);
                dbg_word[19:16] = {diag_overflow_latched_r, diag_fifo_empty_o, diag_fifo_full_o, diag_fft_ready_o};
                dbg_word[23:20] = diag_accept_count_r[3:0];
            end
        endcase
    end

    assign ledr0 = diag_fft_ready_o;
    assign ledr1 = diag_fifo_full_o;
    assign ledr2 = diag_fifo_empty_o;
    assign ledr3 = diag_overflow_latched_r;
    assign ledr4 = diag_accept_w;
    assign ledr5 = tx_i2s_sck_o;
    assign ledr6 = tx_i2s_ws_o;
    assign ledr7 = tx_i2s_sd_o;
    assign ledr8 = diag_fft_last_i;
    assign ledr9 = diag_heartbeat_r;

    assign hex0_i = dbg_word[3:0];
    assign hex1_i = dbg_word[7:4];
    assign hex2_i = dbg_word[11:8];
    assign hex3_i = dbg_word[15:12];
    assign hex4_i = dbg_word[19:16];
    assign hex5_i = dbg_word[23:20];

    hexa7seg hex0(hex0_i, hex0_o);
    hexa7seg hex1(hex1_i, hex1_o);
    hexa7seg hex2(hex2_i, hex2_o);
    hexa7seg hex3(hex3_i, hex3_o);
    hexa7seg hex4(hex4_i, hex4_o);
    hexa7seg hex5(hex5_i, hex5_o);

    i2s_fft_tx_adapter #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .I2S_SAMPLE_W(I2S_SAMPLE_W),
        .I2S_SLOT_W(I2S_SLOT_W),
        .CLOCK_DIV(I2S_CLOCK_DIV),
        .FIFO_DEPTH(DIAG_WINDOW_BINS + 1),
        .BFPEXP_HOLD_FRAMES(DIAG_BFPEXP_HOLD_FRAMES)
    ) u_i2s_fft_tx_adapter (
        .clk(clk),
        .rst(rst),
        .fft_valid_i(diag_fft_valid_i),
        .fft_real_i(diag_fft_real_i),
        .fft_imag_i(diag_fft_imag_i),
        .fft_last_i(diag_fft_last_i),
        .bfpexp_i(diag_bfpexp_i),
        .fft_ready_o(diag_fft_ready_o),
        .fifo_full_o(diag_fifo_full_o),
        .fifo_empty_o(diag_fifo_empty_o),
        .overflow_o(diag_overflow_o),
        .fifo_level_o(diag_fifo_level_o),
        .i2s_sck_o(tx_i2s_sck_o),
        .i2s_ws_o(tx_i2s_ws_o),
        .i2s_sd_o(tx_i2s_sd_o)
    );

    assign gpio_0_d3  = diag_accept_w;
    assign gpio_0_d11 = diag_fft_ready_o;
    assign gpio_0_d12 = diag_fifo_full_o;
    assign gpio_0_d13 = diag_fifo_empty_o;
    assign gpio_0_d14 = diag_overflow_latched_r;
    assign gpio_0_d17 = diag_window_done_w;
    assign gpio_0_d19 = diag_heartbeat_r;

    assign gpio_1_d0  = diag_fft_ready_o;
    assign gpio_1_d1  = diag_fft_last_i;
    assign gpio_1_d2  = diag_accept_w;
    assign gpio_1_d3  = diag_window_done_w;
    assign gpio_1_d4  = diag_overflow_latched_r;
    assign gpio_1_d5  = diag_heartbeat_r;
    assign gpio_1_d17 = sw9 & unused_inputs_probe;
    assign gpio_1_d19 = 1'b0;
    assign gpio_1_d20 = 1'b0;

    // Exporta o stream tagged I2S nos mesmos pinos usados pelo host no top_level_test.
    assign gpio_0_d30 = tx_i2s_sck_o;
    assign gpio_0_d32 = tx_i2s_ws_o;
    assign gpio_0_d34 = tx_i2s_sd_o;
    assign gpio_1_d27 = tx_i2s_sck_o;
    assign gpio_1_d29 = tx_i2s_ws_o;
    assign gpio_1_d31 = tx_i2s_sd_o;

    // Mantem entradas opcionais observaveis para evitar podas agressivas e
    // preservar o mesmo envelope fisico do top_level_test.
//    assign unused_inputs_probe = ^{
//        key0, key1, key2, key3, reset_n,
//        sw2, sw3, sw4, sw5, sw6, sw7, sw8, sw9,
//        clock_50, clock2_50, clock3_50, clock4_50,
//        gpio_0_d2, gpio_0_d4, gpio_0_d5, gpio_0_d6, gpio_0_d7,
//        gpio_0_d8, gpio_0_d9, gpio_0_d10, gpio_0_d15, gpio_0_d16,
//        gpio_0_d18, gpio_0_d20, gpio_0_d21, gpio_0_d22, gpio_0_d23,
//        gpio_0_d24, gpio_0_d25, gpio_0_d26, gpio_0_d27, gpio_0_d28,
//        gpio_0_d29, gpio_0_d30, gpio_0_d31, gpio_0_d32, gpio_0_d33,
//        gpio_0_d34, gpio_0_d35,
//        gpio_1_d6, gpio_1_d7, gpio_1_d8, gpio_1_d9, gpio_1_d10,
//        gpio_1_d11, gpio_1_d12, gpio_1_d13, gpio_1_d14, gpio_1_d15,
//        gpio_1_d16, gpio_1_d18, gpio_1_d21, gpio_1_d22, gpio_1_d23,
//        gpio_1_d24, gpio_1_d25, gpio_1_d26, gpio_1_d28, gpio_1_d30,
//        gpio_1_d32, gpio_1_d33, gpio_1_d34, gpio_1_d35
//    };

endmodule
