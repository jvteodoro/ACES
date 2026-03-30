module fft_dma_reader #(
    parameter int FFT_LENGTH   = 512,
    parameter int FFT_DW       = 18,
    parameter int READ_LATENCY = 1
)(
    input  logic clk,
    input  logic rst,
    input  logic done_i,
    input  logic run_i,

    output logic dmaact_o,
    output logic [$clog2(FFT_LENGTH)-1:0] dmaa_o,

    input  logic signed [FFT_DW-1:0] dmadr_real_i,
    input  logic signed [FFT_DW-1:0] dmadr_imag_i,

    output logic fft_bin_valid_o,
    output logic [$clog2(FFT_LENGTH)-1:0] fft_bin_index_o,
    output logic signed [FFT_DW-1:0] fft_bin_real_o,
    output logic signed [FFT_DW-1:0] fft_bin_imag_o,
    output logic fft_bin_last_o
);

    typedef enum logic [1:0] {
        IDLE,
        ISSUE_PULSE,
        WAIT_LATENCY,
        CAPTURE
    } state_t;

    state_t state;

    logic [$clog2(FFT_LENGTH)-1:0] addr;
    logic [$clog2(READ_LATENCY+1)-1:0] lat_cnt;
    logic done_d;
    logic run_d;
    logic pending_output_r;

    wire done_pulse;
    wire run_pulse;

    assign done_pulse = done_i & ~done_d;
    assign run_pulse  = run_i & ~run_d;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            addr            <= '0;
            dmaa_o          <= '0;
            dmaact_o        <= 1'b0;
            fft_bin_valid_o <= 1'b0;
            fft_bin_index_o <= '0;
            fft_bin_real_o  <= '0;
            fft_bin_imag_o  <= '0;
            fft_bin_last_o  <= 1'b0;
            lat_cnt         <= '0;
            done_d          <= 1'b0;
            run_d           <= 1'b0;
            pending_output_r<= 1'b0;
        end else begin
            fft_bin_valid_o <= 1'b0;
            fft_bin_last_o  <= 1'b0;
            done_d          <= done_i;
            run_d           <= run_i;

            if (done_pulse)
                pending_output_r <= 1'b1;

            case (state)
                IDLE: begin
                    dmaact_o <= 1'b0;
                    if (run_pulse && pending_output_r) begin
                        pending_output_r <= 1'b0;
                        addr     <= '0;
                        dmaa_o   <= '0;
                        dmaact_o <= 1'b1;
                        state    <= ISSUE_PULSE;
                    end
                end

                ISSUE_PULSE: begin
                    dmaact_o <= 1'b0;
                    lat_cnt  <= '0;
                    if (READ_LATENCY <= 0)
                        state <= CAPTURE;
                    else
                        state <= WAIT_LATENCY;
                end

                WAIT_LATENCY: begin
                    if (lat_cnt == READ_LATENCY-1) begin
                        state <= CAPTURE;
                    end else begin
                        lat_cnt <= lat_cnt + 1'b1;
                    end
                end

                CAPTURE: begin
                    fft_bin_valid_o <= 1'b1;
                    fft_bin_index_o <= addr;
                    fft_bin_real_o  <= dmadr_real_i;
                    fft_bin_imag_o  <= dmadr_imag_i;
                    fft_bin_last_o  <= (addr == FFT_LENGTH-1);

                    if (addr == FFT_LENGTH-1) begin
                        dmaact_o <= 1'b0;
                        state    <= IDLE;
                    end else begin
                        addr    <= addr + 1'b1;
                        dmaa_o  <= addr + 1'b1;
                        dmaact_o <= 1'b1;
                        state   <= ISSUE_PULSE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
