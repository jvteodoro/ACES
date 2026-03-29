module i2s_stimulus_manager_rom #(
    parameter int SAMPLE_BITS          = 24,
    parameter int N_POINTS             = 512,
    parameter int N_EXAMPLES           = 8,
    parameter int STARTUP_SCK_CYCLES   = 8,
    parameter bit INACTIVE_ZERO_SYNTH  = 0,
    parameter int TOTAL_SAMPLES = N_POINTS * N_EXAMPLES,
    parameter int ROM_ADDR_W    = (TOTAL_SAMPLES <= 1) ? 1 : $clog2(TOTAL_SAMPLES),
    parameter int EXAMPLE_SEL_W = (N_EXAMPLES   <= 1) ? 1 : $clog2(N_EXAMPLES),
    parameter int POINT_IDX_W   = (N_POINTS     <= 1) ? 1 : $clog2(N_POINTS),
    parameter int STARTUP_W     = (STARTUP_SCK_CYCLES <= 1) ? 1 : $clog2(STARTUP_SCK_CYCLES + 1)
    
)(


    input  logic clk,
    input  logic rst,

    // Controle de reprodução
    input  logic start_i,
    input  logic [EXAMPLE_SEL_W-1:0] example_sel_i,
    input  logic [1:0] loop_mode_i,
    // 00 = sem loop
    // 01 = loop no exemplo selecionado
    // 10 = loop em todos os exemplos (a partir do example_sel_i)
    // 11 = reservado (tratado como loop no exemplo)

    // Pinos equivalentes ao microfone
    input  logic chipen_i,
    input  logic lr_i,     // 0 = slot left ativo, 1 = slot right ativo
    input  logic sck_i,
    input  logic ws_i,
    output logic sd_o,

    // Debug
    output logic ready_o,
    output logic busy_o,
    output logic done_o,          // pulso quando a reprodução termina no modo sem loop
    output logic window_done_o,   // pulso a cada janela concluída
    output logic [EXAMPLE_SEL_W-1:0] current_example_o,
    output logic [POINT_IDX_W-1:0] current_point_o,
    output logic [ROM_ADDR_W-1:0] rom_addr_dbg_o,
    output logic signed [SAMPLE_BITS-1:0] current_sample_dbg_o,
    output logic [5:0] bit_index_o,
    output logic [2:0] state_dbg_o
);

    

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_WAIT_READY,
        ST_PRIME_ROM,
        ST_WAIT_ROM_1,
        ST_WAIT_ROM_2,
        ST_WAIT_TARGET_HALF,
        ST_SHIFT
    } state_t;

    state_t state;

    logic start_d, start_pulse;

    logic sck_prev, ws_prev, chipen_prev;
    logic sck_rise, sck_fall;

    logic [STARTUP_W-1:0] startup_count;
    logic startup_active;

    logic [EXAMPLE_SEL_W-1:0] start_example;
    logic [EXAMPLE_SEL_W-1:0] current_example;
    logic [POINT_IDX_W-1:0]   current_point;

    logic [ROM_ADDR_W-1:0] rom_addr_reg;
    localparam int ROM_IP_ADDR_W = 12;
    logic [ROM_IP_ADDR_W-1:0] rom_addr_ip;
    logic signed [SAMPLE_BITS-1:0] rom_q;
    logic signed [SAMPLE_BITS-1:0] current_sample;

    logic [5:0] bit_index;

    wire target_half_active;
    wire target_half_start;

    assign ready_o              = ~startup_active && (state == ST_IDLE);
    assign busy_o               = (state != ST_IDLE);
    assign current_example_o    = current_example;
    assign current_point_o      = current_point;
    assign rom_addr_dbg_o       = rom_addr_reg;
    assign current_sample_dbg_o = current_sample;
    assign bit_index_o          = bit_index;
    assign state_dbg_o          = state;

    assign target_half_active = (lr_i == 1'b0) ? (ws_i == 1'b0) : (ws_i == 1'b1);
    assign target_half_start  = (lr_i == 1'b0) ? (ws_prev == 1'b1 && ws_i == 1'b0)
                                               : (ws_prev == 1'b0 && ws_i == 1'b1);

    generate
        if (ROM_ADDR_W >= ROM_IP_ADDR_W) begin : g_rom_addr_trunc
            assign rom_addr_ip = rom_addr_reg[ROM_IP_ADDR_W-1:0];
        end else begin : g_rom_addr_extend
            assign rom_addr_ip = {{(ROM_IP_ADDR_W-ROM_ADDR_W){1'b0}}, rom_addr_reg};
        end
    endgenerate

    //------------------------------------------------------------
    // Função para calcular endereço base de cada exemplo
    //------------------------------------------------------------
    function automatic [ROM_ADDR_W-1:0] calc_base_addr(
        input logic [EXAMPLE_SEL_W-1:0] example_idx
    );
        calc_base_addr = example_idx * N_POINTS;
    endfunction

    //------------------------------------------------------------
    // Função para calcular endereço absoluto da ROM
    //------------------------------------------------------------
    function automatic [ROM_ADDR_W-1:0] calc_rom_addr(
        input logic [EXAMPLE_SEL_W-1:0] example_idx,
        input logic [POINT_IDX_W-1:0] point_idx
    );
        calc_rom_addr = calc_base_addr(example_idx) + point_idx;
    endfunction

    //------------------------------------------------------------
    // Detecção de start por pulso
    //------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            start_d <= 1'b0;
        else
            start_d <= start_i;
    end

    assign start_pulse = start_i & ~start_d;

    //------------------------------------------------------------
    // Rastreamento de bordas de SCK, WS e CHIPEN
    //------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sck_prev    <= 1'b0;
            ws_prev     <= 1'b1;
            chipen_prev <= 1'b0;
        end else begin
            sck_prev    <= sck_i;
            ws_prev     <= ws_i;
            chipen_prev <= chipen_i;
        end
    end

    assign sck_rise =  sck_i & ~sck_prev;
    assign sck_fall = ~sck_i &  sck_prev;

    //------------------------------------------------------------
    // Emulação simplificada do delay de startup após CHIPEN
    //------------------------------------------------------------
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
                    if (startup_count == STARTUP_SCK_CYCLES-1)
                        startup_active <= 1'b0;
                    else
                        startup_count <= startup_count + 1'b1;
                end
            end
        end
    end

    //------------------------------------------------------------
    // Instância da ROM IP do Quartus
    //
    // Substitua "signals_rom_ip" pelo nome real do módulo gerado
    // pelo Quartus.
    //
    // Configuração assumida:
    // - address registered
    // - output unregistered
    //------------------------------------------------------------
    signals_rom_ip u_signals_rom (
        .clock   (clk),
        .address (rom_addr_ip),
        .q       (rom_q)
    );

    //------------------------------------------------------------
    // FSM principal
    //------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= ST_IDLE;
            start_example  <= '0;
            current_example<= '0;
            current_point  <= '0;
            rom_addr_reg   <= '0;
            current_sample <= '0;
            bit_index      <= 6'd0;
            done_o         <= 1'b0;
            window_done_o  <= 1'b0;
        end else begin
            done_o        <= 1'b0;
            window_done_o <= 1'b0;

            case (state)

                //------------------------------------------------
                // IDLE
                //------------------------------------------------
                ST_IDLE: begin
                    current_point <= '0;
                    bit_index     <= 6'd0;

                    if (start_pulse && chipen_i) begin
                        start_example   <= example_sel_i;
                        current_example <= example_sel_i;
                        current_point   <= '0;

                        if (startup_active)
                            state <= ST_WAIT_READY;
                        else
                            state <= ST_PRIME_ROM;
                    end
                end

                //------------------------------------------------
                // Espera startup
                //------------------------------------------------
                ST_WAIT_READY: begin
                    if (!chipen_i) begin
                        state <= ST_IDLE;
                    end else if (!startup_active) begin
                        state <= ST_PRIME_ROM;
                    end
                end

                //------------------------------------------------
                // Apresenta endereço para a ROM
                //------------------------------------------------
                ST_PRIME_ROM: begin
                    rom_addr_reg <= calc_rom_addr(current_example, current_point);
                    state        <= ST_WAIT_ROM_1;
                end

                //------------------------------------------------
                // 1o ciclo de latência do endereço registrado
                //------------------------------------------------
                ST_WAIT_ROM_1: begin
                    state <= ST_WAIT_ROM_2;
                end

                //------------------------------------------------
                // Captura saída da ROM
                //------------------------------------------------
                ST_WAIT_ROM_2: begin
                    current_sample <= rom_q;
                    bit_index      <= 6'd0;
                    state          <= ST_WAIT_TARGET_HALF;
                end

                //------------------------------------------------
                // Espera o início do slot ativo (left ou right)
                //------------------------------------------------
                ST_WAIT_TARGET_HALF: begin
                    if (!chipen_i) begin
                        state <= ST_IDLE;
                    end else if (target_half_start) begin
                        bit_index <= 6'd0;
                        state     <= ST_SHIFT;
                    end
                end

                //------------------------------------------------
                // Shift I2S
                //
                // bit 0      = atraso I2S de 1 bit
                // bits 1..24 = sample[23:0], MSB-first
                // bits 25..31 = zero
                //------------------------------------------------
                ST_SHIFT: begin
                    if (!chipen_i) begin
                        state <= ST_IDLE;
                    end else if (sck_fall) begin
                        if (bit_index == 6'd31) begin
                            bit_index <= 6'd0;
                            window_done_o <= (current_point == N_POINTS-1);

                            if (current_point == N_POINTS-1) begin
                                case (loop_mode_i)
                                    2'b00: begin
                                        done_o <= 1'b1;
                                        state  <= ST_IDLE;
                                    end

                                    2'b01,
                                    2'b11: begin
                                        current_point <= '0;
                                        state         <= ST_PRIME_ROM;
                                    end

                                    2'b10: begin
                                        current_point <= '0;

                                        if (current_example == N_EXAMPLES-1)
                                            current_example <= '0;
                                        else
                                            current_example <= current_example + 1'b1;

                                        state <= ST_PRIME_ROM;
                                    end

                                    default: begin
                                        done_o <= 1'b1;
                                        state  <= ST_IDLE;
                                    end
                                endcase
                            end else begin
                                current_point <= current_point + 1'b1;
                                state         <= ST_PRIME_ROM;
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

    //------------------------------------------------------------
    // Saída serial I2S
    //
    // Canal ativo:
    //   bit 0      -> 0
    //   bits 1..24 -> current_sample[23:0], MSB-first
    //   bits 25..31 -> 0
    //
    // Canal inativo:
    //   Z em simulação
    //   0 opcional em síntese
    //------------------------------------------------------------
    always_comb begin
        if (!chipen_i) begin
`ifdef SYNTHESIS
            sd_o = 1'b0;
`else
            if (INACTIVE_ZERO_SYNTH)
                sd_o = 1'b0;
            else
                sd_o = 1'bz;
`endif
        end else if (target_half_active) begin
            if (bit_index == 6'd0)
                sd_o = 1'b0;
            else if (bit_index >= 6'd1 && bit_index <= 6'd24)
                sd_o = current_sample[SAMPLE_BITS - bit_index];
            else
                sd_o = 1'b0;
        end else begin
`ifdef SYNTHESIS
            sd_o = 1'b0;
`else
            if (INACTIVE_ZERO_SYNTH)
                sd_o = 1'b0;
            else
                sd_o = 1'bz;
`endif
        end
    end

endmodule