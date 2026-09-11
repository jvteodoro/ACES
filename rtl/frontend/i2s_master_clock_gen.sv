module i2s_master_clock_gen #(
    parameter int CLOCK_DIV = 16,
    parameter bit USE_FRACTIONAL_CLOCK = 1'b0,
    parameter int SYSTEM_CLOCK_HZ = 50_000_000,
    parameter int AUDIO_SAMPLE_RATE_HZ = 48_000,
    parameter int I2S_SLOTS_PER_FRAME = 64
)(
    input  logic clk,
    input  logic rst,
    output logic sck_o,
    output logic ws_o
);

    logic [$clog2(CLOCK_DIV)-1:0] div_cnt;
    logic [5:0] frame_bit_cnt;
    logic [31:0] phase_acc;

    localparam int BCLK_HZ = AUDIO_SAMPLE_RATE_HZ * I2S_SLOTS_PER_FRAME;

    generate
        if (USE_FRACTIONAL_CLOCK) begin : gen_fractional_clock
            // NCO divider: the average BCLK is exact to the integer parameter
            // ratio, unlike the legacy integer CLOCK_DIV divider.
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    phase_acc     <= '0;
                    sck_o         <= 1'b0;
                    ws_o          <= 1'b1;
                    frame_bit_cnt <= 6'd0;
                end else if (phase_acc + BCLK_HZ >= SYSTEM_CLOCK_HZ) begin
                    phase_acc <= phase_acc + BCLK_HZ - SYSTEM_CLOCK_HZ;
                    sck_o <= ~sck_o;

                    if (!sck_o) begin
                        if (frame_bit_cnt == I2S_SLOTS_PER_FRAME-1)
                            frame_bit_cnt <= 6'd0;
                        else
                            frame_bit_cnt <= frame_bit_cnt + 1'b1;
                        ws_o <= (frame_bit_cnt < I2S_SLOTS_PER_FRAME/2) ? 1'b1 : 1'b0;
                    end
                end else begin
                    phase_acc <= phase_acc + BCLK_HZ;
                end
            end
        end else begin : gen_integer_clock
            always_ff @(posedge clk or posedge rst) begin
                if (rst) begin
                    div_cnt       <= '0;
                    sck_o         <= 1'b0;
                    ws_o          <= 1'b1;
                    frame_bit_cnt <= 6'd0;
                end else if (div_cnt == CLOCK_DIV-1) begin
                    div_cnt <= '0;
                    sck_o   <= ~sck_o;
                    if (!sck_o) begin
                        if (frame_bit_cnt == I2S_SLOTS_PER_FRAME-1)
                            frame_bit_cnt <= 6'd0;
                        else
                            frame_bit_cnt <= frame_bit_cnt + 1'b1;
                        ws_o <= (frame_bit_cnt < I2S_SLOTS_PER_FRAME/2) ? 1'b1 : 1'b0;
                    end
                end else begin
                    div_cnt <= div_cnt + 1'b1;
                end
            end
        end
    endgenerate

endmodule
