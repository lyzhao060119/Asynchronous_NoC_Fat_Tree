set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_CFIFO_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_cfifo_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/DLatchBank.v" \
  "$RTL_DIR/PhaseResetDLatch.v" \
  "$RTL_DIR/CircularWriteCounter.v" \
  "$RTL_DIR/CircularReadCounter.v" \
  "$RTL_DIR/WriteControlBlock.v" \
  "$RTL_DIR/ReadControlBlock.v" \
  "$RTL_DIR/CircularFIFO.v" \
  "$RTL_DIR/CircularFifoUnit.v"]
elaborate CircularFifoUnit -work WORK
current_design CircularFifoUnit
uniquify
link
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
set clear_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set set_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]
if {[sizeof_collection $clear_pre] != 118 || [sizeof_collection $set_pre] != 6} {
  puts "TCF_DC_FAIL pre_latch_structure clear=[sizeof_collection $clear_pre] set=[sizeof_collection $set_pre]"
  exit 2
}
set_dont_touch $clear_pre true
set_dont_touch $set_pre true
source "$RTL_DIR/async_primitives.tcl"
compile_ultra -no_autoungroup
source "$PROJECT_DIR/scripts/dc/async_circular_fifo_rtc.sdc"
async_cfifo_insert_hs02_buffer
async_cfifo_apply_hs02 $REPORT_DIR
async_cfifo_apply_rd01 $REPORT_DIR
async_cfifo_insert_rd01_buffers
compile_ultra -incremental -no_autoungroup
async_cfifo_report_hs02 $REPORT_DIR
async_cfifo_report_rd01 $REPORT_DIR
source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]
set wcb [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ WriteControlBlock*}]]
set rcb [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ ReadControlBlock*}]]
set clear [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]]
set set [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]]
puts "TCF_DC_STRUCTURE wcb=$wcb rcb=$rcb clear=$clear set=$set gtech=$n_gtech unmapped=$n_unmapped"
if {$n_gtech > 0 || $n_unmapped > 0 || $wcb != 4 || $rcb != 4 || $clear != 118 || $set != 6} {
  puts "TCF_DC_FAIL post_structure"
  exit 2
}
async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
report_timing -delay_type max -max_paths 50 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 50 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format verilog -output "$OUTPUT_DIR/CircularFifoUnit_post.v"
write_sdf "$OUTPUT_DIR/CircularFifoUnit.sdf"
write -hierarchy -format ddc -output "$OUTPUT_DIR/CircularFifoUnit.ddc"
exec sha256sum "$OUTPUT_DIR/CircularFifoUnit_post.v" "$OUTPUT_DIR/CircularFifoUnit.sdf" "$OUTPUT_DIR/CircularFifoUnit.ddc" > "$REPORT_DIR/post_hashes.sha256"
puts "TCF_DC_PASS output=$OUTPUT_DIR"
quit
