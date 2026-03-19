module fft_dma_reader #(
    parameter int FFT_LENGTH   = 512,
    parameter int FFT_DW       = 18,
    parameter int READ_LATENCY = 1
)(
    input  logic clk,
    input  logic rst,
    input  logic done_i,

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
        ISSUE,
        CAPTURE
    } state_t;

    state_t state;

    logic [$clog2(FFT_LENGTH)-1:0] addr;
    logic [$clog2(READ_LATENCY+1)-1:0] lat_cnt;

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
        end else begin
            fft_bin_valid_o <= 1'b0;
            fft_bin_last_o  <= 1'b0;

            case (state)
                IDLE: begin
                    dmaact_o <= 1'b0;
                    if (done_i) begin
                        addr     <= '0;
                        dmaa_o   <= '0;
                        dmaact_o <= 1'b1;
                        lat_cnt  <= '0;
                        state    <= ISSUE;
                    end
                end

                ISSUE: begin
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
                        lat_cnt <= '0;
                        state   <= ISSUE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule