# Standalone physical Mutex5 compilation for the TAB dynamic-request trace.
set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/mutex5/$::env(ULTRA_MUTEX5_RUN_ID)"
set OUTPUT_DIR "$PROJECT_DIR/outputs/mutex5/$::env(ULTRA_MUTEX5_RUN_ID)"
set WORK_LIB "$PROJECT_DIR/work/mutex5_dc_$::env(ULTRA_MUTEX5_RUN_ID)"
file mkdir $REPORT_DIR; file mkdir $OUTPUT_DIR; file mkdir $WORK_LIB
source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/Mutex2_ASIC.v" "$RTL_DIR/MullerC2.v" "$RTL_DIR/TAC2.v" \
  "$RTL_DIR/Mutex3Grant.v" "$RTL_DIR/Mutex5Anchor.v"]
elaborate Mutex5Anchor -work WORK
current_design Mutex5Anchor
uniquify; link
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
source "$RTL_DIR/async_primitives.tcl"
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design.rpt"
report_timing -delay_type max -max_paths 50 > "$REPORT_DIR/timing_max.rpt"
write -hierarchy -format verilog -output "$OUTPUT_DIR/Mutex5Anchor_post.v"
write_sdf "$OUTPUT_DIR/Mutex5Anchor.sdf"
exec sha256sum "$OUTPUT_DIR/Mutex5Anchor_post.v" "$OUTPUT_DIR/Mutex5Anchor.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "MUTEX5_DC_PASS"
quit
