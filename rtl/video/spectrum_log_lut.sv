// Compact logarithmic mapping for the VGA spectrum.
// One entry covers eight horizontal pixels, keeping the pixel path small.
// Values are FFT bin indices for a 1024-point FFT (bins 1..511).
module spectrum_log_lut (
    input  logic [5:0]  x_segment,
    input  logic [2:0]  x_subpixel,
    output logic [8:0]  bin_index
);
    logic [8:0] base_bin;
    logic [8:0] next_bin;
    logic [8:0] bin_delta;
    logic [11:0] fractional_delta;
    logic [11:0] interpolated_bin;

    function automatic [8:0] lut_value(input logic [5:0] index);
        begin
            case (index)
                6'd0: lut_value=9'd1;   6'd1: lut_value=9'd1;   6'd2: lut_value=9'd1;   6'd3: lut_value=9'd1;
                6'd4: lut_value=9'd1;   6'd5: lut_value=9'd2;   6'd6: lut_value=9'd2;   6'd7: lut_value=9'd2;
                6'd8: lut_value=9'd2;   6'd9: lut_value=9'd2;   6'd10: lut_value=9'd3;  6'd11: lut_value=9'd3;
                6'd12: lut_value=9'd3;  6'd13: lut_value=9'd4;  6'd14: lut_value=9'd4;  6'd15: lut_value=9'd4;
                6'd16: lut_value=9'd5;  6'd17: lut_value=9'd5;  6'd18: lut_value=9'd6;  6'd19: lut_value=9'd7;
                6'd20: lut_value=9'd7;  6'd21: lut_value=9'd8;  6'd22: lut_value=9'd9;  6'd23: lut_value=9'd10;
                6'd24: lut_value=9'd11; 6'd25: lut_value=9'd12; 6'd26: lut_value=9'd13; 6'd27: lut_value=9'd14;
                6'd28: lut_value=9'd16; 6'd29: lut_value=9'd18; 6'd30: lut_value=9'd19; 6'd31: lut_value=9'd22;
                6'd32: lut_value=9'd24; 6'd33: lut_value=9'd26; 6'd34: lut_value=9'd29; 6'd35: lut_value=9'd32;
                6'd36: lut_value=9'd35; 6'd37: lut_value=9'd39; 6'd38: lut_value=9'd43; 6'd39: lut_value=9'd47;
                6'd40: lut_value=9'd52; 6'd41: lut_value=9'd58; 6'd42: lut_value=9'd64; 6'd43: lut_value=9'd71;
                6'd44: lut_value=9'd78; 6'd45: lut_value=9'd86; 6'd46: lut_value=9'd95; 6'd47: lut_value=9'd105;
                6'd48: lut_value=9'd116; 6'd49: lut_value=9'd128; 6'd50: lut_value=9'd141; 6'd51: lut_value=9'd156;
                6'd52: lut_value=9'd172; 6'd53: lut_value=9'd190; 6'd54: lut_value=9'd210; 6'd55: lut_value=9'd231;
                6'd56: lut_value=9'd256; 6'd57: lut_value=9'd282; 6'd58: lut_value=9'd312; 6'd59: lut_value=9'd344;
                6'd60: lut_value=9'd380; 6'd61: lut_value=9'd419; 6'd62: lut_value=9'd463; 6'd63: lut_value=9'd511;
                default: lut_value=9'd511;
            endcase
        end
    endfunction

    always_comb begin
        base_bin = lut_value(x_segment);
        next_bin = lut_value((x_segment == 6'd63) ? 6'd63 : x_segment + 6'd1);
        bin_delta = next_bin - base_bin;
        // x_subpixel/8 interpolation using shifts/adds, avoiding a generic
        // multiplier in the pixel renderer.
        case (x_subpixel)
            3'd0: fractional_delta = 12'd0;
            3'd1: fractional_delta = bin_delta >> 3;
            3'd2: fractional_delta = bin_delta >> 2;
            3'd3: fractional_delta = (bin_delta >> 2) + (bin_delta >> 3);
            3'd4: fractional_delta = bin_delta >> 1;
            3'd5: fractional_delta = (bin_delta >> 1) + (bin_delta >> 3);
            3'd6: fractional_delta = (bin_delta >> 1) + (bin_delta >> 2);
            default: fractional_delta = bin_delta - (bin_delta >> 3);
        endcase
        interpolated_bin = base_bin + fractional_delta;
        bin_index = (interpolated_bin > 12'd511) ? 9'd511 : interpolated_bin[8:0];
    end
endmodule
