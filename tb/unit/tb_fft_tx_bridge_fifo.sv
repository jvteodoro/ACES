`timescale 1ns/1ps

module tb_fft_tx_bridge_fifo;

    localparam int FFT_DW     = 18;
    localparam int BFPEXP_W   = 8;
    localparam int FIFO_DEPTH = 4;
    localparam time CLK_HALF  = 5ns;

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

    always #CLK_HALF clk = ~clk;

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

    task automatic expect_status(
        input int expected_level,
        input bit expected_empty,
        input bit expected_full
    );
        begin
            #1;
            assert (level_o == expected_level)
            else $fatal(1, "Level mismatch: exp=%0d got=%0d", expected_level, level_o);

            assert (empty_o === expected_empty)
            else $fatal(1, "empty_o mismatch: exp=%0b got=%0b", expected_empty, empty_o);

            assert (full_o === expected_full)
            else $fatal(1, "full_o mismatch: exp=%0b got=%0b", expected_full, full_o);

            assert (valid_o === !expected_empty)
            else $fatal(1, "valid_o mismatch: exp=%0b got=%0b", !expected_empty, valid_o);
        end
    endtask

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
        end
    endtask

    task automatic push_pop_same_cycle(
        input logic signed [FFT_DW-1:0] push_real_i,
        input logic signed [FFT_DW-1:0] push_imag_i,
        input logic push_last_i,
        input logic signed [BFPEXP_W-1:0] push_exp_i
    );
        begin
            @(negedge clk);
            push_i      = 1'b1;
            pop_i       = 1'b1;
            fft_real_i  = push_real_i;
            fft_imag_i  = push_imag_i;
            fft_last_i  = push_last_i;
            bfpexp_i    = push_exp_i;
            @(posedge clk);
            @(negedge clk);
            push_i      = 1'b0;
            pop_i       = 1'b0;
            fft_last_i  = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (!rst) begin
            assert (valid_o == !empty_o)
            else $fatal(1, "valid_o e empty_o divergem.");

            assert (full_o == (level_o == FIFO_DEPTH))
            else $fatal(1, "full_o incoerente com level_o=%0d", level_o);

            assert (empty_o == (level_o == 0))
            else $fatal(1, "empty_o incoerente com level_o=%0d", level_o);

            assert (!(full_o && empty_o))
            else $fatal(1, "FIFO nao pode estar full e empty ao mesmo tempo.");
        end
    end

    initial begin
        clk        = 1'b0;
        rst        = 1'b1;
        push_i     = 1'b0;
        pop_i      = 1'b0;
        fft_real_i = '0;
        fft_imag_i = '0;
        fft_last_i = 1'b0;
        bfpexp_i   = '0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        expect_status(0, 1'b1, 1'b0);
        assert (overflow_o == 1'b0)
        else $fatal(1, "overflow_o deveria iniciar em 0.");

        push_one(18'sd10, -18'sd10, 1'b0, 8'sd3);
        expect_status(1, 1'b0, 1'b0);
        assert (fft_real_o === 18'sd10 && fft_imag_o === -18'sd10)
        else $fatal(1, "Cabeca da FIFO nao refletiu o primeiro push.");

        push_one(18'sd20, -18'sd20, 1'b0, 8'sd4);
        expect_status(2, 1'b0, 1'b0);
        assert (fft_real_o === 18'sd10)
        else $fatal(1, "FIFO deveria preservar a ordenacao na cabeca.");

        pop_expect(18'sd10, -18'sd10, 1'b0, 8'sd3);
        expect_status(1, 1'b0, 1'b0);
        pop_expect(18'sd20, -18'sd20, 1'b0, 8'sd4);
        expect_status(0, 1'b1, 1'b0);

        push_one(18'sd1, -18'sd1, 1'b0, 8'sd1);
        push_one(18'sd2, -18'sd2, 1'b0, 8'sd2);
        push_one(18'sd3, -18'sd3, 1'b0, 8'sd3);
        push_one(18'sd4, -18'sd4, 1'b1, 8'sd4);
        expect_status(FIFO_DEPTH, 1'b0, 1'b1);
        assert (fft_real_o === 18'sd1)
        else $fatal(1, "Cabeca deveria permanecer no primeiro elemento apos enchimento.");

        push_one(18'sd99, -18'sd99, 1'b0, 8'sd7);
        #1;
        assert (overflow_o)
        else $fatal(1, "overflow_o deveria pulsar apos push em FIFO cheia.");
        expect_status(FIFO_DEPTH, 1'b0, 1'b1);
        assert (fft_real_o === 18'sd1 && fft_imag_o === -18'sd1)
        else $fatal(1, "Push com overflow nao deve corromper a cabeca da FIFO.");

        push_pop_same_cycle(18'sd55, -18'sd55, 1'b1, -8'sd5);
        #1;
        assert (overflow_o == 1'b0)
        else $fatal(1, "Push+pop simultaneo nao deveria gerar overflow.");
        expect_status(FIFO_DEPTH, 1'b0, 1'b1);

        pop_expect(18'sd2, -18'sd2, 1'b0, 8'sd2);
        pop_expect(18'sd3, -18'sd3, 1'b0, 8'sd3);
        pop_expect(18'sd4, -18'sd4, 1'b1, 8'sd4);
        pop_expect(18'sd55, -18'sd55, 1'b1, -8'sd5);
        expect_status(0, 1'b1, 1'b0);

        $display("tb_fft_tx_bridge_fifo PASSED");
        $finish;
    end

endmodule
