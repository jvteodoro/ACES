`timescale 1ns/1ps

module tb_sample_bridge_and_ingest;

    localparam int SAMPLE_W = 18;
    localparam int N_SAMPLES = 4;

    logic clk = 0;
    logic mic_clk = 0;
    logic rst = 1;

    always #5  clk     = ~clk;     // 100 MHz
    always #40 mic_clk = ~mic_clk; // 12.5 MHz

    logic sample_valid_i;
    logic signed [SAMPLE_W-1:0] sample_i;

    logic fft_valid;
    logic signed [SAMPLE_W-1:0] fft_sample;

    logic sact;
    logic signed [SAMPLE_W-1:0] real_sig;
    logic signed [SAMPLE_W-1:0] imag_sig;

    logic signed [SAMPLE_W-1:0] test_vectors [0:N_SAMPLES-1];

    int sent = 0;
    int received = 0;
    logic sact_prev;

    sample_bridge_to_fft_clk #(.SAMPLE_W(SAMPLE_W)) u_bridge (
        .rst(rst),
        .mic_sck_i(mic_clk),
        .sample_valid_i(sample_valid_i),
        .sample_i(sample_i),
        .clk(clk),
        .fft_sample_valid_o(fft_valid),
        .fft_sample_o(fft_sample)
    );

    aces_fft_ingest #(.FFT_DW(SAMPLE_W)) u_ingest (
        .clk(clk),
        .rst(rst),
        .fft_sample_valid_i(fft_valid),
        .fft_sample_i(fft_sample),
        .sact_istream_o(sact),
        .sdw_istream_real_o(real_sig),
        .sdw_istream_imag_o(imag_sig)
    );

    initial begin
        test_vectors[0] = 18'h00001;
        test_vectors[1] = 18'h048D1;
        test_vectors[2] = 18'h20000;
        test_vectors[3] = 18'h1EAF3;
    end

    // Drive source-domain samples as one-cycle valid pulses
    initial begin
        sample_valid_i = 1'b0;
        sample_i       = '0;

        #100;
        rst = 1'b0;

        repeat (N_SAMPLES) begin
            @(posedge mic_clk);
            sample_i       <= test_vectors[sent];
            sample_valid_i <= 1'b1;
            @(posedge mic_clk);
            sample_valid_i <= 1'b0;
            sent <= sent + 1;
        end
    end

    // Temporal and functional assertions in FFT clock domain
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            received  <= 0;
            sact_prev <= 1'b0;
        end else begin
            // sact must be one-shot, never high in two consecutive clk cycles
            assert (!(sact && sact_prev))
            else $error("sact_istream_o stayed high for more than one clk cycle");

            sact_prev <= sact;

            // whenever sact rises, real must match current expected sample and imag must be zero
            if (sact) begin
                assert (received < N_SAMPLES)
                else $error("Received more samples than expected");

                assert (real_sig == test_vectors[received])
                else $error("FFT ingest real_sig mismatch at idx=%0d exp=0x%05h got=0x%05h",
                            received, test_vectors[received], real_sig);

                assert (imag_sig == '0)
                else $error("FFT ingest imag must be zero at idx=%0d", received);

                assert (fft_valid)
                else $error("sact asserted without fft_sample_valid_i in same cycle");

                received <= received + 1;
            end

            // if fft_valid is asserted, the bridge sample must be stable and ingest must pulse sact
            if (fft_valid) begin
                assert (sact)
                else $error("fft_sample_valid_o asserted but sact_istream_o did not pulse");

                assert (real_sig == fft_sample)
                else $error("real_sig output differs from bridged sample");
            end
        end
    end

    initial begin
        #5000;
        assert (received == N_SAMPLES)
        else $error("Did not receive all samples, got %0d expected %0d", received, N_SAMPLES);

        $display("tb_sample_bridge_and_ingest PASSED");
        $finish;
    end

endmodule
