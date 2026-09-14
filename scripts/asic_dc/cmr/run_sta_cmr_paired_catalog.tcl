# Step-C paired STA on the frozen thin NoC16 DDC.
# Measures CMR-RCU-01 (all 25 RCUs, per-bit A1 vs Z) and CMR-OPM-01
# (all 25 OPMs, Head/Body/Tail, rise/fall vs E fall).  OPM-01-CE is a
# same-close segment report, not an inner-loop ID.
# Does not write production SDC and does not resize DelayElement cells.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_NOC16_BASELINE)
set RUN_ID $::env(CMR_PAIRED_STA_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

set STA_DIR [file dirname [info script]]
source "$STA_DIR/sta_cmr_paired_lib.tcl"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
current_design NoC_16nodes
link
cmr_sta_reset_inner_exceptions

set man [open "$REPORT_DIR/timing_environment.txt" w]
puts $man "baseline=$BASELINE"
puts $man "run_id=$RUN_ID"
puts $man "dc_version=[version]"
puts $man "pvt=tech_t28ss.tcl (ssg0p81v125c)"
puts $man "role=step-C paired STA measurement only"
puts $man "production_sdc=none"
puts $man "ddc=$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
close $man

cmr_sta_open_csv "$REPORT_DIR/paired_catalog.csv"
cmr_sta_measure_rcu01 $REPORT_DIR
cmr_sta_measure_opm01 $REPORT_DIR
cmr_sta_measure_opm01_ce $REPORT_DIR
if {[info exists ::env(CMR_STA_MEASURE_LINKS)] && $::env(CMR_STA_MEASURE_LINKS) eq "1"} {
  puts "CMR_PAIRED_LINKS enabled"
  cmr_sta_measure_links $REPORT_DIR
}
cmr_sta_close_csv

puts "CMR_PAIRED_STA_DONE report=$REPORT_DIR"
quit
