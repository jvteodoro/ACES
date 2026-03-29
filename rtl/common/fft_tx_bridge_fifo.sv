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

    localparam int FIFO_PTR_W = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam int FIFO_LVL_W = $clog2(FIFO_DEPTH + 1);

    logic [FIFO_PTR_W-1:0] wr_ptr_r;
    logic [FIFO_PTR_W-1:0] rd_ptr_r;
    logic [FIFO_LVL_W-1:0] count_r;

    logic signed [FFT_DW-1:0] real_mem [0:FIFO_DEPTH-1];
    logic signed [FFT_DW-1:0] imag_mem [0:FIFO_DEPTH-1];
    logic last_mem [0:FIFO_DEPTH-1];
    logic signed [BFPEXP_W-1:0] bfpexp_mem [0:FIFO_DEPTH-1];

    function automatic [FIFO_PTR_W-1:0] ptr_inc(
        input logic [FIFO_PTR_W-1:0] ptr_i,
        input int unsigned delta_i
    );
        int unsigned next_ptr;
        begin
            next_ptr = ptr_i + delta_i;
            if (next_ptr >= FIFO_DEPTH)
                next_ptr = next_ptr - FIFO_DEPTH;
            ptr_inc = next_ptr[FIFO_PTR_W-1:0];
        end
    endfunction

    assign full_o     = (count_r == FIFO_DEPTH);
    assign empty_o    = (count_r == 0);
    assign valid_o    = !empty_o;
    assign level_o    = count_r;
    assign fft_real_o = real_mem[rd_ptr_r];
    assign fft_imag_o = imag_mem[rd_ptr_r];
    assign fft_last_o = last_mem[rd_ptr_r];
    assign bfpexp_o   = bfpexp_mem[rd_ptr_r];

    always_ff @(posedge clk or posedge rst) begin
        int unsigned next_count;
        logic do_push;
        logic do_pop;

        if (rst) begin
            wr_ptr_r    <= '0;
            rd_ptr_r    <= '0;
            count_r     <= '0;
            overflow_o  <= 1'b0;
        end else begin
            do_pop  = pop_i && (count_r != 0);
            do_push = push_i && ((count_r != FIFO_DEPTH) || do_pop);

            if (push_i && !do_push)
                overflow_o <= 1'b1;

            if (do_push) begin
                real_mem[wr_ptr_r]   <= fft_real_i;
                imag_mem[wr_ptr_r]   <= fft_imag_i;
                last_mem[wr_ptr_r]   <= fft_last_i;
                bfpexp_mem[wr_ptr_r] <= bfpexp_i;
                wr_ptr_r             <= ptr_inc(wr_ptr_r, 1);
            end

            if (do_pop)
                rd_ptr_r <= ptr_inc(rd_ptr_r, 1);

            if (do_push || do_pop) begin
                next_count = count_r;
                if (do_push)
                    next_count = next_count + 1;
                if (do_pop)
                    next_count = next_count - 1;
                count_r <= next_count[FIFO_LVL_W-1:0];
            end
        end
    end

    initial begin
        if (FIFO_DEPTH < 2)
            $error("fft_tx_bridge_fifo: FIFO_DEPTH deve ser pelo menos 2.");
    end

endmodule
