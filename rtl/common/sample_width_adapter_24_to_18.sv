module sample_width_adapter_24_to_18 (
    input  logic signed [23:0] sample_24_i,
    input logic valid_24_i,
    output logic signed [17:0] sample_18_o,
    output logic valid_18_o
);
    // Sign-preserving arithmetic truncation:
    // keep the 18 MSBs and discard 6 LSBs.
    always_comb begin
        sample_18_o = sample_24_i[23:6];
        valid_18_o = valid_24_i;
    end
endmodule
