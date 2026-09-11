# FPGA feature analyzer

`rtl/analysis/fft_feature_analyzer.sv` moves the post-processing that was
performed by `ACES-RPi-interface/rpi3b_i2s_fft/fpga_fft_adapter.py` into the
FPGA:

1. approximated magnitude of each complex FFT bin;
2. first 256 bins retained from a 512-bin frame;
3. 32 triangular Mel filters for 48 kHz audio and `n_fft=510`;
4. natural logarithm approximation; and
5. 13-point DCT-II (MFCC), matching the former `scipy.fftpack.dct(...,
   type=2, norm="ortho")` shape.

The module accepts the existing `fft_tx_*` stream from `aces`. A frame is
complete when `fft_bin_last_i` is asserted. It then reuses one accumulator,
so the analysis takes about 9,000 `clk` cycles at 50 MHz. The magnitude RAM is
annotated with `ramstyle = "M10K"` for mapping to the DE10-Lite's embedded
memory.

## Interface example

```systemverilog
fft_feature_analyzer #(
    .FFT_LENGTH(FFT_LENGTH),
    .USEFUL_BINS(256)
) u_feature_analyzer (
    .clk(clk), .rst(rst),
    .fft_bin_valid_i(fft_tx_valid_o),
    .fft_bin_index_i(fft_tx_index_o),
    .fft_bin_real_i(fft_tx_real_o),
    .fft_bin_imag_i(fft_tx_imag_o),
    .fft_bin_last_i(fft_tx_last_o),
    .busy_o(feature_busy),
    .result_valid_o(mfcc_valid),
    .result_index_o(mfcc_index),
    .result_data_o(mfcc_q16_16),
    .frame_done_o(feature_frame_done)
);
```

`result_data_o` is signed Q16.16. `result_index_o` runs from 0 through 12;
the values are emitted in order. The coefficients and Mel edges are currently
specialized to the 48 kHz/512-bin configuration used by the Raspberry Pi
application.

The module deliberately does not alter the legacy Cyclone-V top-level yet:
the DE10-Lite SystemCD project uses a different MAX 10 device and pinout. The
next integration step is to instantiate this block in the DE10-Lite top-level
and expose the 13 results through the chosen GPIO/UART/SPI transport.
