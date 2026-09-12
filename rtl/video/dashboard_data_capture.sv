module dashboard_data_capture #(
    parameter int FFT_BINS = 512,
    parameter int MFCC_COUNT = 13
) (
    input  logic clk_50,
    input  logic pixel_clk,
    input  logic rst,
    input  logic frame_start_i,

    input  logic fft_tx_valid_i,
    input  logic [9:0] fft_tx_index_i,
    input  logic signed [17:0] fft_tx_real_i,
    input  logic signed [17:0] fft_tx_imag_i,
    input  logic signed [7:0] bfpexp_i,
    input  logic fft_run_i,
    input  logic fft_done_i,
    input  logic [2:0] fft_status_i,
    input  logic [1:0] fft_input_status_i,
    input  logic feature_busy_i,
    input  logic mfcc_valid_i,
    input  logic [3:0] mfcc_index_i,
    input  logic signed [31:0] mfcc_data_i,
    input  logic feature_frame_done_i,

    input  logic [8:0] spectrum_read_index_i,
    input  logic [3:0] mfcc_read_index_i,
    output logic [9:0] spectrum_value_o,
    output logic signed [31:0] mfcc_value_o,
    output logic [7:0] bfpexp_o,
    output logic fft_run_o,
    output logic fft_done_o,
    output logic [2:0] fft_status_o,
    output logic [1:0] fft_input_status_o,
    output logic feature_busy_o,
    output logic [31:0] frame_count_o
);
    // Keep the pre-normalized magnitude so a large BFPEXP cannot flatten the
    // entire display to 10'h3ff. The display reference is a peak hold: it only
    // increases when a new frame exceeds the historical maximum.
    (* ramstyle = "M9K" *) logic [19:0] spectrum_bank [0:1][0:FFT_BINS-1];
    (* ramstyle = "M9K" *) logic signed [31:0] mfcc_bank [0:1][0:MFCC_COUNT-1];
    logic [31:0] frame_count_bank [0:1];
    logic [7:0] bfpexp_bank [0:1];
    logic fft_run_bank [0:1], fft_done_bank [0:1], feature_busy_bank [0:1];
    logic [2:0] fft_status_bank [0:1];
    logic [1:0] fft_input_status_bank [0:1];
    logic write_bank;
    logic ready_bank_50, ready_toggle_50;
    logic ready_toggle_v1, ready_toggle_v2, ready_toggle_seen;
    logic ready_bank_v1, ready_bank_v2, display_bank_vga;
    logic [31:0] frame_counter;
    logic [19:0] peak_work;
    logic [19:0] peak_hold;
    logic [19:0] peak_bank [0:1];
    logic [19:0] spectrum_raw_read;
    logic [19:0] current_bin_magnitude;
    logic [19:0] completed_peak_value;
    logic current_bin_valid;

    function automatic [19:0] raw_magnitude(
        input logic signed [17:0] re,
        input logic signed [17:0] im,
        input logic signed [7:0] exponent
    );
        logic [18:0] are, aim;
        logic [19:0] sum;
        logic [47:0] scaled;
        integer shift_amount;
        logic [5:0] shift_left, shift_right;
        integer magnitude_shift;
        begin
            are = re[17] ? {1'b0, (~re + 1'b1)} : {1'b0, re};
            aim = im[17] ? {1'b0, (~im + 1'b1)} : {1'b0, im};
            sum = are + aim;
            shift_amount = $signed(exponent);
            magnitude_shift = -shift_amount;
            shift_left = (shift_amount > 24) ? 6'd24 : shift_amount[5:0];
            shift_right = (magnitude_shift > 20) ? 6'd20 : magnitude_shift[5:0];
            // Extend before shifting. In SystemVerilog the width of a shift
            // expression is the width of its left operand; shifting the
            // 20-bit sum directly would discard the high bits before the
            // 48-bit assignment.
            if (shift_amount >= 0)
                scaled = {28'd0, sum} << shift_left;
            else
                scaled = {28'd0, sum} >> shift_right;
            if (scaled > 20'hfffff)
                raw_magnitude = 20'hfffff;
            else
                raw_magnitude = scaled[19:0];
        end
    endfunction

    function automatic [19:0] completed_peak(
        input logic [19:0] accumulated_peak,
        input logic        last_valid,
        input logic [19:0] last_magnitude
    );
        begin
            if (last_valid && (last_magnitude > accumulated_peak))
                completed_peak = last_magnitude;
            else
                completed_peak = accumulated_peak;
        end
    endfunction

    always_comb begin
        current_bin_valid = fft_tx_valid_i && (fft_tx_index_i < FFT_BINS);
        current_bin_magnitude = raw_magnitude(fft_tx_real_i, fft_tx_imag_i, bfpexp_i);
        completed_peak_value = completed_peak(
            peak_work, current_bin_valid, current_bin_magnitude);
    end

    // Normalize by a power of two derived from the frame peak. This avoids a
    // divider in the 25 MHz pixel path while keeping the peak near full scale.
    function automatic [9:0] normalized_magnitude(
        input logic [19:0] raw,
        input logic [19:0] peak
    );
        integer highest_bit;
        integer shift_amount;
        logic [31:0] normalized;
        begin
            highest_bit = -1;
            for (int k = 19; k >= 0; k = k - 1)
                if ((highest_bit < 0) && peak[k]) highest_bit = k;
            if (raw == 0) begin
                normalized_magnitude = 10'd0;
            end else if (highest_bit < 0) begin
                // A frame marker can legally arrive without a captured peak
                // (for example while the FFT pipeline is being restarted).
                // Do not turn a nonzero snapshot into a completely blank
                // dashboard in that transient condition. This fallback is
                // intentionally equivalent to the former 10-bit saturating
                // display path; normal frames use peak-based normalization.
                normalized_magnitude = (raw > 20'd1023) ? 10'h3ff : raw[9:0];
            end else begin
                shift_amount = highest_bit - 9;
                if (shift_amount >= 0)
                    normalized = raw >> shift_amount;
                else
                    normalized = raw << (-shift_amount);
                normalized_magnitude = (normalized > 1023) ? 10'h3ff : normalized[9:0];
            end
        end
    endfunction

    always_ff @(posedge clk_50 or posedge rst) begin
        if (rst) begin
            write_bank <= 1'b0;
            ready_bank_50 <= 1'b0;
            ready_toggle_50 <= 1'b0;
            frame_counter <= '0;
            peak_work <= '0;
            peak_hold <= '0;
            for (int b = 0; b < 2; b = b + 1) begin
                frame_count_bank[b] <= '0;
                bfpexp_bank[b] <= '0;
                fft_run_bank[b] <= 1'b0;
                fft_done_bank[b] <= 1'b0;
                feature_busy_bank[b] <= 1'b0;
                fft_status_bank[b] <= '0;
                fft_input_status_bank[b] <= '0;
                peak_bank[b] <= '0;
            end
        end else begin
            if (fft_tx_valid_i && (fft_tx_index_i < FFT_BINS)) begin
                spectrum_bank[write_bank][fft_tx_index_i[8:0]] <=
                    raw_magnitude(fft_tx_real_i, fft_tx_imag_i, bfpexp_i);
                if (raw_magnitude(fft_tx_real_i, fft_tx_imag_i, bfpexp_i) > peak_work)
                    peak_work <= raw_magnitude(fft_tx_real_i, fft_tx_imag_i, bfpexp_i);
            end
            if (mfcc_valid_i && (mfcc_index_i < MFCC_COUNT))
                mfcc_bank[write_bank][mfcc_index_i] <= mfcc_data_i;

            if (feature_frame_done_i) begin
                frame_counter <= frame_counter + 1'b1;
                frame_count_bank[write_bank] <= frame_counter + 1'b1;
                bfpexp_bank[write_bank] <= bfpexp_i;
                fft_run_bank[write_bank] <= fft_run_i;
                fft_done_bank[write_bank] <= fft_done_i;
                feature_busy_bank[write_bank] <= feature_busy_i;
                fft_status_bank[write_bank] <= fft_status_i;
                fft_input_status_bank[write_bank] <= fft_input_status_i;
                // Include a possible last FFT bin on the same cycle as the
                // frame marker instead of losing it to nonblocking ordering.
                // Retain the largest completed-frame peak for stable scaling.
                if (completed_peak_value > peak_hold)
                    peak_hold <= completed_peak_value;
                peak_bank[write_bank] <= (completed_peak_value > peak_hold) ?
                    completed_peak_value : peak_hold;
                ready_bank_50 <= write_bank;
                ready_toggle_50 <= ~ready_toggle_50;
                write_bank <= ~write_bank;
                peak_work <= '0;
            end
        end
    end

    // The selected bank is stable before the toggle is observed. It is only
    // changed at frame_start, so VGA never consumes a bank being written.
    always_ff @(posedge pixel_clk or posedge rst) begin
        if (rst) begin
            ready_toggle_v1 <= 1'b0;
            ready_toggle_v2 <= 1'b0;
            ready_toggle_seen <= 1'b0;
            ready_bank_v1 <= 1'b0;
            ready_bank_v2 <= 1'b0;
            display_bank_vga <= 1'b0;
        end else begin
            ready_toggle_v1 <= ready_toggle_50;
            ready_toggle_v2 <= ready_toggle_v1;
            ready_bank_v1 <= ready_bank_50;
            ready_bank_v2 <= ready_bank_v1;
            if ((ready_toggle_v2 != ready_toggle_seen) && frame_start_i) begin
                ready_toggle_seen <= ready_toggle_v2;
                display_bank_vga <= ready_bank_v2;
                bfpexp_o <= bfpexp_bank[ready_bank_v2];
                fft_run_o <= fft_run_bank[ready_bank_v2];
                fft_done_o <= fft_done_bank[ready_bank_v2];
                fft_status_o <= fft_status_bank[ready_bank_v2];
                fft_input_status_o <= fft_input_status_bank[ready_bank_v2];
                feature_busy_o <= feature_busy_bank[ready_bank_v2];
                frame_count_o <= frame_count_bank[ready_bank_v2];
            end
        end
    end

    // Synchronous read ports allow Quartus to infer the small snapshot banks
    // as dual-clock M9K memories instead of expanding them into registers.
    // The renderer tolerates this one-pixel telemetry latency.
    always_ff @(posedge pixel_clk or posedge rst) begin
        if (rst) begin
            spectrum_value_o <= '0;
            mfcc_value_o <= '0;
            spectrum_raw_read <= '0;
        end else begin
            // Keep the RAM read as a standalone synchronous operation so
            // Quartus can infer the dual-port M9K. Normalize one cycle later.
            spectrum_raw_read <= spectrum_bank[display_bank_vga][spectrum_read_index_i];
            spectrum_value_o <= normalized_magnitude(spectrum_raw_read, peak_bank[display_bank_vga]);
            mfcc_value_o <= mfcc_bank[display_bank_vga][mfcc_read_index_i];
        end
    end
endmodule
