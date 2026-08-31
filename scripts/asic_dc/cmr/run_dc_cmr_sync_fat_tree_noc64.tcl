# Clocked DC for SyncNoC_64nodes.
# Thin (1,1): 21 routers, 105 ports, 0 SyncLaneSelector.
# Fat 1-2-2-2: 21 routers, 146 ports, 264 SyncLaneSelector.
# No Mutex, no DelayElement, no LanePhaseAdapter.  Clock period from SDC.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_SYNC64_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set DUT_V "$RTL_DIR/SyncNoC_64nodes.v"
if {[info exists ::env(CMR_SYNC64_DUT_V)] && $::env(CMR_SYNC64_DUT_V) ne ""} {
  set DUT_V $::env(CMR_SYNC64_DUT_V)
}
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_sync_noc64_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_routers 21
set expected_ports 105
set expected_top 1
set expected_selectors -1
if {[info exists ::env(CMR_EXPECTED_ROUTERS)] && $::env(CMR_EXPECTED_ROUTERS) ne ""} {
  set expected_routers $::env(CMR_EXPECTED_ROUTERS)
}
if {[info exists ::env(CMR_EXPECTED_PORTS)] && $::env(CMR_EXPECTED_PORTS) ne ""} {
  set expected_ports $::env(CMR_EXPECTED_PORTS)
}
if {[info exists ::env(CMR_EXPECTED_SELECTORS)] && $::env(CMR_EXPECTED_SELECTORS) ne ""} {
  set expected_selectors $::env(CMR_EXPECTED_SELECTORS)
}

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list $DUT_V]
elaborate SyncNoC_64nodes -work WORK
current_design SyncNoC_64nodes
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

set router_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ SyncCmrRouter*}]]
set ipm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ SyncCmrIPM*}]]
set opm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ SyncOPM*}]]
set mutex_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex*}]]
set delay_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement*}]]
set adapter_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]]
set fifo_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ AsyncFifo* || ref_name =~ CircularFifo*}]]
set selector_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ SyncLaneSelector*}]]
set latch_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCSNDQD* || ref_name =~ LHCNDQD* || ref_name =~ LHSNDQD*}]]

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

set fd [open "$REPORT_DIR/cmr_sync_noc64_structure.rpt" w]
puts $fd "ROUTER_COUNT=$router_count"
puts $fd "IPM_COUNT=$ipm_count"
puts $fd "OPM_COUNT=$opm_count"
puts $fd "MUTEX_COUNT=$mutex_count"
puts $fd "DELAY_CELL_COUNT=$delay_count"
puts $fd "ADAPTER_COUNT=$adapter_count"
puts $fd "FIFO_COUNT=$fifo_count"
puts $fd "SELECTOR_COUNT=$selector_count"
puts $fd "LATCH_COUNT=$latch_count"
puts $fd "WNS=$wns"
puts $fd "WHS=$whs"
close $fd
puts "CMR_SYNC64_STRUCTURE ROUTER=$router_count IPM=$ipm_count OPM=$opm_count MUTEX=$mutex_count DELAY=$delay_count ADAPTER=$adapter_count FIFO=$fifo_count SELECTOR=$selector_count LATCH=$latch_count WNS=$wns WHS=$whs"

if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_SYNC64_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}
if {$router_count != $expected_routers || $ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_SYNC64_DC_FAIL router_or_port_structure router=$router_count ipm=$ipm_count opm=$opm_count expected_router=$expected_routers expected_ports=$expected_ports"
  exit 2
}
if {$mutex_count != 0 || $delay_count != 0 || $adapter_count != 0} {
  puts "CMR_SYNC64_DC_FAIL async_primitive_leak mutex=$mutex_count delay=$delay_count adapter=$adapter_count"
  exit 2
}
if {$fifo_count != 0} {
  puts "CMR_SYNC64_DC_FAIL unexpected_fifo fifo=$fifo_count"
  exit 2
}
if {$expected_selectors >= 0 && $selector_count != $expected_selectors} {
  puts "CMR_SYNC64_DC_FAIL selector_count selector=$selector_count expected=$expected_selectors"
  exit 2
}
if {$wns eq "NA" || $wns < 0} {
  puts "CMR_SYNC64_DC_FAIL setup_slack wns=$wns"
  exit 2
}
if {$whs eq "NA" || $whs < 0} {
  puts "CMR_SYNC64_DC_FAIL hold_slack whs=$whs"
  exit 2
}

report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
report_clock -nosplit > "$REPORT_DIR/clock.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/SyncNoC_64nodes.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/SyncNoC_64nodes_post.v"
write_sdf "$OUTPUT_DIR/SyncNoC_64nodes.sdf"
write_sdc "$OUTPUT_DIR/SyncNoC_64nodes.sdc"
exec sha256sum "$OUTPUT_DIR/SyncNoC_64nodes.ddc" "$OUTPUT_DIR/SyncNoC_64nodes_post.v" "$OUTPUT_DIR/SyncNoC_64nodes.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_SYNC64_DC_PASS output=$OUTPUT_DIR wns=$wns whs=$whs"
quit
