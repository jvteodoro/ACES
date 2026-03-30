module dpram (
    input  logic        clock,
    input  logic [35:0] data,
    input  logic [7:0]  rdaddress,
    input  logic [7:0]  wraddress,
    input  logic        wren,
    output logic [35:0] q
);
    logic [7:0] address_r;
    logic [35:0] mem [0:255];

    integer idx_i;
    initial begin
        for (idx_i = 0; idx_i < 256; idx_i = idx_i + 1)
            mem[idx_i] = '0;
    end

    always @(posedge clock) begin
        if (wren)
            mem[wraddress] <= data;
        address_r <= rdaddress;
    end

    always_comb
        q = mem[address_r];

endmodule
