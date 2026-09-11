set project_dir [file dirname [info script]]
set repo_root [file normalize [file join $project_dir ..]]

proc add_source {repo_root relpath kind} {
    set path [file normalize [file join $repo_root $relpath]]
    if {![file exists $path]} {
        post_message -type error "Missing source: $relpath"
        return -code error
    }
    set_global_assignment -name $kind $path
}

foreach relpath {
    rtl/top/de10lite_audio_fft_top.sv
    rtl/analysis/fft_feature_analyzer.sv
    rtl/analysis/feature_temporal_stabilizer.sv
    rtl/common/hexa7seg.v
    rtl/common/sample_width_adapter_24_to_18.sv
    rtl/common/fft_control.sv
    rtl/common/fft_dma_reader.sv
    rtl/common/fft_tx_bridge_fifo.sv
    rtl/frontend/i2s_master_clock_gen.sv
    rtl/frontend/fft_window_multiplier.sv
    rtl/frontend/audio_overlap_frame_buffer.sv
    rtl/frontend/i2s_rx_adapter_24.sv
    rtl/frontend/i2s_fft_tx_adapter.sv
    rtl/core/aces_audio_to_fft_pipeline.sv
    rtl/core/aces.sv
    submodules/R2FFT/hdl/R2FFT.sv
    submodules/R2FFT/hdl/R2FFT_tribuf.sv
    submodules/R2FFT/hdl/bfp_Shifter.sv
    submodules/R2FFT/hdl/bfp_bitWidthAcc.sv
    submodules/R2FFT/hdl/bfp_bitWidthDetector.sv
    submodules/R2FFT/hdl/bfp_maxBitWidth.sv
    submodules/R2FFT/hdl/bitReverseCounter.sv
    submodules/R2FFT/hdl/butterflyCore.sv
    submodules/R2FFT/hdl/butterflyUnit.sv
    submodules/R2FFT/hdl/fftAddressGenerator.sv
    submodules/R2FFT/hdl/radix2Butterfly.sv
    submodules/R2FFT/hdl/ramPipelineBridge.sv
    submodules/R2FFT/hdl/readBusMux.sv
    submodules/R2FFT/hdl/readBusMux_tribuf.sv
    submodules/R2FFT/hdl/twiddleFactorRomBridge.sv
    submodules/R2FFT/hdl/writeBusMux.sv
    submodules/R2FFT/hdl/writeBusMux_tribuf.sv
    submodules/R2FFT/quartus/r2fft_tribuf_impl.sv
    submodules/R2FFT/quartus/twrom.v
    submodules/R2FFT/quartus/dpram.v
} {
    add_source $repo_root $relpath SYSTEMVERILOG_FILE
}

set_global_assignment -name SEARCH_PATH [file normalize [file join $repo_root submodules R2FFT quartus]]
set_global_assignment -name MIF_FILE [file normalize [file join $repo_root submodules R2FFT quartus twrom.mif]]
set_global_assignment -name SEARCH_PATH [file normalize [file join $repo_root rtl frontend]]
set_global_assignment -name HEX_FILE [file normalize [file join $repo_root rtl frontend hann_window_q15.hex]]
set_global_assignment -name HEX_FILE [file normalize [file join $repo_root rtl frontend hann_window_q15_1024.hex]]
set_global_assignment -name HEX_FILE [file normalize [file join $repo_root rtl analysis mel_coeffs_1024_q16.hex]]
set_global_assignment -name HEX_FILE [file normalize [file join $repo_root rtl analysis log_mantissa_q16.hex]]
