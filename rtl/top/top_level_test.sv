module top_level_test #(
    parameter int N_POINTS      = 512,
    parameter int N_EXAMPLES    = 8,
    parameter int I2S_CLOCK_DIV = 8
)(

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
    output logic gpio_1_d17,
    inout logic gpio_1_d18,
    output logic gpio_1_d19,
    output logic gpio_1_d20,
    output logic gpio_1_d21,
    inout logic gpio_1_d22,
    output logic gpio_1_d23,
    inout logic gpio_1_d24,
    output logic gpio_1_d25,
    inout logic gpio_1_d26,
    input logic gpio_1_d27,
    inout logic gpio_1_d28,
    input logic gpio_1_d29,
    output logic gpio_1_d30,
    output logic gpio_1_d31,
    output logic gpio_1_d32,
    inout logic gpio_1_d33,
    output logic gpio_1_d34,
    inout logic gpio_1_d35
);

    localparam int EXAMPLE_SEL_W = (N_EXAMPLES > 1) ? $clog2(N_EXAMPLES) : 1;
    localparam int POINT_W = (N_POINTS > 1) ? $clog2(N_POINTS) : 1;
    localparam int ROM_ADDR_W = ((N_POINTS * N_EXAMPLES) > 1) ? $clog2(N_POINTS * N_EXAMPLES) : 1;

    logic clk;
    logic rst;

    logic stim_start_i;
    logic [EXAMPLE_SEL_W-1:0] stim_example_sel_i;
    logic [1:0] stim_loop_mode_i;
    logic stim_lr_sel_i;

    logic dbg_capture_leds_i;
    logic dbg_capture_hex_i;
    logic dbg_capture_gpio_i;
    logic dbg_capture_clear_i;

    logic stim_ready_o;
    logic stim_busy_o;
    logic stim_done_o;
    logic stim_window_done_o;
    logic [EXAMPLE_SEL_W-1:0] stim_current_example_o;
    logic [POINT_W-1:0] stim_current_point_o;
    logic [ROM_ADDR_W-1:0] stim_rom_addr_dbg_o;
    logic signed [23:0] stim_current_sample_dbg_o;
    logic [5:0] stim_bit_index_o;
    logic [2:0] stim_state_dbg_o;
    logic stim_sd_o;

    logic i2s_sck_o;
    logic i2s_ws_o;
    logic mic_chipen_o;
    logic mic_lr_sel_o;
    logic mic_sd_o;
    logic mic_sd_internal;

    logic [1:0] dbg_stage_sel;
    logic [1:0] dbg_page_sel;
    logic [9:0] dbg_led_live;
    logic [23:0] dbg_hex_live;
    logic [3:0] dbg_gpio_live;
    logic [9:0] dbg_led_capture_r;
    logic [23:0] dbg_hex_capture_r;
    logic [3:0] dbg_gpio_capture_r;
    logic [3:0] hex0_i;
    logic [3:0] hex1_i;
    logic [3:0] hex2_i;
    logic [3:0] hex3_i;
    logic [3:0] hex4_i;
    logic [3:0] hex5_i;

    assign clk = clock_50;
    assign rst = gpio_1_d1;

    assign stim_start_i       = sw0;
    assign stim_example_sel_i = {sw3, sw2, sw1};
    assign stim_loop_mode_i   = {sw5, sw4};
    assign stim_lr_sel_i      = sw6;

    assign dbg_capture_leds_i  = gpio_1_d5;
    assign dbg_capture_hex_i   = gpio_1_d7;
    assign dbg_capture_gpio_i  = gpio_1_d9;
    assign dbg_capture_clear_i = gpio_1_d11;

    assign dbg_stage_sel = {key3, key2};
    assign dbg_page_sel  = {key1, key0};

    assign gpio_0_d12 = dbg_stage_sel[0];
    assign gpio_0_d14 = dbg_stage_sel[1];
    assign gpio_0_d16 = dbg_page_sel[0];
    assign gpio_0_d18 = dbg_page_sel[1];

    assign mic_sd_o = gpio_1_d6;
    assign mic_sd_internal = sw7 ? stim_sd_o : mic_sd_o;

    assign gpio_1_d0  = mic_lr_sel_o;
    assign gpio_1_d2  = i2s_ws_o;
    assign gpio_1_d4  = i2s_sck_o;

    assign gpio_1_d17 = i2s_sck_o;
    assign gpio_1_d19 = i2s_ws_o;
    assign gpio_1_d20 = mic_sd_internal;

    assign gpio_1_d21 = mic_sd_o;
    assign gpio_1_d23 = stim_sd_o;
    assign gpio_1_d25 = sw7;
    assign gpio_1_d30 = mic_chipen_o;
    assign gpio_1_d31 = mic_lr_sel_o;
    assign gpio_1_d32 = stim_busy_o;
    assign gpio_1_d34 = stim_window_done_o;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            dbg_led_capture_r  <= '0;
            dbg_hex_capture_r  <= '0;
            dbg_gpio_capture_r <= '0;
        end else if (dbg_capture_clear_i) begin
            dbg_led_capture_r  <= '0;
            dbg_hex_capture_r  <= '0;
            dbg_gpio_capture_r <= '0;
        end else begin
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
                dbg_led_live[0]   = stim_ready_o;
                dbg_led_live[1]   = stim_busy_o;
                dbg_led_live[2]   = stim_done_o;
                dbg_led_live[3]   = stim_window_done_o;
                dbg_led_live[6:4] = stim_example_sel_i[2:0];
                dbg_led_live[8:7] = stim_loop_mode_i;
                dbg_led_live[9]   = stim_lr_sel_i;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[3:0]   = {1'b0, stim_current_example_o};
                        dbg_hex_live[7:4]   = stim_current_point_o[3:0];
                        dbg_hex_live[11:8]  = stim_current_point_o[7:4];
                        dbg_hex_live[15:12] = {3'b000, stim_current_point_o[8]};
                        dbg_hex_live[19:16] = stim_rom_addr_dbg_o[3:0];
                        dbg_hex_live[23:20] = stim_rom_addr_dbg_o[7:4];
                        dbg_gpio_live       = {stim_window_done_o, stim_done_o, stim_busy_o, stim_ready_o};
                    end
                    2'b01: begin
                        dbg_hex_live[3:0]   = stim_bit_index_o[3:0];
                        dbg_hex_live[7:4]   = {2'b00, stim_bit_index_o[5:4]};
                        dbg_hex_live[11:8]  = {1'b0, stim_state_dbg_o};
                        dbg_hex_live[15:12] = {2'b00, stim_loop_mode_i};
                        dbg_hex_live[19:16] = {1'b0, stim_example_sel_i[2:0]};
                        dbg_hex_live[23:20] = {3'b000, stim_lr_sel_i};
                        dbg_gpio_live       = {stim_state_dbg_o[0], stim_state_dbg_o[1], stim_state_dbg_o[2], mic_sd_internal};
                    end
                    default: begin
                        dbg_hex_live  = stim_current_sample_dbg_o;
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
                dbg_led_live[0] = i2s_sck_o;
                dbg_led_live[1] = i2s_ws_o;
                dbg_led_live[2] = mic_chipen_o;
                dbg_led_live[3] = mic_lr_sel_o;
                dbg_led_live[4] = mic_sd_o;
                dbg_led_live[5] = stim_sd_o;
                dbg_led_live[6] = mic_sd_internal;
                dbg_led_live[7] = sw7;
                dbg_led_live[8] = stim_busy_o;
                dbg_led_live[9] = stim_window_done_o;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[3:0]   = {3'b000, i2s_sck_o};
                        dbg_hex_live[7:4]   = {3'b000, i2s_ws_o};
                        dbg_hex_live[11:8]  = {3'b000, mic_sd_o};
                        dbg_hex_live[15:12] = {3'b000, stim_sd_o};
                        dbg_hex_live[19:16] = {3'b000, mic_sd_internal};
                        dbg_hex_live[23:20] = {3'b000, sw7};
                        dbg_gpio_live       = {mic_lr_sel_o, mic_chipen_o, i2s_ws_o, i2s_sck_o};
                    end
                    2'b01: begin
                        dbg_hex_live[3:0]   = {3'b000, gpio_1_d17};
                        dbg_hex_live[7:4]   = {3'b000, gpio_1_d19};
                        dbg_hex_live[11:8]  = {3'b000, gpio_1_d20};
                        dbg_hex_live[15:12] = {3'b000, gpio_1_d21};
                        dbg_hex_live[19:16] = {3'b000, gpio_1_d23};
                        dbg_hex_live[23:20] = {3'b000, gpio_1_d25};
                        dbg_gpio_live       = {gpio_1_d25, gpio_1_d23, gpio_1_d21, gpio_1_d20};
                    end
                    default: begin
                        dbg_hex_live[3:0]   = {3'b000, gpio_1_d30};
                        dbg_hex_live[7:4]   = {3'b000, gpio_1_d31};
                        dbg_hex_live[11:8]  = {3'b000, gpio_1_d32};
                        dbg_hex_live[15:12] = {3'b000, gpio_1_d34};
                        dbg_hex_live[19:16] = {3'b000, sw7};
                        dbg_hex_live[23:20] = {3'b000, stim_lr_sel_i};
                        dbg_gpio_live       = {gpio_1_d34, gpio_1_d32, gpio_1_d31, gpio_1_d30};
                    end
                endcase
            end

            2'b10: begin
                dbg_led_live[0] = gpio_1_d17;
                dbg_led_live[1] = gpio_1_d19;
                dbg_led_live[2] = gpio_1_d20;
                dbg_led_live[3] = gpio_1_d21;
                dbg_led_live[4] = gpio_1_d23;
                dbg_led_live[5] = gpio_1_d25;
                dbg_led_live[6] = gpio_1_d30;
                dbg_led_live[7] = gpio_1_d31;
                dbg_led_live[8] = gpio_1_d32;
                dbg_led_live[9] = gpio_1_d34;

                unique case (dbg_page_sel)
                    2'b00: begin
                        dbg_hex_live[3:0]   = {3'b000, stim_ready_o};
                        dbg_hex_live[7:4]   = {3'b000, stim_busy_o};
                        dbg_hex_live[11:8]  = {3'b000, stim_done_o};
                        dbg_hex_live[15:12] = {3'b000, stim_window_done_o};
                        dbg_hex_live[19:16] = {3'b000, stim_start_i};
                        dbg_hex_live[23:20] = {3'b000, sw7};
                        dbg_gpio_live       = {stim_window_done_o, stim_done_o, stim_busy_o, stim_ready_o};
                    end
                    2'b01: begin
                        dbg_hex_live[3:0]   = {3'b000, dbg_stage_sel[0]};
                        dbg_hex_live[7:4]   = {3'b000, dbg_stage_sel[1]};
                        dbg_hex_live[11:8]  = {3'b000, dbg_page_sel[0]};
                        dbg_hex_live[15:12] = {3'b000, dbg_page_sel[1]};
                        dbg_hex_live[19:16] = {3'b000, dbg_capture_leds_i};
                        dbg_hex_live[23:20] = {3'b000, dbg_capture_hex_i};
                        dbg_gpio_live       = {dbg_capture_clear_i, dbg_capture_gpio_i, dbg_capture_hex_i, dbg_capture_leds_i};
                    end
                    default: begin
                        dbg_hex_live[3:0]   = dbg_gpio_capture_r;
                        dbg_hex_live[7:4]   = dbg_hex_capture_r[3:0];
                        dbg_hex_live[11:8]  = dbg_hex_capture_r[7:4];
                        dbg_hex_live[15:12] = dbg_hex_capture_r[11:8];
                        dbg_hex_live[19:16] = dbg_hex_capture_r[15:12];
                        dbg_hex_live[23:20] = dbg_hex_capture_r[19:16];
                        dbg_gpio_live       = dbg_gpio_capture_r;
                    end
                endcase
            end

            default: begin
                dbg_led_live[0] = i2s_sck_o;
                dbg_led_live[1] = i2s_ws_o;
                dbg_led_live[2] = mic_sd_o;
                dbg_led_live[3] = stim_sd_o;
                dbg_led_live[4] = mic_sd_internal;
                dbg_led_live[5] = mic_chipen_o;
                dbg_led_live[6] = mic_lr_sel_o;
                dbg_led_live[7] = stim_ready_o;
                dbg_led_live[8] = stim_busy_o;
                dbg_led_live[9] = stim_window_done_o;

                dbg_hex_live[3:0]   = {3'b000, i2s_sck_o};
                dbg_hex_live[7:4]   = {3'b000, i2s_ws_o};
                dbg_hex_live[11:8]  = {3'b000, mic_sd_internal};
                dbg_hex_live[15:12] = {3'b000, sw7};
                dbg_hex_live[19:16] = {3'b000, stim_busy_o};
                dbg_hex_live[23:20] = {3'b000, stim_window_done_o};
                dbg_gpio_live       = {stim_window_done_o, stim_busy_o, sw7, mic_sd_internal};
            end
        endcase

        {ledr9, ledr8, ledr7, ledr6, ledr5, ledr4, ledr3, ledr2, ledr1, ledr0} = dbg_led_capture_r;

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

    aces #(
        .I2S_CLOCK_DIV(I2S_CLOCK_DIV)
    ) u_aces (
        .clk(clk),
        .rst(rst),
        .mic_lr_sel_i(stim_lr_sel_i),
        .mic_sck_o(i2s_sck_o),
        .mic_ws_o(i2s_ws_o),
        .mic_chipen_o(mic_chipen_o),
        .mic_lr_sel_o(mic_lr_sel_o)
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
        .sck_i(i2s_sck_o),
        .ws_i(i2s_ws_o),
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

endmodule
