`timescale 1 ns / 1 ns

module tb_rom_ip;
    parameter CLK_PERIOD = 10;
    logic clk;
    logic [15:0] address;
    logic [23:0] q_sig;

    signals_rom_ip	signals_rom_ip_inst (
	.address ( address ),
	.clock ( clk ),
	.q ( q_sig )
	);

    always @(clk) begin
        clk <= #CLK_PERIOD ~clk;
    end

    always @(posedge clk) begin
        address <= address+1;
    end

    initial begin
        clk <= 0;
        address <= 0;
        #CLK_PERIOD;
        while (address != {15{1'b1}}) begin
            #CLK_PERIOD;
        end
        $finish;
    end

 

endmodule