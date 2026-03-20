`timescale 1ns/1ps

module tb_aces_stimulus_manager;

    localparam int SAMPLE_BITS        = 24;
    localparam int ROM_DEPTH          = 4;
    localparam int ROM_ADDR_W         = 4;
    localparam int STARTUP_SCK_CYCLES = 8;
    localparam time CLK_HALF          = 5ns;
    localparam time SCK_HALF          = 20ns;

    logic clk;
    logic rst;
    logic sck_i;
    logic ws_i;

    logic start_i;
    logic loop_enable_i;
    logic [ROM_ADDR_W-1:0] base_addr_i;
    logic [ROM_ADDR_W-1:0] signal_length_i;
    tri   sd_o;

    logic [ROM_ADDR_W-1:0] rom_addr_o;
    logic signed [SAMPLE_BITS-1:0] rom_data_i;
    logic busy_o, done_o, ready_o;
    logic [ROM_ADDR_W-1:0] sample_index_o;
    logic [5:0] bit_index_o;
    logic signed [SAMPLE_BITS-1:0] current_sample_dbg_o;

    logic signed [23:0] rx_sample;
    logic rx_valid;
    logic signed [SAMPLE_BITS-1:0] rom_mem [0:ROM_DEPTH-1];
    int rx_count;
    bit saw_z_on_inactive;

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

    initial begin
        rom_mem[0] = 24'h000001;
        rom_mem[1] = 24'h123456;
        rom_mem[2] = 24'h800000;
        rom_mem[3] = 24'h7ABCDE;
    end

    always_ff @(posedge clk) rom_data_i <= rom_mem[rom_addr_o];

    i2s_stimulus_manager #(
        .SAMPLE_BITS(SAMPLE_BITS),
        .ROM_ADDR_W(ROM_ADDR_W),
        .GENERATE_CLOCKS(0),
        .STARTUP_SCK_CYCLES(STARTUP_SCK_CYCLES),
        .INACTIVE_ZERO_SYNTH(0)
    ) dut (
        .clk(clk), .rst(rst), .start_i(start_i), .loop_enable_i(loop_enable_i),
        .base_addr_i(base_addr_i), .signal_length_i(signal_length_i), .chipen_i(1'b1), .lr_i(1'b0),
        .sck_i(sck_i), .ws_i(ws_i), .sck_o(), .ws_o(), .sd_o(sd_o), .rom_addr_o(rom_addr_o), .rom_data_i(rom_data_i),
        .busy_o(busy_o), .done_o(done_o), .ready_o(ready_o), .sample_index_o(sample_index_o), .bit_index_o(bit_index_o), .current_sample_dbg_o(current_sample_dbg_o)
    );

    i2s_rx_adapter_24 u_rx (
        .rst(rst), .sck_i(sck_i), .ws_i(ws_i), .sd_i(sd_o), .sample_valid_o(rx_valid), .sample_24_o(rx_sample)
    );

    always @(posedge rx_valid) begin
        assert (rx_count < ROM_DEPTH) else $error("Received more loopback samples than expected");
        assert (rx_sample === rom_mem[rx_count]) else $error("Loopback mismatch idx=%0d", rx_count);
        rx_count = rx_count + 1;
    end

    always @(negedge sck_i) begin
        if (busy_o && ws_i == 1'b1 && sd_o === 1'bz)
            saw_z_on_inactive = 1'b1;
    end

    initial begin
        rst               = 1'b1;
        start_i           = 1'b0;
        loop_enable_i     = 1'b0;
        base_addr_i       = '0;
        signal_length_i   = ROM_DEPTH;
        rx_count          = 0;
        saw_z_on_inactive = 1'b0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (4) @(posedge clk);

        start_i = 1'b1;
        @(posedge clk);
        start_i = 1'b0;

        wait(done_o === 1'b1);
        repeat (10) @(posedge clk);

        assert (rx_count == ROM_DEPTH) else $error("Expected %0d received samples, got %0d", ROM_DEPTH, rx_count);
        assert (saw_z_on_inactive) else $error("Expected Z on inactive I2S half-frame");

        $display("tb_aces_stimulus_manager PASSED");
        $finish;
    end

endmodule
