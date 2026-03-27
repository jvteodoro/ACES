# Quartus source manifest for the active board-oriented top-level.
# Load this project from quartus/top_level_test.qpf and Quartus will import
# all RTL/IP files required to elaborate the `top_level_test` entity.

set project_dir [file dirname [info script]]
set repo_root [file normalize [file join $project_dir ..]]

proc add_repo_file {repo_root relpath kind} {
    set abs_path [file normalize [file join $repo_root $relpath]]
    if {![file exists $abs_path]} {
        post_message -type error "Missing required source: $relpath"
        return -code error
    }
    set_global_assignment -name $kind $abs_path
}

add_repo_file $repo_root rtl/common/hexa7seg.v VERILOG_FILE

foreach relpath {
    rtl/common/sample_width_adapter_24_to_18.sv
    rtl/common/fft_control.sv
    rtl/common/fft_dma_reader.sv
    rtl/frontend/i2s_master_clock_gen.sv
    rtl/frontend/i2s_rx_adapter_24.sv
    rtl/frontend/i2s_fft_tx_adapter.sv
    rtl/core/aces_audio_to_fft_pipeline.sv
    rtl/core/aces.sv
    rtl/stimulus/i2s_stimulus_manager_rom.sv
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
    submodules/R2FFT/quartus/r2fft_impl.sv
    submodules/R2FFT/quartus/r2fft_tribuf_impl.sv
    rtl/top/top_level_test.sv
} {
    add_repo_file $repo_root $relpath SYSTEMVERILOG_FILE
}

# Quartus-generated IP wrappers and metadata.
# Keep the FFT memories promoted under rtl/ip/fft so the root project does not
# depend on duplicate twrom/dpram definitions inside the restored snapshot.
foreach relpath {
    rtl/ip/rom/signals_rom_ip.qip
    rtl/ip/fft/dpram.qip
    rtl/ip/fft/twrom.qip
} {
    add_repo_file $repo_root $relpath QIP_FILE
}


proc add_repo_mif {repo_root relpath} {
    set abs_path [file normalize [file join $repo_root $relpath]]
    if {![file exists $abs_path]} {
        post_message -type error "Missing required memory file: $relpath"
        return -code error
    }
    set_global_assignment -name MIF_FILE $abs_path
}

foreach relpath {
    tools/signals_rom.mif
    rtl/ip/fft/twrom.mif
} {
    add_repo_mif $repo_root $relpath
}
