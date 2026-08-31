# Separate structural boundary endpoint synthesis for strict NoC16 SDF runs.
set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RUN_ID $::env(ULTRA_NOC16_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID/endpoints"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID/endpoints"
set WORK_LIB "$PROJECT_DIR/sim/work/dc_endpoint_$RUN_ID"
file mkdir $REPORT_DIR; file mkdir $OUTPUT_DIR; file mkdir $WORK_LIB

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/DLatchBank.v" "$RTL_DIR/MousetrapStage.v" "$RTL_DIR/AsyncEndpointBank20.sv"]
elaborate AsyncEndpointBank20 -work WORK
current_design AsyncEndpointBank20
link
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design.rpt"
set reset_latches [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set latch_count [sizeof_collection $reset_latches]
puts "ULTRA_ENDPOINT_LATCH_COUNT=$latch_count"
if {$latch_count < 40} { puts "ULTRA_ENDPOINT_DC_FAIL missing_mousetrap_latches"; exit 2 }
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/AsyncEndpointBank20.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/AsyncEndpointBank20_post.v"
write_sdf "$OUTPUT_DIR/AsyncEndpointBank20.sdf"
exec sha256sum "$OUTPUT_DIR/AsyncEndpointBank20.ddc" "$OUTPUT_DIR/AsyncEndpointBank20_post.v" "$OUTPUT_DIR/AsyncEndpointBank20.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "ULTRA_ENDPOINT_DC_PASS output=$OUTPUT_DIR"
quit
