module fft_control(
    input  logic       clk,
    input  logic       rst,
    input  logic [1:0] status,
    input  logic       sact_istream_i,
    output logic       run
);
    localparam logic [1:0] S_FBUFFER = 2'h2;

    typedef enum logic [1:0] {
        FFT_IDLE    = 2'd0,
        FFT_ISTREAM = 2'd1,
        FFT_FULL    = 2'd2
    } state_t;

    state_t state, state_n;

    always_comb begin
        state_n = state;
        case (state)
            FFT_IDLE: begin
                if (sact_istream_i)
                    state_n = FFT_ISTREAM;
            end
            FFT_ISTREAM: begin
                if (status == S_FBUFFER)
                    state_n = FFT_FULL;
                else
                    state_n = FFT_ISTREAM;
            end
            FFT_FULL: begin
                state_n = FFT_IDLE;
            end
            default: state_n = FFT_IDLE;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= FFT_IDLE;
        else
            state <= state_n;
    end

    always_comb begin
        run = (state == FFT_FULL);
    end
endmodule
