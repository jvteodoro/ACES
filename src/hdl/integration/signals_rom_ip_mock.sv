module signals_rom_ip #(
    localparam int SAMPLE_BITS        = 24,
    localparam int N_POINTS           = 8,
    localparam int N_EXAMPLES         = 4,
    localparam int TOTAL_SAMPLES      = N_POINTS * N_EXAMPLES,
    localparam int EXAMPLE_SEL_W      = (N_EXAMPLES <= 1) ? 1 : $clog2(N_EXAMPLES),
    localparam int POINT_IDX_W        = (N_POINTS   <= 1) ? 1 : $clog2(N_POINTS),
    localparam int ROM_ADDR_W         = (TOTAL_SAMPLES <= 1) ? 1 : $clog2(TOTAL_SAMPLES),
    localparam int STARTUP_SCK_CYCLES = 8

) (
    
        input  logic clock,
        input  logic [ROM_ADDR_W-1:0] address,
        output logic signed [SAMPLE_BITS-1:0] q
    );
    
    logic [ROM_ADDR_W-1:0] address_r;
    logic signed [SAMPLE_BITS-1:0] rom_mem [0:TOTAL_SAMPLES-1];

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

        always_ff @(posedge clock) begin
            address_r <= address;
        end

        always_comb begin
            q = rom_mem[address_r];
        end
endmodule