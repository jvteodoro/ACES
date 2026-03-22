`timescale 1ns/1ps

module tb_i2s_master_clock_gen;

    localparam int CLOCK_DIV = 4;
    localparam int HALF_FRAME_BITS = 32;

    logic clk;
    logic rst;
    logic sck_o;
    logic ws_o;

    int clk_edges_since_toggle;
    int sck_toggle_count;
    int ws_transition_count;
    logic prev_sck;
    logic prev_ws;

    always #5 clk = ~clk;

    i2s_master_clock_gen #(
        .CLOCK_DIV(CLOCK_DIV)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sck_o(sck_o),
        .ws_o(ws_o)
    );

    always @(posedge clk) begin
        if (rst) begin
            clk_edges_since_toggle <= 0;
            sck_toggle_count       <= 0;
            ws_transition_count    <= 0;
            prev_sck               <= 1'b0;
            prev_ws                <= 1'b1;
        end else begin
            clk_edges_since_toggle <= clk_edges_since_toggle + 1;

            if (sck_o != prev_sck) begin
                assert (clk_edges_since_toggle == CLOCK_DIV)
                else $error("SCK mudou fora do divisor esperado: %0d", clk_edges_since_toggle);

                clk_edges_since_toggle <= 0;
                sck_toggle_count       <= sck_toggle_count + 1;
                prev_sck               <= sck_o;
            end

            if (ws_o != prev_ws) begin
                ws_transition_count <= ws_transition_count + 1;
                prev_ws             <= ws_o;
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        repeat (HALF_FRAME_BITS * 2 * CLOCK_DIV * 2 + 8) @(posedge clk);

        assert (sck_toggle_count > 64)
        else $error("Poucos toggles de SCK observados: %0d", sck_toggle_count);

        assert (ws_transition_count >= 2)
        else $error("WS nao alternou como esperado");

        $display("tb_i2s_master_clock_gen PASSED");
        $finish;
    end

endmodule
