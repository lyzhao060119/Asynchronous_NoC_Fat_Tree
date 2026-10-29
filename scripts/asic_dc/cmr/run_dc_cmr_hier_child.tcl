# Hop-sized DC of one uniquified CMRRouter* ref from a full NoC DUT.
# Coordinates stay compile-time constants.  Do not elaborate the top here.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_HIER_CHILD_RUN_ID)
set REF $::env(CMR_HIER_REF)
set RTL_DIR "$PROJECT_DIR/rtl"
set DUT_V $::env(CMR_HIER_DUT_V)
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_hier_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_ports 5
if {[info exists ::env(CMR_EXPECTED_PORTS)] && $::env(CMR_EXPECTED_PORTS) ne ""} {
  set expected_ports $::env(CMR_EXPECTED_PORTS)
}
set expected_adapters 0
if {[info exists ::env(CMR_EXPECTED_ADAPTERS)] && $::env(CMR_EXPECTED_ADAPTERS) ne ""} {
  set expected_adapters $::env(CMR_EXPECTED_ADAPTERS)
}
set expected_path_state_dffs [expr {4 * $expected_ports}]
set path_state_impl "dff"
if {[info exists ::env(CMR_PATH_STATE_IMPL)] && $::env(CMR_PATH_STATE_IMPL) ne ""} {
  set path_state_impl $::env(CMR_PATH_STATE_IMPL)
}
set rcu_unit_ps 50
if {[info exists ::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)] && $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS) ne ""} {
  set rcu_unit_ps $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)
}
set opm_ackin_unit_ps 50
if {[info exists ::env(CMR_OPM_ACKIN_DELAY_UNIT_PS)] && $::env(CMR_OPM_ACKIN_DELAY_UNIT_PS) ne ""} {
  set opm_ackin_unit_ps $::env(CMR_OPM_ACKIN_DELAY_UNIT_PS)
}
set opm_reqout_steps 1
if {[info exists ::env(CMR_OPM_REQOUT_DELAY_STEPS)] && $::env(CMR_OPM_REQOUT_DELAY_STEPS) ne ""} {
  set opm_reqout_steps $::env(CMR_OPM_REQOUT_DELAY_STEPS)
}
set opm_reqout_unit_ps 50
if {[info exists ::env(CMR_OPM_REQOUT_DELAY_UNIT_PS)] && $::env(CMR_OPM_REQOUT_DELAY_UNIT_PS) ne ""} {
  set opm_reqout_unit_ps $::env(CMR_OPM_REQOUT_DELAY_UNIT_PS)
}
set opm_reqout_buffer_stages 1
if {[info exists ::env(CMR_OPM_REQOUT_BUFFER_STAGES)] && $::env(CMR_OPM_REQOUT_BUFFER_STAGES) ne ""} {
  set opm_reqout_buffer_stages $::env(CMR_OPM_REQOUT_BUFFER_STAGES)
}

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/DelayElement_ASIC.v" \
  "$RTL_DIR/DontTouchBuf_ASIC.v" \
  "$RTL_DIR/Mutex2_ASIC.v" \
  "$RTL_DIR/Mutex4.v" \
  "$RTL_DIR/MullerC2.v" \
  "$RTL_DIR/CMRMutexN.v" \
  "$RTL_DIR/CMRFlattenedTAC.v" \
  "$RTL_DIR/DLatchBank.v" \
  "$RTL_DIR/V2CloseEvent.v" \
  "$RTL_DIR/Toggle.v" \
  "$RTL_DIR/HeadPredictor.v" \
  "$RTL_DIR/PhaseSelector.v" \
  "$RTL_DIR/AddressRegisterUnit.v" \
  "$RTL_DIR/InternalAckModule.v" \
  "$RTL_DIR/RouteSelAnd2.v" \
  "$RTL_DIR/OPMSelector.v" \
  "$RTL_DIR/PhaseResetDLatch.v" \
  "$RTL_DIR/LanePhaseAdapterDFF.v" \
  "$RTL_DIR/LaneSelector.v" \
  "$RTL_DIR/WriteControlUnit.v" \
  "$RTL_DIR/WriteCounter.v" \
  "$RTL_DIR/WriteAckGenerator.v" \
  "$RTL_DIR/ReadControlUnit.v" \
  "$RTL_DIR/ReadCounter.v" \
  "$RTL_DIR/ReadRequestGenerator.v" \
  "$RTL_DIR/ReadPhaseSelector.v" \
  "$RTL_DIR/ReadAckGenerator.v" \
  $DUT_V]

set uniquify_naming_style "${REF}_%s_%d"
elaborate $REF -work WORK
current_design $REF
uniquify
link
check_design > "$REPORT_DIR/check_design_pre.rpt"

# Current RTL uses one PathStateDFF per route bit.  The frozen CMR_v1 archive
# instead uses reset-dominant BlockLatch + PathLatch pairs.  Keep the default
# strict DFF audit, but allow an explicit archive-only SR-latch audit rather
# than rejecting a structurally valid frozen source tree.
if {$path_state_impl eq "dff"} {
  set path_state_pre [get_cells -hierarchical -quiet -filter {full_name =~ *PathState*path_state_reg && ref_name =~ DFCNQD1BWP12T30P140}]
  set path_state_pre_count [sizeof_collection $path_state_pre]
  if {$path_state_pre_count != $expected_path_state_dffs} {
    puts "CMR_HIER_CHILD_DC_FAIL path_state_dff_pre ref=$REF actual=$path_state_pre_count expected=$expected_path_state_dffs"
    exit 2
  }
  set_dont_touch $path_state_pre true
} elseif {$path_state_impl eq "srlatch"} {
  set expected_path_state_latches [expr {8 * $expected_ports}]
  # Before compile/ungroup the two state holders are hierarchical SRLatch
  # instances (BlockLatch and PathLatch); the LHCNDQD leaf is below them and
  # is not returned by this pre-compile design-level query.
  set block_state_pre [get_cells -hierarchical -quiet -filter {full_name =~ *BlockLatch}]
  set route_state_pre [get_cells -hierarchical -quiet -filter {full_name =~ *PathLatch}]
  set path_state_pre [add_to_collection $block_state_pre $route_state_pre]
  set path_state_pre_count [sizeof_collection $path_state_pre]
  if {$path_state_pre_count != $expected_path_state_latches} {
    puts "CMR_HIER_CHILD_DC_FAIL path_state_srlatch_pre ref=$REF actual=$path_state_pre_count expected=$expected_path_state_latches"
    exit 2
  }
} else {
  puts "CMR_HIER_CHILD_DC_FAIL unsupported_path_state_impl ref=$REF impl=$path_state_impl"
  exit 2
}
switch -- $opm_reqout_unit_ps {
  50  {set opm_reqout_cell DEL050D1BWP12T30P140}
  75  {set opm_reqout_cell DEL075D1BWP12T30P140}
  100 {set opm_reqout_cell DEL100D1BWP12T30P140}
  150 {set opm_reqout_cell DEL150D1BWP12T30P140}
  250 {set opm_reqout_cell DEL250D1BWP12T30P140}
  default {
    puts "CMR_HIER_CHILD_DC_FAIL unsupported_opm_reqout_unit ref=$REF unit=$opm_reqout_unit_ps"
    exit 2
  }
}
set opm_delay_pre [get_cells -hierarchical -quiet -filter "ref_name =~ $opm_reqout_cell && full_name =~ *OPMDelay*"]
set opm_buffer_pre [get_cells -hierarchical -quiet -filter {full_name =~ *OutputPortModules_*/OPMReqoutBuffer_*/D0 && ref_name == BUFFD0BWP12T30P140}]
set opm_delay_pre_count [sizeof_collection $opm_delay_pre]
set opm_buffer_pre_count [sizeof_collection $opm_buffer_pre]
set expected_opm_delay_pre_count [expr {$expected_ports * $opm_reqout_steps}]
set expected_opm_buffer_pre_count [expr {$expected_ports * $opm_reqout_buffer_stages}]
if {$opm_delay_pre_count != $expected_opm_delay_pre_count || $opm_buffer_pre_count != $expected_opm_buffer_pre_count} {
  puts "CMR_HIER_CHILD_DC_FAIL opm_output_protection_pre ref=$REF delay=$opm_delay_pre_count expected_delay=$expected_opm_delay_pre_count buffer=$opm_buffer_pre_count expected_buffer=$expected_opm_buffer_pre_count"
  exit 2
}
# Uniquify prefixes DontTouchBuf references, so a ref_name =~ DontTouchBuf*
# primitive rule does not reliably protect these cells. Preserve exact leaves.
set_dont_touch $opm_buffer_pre true
set clear_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set set_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]
if {[sizeof_collection $clear_pre] == 0 || [sizeof_collection $set_pre] == 0} {
  puts "CMR_HIER_CHILD_DC_FAIL phase_latch_pre ref=$REF"
  exit 2
}
set_dont_touch $clear_pre true
set_dont_touch $set_pre true

source "$RTL_DIR/async_primitives.tcl"
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
compile_ultra -incremental -no_autoungroup
if {$expected_ports > 24} {
  # Preserve the expensive mapped input before equivalent-cell recipes.
  write -hierarchy -format ddc -output "$OUTPUT_DIR/${REF}_mapped_pre_recipe.ddc"
}
if {[info exists ::env(CMR_APPLY_IPM_TIMING_RECIPE)] && $::env(CMR_APPLY_IPM_TIMING_RECIPE) eq "1"} {
  if {[catch {
    source "$PROJECT_DIR/scripts/dc/apply_cmr_ipm_timing_recipe.tcl"
    cmr_ipm_apply_timing_recipe $expected_ports $REPORT_DIR
    source "$PROJECT_DIR/scripts/dc/apply_cmr_router_cell_recipe.tcl"
    cmr_router_apply_cell_recipe $REPORT_DIR
  } recipe_error]} {
    puts "CMR_HIER_CHILD_DC_FAIL ipm_timing_recipe=$recipe_error"
    exit 2
  }
}
check_design > "$REPORT_DIR/check_design_post.rpt"
redirect "$REPORT_DIR/area.rpt" {report_area -hierarchy}
redirect "$REPORT_DIR/reference.rpt" {report_reference -hierarchy}
# Diagnostic only: asynchronous latency acceptance uses event-referenced
# paired STA / SDF, not a fictitious global clock or an unconstrained WNS.
redirect "$REPORT_DIR/timing_diagnostic.rpt" {report_timing -max_paths 20 -input_pins -nets -transition_time -capacitance}
set opm_buffer_post [get_cells -hierarchical -quiet -filter {full_name =~ *OutputPortModules_*/OPMReqoutBuffer_*/D0 && ref_name == BUFFD0BWP12T30P140}]
if {[sizeof_collection $opm_buffer_post] != $expected_opm_buffer_pre_count} {
  puts "CMR_HIER_CHILD_DC_FAIL opm_output_buffer_lost ref=$REF actual=[sizeof_collection $opm_buffer_post] expected=$expected_opm_buffer_pre_count"
  exit 2
}
redirect "$REPORT_DIR/opm_output_buffers_post.rpt" {report_cell -connections $opm_buffer_post}

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]
if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_HIER_CHILD_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped ref=$REF"
  exit 2
}

# Count only the current-design instances InputPortModules_N / OutputPortModules_N.
# Glob filters on full_name or ref_name after uniquify are not reliable here.
set ipm_count 0
set opm_count 0
for {set i 0} {$i < $expected_ports} {incr i} {
  if {[sizeof_collection [get_cells -quiet InputPortModules_$i]] == 1} {
    incr ipm_count
  }
  if {[sizeof_collection [get_cells -quiet OutputPortModules_$i]] == 1} {
    incr opm_count
  }
}
puts "CMR_HIER_CHILD_PORTS ref=$REF ipm=$ipm_count opm=$opm_count expected=$expected_ports"
if {$ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_HIER_CHILD_DC_FAIL ports ref=$REF ipm=$ipm_count opm=$opm_count expected=$expected_ports"
  exit 2
}

write -hierarchy -format ddc -output "$OUTPUT_DIR/${REF}.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/${REF}_post.v"
write_sdf "$OUTPUT_DIR/${REF}.sdf"
exec sha256sum "$OUTPUT_DIR/${REF}.ddc" "$OUTPUT_DIR/${REF}_post.v" "$OUTPUT_DIR/${REF}.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_HIER_CHILD_DC_PASS ref=$REF output=$OUTPUT_DIR ipm=$ipm_count adapters=$expected_adapters"
quit
