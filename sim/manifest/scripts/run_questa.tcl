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

proc write_absolute_filelist {root source_path output_path} {
    set in [open $source_path r]
    set out [open $output_path w]

    try {
        while {[gets $in line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq "" || [string match "#*" $trimmed]} {
                puts $out $line
            } elseif {[file pathtype $trimmed] eq "relative"} {
                puts $out [file normalize [file join $root $trimmed]]
            } else {
                puts $out $trimmed
            }
        }
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

array set filelists {
    i2s_rx_adapter_24              mock_unit_i2s_rx_adapter_24.f
    sample_width_adapter_24_to_18  mock_unit_sample_width_adapter_24_to_18.f
    i2s_stimulus_manager           mock_unit_i2s_stimulus_manager.f
    i2s_stimulus_manager_rom       mock_unit_i2s_stimulus_manager_rom.f
    sample_bridge_and_ingest       mock_integration_sample_bridge_and_ingest.f
    aces                           mock_integration_aces.f
    aces_stimulus_manager          mock_integration_aces_stimulus_manager.f
    top_level_test                 mock_integration_top_level_test.f
}

array set tops {
    i2s_rx_adapter_24              tb_i2s_rx_adapter_24
    sample_width_adapter_24_to_18  tb_sample_width_adapter_24_to_18
    i2s_stimulus_manager           tb_i2s_stimulus_manager
    i2s_stimulus_manager_rom       tb_i2s_stimulus_manager_rom
    sample_bridge_and_ingest       tb_sample_bridge_and_ingest
    aces                           tb_aces
    aces_stimulus_manager          tb_aces_stimulus_manager
    top_level_test                 tb_top_level_test_real
}

if {$flow eq "real"} {
    if {$test_name ne "top_level_test"} {
        fail "Real flow is currently defined only for top_level_test."
    }
    set filelist_name real_ip_top_level_test.f
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
write_absolute_filelist $repo_root $filelist_path $local_filelist_path

set compile_cmd [list vlog -sv -work work -f $local_filelist_path]
puts "Compiling: $compile_cmd"
if {[catch {eval $compile_cmd} result]} {
    fail "Compile failed: $result"
}

if {$extra_filelist ne ""} {
    set local_extra_filelist_path [file join $local_dir compiled_extra_files.f]
    write_absolute_filelist $repo_root $extra_filelist $local_extra_filelist_path

    set extra_cmd [list vlog -sv -work work -f $local_extra_filelist_path]
    puts "Compiling extra filelist: $extra_cmd"
    if {[catch {eval $extra_cmd} result]} {
        fail "Extra filelist compile failed: $result"
    }
}

set top $tops($test_name)
if {$gui_mode} {
    set sim_do "view wave; log -r sim:/*; add wave -r sim:/*; run -all"
    set sim_cmd [list vsim work.$top -do $sim_do]
} else {
    set sim_do "run -all; quit -code 0"
    set sim_cmd [list vsim -c work.$top -do $sim_do]
}
puts "Launching: $sim_cmd"
if {[catch {eval $sim_cmd} result]} {
    fail "Simulation failed: $result"
}
