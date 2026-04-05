`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// spi_fft_frame_master
// -----------------------------------------------------------------------------
// Exporta resultados FFT como frames SPI completos, com a FPGA atuando como
// master e o receptor externo apenas observando SCLK/CS_N/MOSI.
//
// Protocolo:
// - 1 transacao SPI = 1 frame FFT
// - 3 palavras de header de 32 bits
// - COUNT palavras de payload
// - payload em ordem: bin0 real, bin0 imag, bin1 real, bin1 imag...
//
// Regras operacionais:
// - o frame so e transmitido depois que o ultimo bin (`fft_last_i`) chega
// - em idle: CS_N=1, SCLK=0, MOSI=0
// - SPI mode 0: CPOL=0, CPHA=0
// - bytes e bits saem em ordem big-endian / MSB-first
// -----------------------------------------------------------------------------
module spi_fft_frame_master #(
    parameter int FFT_DW            = 18,
    parameter int BFPEXP_W          = 8,
    parameter int BIN_ID_W          = 9,
    parameter int WORD_W            = 32,
    parameter int FIFO_DEPTH        = 2048,
    parameter int FRAME_FIFO_DEPTH  = 8,
    parameter int SPI_CLK_DIV       = 4,
    parameter logic [15:0] SOF      = 16'hA55A,
    parameter logic [7:0] VERSION   = 8'h01,
    parameter logic [7:0] FRAME_TYPE= 8'h01,
    parameter logic [15:0] DEFAULT_FLAGS = 16'h0000
) (
    input  logic clk,
    input  logic rst,

    input  logic fft_valid_i,
    input  logic [BIN_ID_W-1:0] fft_bin_index_i,
    input  logic signed [FFT_DW-1:0] fft_real_i,
    input  logic signed [FFT_DW-1:0] fft_imag_i,
    input  logic fft_last_i,
    input  logic signed [BFPEXP_W-1:0] bfpexp_i,

    output logic fft_ready_o,
    output logic bin_fifo_full_o,
    output logic frame_fifo_full_o,
    output logic overflow_o,
    output logic [$clog2(FIFO_DEPTH+1)-1:0] bin_fifo_level_o,
    output logic [$clog2(FRAME_FIFO_DEPTH+1)-1:0] frame_fifo_level_o,
    output logic frame_pending_o,

    output logic spi_sclk_o,
    output logic spi_cs_n_o,
    output logic spi_mosi_o,
    output logic spi_active_o
);

    localparam int PAYLOAD_VALUE_W = 18;
    localparam int HALF_DIV_W      = (SPI_CLK_DIV <= 1) ? 1 : $clog2(SPI_CLK_DIV);
    localparam int BIN_PTR_W       = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam int FRAME_PTR_W     = (FRAME_FIFO_DEPTH <= 1) ? 1 : $clog2(FRAME_FIFO_DEPTH);
    localparam int BIN_COUNT_W     = $clog2(FIFO_DEPTH + 1);
    localparam logic [WORD_W-1:0] HEADER_WORD0_C = {SOF, VERSION, FRAME_TYPE};

    localparam logic PART_REAL_C = 1'b0;
    localparam logic PART_IMAG_C = 1'b1;

    typedef enum logic [1:0] {
        SPI_IDLE,
        SPI_LOW,
        SPI_HIGH
    } spi_state_t;

    logic [BIN_ID_W-1:0]      bin_id_mem   [0:FIFO_DEPTH-1];
    logic signed [FFT_DW-1:0] bin_real_mem [0:FIFO_DEPTH-1];
    logic signed [FFT_DW-1:0] bin_imag_mem [0:FIFO_DEPTH-1];

    logic [15:0] frame_seq_mem   [0:FRAME_FIFO_DEPTH-1];
    logic [15:0] frame_count_mem [0:FRAME_FIFO_DEPTH-1];
    logic [15:0] frame_flags_mem [0:FRAME_FIFO_DEPTH-1];
    logic [15:0] frame_exp_mem   [0:FRAME_FIFO_DEPTH-1];

    logic [BIN_PTR_W-1:0]   bin_wptr_r;
    logic [BIN_PTR_W-1:0]   bin_rptr_r;
    logic [FRAME_PTR_W-1:0] frame_wptr_r;
    logic [FRAME_PTR_W-1:0] frame_rptr_r;
    logic [15:0]            seq_counter_r;
    logic [BIN_COUNT_W-1:0] assembling_bin_count_r;

    logic [WORD_W-1:0]      active_word_r;
    logic [5:0]             active_bit_index_r;
    logic [15:0]            frame_word_index_r;
    logic [HALF_DIV_W-1:0]  spi_div_count_r;
    spi_state_t             spi_state_r;

    logic [BIN_ID_W-1:0]      active_bin_id_r;
    logic signed [FFT_DW-1:0] active_bin_imag_r;
    logic                     active_bin_valid_r;

    logic [15:0] current_frame_seq_r;
    logic [15:0] current_frame_count_words_r;
    logic [15:0] current_frame_flags_r;
    logic [15:0] current_frame_exp_r;

    logic [BIN_ID_W-1:0]      bin_head_id_w;
    logic signed [FFT_DW-1:0] bin_head_real_w;
    logic signed [FFT_DW-1:0] bin_head_imag_w;
    logic [15:0] frame_head_seq_w;
    logic [15:0] frame_head_count_w;
    logic [15:0] frame_head_flags_w;
    logic [15:0] frame_head_exp_w;

    function automatic logic [BIN_PTR_W-1:0] bin_inc_ptr(
        input logic [BIN_PTR_W-1:0] ptr_i
    );
        begin
            if (ptr_i == FIFO_DEPTH-1)
                bin_inc_ptr = '0;
            else
                bin_inc_ptr = ptr_i + 1'b1;
        end
    endfunction

    function automatic logic [FRAME_PTR_W-1:0] frame_inc_ptr(
        input logic [FRAME_PTR_W-1:0] ptr_i
    );
        begin
            if (ptr_i == FRAME_FIFO_DEPTH-1)
                frame_inc_ptr = '0;
            else
                frame_inc_ptr = ptr_i + 1'b1;
        end
    endfunction

    function automatic logic [15:0] extend_exp(
        input logic signed [BFPEXP_W-1:0] bfpexp_i_f
    );
        begin
            if (BFPEXP_W >= 16)
                extend_exp = bfpexp_i_f[15:0];
            else
                extend_exp = {{(16-BFPEXP_W){bfpexp_i_f[BFPEXP_W-1]}}, bfpexp_i_f};
        end
    endfunction

    function automatic logic signed [PAYLOAD_VALUE_W-1:0] extend_value(
        input logic signed [FFT_DW-1:0] sample_i
    );
        begin
            if (FFT_DW >= PAYLOAD_VALUE_W)
                extend_value = sample_i[PAYLOAD_VALUE_W-1:0];
            else
                extend_value = {{(PAYLOAD_VALUE_W-FFT_DW){sample_i[FFT_DW-1]}}, sample_i};
        end
    endfunction

    function automatic logic [WORD_W-1:0] build_header_word1(
        input logic [15:0] seq_i,
        input logic [15:0] count_i
    );
        begin
            build_header_word1 = {seq_i, count_i};
        end
    endfunction

    function automatic logic [WORD_W-1:0] build_header_word2(
        input logic [15:0] flags_i,
        input logic [15:0] exp_i
    );
        begin
            build_header_word2 = {flags_i, exp_i};
        end
    endfunction

    function automatic logic [WORD_W-1:0] build_payload_word(
        input logic [BIN_ID_W-1:0]      bin_id_i,
        input logic                     part_i,
        input logic [3:0]               flags_local_i,
        input logic signed [FFT_DW-1:0] value_i
    );
        logic [8:0] bin_id_ext;
        logic signed [PAYLOAD_VALUE_W-1:0] value_ext;
        begin
            if (BIN_ID_W >= 9)
                bin_id_ext = bin_id_i[8:0];
            else
                bin_id_ext = {{(9-BIN_ID_W){1'b0}}, bin_id_i};
            value_ext  = extend_value(value_i);
            build_payload_word = {bin_id_ext, part_i, flags_local_i, value_ext[17:0]};
        end
    endfunction

    assign bin_head_id_w      = bin_id_mem[bin_rptr_r];
    assign bin_head_real_w    = bin_real_mem[bin_rptr_r];
    assign bin_head_imag_w    = bin_imag_mem[bin_rptr_r];
    assign frame_head_seq_w   = frame_seq_mem[frame_rptr_r];
    assign frame_head_count_w = frame_count_mem[frame_rptr_r];
    assign frame_head_flags_w = frame_flags_mem[frame_rptr_r];
    assign frame_head_exp_w   = frame_exp_mem[frame_rptr_r];

    assign bin_fifo_full_o   = (bin_fifo_level_o == FIFO_DEPTH);
    assign frame_fifo_full_o = (frame_fifo_level_o == FRAME_FIFO_DEPTH);
    assign frame_pending_o   = (frame_fifo_level_o != '0);
    assign fft_ready_o       = !bin_fifo_full_o && !(fft_last_i && frame_fifo_full_o);

    initial begin
        if (WORD_W != 32)
            $error("spi_fft_frame_master: WORD_W deve ser 32.");
        if (FFT_DW > PAYLOAD_VALUE_W)
            $error("spi_fft_frame_master: FFT_DW deve ser <= 18.");
        if (BIN_ID_W > 9)
            $error("spi_fft_frame_master: BIN_ID_W deve ser <= 9.");
        if (BFPEXP_W > 16)
            $error("spi_fft_frame_master: BFPEXP_W deve ser <= 16.");
        if (FIFO_DEPTH < 2)
            $error("spi_fft_frame_master: FIFO_DEPTH deve ser >= 2.");
        if (FRAME_FIFO_DEPTH < 1)
            $error("spi_fft_frame_master: FRAME_FIFO_DEPTH deve ser >= 1.");
        if (SPI_CLK_DIV < 1)
            $error("spi_fft_frame_master: SPI_CLK_DIV deve ser >= 1.");
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            bin_wptr_r               <= '0;
            bin_rptr_r               <= '0;
            frame_wptr_r             <= '0;
            frame_rptr_r             <= '0;
            seq_counter_r            <= '0;
            assembling_bin_count_r   <= '0;
            bin_fifo_level_o         <= '0;
            frame_fifo_level_o       <= '0;
            overflow_o               <= 1'b0;
            active_word_r            <= '0;
            active_bit_index_r       <= WORD_W-1;
            frame_word_index_r       <= '0;
            spi_div_count_r          <= '0;
            spi_state_r              <= SPI_IDLE;
            active_bin_id_r          <= '0;
            active_bin_imag_r        <= '0;
            active_bin_valid_r       <= 1'b0;
            current_frame_seq_r      <= '0;
            current_frame_count_words_r <= '0;
            current_frame_flags_r    <= '0;
            current_frame_exp_r      <= '0;
            spi_sclk_o               <= 1'b0;
            spi_cs_n_o               <= 1'b1;
            spi_mosi_o               <= 1'b0;
            spi_active_o             <= 1'b0;
        end else begin
            logic bin_push_now;
            logic bin_pop_now;
            logic frame_push_now;
            logic frame_pop_now;
            logic [15:0] next_word_index_v;
            logic [15:0] payload_word_index_v;
            logic [WORD_W-1:0] next_word_v;
            logic [15:0] new_count_words_v;

            bin_push_now        = 1'b0;
            bin_pop_now         = 1'b0;
            frame_push_now      = 1'b0;
            frame_pop_now       = 1'b0;
            next_word_index_v   = '0;
            payload_word_index_v= '0;
            next_word_v         = '0;
            new_count_words_v   = '0;
            overflow_o          <= 1'b0;

            if (fft_valid_i) begin
                if (fft_ready_o) begin
                    bin_push_now                 = 1'b1;
                    bin_id_mem[bin_wptr_r]      <= fft_bin_index_i;
                    bin_real_mem[bin_wptr_r]    <= fft_real_i;
                    bin_imag_mem[bin_wptr_r]    <= fft_imag_i;

                    if (fft_last_i) begin
                        frame_push_now             = 1'b1;
                        new_count_words_v          = (assembling_bin_count_r + 1'b1) << 1;
                        frame_seq_mem[frame_wptr_r]   <= seq_counter_r;
                        frame_count_mem[frame_wptr_r] <= new_count_words_v;
                        frame_flags_mem[frame_wptr_r] <= DEFAULT_FLAGS;
                        frame_exp_mem[frame_wptr_r]   <= extend_exp(bfpexp_i);
                        seq_counter_r              <= seq_counter_r + 1'b1;
                        assembling_bin_count_r     <= '0;
                    end else begin
                        assembling_bin_count_r     <= assembling_bin_count_r + 1'b1;
                    end
                end else begin
                    overflow_o <= 1'b1;
                end
            end

            if (!spi_active_o) begin
                spi_state_r     <= SPI_IDLE;
                spi_sclk_o      <= 1'b0;
                spi_div_count_r <= '0;
                spi_mosi_o      <= 1'b0;
                spi_cs_n_o      <= 1'b1;

                if (frame_fifo_level_o != '0) begin
                    frame_pop_now               = 1'b1;
                    current_frame_seq_r         <= frame_head_seq_w;
                    current_frame_count_words_r <= frame_head_count_w;
                    current_frame_flags_r       <= frame_head_flags_w;
                    current_frame_exp_r         <= frame_head_exp_w;
                    active_bin_valid_r          <= 1'b0;
                    frame_word_index_r          <= 16'd0;
                    active_word_r               <= HEADER_WORD0_C;
                    active_bit_index_r          <= WORD_W-1;
                    spi_mosi_o                  <= HEADER_WORD0_C[WORD_W-1];
                    spi_cs_n_o                  <= 1'b0;
                    spi_state_r                 <= SPI_LOW;
                    spi_active_o                <= 1'b1;
                end
            end else begin
                case (spi_state_r)
                    SPI_LOW: begin
                        spi_sclk_o <= 1'b0;
                        if (spi_div_count_r == SPI_CLK_DIV-1) begin
                            spi_div_count_r <= '0;
                            spi_state_r     <= SPI_HIGH;
                            spi_sclk_o      <= 1'b1;
                        end else begin
                            spi_div_count_r <= spi_div_count_r + 1'b1;
                        end
                    end

                    SPI_HIGH: begin
                        spi_sclk_o <= 1'b1;
                        if (spi_div_count_r == SPI_CLK_DIV-1) begin
                            spi_div_count_r <= '0;
                            spi_sclk_o      <= 1'b0;

                            if (active_bit_index_r != 0) begin
                                active_bit_index_r <= active_bit_index_r - 1'b1;
                                spi_state_r        <= SPI_LOW;
                                spi_mosi_o         <= active_word_r[active_bit_index_r - 1'b1];
                            end else if (frame_word_index_r == (current_frame_count_words_r + 16'd2)) begin
                                spi_state_r        <= SPI_IDLE;
                                spi_active_o       <= 1'b0;
                                spi_cs_n_o         <= 1'b1;
                                spi_mosi_o         <= 1'b0;
                                active_bit_index_r <= WORD_W-1;
                                frame_word_index_r <= '0;
                            end else begin
                                next_word_index_v   = frame_word_index_r + 1'b1;
                                frame_word_index_r  <= next_word_index_v;
                                active_bit_index_r  <= WORD_W-1;
                                spi_state_r         <= SPI_LOW;

                                unique case (next_word_index_v)
                                    16'd1: begin
                                        next_word_v = build_header_word1(
                                            current_frame_seq_r,
                                            current_frame_count_words_r
                                        );
                                    end

                                    16'd2: begin
                                        next_word_v = build_header_word2(
                                            current_frame_flags_r,
                                            current_frame_exp_r
                                        );
                                    end

                                    default: begin
                                        payload_word_index_v = next_word_index_v - 16'd3;

                                        if (!payload_word_index_v[0]) begin
                                            active_bin_id_r    <= bin_head_id_w;
                                            active_bin_imag_r  <= bin_head_imag_w;
                                            active_bin_valid_r <= 1'b1;
                                            next_word_v = build_payload_word(
                                                bin_head_id_w,
                                                PART_REAL_C,
                                                4'h0,
                                                bin_head_real_w
                                            );
                                        end else begin
                                            if (!active_bin_valid_r)
                                                $fatal(1, "spi_fft_frame_master: imag word requested sem bin real carregado.");
                                            next_word_v = build_payload_word(
                                                active_bin_id_r,
                                                PART_IMAG_C,
                                                4'h0,
                                                active_bin_imag_r
                                            );
                                            active_bin_valid_r <= 1'b0;
                                            bin_pop_now        = 1'b1;
                                        end
                                    end
                                endcase

                                active_word_r <= next_word_v;
                                spi_mosi_o    <= next_word_v[WORD_W-1];
                            end
                        end else begin
                            spi_div_count_r <= spi_div_count_r + 1'b1;
                        end
                    end

                    default: begin
                        spi_state_r     <= SPI_IDLE;
                        spi_sclk_o      <= 1'b0;
                        spi_cs_n_o      <= 1'b1;
                        spi_mosi_o      <= 1'b0;
                        spi_active_o    <= 1'b0;
                        spi_div_count_r <= '0;
                    end
                endcase
            end

            if (bin_push_now)
                bin_wptr_r <= bin_inc_ptr(bin_wptr_r);

            if (bin_pop_now)
                bin_rptr_r <= bin_inc_ptr(bin_rptr_r);

            unique case ({bin_push_now, bin_pop_now})
                2'b10: bin_fifo_level_o <= bin_fifo_level_o + 1'b1;
                2'b01: bin_fifo_level_o <= bin_fifo_level_o - 1'b1;
                default: bin_fifo_level_o <= bin_fifo_level_o;
            endcase

            if (frame_push_now)
                frame_wptr_r <= frame_inc_ptr(frame_wptr_r);

            if (frame_pop_now)
                frame_rptr_r <= frame_inc_ptr(frame_rptr_r);

            unique case ({frame_push_now, frame_pop_now})
                2'b10: frame_fifo_level_o <= frame_fifo_level_o + 1'b1;
                2'b01: frame_fifo_level_o <= frame_fifo_level_o - 1'b1;
                default: frame_fifo_level_o <= frame_fifo_level_o;
            endcase
        end
    end

endmodule
