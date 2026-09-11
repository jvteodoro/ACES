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

    // Fixed labels are decoded as characters so no framebuffer or string
    // storage is required. The graph uses a logarithmic frequency axis and a
    // normalized magnitude axis; the labels deliberately expose that fact.
    function automatic [7:0] label_char(input integer line, input integer p);
        begin
            label_char = " ";
            case (line)
                0: case (p) 0: label_char="M"; 1: label_char="A"; 2: label_char="X"; endcase
                1: case (p) 0: label_char="3"; 1: label_char="/"; 2: label_char="4"; endcase
                2: case (p) 0: label_char="1"; 1: label_char="/"; 2: label_char="2"; endcase
                3: case (p) 0: label_char="1"; 1: label_char="/"; 2: label_char="4"; endcase
                4: case (p) 0: label_char="0"; endcase
                5: case (p) 0: label_char="5"; 1: label_char="0"; endcase
                6: case (p) 0: label_char="5"; 1: label_char="0"; 2: label_char="0"; endcase
                7: case (p) 0: label_char="4"; 1: label_char="K"; endcase
                8: case (p) 0: label_char="1"; 1: label_char="2"; 2: label_char="K"; endcase
                9: case (p) 0: label_char="2"; 1: label_char="4"; 2: label_char="K"; endcase
                10: case (p) 0: label_char="F"; 1: label_char="R"; 2: label_char="E"; 3: label_char="Q"; 5: label_char="L"; 6: label_char="O"; 7: label_char="G"; endcase
                11: case (p) 0: label_char="R"; 1: label_char="U"; 2: label_char="N"; endcase
                12: case (p) 0: label_char="B"; 1: label_char="U"; 2: label_char="S"; 3: label_char="Y"; endcase
                13: case (p) 0: label_char="D"; 1: label_char="O"; 2: label_char="N"; 3: label_char="E"; endcase
                14: case (p) 0: label_char="E"; 1: label_char="R"; 2: label_char="R"; endcase
                15: case (p) 0: label_char="F"; 1: label_char="R"; 2: label_char="A"; 3: label_char="M"; 4: label_char="E"; endcase
                16: case (p) 0: label_char="B"; 1: label_char="F"; 2: label_char="P"; endcase
                default: label_char = " ";
            endcase
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
        end else if ((cell_y == 8) && (cell_x >= 1) && (cell_x < 4))
            character = label_char(0, cell_x - 1);
        else if ((cell_y == 13) && (cell_x >= 1) && (cell_x < 4))
            character = label_char(1, cell_x - 1);
        else if ((cell_y == 18) && (cell_x >= 1) && (cell_x < 4))
            character = label_char(2, cell_x - 1);
        else if ((cell_y == 23) && (cell_x >= 1) && (cell_x < 4))
            character = label_char(3, cell_x - 1);
        else if ((cell_y == 35) && (cell_x >= 1) && (cell_x < 2))
            character = label_char(4, cell_x - 1);
        else if ((cell_y == 34) && (cell_x >= 8) && (cell_x < 16))
            character = label_char(10, cell_x - 8);
        else if ((cell_y == 36) && (cell_x >= 8) && (cell_x < 10))
            character = label_char(5, cell_x - 8);
        else if ((cell_y == 36) && (cell_x >= 32) && (cell_x < 35))
            character = label_char(6, cell_x - 32);
        else if ((cell_y == 36) && (cell_x >= 53) && (cell_x < 55))
            character = label_char(7, cell_x - 53);
        else if ((cell_y == 36) && (cell_x >= 64) && (cell_x < 67))
            character = label_char(8, cell_x - 64);
        else if ((cell_y == 36) && (cell_x >= 71) && (cell_x < 74))
            character = label_char(9, cell_x - 71);
        else if ((cell_y == 43) && (cell_x >= 57) && (cell_x < 60))
            character = label_char(11, cell_x - 57);
        else if ((cell_y == 45) && (cell_x >= 57) && (cell_x < 61))
            character = label_char(12, cell_x - 57);
        else if ((cell_y == 47) && (cell_x >= 57) && (cell_x < 61))
            character = label_char(13, cell_x - 57);
        else if ((cell_y == 49) && (cell_x >= 57) && (cell_x < 60))
            character = label_char(14, cell_x - 57);
        else if ((cell_y == 52) && (cell_x >= 51) && (cell_x < 56))
            character = label_char(15, cell_x - 51);
        else if ((cell_y == 53) && (cell_x >= 51) && (cell_x < 59))
            character = hex_char(frame_count[(59-cell_x)*4 +: 4]);
        else if ((cell_y == 55) && (cell_x >= 51) && (cell_x < 54))
            character = label_char(16, cell_x - 51);
        else if ((cell_y == 56) && (cell_x >= 51) && (cell_x < 53))
            character = hex_char(bfpexp[(52-cell_x)*4 +: 4]);
    end

    font_rom u_font (.char_code(character), .row(glyph_row), .row_bits(glyph_bits));
    always_comb begin
        text_pixel = active_video && (glyph_bits[7 - pixel_x[2:0]] == 1'b1);
    end
endmodule
