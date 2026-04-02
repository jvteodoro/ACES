`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// i2s_fft_tx_adapter
// -----------------------------------------------------------------------------
// Bloco sintetizavel para transmitir resultados da FFT via I2S.
//
// Contrato de entrada:
// - A FFT entrega pares (real, imag) com um pulso em fft_valid_i.
// - fft_last_i identifica o ultimo bin de uma janela.
// - bfpexp_i deve permanecer valido junto do primeiro bin da janela.
//
// Contrato de saida:
// - O modulo emite um frame especial de bfpexp no inicio de cada janela e
//   depois os bins da FFT na ordem recebida.
// - O frame de bfpexp e repetido por BFPEXP_HOLD_FRAMES frames I2S completos.
// - Cada bin da FFT ocupa um frame I2S:
//     left  = parte real
//     right = parte imaginaria
//
// Formato do slot I2S:
// - 2 bits de tag em-band nos bits mais altos do slot:
//     2'd0 = IDLE, 2'd1 = BFPEXP, 2'd2 = FFT
// - I2S_SAMPLE_W bits de payload signed nos bits menos significativos.
// - bits intermediarios reservados em zero ate completar I2S_SLOT_W bits.
//
// Observacao importante:
// - Este modulo nao contem FIFO profunda para absorver bursts da FFT.
// - Existe apenas um registrador pendente de 1 entrada para handshake.
// - A desacoplagem principal deve ser feita por uma FIFO externa.
//
// Observacao:
// - Este arquivo contem apenas RTL sintetizavel. O testbench correspondente
//   esta em tb/unit/tb_i2s_fft_tx_adapter.sv.
// -----------------------------------------------------------------------------
module i2s_fft_tx_adapter #(
    parameter int FFT_DW              = 18,
    parameter int BFPEXP_W            = 8,
    parameter int I2S_SAMPLE_W        = 18,
    parameter int I2S_SLOT_W          = 32,
    parameter int CLOCK_DIV           = 16,
    parameter int FIFO_DEPTH          = 1024,
    parameter int BFPEXP_HOLD_FRAMES  = 128
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

    output logic i2s_sck_o,
    output logic i2s_ws_o,
    output logic i2s_sd_o
);

    localparam int SLOT_BIT_W    = (I2S_SLOT_W <= 1) ? 1 : $clog2(I2S_SLOT_W);
    localparam int HOLD_CNT_W    = $clog2(BFPEXP_HOLD_FRAMES + 1);
    localparam int TAG_W         = 2;
    localparam int RESERVED_W    = I2S_SLOT_W - I2S_SAMPLE_W - TAG_W;
    localparam int DIV_CNT_W     = (CLOCK_DIV <= 1) ? 1 : $clog2(CLOCK_DIV);
    localparam int FIFO_LEVEL_W  = $clog2(FIFO_DEPTH + 1);
    localparam logic [DIV_CNT_W-1:0] WS_PREP_DIV_C =
        (CLOCK_DIV > 1) ? DIV_CNT_W'(CLOCK_DIV-2) : '0;
    localparam logic [HOLD_CNT_W-1:0] BFPEXP_HOLD_FRAMES_C = HOLD_CNT_W'(BFPEXP_HOLD_FRAMES);
    localparam logic [HOLD_CNT_W-1:0] ONE_HOLD_FRAME_C     = {{(HOLD_CNT_W-1){1'b0}}, 1'b1};
    localparam logic [FIFO_LEVEL_W-1:0] ONE_FIFO_LEVEL_C   = {{(FIFO_LEVEL_W-1){1'b0}}, 1'b1};
    localparam logic [TAG_W-1:0] TAG_IDLE_C   = 2'd0;
    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

    logic input_window_in_progress_r;

    logic [DIV_CNT_W-1:0] div_cnt_r;
    logic channel_r;
    logic [SLOT_BIT_W-1:0] slot_bit_r;

    logic active_valid_r;
    logic [TAG_W-1:0] active_tag_r;
    logic signed [I2S_SAMPLE_W-1:0] active_left_r;
    logic signed [I2S_SAMPLE_W-1:0] active_right_r;
    logic [HOLD_CNT_W-1:0] active_hold_frames_r;

    logic pending_valid_r;
    logic signed [FFT_DW-1:0] pending_real_r;
    logic signed [FFT_DW-1:0] pending_imag_r;
    logic pending_last_r;
    logic signed [BFPEXP_W-1:0] pending_bfpexp_r;

    logic stalled_input_valid_r;
    logic signed [FFT_DW-1:0] stalled_real_r;
    logic signed [FFT_DW-1:0] stalled_imag_r;
    logic stalled_last_r;
    logic signed [BFPEXP_W-1:0] stalled_bfpexp_r;

    function automatic logic signed [I2S_SAMPLE_W-1:0] extend_fft_sample(
        input logic signed [FFT_DW-1:0] sample_i
    );
        begin
            extend_fft_sample = {{(I2S_SAMPLE_W-FFT_DW){sample_i[FFT_DW-1]}}, sample_i};
        end
    endfunction

    function automatic logic signed [I2S_SAMPLE_W-1:0] extend_bfpexp(
        input logic signed [BFPEXP_W-1:0] bfpexp_i_f
    );
        begin
            extend_bfpexp = {{(I2S_SAMPLE_W-BFPEXP_W){bfpexp_i_f[BFPEXP_W-1]}}, bfpexp_i_f};
        end
    endfunction

    function automatic logic i2s_slot_bit(
        input logic [TAG_W-1:0] tag_i,
        input logic signed [I2S_SAMPLE_W-1:0] sample_i,
        input logic [SLOT_BIT_W-1:0] bit_idx_i
    );
        logic [I2S_SLOT_W-1:0] slot_word;
        begin
            slot_word = {tag_i, {RESERVED_W{1'b0}}, sample_i};
            i2s_slot_bit = slot_word[I2S_SLOT_W-1-bit_idx_i];
        end
    endfunction

    assign fft_ready_o   = !pending_valid_r;
    assign fifo_full_o   = pending_valid_r;
    assign fifo_empty_o  = !pending_valid_r;
    assign fifo_level_o  = pending_valid_r ? ONE_FIFO_LEVEL_C : '0;

    initial begin
        if (I2S_SAMPLE_W > (I2S_SLOT_W - TAG_W))
            $error("i2s_fft_tx_adapter: I2S_SAMPLE_W deve caber no slot junto com os bits de tag.");
        if (I2S_SAMPLE_W < FFT_DW)
            $error("i2s_fft_tx_adapter: I2S_SAMPLE_W deve ser >= FFT_DW.");
        if (I2S_SAMPLE_W < BFPEXP_W)
            $error("i2s_fft_tx_adapter: I2S_SAMPLE_W deve ser >= BFPEXP_W.");
        if (BFPEXP_HOLD_FRAMES < 1)
            $error("i2s_fft_tx_adapter: BFPEXP_HOLD_FRAMES deve ser >= 1.");
        if (CLOCK_DIV < 2)
            $error("i2s_fft_tx_adapter: CLOCK_DIV deve ser >= 2 para garantir setup do WS.");
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            input_window_in_progress_r  <= 1'b0;

            div_cnt_r                   <= '0;
            i2s_sck_o                   <= 1'b0;
            i2s_ws_o                    <= 1'b1;
            i2s_sd_o                    <= 1'b0;
            channel_r                   <= 1'b1;
            slot_bit_r                  <= '0;

            active_valid_r              <= 1'b0;
            active_tag_r                <= TAG_IDLE_C;
            active_left_r               <= '0;
            active_right_r              <= '0;
            active_hold_frames_r        <= '0;

            pending_valid_r             <= 1'b0;
            pending_real_r              <= '0;
            pending_imag_r              <= '0;
            pending_last_r              <= 1'b0;
            pending_bfpexp_r            <= '0;

            stalled_input_valid_r       <= 1'b0;
            stalled_real_r              <= '0;
            stalled_imag_r              <= '0;
            stalled_last_r              <= 1'b0;
            stalled_bfpexp_r            <= '0;
            overflow_o                  <= 1'b0;
        end else begin
            logic frame_boundary;
            logic next_channel;
            logic [SLOT_BIT_W-1:0] next_slot_bit;
            logic next_active_valid;
            logic [TAG_W-1:0] next_active_tag;
            logic signed [I2S_SAMPLE_W-1:0] next_active_left;
            logic signed [I2S_SAMPLE_W-1:0] next_active_right;
            logic [HOLD_CNT_W-1:0] next_active_hold_frames;

            frame_boundary = 1'b0;
            next_channel   = channel_r;
            next_slot_bit  = slot_bit_r;
            overflow_o     <= 1'b0;

            if (pending_valid_r && fft_valid_i) begin
                if (!stalled_input_valid_r) begin
                    stalled_input_valid_r <= 1'b1;
                    stalled_real_r        <= fft_real_i;
                    stalled_imag_r        <= fft_imag_i;
                    stalled_last_r        <= fft_last_i;
                    stalled_bfpexp_r      <= bfpexp_i;
                end else if ((fft_real_i  !== stalled_real_r)   ||
                             (fft_imag_i  !== stalled_imag_r)   ||
                             (fft_last_i  !== stalled_last_r)   ||
                             (bfpexp_i    !== stalled_bfpexp_r)) begin
                    overflow_o            <= 1'b1;
                end
            end else begin
                stalled_input_valid_r <= 1'b0;
            end

            if (!pending_valid_r && fft_valid_i) begin
                pending_valid_r  <= 1'b1;
                pending_real_r   <= fft_real_i;
                pending_imag_r   <= fft_imag_i;
                pending_last_r   <= fft_last_i;
                pending_bfpexp_r <= bfpexp_i;
            end

            // O bcm2835 em slave mode amostra o frame-sync na borda negativa do
            // BCLK. Antecipamos o WS um ciclo de clk antes dessa borda para dar
            // setup real no pino, em vez de trocar WS simultaneamente ao falling
            // edge interno do serializer.
            if (i2s_sck_o && (div_cnt_r == WS_PREP_DIV_C) && (slot_bit_r == I2S_SLOT_W-2))
                i2s_ws_o <= ~channel_r;

            if (div_cnt_r == CLOCK_DIV-1) begin
                div_cnt_r <= '0;

                if (i2s_sck_o) begin
                    i2s_sck_o <= 1'b0;

                    next_active_valid              = active_valid_r;
                    next_active_tag                = active_tag_r;
                    next_active_left               = active_left_r;
                    next_active_right              = active_right_r;
                    next_active_hold_frames        = active_hold_frames_r;

                    if (slot_bit_r == I2S_SLOT_W-1) begin
                        next_slot_bit = '0;
                        slot_bit_r <= '0;
                        next_channel = ~channel_r;
                        channel_r <= next_channel;

                        if (channel_r == 1'b0)
                            frame_boundary = 1'b1;
                    end else begin
                        next_slot_bit = slot_bit_r + 1'b1;
                        slot_bit_r <= slot_bit_r + 1'b1;
                    end

                    if (frame_boundary) begin
                        if (active_valid_r && (active_tag_r == TAG_BFPEXP_C) && (active_hold_frames_r > 1)) begin
                            next_active_hold_frames = active_hold_frames_r - 1'b1;
                            active_hold_frames_r <= active_hold_frames_r - 1'b1;
                        end else begin
                            if (!input_window_in_progress_r && pending_valid_r) begin
                                next_active_valid              = 1'b1;
                                next_active_tag                = TAG_BFPEXP_C;
                                next_active_left               = extend_bfpexp(pending_bfpexp_r);
                                next_active_right              = extend_bfpexp(pending_bfpexp_r);
                                next_active_hold_frames        = BFPEXP_HOLD_FRAMES_C;
                                active_valid_r        <= 1'b1;
                                active_tag_r          <= TAG_BFPEXP_C;
                                active_left_r         <= extend_bfpexp(pending_bfpexp_r);
                                active_right_r        <= extend_bfpexp(pending_bfpexp_r);
                                active_hold_frames_r  <= BFPEXP_HOLD_FRAMES_C;
                                input_window_in_progress_r <= 1'b1;
                            end else if (input_window_in_progress_r && pending_valid_r) begin
                                next_active_valid              = 1'b1;
                                next_active_tag                = TAG_FFT_C;
                                next_active_left               = extend_fft_sample(pending_real_r);
                                next_active_right              = extend_fft_sample(pending_imag_r);
                                next_active_hold_frames        = ONE_HOLD_FRAME_C;
                                active_valid_r        <= 1'b1;
                                active_tag_r          <= TAG_FFT_C;
                                active_left_r         <= extend_fft_sample(pending_real_r);
                                active_right_r        <= extend_fft_sample(pending_imag_r);
                                active_hold_frames_r  <= ONE_HOLD_FRAME_C;
                                pending_valid_r       <= 1'b0;

                                if (pending_last_r)
                                    input_window_in_progress_r <= 1'b0;
                            end else begin
                                next_active_valid              = 1'b0;
                                next_active_tag                = TAG_IDLE_C;
                                next_active_left               = '0;
                                next_active_right              = '0;
                                next_active_hold_frames        = '0;
                                active_valid_r       <= 1'b0;
                                active_tag_r         <= TAG_IDLE_C;
                                active_left_r        <= '0;
                                active_right_r       <= '0;
                                active_hold_frames_r <= '0;
                            end
                        end
                    end

                    // Philips I2S: o dado do proximo sample continua sendo
                    // preparado no semiperiodo baixo. O WS, por sua vez, ja
                    // foi antecipado durante o semiperiodo alto anterior para
                    // chegar estavel a tempo da borda negativa observada pelo
                    // receptor bcm2835 em slave mode.
                    i2s_sd_o <= next_active_valid
                                ? i2s_slot_bit(
                                      next_active_tag,
                                      next_channel ? next_active_right : next_active_left,
                                      next_slot_bit
                                  )
                                : 1'b0;
                end else begin
                    i2s_sck_o <= 1'b1;
                end
            end else begin
                div_cnt_r <= div_cnt_r + 1'b1;
            end
        end
    end

endmodule
