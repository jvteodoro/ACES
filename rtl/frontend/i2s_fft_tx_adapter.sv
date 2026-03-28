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
// - O modulo insere na FIFO um frame especial de bfpexp no inicio de cada
//   janela e depois os bins da FFT na ordem recebida.
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
// Estrategia de buffering:
// - A FIFO armazena tanto o marcador de bfpexp quanto os bins da FFT.
// - Isso desacopla o ritmo da FFT do ritmo de transmissao serial.
// - Se faltar espaco no meio de uma janela, overflow_o sobe e a janela atual
//   passa a ser descartada ate fft_last_i, evitando misturar janelas.
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

    localparam int FIFO_PTR_W  = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam int FIFO_LVL_W  = $clog2(FIFO_DEPTH + 1);
    localparam int SLOT_BIT_W  = (I2S_SLOT_W <= 1) ? 1 : $clog2(I2S_SLOT_W);
    localparam int HOLD_CNT_W  = $clog2(BFPEXP_HOLD_FRAMES + 1);
    localparam int TAG_W       = 2;
    localparam int RESERVED_W  = I2S_SLOT_W - I2S_SAMPLE_W - TAG_W;
    localparam int DIV_CNT_W   = (CLOCK_DIV <= 1) ? 1 : $clog2(CLOCK_DIV);
    localparam int unsigned FIFO_DEPTH_U = FIFO_DEPTH;
    localparam logic [HOLD_CNT_W-1:0] BFPEXP_HOLD_FRAMES_C = HOLD_CNT_W'(BFPEXP_HOLD_FRAMES);
    localparam logic [HOLD_CNT_W-1:0] ONE_HOLD_FRAME_C     = {{(HOLD_CNT_W-1){1'b0}}, 1'b1};
    localparam logic [TAG_W-1:0] TAG_IDLE_C   = 2'd0;
    localparam logic [TAG_W-1:0] TAG_BFPEXP_C = 2'd1;
    localparam logic [TAG_W-1:0] TAG_FFT_C    = 2'd2;

    logic [TAG_W-1:0] fifo_tag_mem [0:FIFO_DEPTH-1];
    logic signed [I2S_SAMPLE_W-1:0] fifo_left_mem [0:FIFO_DEPTH-1];
    logic signed [I2S_SAMPLE_W-1:0] fifo_right_mem [0:FIFO_DEPTH-1];

    logic [FIFO_PTR_W-1:0] fifo_wr_ptr_r;
    logic [FIFO_PTR_W-1:0] fifo_rd_ptr_r;
    logic [FIFO_LVL_W-1:0] fifo_count_r;

    logic input_window_in_progress_r;
    logic drop_window_r;

    logic [DIV_CNT_W-1:0] div_cnt_r;
    logic channel_r;
    logic [SLOT_BIT_W-1:0] slot_bit_r;

    logic active_valid_r;
    logic [TAG_W-1:0] active_tag_r;
    logic signed [I2S_SAMPLE_W-1:0] active_left_r;
    logic signed [I2S_SAMPLE_W-1:0] active_right_r;
    logic [HOLD_CNT_W-1:0] active_hold_frames_r;

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

    function automatic [FIFO_PTR_W-1:0] ptr_inc(
        input logic [FIFO_PTR_W-1:0] ptr_i,
        input int unsigned delta_i
    );
        int unsigned next_ptr;
        begin
            next_ptr = ptr_i + delta_i;
            if (next_ptr >= FIFO_DEPTH_U)
                next_ptr = next_ptr - FIFO_DEPTH;
            ptr_inc = next_ptr[FIFO_PTR_W-1:0];
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

    always_comb begin
        int unsigned needed_slots;
        int unsigned next_level;

        needed_slots = input_window_in_progress_r ? 1 : 2;
        next_level   = fifo_count_r + needed_slots;

        if (drop_window_r)
            fft_ready_o = 1'b0;
        else
            fft_ready_o = next_level <= FIFO_DEPTH_U;
    end

    assign fifo_full_o   = (fifo_count_r == FIFO_DEPTH_U);
    assign fifo_empty_o  = (fifo_count_r == 0);
    assign fifo_level_o  = fifo_count_r;
    assign i2s_sd_o      = active_valid_r ? i2s_slot_bit(active_tag_r, channel_r ? active_right_r : active_left_r, slot_bit_r) : 1'b0;

    initial begin
        if (I2S_SAMPLE_W > (I2S_SLOT_W - TAG_W))
            $error("i2s_fft_tx_adapter: I2S_SAMPLE_W deve caber no slot junto com os bits de tag.");
        if (FIFO_DEPTH < 2)
            $error("i2s_fft_tx_adapter: FIFO_DEPTH deve ser pelo menos 2.");
        if (BFPEXP_HOLD_FRAMES < 1)
            $error("i2s_fft_tx_adapter: BFPEXP_HOLD_FRAMES deve ser >= 1.");
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fifo_wr_ptr_r               <= '0;
            fifo_rd_ptr_r               <= '0;
            fifo_count_r                <= '0;
            input_window_in_progress_r  <= 1'b0;
            drop_window_r               <= 1'b0;
            overflow_o                  <= 1'b0;

            div_cnt_r                   <= '0;
            i2s_sck_o                   <= 1'b0;
            i2s_ws_o                    <= 1'b1;
            channel_r                   <= 1'b1;
            slot_bit_r                  <= '0;

            active_valid_r              <= 1'b0;
            active_tag_r                <= TAG_IDLE_C;
            active_left_r               <= '0;
            active_right_r              <= '0;
            active_hold_frames_r        <= '0;
        end else begin
            int unsigned write_count;
            int unsigned next_fifo_count;
            int unsigned free_slots;
            int unsigned required_slots;
            logic pop_entry;
            logic frame_boundary;
            logic next_channel;
            logic [TAG_W-1:0] write_tag0;
            logic signed [I2S_SAMPLE_W-1:0] write_left0;
            logic signed [I2S_SAMPLE_W-1:0] write_right0;
            logic [TAG_W-1:0] write_tag1;
            logic signed [I2S_SAMPLE_W-1:0] write_left1;
            logic signed [I2S_SAMPLE_W-1:0] write_right1;

            write_count    = 0;
            pop_entry      = 1'b0;
            frame_boundary = 1'b0;
            next_channel   = channel_r;
            write_tag0       = TAG_IDLE_C;
            write_left0      = '0;
            write_right0     = '0;
            write_tag1       = TAG_IDLE_C;
            write_left1      = '0;
            write_right1     = '0;

            if (div_cnt_r == CLOCK_DIV-1) begin
                div_cnt_r <= '0;

                if (i2s_sck_o) begin
                    i2s_sck_o <= 1'b0;

                    if (slot_bit_r == I2S_SLOT_W-1) begin
                        slot_bit_r <= '0;
                        next_channel = ~channel_r;
                        channel_r <= next_channel;
                        i2s_ws_o <= next_channel;

                        if (channel_r == 1'b0)
                            frame_boundary = 1'b1;
                    end else begin
                        slot_bit_r <= slot_bit_r + 1'b1;
                    end

                    if (frame_boundary) begin
                        if (active_valid_r && (active_tag_r == TAG_BFPEXP_C) && (active_hold_frames_r > 1)) begin
                            active_hold_frames_r <= active_hold_frames_r - 1'b1;
                        end else if (fifo_count_r != 0) begin
                            pop_entry           = 1'b1;
                            active_valid_r      <= 1'b1;
                            active_tag_r        <= fifo_tag_mem[fifo_rd_ptr_r];
                            active_left_r       <= fifo_left_mem[fifo_rd_ptr_r];
                            active_right_r      <= fifo_right_mem[fifo_rd_ptr_r];
                            active_hold_frames_r <= (fifo_tag_mem[fifo_rd_ptr_r] == TAG_BFPEXP_C) ? BFPEXP_HOLD_FRAMES_C
                                                                                                      : ONE_HOLD_FRAME_C;
                        end else begin
                            active_valid_r       <= 1'b0;
                            active_tag_r         <= TAG_IDLE_C;
                            active_left_r        <= '0;
                            active_right_r       <= '0;
                            active_hold_frames_r <= '0;
                        end
                    end
                end else begin
                    i2s_sck_o <= 1'b1;
                end
            end else begin
                div_cnt_r <= div_cnt_r + 1'b1;
            end

            next_fifo_count = int'(fifo_count_r);
            if (pop_entry)
                next_fifo_count = next_fifo_count - 1;

            if (fft_valid_i) begin
                if (drop_window_r) begin
                    if (fft_last_i) begin
                        drop_window_r              <= 1'b0;
                        input_window_in_progress_r <= 1'b0;
                    end else begin
                        input_window_in_progress_r <= 1'b1;
                    end
                end else begin
                    required_slots = input_window_in_progress_r ? 1 : 2;
                    free_slots     = FIFO_DEPTH_U - next_fifo_count;

                    if (free_slots < required_slots) begin
                        overflow_o <= 1'b1;

                        if (fft_last_i) begin
                            drop_window_r              <= 1'b0;
                            input_window_in_progress_r <= 1'b0;
                        end else begin
                            drop_window_r              <= 1'b1;
                            input_window_in_progress_r <= 1'b1;
                        end
                    end else begin
                        if (!input_window_in_progress_r) begin
                            write_tag0       = TAG_BFPEXP_C;
                            write_left0      = extend_bfpexp(bfpexp_i);
                            write_right0     = extend_bfpexp(bfpexp_i);
                            write_tag1       = TAG_FFT_C;
                            write_left1      = extend_fft_sample(fft_real_i);
                            write_right1     = extend_fft_sample(fft_imag_i);
                            write_count = 2;
                        end else begin
                            write_tag0       = TAG_FFT_C;
                            write_left0      = extend_fft_sample(fft_real_i);
                            write_right0     = extend_fft_sample(fft_imag_i);
                            write_count = 1;
                        end

                        drop_window_r              <= 1'b0;
                        input_window_in_progress_r <= !fft_last_i;
                    end
                end
            end

            if (write_count > 0) begin
                fifo_tag_mem[fifo_wr_ptr_r]       <= write_tag0;
                fifo_left_mem[fifo_wr_ptr_r]      <= write_left0;
                fifo_right_mem[fifo_wr_ptr_r]     <= write_right0;
            end

            if (write_count > 1) begin
                fifo_tag_mem[ptr_inc(fifo_wr_ptr_r, 1)]       <= write_tag1;
                fifo_left_mem[ptr_inc(fifo_wr_ptr_r, 1)]      <= write_left1;
                fifo_right_mem[ptr_inc(fifo_wr_ptr_r, 1)]     <= write_right1;
            end

            if (pop_entry)
                fifo_rd_ptr_r <= ptr_inc(fifo_rd_ptr_r, 1);

            if (write_count > 0)
                fifo_wr_ptr_r <= ptr_inc(fifo_wr_ptr_r, write_count);

            if (pop_entry || (write_count != 0)) begin
                next_fifo_count = int'(fifo_count_r);
                if (pop_entry)
                    next_fifo_count = next_fifo_count - 1;
                next_fifo_count = next_fifo_count + write_count;
                fifo_count_r <= next_fifo_count[FIFO_LVL_W-1:0];
            end
        end
    end

endmodule
