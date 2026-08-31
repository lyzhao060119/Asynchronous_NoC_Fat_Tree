# CMR fat-tree NoC64 DC entry: 16 L1 + 4 L2 + 1 L3.
# Geometry is selected by CMR_FAT_LANE_PROFILE (1248 or 1222).
# Default DUT omits inter-level FIFOs (bypass).
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_NOC64_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set DUT_V "$RTL_DIR/NoC_64nodes.v"
if {[info exists ::env(CMR_NOC64_DUT_V)] && $::env(CMR_NOC64_DUT_V) ne ""} {
  set DUT_V $::env(CMR_NOC64_DUT_V)
}
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_ft_noc64_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_routers 21
set expected_fifos 0
if {[info exists ::env(CMR_BYPASS_INTERLEVEL_FIFO)] && $::env(CMR_BYPASS_INTERLEVEL_FIFO) eq "0"} {
  if {[info exists ::env(CMR_EXPECTED_FIFOS)] && $::env(CMR_EXPECTED_FIFOS) ne ""} {
    set expected_fifos $::env(CMR_EXPECTED_FIFOS)
  } else {
    set expected_fifos 96
  }
}
set expected_ports 168
if {[info exists ::env(CMR_EXPECTED_PORTS)] && $::env(CMR_EXPECTED_PORTS) ne ""} {
  set expected_ports $::env(CMR_EXPECTED_PORTS)
}
set expected_path_latches [expr {4 * $expected_ports}]
set expected_routesel_and [expr {4 * $expected_ports}]
set lane01_stages 0
if {[info exists ::env(CMR_LANE01_BUF_STAGES)] && $::env(CMR_LANE01_BUF_STAGES) ne ""} {
  set lane01_stages $::env(CMR_LANE01_BUF_STAGES)
}
set expected_adapters [expr {[info exists ::env(CMR_EXPECTED_ADAPTERS)] ? $::env(CMR_EXPECTED_ADAPTERS) : 352}]
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

proc cmr_circular_fifo_count {} {
  set wcb [get_cells -hierarchical -quiet -filter {ref_name =~ WriteControlBlock*}]
  set n [sizeof_collection $wcb]
  if {$n == 0} {
    return 0
  }
  if {[expr {$n % 4}] != 0} {
    puts "CMR_NOC64_DC_FAIL circular_wcb_alignment wcb=$n"
    exit 2
  }
  return [expr {$n / 4}]
}

proc cmr_ft_lib_cell {name} {
  set lib [get_lib_cells -quiet */$name]
  if {[sizeof_collection $lib] == 0} {
    return ""
  }
  return [get_object_name [index_collection $lib 0]]
}

proc cmr_ft_delay_glob {unit} {
  switch -- $unit {
    50  { return "DEL050D1*" }
    75  { return "DEL075D1*" }
    100 { return "DEL100D1*" }
    150 { return "DEL150D1*" }
    250 { return "DEL250D1*" }
    default {
      puts "CMR_NOC64_DC_FAIL delay_unit $unit"
      exit 2
    }
  }
}

proc cmr_ft_matched_leaves {unit} {
  set glob [cmr_ft_delay_glob $unit]
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *MatchedDelay*"]
}

proc cmr_ft_ackin_leaves {unit} {
  set glob [cmr_ft_delay_glob $unit]
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *AckinDelay*"]
}

proc cmr_ft_acklatch_e_pins {} {
  set pins [get_pins -hierarchical -quiet -filter {full_name =~ *AckLatch*latch_cell/E}]
  set offset [get_pins -hierarchical -quiet -filter {full_name =~ *OffsetLatch*latch_cell/E}]
  if {[sizeof_collection $offset] > 0} {
    set pins [remove_from_collection $pins $offset]
  }
  return $pins
}

proc cmr_ft_insert_lane01_bufs {nbuf expected_adapters} {
  if {$nbuf < 1} {
    puts "CMR_LANE01_ACKLATCH_BUF skipped stages=0"
    return
  }
  set lib_name [cmr_ft_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC64_DC_FAIL lane01_missing_buffd0"
    exit 2
  }
  set pins [cmr_ft_acklatch_e_pins]
  set n [sizeof_collection $pins]
  if {$n != $expected_adapters} {
    puts "CMR_NOC64_DC_FAIL lane01_acklatch_e_count actual=$n expected=$expected_adapters"
    exit 2
  }
  set pin_names {}
  foreach_in_collection p $pins {
    lappend pin_names [get_object_name $p]
  }
  set latch_cells [get_cells -of_objects $pins]
  if {[sizeof_collection $latch_cells] > 0} {
    set_dont_touch $latch_cells false
  }
  set inserted 0
  for {set stage 1} {$stage <= $nbuf} {incr stage} {
    foreach pin_name $pin_names {
      set pin [get_pins -quiet $pin_name]
      if {[sizeof_collection $pin] != 1} {
        puts "CMR_NOC64_DC_FAIL lane01_buf_pin $pin_name"
        exit 2
      }
      if {[catch {insert_buffer $pin $lib_name -new_cell_names lane01_acklatch_e_buf_s${stage}} err]} {
        puts "CMR_NOC64_DC_FAIL lane01_buf_insert stage=$stage pin=$pin_name error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *lane01_acklatch_e_buf_s*}]
  set expected [expr {$expected_adapters * $nbuf}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC64_DC_FAIL lane01_buf_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  if {[sizeof_collection $latch_cells] > 0} {
    set_dont_touch $latch_cells true
  }
  puts "CMR_LANE01_ACKLATCH_BUF inserts=$inserted stages=$nbuf adapters=$n lib=$lib_name"
}

proc cmr_ft_insert_cfifo_hs02 {} {
  global expected_fifos
  set circular [cmr_circular_fifo_count]
  if {$circular == 0} {
    puts "CMR_CFIFO_HS02 disabled (no CircularFIFO)"
    return
  }
  if {$circular != $expected_fifos} {
    puts "CMR_NOC64_DC_FAIL cfifo_hs02_fifo_count actual=$circular expected=$expected_fifos"
    exit 2
  }
  set targets [get_pins -hierarchical -quiet -filter {full_name =~ *read_counter/U10/A1}]
  if {[sizeof_collection $targets] != $circular} {
    puts "CMR_NOC64_DC_FAIL cfifo_hs02_bind actual=[sizeof_collection $targets] expected=$circular"
    exit 2
  }
  set lib_name [cmr_ft_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC64_DC_FAIL cfifo_hs02_missing_buffd0"
    exit 2
  }
  set inserted 0
  for {set stage 1} {$stage <= 3} {incr stage} {
    foreach_in_collection target $targets {
      if {[catch {insert_buffer $target $lib_name -new_cell_names cfifo_hs02_ack_counter_buf_s${stage}} err]} {
        puts "CMR_NOC64_DC_FAIL cfifo_hs02_insert stage=$stage pin=[get_object_name $target] error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_hs02_ack_counter_buf_s*}]
  set expected [expr {$circular * 3}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC64_DC_FAIL cfifo_hs02_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  puts "CMR_CFIFO_HS02 buffers=[sizeof_collection $cells] stages=3 fifos=$circular lib=$lib_name"
}

proc cmr_ft_cfifo_reqout_xor_pins {} {
  set reqouts [get_pins -hierarchical -quiet -filter {full_name =~ */bb/Reqout}]
  set pins ""
  foreach_in_collection rp $reqouts {
    set nets [get_nets -quiet -of_objects $rp]
    if {[sizeof_collection $nets] == 0} {
      continue
    }
    set net_pins [get_pins -quiet -of_objects $nets]
    foreach_in_collection np $net_pins {
      if {[get_attribute -quiet $np pin_direction] ne "out"} {
        continue
      }
      set cell [get_cells -quiet -of_objects $np]
      if {[sizeof_collection $cell] == 0} {
        continue
      }
      set ins [get_pins -quiet -of_objects $cell -filter {name =~ A*}]
      if {$pins eq ""} {
        set pins $ins
      } else {
        append_to_collection pins $ins
      }
    }
  }
  return $pins
}

proc cmr_ft_insert_cfifo_rd01 {} {
  global CMR_FT_RD01_EXPECTED
  set circular [cmr_circular_fifo_count]
  if {$circular == 0} {
    puts "CMR_CFIFO_RD01 disabled (no CircularFIFO)"
    set CMR_FT_RD01_EXPECTED 0
    return
  }
  set reqouts [get_pins -hierarchical -quiet -filter {full_name =~ */bb/Reqout}]
  if {[sizeof_collection $reqouts] != $circular} {
    puts "CMR_NOC64_DC_FAIL cfifo_rd01_reqout_count actual=[sizeof_collection $reqouts] expected=$circular"
    exit 2
  }
  # XOR4 maps to U2/A* (4 per FIFO). En=WriteEnable can make DC emit an XOR2
  # tree; then bind the last gate driving bb/Reqout (2 per FIFO). Either
  # mapping still gets 16 buffer stages on every Reqout path.
  set named [get_pins -hierarchical -quiet -filter {full_name =~ *bb/U2/A*}]
  set mapped [cmr_ft_cfifo_reqout_xor_pins]
  set n_named [sizeof_collection $named]
  set n_mapped [expr {$mapped eq "" ? 0 : [sizeof_collection $mapped]}]
  set n4 [expr {$circular * 4}]
  set n2 [expr {$circular * 2}]
  if {$n_named == $n4} {
    set targets $named
  } elseif {$n_mapped == $n4 || $n_mapped == $n2} {
    set targets $mapped
  } else {
    puts "CMR_NOC64_DC_FAIL cfifo_rd01_xor_bind named_u2=$n_named reqout_xor=$n_mapped expected=$n4 or $n2"
    exit 2
  }
  set expected_targets [sizeof_collection $targets]
  puts "CMR_CFIFO_RD01_BIND pins=$expected_targets named_u2=$n_named reqout_xor=$n_mapped"
  set lib_name [cmr_ft_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC64_DC_FAIL cfifo_rd01_missing_buffd0"
    exit 2
  }
  set stages 16
  set inserted 0
  for {set stage 1} {$stage <= $stages} {incr stage} {
    foreach_in_collection target $targets {
      if {[catch {insert_buffer $target $lib_name -new_cell_names cfifo_rd01_reqout_buf_s${stage}} err]} {
        puts "CMR_NOC64_DC_FAIL cfifo_rd01_insert stage=$stage pin=[get_object_name $target] error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_rd01_reqout_buf_s*}]
  set expected [expr {$expected_targets * $stages}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC64_DC_FAIL cfifo_rd01_buffer_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  set CMR_FT_RD01_EXPECTED $expected
  puts "CMR_CFIFO_RD01_ECO buffers=[sizeof_collection $cells] stages=$stages fifos=$circular pins=$expected_targets lib=$lib_name"
}

elaborate NoC_64nodes -work WORK
current_design NoC_64nodes
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
puts "CMR_NOC64_LATCH_PRE CLEAR=$clear_pre_count SET=$set_pre_count SR=$sr_pre_count PATH_CLEAR=$path_pre_count PATH_DUAL=$selector_dual_pre_count"
if {$path_pre_count != $expected_path_latches || $selector_dual_pre_count != 0 || $clear_pre_count == 0 || $set_pre_count == 0} {
  puts "CMR_NOC64_DC_FAIL latch_pre_structure path_clear=$path_pre_count expected=$expected_path_latches path_dual=$selector_dual_pre_count clear=$clear_pre_count set=$set_pre_count"
  exit 2
}
set_dont_touch $clear_pre true
set_dont_touch $set_pre true

source "$RTL_DIR/async_primitives.tcl"
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
cmr_ft_insert_lane01_bufs $lane01_stages $expected_adapters
cmr_ft_insert_cfifo_hs02
cmr_ft_insert_cfifo_rd01
compile_ultra -incremental -no_autoungroup
check_design > "$REPORT_DIR/check_design_post.rpt"

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]

set router_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ CMRRouter*}]]
set async_fifo_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ AsyncFifo*}]]
set circular_fifo_count [cmr_circular_fifo_count]
set fifo_count [expr {$async_fifo_count + $circular_fifo_count}]
set ipm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ IPM*}]]
set opm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ OPM* && ref_name !~ OPMSelector*}]]
set mutex4_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex4*}]]
set mutex2_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex2*}]]
set clear_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]]
set set_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]]
set sr_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCSNDQD*}]]
set path_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]]
set selector_dual_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]]
set close_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ V2CloseEvent* || full_name =~ *RegClose*}]]
set handshake_complete_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ HandshakeComplete*}]]
set routesel_and_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ RouteSelAnd2*}]]
set routesel_an2_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *RouteSelAnd* && ref_name =~ AN2D0BWP12T30P140}]]
set adapter_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]]
set acklatch_e_count [sizeof_collection [cmr_ft_acklatch_e_pins]]
set lane01_buf [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *lane01_acklatch_e_buf_s*}]]
set cfifo_hs02_buf [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_hs02_ack_counter_buf_s*}]]
set cfifo_rd01_buf [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_rd01_reqout_buf_s*}]]
set del050_rcu [sizeof_collection [cmr_ft_matched_leaves 50]]
set del075_rcu [sizeof_collection [cmr_ft_matched_leaves 75]]
set del100_rcu [sizeof_collection [cmr_ft_matched_leaves 100]]
set del150_rcu [sizeof_collection [cmr_ft_matched_leaves 150]]
set ackin_count [sizeof_collection [cmr_ft_ackin_leaves $opm_ackin_unit_ps]]
set ackin_del250 [sizeof_collection [cmr_ft_ackin_leaves 250]]
set fifo_del150 [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL150D1* && full_name =~ *outReqDelay*}]]

set fd [open "$REPORT_DIR/cmr_fat_tree_noc64_structure.rpt" w]
puts $fd "ROUTER_COUNT=$router_count"
puts $fd "INTERLEVEL_FIFO_COUNT=$fifo_count"
puts $fd "ASYNC_FIFO_COUNT=$async_fifo_count"
puts $fd "CIRCULAR_FIFO_COUNT=$circular_fifo_count"
puts $fd "IPM_COUNT=$ipm_count"
puts $fd "OPM_COUNT=$opm_count"
puts $fd "MUTEX4_COUNT=$mutex4_count"
puts $fd "MUTEX2_COUNT=$mutex2_count"
puts $fd "RESET_LATCH_COUNT=$clear_count"
puts $fd "SET_RESET_LATCH_COUNT=$set_count"
puts $fd "SR_LATCH_COUNT=$sr_count"
puts $fd "PATH_LATCH_CLEAR_COUNT=$path_count"
puts $fd "PATH_LATCH_DUAL_COUNT=$selector_dual_count"
puts $fd "V2_CLOSE_EVENT_COUNT=$close_count"
puts $fd "HANDSHAKE_COMPLETE_COUNT=$handshake_complete_count"
puts $fd "ROUTESEL_AND2_COUNT=$routesel_and_count"
puts $fd "ROUTESEL_AN2D0_COUNT=$routesel_an2_count"
puts $fd "ADAPTER_COUNT=$adapter_count"
puts $fd "ACKLATCH_E_COUNT=$acklatch_e_count"
puts $fd "LANE01_ACKLATCH_BUF_COUNT=$lane01_buf"
puts $fd "LANE01_BUF_STAGES=$lane01_stages"
puts $fd "CFIFO_HS02_BUF_COUNT=$cfifo_hs02_buf"
puts $fd "CFIFO_RD01_BUF_COUNT=$cfifo_rd01_buf"
puts $fd "RCU_DEL050_COUNT=$del050_rcu"
puts $fd "RCU_DEL075_COUNT=$del075_rcu"
puts $fd "RCU_DEL100_COUNT=$del100_rcu"
puts $fd "RCU_DEL150_COUNT=$del150_rcu"
puts $fd "RCU_MATCHED_DELAY_UNIT_PS=$rcu_unit_ps"
puts $fd "RCU_MATCHED_DELAY_STEPS=$rcu_steps"
puts $fd "OPM_ACKIN_DELAY_COUNT=$ackin_count"
puts $fd "OPM_ACKIN_DELAY_UNIT_PS=$opm_ackin_unit_ps"
puts $fd "OPM_ACKIN_DEL250_COUNT=$ackin_del250"
puts $fd "FIFO_OUTREQ_DEL150_COUNT=$fifo_del150"
close $fd
puts "CMR_NOC64_STRUCTURE ROUTER=$router_count FIFO=$fifo_count ASYNC_FIFO=$async_fifo_count CIRCULAR_FIFO=$circular_fifo_count IPM=$ipm_count OPM=$opm_count ADAPTER=$adapter_count ACKLATCH_E=$acklatch_e_count LANE01_BUF=$lane01_buf stages=$lane01_stages MUTEX4=$mutex4_count MUTEX2=$mutex2_count CLEAR=$clear_count SET=$set_count SR=$sr_count CLOSE=$close_count COMPLETE=$handshake_complete_count ROUTESEL_AND2=$routesel_and_count ROUTESEL_AN2D0=$routesel_an2_count DEL050=$del050_rcu ACKIN=$ackin_count ACKIN_UNIT=$opm_ackin_unit_ps ACKIN250=$ackin_del250 HS02=$cfifo_hs02_buf RD01=$cfifo_rd01_buf FIFO_OUTREQ_DEL150=$fifo_del150"

if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_NOC64_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}
if {$router_count != $expected_routers || $fifo_count != $expected_fifos || $ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_NOC64_DC_FAIL router_or_fifo_structure router=$router_count fifo=$fifo_count ipm=$ipm_count opm=$opm_count"
  exit 2
}
if {$clear_count != $clear_pre_count || $set_count != $set_pre_count || $path_count != $expected_path_latches || $selector_dual_count != 0 || $close_count == 0} {
  puts "CMR_NOC64_DC_FAIL async_storage_structure clear=$clear_count expected_clear=$clear_pre_count set=$set_count expected_set=$set_pre_count path_clear=$path_count expected_path=$expected_path_latches path_dual=$selector_dual_count close=$close_count"
  exit 2
}
if {$handshake_complete_count != 0} {
  puts "CMR_NOC64_DC_FAIL obsolete_handshake_complete actual=$handshake_complete_count expected=0"
  exit 2
}
if {$routesel_and_count != $expected_routesel_and || $routesel_an2_count != $expected_routesel_and} {
  puts "CMR_NOC64_DC_FAIL routesel_and2_structure hier=$routesel_and_count an2=$routesel_an2_count expected=$expected_routesel_and"
  exit 2
}
if {![async_mutex2_drive_mismatch_ok]} {
  puts "CMR_NOC64_DC_FAIL mutex2_nand_drive_mismatch"
  exit 2
}
if {$acklatch_e_count != $expected_adapters} {
  puts "CMR_NOC64_DC_FAIL acklatch_e_count actual=$acklatch_e_count expected=$expected_adapters"
  exit 2
}
set expected_lane01_buf [expr {$expected_adapters * $lane01_stages}]
if {$lane01_buf != $expected_lane01_buf} {
  puts "CMR_NOC64_DC_FAIL lane01_acklatch_buf actual=$lane01_buf expected=$expected_lane01_buf stages=$lane01_stages"
  exit 2
}
if {$rcu_steps == 1 && $rcu_unit_ps == 50} {
  if {$del050_rcu != $expected_ports || $del075_rcu != 0 || $del100_rcu != 0 || $del150_rcu != 0} {
    puts "CMR_NOC64_DC_FAIL rcu_matched_unit DEL050=$del050_rcu expected=$expected_ports DEL075=$del075_rcu DEL100=$del100_rcu DEL150=$del150_rcu"
    exit 2
  }
}
if {$ackin_count != $expected_ports} {
  puts "CMR_NOC64_DC_FAIL opm_ackin_delay actual=$ackin_count expected=$expected_ports unit=$opm_ackin_unit_ps"
  exit 2
}
if {$opm_ackin_unit_ps != 250 && $ackin_del250 != 0} {
  puts "CMR_NOC64_DC_FAIL leftover_ackin_del250 actual=$ackin_del250"
  exit 2
}
if {$expected_fifos == 0} {
  if {$circular_fifo_count != 0 || $async_fifo_count != 0 || $cfifo_hs02_buf != 0 || $cfifo_rd01_buf != 0 || $fifo_del150 != 0} {
    puts "CMR_NOC64_DC_FAIL unexpected_fifo_on_bypass circular=$circular_fifo_count async=$async_fifo_count HS02=$cfifo_hs02_buf RD01=$cfifo_rd01_buf FIFO_DEL150=$fifo_del150"
    exit 2
  }
  puts "CMR_NOC64_BYPASS_INTERLEVEL_FIFO fifos=0"
} elseif {$circular_fifo_count == $expected_fifos} {
  set expected_hs02 [expr {$circular_fifo_count * 3}]
  if {![info exists CMR_FT_RD01_EXPECTED]} {
    set CMR_FT_RD01_EXPECTED [expr {$circular_fifo_count * 4 * 16}]
  }
  if {$cfifo_hs02_buf != $expected_hs02} {
    puts "CMR_NOC64_DC_FAIL cfifo_hs02_buf actual=$cfifo_hs02_buf expected=$expected_hs02"
    exit 2
  }
  if {$cfifo_rd01_buf != $CMR_FT_RD01_EXPECTED} {
    puts "CMR_NOC64_DC_FAIL cfifo_rd01_buf actual=$cfifo_rd01_buf expected=$CMR_FT_RD01_EXPECTED"
    exit 2
  }
  if {$fifo_del150 != 0} {
    puts "CMR_NOC64_DC_FAIL unexpected_acg_outreq_on_circular actual=$fifo_del150"
    exit 2
  }
} elseif {$async_fifo_count == $expected_fifos} {
  set expected_outreq [expr {$expected_fifos * 3}]
  if {$circular_fifo_count != 0} {
    puts "CMR_NOC64_DC_FAIL mixed_fifo_kind circular=$circular_fifo_count async=$async_fifo_count"
    exit 2
  }
  if {$fifo_del150 != $expected_outreq} {
    puts "CMR_NOC64_DC_FAIL fifo_outreq_del150 actual=$fifo_del150 expected=$expected_outreq"
    exit 2
  }
  if {$cfifo_hs02_buf != 0 || $cfifo_rd01_buf != 0} {
    puts "CMR_NOC64_DC_FAIL unexpected_cfifo_eco_on_acg HS02=$cfifo_hs02_buf RD01=$cfifo_rd01_buf"
    exit 2
  }
  puts "CMR_FIFO_01 outReqDelay DEL150=$fifo_del150 stages=3 fifos=$async_fifo_count"
} else {
  puts "CMR_NOC64_DC_FAIL fifo_kind circular=$circular_fifo_count async=$async_fifo_count expected=$expected_fifos"
  exit 2
}

async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/NoC_64nodes.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/NoC_64nodes_post.v"
write_sdf "$OUTPUT_DIR/NoC_64nodes.sdf"
write_sdc "$OUTPUT_DIR/NoC_64nodes.sdc"
exec sha256sum "$OUTPUT_DIR/NoC_64nodes.ddc" "$OUTPUT_DIR/NoC_64nodes_post.v" "$OUTPUT_DIR/NoC_64nodes.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_NOC64_DC_PASS output=$OUTPUT_DIR"
quit
