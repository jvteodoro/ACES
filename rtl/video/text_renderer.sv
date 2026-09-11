module text_renderer (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic       active_video,
    input  logic [31:0] frame_count,
    input  logic [7:0] bfpexp,
    output logic       text_pixel
);
    logic [7:0] glyph_bits;
    logic [7:0] character;
    logic [7:0] cell_x, cell_y;
    logic [2:0] glyph_row;

    function automatic [7:0] title_char(input integer p);
        begin
            case (p)
                0: title_char = "A"; 1: title_char = "C"; 2: title_char = "E";
                3: title_char = "S"; 4: title_char = " "; 5: title_char = "R";
                6: title_char = "E"; 7: title_char = "A"; 8: title_char = "L";
                9: title_char = "T"; 10: title_char = "I"; 11: title_char = "M";
                12: title_char = "E"; default: title_char = " ";
            endcase
        end
    endfunction

    function automatic [7:0] hex_char(input logic [3:0] value);
        begin
            if (value < 10) hex_char = 8'h30 + {4'b0, value};
            else hex_char = 8'h41 + {4'b0, (value - 4'd10)};
        end
    endfunction

    always_comb begin
        cell_x = pixel_x[9:3];
        cell_y = pixel_y[9:3];
        glyph_row = pixel_y[2:0];
        character = " ";

        if ((cell_y == 1) && (cell_x < 13))
            character = title_char(cell_x);
        else if ((cell_y == 5) && (cell_x >= 8) && (cell_x < 21)) begin
            case (cell_x - 8)
                0: character = "F"; 1: character = "F"; 2: character = "T";
                3: character = " "; 4: character = "S"; 5: character = "P";
                6: character = "E"; 7: character = "C"; 8: character = "T";
                9: character = "R"; 10: character = "U"; 11: character = "M";
                default: character = " ";
            endcase
        end else if ((cell_y == 42) && (cell_x >= 7) && (cell_x < 11)) begin
            case (cell_x - 7)
                0: character = "M"; 1: character = "F"; 2: character = "C";
                default: character = "C";
            endcase
        end else if ((cell_y == 42) && (cell_x >= 51) && (cell_x < 57)) begin
            case (cell_x - 51)
                0: character = "S"; 1: character = "T"; 2: character = "A";
                3: character = "T"; 4: character = "U"; 5: character = "S";
                default: character = " ";
            endcase
        end else if ((cell_y == 43) && (cell_x >= 51) && (cell_x < 59))
            character = hex_char(frame_count[(59-cell_x)*4 +: 4]);
        else if ((cell_y == 44) && (cell_x >= 51) && (cell_x < 53))
            character = hex_char(bfpexp[(52-cell_x)*4 +: 4]);
    end

    font_rom u_font (.char_code(character), .row(glyph_row), .row_bits(glyph_bits));
    always_comb begin
        text_pixel = active_video && (glyph_bits[7 - pixel_x[2:0]] == 1'b1);
    end
endmodule
