# PrimeTime PX time-based power for async NoC_16nodes smoke VCD.
# Reference style: /home/zhangjl19/ANPX/Nature_Sim/PowerSim/power.tcl
# Do not source or modify that reference script.

set PROJECT_DIR "/home/ghy19/Asynchronous_Router"
set OUTPUT_DIR  "$PROJECT_DIR/outputs"
set REPORT_DIR  "$PROJECT_DIR/reports/NoC_16nodes"
set LOG_DIR     "$PROJECT_DIR/logs"

file mkdir $REPORT_DIR

set LIB_DIR      "/process/course_lib/t28hpc+"
set STD_CELL_LIB "$LIB_DIR/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db"
set DESIGN_DDC   "$OUTPUT_DIR/NoC_16nodes.ddc"
set DESIGN_SDC   "$OUTPUT_DIR/NoC_16nodes_dc.sdc"
set VCD_FILE     "$LOG_DIR/noc16_sdf_smoke.vcd"

if {[info exists ::env(NOC16_POWER_VCD)] && $::env(NOC16_POWER_VCD) ne ""} {
  set VCD_FILE $::env(NOC16_POWER_VCD)
}

if {![file exists $STD_CELL_LIB]} {
  puts "ERROR: missing library $STD_CELL_LIB"
  exit 1
}
if {![file exists $DESIGN_DDC]} {
  puts "ERROR: missing DDC $DESIGN_DDC"
  exit 1
}
if {![file exists $DESIGN_SDC]} {
  puts "ERROR: missing SDC $DESIGN_SDC"
  exit 1
}
if {![file exists $VCD_FILE]} {
  puts "ERROR: missing VCD $VCD_FILE"
  exit 1
}

set search_path [list . $LIB_DIR]
set target_library [list $STD_CELL_LIB]
set link_library [list * $STD_CELL_LIB]

read_ddc $DESIGN_DDC
current_design NoC_16nodes
link_design
read_sdc $DESIGN_SDC

set power_enable_analysis true
set power_enable_leakage_variation_analysis true
set power_enable_multi_rail_analysis true
set power_analysis_mode time_based

set start_time 0
set end_time 0
if {[info exists ::env(NOC16_POWER_START)] && $::env(NOC16_POWER_START) ne ""} {
  set start_time $::env(NOC16_POWER_START)
}
if {[info exists ::env(NOC16_POWER_END)] && $::env(NOC16_POWER_END) ne ""} {
  set end_time $::env(NOC16_POWER_END)
}
# PrimeTime interprets read_vcd -time values in ns for this flow, even though
# the VCS VCD header uses a 1ps timescale.
if {$end_time <= $start_time} {
  puts "ERROR: invalid power window start=$start_time end=$end_time; set NOC16_POWER_START/END in ns"
  exit 1
}

puts "INFO: read_vcd $VCD_FILE -time {$start_time $end_time}"
read_vcd -strip_path tb_gls_noc16_func/dut $VCD_FILE -time [list $start_time $end_time]
check_power > "$REPORT_DIR/power_timebased_smoke_check.rpt"
update_power
report_power > "$REPORT_DIR/power_timebased_smoke.rpt"
report_power -hierarchy > "$REPORT_DIR/power_timebased_smoke_hier.rpt"

puts "INFO: NoC16 time-based power reports:"
puts "INFO: $REPORT_DIR/power_timebased_smoke.rpt"
puts "INFO: $REPORT_DIR/power_timebased_smoke_hier.rpt"
exit
