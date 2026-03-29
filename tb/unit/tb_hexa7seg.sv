`timescale 1ns/1ps

module tb_hexa7seg;

    logic [3:0] hexa;
    logic [6:0] display;

    logic [6:0] expected [0:15];
    int idx;

    hexa7seg dut (
        .hexa(hexa),
        .display(display)
    );

    initial begin
        expected[4'h0] = 7'b1000000;
        expected[4'h1] = 7'b1111001;
        expected[4'h2] = 7'b0100100;
        expected[4'h3] = 7'b0110000;
        expected[4'h4] = 7'b0011001;
        expected[4'h5] = 7'b0010010;
        expected[4'h6] = 7'b0000010;
        expected[4'h7] = 7'b1111000;
        expected[4'h8] = 7'b0000000;
        expected[4'h9] = 7'b0010000;
        expected[4'hA] = 7'b0001000;
        expected[4'hB] = 7'b0000011;
        expected[4'hC] = 7'b1000110;
        expected[4'hD] = 7'b0100001;
        expected[4'hE] = 7'b0000110;
        expected[4'hF] = 7'b0001110;

        for (idx = 0; idx < 16; idx++) begin
            hexa = idx[3:0];
            #1;

            assert (display === expected[idx])
            else $fatal(1, "hexa7seg mismatch for input 0x%0h: got=%07b expected=%07b",
                        hexa, display, expected[idx]);
        end

        $display("tb_hexa7seg PASSED");
        $finish;
    end

endmodule
