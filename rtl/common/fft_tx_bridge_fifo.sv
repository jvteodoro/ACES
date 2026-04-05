// -----------------------------------------------------------------------------
// fft_tx_bridge_fifo
// -----------------------------------------------------------------------------
// FIFO show-ahead reutilizavel para transportar um bin FFT completo
// (`real/imag/last/bfpexp`) entre dois blocos com ritmos diferentes.
//
// Este modulo existe para isolar a politica de buffering do transporte fisico:
// o adaptador SPI o instancia internamente, e os benches tambem o exercitam de
// forma independente para validar ordenacao, overflow e push/pop simultaneos.
// -----------------------------------------------------------------------------
module fft_tx_bridge_fifo #(
    parameter int FFT_DW     = 18,
    parameter int BFPEXP_W   = 8,
    parameter int FIFO_DEPTH = 2048
)(
    input  logic clk,
    input  logic rst,

    input  logic push_i,
    input  logic signed [FFT_DW-1:0] fft_real_i,
    input  logic signed [FFT_DW-1:0] fft_imag_i,
    input  logic fft_last_i,
    input  logic signed [BFPEXP_W-1:0] bfpexp_i,

    input  logic pop_i,

    output logic valid_o,
    output logic signed [FFT_DW-1:0] fft_real_o,
    output logic signed [FFT_DW-1:0] fft_imag_o,
    output logic fft_last_o,
    output logic signed [BFPEXP_W-1:0] bfpexp_o,

    output logic full_o,
    output logic empty_o,
    output logic overflow_o,
    output logic [$clog2(FIFO_DEPTH+1)-1:0] level_o
);

    localparam int ENTRY_W = (2 * FFT_DW) + BFPEXP_W + 1;
    localparam int PTR_W   = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);

    logic [ENTRY_W-1:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [PTR_W-1:0] wptr_r;
    logic [PTR_W-1:0] rptr_r;
    logic [ENTRY_W-1:0] head_word;

    function automatic logic [PTR_W-1:0] fifo_inc_ptr(
        input logic [PTR_W-1:0] ptr_i
    );
        begin
            if (ptr_i == FIFO_DEPTH-1)
                fifo_inc_ptr = '0;
            else
                fifo_inc_ptr = ptr_i + 1'b1;
        end
    endfunction

    // Show-ahead: a cabeca atual fica permanentemente refletida nas saidas
    // enquanto `level_o != 0`, sem exigir um pop previo para leitura.
    assign head_word = fifo_mem[rptr_r];

    assign valid_o    = (level_o != '0);
    assign empty_o    = (level_o == '0);
    assign full_o     = (level_o == FIFO_DEPTH);
    assign fft_real_o = empty_o ? '0 : head_word[ENTRY_W-1 -: FFT_DW];
    assign fft_imag_o = empty_o ? '0 : head_word[BFPEXP_W+1 +: FFT_DW];
    assign fft_last_o = empty_o ? 1'b0 : head_word[BFPEXP_W];
    assign bfpexp_o   = empty_o ? '0 : head_word[BFPEXP_W-1:0];

    initial begin
        if (FIFO_DEPTH < 1)
            $error("fft_tx_bridge_fifo: FIFO_DEPTH deve ser >= 1.");
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wptr_r      <= '0;
            rptr_r      <= '0;
            level_o     <= '0;
            overflow_o  <= 1'b0;
        end else begin
            logic do_push;
            logic do_pop;

            do_pop      = pop_i && !empty_o;
            // Push e pop no mesmo ciclo sao aceitos. Isso permite throughput 1
            // entrada/ciclo quando um consumidor drena a FIFO continuamente.
            do_push     = push_i && (!full_o || do_pop);
            overflow_o  <= push_i && full_o && !do_pop;

            if (do_push) begin
                fifo_mem[wptr_r] <= {fft_real_i, fft_imag_i, fft_last_i, bfpexp_i};
                wptr_r <= fifo_inc_ptr(wptr_r);
            end

            if (do_pop)
                rptr_r <= fifo_inc_ptr(rptr_r);

            case ({do_push, do_pop})
                2'b10: level_o <= level_o + 1'b1;
                2'b01: level_o <= level_o - 1'b1;
                default: level_o <= level_o;
            endcase
        end
    end

endmodule
