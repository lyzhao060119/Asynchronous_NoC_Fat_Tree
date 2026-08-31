# Synopsys Design Compiler RTL synthesis for async NoC_16nodes (TSMC 28nm SS CCS).
#
# Run from ~/Asynchronous_Router on a compute node (not login):
#   module load syn
#   bsub -Is dc_shell-t -64 -f scripts/run_dc_noc16_t28ss.tcl

set PROJECT_DIR "/home/ghy19/Asynchronous_Router"
set RTL_DIR     "$PROJECT_DIR/rtl"
set SCRIPT_DIR  "$PROJECT_DIR/scripts"
set DESIGN_NAME "NoC_16nodes"
set WORK_LIB    "$PROJECT_DIR/work"
set REPORT_DIR  "$PROJECT_DIR/reports/NoC_16nodes"
set OUTPUT_DIR  "$PROJECT_DIR/outputs"
set LOG_DIR     "$PROJECT_DIR/logs"

file mkdir $WORK_LIB
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $LOG_DIR

set_host_options -max_cores 8
# hier_map guidance blocks compile_ultra with GHM-006 on this flow — keep off.
set_app_var hdlin_enable_hier_map false
set verilogout_no_tri true
set_fix_multiple_port_nets -all -buffer_constants

source -echo -verbose "$SCRIPT_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB

analyze -format verilog -work WORK \
  [list \
    "$RTL_DIR/DelayElement_ASIC.v" \
    "$RTL_DIR/Mutex2_ASIC.v" \
    "$RTL_DIR/MullerC2.v" \
    "$RTL_DIR/MullerC3.v" \
    "$RTL_DIR/DLatchBank.v" \
    "$RTL_DIR/MousetrapStage.v" \
    "$RTL_DIR/TAC2.v" \
    "$RTL_DIR/Mutex3Grant.v" \
    "$RTL_DIR/Mutex5Anchor.v" \
    "$RTL_DIR/NoC_16nodes.v" \
  ]

elaborate $DESIGN_NAME -work WORK
current_design $DESIGN_NAME
uniquify
link
check_design > "$REPORT_DIR/check_design_pre_compile.rpt"

set_operating_conditions -library $LIB_NAME $OPERATING_COND
if {[catch {set_wire_load_model -name ZeroWireload -library $LIB_NAME} wlw]} {
  puts "WARN: ZeroWireload not set ($wlw); continuing without explicit wire-load model"
}

source -echo -verbose "$SCRIPT_DIR/async_noc16_t28.sdc"
source -echo -verbose "$SCRIPT_DIR/async_primitives.tcl"

set_max_area 0
catch {remove_unconnected_ports [get_cells -hierarchical *]}

compile_ultra
check_design > "$REPORT_DIR/check_design_post_compile.rpt"
check_timing > "$REPORT_DIR/check_timing.rpt"
catch {compile -incr -only_design_rule}
change_names -rules verilog -hierarchy

source -echo -verbose "$SCRIPT_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmap [async_assert_no_seqgen $REPORT_DIR]
if {$n_gtech > 0 || $n_unmap > 0} {
  puts "ERROR: compile left unmapped cells (GTECH=$n_gtech unmap_flag=$n_unmap) — abort before write"
  exit 1
}

async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"

report_qor > "$REPORT_DIR/qor.rpt"
report_area -hierarchy > "$REPORT_DIR/area.rpt"
report_timing -delay_type max -max_paths 20 > "$REPORT_DIR/timing_setup.rpt"
report_timing -delay_type min -max_paths 20 > "$REPORT_DIR/timing_hold.rpt"
report_power -hierarchy > "$REPORT_DIR/power_vectorless.rpt"

set del_cells [get_cells -hierarchical -quiet -filter {ref_name =~ DEL*}]
if {[sizeof_collection $del_cells] > 0} {
  set del_pins [get_pins -quiet -of_objects $del_cells -filter {name == I}]
  if {[sizeof_collection $del_pins] == 0} {
    set del_pins [get_pins -quiet -of_objects $del_cells -filter {direction == in}]
  }
  if {[sizeof_collection $del_pins] > 0} {
    report_timing -delay_type max -through $del_pins -max_paths 20 \
      > "$REPORT_DIR/timing_through_del.rpt"
  } else {
    puts "WARN: no DEL* input pins for -through report; skipping"
  }
}

write -hierarchy -format ddc -output "$OUTPUT_DIR/${DESIGN_NAME}.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/${DESIGN_NAME}_post.v"
write_sdf "$OUTPUT_DIR/${DESIGN_NAME}_dc.sdf"
write_sdc "$OUTPUT_DIR/${DESIGN_NAME}_dc.sdc"

set gtech_left [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ GTECH*}]]
puts "INFO: final GTECH cell count = $gtech_left"
if {$gtech_left > 0} {
  puts "ERROR: NoC_16nodes netlist still contains GTECH cells"
}

puts "INFO: async NoC_16nodes DC complete. Results under $REPORT_DIR and $OUTPUT_DIR"
quit
