set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RUN_ID $::env(ULTRA_RUN_ID)
# Observation-only STA may reuse a frozen DDC/SDF from another run.
set NETLIST_RUN_ID $RUN_ID
if {[info exists ::env(ULTRA_NETLIST_RUN_ID)] && $::env(ULTRA_NETLIST_RUN_ID) ne ""} {
  set NETLIST_RUN_ID $::env(ULTRA_NETLIST_RUN_ID)
}
set OUT "$PROJECT_DIR/outputs/$NETLIST_RUN_ID"
set RPT "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $RPT
source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
set manifest [open "$RPT/timing_environment.txt" w]
puts $manifest "run_id=$RUN_ID"
puts $manifest "dc_version=[version]"
puts $manifest "library=tech_t28ss.tcl"
puts $manifest "pvt=as configured by tech_t28ss.tcl"
puts $manifest "delay_profile=[expr {[info exists ::env(ASYNC_DELAY_PROFILE)] ? $::env(ASYNC_DELAY_PROFILE) : "UNSET"}]"
puts $manifest "dc_seed=[expr {[info exists ::env(ULTRA_DC_SEED)] ? $::env(ULTRA_DC_SEED) : "NOT_RECORDED"}]"
close $manifest
read_ddc "$OUT/UltraRouter.ddc"
current_design UltraRouter
read_sdc "$OUT/UltraRouter.sdc"
check_timing > "$RPT/check_timing.rpt"
set dels [get_cells -hier -quiet -filter {ref_name =~ DEL250D1*}]
puts "DEL250_COUNT=[sizeof_collection $dels]"
if {[sizeof_collection $dels] > 0} {
  set pins [get_pins -quiet -of_objects $dels -filter {name == I}]
  report_timing -delay_type max -through $pins -max_paths 50 > "$RPT/del250_max.rpt"
  report_timing -delay_type min -through $pins -max_paths 50 > "$RPT/del250_min.rpt"
}
# Async paths must be reported through concrete pins/nets, not cell
# collections.  The old cell-based form was silently rejected by DC and did
# not provide any usable Req/Data comparison.
proc ultra_report_path {file from_pat to_pat through_pat} {
  set fd [open $file w]
  set from [get_pins -hierarchical -quiet $from_pat]
  if {[sizeof_collection $from] == 0} { set from [get_ports -quiet $from_pat] }
  set to [get_pins -hierarchical -quiet $to_pat]
  if {[sizeof_collection $to] == 0} { set to [get_ports -quiet $to_pat] }
  set through [get_pins -hierarchical -quiet $through_pat]
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    puts $fd "NO_PATH from=$from_pat to=$to_pat through=$through_pat"
  } elseif {[sizeof_collection $through] == 0} {
    report_timing -from $from -to $to -delay_type max -path_type full_clock_expanded >> $file
    report_timing -from $from -to $to -delay_type min -path_type full_clock_expanded >> $file
  } else {
    report_timing -from $from -through $through -to $to -delay_type max -path_type full_clock_expanded >> $file
    report_timing -from $from -through $through -to $to -delay_type min -path_type full_clock_expanded >> $file
  }
  close $fd
}

# child0 -> parent (OPM4 local source0 / branch3) characterisation.
ultra_report_path "$RPT/head_req.rpt" \
  "inputModules_0/mousetrap/request_latch/q_reg[0]/Q" \
  "outputModules_4/requestOutLatch/q_reg[0]/D" \
  "inputModules_0/prs/matchedDelay/*/Z"
ultra_report_path "$RPT/body_req.rpt" \
  "inputModules_0/mousetrap/request_latch/q_reg[0]/Q" \
  "outputModules_4/requestOutLatch/q_reg[0]/D" \
  "outputModules_4/requestLatches_0/q_reg[0]/Q"
ultra_report_path "$RPT/data_to_l5.rpt" \
  "inputModules_0/mousetrap/data_latch/q_reg[0]/Q" \
  "outputModules_4/dataOutLatch/q_reg[0]/D" \
  "outputModules_4/dataOutLatch/q_reg[0]/D"
ultra_report_path "$RPT/data_out.rpt" \
  "inputModules_0/mousetrap/data_latch/q_reg[0]/Q" \
  "outputModules_4/dataOutLatch/q_reg[0]/Q" \
  "outputModules_4/dataOutLatch/q_reg[0]/D"
ultra_report_path "$RPT/opm_control_to_reqout.rpt" \
  "outputModules_4/requestLatches_0/q_reg[0]/Q" \
  "io_outputs_parent_0_HS_Req" \
  "outputModules_4/requestOutLatch/q_reg[0]/Q"

# Parallel OPM V2 RTC evidence for all 20 legal source/output edges.  The
# paired reports deliberately retain the control and data legs separately:
# their continuous-time comparison is made by the RTM audit/VCD, not by an
# invented synchronous launch clock.
set rtc_index [open "$RPT/opm_v2_rtc_index.csv" w]
# These are static segment reports, intentionally not an RTM pass/fail table:
# in an asynchronous bundled-data circuit a max/max subtraction would be
# unsound.  TB_RTC_SAMPLE plus multi-corner aggregation supplies Tdata_max and
# Tctrl_min with one common transaction reference.
puts $rtc_index "rtc_id,output,source,phase,control_report,data_d_report,data_q_report,rtm_status,reason"
for {set output 0} {$output < 5} {incr output} {
  for {set source 0} {$source < 4} {incr source} {
    set stem "opm${output}_src${source}"
    ultra_report_path "$RPT/${stem}_control.rpt" \
      "outputModules_${output}/requestLatches_${source}/q_reg[0]/Q" \
      "outputModules_${output}/requestOutLatch/q_reg[0]/D" \
      ""
    ultra_report_path "$RPT/${stem}_data_d.rpt" \
      "outputModules_${output}/io_DataX_${source}_flit[0]" \
      "outputModules_${output}/dataOutLatch/q_reg[0]/D" \
      ""
    ultra_report_path "$RPT/${stem}_data_q.rpt" \
      "outputModules_${output}/dataOutLatch/q_reg[0]/D" \
      "io_outputs_*_Data_flit[0]" \
      "outputModules_${output}/dataOutLatch/q_reg[0]/Q"
    puts $rtc_index "OPM_V2_${output}_${source},$output,$source,rise,${stem}_control.rpt,${stem}_data_d.rpt,${stem}_data_q.rpt,NOT_COMPARABLE_STATIC,requires common-event SDF sample"
    puts $rtc_index "OPM_V2_${output}_${source},$output,$source,fall,${stem}_control.rpt,${stem}_data_d.rpt,${stem}_data_q.rpt,NOT_COMPARABLE_STATIC,requires common-event SDF sample"
  }
}
close $rtc_index

# Preserve pin-level segment evidence for each current DEL250 role.  This is
# Phase-1 measurement only; no min/max delay constraint is derived here.
set role_index [open "$RPT/delay_role_index.csv" w]
puts $role_index "instance,ref_name,input_pin,output_pin,static_max_report,static_min_report,rtm_status"
foreach_in_collection cell [get_cells -hier -quiet -filter {ref_name =~ DEL*}] {
  set ref [get_attribute $cell ref_name]
  set name [get_object_name $cell]
  set ip [get_pins -quiet "$name/I"]
  set op [get_pins -quiet "$name/Z"]
  if {[sizeof_collection $ip] > 0 && [sizeof_collection $op] > 0} {
    set safe [string map {/ _ [ _ ] _ . _} $name]
    set max_file "$RPT/delay_${safe}_max.rpt"
    set min_file "$RPT/delay_${safe}_min.rpt"
    report_timing -from $ip -to $op -delay_type max -path_type full_clock_expanded > $max_file
    report_timing -from $ip -to $op -delay_type min -path_type full_clock_expanded > $min_file
    puts $role_index "$name,$ref,$name/I,$name/Z,[file tail $max_file],[file tail $min_file],NOT_COMPARABLE_STATIC"
  }
}
close $role_index

# Pin-level evidence for the Body reopening chain.  These reports intentionally
# tolerate optimized names by recording NO_PATH instead of failing STA.
ultra_report_path "$RPT/ackgen_d_to_q.rpt" \
  "io_inputs_child_0_0_HS_Ack" \
  "inputModules_0/ackGenerator/ackReg_reg/Q" \
  "inputModules_0/ackGenerator/ackReg_reg/D"
ultra_report_path "$RPT/ackgen_complete_to_cp.rpt" \
  "outputModules_4/requestLatches_0/q_reg[0]/Q" \
  "inputModules_0/ackGenerator/ackReg_reg/CP" \
  "inputModules_0/ackGenerator/N3"
ultra_report_path "$RPT/prs_to_v1_enable.rpt" \
  "inputModules_0/prs/matchedDelay/*/Z" \
  "inputModules_0/mousetrap/latch_en" \
  "inputModules_0/mousetrap/latch_en"
ultra_report_path "$RPT/opm_ack_d_to_q.rpt" \
  "outputModules_4/requestLatches_0/q_reg[0]/Q" \
  "outputModules_4/ackState_0_reg/Q" \
  "outputModules_4/ackState_0_reg/D"
ultra_report_path "$RPT/opm_ack_clock.rpt" \
  "io_outputs_parent_0_HS_Req" \
  "outputModules_4/ackState_0_reg/CP" \
  "outputModules_4/N15"

# Commit/ACG Dfire paired RTC.  Static segments only; Tdata_max/Tctrl_min
# come from the same-reference SDF TB_DFIRE_WINDOW sample, not max-max STA.
# DFIRE0 bypasses the explicit DEL cell: report Start→fire_o as the primary
# control path and mark the cell segment BYPASSED when I/Z pins are gone.
set dfire_z [get_pins -hierarchical -quiet "admission/commitController/fire_o_Dfire*/Z"]
if {[sizeof_collection $dfire_z] == 0} {
  set dfire_z [get_pins -hierarchical -quiet "*commitController*fire_o_Dfire*/Z"]
}
if {[sizeof_collection $dfire_z] > 0} {
  ultra_report_path "$RPT/dfire_start_to_fire.rpt" \
    "admission/commitController/Start" \
    "admission/commitController/fire_o" \
    "admission/commitController/fire_o_Dfire*/Z"
  ultra_report_path "$RPT/dfire_cell_i_to_z.rpt" \
    "admission/commitController/fire_o_Dfire*/I" \
    "admission/commitController/fire_o_Dfire*/Z" \
    ""
} else {
  ultra_report_path "$RPT/dfire_start_to_fire.rpt" \
    "admission/commitController/Start" \
    "admission/commitController/fire_o" \
    ""
  set dfire_bypass [open "$RPT/dfire_cell_i_to_z.rpt" w]
  puts $dfire_bypass "BYPASSED explicit DEL250 removed; Start→fire is the control RTC"
  close $dfire_bypass
  puts "ULTRA_STA_DFIRE_CELL=BYPASSED"
}
ultra_report_path "$RPT/dfire_tx_winner_q_to_active_d.rpt" \
  "admission/tx/winner_latch/*/Q" \
  "admission/activeRegs_0_reg/D" \
  ""
ultra_report_path "$RPT/dfire_tx_mask0_q_to_owner_d.rpt" \
  "admission/tx/txm0/*/Q" \
  "admission/ownerRegs_4_reg*/D" \
  ""
report_constraints -all_violators > "$RPT/constraints.rpt"
puts "ULTRA_STA_DONE report=$RPT"
quit
