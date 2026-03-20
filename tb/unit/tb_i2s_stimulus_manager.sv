`timescale 1ns/1ps

module tb_i2s_stimulus_manager;
    localparam int SAMPLE_BITS = 24;
    localparam int ROM_ADDR_W  = 4;
    localparam int N_SAMPLES   = 4;

    logic clk = 0;
    logic rst;
    logic start;
    logic loop_enable;
    logic chipen_i;
    logic lr_i;
    logic sck_i, ws_i;
    logic sck_o, ws_o, sd_o;
    logic [ROM_ADDR_W-1:0] rom_addr_o;
    logic signed [SAMPLE_BITS-1:0] rom_data_i;
    logic [ROM_ADDR_W-1:0] signal_length_i;
    logic busy, done;
    logic [ROM_ADDR_W-1:0] sample_index_o;
    logic [5:0] bit_index_o;
    logic signed [SAMPLE_BITS-1:0] current_sample_dbg_o;

    logic signed [SAMPLE_BITS-1:0] rom_mem [0:N_SAMPLES-1];
    logic [ROM_ADDR_W-1:0] rom_addr_q;

    i2s_stimulus_manager #(
        .SAMPLE_BITS(SAMPLE_BITS),
        .ROM_ADDR_W(ROM_ADDR_W),
        .GENERATE_CLOCKS(1),
        .CLOCK_DIV(2)
    ) dut (
        .clk,
        .rst,
        .start,
        .loop_enable,
        .chipen_i,
        .lr_i,
        .sck_i(1'b0),
        .ws_i(1'b0),
        .sck_o,
        .ws_o,
        .sd_o,
        .rom_addr_o,
        .rom_data_i,
        .signal_length_i,
        .busy,
        .done,
        .sample_index_o,
        .bit_index_o,
        .current_sample_dbg_o
    );

    always #5 clk = ~clk;

    // synchronous ROM model
    always_ff @(posedge clk) begin
        rom_addr_q <= rom_addr_o;
        rom_data_i <= rom_mem[rom_addr_q];
    end

    initial begin
        rom_mem[0] = 24'sh123456;
        rom_mem[1] = -24'sh012345;
        rom_mem[2] = 24'sh654321;
        rom_mem[3] = -24'sh000111;
    end

    integer left_driven_bits;
    integer right_z_bits;

    always @(negedge sck_o) begin
        if (busy) begin
            if (ws_o == 1'b0 && bit_index_o >= 1 && bit_index_o <= 24) begin
                left_driven_bits = left_driven_bits + 1;
            end
            if (ws_o == 1'b1 && sd_o === 1'bz) begin
                right_z_bits = right_z_bits + 1;
            end
        end
    end

    initial begin
        rst = 1'b1;
        start = 1'b0;
        loop_enable = 1'b0;
        chipen_i = 1'b1;
        lr_i = 1'b0;
        signal_length_i = N_SAMPLES;
        rom_data_i = '0;
        rom_addr_q = '0;
        left_driven_bits = 0;
        right_z_bits = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (3) @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(done === 1'b1);
        repeat (5) @(posedge clk);

        if (left_driven_bits < N_SAMPLES*24)
            $error("manager did not drive expected number of left-channel data bits");
        if (right_z_bits == 0)
            $error("manager did not present Z on inactive channel during simulation");

        $display("tb_i2s_stimulus_manager PASSED");
        $finish;
    end
endmodule
