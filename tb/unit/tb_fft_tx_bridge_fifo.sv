`timescale 1ns/1ps

module tb_fft_tx_bridge_fifo;

    localparam int FFT_DW     = 18;
    localparam int BFPEXP_W   = 8;
    localparam int FIFO_DEPTH = 4;

    logic clk;
    logic rst;

    logic push_i;
    logic signed [FFT_DW-1:0] fft_real_i;
    logic signed [FFT_DW-1:0] fft_imag_i;
    logic fft_last_i;
    logic signed [BFPEXP_W-1:0] bfpexp_i;

    logic pop_i;

    logic valid_o;
    logic signed [FFT_DW-1:0] fft_real_o;
    logic signed [FFT_DW-1:0] fft_imag_o;
    logic fft_last_o;
    logic signed [BFPEXP_W-1:0] bfpexp_o;
    logic full_o;
    logic empty_o;
    logic overflow_o;
    logic [$clog2(FIFO_DEPTH+1)-1:0] level_o;

    always #5 clk = ~clk;

    fft_tx_bridge_fifo #(
        .FFT_DW(FFT_DW),
        .BFPEXP_W(BFPEXP_W),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .push_i(push_i),
        .fft_real_i(fft_real_i),
        .fft_imag_i(fft_imag_i),
        .fft_last_i(fft_last_i),
        .bfpexp_i(bfpexp_i),
        .pop_i(pop_i),
        .valid_o(valid_o),
        .fft_real_o(fft_real_o),
        .fft_imag_o(fft_imag_o),
        .fft_last_o(fft_last_o),
        .bfpexp_o(bfpexp_o),
        .full_o(full_o),
        .empty_o(empty_o),
        .overflow_o(overflow_o),
        .level_o(level_o)
    );

    task automatic push_one(
        input logic signed [FFT_DW-1:0] real_i,
        input logic signed [FFT_DW-1:0] imag_i,
        input logic last_i,
        input logic signed [BFPEXP_W-1:0] exp_i
    );
        begin
            @(negedge clk);
            push_i      = 1'b1;
            fft_real_i  = real_i;
            fft_imag_i  = imag_i;
            fft_last_i  = last_i;
            bfpexp_i    = exp_i;
            @(posedge clk);
            @(negedge clk);
            push_i      = 1'b0;
            fft_last_i  = 1'b0;
            #1;
        end
    endtask

    task automatic pop_expect(
        input logic signed [FFT_DW-1:0] real_e,
        input logic signed [FFT_DW-1:0] imag_e,
        input logic last_e,
        input logic signed [BFPEXP_W-1:0] exp_e
    );
        begin
            assert (valid_o)
            else $fatal(1, "FIFO deveria estar valida antes do pop.");

            assert (fft_real_o === real_e)
            else $fatal(1, "real mismatch: exp=%0d got=%0d", real_e, fft_real_o);

            assert (fft_imag_o === imag_e)
            else $fatal(1, "imag mismatch: exp=%0d got=%0d", imag_e, fft_imag_o);

            assert (fft_last_o === last_e)
            else $fatal(1, "last mismatch: exp=%0b got=%0b", last_e, fft_last_o);

            assert (bfpexp_o === exp_e)
            else $fatal(1, "bfpexp mismatch: exp=%0d got=%0d", exp_e, bfpexp_o);

            @(negedge clk);
            pop_i = 1'b1;
            @(posedge clk);
            @(negedge clk);
            pop_i = 1'b0;
            #1;
        end
    endtask

    initial begin
        clk       = 1'b0;
        rst       = 1'b1;
        push_i    = 1'b0;
        pop_i     = 1'b0;
        fft_real_i = '0;
        fft_imag_i = '0;
        fft_last_i = 1'b0;
        bfpexp_i   = '0;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        #1;

        assert (empty_o && !valid_o && !full_o && (level_o == 0) && !overflow_o)
        else $fatal(1, "Estado inicial invalido apos reset.");

        push_one(18'sd10, -18'sd10, 1'b0, 8'sd3);
        push_one(18'sd20, -18'sd20, 1'b0, 8'sd3);
        assert (level_o == 2)
        else $fatal(1, "Level esperado 2, got=%0d", level_o);

        pop_expect(18'sd10, -18'sd10, 1'b0, 8'sd3);
        pop_expect(18'sd20, -18'sd20, 1'b0, 8'sd3);

        assert (empty_o && (level_o == 0))
        else $fatal(1, "FIFO deveria estar vazia apos dois pops.");

        // Enche FIFO para testar full e overflow.
        push_one(18'sd1, -18'sd1, 1'b0, 8'sd1);
        push_one(18'sd2, -18'sd2, 1'b0, 8'sd2);
        push_one(18'sd3, -18'sd3, 1'b0, 8'sd3);
        push_one(18'sd4, -18'sd4, 1'b1, 8'sd4);
        assert (full_o && (level_o == FIFO_DEPTH))
        else $fatal(1, "FIFO deveria estar cheia.");

        push_one(18'sd99, -18'sd99, 1'b0, 8'sd7);
        assert (overflow_o)
        else $fatal(1, "overflow_o deveria ser 1 apos push em FIFO cheia.");
        assert (level_o == FIFO_DEPTH)
        else $fatal(1, "Level deveria permanecer em FIFO_DEPTH.");

        pop_expect(18'sd1, -18'sd1, 1'b0, 8'sd1);

        // Testa push+pop simultaneo sem perder alinhamento.
        @(negedge clk);
        push_i      = 1'b1;
        pop_i       = 1'b1;
        fft_real_i  = 18'sd55;
        fft_imag_i  = -18'sd55;
        fft_last_i  = 1'b1;
        bfpexp_i    = -8'sd5;
        @(posedge clk);
        @(negedge clk);
        push_i      = 1'b0;
        pop_i       = 1'b0;
        fft_last_i  = 1'b0;
        #1;

        assert (level_o == 3)
        else $fatal(1, "Level deveria manter 3 apos push+pop simultaneo, got=%0d", level_o);

        pop_expect(18'sd3, -18'sd3, 1'b0, 8'sd3);
        pop_expect(18'sd4, -18'sd4, 1'b1, 8'sd4);
        pop_expect(18'sd55, -18'sd55, 1'b1, -8'sd5);

        assert (empty_o && !valid_o && (level_o == 0))
        else $fatal(1, "FIFO deveria terminar vazia.");

        $display("tb_fft_tx_bridge_fifo PASSED");
        $finish;
    end

endmodule