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
    rtl/frontend/i2s_master_clock_gen.sv
    rtl/core/aces.sv
    rtl/stimulus/i2s_stimulus_manager_rom.sv
    rtl/top/top_level_test.sv
} {
    add_repo_file $repo_root $relpath SYSTEMVERILOG_FILE
}

foreach relpath {
    rtl/ip/rom/signals_rom_ip.qip
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
    rtl/ip/rom/signals_rom.mif
} {
    add_repo_mif $repo_root $relpath
}
