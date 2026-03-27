`timescale 1ns/1ps

module tb_aces_audio_to_fft_pipeline;

    localparam int SAMPLE_W = 18;
    localparam int N_SAMPLES = 4;

    localparam time CLK_HALF = 5ns;    // 100 MHz
    localparam time SCK_HALF = 40ns;   // 12.5 MHz / 80 ns período

    logic clk;
    logic rst;

    logic mic_sck_i;
    logic mic_ws_i;
    logic mic_sd_i;

    logic sample_valid_mic_o;
    logic signed [SAMPLE_W-1:0] sample_mic_o;
    logic signed [23:0] sample_24_dbg_o;

    logic fft_sample_valid_o;
    logic signed [SAMPLE_W-1:0] fft_sample_o;

    logic sact_istream_o;
    logic signed [SAMPLE_W-1:0] sdw_istream_real_o;
    logic signed [SAMPLE_W-1:0] sdw_istream_imag_o;

    logic signed [23:0] expected24 [0:N_SAMPLES-1];
    logic signed [17:0] expected18 [0:N_SAMPLES-1];

    integer mic_count;
    integer fft_count;
    integer stream_count;

    logic fft_valid_d;
    logic signed [SAMPLE_W-1:0] fft_sample_d;
    logic sact_prev;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    aces_audio_to_fft_pipeline #(
        .SAMPLE_W(SAMPLE_W)
    ) dut (
        .rst(rst),
        .mic_sck_i(mic_sck_i),
        .mic_ws_i(mic_ws_i),
        .mic_sd_i(mic_sd_i),
        .clk(clk),

        .sample_valid_mic_o(sample_valid_mic_o),
        .sample_mic_o(sample_mic_o),
        .sample_24_dbg_o(sample_24_dbg_o),

        .fft_sample_valid_o(fft_sample_valid_o),
        .fft_sample_o(fft_sample_o),

        .sact_istream_o(sact_istream_o),
        .sdw_istream_real_o(sdw_istream_real_o),
        .sdw_istream_imag_o(sdw_istream_imag_o)
    );

    // ------------------------------------------------------------
    // clock do sistema
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #CLK_HALF clk = ~clk;
    end

    // ------------------------------------------------------------
    // valores esperados
    // ------------------------------------------------------------
    initial begin
        expected24[0] = 24'h000001;
        expected24[1] = 24'h123456;
        expected24[2] = 24'h800000;
        expected24[3] = 24'h7ABCDE;

        expected18[0] = expected24[0][23:6];
        expected18[1] = expected24[1][23:6];
        expected18[2] = expected24[2][23:6];
        expected18[3] = expected24[3][23:6];
    end

    // ------------------------------------------------------------
    // tarefa: 1 ciclo completo de SCK
    // setup em SCK baixo, amostragem no posedge
    // ------------------------------------------------------------
    task automatic sck_cycle(
        input logic ws_val,
        input logic sd_val
    );
        begin
            mic_ws_i = ws_val;
            mic_sd_i = sd_val;
            #SCK_HALF;
            mic_sck_i = 1'b1;
            #SCK_HALF;
            mic_sck_i = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // tarefa: envia 1 amostra no canal esquerdo
    //
    // Compatível com o receiver atual:
    // - ws muda 1->0
    // - 1 ciclo para detectar borda
    // - 1 ciclo de skip_bit
    // - 24 bits úteis MSB-first
    // - padding até 32 bits no half-frame
    // - half-frame direito em ws=1
    // ------------------------------------------------------------
    task automatic send_left_sample(
        input logic signed [23:0] sample
    );
        integer i;
        begin
            // garante que estamos em half-frame direito antes de começar
            repeat (4) sck_cycle(1'b1, 1'b0);

            // borda WS 1 -> 0 detectada no próximo posedge
            sck_cycle(1'b0, 1'b0);

            // ciclo consumido pelo skip_bit do receiver
            sck_cycle(1'b0, 1'b0);

            // 24 bits úteis
            for (i = 23; i >= 0; i = i - 1) begin
                sck_cycle(1'b0, sample[i]);
            end

            // padding restante do half-frame esquerdo:
            // total do slot = 32 ciclos
            // já usamos 2 + 24 = 26
            repeat (6) sck_cycle(1'b0, 1'b0);

            // half-frame direito completo
            repeat (32) sck_cycle(1'b1, 1'b0);
        end
    endtask

    // ------------------------------------------------------------
    // checks no domínio mic_sck
    // ------------------------------------------------------------
    always @(posedge sample_valid_mic_o) begin
        assert(mic_count < N_SAMPLES)
        else $error("Mais samples no frontend do que o esperado");

        assert(sample_24_dbg_o === expected24[mic_count])
        else $error(
            "sample_24_dbg_o mismatch idx=%0d exp=0x%06h got=0x%06h",
            mic_count, expected24[mic_count][23:0], sample_24_dbg_o[23:0]
        );

        assert(sample_mic_o === expected18[mic_count])
        else $error(
            "sample_mic_o mismatch idx=%0d exp=0x%05h got=0x%05h",
            mic_count, expected18[mic_count], sample_mic_o
        );

        mic_count = mic_count + 1;
    end

    // ------------------------------------------------------------
    // checks no domínio clk
    //
    // Esperado:
    // - fft_sample_valid_o pulse 1 ciclo com a amostra correta
    // - no ciclo seguinte:
    //     sact_istream_o = 1
    //     sdw_istream_real_o = amostra correta
    //     sdw_istream_imag_o = 0
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fft_valid_d   <= 1'b0;
            fft_sample_d  <= '0;
            sact_prev     <= 1'b0;
        end else begin
            // guarda o valid atual para checar sact no ciclo seguinte
            fft_valid_d  <= fft_sample_valid_o;
            if (fft_sample_valid_o)
                fft_sample_d <= fft_sample_o;

            // checa sequência do bridge
            if (fft_sample_valid_o) begin
                assert(fft_count < N_SAMPLES)
                else $error("Mais samples no bridge do que o esperado");

                assert(fft_sample_o === expected18[fft_count])
                else $error(
                    "fft_sample_o mismatch idx=%0d exp=0x%05h got=0x%05h",
                    fft_count, expected18[fft_count], fft_sample_o
                );

                fft_count = fft_count + 1;
            end

            // checa ingestão 1 ciclo depois do bridge valid
            if (fft_valid_d) begin
                assert(sact_istream_o === 1'b1)
                else $error("sact_istream_o deveria subir 1 ciclo após fft_sample_valid_o");

                assert(sdw_istream_real_o === fft_sample_d)
                else $error(
                    "sdw_istream_real_o mismatch exp=0x%05h got=0x%05h",
                    fft_sample_d, sdw_istream_real_o
                );

                assert(sdw_istream_imag_o === '0)
                else $error("sdw_istream_imag_o deveria ser zero");

                stream_count = stream_count + 1;
            end

            // largura do pulso de sact = 1 ciclo
            if (sact_prev && sact_istream_o) begin
                $error("sact_istream_o permaneceu alto por mais de 1 ciclo");
            end

            sact_prev <= sact_istream_o;
        end
    end

    // ------------------------------------------------------------
    // estímulo principal
    // ------------------------------------------------------------
    initial begin
        rst               = 1'b1;
        mic_sck_i         = 1'b0;
        mic_ws_i          = 1'b1;
        mic_sd_i          = 1'b0;

        mic_count         = 0;
        fft_count         = 0;
        stream_count      = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        repeat (10) @(posedge clk);

        send_left_sample(expected24[0]);
        send_left_sample(expected24[1]);
        send_left_sample(expected24[2]);
        send_left_sample(expected24[3]);

        // espera a drenagem completa do pipeline
        repeat (100) @(posedge clk);

        assert(mic_count == N_SAMPLES)
        else $error("Esperado %0d samples no frontend, obtido %0d", N_SAMPLES, mic_count);

        assert(fft_count == N_SAMPLES)
        else $error("Esperado %0d samples no bridge, obtido %0d", N_SAMPLES, fft_count);

        assert(stream_count == N_SAMPLES)
        else $error("Esperado %0d pulsos de stream, obtido %0d", N_SAMPLES, stream_count);

        $display("tb_aces_audio_to_fft_pipeline PASSED");
        $finish;
    end

endmodule