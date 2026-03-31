module i2s_rx_adapter_24 (
    input  logic rst,

    input  logic sck_i,
    input  logic ws_i,
    input  logic sd_i,

    // Seleção igual ao pino L/R do microfone:
    // 0 = capturar canal esquerdo
    // 1 = capturar canal direito
    input  logic lr_i,

    output logic               sample_valid_o,
    output logic signed [23:0] sample_24_o,

    // Flags de diagnóstico
    output logic frame_error_o,
    output logic active_o
);

    // -------------------------------------------------------------------------
    // Estratégia de robustez:
    //   - Amostra WS e SD no negedge de SCK
    //   - Processa tudo no posedge de SCK usando as cópias já estabilizadas
    //
    // Isso dá ~meio ciclo para os sinais externos assentarem.
    // -------------------------------------------------------------------------

    logic ws_q_n;
    logic sd_q_n;

    always_ff @(negedge sck_i or posedge rst) begin
        if (rst) begin
            ws_q_n <= 1'b0;
            sd_q_n <= 1'b0;
        end else begin
            ws_q_n <= ws_i;
            sd_q_n <= sd_i;
        end
    end

    // -------------------------------------------------------------------------
    // Máquina de estados
    // -------------------------------------------------------------------------

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_SHIFT,
        ST_HOLD
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Registradores internos
    // -------------------------------------------------------------------------

    logic ws_prev;
    logic [5:0] slot_count;      // 0..31 dentro do canal
    logic [4:0] bit_count;       // 0..23
    logic [23:0] shift_reg;

    logic target_slot;

    // Convenção do I2S do INMP441:
    // left  = ws = 0
    // right = ws = 1
    assign target_slot = (lr_i == 1'b0) ? (ws_q_n == 1'b0) : (ws_q_n == 1'b1);

    assign active_o = (state != ST_IDLE);

    // -------------------------------------------------------------------------
    // Lógica principal
    // -------------------------------------------------------------------------

    always_ff @(posedge sck_i or posedge rst) begin
        if (rst) begin
            state          <= ST_IDLE;
            ws_prev        <= 1'b0;
            slot_count     <= 6'd0;
            bit_count      <= 5'd0;
            shift_reg      <= 24'd0;
            sample_24_o    <= 24'sd0;
            sample_valid_o <= 1'b0;
            frame_error_o  <= 1'b0;
        end else begin
            sample_valid_o <= 1'b0;

            // Detecta borda de WS usando a versão já amostrada no negedge
            if (ws_q_n != ws_prev) begin
                if (state == ST_SHIFT) begin
                    frame_error_o <= 1'b1;
                end

                // Início de um novo slot/canal
                slot_count <= 6'd0;
                bit_count  <= 5'd0;
                shift_reg  <= 24'd0;

                if (target_slot) begin
                    // Como WS foi capturado no negedge anterior, a borda já
                    // "consumiu" o bit de atraso do I2S. O próximo posedge
                    // processará o MSB armazenado em sd_q_n.
                    state <= ST_SHIFT;
                end else begin
                    state <= ST_IDLE;
                end
            end else begin
                // Seguimos dentro do mesmo slot
                if (slot_count < 6'd31) begin
                    slot_count <= slot_count + 6'd1;
                end else begin
                    slot_count <= slot_count;
                end

                case (state)
                    ST_IDLE: begin
                        // aguardando próximo slot de interesse
                    end

                    ST_SHIFT: begin
                        shift_reg <= {shift_reg[22:0], sd_q_n};

                        if (bit_count == 5'd23) begin
                            sample_24_o    <= {shift_reg[22:0], sd_q_n};
                            sample_valid_o <= 1'b1;
                            state          <= ST_HOLD;
                        end

                        bit_count <= bit_count + 5'd1;
                    end

                    ST_HOLD: begin
                        // Palavra já capturada; ignora o resto do slot
                    end

                    default: begin
                        state <= ST_IDLE;
                    end
                endcase

                // Verificação simples de integridade:
                // no I2S do INMP441 há 32 clocks por canal/palavra
                // e 64 clocks por frame estéreo. Se ainda estivermos tentando
                // capturar depois da janela útil, sinalizamos erro.
                if ((state == ST_SHIFT) && (slot_count >= 6'd31)) begin
                    frame_error_o <= 1'b1;
                    state         <= ST_IDLE;
                end
            end

            ws_prev <= ws_q_n;
        end
    end

endmodule
