module twrom (
    input  logic [7:0]  address,
    input  logic        clock,
    output logic [17:0] q
);
    logic [17:0] rom_mem [0:255];

    initial begin
        string line_s;
        integer fd_i;
        integer addr_i;
        integer data_i;

        for (addr_i = 0; addr_i < 256; addr_i = addr_i + 1)
            rom_mem[addr_i] = '0;

        fd_i = $fopen("twrom.mif", "r");
        if (fd_i == 0)
            $fatal(1, "Nao foi possivel abrir twrom.mif para o modelo de simulacao.");

        while (!$feof(fd_i)) begin
            void'($fgets(line_s, fd_i));
            if ($sscanf(line_s, "%d : %d;", addr_i, data_i) == 2)
                rom_mem[addr_i[7:0]] = {2'b00, data_i[15:0]};
        end

        $fclose(fd_i);
    end

    always_comb
        q = rom_mem[address];

endmodule
