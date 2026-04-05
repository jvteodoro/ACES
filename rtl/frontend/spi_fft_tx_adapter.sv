`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// spi_fft_tx_adapter
// -----------------------------------------------------------------------------
// Backend sintetizavel para exportar resultados da FFT a um host externo via
// SPI slave, preservando o mesmo empacotamento logico usado antes no transporte
// tagged-I2S:
//
//   [2-bit tag][reserved zero bits][PAYLOAD_W signed payload bits]
//
// O host continua recebendo pares de palavras de 32 bits:
// - palavra esquerda  = BFPEXP ou parte real
// - palavra direita   = BFPEXP ou parte imaginaria
//
// Em vez de serializar continuamente, o host agora inicia uma transacao SPI
// quando `window_ready_o` sobe. Cada transacao entrega uma janela inteira:
// - BFPEXP repetido BFPEXP_HOLD_FRAMES vezes
// - seguido pelos bins FFT na ordem recebida
//
// A arquitetura interna foi separada em tres responsabilidades:
// 1. absorver bins FFT em uma FIFO show-ahead;
// 2. contar quantas janelas completas ja estao prontas para leitura;
// 3. transformar a cabeca da FIFO em palavras tagged de 32 bits e serializa-las
//    em MISO no formato esperado pelo host.
//
// Premissas de uso:
// - SPI mode 0 (CPOL=0, CPHA=0)
// - o clock `clk` deve ser varias vezes mais rapido que `spi_sclk_i`
// - o host deve manter `spi_cs_n_i` em alto quando nao estiver lendo
// -----------------------------------------------------------------------------
module spi_fft_tx_adapter #(
    parameter int FFT_DW              = 18,
    parameter int BFPEXP_W            = 8,
    parameter int PAYLOAD_W           = 18,
    parameter int WORD_W              = 32,
    parameter int FIFO_DEPTH          = 2048,
    parameter int BFPEXP_HOLD_FRAMES  = 1
) (
    input  logic clk,
    input  logic rst,

    input  logic fft_valid_i,
    input  logic signed [FFT_DW-1:0] fft_real_i,
    input  logic signed [FFT_DW-1:0] fft_imag_i,
    input  logic fft_last_i,
    input  logic signed [BFPEXP_W-1:0] bfpexp_i,

    output logic fft_ready_o,
    output logic fifo_full_o,
    output logic fifo_empty_o,
    output logic overflow_o,
    output logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_level_o,

    input  logic spi_sclk_i,
    input  logic spi_cs_n_i,
    output logic spi_miso_o,
    output logic window_ready_o,
    output logic spi_active_o
);

    localparam int TAG_W = 2;
    localparam int RESERVED_W = WORD_W - PAYLOAD_W - TAG_W;
    localparam int HOLD_CNT_W = $clog2(BFPEXP_HOLD_FRAMES + 1);
    localparam int WINDOW_CNT_W = $clog2(FIFO_DEPTH + 1);

    localparam logic [TAG_W-1:0] TAG_IDLE_C   = 2'd0;
    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

    typedef enum logic [1:0] {
        PAIR_IDLE,
        PAIR_BFPEXP,
        PAIR_FFT
    } pair_kind_t;

    // FIFO interna que desacopla a producao bursty de bins FFT da drenagem
    // serial SPI, que eh dirigida pelo host e pode ser muito mais lenta.
    logic fifo_push_w;
    logic fifo_pop_r;
    logic fifo_valid_w;
    logic signed [FFT_DW-1:0] fifo_real_w;
    logic signed [FFT_DW-1:0] fifo_imag_w;
    logic fifo_last_w;
    logic signed [BFPEXP_W-1:0] fifo_bfpexp_w;
    logic fifo_overflow_w;

    // Conta quantas janelas completas ja entraram na FIFO. Isso eh separado do
    // nivel total da FIFO porque uma janela so pode ser anunciada ao host depois
    // que o bin marcado com `fft_last_i` for realmente aceito.
    logic [WINDOW_CNT_W-1:0] complete_windows_r;

    // Sinais SPI chegam assincronos ao dominio `clk`, entao eles passam por um
    // sincronizador simples antes da deteccao de borda.
    logic spi_sclk_meta_r;
    logic spi_sclk_sync_r;
    logic spi_sclk_prev_r;
    logic spi_cs_meta_r;
    logic spi_cs_sync_r;
    logic spi_cs_prev_r;

    logic spi_sclk_rise_w;
    logic spi_sclk_fall_w;
    logic spi_cs_fall_w;
    logic spi_cs_rise_w;

    // Estado da transacao e do serializer byte/bit a byte.
    logic spi_transaction_active_r;
    logic tx_window_in_progress_r;
    logic wait_next_fft_pair_r;
    logic wait_fifo_refresh_r;
    logic byte_complete_pending_r;

    logic [HOLD_CNT_W-1:0] bfpexp_hold_remaining_r;

    pair_kind_t active_pair_kind_r;
    logic [WORD_W-1:0] active_left_word_r;
    logic [WORD_W-1:0] active_right_word_r;
    logic active_fft_last_r;

    logic [2:0] pair_byte_idx_r;
    logic [7:0] current_byte_r;
    logic [2:0] current_bit_idx_r;

    function automatic logic signed [PAYLOAD_W-1:0] extend_fft_sample(
        input logic signed [FFT_DW-1:0] sample_i
    );
        begin
            extend_fft_sample = {{(PAYLOAD_W-FFT_DW){sample_i[FFT_DW-1]}}, sample_i};
        end
    endfunction

    function automatic logic signed [PAYLOAD_W-1:0] extend_bfpexp(
        input logic signed [BFPEXP_W-1:0] bfpexp_i_f
    );
        begin
            extend_bfpexp = {{(PAYLOAD_W-BFPEXP_W){bfpexp_i_f[BFPEXP_W-1]}}, bfpexp_i_f};
        end
    endfunction

    function automatic logic [WORD_W-1:0] pack_word(
        input logic [TAG_W-1:0] tag_i,
        input logic signed [PAYLOAD_W-1:0] payload_i
    );
        begin
            pack_word = {tag_i, {RESERVED_W{1'b0}}, payload_i};
        end
    endfunction

    // O fio SPI transmite cada palavra de 32 bits em ordem little-endian por
    // byte: primeiro os 8 bits menos significativos da palavra esquerda, depois
    // o restante da palavra esquerda, e so entao a palavra direita.
    function automatic logic [7:0] pair_byte(
        input logic [WORD_W-1:0] left_i,
        input logic [WORD_W-1:0] right_i,
        input logic [2:0] byte_idx_i
    );
        begin
            unique case (byte_idx_i)
                3'd0: pair_byte = left_i[7:0];
                3'd1: pair_byte = left_i[15:8];
                3'd2: pair_byte = left_i[23:16];
                3'd3: pair_byte = left_i[31:24];
                3'd4: pair_byte = right_i[7:0];
                3'd5: pair_byte = right_i[15:8];
                3'd6: pair_byte = right_i[23:16];
                default: pair_byte = right_i[31:24];
            endcase
        end
    endfunction

    // Centraliza a troca do "par logico" atualmente em transmissao, reiniciando
    // tambem o serializer para o primeiro byte e o primeiro bit desse par.
    task automatic load_pair_words(
        input pair_kind_t kind_i,
        input logic [WORD_W-1:0] left_i,
        input logic [WORD_W-1:0] right_i,
        input logic last_i,
        output pair_kind_t kind_o,
        output logic [WORD_W-1:0] left_o,
        output logic [WORD_W-1:0] right_o,
        output logic last_o,
        output logic [2:0] byte_idx_o,
        output logic [7:0] byte_o,
        output logic [2:0] bit_idx_o,
        output logic miso_o
    );
        logic [7:0] first_byte;
        begin
            first_byte = pair_byte(left_i, right_i, 3'd0);
            kind_o     = kind_i;
            left_o     = left_i;
            right_o    = right_i;
            last_o     = last_i;
            byte_idx_o = 3'd0;
            byte_o     = first_byte;
            bit_idx_o  = 3'd7;
            miso_o     = first_byte[7];
        end
    endtask

    initial begin
        if (PAYLOAD_W < FFT_DW)
            $error("spi_fft_tx_adapter: PAYLOAD_W deve ser >= FFT_DW.");
        if (PAYLOAD_W < BFPEXP_W)
            $error("spi_fft_tx_adapter: PAYLOAD_W deve ser >= BFPEXP_W.");
        if (WORD_W != 32)
            $error("spi_fft_tx_adapter: o host atual espera palavras de 32 bits.");
        if (BFPEXP_HOLD_FRAMES < 1)
            $error("spi_fft_tx_adapter: BFPEXP_HOLD_FRAMES deve ser >= 1.");
    end

    assign fft_ready_o    = !fifo_full_o;
    assign fifo_push_w    = fft_valid_i && fft_ready_o;
    // `window_ready_o` so sobe quando existe ao menos uma janela completa e nao
    // ha transacao ativa, evitando que o host veja "janela pronta" no meio de um
    // burst que ainda esta sendo drenado.
    assign window_ready_o = (complete_windows_r != '0) && !spi_transaction_active_r;
    assign spi_active_o   = spi_transaction_active_r;

    fft_tx_bridge_fifo #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_fifo (
        .clk(clk),
        .rst(rst),
        .push_i(fifo_push_w),
        .fft_real_i(fft_real_i),
        .fft_imag_i(fft_imag_i),
        .fft_last_i(fft_last_i),
        .bfpexp_i(bfpexp_i),
        .pop_i(fifo_pop_r),
        .valid_o(fifo_valid_w),
        .fft_real_o(fifo_real_w),
        .fft_imag_o(fifo_imag_w),
        .fft_last_o(fifo_last_w),
        .bfpexp_o(fifo_bfpexp_w),
        .full_o(fifo_full_o),
        .empty_o(fifo_empty_o),
        .overflow_o(fifo_overflow_w),
        .level_o(fifo_level_o)
    );

    assign overflow_o = fifo_overflow_w;

    assign spi_sclk_rise_w = !spi_sclk_prev_r && spi_sclk_sync_r;
    assign spi_sclk_fall_w = spi_sclk_prev_r && !spi_sclk_sync_r;
    assign spi_cs_fall_w   = spi_cs_prev_r && !spi_cs_sync_r;
    assign spi_cs_rise_w   = !spi_cs_prev_r && spi_cs_sync_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            complete_windows_r       <= '0;
            spi_sclk_meta_r          <= 1'b0;
            spi_sclk_sync_r          <= 1'b0;
            spi_sclk_prev_r          <= 1'b0;
            spi_cs_meta_r            <= 1'b1;
            spi_cs_sync_r            <= 1'b1;
            spi_cs_prev_r            <= 1'b1;
            spi_transaction_active_r <= 1'b0;
            tx_window_in_progress_r  <= 1'b0;
            wait_next_fft_pair_r     <= 1'b0;
            wait_fifo_refresh_r      <= 1'b0;
            byte_complete_pending_r  <= 1'b0;
            bfpexp_hold_remaining_r  <= '0;
            active_pair_kind_r       <= PAIR_IDLE;
            active_left_word_r       <= '0;
            active_right_word_r      <= '0;
            active_fft_last_r        <= 1'b0;
            pair_byte_idx_r          <= '0;
            current_byte_r           <= '0;
            current_bit_idx_r        <= 3'd7;
            spi_miso_o               <= 1'b0;
            fifo_pop_r               <= 1'b0;
        end else begin
            logic [WINDOW_CNT_W-1:0] complete_windows_next;
            logic signed [PAYLOAD_W-1:0] bfpexp_payload_w;
            logic [WORD_W-1:0] bfpexp_word_w;
            logic [WORD_W-1:0] fft_left_word_w;
            logic [WORD_W-1:0] fft_right_word_w;

            // Traz `spi_sclk_i` e `spi_cs_n_i` com seguranca para o dominio
            // `clk` antes de detectar bordas.
            spi_sclk_meta_r <= spi_sclk_i;
            spi_sclk_sync_r <= spi_sclk_meta_r;
            spi_sclk_prev_r <= spi_sclk_sync_r;
            spi_cs_meta_r   <= spi_cs_n_i;
            spi_cs_sync_r   <= spi_cs_meta_r;
            spi_cs_prev_r   <= spi_cs_sync_r;

            fifo_pop_r <= 1'b0;

            // O contador de janelas prontas avanca quando o ultimo bin de uma
            // janela eh aceito na FIFO, e recua apenas quando o ultimo bin dessa
            // janela eh totalmente serializado para fora.
            complete_windows_next = complete_windows_r;
            if (fifo_push_w && fft_last_i)
                complete_windows_next = complete_windows_next + 1'b1;

            // Empacota a cabeca atual da FIFO no contrato de 32 bits do host.
            bfpexp_payload_w = extend_bfpexp(fifo_bfpexp_w);
            bfpexp_word_w    = pack_word(TAG_BFPEXP_C, bfpexp_payload_w);
            fft_left_word_w  = pack_word(TAG_FFT_C, extend_fft_sample(fifo_real_w));
            fft_right_word_w = pack_word(TAG_FFT_C, extend_fft_sample(fifo_imag_w));

            // Encerrar CS aborta qualquer transmissao parcial e zera o estado
            // local da transacao. O conteudo da FIFO permanece intocado.
            if (spi_cs_rise_w) begin
                spi_transaction_active_r <= 1'b0;
                tx_window_in_progress_r  <= 1'b0;
                wait_next_fft_pair_r     <= 1'b0;
                wait_fifo_refresh_r      <= 1'b0;
                byte_complete_pending_r  <= 1'b0;
                bfpexp_hold_remaining_r  <= '0;
                active_pair_kind_r       <= PAIR_IDLE;
                active_left_word_r       <= '0;
                active_right_word_r      <= '0;
                active_fft_last_r        <= 1'b0;
                pair_byte_idx_r          <= '0;
                current_byte_r           <= '0;
                current_bit_idx_r        <= 3'd7;
                spi_miso_o               <= 1'b0;
            end else begin
                // O inicio de uma transacao sempre carrega imediatamente o
                // primeiro par a ser transmitido: BFPEXP se ja existe uma janela
                // completa, ou um par IDLE se o host sondar cedo demais.
                if (spi_cs_fall_w) begin
                    spi_transaction_active_r <= 1'b1;
                    byte_complete_pending_r  <= 1'b0;
                    wait_next_fft_pair_r     <= 1'b0;
                    wait_fifo_refresh_r      <= 1'b0;

                    if ((complete_windows_r != '0) && fifo_valid_w) begin
                        tx_window_in_progress_r <= 1'b1;
                        bfpexp_hold_remaining_r <= HOLD_CNT_W'(BFPEXP_HOLD_FRAMES);
                        load_pair_words(
                            PAIR_BFPEXP,
                            bfpexp_word_w,
                            bfpexp_word_w,
                            1'b0,
                            active_pair_kind_r,
                            active_left_word_r,
                            active_right_word_r,
                            active_fft_last_r,
                            pair_byte_idx_r,
                            current_byte_r,
                            current_bit_idx_r,
                            spi_miso_o
                        );
                    end else begin
                        tx_window_in_progress_r <= 1'b0;
                        bfpexp_hold_remaining_r <= '0;
                        load_pair_words(
                            PAIR_IDLE,
                            '0,
                            '0,
                            1'b0,
                            active_pair_kind_r,
                            active_left_word_r,
                            active_right_word_r,
                            active_fft_last_r,
                            pair_byte_idx_r,
                            current_byte_r,
                            current_bit_idx_r,
                            spi_miso_o
                        );
                    end
                end

                // Depois de enviar um par FFT e gerar `fifo_pop_r`, a FIFO
                // show-ahead precisa de um ciclo para expor a nova cabeca. O par
                // seguinte so eh carregado depois dessa pequena espera.
                if (wait_next_fft_pair_r && spi_transaction_active_r && !spi_cs_sync_r) begin
                    if (wait_fifo_refresh_r) begin
                        wait_fifo_refresh_r <= 1'b0;
                    end else begin
                        load_pair_words(
                            PAIR_FFT,
                            fft_left_word_w,
                            fft_right_word_w,
                            fifo_last_w,
                            active_pair_kind_r,
                            active_left_word_r,
                            active_right_word_r,
                            active_fft_last_r,
                            pair_byte_idx_r,
                            current_byte_r,
                            current_bit_idx_r,
                            spi_miso_o
                        );
                        wait_next_fft_pair_r <= 1'b0;
                    end
                end

                // Em SPI mode 0 o mestre amostra em borda de subida. Quando o
                // ultimo bit do byte atual eh amostrado, adiamos a troca para a
                // borda de descida seguinte, quando o proximo bit pode ser
                // apresentado com folga temporal.
                if (spi_transaction_active_r && !spi_cs_sync_r && spi_sclk_rise_w) begin
                    if (current_bit_idx_r == 3'd0)
                        byte_complete_pending_r <= 1'b1;
                end

                if (spi_transaction_active_r && !spi_cs_sync_r && spi_sclk_fall_w) begin
                    if (byte_complete_pending_r) begin
                        byte_complete_pending_r <= 1'b0;

                        // O oitavo byte fecha o par inteiro de 64 bits. A partir
                        // daqui decidimos qual par entra em seguida.
                        if (pair_byte_idx_r == 3'd7) begin
                            unique case (active_pair_kind_r)
                                PAIR_BFPEXP: begin
                                    // Repetimos o BFPEXP quantas vezes o host
                                    // espera antes de iniciar os bins FFT.
                                    if (bfpexp_hold_remaining_r > 1) begin
                                        bfpexp_hold_remaining_r <= bfpexp_hold_remaining_r - 1'b1;
                                        load_pair_words(
                                            PAIR_BFPEXP,
                                            active_left_word_r,
                                            active_right_word_r,
                                            1'b0,
                                            active_pair_kind_r,
                                            active_left_word_r,
                                            active_right_word_r,
                                            active_fft_last_r,
                                            pair_byte_idx_r,
                                            current_byte_r,
                                            current_bit_idx_r,
                                            spi_miso_o
                                        );
                                    end else begin
                                        bfpexp_hold_remaining_r <= '0;
                                        // Depois da ultima copia do BFPEXP, a
                                        // cabeca atual da FIFO ja contem o
                                        // primeiro bin FFT da janela.
                                        load_pair_words(
                                            PAIR_FFT,
                                            fft_left_word_w,
                                            fft_right_word_w,
                                            fifo_last_w,
                                            active_pair_kind_r,
                                            active_left_word_r,
                                            active_right_word_r,
                                            active_fft_last_r,
                                            pair_byte_idx_r,
                                            current_byte_r,
                                            current_bit_idx_r,
                                            spi_miso_o
                                        );
                                    end
                                end

                                PAIR_FFT: begin
                                    // So removemos um bin da FIFO depois que os
                                    // 64 bits que o representam foram enviados.
                                    fifo_pop_r <= 1'b1;
                                    if (active_fft_last_r && (complete_windows_r != '0))
                                        complete_windows_next = complete_windows_next - 1'b1;

                                    if (active_fft_last_r) begin
                                        // A janela terminou. Mantemos o barramento
                                        // em IDLE ate o host encerrar CS.
                                        tx_window_in_progress_r <= 1'b0;
                                        load_pair_words(
                                            PAIR_IDLE,
                                            '0,
                                            '0,
                                            1'b0,
                                            active_pair_kind_r,
                                            active_left_word_r,
                                            active_right_word_r,
                                            active_fft_last_r,
                                            pair_byte_idx_r,
                                            current_byte_r,
                                            current_bit_idx_r,
                                            spi_miso_o
                                        );
                                    end else begin
                                        // A proxima amostra vira da nova cabeca
                                        // da FIFO depois do refresh show-ahead.
                                        wait_next_fft_pair_r <= 1'b1;
                                        wait_fifo_refresh_r  <= 1'b1;
                                    end
                                end

                                default: begin
                                    // Enquanto o host mantiver CS baixo sem uma
                                    // janela ativa, o adapter continua devolvendo
                                    // zeros tagged como IDLE.
                                    load_pair_words(
                                        PAIR_IDLE,
                                        '0,
                                        '0,
                                        1'b0,
                                        active_pair_kind_r,
                                        active_left_word_r,
                                        active_right_word_r,
                                        active_fft_last_r,
                                        pair_byte_idx_r,
                                        current_byte_r,
                                        current_bit_idx_r,
                                        spi_miso_o
                                    );
                                end
                            endcase
                        end else begin
                            // Ainda estamos no mesmo par de palavras: avanca
                            // para o proximo byte.
                            logic [2:0] next_byte_idx_w;
                            logic [7:0] next_byte_w;

                            next_byte_idx_w = pair_byte_idx_r + 1'b1;
                            next_byte_w     = pair_byte(active_left_word_r, active_right_word_r, next_byte_idx_w);

                            pair_byte_idx_r   <= next_byte_idx_w;
                            current_byte_r    <= next_byte_w;
                            current_bit_idx_r <= 3'd7;
                            spi_miso_o        <= next_byte_w[7];
                        end
                    end else begin
                        // Ainda no mesmo byte: desloca para o proximo bit, MSB
                        // first dentro do byte.
                        logic [2:0] next_bit_idx_w;
                        next_bit_idx_w = current_bit_idx_r - 1'b1;
                        current_bit_idx_r <= next_bit_idx_w;
                        spi_miso_o        <= current_byte_r[next_bit_idx_w];
                    end
                end
            end

            complete_windows_r <= complete_windows_next;
        end
    end

endmodule
