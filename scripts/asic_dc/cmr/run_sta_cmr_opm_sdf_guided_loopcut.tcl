# Measurement-only pilot for the SDF-confirmed RouterL1 OPM0 source-2 path.
# One causal acknowledgement return arc is cut to open the protocol loop;
# the measured Reqout/DataReg CP->Q arcs are intentionally kept enabled.

set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_ROUTER_STA_BASELINE)
set RUN_ID $::env(CMR_PAIRED_STA_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
set WINDOW_NS 20.0
file mkdir $REPORT_DIR
file mkdir "$REPORT_DIR/paths"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/CMRRouter.ddc"
current_design CMRRouter
link

proc cmr_require_one {objects label} {
  if {[sizeof_collection $objects] != 1} {
    puts "CMR_STA_FAIL bind=$label count=[sizeof_collection $objects]"
    exit 2
  }
}

proc cmr_measure_pin_path {from to dtype edge} {
  if {$edge eq "rise"} {
    set paths [get_timing_paths -from $from -rise_to $to -delay_type $dtype -max_paths 1 -nworst 1]
  } else {
    set paths [get_timing_paths -from $from -fall_to $to -delay_type $dtype -max_paths 1 -nworst 1]
  }
  if {[sizeof_collection $paths] != 1} { return NO_PATH }
  set delay [get_attribute [index_collection $paths 0] arrival]
  if {$delay eq "" || ![string is double -strict $delay]} { return NO_PATH }
  return $delay
}

set opm [get_cells -quiet OutputPortModules_0]
cmr_require_one $opm OPM0
set data_regs [get_cells -quiet -hierarchical -filter {full_name =~ OutputPortModules_0/DataReg_ff_reg*}]
set data_reg ""
foreach_in_collection c $data_regs {
  if {[regexp {OutputPortModules_0/DataReg_ff_reg\[27\]$} [get_object_name $c]]} {
    set data_reg $c
  }
}
set req_reg [get_cells -quiet OutputPortModules_0/io_Reqout_ff_reg]
set ack_reg [get_cells -quiet OutputPortModules_0/FF0_FF3_2_reg]
cmr_require_one $data_reg OPM0_DataReg27
cmr_require_one $req_reg OPM0_Reqout
cmr_require_one $ack_reg OPM0_AckoutSource2

set data_cp [get_pins -quiet -of_objects $data_reg -filter {name == CP}]
set data_q [get_pins -quiet -of_objects $data_reg -filter {name == Q}]
set req_cp [get_pins -quiet -of_objects $req_reg -filter {name == CP}]
set req_q [get_pins -quiet -of_objects $req_reg -filter {name == Q}]
set ack_cp [get_pins -quiet -of_objects $ack_reg -filter {name == CP}]
set ack_q [get_pins -quiet -of_objects $ack_reg -filter {name == Q}]
cmr_require_one $data_cp OPM0_DataReg27_CP
cmr_require_one $data_q OPM0_DataReg27_Q
cmr_require_one $req_cp OPM0_Reqout_CP
cmr_require_one $req_q OPM0_Reqout_Q
cmr_require_one $ack_cp OPM0_Ackout2_CP
cmr_require_one $ack_q OPM0_Ackout2_Q

# SDF probe confirms Ackout_2 returns through InputPortModules_3.io_Ackin_0
# at 31.572 ns, after Reqout (31.435 ns) and Dataout (31.462 ns).  Cut only
# this return-state CP->Q arc for the read-only c2q query.  Do not cut either
# measured output register arc or RegEnable-to-CP source.
if {[catch {set_disable_timing -from CP -to Q $ack_reg} cut_err]} {
  puts "CMR_STA_FAIL loop_cut=OPM0_AckoutSource2 error=$cut_err"
  exit 2
}
puts "CMR_STA_LOOP_CUT id=CMR-OPM0-SDF-ACK-RETURN-01 cell=[get_object_name $ack_reg] from=CP to=Q feeds=InputPortModules_3.io_Ackin_0 reason=SDF_ackout2_after_req_and_data measured_arcs_preserved=DataReg27.CP-Q,Reqout.CP-Q"

# Apply analysis-only windows once per measured arc, then query both edge
# polarities.  The production SDC and frozen DDC are never written.
foreach pair [list [list $data_cp $data_q] [list $req_cp $req_q]] {
  lassign $pair from to
  if {[catch {set_max_delay $WINDOW_NS -from $from -to $to} e1]} {
    puts "CMR_STA_FAIL analysis_max_delay error=$e1"; exit 2
  }
  if {[catch {set_min_delay 0.0 -from $from -to $to} e2]} {
    puts "CMR_STA_FAIL analysis_min_delay error=$e2"; exit 2
  }
}

set csv "$REPORT_DIR/opm0_sdf_guided_c2q.csv"
set fd [open $csv w]
puts $fd "class,instance,bit,data_edge,delay_type,delay_ns,from_pin,to_pin,no_path"
set data_rise_max [cmr_measure_pin_path $data_cp $data_q max rise]
set data_fall_max [cmr_measure_pin_path $data_cp $data_q max fall]
set req_rise_min [cmr_measure_pin_path $req_cp $req_q min rise]
set req_fall_min [cmr_measure_pin_path $req_cp $req_q min fall]
foreach row [list \
  [list DATA max rise $data_rise_max $data_cp $data_q] \
  [list DATA max fall $data_fall_max $data_cp $data_q] \
  [list REQ min rise $req_rise_min $req_cp $req_q] \
  [list REQ min fall $req_fall_min $req_cp $req_q]] {
  lassign $row kind dtype edge delay from to
  set no_path [expr {$delay eq "NO_PATH"}]
  puts $fd [join [list CMR-OPM-Q-01 OutputPortModules_0 27 $kind/$edge $dtype $delay [get_object_name $from] [get_object_name $to] $no_path] ","]
}
close $fd

redirect "$REPORT_DIR/paths/datareg27_c2q_rise_max.rpt" {
  report_timing -from $data_cp -rise_to $data_q -delay_type max -max_paths 1 -nosplit -input_pins -nets
}
redirect "$REPORT_DIR/paths/reqout_c2q_rise_min.rpt" {
  report_timing -from $req_cp -rise_to $req_q -delay_type min -max_paths 1 -nosplit -input_pins -nets
}
redirect "$REPORT_DIR/paths/ackout2_cut.rpt" {
  report_timing -from $ack_cp -rise_to $ack_q -delay_type max -max_paths 1 -nosplit -input_pins -nets
}

set summary "$REPORT_DIR/opm0_sdf_guided_summary.txt"
set sf [open $summary w]
puts $sf "baseline=$BASELINE"
puts $sf "corner=ssg0p81v125c"
puts $sf "analysis_only=true"
puts $sf "loop_cut=OutputPortModules_0/FF0_FF3_2_reg CP->Q"
puts $sf "measured_data=OutputPortModules_0/DataReg_ff_reg\[27\] CP->Q"
puts $sf "measured_control=OutputPortModules_0/io_Reqout_ff_reg CP->Q"
puts $sf "sdf_reference=common RegEnable; Reqout rise 31.435 ns; Dataout rise 31.462 ns"
puts $sf "data_rise_max_ns=$data_rise_max"
puts $sf "data_fall_max_ns=$data_fall_max"
puts $sf "req_rise_min_ns=$req_rise_min"
puts $sf "req_fall_min_ns=$req_fall_min"
if {$data_rise_max ne "NO_PATH" && $req_rise_min ne "NO_PATH"} {
  set shortfall [expr {$data_rise_max > $req_rise_min ? $data_rise_max - $req_rise_min : 0.0}]
  set rtm [expr {$data_rise_max == 0.0 ? 0.0 : 100.0 * ($req_rise_min - $data_rise_max) / $data_rise_max}]
  puts $sf "rise_shortfall_ns=$shortfall"
  puts $sf "rise_rtm_pct=$rtm"
} else {
  puts $sf "rise_shortfall_ns=NA"
  puts $sf "rise_rtm_pct=NA"
}
close $sf

if {$data_rise_max eq "NO_PATH" || $req_rise_min eq "NO_PATH"} {
  puts "CMR_STA_FAIL measured_path_no_path"
  exit 2
}
puts "CMR_STA_OPM_SDF_GUIDED_DONE data_rise_max_ns=$data_rise_max req_rise_min_ns=$req_rise_min"
quit
