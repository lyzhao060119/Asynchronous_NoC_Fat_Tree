# CMR 8x8 mesh NoC64 DC: 64 Thin (1,1) routers, no top ports, no FIFOs.
# Locked hop delay: RCU 1xDEL050, matched buf=0, Ackin 1xDEL050.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_MESH64_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set DUT_V "$RTL_DIR/CMRMeshNoC.v"
if {[info exists ::env(CMR_MESH64_DUT_V)] && $::env(CMR_MESH64_DUT_V) ne ""} {
  set DUT_V $::env(CMR_MESH64_DUT_V)
}
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_mesh64_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_routers 64
if {[info exists ::env(CMR_EXPECTED_ROUTERS)] && $::env(CMR_EXPECTED_ROUTERS) ne ""} {
  set expected_routers $::env(CMR_EXPECTED_ROUTERS)
}
set expected_ports 320
if {[info exists ::env(CMR_EXPECTED_PORTS)] && $::env(CMR_EXPECTED_PORTS) ne ""} {
  set expected_ports $::env(CMR_EXPECTED_PORTS)
}
set expected_path_latches [expr {4 * $expected_ports}]
set expected_routesel_and [expr {4 * $expected_ports}]
set expected_adapters 0
if {[info exists ::env(CMR_EXPECTED_ADAPTERS)] && $::env(CMR_EXPECTED_ADAPTERS) ne ""} {
  set expected_adapters $::env(CMR_EXPECTED_ADAPTERS)
}
set rcu_unit_ps 50
if {[info exists ::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)] && $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS) ne ""} {
  set rcu_unit_ps $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)
}
set rcu_steps 1
if {[info exists ::env(CMR_RCU_MATCHED_DELAY_STEPS)] && $::env(CMR_RCU_MATCHED_DELAY_STEPS) ne ""} {
  set rcu_steps $::env(CMR_RCU_MATCHED_DELAY_STEPS)
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
  "$RTL_DIR/WriteControlUnit.v" \
  "$RTL_DIR/WriteCounter.v" \
  "$RTL_DIR/WriteAckGenerator.v" \
  "$RTL_DIR/ReadControlUnit.v" \
  "$RTL_DIR/ReadCounter.v" \
  "$RTL_DIR/ReadRequestGenerator.v" \
  "$RTL_DIR/ReadPhaseSelector.v" \
  "$RTL_DIR/ReadAckGenerator.v" \
  $DUT_V]

proc cmr_mesh_lib_cell {name} {
  set lib [get_lib_cells -quiet */$name]
  if {[sizeof_collection $lib] == 0} {
    return ""
  }
  return [get_object_name [index_collection $lib 0]]
}

proc cmr_mesh_delay_glob {unit} {
  switch -- $unit {
    50  { return "DEL050D1*" }
    75  { return "DEL075D1*" }
    100 { return "DEL100D1*" }
    150 { return "DEL150D1*" }
    250 { return "DEL250D1*" }
    default {
      puts "CMR_MESH64_DC_FAIL delay_unit $unit"
      exit 2
    }
  }
}

proc cmr_mesh_matched_leaves {unit} {
  set glob [cmr_mesh_delay_glob $unit]
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *MatchedDelay*"]
}

proc cmr_mesh_ackin_leaves {unit} {
  set glob [cmr_mesh_delay_glob $unit]
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *AckinDelay*"]
}

elaborate CMRMeshNoC -work WORK
current_design CMRMeshNoC
uniquify
link
check_design > "$REPORT_DIR/check_design_pre.rpt"

set sr_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCSNDQD*}]
set clear_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set set_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]
set sr_pre_count [sizeof_collection $sr_pre]
set clear_pre_count [sizeof_collection $clear_pre]
set set_pre_count [sizeof_collection $set_pre]
set path_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]
set selector_dual_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]
set path_pre_count [sizeof_collection $path_pre]
set selector_dual_pre_count [sizeof_collection $selector_dual_pre]
puts "CMR_MESH64_LATCH_PRE CLEAR=$clear_pre_count SET=$set_pre_count SR=$sr_pre_count PATH_CLEAR=$path_pre_count PATH_DUAL=$selector_dual_pre_count"
if {$path_pre_count != $expected_path_latches || $selector_dual_pre_count != 0 || $clear_pre_count == 0 || $set_pre_count == 0} {
  puts "CMR_MESH64_DC_FAIL latch_pre_structure path_clear=$path_pre_count expected=$expected_path_latches path_dual=$selector_dual_pre_count clear=$clear_pre_count set=$set_pre_count"
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

set router_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ CMRRouter*}]]
set async_fifo_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ AsyncFifo*}]]
set ipm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ IPM*}]]
set opm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ OPM* && ref_name !~ OPMSelector*}]]
set mutex4_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex4*}]]
set mutex2_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex2*}]]
set clear_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]]
set set_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]]
set path_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]]
set selector_dual_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]]
set close_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ V2CloseEvent* || full_name =~ *RegClose*}]]
set handshake_complete_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ HandshakeComplete*}]]
set routesel_and_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ RouteSelAnd2*}]]
set routesel_an2_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *RouteSelAnd* && ref_name =~ AN2D0BWP12T30P140}]]
set adapter_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]]
set del050_rcu [sizeof_collection [cmr_mesh_matched_leaves 50]]
set del075_rcu [sizeof_collection [cmr_mesh_matched_leaves 75]]
set del100_rcu [sizeof_collection [cmr_mesh_matched_leaves 100]]
set del150_rcu [sizeof_collection [cmr_mesh_matched_leaves 150]]
set ackin_count [sizeof_collection [cmr_mesh_ackin_leaves $opm_ackin_unit_ps]]
set ackin_del250 [sizeof_collection [cmr_mesh_ackin_leaves 250]]
set top_ports [sizeof_collection [get_ports -quiet io_top_input*]]

set fd [open "$REPORT_DIR/cmr_mesh64_structure.rpt" w]
puts $fd "ROUTER_COUNT=$router_count"
puts $fd "ASYNC_FIFO_COUNT=$async_fifo_count"
puts $fd "IPM_COUNT=$ipm_count"
puts $fd "OPM_COUNT=$opm_count"
puts $fd "MUTEX4_COUNT=$mutex4_count"
puts $fd "MUTEX2_COUNT=$mutex2_count"
puts $fd "RESET_LATCH_COUNT=$clear_count"
puts $fd "SET_RESET_LATCH_COUNT=$set_count"
puts $fd "PATH_LATCH_CLEAR_COUNT=$path_count"
puts $fd "PATH_LATCH_DUAL_COUNT=$selector_dual_count"
puts $fd "V2_CLOSE_EVENT_COUNT=$close_count"
puts $fd "HANDSHAKE_COMPLETE_COUNT=$handshake_complete_count"
puts $fd "ROUTESEL_AND2_COUNT=$routesel_and_count"
puts $fd "ROUTESEL_AN2D0_COUNT=$routesel_an2_count"
puts $fd "ADAPTER_COUNT=$adapter_count"
puts $fd "TOP_PORT_COUNT=$top_ports"
puts $fd "RCU_DEL050_COUNT=$del050_rcu"
puts $fd "RCU_DEL075_COUNT=$del075_rcu"
puts $fd "RCU_DEL100_COUNT=$del100_rcu"
puts $fd "RCU_DEL150_COUNT=$del150_rcu"
puts $fd "RCU_MATCHED_DELAY_UNIT_PS=$rcu_unit_ps"
puts $fd "RCU_MATCHED_DELAY_STEPS=$rcu_steps"
puts $fd "OPM_ACKIN_DELAY_COUNT=$ackin_count"
puts $fd "OPM_ACKIN_DELAY_UNIT_PS=$opm_ackin_unit_ps"
puts $fd "OPM_ACKIN_DEL250_COUNT=$ackin_del250"
close $fd
puts "CMR_MESH64_STRUCTURE ROUTER=$router_count FIFO=$async_fifo_count IPM=$ipm_count OPM=$opm_count ADAPTER=$adapter_count TOP=$top_ports MUTEX4=$mutex4_count MUTEX2=$mutex2_count CLEAR=$clear_count SET=$set_count PATH=$path_count CLOSE=$close_count ROUTESEL_AND2=$routesel_and_count DEL050=$del050_rcu ACKIN=$ackin_count ACKIN_UNIT=$opm_ackin_unit_ps ACKIN250=$ackin_del250"

if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_MESH64_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}
if {$router_count != $expected_routers || $async_fifo_count != 0 || $ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_MESH64_DC_FAIL router_or_port_structure router=$router_count fifo=$async_fifo_count ipm=$ipm_count opm=$opm_count"
  exit 2
}
if {$clear_count != $clear_pre_count || $set_count != $set_pre_count || $path_count != $expected_path_latches || $selector_dual_count != 0 || $close_count == 0} {
  puts "CMR_MESH64_DC_FAIL async_storage_structure clear=$clear_count expected_clear=$clear_pre_count set=$set_count expected_set=$set_pre_count path_clear=$path_count expected_path=$expected_path_latches path_dual=$selector_dual_count close=$close_count"
  exit 2
}
if {$handshake_complete_count != 0} {
  puts "CMR_MESH64_DC_FAIL obsolete_handshake_complete actual=$handshake_complete_count expected=0"
  exit 2
}
if {$routesel_and_count != $expected_routesel_and || $routesel_an2_count != $expected_routesel_and} {
  puts "CMR_MESH64_DC_FAIL routesel_and2_structure hier=$routesel_and_count an2=$routesel_an2_count expected=$expected_routesel_and"
  exit 2
}
if {![async_mutex2_drive_mismatch_ok]} {
  puts "CMR_MESH64_DC_FAIL mutex2_nand_drive_mismatch"
  exit 2
}
if {$adapter_count != $expected_adapters} {
  puts "CMR_MESH64_DC_FAIL adapter_count actual=$adapter_count expected=$expected_adapters"
  exit 2
}
if {$top_ports != 0} {
  puts "CMR_MESH64_DC_FAIL unexpected_top_ports actual=$top_ports"
  exit 2
}
if {$rcu_steps == 1 && $rcu_unit_ps == 50} {
  if {$del050_rcu != $expected_ports || $del075_rcu != 0 || $del100_rcu != 0 || $del150_rcu != 0} {
    puts "CMR_MESH64_DC_FAIL rcu_matched_unit DEL050=$del050_rcu expected=$expected_ports DEL075=$del075_rcu DEL100=$del100_rcu DEL150=$del150_rcu"
    exit 2
  }
}
if {$ackin_count != $expected_ports} {
  puts "CMR_MESH64_DC_FAIL opm_ackin_delay actual=$ackin_count expected=$expected_ports unit=$opm_ackin_unit_ps"
  exit 2
}
if {$opm_ackin_unit_ps != 250 && $ackin_del250 != 0} {
  puts "CMR_MESH64_DC_FAIL leftover_ackin_del250 actual=$ackin_del250"
  exit 2
}

async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/CMRMeshNoC.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/CMRMeshNoC_post.v"
write_sdf "$OUTPUT_DIR/CMRMeshNoC.sdf"
write_sdc "$OUTPUT_DIR/CMRMeshNoC.sdc"
exec sha256sum "$OUTPUT_DIR/CMRMeshNoC.ddc" "$OUTPUT_DIR/CMRMeshNoC_post.v" "$OUTPUT_DIR/CMRMeshNoC.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_MESH64_DC_PASS output=$OUTPUT_DIR"
quit
