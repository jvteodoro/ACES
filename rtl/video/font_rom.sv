module font_rom (
    input  logic [7:0] char_code,
    input  logic [2:0] row,
    output logic [7:0] row_bits
);
    // Compact 8x8 bitmap font. Unsupported characters intentionally render as
    // blank so text never creates random pixels.
    always_comb begin
        row_bits = 8'h00;
        case (char_code)
            "A": case(row) 0:row_bits=8'h18;1:row_bits=8'h24;2:row_bits=8'h42;3:row_bits=8'h7e;4:row_bits=8'h42;5:row_bits=8'h42;default:row_bits=0; endcase
            "C": case(row) 0:row_bits=8'h3c;1:row_bits=8'h42;2:row_bits=8'h40;3:row_bits=8'h40;4:row_bits=8'h40;5:row_bits=8'h42;6:row_bits=8'h3c;default:row_bits=0; endcase
            "E": case(row) 0:row_bits=8'h7e;1:row_bits=8'h40;2:row_bits=8'h40;3:row_bits=8'h7c;4:row_bits=8'h40;5:row_bits=8'h40;6:row_bits=8'h7e;default:row_bits=0; endcase
            "F": case(row) 0:row_bits=8'h7e;1:row_bits=8'h40;2:row_bits=8'h40;3:row_bits=8'h7c;4:row_bits=8'h40;5:row_bits=8'h40;default:row_bits=0; endcase
            "M": case(row) 0:row_bits=8'h42;1:row_bits=8'h66;2:row_bits=8'h5a;3:row_bits=8'h42;4:row_bits=8'h42;5:row_bits=8'h42;default:row_bits=0; endcase
            "S": case(row) 0:row_bits=8'h3c;1:row_bits=8'h42;2:row_bits=8'h40;3:row_bits=8'h3c;4:row_bits=8'h02;5:row_bits=8'h42;6:row_bits=8'h3c;default:row_bits=0; endcase
            "T": case(row) 0:row_bits=8'h7e;1:row_bits=8'h18;2:row_bits=8'h18;3:row_bits=8'h18;4:row_bits=8'h18;5:row_bits=8'h18;default:row_bits=0; endcase
            "U": case(row) 0:row_bits=8'h42;1:row_bits=8'h42;2:row_bits=8'h42;3:row_bits=8'h42;4:row_bits=8'h42;5:row_bits=8'h3c;default:row_bits=0; endcase
            "I": case(row) 0,5:row_bits=8'h7e;1,2,3,4:row_bits=8'h18;default:row_bits=0; endcase
            "L": case(row) 0,1,2,3,4:row_bits=8'h40;5:row_bits=8'h7e;default:row_bits=0; endcase
            "P": case(row) 0:row_bits=8'h7c;1:row_bits=8'h42;2:row_bits=8'h42;3:row_bits=8'h7c;4,5:row_bits=8'h40;default:row_bits=0; endcase
            "R": case(row) 0:row_bits=8'h7c;1:row_bits=8'h42;2:row_bits=8'h42;3:row_bits=8'h7c;4:row_bits=8'h48;5:row_bits=8'h46;default:row_bits=0; endcase
            "0": case(row) 0:row_bits=8'h3c;1:row_bits=8'h46;2:row_bits=8'h4a;3:row_bits=8'h52;4:row_bits=8'h62;5:row_bits=8'h3c;default:row_bits=0; endcase
            "1": case(row) 0:row_bits=8'h18;1:row_bits=8'h38;2:row_bits=8'h18;3:row_bits=8'h18;4:row_bits=8'h18;5:row_bits=8'h7e;default:row_bits=0; endcase
            "2": case(row) 0:row_bits=8'h3c;1:row_bits=8'h42;2:row_bits=8'h04;3:row_bits=8'h18;4:row_bits=8'h20;5:row_bits=8'h7e;default:row_bits=0; endcase
            "3": case(row) 0:row_bits=8'h3c;1:row_bits=8'h42;2:row_bits=8'h0c;3:row_bits=8'h02;4:row_bits=8'h42;5:row_bits=8'h3c;default:row_bits=0; endcase
            "4": case(row) 0:row_bits=8'h0c;1:row_bits=8'h14;2:row_bits=8'h24;3:row_bits=8'h44;4:row_bits=8'h7e;5:row_bits=8'h04;default:row_bits=0; endcase
            "5": case(row) 0:row_bits=8'h7e;1:row_bits=8'h40;2:row_bits=8'h7c;3:row_bits=8'h02;4:row_bits=8'h42;5:row_bits=8'h3c;default:row_bits=0; endcase
            "6": case(row) 0:row_bits=8'h1c;1:row_bits=8'h20;2:row_bits=8'h40;3:row_bits=8'h7c;4:row_bits=8'h42;5:row_bits=8'h3c;default:row_bits=0; endcase
            "7": case(row) 0:row_bits=8'h7e;1:row_bits=8'h04;2:row_bits=8'h08;3:row_bits=8'h10;4:row_bits=8'h20;5:row_bits=8'h20;default:row_bits=0; endcase
            "8": case(row) 0:row_bits=8'h3c;1:row_bits=8'h42;2:row_bits=8'h3c;3:row_bits=8'h42;4:row_bits=8'h42;5:row_bits=8'h3c;default:row_bits=0; endcase
            "9": case(row) 0:row_bits=8'h3c;1:row_bits=8'h42;2:row_bits=8'h3e;3:row_bits=8'h02;4:row_bits=8'h04;5:row_bits=8'h38;default:row_bits=0; endcase
            "-": case(row) 3:row_bits=8'h7e;default:row_bits=0; endcase
            ":": case(row) 2,4:row_bits=8'h18;default:row_bits=0; endcase
            ".": case(row) 5:row_bits=8'h18;default:row_bits=0; endcase
            default: row_bits = 8'h00;
        endcase
    end
endmodule
