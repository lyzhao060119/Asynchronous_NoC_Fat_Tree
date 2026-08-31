# TSMC 28HPC+ physical kit for CMR Router primitive P&R.
# Paths are discovered at runtime; the literals below are the C1 freeze.

if {![info exists ::env(CMR_PNR_TSMC_HOME)] || $::env(CMR_PNR_TSMC_HOME) eq ""} {
  set ::env(CMR_PNR_TSMC_HOME) "/process/tsmc/CLN28HPC+/TSMCHOME"
}
set TSMC_HOME $::env(CMR_PNR_TSMC_HOME)
set CELL "tcbn28hpcplusbwp12t30p140"
set CELL_LEF_DIR "$TSMC_HOME/digital/Back_End/lef/${CELL}_170a/lef"
set CELL_MW_DIR  "$TSMC_HOME/digital/Back_End/milkyway/${CELL}_170a"
set CELL_GDS_DIR "$TSMC_HOME/digital/Back_End/gds/${CELL}_170a"
set CELL_CCS_DIR "$TSMC_HOME/digital/Front_End/timing_power_noise/CCS/${CELL}_180a"
set COURSE_LIB   "/process/course_lib/t28hpc+"

proc pnr_first {args} {
  foreach p $args {
    if {$p ne "" && [file exists $p]} {
      return $p
    }
  }
  return ""
}

proc pnr_env {name} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return ""
}

set CMR_PNR_LEF [pnr_first [pnr_env CMR_PNR_LEF] \
  "$CELL_LEF_DIR/${CELL}.lef" "$CELL_LEF_DIR/${CELL}_9lm.lef"]
set CMR_PNR_MW [pnr_first [pnr_env CMR_PNR_MW] \
  "$CELL_MW_DIR/frame_only_VHV_0d5_0/tcbn28hpcplusbwp12t30p140" \
  "$CELL_MW_DIR/cell_frame_VHV_0d5_0/tcbn28hpcplusbwp12t30p140" \
  "$CELL_MW_DIR/frame_only_VHV_0d5_0"]
set CMR_PNR_TECH_LEF [pnr_first [pnr_env CMR_PNR_TECH_LEF]]
set CMR_PNR_GDS [pnr_first [pnr_env CMR_PNR_GDS] "$CELL_GDS_DIR/${CELL}.gds"]
set CMR_PNR_LIBERTY [pnr_first [pnr_env CMR_PNR_LIBERTY] \
  "$CELL_CCS_DIR/${CELL}ssg0p81v125c_ccs.lib" \
  "$CELL_CCS_DIR/${CELL}ssg0p81v125c.lib"]
set CMR_PNR_DB [pnr_first [pnr_env CMR_PNR_DB] \
  "$CELL_CCS_DIR/${CELL}ssg0p81v125c_ccs.db" \
  "$COURSE_LIB/${CELL}ssg0p81v125c_ccs.db"]
set CMR_PNR_TECH_TF [pnr_first [pnr_env CMR_PNR_TECH_TF]]
set CMR_PNR_NDM [pnr_first [pnr_env CMR_PNR_NDM]]
set CMR_PNR_QRC [pnr_first [pnr_env CMR_PNR_QRC] \
  "$TSMC_HOME/design_rule/tn28clrp051_2_0/qrcTechFile" \
  "$TSMC_HOME/PDK/PDK1.8_2P3A/QRC.config"]

set CMR_PNR_SITE "core"
if {[pnr_env CMR_PNR_SITE] ne ""} {
  set CMR_PNR_SITE [pnr_env CMR_PNR_SITE]
}
set CMR_PNR_CORNER "ssg0p81v125c"
set CMR_PNR_LIBNAME $CELL
set CMR_PNR_UTIL 0.60
if {[pnr_env CMR_PNR_UTIL] ne ""} {
  set CMR_PNR_UTIL [pnr_env CMR_PNR_UTIL]
}

puts "CMR_PNR_TECH lef=$CMR_PNR_LEF techlef=$CMR_PNR_TECH_LEF mw=$CMR_PNR_MW gds=$CMR_PNR_GDS liberty=$CMR_PNR_LIBERTY db=$CMR_PNR_DB tf=$CMR_PNR_TECH_TF ndm=$CMR_PNR_NDM qrc=$CMR_PNR_QRC"
if {$CMR_PNR_LEF eq ""} {
  puts "CMR_PNR_FAIL missing_lef"
  exit 2
}
