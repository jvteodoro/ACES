`timescale 1ns/1ps

module tb_fft_dma_reader;

    localparam int FFT_LENGTH   = 4;
    localparam int FFT_DW       = 18;
    localparam int READ_LATENCY = 2;

    logic clk;
    logic rst;
    logic done_i;
    logic dmaact_o;
    logic [$clog2(FFT_LENGTH)-1:0] dmaa_o;
    logic signed [FFT_DW-1:0] dmadr_real_i;
    logic signed [FFT_DW-1:0] dmadr_imag_i;
    logic fft_bin_valid_o;
    logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_o;
    logic signed [FFT_DW-1:0] fft_bin_real_o;
    logic signed [FFT_DW-1:0] fft_bin_imag_o;
    logic fft_bin_last_o;

    logic signed [FFT_DW-1:0] real_mem [0:FFT_LENGTH-1];
    logic signed [FFT_DW-1:0] imag_mem [0:FFT_LENGTH-1];
    int capture_count;

    always #5 clk = ~clk;

    always_comb begin
        dmadr_real_i = real_mem[dmaa_o];
        dmadr_imag_i = imag_mem[dmaa_o];
    end

    fft_dma_reader #(
        .FFT_LENGTH(FFT_LENGTH),
        .FFT_DW(FFT_DW),
        .READ_LATENCY(READ_LATENCY)
    ) dut (
        .clk(clk),
        .rst(rst),
        .done_i(done_i),
        .dmaact_o(dmaact_o),
        .dmaa_o(dmaa_o),
        .dmadr_real_i(dmadr_real_i),
        .dmadr_imag_i(dmadr_imag_i),
        .fft_bin_valid_o(fft_bin_valid_o),
        .fft_bin_index_o(fft_bin_index_o),
        .fft_bin_real_o(fft_bin_real_o),
        .fft_bin_imag_o(fft_bin_imag_o),
        .fft_bin_last_o(fft_bin_last_o)
    );

    always @(posedge clk) begin
        if (fft_bin_valid_o) begin
            assert (fft_bin_index_o == capture_count[$clog2(FFT_LENGTH)-1:0])
            else $fatal(1, "Index mismatch idx=%0d got=%0d", capture_count, fft_bin_index_o);

            assert (fft_bin_real_o == real_mem[capture_count])
            else $fatal(1, "Real mismatch idx=%0d", capture_count);

            assert (fft_bin_imag_o == imag_mem[capture_count])
            else $fatal(1, "Imag mismatch idx=%0d", capture_count);

            assert (fft_bin_last_o == (capture_count == FFT_LENGTH-1))
            else $fatal(1, "Last mismatch idx=%0d", capture_count);

            capture_count = capture_count + 1;
        end
    end

    initial begin
        real_mem[0] = 18'sd10; imag_mem[0] = -18'sd1;
        real_mem[1] = 18'sd20; imag_mem[1] = -18'sd2;
        real_mem[2] = 18'sd30; imag_mem[2] = -18'sd3;
        real_mem[3] = 18'sd40; imag_mem[3] = -18'sd4;

        clk          = 1'b0;
        rst          = 1'b1;
        done_i       = 1'b0;
        capture_count= 0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        @(posedge clk);
        done_i = 1'b1;
        @(posedge clk);
        done_i = 1'b0;

        wait (capture_count == FFT_LENGTH);
        @(posedge clk);
        assert (dmaact_o == 1'b0) else $fatal(1, "DMA deveria voltar a idle");

        $display("tb_fft_dma_reader PASSED");
        $finish;
    end

endmodule
