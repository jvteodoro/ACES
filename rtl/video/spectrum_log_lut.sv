// Compact logarithmic mapping for the VGA spectrum.
// One entry covers eight horizontal pixels, keeping the pixel path small.
// Values are FFT bin indices for a 1024-point FFT (bins 1..511).
module spectrum_log_lut (
    input  logic [5:0]  x_segment,
    output logic [8:0]  bin_index
);
    always_comb begin
        case (x_segment)
            6'd0: bin_index=9'd1;   6'd1: bin_index=9'd1;   6'd2: bin_index=9'd1;   6'd3: bin_index=9'd1;
            6'd4: bin_index=9'd1;   6'd5: bin_index=9'd2;   6'd6: bin_index=9'd2;   6'd7: bin_index=9'd2;
            6'd8: bin_index=9'd2;   6'd9: bin_index=9'd2;   6'd10: bin_index=9'd3;  6'd11: bin_index=9'd3;
            6'd12: bin_index=9'd3;  6'd13: bin_index=9'd4;  6'd14: bin_index=9'd4;  6'd15: bin_index=9'd4;
            6'd16: bin_index=9'd5;  6'd17: bin_index=9'd5;  6'd18: bin_index=9'd6;  6'd19: bin_index=9'd7;
            6'd20: bin_index=9'd7;  6'd21: bin_index=9'd8;  6'd22: bin_index=9'd9;  6'd23: bin_index=9'd10;
            6'd24: bin_index=9'd11; 6'd25: bin_index=9'd12; 6'd26: bin_index=9'd13; 6'd27: bin_index=9'd14;
            6'd28: bin_index=9'd16; 6'd29: bin_index=9'd18; 6'd30: bin_index=9'd19; 6'd31: bin_index=9'd22;
            6'd32: bin_index=9'd24; 6'd33: bin_index=9'd26; 6'd34: bin_index=9'd29; 6'd35: bin_index=9'd32;
            6'd36: bin_index=9'd35; 6'd37: bin_index=9'd39; 6'd38: bin_index=9'd43; 6'd39: bin_index=9'd47;
            6'd40: bin_index=9'd52; 6'd41: bin_index=9'd58; 6'd42: bin_index=9'd64; 6'd43: bin_index=9'd71;
            6'd44: bin_index=9'd78; 6'd45: bin_index=9'd86; 6'd46: bin_index=9'd95; 6'd47: bin_index=9'd105;
            6'd48: bin_index=9'd116; 6'd49: bin_index=9'd128; 6'd50: bin_index=9'd141; 6'd51: bin_index=9'd156;
            6'd52: bin_index=9'd172; 6'd53: bin_index=9'd190; 6'd54: bin_index=9'd210; 6'd55: bin_index=9'd231;
            6'd56: bin_index=9'd256; 6'd57: bin_index=9'd282; 6'd58: bin_index=9'd312; 6'd59: bin_index=9'd344;
            6'd60: bin_index=9'd380; 6'd61: bin_index=9'd419; 6'd62: bin_index=9'd463; 6'd63: bin_index=9'd511;
            default: bin_index=9'd1;
        endcase
    end
endmodule
