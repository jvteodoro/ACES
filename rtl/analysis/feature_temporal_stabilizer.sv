// Per-coefficient temporal EMA for noisy audio features.
// ALPHA_Q / 2^ALPHA_SHIFT controls the response (default 1/4).
module feature_temporal_stabilizer #(
    parameter int MFCC_COUNT = 13,
    parameter int DATA_W = 32,
    parameter int ALPHA_SHIFT = 2,
    parameter int ALPHA_Q = 1
) (
    input logic clk,
    input logic rst,
    input logic result_valid_i,
    input logic [$clog2(MFCC_COUNT)-1:0] result_index_i,
    input logic signed [DATA_W-1:0] result_data_i,
    input logic frame_done_i,
    output logic result_valid_o,
    output logic [$clog2(MFCC_COUNT)-1:0] result_index_o,
    output logic signed [DATA_W-1:0] result_data_o,
    output logic frame_done_o
);
    localparam int STATE_W = DATA_W + ALPHA_SHIFT + 2;
    logic signed [DATA_W-1:0] state [0:MFCC_COUNT-1];
    logic initialized [0:MFCC_COUNT-1];
    integer i;

    always_ff @(posedge clk or posedge rst) begin : stabilizer
        logic signed [STATE_W-1:0] delta;
        logic signed [STATE_W-1:0] update;
        logic signed [STATE_W-1:0] next_value;
        if (rst) begin
            result_valid_o <= 1'b0;
            result_index_o <= '0;
            result_data_o <= '0;
            frame_done_o <= 1'b0;
            for (i = 0; i < MFCC_COUNT; i = i + 1) begin
                state[i] <= '0;
                initialized[i] <= 1'b0;
            end
        end else begin
            result_valid_o <= result_valid_i;
            frame_done_o <= frame_done_i;
            if (result_valid_i) begin
                result_index_o <= result_index_i;
                if (!initialized[result_index_i]) begin
                    state[result_index_i] <= result_data_i;
                    result_data_o <= result_data_i;
                    initialized[result_index_i] <= 1'b1;
                end else begin
                    delta = result_data_i - state[result_index_i];
                    update = (delta * ALPHA_Q) >>> ALPHA_SHIFT;
                    next_value = state[result_index_i] + update;
                    if (next_value > ((1 <<< (DATA_W-1))-1))
                        state[result_index_i] <= {1'b0, {(DATA_W-1){1'b1}}};
                    else if (next_value < -(1 <<< (DATA_W-1)))
                        state[result_index_i] <= {1'b1, {(DATA_W-1){1'b0}}};
                    else
                        state[result_index_i] <= next_value[DATA_W-1:0];
                    result_data_o <= next_value[DATA_W-1:0];
                end
            end
        end
    end
endmodule
