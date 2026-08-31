# TSMC 28nm SS CCS library setup for async NoC DC on SIC_C1.
# Library stays on /process/course_lib — do not copy .db off the cluster.
# GTECH.db comes from Synopsys DC install (module load syn); used so residual
# GTECH_* can be remapped / recognized during compile.

set LIB_DIR      "/process/course_lib/t28hpc+"
set STD_CELL_LIB "tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db"
# Logical name inside the CCS .db (must match `list_libs`, not the NLDM basename).
set LIB_NAME     "tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs"
set OPERATING_COND "ssg0p81v125c"

# Synopsys install root (set by module load syn on C1; fallback for batch jobs)
if {![info exists ::env(SYNOPSYS)] || $::env(SYNOPSYS) eq ""} {
  set SYN_ROOT "/soft/synopsys/syn/V-2023.12"
} else {
  set SYN_ROOT $::env(SYNOPSYS)
}
set GTECH_DB "$SYN_ROOT/libraries/syn/gtech.db"
set SYNTHETIC_LIB "dw_foundation.sldb"

set search_path  [list . $LIB_DIR "$SYN_ROOT/libraries/syn"]
set target_library $STD_CELL_LIB
set synthetic_library $SYNTHETIC_LIB
if {[file exists $GTECH_DB]} {
  set link_library "* $STD_CELL_LIB $GTECH_DB $SYNTHETIC_LIB"
  puts "INFO: link_library includes gtech.db at $GTECH_DB"
} else {
  set link_library "* $STD_CELL_LIB $SYNTHETIC_LIB"
  puts "WARN: gtech.db not found at $GTECH_DB; link_library without gtech"
}
