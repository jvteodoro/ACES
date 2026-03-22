`timescale 1ns/1ps

module tb_fft_control;

    logic clk;
    logic rst;
    logic [1:0] status;
    logic sact_istream_i;
    logic run;

    always #5 clk = ~clk;

    fft_control dut (
        .clk(clk),
        .rst(rst),
        .status(status),
        .sact_istream_i(sact_istream_i),
        .run(run)
    );

    initial begin
        clk            = 1'b0;
        rst            = 1'b1;
        status         = 2'b00;
        sact_istream_i = 1'b0;

        repeat (2) @(posedge clk);
        rst = 1'b0;

        @(posedge clk);
        sact_istream_i = 1'b1;
        status         = 2'b00;
        @(posedge clk);
        assert (run == 1'b0) else $error("run nao deveria subir sem buffer cheio");

        status         = 2'b10;
        @(posedge clk);
        assert (run == 1'b1) else $error("run deveria subir quando status==S_FBUFFER");

        sact_istream_i = 1'b0;
        status         = 2'b00;
        @(posedge clk);
        assert (run == 1'b0) else $error("run deveria cair ao voltar para IDLE");

        @(posedge clk);
        sact_istream_i = 1'b1;
        status         = 2'b10;
        @(posedge clk);
        sact_istream_i = 1'b0;
        status         = 2'b10;
        @(posedge clk);
        assert (run == 1'b1) else $error("run deveria persistir por um ciclo em FFT_FULL");

        @(posedge clk);
        assert (run == 1'b0) else $error("run deveria limpar apos sair de FFT_FULL");

        $display("tb_fft_control PASSED");
        $finish;
    end

endmodule
