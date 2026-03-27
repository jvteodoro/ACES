module i2s_rx_adapter_24 (
    input  logic rst,

    input  logic sck_i,
    input  logic ws_i,
    input  logic sd_i,

    output logic sample_valid_o,
    output logic signed [23:0] sample_24_o
);

    logic ws_prev;

    logic capturing;
    logic skip_bit;              // atraso de 1 bit do I2S
    logic [4:0] bit_count;       // 0..23
    logic [23:0] shift_reg;

    always_ff @(posedge sck_i or posedge rst) begin
        if (rst) begin
            ws_prev         <= 1'b0;
            capturing       <= 1'b0;
            skip_bit        <= 1'b0;
            bit_count       <= 5'd0;
            shift_reg       <= 24'd0;
            sample_24_o     <= 24'sd0;
            sample_valid_o  <= 1'b0;
        end else begin
            sample_valid_o <= 1'b0;

            // Detecta início do canal esquerdo: WS 1 -> 0
            if (ws_prev == 1'b1 && ws_i == 1'b0) begin
                capturing <= 1'b1;
                // O flanco em que WS muda para o canal esquerdo já consome
                // o bit de atraso do protocolo I2S. A proxima borda de SCK
                skip_bit  <= 1'b1;   // primeiro ciclo após WS é descartado
                bit_count <= 5'd0;
                //shift_reg <= 24'd0;  // evita resíduo da amostra anterior
            end
            else if (capturing) begin
                if (skip_bit) begin
                    skip_bit <= 1'b0;
                end else begin
                    if (bit_count == 5'd22) begin
                        // captura o último bit corretamente
                        sample_24_o    <= {shift_reg[22:0], sd_i};
                        sample_valid_o <= 1'b1;
                        capturing      <= 1'b0;
                    end else begin
                        shift_reg <= {shift_reg[22:0], sd_i};
                        bit_count <= bit_count + 1'b1;
                    end
                end
            end

            ws_prev <= ws_i;
        end
    end

endmodule
