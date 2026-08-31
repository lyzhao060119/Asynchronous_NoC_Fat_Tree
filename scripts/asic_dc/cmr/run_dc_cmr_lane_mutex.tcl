# Standalone physical compilation of the exact CMR two-lane selector equation.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_LANE_MUTEX_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_lane_mutex_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/Mutex2_ASIC.v" \
  "$RTL_DIR/CMRMutexN.v" \
  "$RTL_DIR/CMRLaneSelectorMutex2Harness.v"]
elaborate CMRLaneSelectorMutex2Harness -work WORK
current_design CMRLaneSelectorMutex2Harness
uniquify
link

source "$RTL_DIR/async_primitives.tcl"
set selector_mutex [get_cells -hierarchical -quiet -filter {full_name =~ *mutex*}]
if {[sizeof_collection $selector_mutex] == 0} {
  puts "CMR_LANE_MUTEX_DC_FAIL missing_mutex_hierarchy"
  exit 2
}
set_dont_touch $selector_mutex true
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design.rpt"

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]
set nand_cells [get_cells -hierarchical -quiet -filter {(full_name =~ *q0_nand* || full_name =~ *q1_nand*) && ref_name =~ ND2D1BWP12T30P140}]
set filter_cells [get_cells -hierarchical -quiet -filter {ref_name =~ NR4D1BWP12T30P140 && (full_name =~ *gnt0_filter* || full_name =~ *gnt1_filter*)}]
set nand_count [sizeof_collection $nand_cells]
set filter_count [sizeof_collection $filter_cells]
set mismatch_ok [async_mutex2_drive_mismatch_ok]
set fd [open "$REPORT_DIR/lane_mutex_structure.rpt" w]
puts $fd "MUTEX_NAND_COUNT=$nand_count"
puts $fd "MUTEX_NR4_FILTER_COUNT=$filter_count"
puts $fd "MUTEX_NAND_DRIVE_MISMATCH_OK=$mismatch_ok"
puts $fd "GTECH_COUNT=$n_gtech"
puts $fd "UNMAPPED_COUNT=$n_unmapped"
close $fd
if {$n_gtech != 0 || $n_unmapped != 0 || $nand_count != 2 || $filter_count != 2 || !$mismatch_ok} {
  puts "CMR_LANE_MUTEX_DC_FAIL structure nand=$nand_count nr4=$filter_count mismatch_ok=$mismatch_ok gtech=$n_gtech unmapped=$n_unmapped"
  exit 2
}

report_cell $nand_cells > "$REPORT_DIR/mutex_cells.rpt"
report_cell $filter_cells >> "$REPORT_DIR/mutex_cells.rpt"
report_timing -delay_type max -max_paths 20 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 20 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/CMRLaneSelectorMutex2Harness.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/CMRLaneSelectorMutex2Harness_post.v"
write_sdf "$OUTPUT_DIR/CMRLaneSelectorMutex2Harness.sdf"
exec sha256sum "$OUTPUT_DIR/CMRLaneSelectorMutex2Harness.ddc" "$OUTPUT_DIR/CMRLaneSelectorMutex2Harness_post.v" "$OUTPUT_DIR/CMRLaneSelectorMutex2Harness.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_LANE_MUTEX_DC_PASS output=$OUTPUT_DIR"
quit
