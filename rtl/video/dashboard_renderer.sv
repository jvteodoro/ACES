module dashboard_renderer (
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic       active_video,
    input  logic [19:0] spectrum_value,
    input  logic signed [31:0] mfcc_value,
    input  logic [7:0] bfpexp,
    input  logic       fft_run,
    input  logic       fft_done,
    input  logic [2:0] fft_status,
    input  logic [1:0] fft_input_status,
    input  logic       feature_busy,
    input  logic [31:0] frame_count,
    output logic [8:0] spectrum_read_index,
    output logic [3:0] mfcc_read_index,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
);
    localparam logic [11:0] BLACK = 12'h000, WHITE = 12'hfff;
    localparam logic [11:0] GRID = 12'h345, CYAN = 12'h0cf;
    localparam logic [11:0] GREEN = 12'h0f0, YELLOW = 12'hff0, RED = 12'hf00;
    logic text_pixel;
    logic [11:0] pixel_color;
    logic [9:0] spectrum_slot;
    logic [8:0] log_bin_index;
    integer spectrum_height, mfcc_height, mfcc_mag, mfcc_slot;

    // spectrum_value is peak-normalized (0..1048575). Map amplitude magnitude
    // to a relative dB display without placing a logarithm or divider in the
    // pixel path. The visible range is 0 to
    // -60 dB over the 208-pixel spectrum area.
    function automatic integer db_spectrum_height(input logic [19:0] magnitude);
        begin
            if      (magnitude >= 20'd1048575) db_spectrum_height = 208; //   0 dB
            else if (magnitude >= 20'd589000)  db_spectrum_height = 195; //  -5 dB
            else if (magnitude >= 20'd331000)  db_spectrum_height = 182; // -10 dB
            else if (magnitude >= 20'd186000)  db_spectrum_height = 169; // -15 dB
            else if (magnitude >= 20'd104800)  db_spectrum_height = 156; // -20 dB
            else if (magnitude >= 20'd58900)   db_spectrum_height = 143; // -25 dB
            else if (magnitude >= 20'd33100)   db_spectrum_height = 130; // -30 dB
            else if (magnitude >= 20'd18600)   db_spectrum_height = 117; // -35 dB
            else if (magnitude >= 20'd10480)   db_spectrum_height = 104; // -40 dB
            else if (magnitude >= 20'd5890)    db_spectrum_height = 91;  // -45 dB
            else if (magnitude >= 20'd3310)    db_spectrum_height = 78;  // -50 dB
            else if (magnitude >= 20'd1860)    db_spectrum_height = 65;  // -55 dB
            else if (magnitude >= 20'd1048)    db_spectrum_height = 52;  // -60 dB
            else                            db_spectrum_height = 0;
        end
    endfunction

    text_renderer u_text (
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active_video(active_video),
        .frame_count(frame_count), .bfpexp(bfpexp),
        .text_pixel(text_pixel)
    );

    spectrum_log_lut u_spectrum_log_lut (
        .x_segment(spectrum_slot[8:3]),
        .x_subpixel(spectrum_slot[2:0]),
        .bin_index(log_bin_index)
    );

    always_comb begin
        spectrum_slot = (pixel_x >= 64 && pixel_x <= 575) ?
                        (pixel_x - 10'd64) : 10'd0;
        spectrum_read_index = log_bin_index;
        mfcc_slot = 0;
        // Constant range comparisons synthesize smaller/faster than a divider.
        if (pixel_x >= 80)  mfcc_slot = 1;
        if (pixel_x >= 100) mfcc_slot = 2;
        if (pixel_x >= 120) mfcc_slot = 3;
        if (pixel_x >= 140) mfcc_slot = 4;
        if (pixel_x >= 160) mfcc_slot = 5;
        if (pixel_x >= 180) mfcc_slot = 6;
        if (pixel_x >= 200) mfcc_slot = 7;
        if (pixel_x >= 220) mfcc_slot = 8;
        if (pixel_x >= 240) mfcc_slot = 9;
        if (pixel_x >= 260) mfcc_slot = 10;
        if (pixel_x >= 280) mfcc_slot = 11;
        if (pixel_x >= 300) mfcc_slot = 12;
        if (pixel_x < 60 || pixel_x >= 320) mfcc_slot = 0;
        mfcc_read_index = mfcc_slot[3:0];
        spectrum_height = db_spectrum_height(spectrum_value);
        mfcc_mag = mfcc_value[31] ? -mfcc_value : mfcc_value;
        mfcc_height = mfcc_mag >>> 20;
        if (mfcc_height > 45) mfcc_height = 45;

        pixel_color = BLACK;
        if (active_video) begin
            if (((pixel_x >= 64) && (pixel_x <= 575) &&
                 (((pixel_x - 64) % 64) == 0)) ||
                ((pixel_y == 72) || (pixel_y == 112) || (pixel_y == 152) ||
                 (pixel_y == 192) || (pixel_y == 232) || (pixel_y == 272)))
                pixel_color = GRID;

            // Draw a continuous 2-pixel trace. Temporal averaging is done in
            // the capture block; this avoids the old solid bars that hid the
            // relative shape of the spectrum.
            if ((pixel_x >= 64) && (pixel_x <= 575) && (pixel_y >= 72) &&
                (pixel_y <= 280) && (spectrum_height > 0) &&
                ((pixel_y == (280 - spectrum_height)) ||
                 (pixel_y == (279 - spectrum_height))))
                pixel_color = CYAN;

            if ((pixel_x >= 60) && (pixel_x < 320) && (pixel_y >= 350) &&
                (pixel_y <= 460) && (mfcc_height > 0) &&
                ((mfcc_value >= 0 && pixel_y >= (405 - mfcc_height) && pixel_y < 405) ||
                 (mfcc_value < 0 && pixel_y > 405 && pixel_y <= (405 + mfcc_height))))
                pixel_color = YELLOW;

            if ((pixel_x >= 430) && (pixel_x < 450) && (pixel_y >= 350) && (pixel_y < 360))
                pixel_color = fft_run ? GREEN : RED;
            if ((pixel_x >= 430) && (pixel_x < 450) && (pixel_y >= 370) && (pixel_y < 380))
                pixel_color = feature_busy ? YELLOW : GRID;
            if ((pixel_x >= 430) && (pixel_x < 450) && (pixel_y >= 390) && (pixel_y < 400))
                pixel_color = fft_done ? GREEN : GRID;
            if ((pixel_x >= 430) && (pixel_x < 450) && (pixel_y >= 410) && (pixel_y < 420))
                pixel_color = (|fft_input_status || |fft_status) ? RED : GREEN;

            if (text_pixel)
                pixel_color = WHITE;
        end
        red = pixel_color[11:8];
        green = pixel_color[7:4];
        blue = pixel_color[3:0];
    end
endmodule
