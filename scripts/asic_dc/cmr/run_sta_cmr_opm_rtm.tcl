# Pin-level audit of CMR-OPM-01 / OPM-01-CE on a frozen NoC16 DDC.
# Measurement only: dummy path windows are analysis-only, not production SDC.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_NOC16_BASELINE)
if {[info exists ::env(CMR_PAIRED_STA_RUN_ID)] && $::env(CMR_PAIRED_STA_RUN_ID) ne ""} {
  set RUN_ID $::env(CMR_PAIRED_STA_RUN_ID)
} elseif {[info exists ::env(CMR_OPM_RTM_RUN_ID)]} {
  set RUN_ID $::env(CMR_OPM_RTM_RUN_ID)
} else {
  set RUN_ID "cmr_opm_rtm"
}
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

set STA_DIR [file dirname [info script]]
source "$STA_DIR/sta_cmr_paired_lib.tcl"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
current_design NoC_16nodes
link

cmr_sta_open_csv "$REPORT_DIR/paired_catalog.csv"
cmr_sta_measure_opm01 $REPORT_DIR
cmr_sta_measure_opm01_ce $REPORT_DIR
cmr_sta_close_csv

puts "CMR_OPM_RTM_STA_DONE report=$REPORT_DIR"
quit
