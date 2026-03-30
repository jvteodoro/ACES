module fft_output_fifo (
    input  logic [43:0] data,
    input  logic        rdclk,
    input  logic        rdreq,
    input  logic        wrclk,
    input  logic        wrreq,
    output logic [43:0] q,
    output logic        wrfull
);
    localparam int DEPTH = 1024;
    localparam int PTR_W = $clog2(DEPTH);

    logic [43:0] mem [0:DEPTH-1];
    logic [PTR_W-1:0] wptr_r;
    logic [PTR_W-1:0] rptr_r;
    logic [PTR_W:0] count_r;

    initial begin
        wptr_r = '0;
        rptr_r = '0;
        count_r = '0;
        q = '0;
    end

    function automatic logic [PTR_W-1:0] ptr_inc(input logic [PTR_W-1:0] ptr_i);
        begin
            if (ptr_i == DEPTH-1)
                ptr_inc = '0;
            else
                ptr_inc = ptr_i + 1'b1;
        end
    endfunction

    assign wrfull = (count_r == DEPTH);

    always @(posedge wrclk) begin
        logic do_write;
        logic do_read;

        do_write = wrreq && (count_r < DEPTH);
        do_read  = rdreq && (count_r != 0);

        if (do_write) begin
            mem[wptr_r] <= data;
            wptr_r <= ptr_inc(wptr_r);
        end

        if (do_read) begin
            q <= mem[rptr_r];
            rptr_r <= ptr_inc(rptr_r);
        end

        case ({do_write, do_read})
            2'b10: count_r <= count_r + 1'b1;
            2'b01: count_r <= count_r - 1'b1;
            default: count_r <= count_r;
        endcase
    end

endmodule
