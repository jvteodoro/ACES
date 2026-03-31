# Quartus source manifest for the tagged-I2S diagnostic top-level.
# This variant keeps the board-facing port names from `top_level_test` but
# replaces the full ACES path with a deterministic fixed-pattern generator.

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
    rtl/frontend/i2s_fft_tx_adapter.sv
    rtl/top/top_level_i2s_fft_tx_diag.sv
} {
    add_repo_file $repo_root $relpath SYSTEMVERILOG_FILE
}
