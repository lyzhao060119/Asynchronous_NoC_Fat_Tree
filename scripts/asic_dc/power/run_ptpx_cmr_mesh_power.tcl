# Time-based PrimeTime PX power for a frozen CMR Mesh GLS VCD.
# All inputs are explicit environment variables so the report is bound to one
# immutable netlist/SDF run and one TB_METRICS_V2 measurement window.
foreach key {CMR_POWER_DDC CMR_POWER_SDC CMR_POWER_NETLIST CMR_POWER_SDF CMR_POWER_VCD CMR_POWER_TOP CMR_POWER_STRIP_PATH CMR_POWER_START_NS CMR_POWER_END_NS CMR_POWER_REPORT_DIR} {
  if {![info exists ::env($key)] || $::env($key) eq ""} {
    puts "ERROR: missing $key"
    exit 1
  }
}
set LIB "/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db"
foreach file [list $LIB $::env(CMR_POWER_DDC) $::env(CMR_POWER_SDC) $::env(CMR_POWER_NETLIST) $::env(CMR_POWER_SDF) $::env(CMR_POWER_VCD)] {
  if {![file exists $file]} { puts "ERROR: missing $file"; exit 1 }
}
if {$::env(CMR_POWER_END_NS) <= $::env(CMR_POWER_START_NS)} {
  puts "ERROR: invalid measurement window"
  exit 1
}
file mkdir $::env(CMR_POWER_REPORT_DIR)
exec sha256sum $::env(CMR_POWER_DDC) $::env(CMR_POWER_SDC) $::env(CMR_POWER_NETLIST) $::env(CMR_POWER_SDF) $::env(CMR_POWER_VCD) > "$::env(CMR_POWER_REPORT_DIR)/input_hashes.sha256"
set search_path [list . [file dirname $LIB]]
set target_library [list $LIB]
set link_library [list * $LIB]
read_ddc $::env(CMR_POWER_DDC)
current_design $::env(CMR_POWER_TOP)
link_design
read_sdc $::env(CMR_POWER_SDC)
set power_enable_analysis true
set power_enable_leakage_variation_analysis true
set power_enable_multi_rail_analysis true
set power_analysis_mode time_based
puts "CMR_POWER_WINDOW ns=$::env(CMR_POWER_START_NS):$::env(CMR_POWER_END_NS)"
read_vcd -strip_path $::env(CMR_POWER_STRIP_PATH) $::env(CMR_POWER_VCD) -time [list $::env(CMR_POWER_START_NS) $::env(CMR_POWER_END_NS)]
check_power > "$::env(CMR_POWER_REPORT_DIR)/check_power.rpt"
report_switching_activity -list_not_annotated > "$::env(CMR_POWER_REPORT_DIR)/unannotated_activity.rpt"
update_power
report_power > "$::env(CMR_POWER_REPORT_DIR)/power.rpt"
report_power -hierarchy > "$::env(CMR_POWER_REPORT_DIR)/power_hierarchy.rpt"
report_power -cell_power > "$::env(CMR_POWER_REPORT_DIR)/power_cells.rpt"
puts "CMR_POWER_PASS reports=$::env(CMR_POWER_REPORT_DIR)"
exit
