set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_PATH_LATCH_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_path_latch_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK "$RTL_DIR/OPMSelector.v"
elaborate OPMSelector -work WORK
current_design OPMSelector
uniquify
link

set path_pre [get_cells -hierarchical -quiet -filter {full_name =~ *PathLatch*sr_cell && ref_name =~ LHCNDQD*}]
set dual_pre [get_cells -hierarchical -quiet -filter {full_name =~ *PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]
set path_pre_count [sizeof_collection $path_pre]
set dual_pre_count [sizeof_collection $dual_pre]
if {$path_pre_count != 4 || $dual_pre_count != 0} {
  puts "CMR_PATH_LATCH_DC_FAIL pre clear=$path_pre_count dual=$dual_pre_count"
  exit 2
}
set_dont_touch $path_pre true
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]
set path_post [get_cells -hierarchical -quiet -filter {full_name =~ *PathLatch*sr_cell && ref_name =~ LHCNDQD*}]
set dual_post [get_cells -hierarchical -quiet -filter {full_name =~ *PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]
set path_post_count [sizeof_collection $path_post]
set dual_post_count [sizeof_collection $dual_post]

set fd [open "$REPORT_DIR/path_latch_structure.rpt" w]
puts $fd "PATH_LATCH_CLEAR_COUNT=$path_post_count"
puts $fd "PATH_LATCH_DUAL_COUNT=$dual_post_count"
puts $fd "GTECH_COUNT=$n_gtech"
puts $fd "UNMAPPED_COUNT=$n_unmapped"
close $fd

if {$n_gtech != 0 || $n_unmapped != 0 || $path_post_count != 4 || $dual_post_count != 0} {
  puts "CMR_PATH_LATCH_DC_FAIL post clear=$path_post_count dual=$dual_post_count gtech=$n_gtech unmapped=$n_unmapped"
  exit 2
}

report_timing -delay_type max -max_paths 20 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 20 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/OPMSelector.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/OPMSelector_post.v"
write_sdf "$OUTPUT_DIR/OPMSelector.sdf"
exec sha256sum "$OUTPUT_DIR/OPMSelector.ddc" "$OUTPUT_DIR/OPMSelector_post.v" "$OUTPUT_DIR/OPMSelector.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_PATH_LATCH_DC_PASS output=$OUTPUT_DIR"
quit
