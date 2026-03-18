`timescale 1ns/1ps
`define USE_REAL_ROM
    // mock compatível com "endereço registrado / saída não registrada"


module tb_i2s_stimulus_manager_rom;

    localparam int SAMPLE_BITS        = 24;
    localparam int N_POINTS           = 8;
    localparam int N_EXAMPLES         = 4;
    localparam int TOTAL_SAMPLES      = N_POINTS * N_EXAMPLES;
    localparam int EXAMPLE_SEL_W      = (N_EXAMPLES <= 1) ? 1 : $clog2(N_EXAMPLES);
    localparam int POINT_IDX_W        = (N_POINTS   <= 1) ? 1 : $clog2(N_POINTS);
    localparam int ROM_ADDR_W         = (TOTAL_SAMPLES <= 1) ? 1 : $clog2(TOTAL_SAMPLES);
    localparam int STARTUP_SCK_CYCLES = 8;

    localparam time CLK_HALF = 5ns;
    localparam time SCK_HALF = 20ns;

    logic clk;
    logic rst;

    logic start_i;
    logic [EXAMPLE_SEL_W-1:0] example_sel_i;
    logic [1:0] loop_mode_i;

    logic chipen_i;
    logic lr_i;
    logic sck_i;
    logic ws_i;
    tri   sd_o;

    logic ready_o;
    logic busy_o;
    logic done_o;
    logic window_done_o;
    logic [EXAMPLE_SEL_W-1:0] current_example_o;
    logic [POINT_IDX_W-1:0] current_point_o;
    logic [ROM_ADDR_W-1:0] rom_addr_dbg_o;
    logic signed [SAMPLE_BITS-1:0] current_sample_dbg_o;
    logic [5:0] bit_index_o;
    logic [2:0] state_dbg_o;

    logic signed [23:0] rx_sample;
    logic rx_valid;

`ifndef USE_REAL_ROM
    // ==========================================================
    // MOCK da ROM IP
    // ==========================================================
    logic signed [SAMPLE_BITS-1:0] rom_mem [0:TOTAL_SAMPLES-1];
    logic [ROM_ADDR_W-1:0] addr_reg;

    integer i;

    initial begin
        // Exemplo 0: rampa pequena
        rom_mem[0] = 24'h000001;
        rom_mem[1] = 24'h000002;
        rom_mem[2] = 24'h000003;
        rom_mem[3] = 24'h000004;
        rom_mem[4] = 24'h000005;
        rom_mem[5] = 24'h000006;
        rom_mem[6] = 24'h000007;
        rom_mem[7] = 24'h000008;

        // Exemplo 1
        rom_mem[8]  = 24'h123450;
        rom_mem[9]  = 24'h123451;
        rom_mem[10] = 24'h123452;
        rom_mem[11] = 24'h123453;
        rom_mem[12] = 24'h123454;
        rom_mem[13] = 24'h123455;
        rom_mem[14] = 24'h123456;
        rom_mem[15] = 24'h123457;

        // Exemplo 2
        rom_mem[16] = -24'sh000001;
        rom_mem[17] = -24'sh000002;
        rom_mem[18] = -24'sh000003;
        rom_mem[19] = -24'sh000004;
        rom_mem[20] = -24'sh000005;
        rom_mem[21] = -24'sh000006;
        rom_mem[22] = -24'sh000007;
        rom_mem[23] = -24'sh000008;

        // Exemplo 3
        rom_mem[24] = 24'h7ABCDE;
        rom_mem[25] = 24'h6ABCDE;
        rom_mem[26] = 24'h5ABCDE;
        rom_mem[27] = 24'h4ABCDE;
        rom_mem[28] = 24'h3ABCDE;
        rom_mem[29] = 24'h2ABCDE;
        rom_mem[30] = 24'h1ABCDE;
        rom_mem[31] = 24'h0ABCDE;
    end


`endif

    // ==========================================================
    // clocks
    // ==========================================================
    initial begin
        clk = 1'b0;
        forever #CLK_HALF clk = ~clk;
    end

    initial begin
        sck_i = 1'b0;
        forever #SCK_HALF sck_i = ~sck_i;
    end

    initial begin
        ws_i = 1'b1;
        forever begin
            repeat (32) @(negedge sck_i);
            ws_i = ~ws_i;
        end
    end

    // ==========================================================
    // DUT
    // ==========================================================
    i2s_stimulus_manager_rom #(
        .SAMPLE_BITS(SAMPLE_BITS),
        .N_POINTS(N_POINTS),
        .N_EXAMPLES(N_EXAMPLES),
        .STARTUP_SCK_CYCLES(STARTUP_SCK_CYCLES),
        .INACTIVE_ZERO_SYNTH(0)
    ) dut (
        .clk(clk),
        .rst(rst),

        .start_i(start_i),
        .example_sel_i(example_sel_i),
        .loop_mode_i(loop_mode_i),

        .chipen_i(chipen_i),
        .lr_i(lr_i),
        .sck_i(sck_i),
        .ws_i(ws_i),
        .sd_o(sd_o),

        .ready_o(ready_o),
        .busy_o(busy_o),
        .done_o(done_o),
        .window_done_o(window_done_o),
        .current_example_o(current_example_o),
        .current_point_o(current_point_o),
        .rom_addr_dbg_o(rom_addr_dbg_o),
        .current_sample_dbg_o(current_sample_dbg_o),
        .bit_index_o(bit_index_o),
        .state_dbg_o(state_dbg_o)
    );

    // ==========================================================
    // Receiver para validar a serialização I2S
    // ==========================================================
    i2s_rx_adapter_24 u_rx (
        .rst(rst),
        .sck_i(sck_i),
        .ws_i(ws_i),
        .sd_i(sd_o),
        .sample_valid_o(rx_valid),
        .sample_24_o(rx_sample)
    );

    // ==========================================================
    // scoreboard
    // ==========================================================
    integer rx_count;
    integer expected_addr;
    bit saw_z_on_inactive;

    task automatic check_expected_sample(input int addr);
        begin
`ifndef USE_REAL_ROM
            assert(rx_sample === rom_mem[addr])
            else $error("Sample mismatch: addr=%0d exp=0x%06h got=0x%06h",
                        addr, rom_mem[addr][23:0], rx_sample[23:0]);
`else
            $display("RX sample at addr=%0d -> 0x%06h (valide manualmente contra a ROM IP real)",
                     addr, rx_sample[23:0]);
`endif
        end
    endtask

    always @(posedge rx_valid) begin
        check_expected_sample(expected_addr);
        rx_count = rx_count + 1;
        expected_addr = expected_addr + 1;
    end

    always @(negedge sck_i) begin
        if (((lr_i == 1'b0) && (ws_i == 1'b1)) ||
            ((lr_i == 1'b1) && (ws_i == 1'b0))) begin
            if (sd_o === 1'bz)
                saw_z_on_inactive = 1'b1;
        end
    end

    // ==========================================================
    // cenário 1: sem loop, exemplo 1
    // ==========================================================
    initial begin
        rst              = 1'b1;
        start_i          = 1'b0;
        example_sel_i    = '0;
        loop_mode_i      = 2'b00;
        chipen_i         = 1'b0;
        lr_i             = 1'b0;

        rx_count         = 0;
        expected_addr    = 0;
        saw_z_on_inactive = 1'b0;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        chipen_i = 1'b1;

        wait (ready_o == 1'b1);

        example_sel_i = 1;  // exemplo 1
        loop_mode_i   = 2'b00;
        expected_addr = 1 * N_POINTS;

        start_i = 1'b1;
        @(posedge clk);
        start_i = 1'b0;

        wait (done_o == 1'b1);
        repeat (10) @(posedge clk);

        assert(rx_count == N_POINTS)
        else $error("Sem loop: esperado %0d samples, obtido %0d", N_POINTS, rx_count);

        assert(saw_z_on_inactive)
        else $error("Nao foi observado Z no canal inativo");

        $display("Cenario 1 OK");
    end

    // ==========================================================
    // cenário 2: loop no exemplo
    // ==========================================================
    initial begin
        wait(done_o == 1'b1);
        repeat (20) @(posedge clk);

        rx_count      = 0;
        expected_addr = 2 * N_POINTS;

        example_sel_i = 2;
        loop_mode_i   = 2'b01;

        start_i = 1'b1;
        @(posedge clk);
        start_i = 1'b0;

        wait (rx_count >= N_POINTS + 2);

        $display("Cenario 2 OK");
    end

    // ==========================================================
    // cenário 3: loop em todos os exemplos
    // ==========================================================
    initial begin
        wait(rx_count >= N_POINTS + 2);
        repeat (20) @(posedge clk);

        rx_count      = 0;
        expected_addr = 3 * N_POINTS;

        example_sel_i = 3;
        loop_mode_i   = 2'b10;

        start_i = 1'b1;
        @(posedge clk);
        start_i = 1'b0;

        wait (rx_count >= N_POINTS + 4);

        $display("Cenario 3 OK");

        $display("tb_i2s_stimulus_manager_rom PASSED");
        $finish;
    end

endmodule