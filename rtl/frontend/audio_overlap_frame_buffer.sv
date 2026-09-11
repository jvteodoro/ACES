// Circular audio frame buffer for overlapped FFT windows.
//
// Samples arrive at the audio rate and frames are emitted as a contiguous
// one-sample-per-clock burst. The first frame starts after FRAME_LENGTH input
// samples; subsequent frames start every HOP_LENGTH samples. The input and
// output operate in the same clock domain, while the large rate difference
// leaves ample time between frame triggers for the read burst.
module audio_overlap_frame_buffer #(
    parameter int SAMPLE_W = 18,
    parameter int FRAME_LENGTH = 512,
    parameter int HOP_LENGTH = FRAME_LENGTH / 2
) (
    input logic clk,
    input logic rst,
    input logic sample_valid_i,
    input logic signed [SAMPLE_W-1:0] sample_i,
    output logic frame_sample_valid_o,
    output logic signed [SAMPLE_W-1:0] frame_sample_o,
    output logic frame_start_o,
    output logic frame_last_o
);
    localparam int ADDR_W = (FRAME_LENGTH <= 2) ? 1 : $clog2(FRAME_LENGTH);
    localparam int COUNT_W = $clog2(FRAME_LENGTH + 1);
    localparam int HOP_W = (HOP_LENGTH <= 2) ? 1 : $clog2(HOP_LENGTH);

    (* ramstyle = "M9K" *) logic signed [SAMPLE_W-1:0] sample_ram [0:FRAME_LENGTH-1];
    logic [ADDR_W-1:0] write_ptr;
    logic [ADDR_W-1:0] read_ptr;
    logic [COUNT_W-1:0] samples_in_frame;
    logic [HOP_W-1:0] samples_since_frame;
    logic output_active;
    logic output_first;
    logic [COUNT_W-1:0] output_remaining;

    function automatic [ADDR_W-1:0] increment_addr(input [ADDR_W-1:0] addr);
        if (addr == FRAME_LENGTH-1)
            increment_addr = '0;
        else
            increment_addr = addr + 1'b1;
    endfunction

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr <= '0;
            read_ptr <= '0;
            samples_in_frame <= '0;
            samples_since_frame <= '0;
            output_active <= 1'b0;
            output_first <= 1'b0;
            output_remaining <= '0;
            frame_sample_valid_o <= 1'b0;
            frame_sample_o <= '0;
            frame_start_o <= 1'b0;
            frame_last_o <= 1'b0;
        end else begin
            frame_sample_valid_o <= 1'b0;
            frame_start_o <= 1'b0;
            frame_last_o <= 1'b0;

            if (sample_valid_i) begin
                sample_ram[write_ptr] <= sample_i;
                write_ptr <= increment_addr(write_ptr);

                if (samples_in_frame < FRAME_LENGTH) begin
                    samples_in_frame <= samples_in_frame + 1'b1;
                    if (samples_in_frame == FRAME_LENGTH-1) begin
                        // The current write is the newest sample; the next
                        // address is the oldest sample of the first frame.
                        read_ptr <= increment_addr(write_ptr);
                        output_active <= 1'b1;
                        output_first <= 1'b1;
                        output_remaining <= FRAME_LENGTH;
                        samples_in_frame <= FRAME_LENGTH;
                        samples_since_frame <= '0;
                    end
                end else if (samples_since_frame == HOP_LENGTH-1) begin
                    // The circular buffer has advanced by exactly HOP samples.
                    read_ptr <= increment_addr(write_ptr);
                    output_active <= 1'b1;
                    output_first <= 1'b1;
                    output_remaining <= FRAME_LENGTH;
                    samples_since_frame <= '0;
                end else begin
                    samples_since_frame <= samples_since_frame + 1'b1;
                end
            end

            if (output_active) begin
                frame_sample_valid_o <= 1'b1;
                frame_sample_o <= sample_ram[read_ptr];
                frame_start_o <= output_first;
                frame_last_o <= (output_remaining == 1);
                output_first <= 1'b0;
                if (output_remaining == 1) begin
                    read_ptr <= '0;
                    output_active <= 1'b0;
                    output_remaining <= '0;
                end else begin
                    read_ptr <= increment_addr(read_ptr);
                    output_remaining <= output_remaining - 1'b1;
                end
            end
        end
    end
endmodule
