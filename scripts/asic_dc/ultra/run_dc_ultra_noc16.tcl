# Strict, isolated DC entry for the generated Ultra NoC16 fabric.
set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RTL_DIR "$PROJECT_DIR/rtl"
set RUN_ID $::env(ULTRA_NOC16_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/sim/work/dc_$RUN_ID"
file mkdir $REPORT_DIR; file mkdir $OUTPUT_DIR; file mkdir $WORK_LIB

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/DelayElement_ASIC.v" "$RTL_DIR/Mutex2_ASIC.v" \
  "$RTL_DIR/MullerC2.v" "$RTL_DIR/MullerC3.v" "$RTL_DIR/DLatchBank.v" "$RTL_DIR/V2CloseEvent.v" \
  "$RTL_DIR/MousetrapStage.v" "$RTL_DIR/TAC2.v" "$RTL_DIR/Mutex3Grant.v" \
  "$RTL_DIR/Mutex5Anchor.v" "$RTL_DIR/UltraHeadCaptureCell.v" \
  "$RTL_DIR/AsyncRoundMembershipCell.v" "$RTL_DIR/AsyncRoundDecisionCell.v" \
  "$RTL_DIR/AsyncArbiterTransactionController.v" "$RTL_DIR/NoC_16nodes.v"]
elaborate NoC_16nodes -work WORK
current_design NoC_16nodes
uniquify; link
check_design > "$REPORT_DIR/check_design_pre.rpt"
source "$RTL_DIR/async_primitives.tcl"
# Preserve the asynchronous entry structure. Mapping, sizing and buffers are
# permitted; cross-hierarchy Boolean restructuring is not.
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design_post.rpt"
source "$RTL_DIR/assert_no_gtech.tcl"
set ng [async_assert_no_gtech $REPORT_DIR]
set nu [async_assert_no_seqgen $REPORT_DIR]
async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
set mutex_nand_cells [get_cells -hierarchical -quiet -filter {(full_name =~ *q0_nand* || full_name =~ *q1_nand*) && (ref_name =~ ND2D1BWP12T30P140 || ref_name =~ ND2D2BWP12T30P140)}]
set mutex_filter_cells [get_cells -hierarchical -quiet -filter {ref_name =~ NR4D1BWP12T30P140 && (full_name =~ *gnt0_filter* || full_name =~ *gnt1_filter*)}]
set mutex_nand_count [sizeof_collection $mutex_nand_cells]
set mutex_filter_count [sizeof_collection $mutex_filter_cells]
set mutex_mismatch_ok [async_mutex2_drive_mismatch_ok]
puts "ULTRA_NOC16_MUTEX_STRUCTURE ND2=$mutex_nand_count NR4D1_FILTER=$mutex_filter_count DRIVE_MISMATCH_OK=$mutex_mismatch_ok"
if {$mutex_nand_count == 0 || $mutex_filter_count != $mutex_nand_count || ($mutex_nand_count % 2) != 0 || !$mutex_mismatch_ok} {
  puts "ULTRA_NOC16_DC_FAIL mutex2_filter_structure"
  exit 2
}
set reset_latches [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set reset_latch_count [sizeof_collection $reset_latches]
set v2_plain_latches [get_cells -hierarchical -quiet -filter {full_name =~ *requestOutLatch* && ref_name =~ LHQ*}]
set v2_plain_latch_count [sizeof_collection $v2_plain_latches]
set close_events [get_cells -hierarchical -quiet -filter {full_name =~ *closeEvent*}]
set close_event_count [sizeof_collection $close_events]
puts "ULTRA_NOC16_RESETTABLE_LATCH_COUNT=$reset_latch_count V2_PLAIN_LATCH_COUNT=$v2_plain_latch_count V2_CLOSE_EVENT_COUNT=$close_event_count"
if {$reset_latch_count == 0 || $v2_plain_latch_count != 0 || $close_event_count == 0} {
  puts "ULTRA_NOC16_DC_FAIL resettable_latch_or_close_event_structure"
  exit 2
}
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
if {$ng > 0 || $nu > 0} { puts "ULTRA_NOC16_DC_FAIL gtech=$ng unmapped=$nu"; exit 2 }
write -hierarchy -format ddc -output "$OUTPUT_DIR/NoC_16nodes.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/NoC_16nodes_post.v"
write_sdf "$OUTPUT_DIR/NoC_16nodes.sdf"
write_sdc "$OUTPUT_DIR/NoC_16nodes.sdc"
exec sha256sum "$OUTPUT_DIR/NoC_16nodes.ddc" "$OUTPUT_DIR/NoC_16nodes_post.v" "$OUTPUT_DIR/NoC_16nodes.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "ULTRA_NOC16_DC_PASS output=$OUTPUT_DIR"
quit
