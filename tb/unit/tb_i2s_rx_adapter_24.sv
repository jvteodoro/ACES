`timescale 1ns/1ps

module tb_i2s_rx_adapter_24;

    localparam int ROM_DEPTH = 10;
    localparam time SCK_HALF = 50ns;

    logic rst;
    logic sck_i;
    logic ws_i;
    logic sd_i;

    logic sample_valid_o;
    logic signed [23:0] sample_24_o;

    logic signed [23:0] rom [0:ROM_DEPTH-1];
    logic signed [23:0] captured_samples[$];
    logic signed [23:0] captured_sample;

    integer i;

    i2s_rx_adapter_24 dut (
        .rst(rst),
        .sck_i(sck_i),
        .ws_i(ws_i),
        .sd_i(sd_i),
        .sample_valid_o(sample_valid_o),
        .sample_24_o(sample_24_o)
    );

    initial begin
        rom[0] = 24'sh000001;
        rom[1] = 24'sh123456;
        rom[2] = -24'sh000001;
        rom[3] = 24'sh400000;
        rom[4] = -24'sh400000;
        rom[5] = 24'sh7ABCDE;
        rom[6] = -24'sh123456;
        rom[7] = 24'sh000000;
        rom[8] = 24'sh5BDAD5;
        rom[9] = 24'sh640466;
    end

    task automatic sck_pulse;
        begin
            #SCK_HALF sck_i = 1'b1;
            #SCK_HALF sck_i = 1'b0;
        end
    endtask

    task automatic send_one_sample(
        input logic signed [23:0] sample_in
    );
        integer bit_idx;
        begin
            // canal direito antes
            ws_i = 1'b1;
            sd_i = 1'b0;
            repeat (32) begin
                sck_pulse();
            end

            // transição 1 -> 0 inicia canal esquerdo
            ws_i = 1'b0;

            // atraso de 1 bit do I2S
            sd_i = 1'b0;
            sck_pulse();

            // 24 bits MSB-first
            for (bit_idx = 23; bit_idx >= 0; bit_idx--) begin
                sd_i = sample_in[bit_idx];
                sck_pulse();
            end

            // padding
            repeat (7) begin
                sd_i = 1'b0;
                sck_pulse();
            end
        end
    endtask

    task automatic wait_for_captured_sample(
        output logic signed [23:0] sample_out,
        input  logic signed [23:0] expected_sample
    );
        bit got_sample;
        begin
            got_sample = 1'b0;

            fork
                begin : wait_sample_block
                    wait (captured_samples.size() > 0);
                    sample_out = captured_samples.pop_front();
                    got_sample = 1'b1;
                end

                begin : timeout_block
                    #100_000ns;
                    $fatal(1, "Timeout esperando sample_valid_o para sample 0x%06h", expected_sample[23:0]);
                end
            join_any

            disable wait_sample_block;
            disable timeout_block;

            if (!got_sample) begin
                $fatal(1, "sample_valid_o nao foi observado para sample 0x%06h", expected_sample[23:0]);
            end
        end
    endtask

    // Monitora a saída no negedge de SCK, quando o pulso de sample_valid_o e
    // sample_24_o já estão estáveis após as NBAs do DUT.
    always @(negedge sck_i or posedge rst) begin
        if (rst) begin
            captured_samples.delete();
        end else if (sample_valid_o) begin
            captured_samples.push_back(sample_24_o);
        end
    end

    initial begin
        rst   = 1'b1;
        sck_i = 1'b0;
        ws_i  = 1'b1;
        sd_i  = 1'b0;

        #200;
        rst = 1'b0;
        #100;

        $display("==== INICIO DO TESTE I2S RX ADAPTER 24 ====");

        for (i = 0; i < ROM_DEPTH; i++) begin
            $display("Enviando ROM[%0d] = 0x%06h (%0d)", i, rom[i][23:0], rom[i]);

            if (captured_samples.size() != 0) begin
                $fatal(1, "Fila de samples monitorados nao esvaziou antes do idx=%0d", i);
                captured_samples.delete();
            end

            send_one_sample(rom[i]);
            wait_for_captured_sample(captured_sample, rom[i]);

            if (captured_sample !== rom[i]) begin
                $fatal(1, "ERRO idx=%0d esperado=0x%06h obtido=0x%06h",
                       i, rom[i][23:0], captured_sample[23:0]);
            end else begin
                $display("OK idx=%0d recebido=0x%06h (%0d)",
                         i, captured_sample[23:0], captured_sample);
            end

            #200ns;
        end

        $display("tb_i2s_rx_adapter_24 PASSED");
        #200ns;
        $finish;
    end

endmodule
