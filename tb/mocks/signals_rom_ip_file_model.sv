module signals_rom_ip (
    input  logic [11:0]        address,
    input  logic               clock,
    output logic signed [23:0] q
);
    logic [11:0] address_r;
    logic signed [23:0] rom_mem [0:4095];

    initial begin
        $readmemh("signals_rom_mirror.hex", rom_mem);
    end

    always_ff @(posedge clock)
        address_r <= address;

    always_comb
        q = rom_mem[address_r];

endmodule
