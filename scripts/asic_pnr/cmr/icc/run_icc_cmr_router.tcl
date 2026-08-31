# ICC classic (icc_shell) Verilog+Milkyway import fallback.

set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID      $::env(CMR_PNR_RUN_ID)
set NETLIST     $::env(CMR_PNR_NETLIST)
set TOP         [expr {[info exists ::env(CMR_PNR_TOP)] ? $::env(CMR_PNR_TOP) : "CMRRouter"}]
set REPORT_DIR  "$PROJECT_DIR/reports/pnr/$RUN_ID"
set OUTPUT_DIR  "$PROJECT_DIR/outputs/pnr/$RUN_ID"
set MW_DIR      "$PROJECT_DIR/work/icc_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $MW_DIR

source [file join [file dirname [info script]] .. tech_t28hpc_pnr.tcl]
source [file join [file dirname [info script]] .. async_preserve.tcl]

if {$CMR_PNR_MW eq ""} {
  puts "CMR_PNR_FAIL missing_mw"
  exit 2
}

set mw_lib "$MW_DIR/${TOP}.mw"
if {[catch {
  create_mw_lib $mw_lib -mw_reference_library $CMR_PNR_MW -open
} err]} {
  puts "CMR_PNR_FAIL create_mw_lib $err"
  exit 2
}
if {[catch { import_designs $NETLIST -format verilog -top $TOP } err]} {
  puts "CMR_PNR_FAIL import_designs $err"
  exit 2
}
cmr_async_preserve
catch { create_floorplan -control_type aspect_ratio -core_aspect_ratio 1 -core_utilization 0.6 -left_io2core 2 -right_io2core 2 -top_io2core 2 -bottom_io2core 2 }
puts "CMR_PNR_PLACE start"
if {[catch { place_opt } err]} {
  puts "CMR_PNR_FAIL place_opt $err"
  exit 2
}
puts "CMR_PNR_ROUTE start"
if {[catch { route_opt } err]} {
  puts "CMR_PNR_FAIL route_opt $err"
  exit 2
}
cmr_pnr_write_structure "$REPORT_DIR/structure.rpt"
save_mw_cel
write_verilog "$OUTPUT_DIR/${TOP}_routed.v"
puts "CMR_PNR_PASS tool=icc output=$OUTPUT_DIR"
exit 0
