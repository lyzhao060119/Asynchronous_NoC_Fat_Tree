# PrimeTime post-route STA / SDF / optional PX for a CMR primitive.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID      $::env(CMR_PNR_RUN_ID)
set TOP         [expr {[info exists ::env(CMR_PNR_TOP)] ? $::env(CMR_PNR_TOP) : "CMRRouter"}]
set NETLIST     "$PROJECT_DIR/outputs/pnr/$RUN_ID/${TOP}_routed.v"
set SPEF        "$PROJECT_DIR/outputs/pnr/$RUN_ID/${TOP}.spef"
set SDC_FILE    $::env(CMR_PNR_SDC)
set REPORT_DIR  "$PROJECT_DIR/reports/pnr/$RUN_ID/pt"
file mkdir $REPORT_DIR

source [file join [file dirname [info script]] .. tech_t28hpc_pnr.tcl]
source [file join [file dirname [info script]] .. async_preserve.tcl]
source [file join [file dirname [info script]] .. async_rtc_data_checks.tcl]

if {![file exists $CMR_PNR_DB]} {
  puts "CMR_PNR_FAIL missing_db $CMR_PNR_DB"
  exit 2
}
set search_path [list . [file dirname $CMR_PNR_DB]]
set link_library "* $CMR_PNR_DB"
set target_library $CMR_PNR_DB

read_verilog $NETLIST
link_design $TOP
if {[file exists $SPEF]} {
  read_parasitics $SPEF
}
if {[file exists $SDC_FILE]} {
  catch { read_sdc $SDC_FILE }
}
cmr_async_preserve
cmr_apply_postroute_rtc
cmr_report_rtc $REPORT_DIR
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 50 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 50 > "$REPORT_DIR/timing_min.rpt"
write_sdf "$PROJECT_DIR/outputs/pnr/$RUN_ID/${TOP}_pt.sdf"
puts "CMR_PT_PASS $REPORT_DIR"
exit 0
