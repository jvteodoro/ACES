module i2s_stimulus_manager #(
    parameter int SAMPLE_BITS         = 24,
    parameter int ROM_ADDR_W          = 16,
    parameter bit GENERATE_CLOCKS     = 0,
    parameter int CLOCK_DIV           = 16,
    parameter int STARTUP_SCK_CYCLES  = 218,
    parameter bit INACTIVE_ZERO_SYNTH = 1
)(
    input  logic clk,
    input  logic rst,

    // Extra control pins
    input  logic start_i,
    input  logic loop_enable_i,
    input  logic [ROM_ADDR_W-1:0] base_addr_i,
    input  logic [ROM_ADDR_W-1:0] signal_length_i,

    // INMP441-like pins
    input  logic chipen_i,
    input  logic lr_i,        // 0: left, 1: right

    // External serial clocks
    input  logic sck_i,
    input  logic ws_i,

    // Optional internal serial clocks
    output logic sck_o,
    output logic ws_o,

    // Serial data output
    output logic sd_o,

    // Synchronous ROM interface
    output logic [ROM_ADDR_W-1:0] rom_addr_o,
    input  logic signed [SAMPLE_BITS-1:0] rom_data_i,

    // Status / debug
    output logic busy_o,
    output logic done_o,
    output logic ready_o,
    output logic [ROM_ADDR_W-1:0] sample_index_o,
    output logic [5:0] bit_index_o,
    output logic signed [SAMPLE_BITS-1:0] current_sample_dbg_o
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_WAIT_READY,
        ST_PRIME_ADDR,
        ST_WAIT_ROM_1,
        ST_WAIT_ROM_2,
        ST_WAIT_TARGET_HALF,
        ST_SHIFT
    } state_t;

    state_t state;

    logic start_d, start_pulse;
    logic sck_int, ws_int;
    logic sck_prev, ws_prev;
    logic sck_rise, sck_fall;
    logic [15:0] clk_div_cnt;
    logic [5:0] frame_bit_cnt;

    logic [ROM_ADDR_W-1:0] sample_index;
    logic [ROM_ADDR_W-1:0] active_addr;
    logic signed [SAMPLE_BITS-1:0] current_sample;
    logic [5:0] bit_index;

    logic chipen_prev;
    localparam int STARTUP_W = (STARTUP_SCK_CYCLES <= 1) ? 1 : $clog2(STARTUP_SCK_CYCLES+1);
    logic [STARTUP_W-1:0] startup_count;
    logic startup_active;

    wire target_half_active = (lr_i == 1'b0) ? (ws_int == 1'b0) : (ws_int == 1'b1);
    wire target_half_start  = (lr_i == 1'b0) ? (ws_prev == 1'b1 && ws_int == 1'b0)
                                             : (ws_prev == 1'b0 && ws_int == 1'b1);

    assign sample_index_o       = sample_index;
    assign bit_index_o          = bit_index;
    assign current_sample_dbg_o = current_sample;
    assign rom_addr_o           = active_addr;
    assign ready_o              = ~startup_active;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) start_d <= 1'b0;
        else     start_d <= start_i;
    end
    assign start_pulse = start_i & ~start_d;

    generate
        if (GENERATE_CLOCKS) begin : g_gen_clks
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    clk_div_cnt   <= '0;
                    sck_int       <= 1'b0;
                    ws_int        <= 1'b1;
                    frame_bit_cnt <= '0;
                end else if (busy_o) begin
                    if (clk_div_cnt == CLOCK_DIV-1) begin
                        clk_div_cnt <= '0;
                        sck_int     <= ~sck_int;

                        if (!sck_int) begin
                            if (frame_bit_cnt == 6'd63)
                                frame_bit_cnt <= 6'd0;
                            else
                                frame_bit_cnt <= frame_bit_cnt + 1'b1;

                            ws_int <= (frame_bit_cnt < 6'd32) ? 1'b1 : 1'b0;
                        end
                    end else begin
                        clk_div_cnt <= clk_div_cnt + 1'b1;
                    end
                end else begin
                    clk_div_cnt   <= '0;
                    sck_int       <= 1'b0;
                    ws_int        <= 1'b1;
                    frame_bit_cnt <= '0;
                end
            end

            assign sck_o = sck_int;
            assign ws_o  = ws_int;
        end else begin : g_ext_clks
            assign sck_int = sck_i;
            assign ws_int  = ws_i;
            assign sck_o   = 1'b0;
            assign ws_o    = 1'b0;
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sck_prev    <= 1'b0;
            ws_prev     <= 1'b1;
            chipen_prev <= 1'b0;
        end else begin
            sck_prev    <= sck_int;
            ws_prev     <= ws_int;
            chipen_prev <= chipen_i;
        end
    end

    assign sck_rise =  sck_int & ~sck_prev;
    assign sck_fall = ~sck_int &  sck_prev;

    // Approximate enable/startup behavior after CHIPEN rises
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            startup_count  <= '0;
            startup_active <= 1'b1;
        end else begin
            if (!chipen_i) begin
                startup_count  <= '0;
                startup_active <= 1'b1;
            end else begin
                if (!chipen_prev && chipen_i) begin
                    startup_count  <= '0;
                    startup_active <= 1'b1;
                end else if (startup_active && sck_rise) begin
                    if (startup_count == STARTUP_SCK_CYCLES-1) begin
                        startup_active <= 1'b0;
                    end else begin
                        startup_count <= startup_count + 1'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= ST_IDLE;
            active_addr    <= '0;
            sample_index   <= '0;
            current_sample <= '0;
            bit_index      <= 6'd0;
            sd_o           <= 1'b0;
            busy_o         <= 1'b0;
            done_o         <= 1'b0;
        end else begin
            done_o <= 1'b0;

            case (state)
                ST_IDLE: begin
                    sd_o         <= 1'b0;
                    bit_index    <= 6'd0;
                    sample_index <= '0;
                    active_addr  <= base_addr_i;
                    busy_o       <= 1'b0;

                    if (start_pulse && chipen_i) begin
                        busy_o <= 1'b1;
                        if (startup_active)
                            state <= ST_WAIT_READY;
                        else
                            state <= ST_PRIME_ADDR;
                    end
                end

                ST_WAIT_READY: begin
                    if (!chipen_i) begin
                        busy_o <= 1'b0;
                        state  <= ST_IDLE;
                    end else if (!startup_active) begin
                        state <= ST_PRIME_ADDR;
                    end
                end
                
                ST_PRIME_ADDR: begin
                    active_addr <= base_addr_i + sample_index;
                    state       <= ST_WAIT_ROM_1;
                end

                ST_WAIT_ROM_1: begin
                    state <= ST_WAIT_ROM_2;
                end

                ST_WAIT_ROM_2: begin
                    current_sample <= rom_data_i;
                    bit_index      <= 6'd0;
                    state          <= ST_WAIT_TARGET_HALF;
                end

                ST_WAIT_TARGET_HALF: begin
                    if (!chipen_i) begin
                        busy_o <= 1'b0;
                        sd_o   <= 1'b0;
                        state  <= ST_IDLE;
                    end else if (target_half_start) begin
                        bit_index <= 6'd0;
                        state     <= ST_SHIFT;
                    end
                end

                ST_SHIFT: begin
                    if (!chipen_i) begin
                        busy_o <= 1'b0;
                        sd_o   <= 1'b0;
                        state  <= ST_IDLE;
                    end else if (sck_fall) begin
                        if (target_half_active) begin
                            // bit 0  = atraso I2S
                            // bits 1..24 = current_sample[23:0], MSB-first
                            // bits 25..31 = 0
                            if (bit_index == 6'd0) begin
                                sd_o <= 1'b0;
                            end else if (bit_index >= 6'd1 && bit_index <= 6'd24) begin
                                sd_o <= current_sample[SAMPLE_BITS - bit_index];
                            end else begin
                                sd_o <= 1'b0;
                            end
                        end else begin
                `ifdef SYNTHESIS
                            sd_o <= 1'b0;
                `else
                            if (INACTIVE_ZERO_SYNTH)
                                sd_o <= 1'b0;
                            else
                                sd_o <= 1'bz;
                `endif
                        end

                        if (bit_index == 6'd31) begin
                            bit_index <= 6'd0;

                            // terminou o slot ativo atual -> próxima amostra
                            if (sample_index + 1 >= signal_length_i) begin
                                if (loop_enable_i) begin
                                    sample_index <= '0;
                                    state        <= ST_PRIME_ADDR;
                                end else begin
                                    busy_o <= 1'b0;
                                    done_o <= 1'b1;
                                    sd_o   <= 1'b0;
                                    state  <= ST_IDLE;
                                end
                            end else begin
                                sample_index <= sample_index + 1'b1;
                                state        <= ST_PRIME_ADDR;
                            end
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule