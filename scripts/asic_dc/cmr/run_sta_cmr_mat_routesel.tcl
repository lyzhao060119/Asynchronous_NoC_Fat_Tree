# Per-bit Mat vs RouteSel arrival on the L2 IPM0 RCU after the
# RouteSelAnd2 split.  Data startpoints are AddressRegister dest Q;
# control startpoint is Req_rc Q.  Endpoints are the preserved AND2
# pins so the decode cone and the AND stack are timed separately.
# Step C: also emit rise/fall paired CSV for this sample RCU.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_NOC16_BASELINE)
set RUN_ID $::env(CMR_MAT_ROUTESEL_STA_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

set STA_DIR [file dirname [info script]]
source "$STA_DIR/sta_cmr_paired_lib.tcl"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
current_design NoC_16nodes
link

set rcu "routerL2/InputPortModules_0/RouteComputationUnit"
set rc "$rcu/RouteComputation"
set req_q [get_pins -quiet "$rcu/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
set dest_q [get_pins -quiet "$rcu/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/Q"]
set dest_q [remove_from_collection $dest_q $req_q]
set launch_latches [get_cells -quiet "$rcu/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell"]

puts "CMR_MAT_RS_STRUCTURE dest_q=[sizeof_collection $dest_q] req_q=[sizeof_collection $req_q] latches=[sizeof_collection $launch_latches]"
if {[sizeof_collection $req_q] != 1 || [sizeof_collection $dest_q] != 24 || [sizeof_collection $launch_latches] != 25} {
  puts "CMR_MAT_RS_FAIL address_latch_structure"
  exit 2
}

foreach bit {0 1 2 3} {
  set anda [get_pins -quiet "$rc/RouteSelAnd_${bit}/g/A1"]
  set andb [get_pins -quiet "$rc/RouteSelAnd_${bit}/g/A2"]
  set andz [get_pins -quiet "$rc/RouteSelAnd_${bit}/g/Z"]
  set matp [get_pins -quiet "$rcu/io_Mat_${bit}"]
  set rsp  [get_pins -quiet "$rcu/io_RouteSel_${bit}"]
  if {[sizeof_collection $anda] != 1 || [sizeof_collection $andb] != 1 || [sizeof_collection $andz] != 1} {
    puts "CMR_MAT_RS_FAIL and_pins bit=$bit anda=[sizeof_collection $anda] andb=[sizeof_collection $andb] andz=[sizeof_collection $andz]"
    exit 2
  }
  set and_cell [get_cells -of_objects $anda]
  puts "CMR_MAT_RS_PIN bit=$bit anda=[get_object_name $anda] andz=[get_object_name $andz] and_cell=[get_attribute $and_cell ref_name] mat_port=[sizeof_collection $matp] rs_port=[sizeof_collection $rsp]"
  set mat_net [get_nets -quiet -of_objects $anda]
  set mat_drv [get_pins -quiet -of_objects $mat_net -filter {pin_direction == out}]
  foreach_in_collection pin $mat_drv {
    set cell [get_cells -quiet -of_objects $pin]
    puts "CMR_MAT_RS_MATDRV bit=$bit pin=[get_object_name $pin] cell=[get_attribute $cell full_name] ref=[get_attribute $cell ref_name]"
  }
}

set_disable_timing $launch_latches

foreach bit {0 1 2 3} {
  set anda [get_pins "$rc/RouteSelAnd_${bit}/g/A1"]
  set andz [get_pins "$rc/RouteSelAnd_${bit}/g/Z"]
  redirect "$REPORT_DIR/data_to_mat${bit}_max.rpt" {
    report_timing -from $dest_q -to $anda -delay_type max -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/data_to_mat${bit}_min.rpt" {
    report_timing -from $dest_q -to $anda -delay_type min -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/data_to_rs${bit}_max.rpt" {
    report_timing -from $dest_q -to $andz -delay_type max -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/data_to_rs${bit}_min.rpt" {
    report_timing -from $dest_q -to $andz -delay_type min -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/ctrl_to_rs${bit}_max.rpt" {
    report_timing -from $req_q -to $andz -delay_type max -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/ctrl_to_rs${bit}_min.rpt" {
    report_timing -from $req_q -to $andz -delay_type min -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/and2_a1_to_z${bit}.rpt" {
    report_timing -from $anda -to $andz -delay_type max -nworst 1 -max_paths 1 -nosplit
  }
  set ppe [get_pins -quiet [format {%s/io_PathEnabled_%s} $rcu $bit]]
  if {[sizeof_collection $ppe] != 1} {
    set ppe [get_pins -quiet [format {%s/Selector/selector[%s].PathLatch/sr_cell/Q} $rcu $bit]]
  }
  if {[sizeof_collection $ppe] != 1} {
    puts "CMR_MAT_RS_FAIL ppe_pin bit=$bit count=[sizeof_collection $ppe]"
    exit 2
  }
  puts "CMR_MAT_RS_PPE bit=$bit pin=[get_object_name $ppe] cell=[get_attribute [get_cells -of_objects $ppe] ref_name]"
  redirect "$REPORT_DIR/ctrl_to_ppe${bit}_min.rpt" {
    report_timing -from $req_q -to $ppe -delay_type min -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/ctrl_to_ppe${bit}_max.rpt" {
    report_timing -from $req_q -to $ppe -delay_type max -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
  redirect "$REPORT_DIR/rs_to_ppe${bit}_max.rpt" {
    report_timing -from $andz -to $ppe -delay_type max -nworst 1 -max_paths 1 -nosplit -input_pins -nets
  }
}

# Rise/fall paired numbers for this one RCU.  All 25 RCUs are in
# run_sta_cmr_rcu_rtm.tcl / run_sta_cmr_paired_catalog.tcl.
cmr_sta_open_csv "$REPORT_DIR/paired_catalog.csv"
set loop_cut "disable AddressRegister LatchReg latch_cell (dest/req Q startpoints)"
foreach bit {0 1 2 3} {
  set anda [get_pins "$rc/RouteSelAnd_${bit}/g/A1"]
  set andz [get_pins "$rc/RouteSelAnd_${bit}/g/Z"]
  cmr_sta_apply_window $dest_q $anda
  cmr_sta_apply_window $req_q $andz
  foreach edge {rise fall} {
    set tdata [cmr_sta_worst $dest_q $anda max $edge]
    set tctrl [cmr_sta_worst $req_q $andz min $edge]
    cmr_sta_emit CMR-RCU-01 $rcu bit$bit $edge $tdata $tctrl $loop_cut \
      destQ RouteSelAnd.g/A1 reqQ RouteSelAnd.g/Z \
      "L2 IPM0 sample; opening is Z rise"
  }
  cmr_sta_reset_window $dest_q $anda
  cmr_sta_reset_window $req_q $andz
}
cmr_sta_close_csv

puts "CMR_MAT_RS_STA_DONE report=$REPORT_DIR"
quit
