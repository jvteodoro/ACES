proc fail {msg} {
    puts stderr $msg
    quit -code 1
}

proc first_existing {root candidates} {
    foreach candidate $candidates {
        set full [file join $root $candidate]
        if {[file exists $full]} {
            return $full
        }
    }
    return ""
}

proc normalize_for_hdl {path} {
    return [string map [list \\ /] [file normalize $path]]
}

proc stage_runtime_asset {source_path dest_path} {
    file mkdir [file dirname $dest_path]
    file copy -force $source_path $dest_path
    return $dest_path
}

proc stage_ip_wrapper {source_path dest_path replacements} {
    set in [open $source_path r]
    set data [read $in]
    close $in

    foreach {old new} $replacements {
        set data [string map [list $old $new] $data]
    }

    file mkdir [file dirname $dest_path]
    set out [open $dest_path w]
    puts -nonewline $out $data
    close $out
    return $dest_path
}

proc write_absolute_filelist {root local_dir source_path output_path} {
    set in [open $source_path r]
    set out [open $output_path w]

    # Include Intel/Altera simulation libraries when available.
    set emitted_sim_libs {}
    foreach sim_lib [list \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/sgate.v" \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/altera_primitives.v" \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/220model.v" \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v" \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/altera_lnsim.sv" \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/cycloneive_atoms.v" \
        "C:/altera_lite/25.1std/quartus/eda/sim_lib/cyclonev_atoms.v" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/sgate.v" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/altera_primitives.v" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/220model.v" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/altera_lnsim.sv" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/cycloneive_atoms.v" \
        "/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib/cyclonev_atoms.v" \
        "/opt/intelFPGA/20.1/modelsim_ase/altera/verilog/src/sgate.v" \
        "/opt/intelFPGA/20.1/modelsim_ase/altera/verilog/src/altera_primitives.v" \
        "/opt/intelFPGA/20.1/modelsim_ase/altera/verilog/src/220model.v" \
        "/opt/intelFPGA/20.1/modelsim_ase/altera/verilog/src/altera_mf.v" \
        "/opt/intelFPGA/20.1/modelsim_ase/altera/verilog/src/altera_lnsim.sv" \
    ] {
        if {[file exists $sim_lib]} {
            set normalized_lib [normalize_for_hdl $sim_lib]
            if {[lsearch -exact $emitted_sim_libs $normalized_lib] < 0} {
                puts $out $normalized_lib
                lappend emitted_sim_libs $normalized_lib
            }
        }
    }

    set staged_signals_rom [normalize_for_hdl [stage_runtime_asset         [file join $root tools signals_rom.mif]         [file join $local_dir signals_rom.mif]]]
    set staged_signals_hex [normalize_for_hdl [stage_runtime_asset         [file join $root tools signals_rom_mirror.hex]         [file join $local_dir signals_rom_mirror.hex]]]

    set staged_signals_rom_ip [normalize_for_hdl [stage_ip_wrapper         [file join $root rtl ip rom signals_rom_ip.v]         [file join $local_dir staged_ip signals_rom_ip.v]         [list "../../../tools/signals_rom.mif" $staged_signals_rom]]]

    try {
        while {[gets $in line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq "" || [string match "#*" $trimmed]} {
                puts $out $line
            } elseif {$trimmed eq "rtl/ip/rom/signals_rom_ip.v"} {
                puts $out $staged_signals_rom_ip
            } elseif {[string match {+*} $trimmed] || [string match {-*} $trimmed]} {
                puts $out $trimmed
            } elseif {[file pathtype $trimmed] eq "relative"} {
                puts $out [file normalize [file join $root $trimmed]]
            } else {
                puts $out $trimmed
            }
        }

        puts $out "# staged runtime assets"
        puts $out "# signals_rom_mirror.hex -> $staged_signals_hex"
    } finally {
        close $in
        close $out
    }
}

set repo_root $::env(ACES_REPO_ROOT)
set local_dir $::env(ACES_LOCAL_DIR)
set test_name $::env(ACES_TEST_NAME)
set flow $::env(ACES_FLOW)
set gui_mode [expr {[info exists ::env(ACES_GUI)] && $::env(ACES_GUI) eq "1"}]
set extra_filelist [expr {[info exists ::env(EXTRA_FILELIST)] ? $::env(EXTRA_FILELIST) : ""}]
set sim_plusargs [expr {[info exists ::env(ACES_VSIM_PLUSARGS)] ? [split $::env(ACES_VSIM_PLUSARGS)] : [list]}]

array set filelists {
    hexa7seg                       mock_unit_hexa7seg.f
    i2s_rx_adapter_24              mock_unit_i2s_rx_adapter_24.f
    sample_width_adapter_24_to_18  mock_unit_sample_width_adapter_24_to_18.f
    i2s_master_clock_gen           mock_unit_i2s_master_clock_gen.f
    i2s_stimulus_manager_rom       mock_unit_i2s_stimulus_manager_rom.f
    aces_audio_to_fft_pipeline     mock_integration_aces_audio_to_fft_pipeline.f
}

array set tops {
    hexa7seg                       tb_hexa7seg
    i2s_rx_adapter_24              tb_i2s_rx_adapter_24
    sample_width_adapter_24_to_18  tb_sample_width_adapter_24_to_18
    i2s_master_clock_gen           tb_i2s_master_clock_gen
    i2s_stimulus_manager_rom       tb_i2s_stimulus_manager_rom
    aces_audio_to_fft_pipeline     tb_aces_audio_to_fft_pipeline
}

array set wave_dos {
    i2s_rx_adapter_24              i2s_rx_adapter_24.do
}

if {$flow eq "real"} {
    fail "Real flow was removed together with the legacy FPGA FFT path. Use the maintained mock-flow tests."
} elseif {[info exists filelists($test_name)]} {
    set filelist_name $filelists($test_name)
} else {
    fail "Unknown test '$test_name'."
}

set filelist_path [first_existing $repo_root [list [file join sim manifest filelists $filelist_name] [file join filelists $filelist_name]]]
if {$filelist_path eq ""} {
    fail "Missing filelist: $filelist_name"
}

file mkdir $local_dir
cd $local_dir
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work

set local_filelist_path [file join $local_dir compiled_files.f]
write_absolute_filelist $repo_root $local_dir $filelist_path $local_filelist_path

set compile_cmd [list vlog -work work -f $local_filelist_path]
puts "Compiling: $compile_cmd"
if {[catch {eval $compile_cmd} result]} {
    fail "Compile failed: $result"
}

if {$extra_filelist ne ""} {
    set local_extra_filelist_path [file join $local_dir compiled_extra_files.f]
    write_absolute_filelist $repo_root $local_dir $extra_filelist $local_extra_filelist_path

    set extra_cmd [list vlog -work work -f $local_extra_filelist_path]
    puts "Compiling extra filelist: $extra_cmd"
    if {[catch {eval $extra_cmd} result]} {
        fail "Extra filelist compile failed: $result"
    }
}

set top $tops($test_name)
if {$gui_mode} {
    set wave_candidates [list]

    if {[info exists wave_dos($test_name)]} {
        lappend wave_candidates [file join sim manifest waves $wave_dos($test_name)]
    }

    foreach candidate [list \
        [file join sim manifest waves "${test_name}.do"] \
        [file join sim manifest waves $test_name] \
        [file join sim manifest waves "${top}.do"] \
        [file join sim manifest waves $top] \
        [file join sim manifest waves legacy_questa $top] \
    ] {
        lappend wave_candidates $candidate
    }

    set wave_do_path [first_existing $repo_root $wave_candidates]

    if {$wave_do_path ne "" && [file exists $wave_do_path]} {
        puts "Loading wave setup: $wave_do_path"
        set sim_do "do {$wave_do_path}; run -all"
    } else {
        set sim_do "view wave; log -r sim:/*; add wave -r sim:/*; run -all"
    }

    set sim_cmd [concat [list vsim -voptargs=+acc work.$top] $sim_plusargs [list -do $sim_do]]
} else {
    set sim_do "run -all; quit -code 0"
    set sim_cmd [concat [list vsim -c work.$top] $sim_plusargs [list -do $sim_do]]
}
puts "Launching: $sim_cmd"
if {[catch {eval $sim_cmd} result]} {
    fail "Simulation failed: $result"
}
