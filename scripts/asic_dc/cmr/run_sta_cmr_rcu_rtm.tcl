# Exhaustive post-DC audit of the Fig. 6 RCU bundled-data relation.
# Aggregate reports still terminate at io_RouteSel_*.  Step C then fills
# per-bit RouteSelAnd2 A1 vs Z for all 25 RCUs (catalog CMR-RCU-01).
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_NOC16_BASELINE)
set RUN_ID $::env(CMR_RCU_RTM_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

set STA_DIR [file dirname [info script]]
source "$STA_DIR/sta_cmr_paired_lib.tcl"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
current_design NoC_16nodes
link

set rcus [get_cells -hierarchical -quiet -filter {
  full_name =~ *InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*
}]
set first_rcu 1
foreach_in_collection rcu $rcus {
  set root [get_object_name $rcu]
  set req_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
  set dest_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/Q"]
  set dest_q [remove_from_collection $dest_q $req_q]
  set route_sel [get_pins -quiet "$root/io_RouteSel_*"]
  set address_latches [get_cells -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell"]
  if {[sizeof_collection $req_q] != 1 || [sizeof_collection $dest_q] != 24 || [sizeof_collection $route_sel] != 4 || [sizeof_collection $address_latches] != 25} {
    puts "CMR_RCU_RTM_FAIL rcu=$root req_q=[sizeof_collection $req_q] dest_q=[sizeof_collection $dest_q] route_sel=[sizeof_collection $route_sel]"
    exit 2
  }
  if {$first_rcu} {
    set data_startpoints $dest_q
    set control_startpoints $req_q
    set endpoints $route_sel
    set launch_latches $address_latches
    set first_rcu 0
  } else {
    set data_startpoints [add_to_collection $data_startpoints $dest_q]
    set control_startpoints [add_to_collection $control_startpoints $req_q]
    set endpoints [add_to_collection $endpoints $route_sel]
    set launch_latches [add_to_collection $launch_latches $address_latches]
  }
}

set rcu_count [sizeof_collection $rcus]
set data_count [sizeof_collection $data_startpoints]
set control_count [sizeof_collection $control_startpoints]
set endpoint_count [sizeof_collection $endpoints]
set launch_latch_count [sizeof_collection $launch_latches]
puts "CMR_RCU_RTM_STRUCTURE rcus=$rcu_count data_starts=$data_count control_starts=$control_count endpoints=$endpoint_count launch_latches=$launch_latch_count"
if {$rcu_count != 25 || $data_count != 600 || $control_count != 25 || $endpoint_count != 100 || $launch_latch_count != 625} {
  puts "CMR_RCU_RTM_FAIL endpoint_structure"
  exit 2
}

# The audit reference is the AddressRegister Q boundary.  Without this
# analysis-only cut, DC transparently borrows through LHC* latches and reports
# reset/D-to-Q paths, which are not comparable with the matched-delay launch.
set_disable_timing $launch_latches

redirect "$REPORT_DIR/data_max.rpt" {
  report_timing -from $data_startpoints -to $endpoints -delay_type max -max_paths 100 -nosplit
}
redirect "$REPORT_DIR/control_min.rpt" {
  report_timing -from $control_startpoints -to $endpoints -delay_type min -max_paths 100 -nosplit
}
redirect "$REPORT_DIR/control_max.rpt" {
  report_timing -from $control_startpoints -to $endpoints -delay_type max -max_paths 100 -nosplit
}

# Catalog endpoints are AND2 A1 vs Z, not the io_RouteSel hierarchy pins.
# Re-measure after the aggregate reports; loop-cut is the same latch disable.
cmr_sta_open_csv "$REPORT_DIR/paired_catalog.csv"
cmr_sta_measure_rcu01 $REPORT_DIR
cmr_sta_close_csv

puts "CMR_RCU_RTM_STA_DONE report=$REPORT_DIR"
quit
