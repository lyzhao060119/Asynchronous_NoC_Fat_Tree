# Link-only top: instantiate compiled unique CMRRouter* DDC, do not recompile them.
# Writes the same post.v / MAXIMUM SDF names the 64-core GLS shells already bind.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_HIER_STITCH_RUN_ID)
set TOP $::env(CMR_HIER_TOP)
set RTL_DIR "$PROJECT_DIR/rtl"
set DUT_V $::env(CMR_HIER_DUT_V)
set CHILD_LIST $::env(CMR_HIER_CHILD_LIST)
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_hier_stitch_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_routers 21
if {[info exists ::env(CMR_EXPECTED_ROUTERS)] && $::env(CMR_EXPECTED_ROUTERS) ne ""} {
  set expected_routers $::env(CMR_EXPECTED_ROUTERS)
}
set expected_ports 105
if {[info exists ::env(CMR_EXPECTED_PORTS)] && $::env(CMR_EXPECTED_PORTS) ne ""} {
  set expected_ports $::env(CMR_EXPECTED_PORTS)
}
set expected_adapters 0
if {[info exists ::env(CMR_EXPECTED_ADAPTERS)] && $::env(CMR_EXPECTED_ADAPTERS) ne ""} {
  set expected_adapters $::env(CMR_EXPECTED_ADAPTERS)
}
set expected_fifos 0
if {[info exists ::env(CMR_EXPECTED_FIFOS)] && $::env(CMR_EXPECTED_FIFOS) ne ""} {
  set expected_fifos $::env(CMR_EXPECTED_FIFOS)
}
set pass_token "CMR_NOC64_DC_PASS"
set fail_token "CMR_NOC64_DC_FAIL"
set out_v "${TOP}_post.v"
set out_sdf "${TOP}.sdf"
set out_ddc "${TOP}.ddc"
if {$TOP eq "CMRMeshNoC"} {
  if {![info exists ::env(CMR_NETWORK_NODES)] || $::env(CMR_NETWORK_NODES) eq "64"} {
    set pass_token "CMR_MESH64_DC_PASS"
    set fail_token "CMR_MESH64_DC_FAIL"
  } else {
    set pass_token "CMR_NETWORK_DC_PASS"
    set fail_token "CMR_NETWORK_DC_FAIL"
  }
} elseif {$TOP eq "NoC_256nodes" || $TOP eq "NoC_1024nodes"} {
  set pass_token "CMR_NETWORK_DC_PASS"
  set fail_token "CMR_NETWORK_DC_FAIL"
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

foreach pair [split $CHILD_LIST ","] {
  if {$pair eq ""} { continue }
  set bits [split $pair ":"]
  set cid [lindex $bits 0]
  set ref [lindex $bits 1]
  set ddc "$PROJECT_DIR/outputs/$cid/${ref}.ddc"
  if {![file exists $ddc]} {
    puts "$fail_token missing_child_ddc $ddc"
    exit 2
  }
  catch { remove_design -designs $ref }
  read_ddc $ddc
  puts "CMR_HIER_STITCH_LINK ref=$ref ddc=$ddc"
}

elaborate $TOP -work WORK
current_design $TOP
set router_ds [get_designs -quiet CMRRouter*]
if {[sizeof_collection $router_ds] > 0} {
  set_dont_touch $router_ds true
}
set router_cells [get_cells -hierarchical -quiet -filter {ref_name =~ CMRRouter*}]
if {[sizeof_collection $router_cells] > 0} {
  set_dont_touch $router_cells true
}
link
check_design > "$REPORT_DIR/check_design_pre.rpt"

source "$RTL_DIR/async_primitives.tcl"
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design_post.rpt"

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]
if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "$fail_token unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}

set router_count [sizeof_collection [get_cells -quiet -filter {ref_name =~ CMRRouter*}]]
set ipm_count 0
set opm_count 0
for {set i 0} {$i < 32} {incr i} {
  incr ipm_count [sizeof_collection [get_cells -hierarchical -quiet InputPortModules_$i]]
  incr opm_count [sizeof_collection [get_cells -hierarchical -quiet OutputPortModules_$i]]
}
puts "CMR_HIER_STITCH_COUNTS router=$router_count expected_r=$expected_routers ipm=$ipm_count opm=$opm_count expected_p=$expected_ports"
if {$ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "$fail_token stitch_structure router=$router_count expected_r=$expected_routers ipm=$ipm_count opm=$opm_count expected_p=$expected_ports"
  exit 2
}
if {$router_count != $expected_routers} {
  puts "CMR_HIER_STITCH_WARN router_count=$router_count expected=$expected_routers (uniquify prefixes; IPM/OPM matched)"
}

write -hierarchy -format ddc -output "$OUTPUT_DIR/$out_ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/$out_v"
write_sdf "$OUTPUT_DIR/$out_sdf"
exec sha256sum "$OUTPUT_DIR/$out_ddc" "$OUTPUT_DIR/$out_v" "$OUTPUT_DIR/$out_sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "$pass_token output=$OUTPUT_DIR top=$TOP routers=$router_count ipm=$ipm_count adapters=$expected_adapters fifos=$expected_fifos"
quit
