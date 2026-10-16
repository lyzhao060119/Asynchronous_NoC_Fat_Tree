# Time-based PrimeTime PX power for a frozen CMR Mesh GLS VCD.
# All inputs are explicit environment variables so the report is bound to one
# immutable netlist/SDF run and one TB_METRICS_V2 measurement window.
foreach key {CMR_POWER_DDC CMR_POWER_NETLIST CMR_POWER_SDF CMR_POWER_VCD CMR_POWER_TOP CMR_POWER_STRIP_PATH CMR_POWER_START_NS CMR_POWER_END_NS CMR_POWER_REPORT_DIR} {
  if {![info exists ::env($key)] || $::env($key) eq ""} {
    puts "ERROR: missing $key"
    exit 1
  }
}
if {[info exists ::env(CMR_POWER_LIB)] && $::env(CMR_POWER_LIB) ne ""} {
  set LIB $::env(CMR_POWER_LIB)
} else {
  set LIB "/process/tsmc/CLN28HPC+/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp12t30p140_180a/tcbn28hpcplusbwp12t30p140tt0p8v25c_ccs.db"
}
foreach file [list $LIB $::env(CMR_POWER_DDC) $::env(CMR_POWER_NETLIST) $::env(CMR_POWER_SDF) $::env(CMR_POWER_VCD)] {
  if {![file exists $file]} { puts "ERROR: missing $file"; exit 1 }
}
if {$::env(CMR_POWER_END_NS) <= $::env(CMR_POWER_START_NS)} {
  puts "ERROR: invalid measurement window"
  exit 1
}
file mkdir $::env(CMR_POWER_REPORT_DIR)
set hash_files [list $::env(CMR_POWER_DDC) $::env(CMR_POWER_NETLIST) $::env(CMR_POWER_SDF) $::env(CMR_POWER_VCD)]
if {[info exists ::env(CMR_POWER_SDC)] && $::env(CMR_POWER_SDC) ne ""} {
  if {![file exists $::env(CMR_POWER_SDC)]} { puts "ERROR: missing $::env(CMR_POWER_SDC)"; exit 1 }
  lappend hash_files $::env(CMR_POWER_SDC)
}
exec sha256sum {*}$hash_files > "$::env(CMR_POWER_REPORT_DIR)/input_hashes.sha256"
set search_path [list . [file dirname $LIB]]
set target_library [list $LIB]
set link_library [list * $LIB]
read_ddc $::env(CMR_POWER_DDC)
current_design $::env(CMR_POWER_TOP)
link_design
if {[info exists ::env(CMR_POWER_SDC)] && $::env(CMR_POWER_SDC) ne ""} {
  read_sdc $::env(CMR_POWER_SDC)
} else {
  puts "CMR_POWER_INFO using constraints embedded in DDC; no external SDC supplied"
}
set power_enable_analysis true
set power_enable_leakage_variation_analysis true
set power_enable_multi_rail_analysis true
set power_analysis_mode time_based
puts "CMR_POWER_WINDOW ns=$::env(CMR_POWER_START_NS):$::env(CMR_POWER_END_NS)"
if {[catch {read_vcd -strip_path $::env(CMR_POWER_STRIP_PATH) $::env(CMR_POWER_VCD) -time [list $::env(CMR_POWER_START_NS) $::env(CMR_POWER_END_NS)]} err]} {
  puts "CMR_POWER_FAIL read_vcd/strip-path: $err"
  exit 2
}
check_power > "$::env(CMR_POWER_REPORT_DIR)/check_power.rpt"
report_switching_activity -list_not_annotated > "$::env(CMR_POWER_REPORT_DIR)/unannotated_activity.rpt"
if {[catch {report_switching_activity > "$::env(CMR_POWER_REPORT_DIR)/activity.rpt"} err]} {
  puts "CMR_POWER_FAIL activity report: $err"
  exit 2
}
if {[catch {update_power} err]} {
  puts "CMR_POWER_FAIL update_power: $err"
  exit 2
}
report_power > "$::env(CMR_POWER_REPORT_DIR)/power.rpt"
report_power -hierarchy > "$::env(CMR_POWER_REPORT_DIR)/power_hierarchy.rpt"
report_power -cell_power > "$::env(CMR_POWER_REPORT_DIR)/power_cells.rpt"
foreach name {check_power.rpt activity.rpt power.rpt power_hierarchy.rpt power_cells.rpt} {
  set path "$::env(CMR_POWER_REPORT_DIR)/$name"
  if {![file exists $path] || [file size $path] == 0} {
    puts "CMR_POWER_FAIL missing report $name"
    exit 2
  }
}
set check [read [open "$::env(CMR_POWER_REPORT_DIR)/check_power.rpt" r]]
if {[regexp -nocase {(^|\s)(error|violation)(\s|:)} $check] && ![regexp -nocase {0\s+errors?} $check]} {
  puts "CMR_POWER_FAIL check_power not clean"
  exit 2
}
puts "CMR_POWER_PASS reports=$::env(CMR_POWER_REPORT_DIR)"
exit
