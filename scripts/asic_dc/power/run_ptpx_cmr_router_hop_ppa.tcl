# PrimeTime PX time-based power for one frozen CMR RouterL1 post-DC result.
# Environment inputs are mandatory so this script cannot accidentally use a
# shared NoC output directory.
foreach required {CMR_REMOTE_ROOT CMR_RUN_ID CMR_NETLIST_RUN_ID CMR_POWER_START_NS CMR_POWER_END_NS} {
  if {![info exists ::env($required)] || $::env($required) eq ""} {
    puts "PPA_POWER_FAIL missing environment variable $required"
    exit 2
  }
}

set ROOT $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_RUN_ID)
set NETLIST_RUN_ID $::env(CMR_NETLIST_RUN_ID)
set START_NS $::env(CMR_POWER_START_NS)
set END_NS $::env(CMR_POWER_END_NS)
set OUT "$ROOT/outputs/$NETLIST_RUN_ID"
set REPORT_DIR "$ROOT/reports/hop_ppa/$RUN_ID/power"
set DUT_NAME "CMRRouter"
if {[info exists ::env(CMR_DUT_NAME)] && $::env(CMR_DUT_NAME) ne ""} {
  set DUT_NAME $::env(CMR_DUT_NAME)
}
set TB_STRIP "tb_cmr_router_hop_ppa/dut"
if {[info exists ::env(CMR_TB_STRIP)] && $::env(CMR_TB_STRIP) ne ""} {
  set TB_STRIP $::env(CMR_TB_STRIP)
}
set VCD_FILE "$ROOT/logs/hop_ppa/$RUN_ID/gls/hop_ppa.vcd"
set LIB_DIR "/process/course_lib/t28hpc+"
set STD_CELL_LIB "$LIB_DIR/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db"

if {$END_NS <= $START_NS} {
  puts "PPA_POWER_FAIL invalid time window $START_NS $END_NS"
  exit 2
}
foreach file [list $STD_CELL_LIB "$OUT/$DUT_NAME.ddc" "$OUT/$DUT_NAME.sdc" $VCD_FILE] {
  if {![file exists $file] || [file size $file] == 0} {
    puts "PPA_POWER_FAIL missing input $file"
    exit 2
  }
}
file mkdir $REPORT_DIR
set search_path [list . $LIB_DIR]
set target_library [list $STD_CELL_LIB]
set link_library [list * $STD_CELL_LIB]
read_ddc "$OUT/$DUT_NAME.ddc"
current_design $DUT_NAME
link_design
read_sdc "$OUT/$DUT_NAME.sdc"

set power_enable_analysis true
set power_enable_leakage_variation_analysis true
set power_enable_multi_rail_analysis true
set power_analysis_mode time_based

proc report_vcd_window {vcd_file start_ns end_ns report_path label} {
  if {$end_ns <= $start_ns} {
    puts "PPA_POWER_FAIL invalid $label window $start_ns $end_ns"
    exit 2
  }
  catch {reset_switching_activity}
  puts "PPA_POWER_INFO VCD=$vcd_file window_ns=$start_ns:$end_ns label=$label"
  read_vcd -strip_path $TB_STRIP $vcd_file -time [list $start_ns $end_ns]
  update_power
  report_power > $report_path
}

report_vcd_window $VCD_FILE $START_NS $END_NS "$REPORT_DIR/power.rpt" "packet"
check_power > "$REPORT_DIR/check_power.rpt"
report_power -hierarchy > "$REPORT_DIR/power_hierarchy.rpt"
report_power -cell_power > "$REPORT_DIR/power_cells.rpt"

if {[info exists ::env(CMR_POWER_FLIT_WINDOWS)] && $::env(CMR_POWER_FLIT_WINDOWS) ne ""} {
  set labels [list head body tail]
  set index 0
  foreach win [split $::env(CMR_POWER_FLIT_WINDOWS) ","] {
    set parts [split $win ":"]
    if {[llength $parts] != 2} {
      puts "PPA_POWER_FAIL invalid flit window $win"
      exit 2
    }
    set label [lindex $labels $index]
    report_vcd_window $VCD_FILE [lindex $parts 0] [lindex $parts 1] \
      "$REPORT_DIR/power_${label}.rpt" $label
    incr index
  }
}

puts "PPA_POWER_PASS reports=$REPORT_DIR"
exit
