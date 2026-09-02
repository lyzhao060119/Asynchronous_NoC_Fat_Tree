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
set expected_path_latches [expr {4 * $expected_ports}]
set rcu_unit_ps 50
if {[info exists ::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)] && $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS) ne ""} {
  set rcu_unit_ps $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)
}
set opm_ackin_unit_ps 50
if {[info exists ::env(CMR_OPM_ACKIN_DELAY_UNIT_PS)] && $::env(CMR_OPM_ACKIN_DELAY_UNIT_PS) ne ""} {
  set opm_ackin_unit_ps $::env(CMR_OPM_ACKIN_DELAY_UNIT_PS)
}

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
analyze -format verilog -define ASIC_T28 -work WORK [list \
  "$RTL_DIR/DelayElement_ASIC.v" \
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
  "$RTL_DIR/LanePhaseAdapter.v" \
  "$RTL_DIR/WriteControlUnit.v" \
  "$RTL_DIR/WriteCounter.v" \
  "$RTL_DIR/WriteAckGenerator.v" \
  "$RTL_DIR/ReadControlUnit.v" \
  "$RTL_DIR/ReadCounter.v" \
  "$RTL_DIR/ReadRequestGenerator.v" \
  "$RTL_DIR/ReadPhaseSelector.v" \
  "$RTL_DIR/ReadAckGenerator.v" \
  "$RTL_DIR/WriteControlBlock.v" \
  "$RTL_DIR/ReadControlBlock.v" \
  "$RTL_DIR/CircularWriteCounter.v" \
  "$RTL_DIR/CircularReadCounter.v" \
  "$RTL_DIR/CircularFIFO.v" \
  $DUT_V]

set uniquify_naming_style "${REF}_%s_%d"
elaborate $REF -work WORK
current_design $REF
uniquify
link
check_design > "$REPORT_DIR/check_design_pre.rpt"

set path_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]
set selector_dual_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]
set path_pre_count [sizeof_collection $path_pre]
set selector_dual_pre_count [sizeof_collection $selector_dual_pre]
if {$path_pre_count != $expected_path_latches || $selector_dual_pre_count != 0} {
  puts "CMR_HIER_CHILD_DC_FAIL path_latch_pre ref=$REF clear=$path_pre_count expected=$expected_path_latches dual=$selector_dual_pre_count"
  exit 2
}
set_dont_touch $path_pre true
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
check_design > "$REPORT_DIR/check_design_post.rpt"

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
for {set i 0} {$i < 32} {incr i} {
  if {[sizeof_collection [get_cells -quiet InputPortModules_$i]] == 1} {
    incr ipm_count
  }
  if {[sizeof_collection [get_cells -quiet OutputPortModules_$i]] == 1} {
    incr opm_count
  }
}
puts "CMR_HIER_CHILD_PORTS ref=$REF ipm=$ipm_count opm=$opm_count expected=$expected_ports"
if {$ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_HIER_CHILD_DC_WARN ports ref=$REF ipm=$ipm_count opm=$opm_count expected=$expected_ports"
}

write -hierarchy -format ddc -output "$OUTPUT_DIR/${REF}.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/${REF}_post.v"
write_sdf "$OUTPUT_DIR/${REF}.sdf"
exec sha256sum "$OUTPUT_DIR/${REF}.ddc" "$OUTPUT_DIR/${REF}_post.v" "$OUTPUT_DIR/${REF}.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_HIER_CHILD_DC_PASS ref=$REF output=$OUTPUT_DIR ipm=$ipm_count adapters=$expected_adapters"
quit
