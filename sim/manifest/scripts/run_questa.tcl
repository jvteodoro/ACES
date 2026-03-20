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

set repo_root $::env(ACES_REPO_ROOT)
set local_dir $::env(ACES_LOCAL_DIR)
set test_name $::env(ACES_TEST_NAME)
set flow $::env(ACES_FLOW)
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

set compile_cmd [list vlog -sv -work work -f $filelist_path]
puts "Compiling: $compile_cmd"
if {[catch {eval $compile_cmd} result]} {
    fail "Compile failed: $result"
}

if {$extra_filelist ne ""} {
    set extra_cmd [list vlog -sv -work work -f $extra_filelist]
    puts "Compiling extra filelist: $extra_cmd"
    if {[catch {eval $extra_cmd} result]} {
        fail "Extra filelist compile failed: $result"
    }
}

set top $tops($test_name)
set sim_cmd [list vsim -c work.$top -do "run -all; quit -code 0"]
puts "Launching: $sim_cmd"
if {[catch {eval $sim_cmd} result]} {
    fail "Simulation failed: $result"
}
