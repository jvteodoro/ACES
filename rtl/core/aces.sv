module aces #(
    parameter int I2S_CLOCK_DIV = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic mic_lr_sel_i,

    output logic mic_sck_o,
    output logic mic_ws_o,
    output logic mic_chipen_o,
    output logic mic_lr_sel_o
);

    assign mic_chipen_o = 1'b1;
    assign mic_lr_sel_o = mic_lr_sel_i;

    i2s_master_clock_gen #(
        .CLOCK_DIV(I2S_CLOCK_DIV)
    ) u_i2s_master_clock_gen (
        .clk(clk),
        .rst(rst),
        .sck_o(mic_sck_o),
        .ws_o(mic_ws_o)
    );

endmodule
