# Isolated SyncCmrRouter DC.  1.0 ns SS ZeroWireload.  No Mutex / DEL / LanePhaseAdapter.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_SYNC_ROUTER_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set DUT_V "$RTL_DIR/runs/$RUN_ID/SyncCmrRouter.v"
if {[info exists ::env(CMR_DUT_V)] && $::env(CMR_DUT_V) ne ""} {
  set DUT_V $::env(CMR_DUT_V)
}
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_sync_router_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_ports 5
set expected_selectors 0
if {[info exists ::env(CMR_EXPECTED_PORTS)] && $::env(CMR_EXPECTED_PORTS) ne ""} {
  set expected_ports $::env(CMR_EXPECTED_PORTS)
}
if {[info exists ::env(CMR_EXPECTED_SELECTORS)] && $::env(CMR_EXPECTED_SELECTORS) ne ""} {
  set expected_selectors $::env(CMR_EXPECTED_SELECTORS)
}

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list $DUT_V]
elaborate SyncCmrRouter -work WORK
current_design SyncCmrRouter
uniquify
link
check_design > "$REPORT_DIR/check_design_pre.rpt"

source "$RTL_DIR/sync_cmr_noc64.sdc"
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
set_fix_hold [all_clocks]
compile_ultra -incremental -no_autoungroup
check_design > "$REPORT_DIR/check_design_post.rpt"

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]

set ipm_count [sizeof_collection [get_cells -quiet InputPortModules_*]]
set opm_count [sizeof_collection [get_cells -quiet OutputPortModules_*]]
set mutex_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex*}]]
set delay_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement*}]]
set adapter_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]]
set selector_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ SyncLaneSelector*}]]

set wns "NA"
set whs "NA"
if {![catch {get_timing_paths -delay_type max -nworst 1} max_paths]} {
  if {[sizeof_collection $max_paths] > 0} {
    set wns [get_attribute [index_collection $max_paths 0] slack]
  }
}
if {![catch {get_timing_paths -delay_type min -nworst 1} min_paths]} {
  if {[sizeof_collection $min_paths] > 0} {
    set whs [get_attribute [index_collection $min_paths 0] slack]
  }
}

set fd [open "$REPORT_DIR/cmr_structure.rpt" w]
puts $fd "IPM_COUNT=$ipm_count"
puts $fd "OPM_COUNT=$opm_count"
puts $fd "ADAPTER_COUNT=$adapter_count"
puts $fd "SELECTOR_COUNT=$selector_count"
puts $fd "MUTEX_COUNT=$mutex_count"
puts $fd "DELAY_CELL_COUNT=$delay_count"
puts $fd "WNS=$wns"
puts $fd "WHS=$whs"
puts $fd "RCU_MATCHED_BUF_COUNT=0"
puts $fd "RCU_MATCHED_BUF_STAGES=0"
puts $fd "RCU_MATCHED_DELAY_UNIT_PS=50"
puts $fd "RCU_MATCHED_DELAY_STEPS=1"
puts $fd "OPM_ACKIN_DELAY_UNIT_PS=50"
puts $fd "OPM_ACKIN_DELAY_STEPS=1"
puts $fd "OPM_ACKIN_USE_BUF=0"
close $fd
puts "CMR_SYNC_ROUTER_STRUCTURE IPM=$ipm_count OPM=$opm_count SELECTOR=$selector_count MUTEX=$mutex_count DELAY=$delay_count WNS=$wns WHS=$whs"

if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}
if {$ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_DC_FAIL router_or_port_structure ipm=$ipm_count opm=$opm_count expected=$expected_ports"
  exit 2
}
if {$mutex_count != 0 || $delay_count != 0 || $adapter_count != 0} {
  puts "CMR_DC_FAIL async_primitive_leak mutex=$mutex_count delay=$delay_count adapter=$adapter_count"
  exit 2
}
if {$selector_count != $expected_selectors} {
  puts "CMR_DC_FAIL selector_count selector=$selector_count expected=$expected_selectors"
  exit 2
}
if {$wns eq "NA" || $wns < 0} {
  puts "CMR_DC_FAIL setup_slack wns=$wns"
  exit 2
}
if {$whs eq "NA" || $whs < 0} {
  puts "CMR_DC_FAIL hold_slack whs=$whs"
  exit 2
}

report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 50 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 50 > "$REPORT_DIR/timing_min.rpt"
report_clock -nosplit > "$REPORT_DIR/clock.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/SyncCmrRouter.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/SyncCmrRouter_post.v"
write_sdf "$OUTPUT_DIR/SyncCmrRouter.sdf"
write_sdc "$OUTPUT_DIR/SyncCmrRouter.sdc"
exec sha256sum "$OUTPUT_DIR/SyncCmrRouter.ddc" "$OUTPUT_DIR/SyncCmrRouter_post.v" \
  "$OUTPUT_DIR/SyncCmrRouter.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_DC_PASS output=$OUTPUT_DIR wns=$wns whs=$whs"
quit
