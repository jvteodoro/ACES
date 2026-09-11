// Fixed-point replacement for the post-processing previously done on the
// Raspberry Pi (magnitude -> Mel energies -> log -> 13 MFCC coefficients).
//
// Input: one complete frame of FFT bins, indexed 0..511.  The first 256 bins
// are retained, matching fpga_fft_adapter.py.  Magnitudes and Mel energies
// are unsigned integers; MFCC outputs are signed Q16.16 values.
//
// The implementation intentionally reuses one accumulator.  At 50 MHz a
// frame takes roughly 9k clocks to process, while the input frame itself is
// much slower at a 48 kHz sample rate.  The magnitude store is marked M10K so
// Quartus can map it to the DE10-Lite's embedded RAM instead of registers.

module fft_feature_analyzer #(
    parameter int FFT_LENGTH = 512,
    parameter int USEFUL_BINS = 256,
    parameter int MEL_BANDS = 32,
    parameter int MFCC_COUNT = 13,
    parameter int COEFF_Q = 12
) (
    input  logic clk,
    input  logic rst,

    input  logic fft_bin_valid_i,
    input  logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_i,
    input  logic signed [17:0] fft_bin_real_i,
    input  logic signed [17:0] fft_bin_imag_i,
    input  logic fft_bin_last_i,

    output logic busy_o,
    output logic result_valid_o,
    output logic [$clog2(MFCC_COUNT)-1:0] result_index_o,
    output logic signed [31:0] result_data_o,
    output logic frame_done_o
);

    localparam int BIN_W = $clog2(USEFUL_BINS);
    localparam int BAND_W = $clog2(MEL_BANDS);
    localparam int MEL_W = $clog2(MEL_BANDS);
    localparam int ACC_W = 50;

    // Mel filter breakpoints for sr=48 kHz, n_fft=510, n_mels=32.  These are
    // the same geometry used by librosa.filters.mel in the old receiver.
    (* ramstyle = "M10K" *) logic [31:0] magnitude_ram [0:USEFUL_BINS-1];
    logic [31:0] mel_energy [0:MEL_BANDS-1];
    logic signed [31:0] log_energy [0:MEL_BANDS-1];

    typedef enum logic [3:0] {IDLE, MEL_PREP, MEL_ACC, LOG_ACC, DCT_ACC, EMIT} state_t;
    state_t state;
    logic [BAND_W-1:0] band;
    logic [BIN_W-1:0] bin;
    // This counter also indexes all 32 log-Mel values, so it needs 5 bits;
    // only values 0..12 are exposed on the MFCC result interface.
    logic [MEL_W-1:0] mfcc;
    logic [MEL_W-1:0] dct_mel;
    logic signed [ACC_W-1:0] accumulator;

    function automatic [18:0] abs18(input logic signed [17:0] value);
        begin
            abs18 = value[17] ? {1'b0, (~value + 1'b1)} : {1'b0, value};
        end
    endfunction

    function automatic [31:0] magnitude(input logic signed [17:0] re, input logic signed [17:0] im);
        logic [18:0] are, aim, hi, lo;
        begin
            are = abs18(re); aim = abs18(im);
            hi = (are >= aim) ? are : aim;
            lo = (are >= aim) ? aim : are;
            // max + min/2 is a low-cost approximation to sqrt(re^2+im^2).
            magnitude = {13'd0, hi} + {13'd0, (lo >> 1)};
        end
    endfunction

    function automatic integer mel_edge_base(input integer idx);
        begin
            case (idx)
                0:mel_edge_base=0; 1:mel_edge_base=1; 2:mel_edge_base=2; 3:mel_edge_base=3;
                4:mel_edge_base=4; 5:mel_edge_base=5; 6:mel_edge_base=7; 7:mel_edge_base=8;
                8:mel_edge_base=10; 9:mel_edge_base=12; 10:mel_edge_base=14; 11:mel_edge_base=17;
                12:mel_edge_base=20; 13:mel_edge_base=23; 14:mel_edge_base=26; 15:mel_edge_base=30;
                16:mel_edge_base=34; 17:mel_edge_base=39; 18:mel_edge_base=45; 19:mel_edge_base=50;
                20:mel_edge_base=57; 21:mel_edge_base=64; 22:mel_edge_base=73; 23:mel_edge_base=82;
                24:mel_edge_base=92; 25:mel_edge_base=103; 26:mel_edge_base=116; 27:mel_edge_base=130;
                28:mel_edge_base=146; 29:mel_edge_base=163; 30:mel_edge_base=182; 31:mel_edge_base=204;
                32:mel_edge_base=228; default:mel_edge_base=255;
            endcase
        end
    endfunction

    // The reference breakpoints are expressed for 512-point FFT / 256
    // positive bins. Scale them with the configured positive-bin count so the
    // same 0..Nyquist Mel geometry is retained for 1024-point FFTs.
    function automatic integer mel_edge(input integer idx);
        mel_edge = (mel_edge_base(idx) * USEFUL_BINS) / 256;
    endfunction

    // A 33-entry quarter-wave cosine ROM avoids a large coefficient matrix.
    // phase is k*(2*n+1), measured in units of pi/64.
    function automatic signed [15:0] dct_coeff(input integer k, input integer n);
        integer phase, offset, lut_idx, sign;
        integer c;
        begin
            phase = (k * (2*n + 1)) & 127;
            if (phase <= 32) begin lut_idx = phase; sign = 1; end
            else if (phase <= 64) begin lut_idx = 64-phase; sign = -1; end
            else if (phase <= 96) begin lut_idx = phase-64; sign = -1; end
            else begin lut_idx = 128-phase; sign = 1; end
            case (lut_idx)
                0:c=4096; 1:c=4091; 2:c=4076; 3:c=4052; 4:c=4017; 5:c=3973;
                6:c=3920; 7:c=3857; 8:c=3784; 9:c=3703; 10:c=3612; 11:c=3513;
                12:c=3406; 13:c=3290; 14:c=3166; 15:c=3035; 16:c=2896; 17:c=2751;
                18:c=2598; 19:c=2440; 20:c=2276; 21:c=2106; 22:c=1931; 23:c=1751;
                24:c=1567; 25:c=1380; 26:c=1189; 27:c=995; 28:c=799; 29:c=601;
                30:c=401; 31:c=201; default:c=0;
            endcase
            if (sign < 0) dct_coeff = -c[15:0];
            else dct_coeff = c[15:0];
        end
    endfunction

    function automatic [12:0] mel_weight(input integer b, input integer k);
        integer left_edge, center_edge, right_edge;
        begin
            left_edge = mel_edge(b); center_edge = mel_edge(b+1); right_edge = mel_edge(b+2);
            if ((k <= left_edge) || (k >= right_edge) || (right_edge <= left_edge))
                mel_weight = 0;
            else if (k < center_edge && center_edge > left_edge)
                mel_weight = ((k-left_edge) << COEFF_Q) / (center_edge-left_edge);
            else if (right_edge > center_edge)
                mel_weight = ((right_edge-k) << COEFF_Q) / (right_edge-center_edge);
            else
                mel_weight = 0;
        end
    endfunction

    function automatic signed [31:0] natural_log_q16(input logic [31:0] value);
        integer i, msb;
        logic [31:0] normalized;
        integer frac_log2;
        integer log2_q16;
        begin
            if (value == 0) begin
                natural_log_q16 = -32'sd1048576; // ln(2^-16), safe floor
            end else begin
                msb = 0;
                for (i = 0; i < 32; i = i + 1)
                    if (value[i]) msb = i;
                normalized = value << (31-msb);
                case (normalized[30:27])
                    4'd0: frac_log2=0; 4'd1: frac_log2=5732; 4'd2: frac_log2=11136; 4'd3: frac_log2=16248;
                    4'd4: frac_log2=21098; 4'd5: frac_log2=25711; 4'd6: frac_log2=30109; 4'd7: frac_log2=34312;
                    4'd8: frac_log2=38336; 4'd9: frac_log2=42196; 4'd10: frac_log2=45904; 4'd11: frac_log2=49472;
                    4'd12: frac_log2=52911; 4'd13: frac_log2=56229; 4'd14: frac_log2=59434; default: frac_log2=62534;
                endcase
                log2_q16 = (msb << 16) + frac_log2;
                natural_log_q16 = (log2_q16 * 45426) >>> 16; // ln(2) in Q0.16
            end
        end
    endfunction

    always_ff @(posedge clk or posedge rst) begin : analyzer_fsm
        logic [31:0] product;
        logic signed [ACC_W-1:0] next_acc;
        if (rst) begin
            state <= IDLE; band <= '0; bin <= '0; mfcc <= '0; dct_mel <= '0;
            accumulator <= '0; busy_o <= 1'b0; result_valid_o <= 1'b0;
            result_index_o <= '0; result_data_o <= '0; frame_done_o <= 1'b0;
        end else begin
            result_valid_o <= 1'b0;
            frame_done_o <= 1'b0;
            case (state)
                IDLE: begin
                    busy_o <= 1'b0;
                    if (fft_bin_valid_i) begin
                        if (fft_bin_index_i < USEFUL_BINS)
                            magnitude_ram[fft_bin_index_i[BIN_W-1:0]] <= magnitude(fft_bin_real_i, fft_bin_imag_i);
                        if (fft_bin_last_i) begin
                            busy_o <= 1'b1; band <= '0; state <= MEL_PREP;
                        end
                    end
                end
                MEL_PREP: begin
                    accumulator <= '0; bin <= mel_edge(band); state <= MEL_ACC;
                    if (mel_edge(band+1) <= mel_edge(band+0)) begin
                        mel_energy[band] <= 0;
                        if (band == MEL_BANDS-1) begin mfcc <= 0; state <= LOG_ACC; end
                        else band <= band + 1'b1;
                    end
                end
                MEL_ACC: begin
                    product = magnitude_ram[bin] * mel_weight(band, bin);
                    next_acc = accumulator + product;
                    if (bin >= mel_edge(band+1)-1 || bin == USEFUL_BINS-1) begin
                        mel_energy[band] <= next_acc >>> COEFF_Q;
                        if (band == MEL_BANDS-1) begin mfcc <= 0; state <= LOG_ACC; end
                        else begin band <= band + 1'b1; state <= MEL_PREP; end
                    end else begin bin <= bin + 1'b1; accumulator <= next_acc; end
                end
                LOG_ACC: begin
                    log_energy[mfcc] <= natural_log_q16(mel_energy[mfcc]);
                    if (mfcc == MEL_BANDS-1) begin mfcc <= 0; dct_mel <= 0; accumulator <= 0; state <= DCT_ACC; end
                    else mfcc <= mfcc + 1'b1;
                end
                DCT_ACC: begin
                    next_acc = accumulator + (log_energy[dct_mel] * dct_coeff(mfcc, dct_mel));
                    if (dct_mel == MEL_BANDS-1) begin
                        result_data_o <= next_acc >>> COEFF_Q;
                        result_index_o <= mfcc; result_valid_o <= 1'b1;
                        if (mfcc == MFCC_COUNT-1) begin frame_done_o <= 1'b1; state <= EMIT; end
                        else begin mfcc <= mfcc + 1'b1; dct_mel <= 0; accumulator <= 0; end
                    end else begin dct_mel <= dct_mel + 1'b1; accumulator <= next_acc; end
                end
                EMIT: begin busy_o <= 1'b0; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
