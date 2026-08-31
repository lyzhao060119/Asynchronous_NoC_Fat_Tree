# Paired STA of CMR-RCU-01 on a frozen standalone CMRRouter DDC.
# Dummy windows only; does not write production SDC or resize DELs.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_ROUTER_STA_BASELINE)
set RUN_ID $::env(CMR_PAIRED_STA_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

set STA_DIR [file dirname [info script]]
source "$STA_DIR/sta_cmr_paired_lib.tcl"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/CMRRouter.ddc"
current_design CMRRouter
link
cmr_sta_reset_inner_exceptions

set man [open "$REPORT_DIR/timing_environment.txt" w]
puts $man "baseline=$BASELINE"
puts $man "run_id=$RUN_ID"
puts $man "design=CMRRouter"
puts $man "dc_version=[version]"
puts $man "pvt=tech_t28ss.tcl (ssg0p81v125c)"
puts $man "role=CMR-RCU-01 paired STA measurement only"
puts $man "production_sdc=none"
puts $man "ddc=$PROJECT_DIR/outputs/$BASELINE/CMRRouter.ddc"
close $man

cmr_sta_open_csv "$REPORT_DIR/paired_catalog.csv"
cmr_sta_measure_rcu01 $REPORT_DIR
cmr_sta_close_csv

puts "CMR_PAIRED_STA_DONE report=$REPORT_DIR"
quit
