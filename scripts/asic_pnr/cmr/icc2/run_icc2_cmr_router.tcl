# ICC2 V-2023.12 CMR Router primitive P&R.
# Async: no CTS.  Sync: clock_opt when CMR_PNR_SYNC=1.

set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID      $::env(CMR_PNR_RUN_ID)
set NETLIST     $::env(CMR_PNR_NETLIST)
set SDC_FILE    $::env(CMR_PNR_SDC)
set TOP "CMRRouter"
if {[info exists ::env(CMR_PNR_TOP)] && $::env(CMR_PNR_TOP) ne ""} {
  set TOP $::env(CMR_PNR_TOP)
}
set SYNC 0
if {[info exists ::env(CMR_PNR_SYNC)] && $::env(CMR_PNR_SYNC) eq "1"} {
  set SYNC 1
}
set EXPECT_DEL ""
if {[info exists ::env(CMR_EXPECTED_DEL050)]} {
  set EXPECT_DEL $::env(CMR_EXPECTED_DEL050)
}
set REPORT_DIR  "$PROJECT_DIR/reports/pnr/$RUN_ID"
set OUTPUT_DIR  "$PROJECT_DIR/outputs/pnr/$RUN_ID"
set WORK_DIR    "$PROJECT_DIR/work/pnr_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_DIR

set PNR_ROOT [file normalize [file join [file dirname [info script]] ..]]
source "$PNR_ROOT/tech_t28hpc_pnr.tcl"
source "$PNR_ROOT/async_preserve.tcl"
source "$PNR_ROOT/async_rtc_data_checks.tcl"

set NDM_DIR "$PROJECT_DIR/work/ndm_tcbn28hpcplusbwp12t30p140"
set nlib "$WORK_DIR/${TOP}.nlib"
set created 0

if {![catch { create_lib $nlib -use_technology_lib $CMR_PNR_MW -ref_libs [list $CMR_PNR_MW] } err]} {
  puts "CMR_PNR_LIB create_lib -use_technology_lib mw=$CMR_PNR_MW"
  set created 1
} else {
  puts "CMR_PNR_WARN use_technology_lib $err"
  if {![catch { create_lib $nlib -technology $CMR_PNR_MW -ref_libs [list $CMR_PNR_MW] } err2]} {
    puts "CMR_PNR_LIB create_lib -technology mw=$CMR_PNR_MW"
    set created 1
  } else {
    puts "CMR_PNR_WARN technology $err2"
  }
}

if {!$created} {
  puts "CMR_PNR_NDM_BUILD start"
  set lm [open "$WORK_DIR/build_ndm.tcl" w]
  puts $lm "create_workspace -flow physical -technology {$CMR_PNR_MW} cmr_t28_ws"
  if {$CMR_PNR_DB ne ""} {
    puts $lm "read_db {$CMR_PNR_DB}"
  } elseif {$CMR_PNR_LIBERTY ne ""} {
    puts $lm "read_db {$CMR_PNR_LIBERTY}"
  }
  puts $lm "catch {check_workspace}"
  puts $lm "commit_workspace -output {$NDM_DIR}"
  puts $lm "exit"
  close $lm
  if {[catch { exec icc2_lm_shell -batch -file "$WORK_DIR/build_ndm.tcl" >@stdout 2>@stderr } err]} {
    puts "CMR_PNR_NDM_FAIL $err"
    puts "CMR_PNR_FAIL ndm_convert"
    exit 2
  }
  if {[catch { create_lib $nlib -ref_libs $NDM_DIR } err3]} {
    puts "CMR_PNR_FAIL create_lib $err3"
    exit 2
  }
}

open_lib $nlib

if {[catch { read_verilog -top $TOP $NETLIST } err]} {
  puts "CMR_PNR_FAIL read_verilog $err"
  exit 2
}
if {[catch { current_block ${TOP} }]} {
  current_design $TOP
}
if {[catch { link_block } err]} {
  puts "CMR_PNR_WARN link_block $err"
}

if {[file exists $SDC_FILE]} {
  catch { read_sdc $SDC_FILE }
}

cmr_async_preserve
cmr_apply_postroute_rtc

if {[catch { initialize_floorplan -core_utilization $CMR_PNR_UTIL -core_offset 2.0 } err]} {
  puts "CMR_PNR_WARN floorplan $err"
  if {[catch { initialize_floorplan -control_type die -side_length {100 100} -core_offset 2.0 } err2]} {
    puts "CMR_PNR_FAIL floorplan $err2"
    exit 2
  }
}
catch { create_placement -floorplan }
catch { place_pins -self }

puts "CMR_PNR_PLACE start"
if {[catch { place_opt } err]} {
  puts "CMR_PNR_FAIL place_opt $err"
  exit 2
}

if {$SYNC} {
  puts "CMR_PNR_CTS start"
  if {[catch { clock_opt } err]} {
    puts "CMR_PNR_FAIL clock_opt $err"
    exit 2
  }
} else {
  puts "CMR_PNR_CTS skipped_async"
}

puts "CMR_PNR_ROUTE start"
if {[catch { route_auto } err]} {
  puts "CMR_PNR_FAIL route_auto $err"
  exit 2
}
catch { route_opt }

set shorts  -1
set opens   -1
if {![catch { check_routes }]} {
  catch { set shorts [sizeof_collection [get_drc_errors -quiet -filter {type =~ *short*}]] }
  catch { set opens  [sizeof_collection [get_drc_errors -quiet -filter {type =~ *open*}]] }
}
puts "CMR_PNR_DRC shorts=$shorts opens=$opens"

cmr_pnr_write_structure "$REPORT_DIR/structure.rpt"
if {![cmr_pnr_gate_counts $EXPECT_DEL]} {
  puts "CMR_PNR_FAIL structure"
  exit 2
}
cmr_report_rtc $REPORT_DIR
catch { report_qor > "$REPORT_DIR/qor.rpt" }
catch { report_power > "$REPORT_DIR/power.rpt" }
catch { report_area > "$REPORT_DIR/area.rpt" }

catch { write_verilog -hier all "$OUTPUT_DIR/${TOP}_routed.v" }
catch { write_gds "$OUTPUT_DIR/${TOP}.gds" }
catch { write_sdf "$OUTPUT_DIR/${TOP}.sdf" }
catch { write_parasitics -output "$OUTPUT_DIR/${TOP}" }
catch { write_def "$OUTPUT_DIR/${TOP}.def" }
catch { save_block }
catch { save_lib }

if {$shorts > 0 || $opens > 0} {
  puts "CMR_PNR_FAIL shorts=$shorts opens=$opens"
  exit 2
}
puts "CMR_PNR_PASS tool=icc2 output=$OUTPUT_DIR"
exit 0
