# Standalone physical TAC2 compilation for strict-SDF contention diagnosis.
set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/tac2/$::env(ULTRA_TAC2_RUN_ID)"
set OUTPUT_DIR "$PROJECT_DIR/outputs/tac2/$::env(ULTRA_TAC2_RUN_ID)"
set WORK_LIB "$PROJECT_DIR/work/tac2_dc_$::env(ULTRA_TAC2_RUN_ID)"
file mkdir $REPORT_DIR; file mkdir $OUTPUT_DIR; file mkdir $WORK_LIB
source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/Mutex2_ASIC.v" "$RTL_DIR/MullerC2.v" "$RTL_DIR/TAC2.v"]
elaborate TAC2 -work WORK
current_design TAC2
uniquify; link
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
source "$RTL_DIR/async_primitives.tcl"
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design.rpt"
set nand_cells [get_cells -hierarchical -quiet -filter {full_name =~ *q0_nand* || full_name =~ *q1_nand*}]
set filter_cells [get_cells -hierarchical -quiet -filter {full_name =~ *gnt0_inv* || full_name =~ *gnt1_inv* || full_name =~ *gnt0_filter* || full_name =~ *gnt1_filter*}]
puts "TAC2_DC mutex_nand_count=[sizeof_collection $nand_cells] output_filter_count=[sizeof_collection $filter_cells]"
report_cell $nand_cells > "$REPORT_DIR/mutex_cells.rpt"
report_timing -delay_type max -max_paths 20 > "$REPORT_DIR/timing_max.rpt"
write -hierarchy -format verilog -output "$OUTPUT_DIR/TAC2_post.v"
write_sdf "$OUTPUT_DIR/TAC2.sdf"
exec sha256sum "$OUTPUT_DIR/TAC2_post.v" "$OUTPUT_DIR/TAC2.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "TAC2_DC_PASS"
quit
