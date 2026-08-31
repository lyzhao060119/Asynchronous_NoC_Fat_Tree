# Dedicated CMRRouter DC entry. CMR_REMOTE_ROOT and CMR_RUN_ID are supplied
# by run_remote_cmr_flow.py.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_ports [expr {[info exists ::env(CMR_EXPECTED_PORTS)] ? $::env(CMR_EXPECTED_PORTS) : 5}]
set expected_edges [expr {[info exists ::env(CMR_EXPECTED_EDGES)] ? $::env(CMR_EXPECTED_EDGES) : 20}]
set expected_path_latches [expr {4 * $expected_ports}]
set seed_run ""
if {[info exists ::env(CMR_DC_SEED_RUN_ID)] && $::env(CMR_DC_SEED_RUN_ID) ne ""} {
  set seed_run $::env(CMR_DC_SEED_RUN_ID)
}
set buf_stages 0
if {[info exists ::env(CMR_RCU_MATCHED_BUF_STAGES)] && $::env(CMR_RCU_MATCHED_BUF_STAGES) ne ""} {
  set buf_stages $::env(CMR_RCU_MATCHED_BUF_STAGES)
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
set opm_ackin_steps 1
if {[info exists ::env(CMR_OPM_ACKIN_DELAY_STEPS)] && $::env(CMR_OPM_ACKIN_DELAY_STEPS) ne ""} {
  set opm_ackin_steps $::env(CMR_OPM_ACKIN_DELAY_STEPS)
}
set ackin_use_buf 0
if {[info exists ::env(CMR_OPM_ACKIN_USE_BUF)] && $::env(CMR_OPM_ACKIN_USE_BUF) eq "1"} {
  set ackin_use_buf 1
}
set lane01_stages 0
if {[info exists ::env(CMR_LANE01_BUF_STAGES)] && $::env(CMR_LANE01_BUF_STAGES) ne ""} {
  set lane01_stages $::env(CMR_LANE01_BUF_STAGES)
}
set expected_adapters [expr {[info exists ::env(CMR_EXPECTED_ADAPTERS)] ? $::env(CMR_EXPECTED_ADAPTERS) : 0}]
if {$rcu_steps == 0 && $buf_stages > 0} {
  puts "CMR_DC_FAIL rcu_buf_without_matched_delay steps=$rcu_steps buf=$buf_stages"
  exit 2
}

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB

proc cmr_router_lib_cell {name} {
  set lib [get_lib_cells -quiet */$name]
  if {[sizeof_collection $lib] == 0} {
    return ""
  }
  return [get_object_name [index_collection $lib 0]]
}

proc cmr_router_matched_leaf_glob {unit} {
  switch -- $unit {
    50  { return "DEL050D1*" }
    75  { return "DEL075D1*" }
    100 { return "DEL100D1*" }
    150 { return "DEL150D1*" }
    250 { return "DEL250D1*" }
    default {
      puts "CMR_DC_FAIL rcu_matched_unit $unit"
      exit 2
    }
  }
}

proc cmr_router_matched_leaves {unit} {
  set glob [cmr_router_matched_leaf_glob $unit]
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *MatchedDelay*"]
}

proc cmr_router_insert_matched_bufs {nbuf expected_ports unit} {
  set lib_name [cmr_router_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_DC_FAIL rcu_matched_missing_buffd0"
    exit 2
  }
  set leaves [cmr_router_matched_leaves $unit]
  set n [sizeof_collection $leaves]
  if {$n != $expected_ports} {
    puts "CMR_DC_FAIL rcu_matched_leaf_before actual=$n expected=$expected_ports unit=$unit"
    exit 2
  }
  set load_names {}
  foreach_in_collection c $leaves {
    set name [get_object_name $c]
    set z_pin [get_pins -quiet "$name/Z"]
    if {[sizeof_collection $z_pin] != 1} {
      puts "CMR_DC_FAIL rcu_matched_z_pin $name"
      exit 2
    }
    set z_net [get_nets -of_objects $z_pin]
    set loads [remove_from_collection [get_pins -of_objects $z_net] $z_pin]
    if {[sizeof_collection $loads] == 0} {
      puts "CMR_DC_FAIL rcu_matched_no_load $name"
      exit 2
    }
    foreach_in_collection p $loads {
      lappend load_names [get_object_name $p]
    }
  }
  if {[llength $load_names] != $expected_ports} {
    puts "CMR_DC_FAIL rcu_matched_buf_loads actual=[llength $load_names] expected=$expected_ports"
    exit 2
  }
  set inserted 0
  for {set stage 1} {$stage <= $nbuf} {incr stage} {
    foreach pin_name $load_names {
      set pin [get_pins -quiet $pin_name]
      if {[sizeof_collection $pin] != 1} {
        puts "CMR_DC_FAIL rcu_matched_buf_pin $pin_name"
        exit 2
      }
      if {[catch {insert_buffer $pin $lib_name -new_cell_names rcu_matched_buf_s${stage}} err]} {
        puts "CMR_DC_FAIL rcu_matched_buf_insert stage=$stage pin=$pin_name error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]
  set expected [expr {$expected_ports * $nbuf}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_DC_FAIL rcu_matched_buf_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  puts "CMR_RCU_MATCHED_BUF inserts=$inserted stages=$nbuf loads=[llength $load_names] lib=$lib_name"
}

proc cmr_router_acklatch_e_pins {} {
  set pins [get_pins -hierarchical -quiet -filter {full_name =~ *AckLatch*latch_cell/E}]
  set offset [get_pins -hierarchical -quiet -filter {full_name =~ *OffsetLatch*latch_cell/E}]
  if {[sizeof_collection $offset] > 0} {
    set pins [remove_from_collection $pins $offset]
  }
  return $pins
}

proc cmr_router_insert_lane01_bufs {nbuf expected_adapters} {
  set lib_name [cmr_router_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_DC_FAIL lane01_missing_buffd0"
    exit 2
  }
  set pins [cmr_router_acklatch_e_pins]
  set n [sizeof_collection $pins]
  if {$n != $expected_adapters} {
    puts "CMR_DC_FAIL lane01_acklatch_e_count actual=$n expected=$expected_adapters"
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
        puts "CMR_DC_FAIL lane01_buf_pin $pin_name"
        exit 2
      }
      if {[catch {insert_buffer $pin $lib_name -new_cell_names lane01_acklatch_e_buf_s${stage}} err]} {
        puts "CMR_DC_FAIL lane01_buf_insert stage=$stage pin=$pin_name error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *lane01_acklatch_e_buf_s*}]
  set expected [expr {$expected_adapters * $nbuf}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_DC_FAIL lane01_buf_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  if {[sizeof_collection $latch_cells] > 0} {
    set_dont_touch $latch_cells true
  }
  puts "CMR_LANE01_ACKLATCH_BUF inserts=$inserted stages=$nbuf adapters=$n lib=$lib_name"
}

if {$seed_run ne ""} {
  if {$buf_stages < 1 && $lane01_stages < 1} {
    puts "CMR_DC_FAIL incremental_buf_stages nbuf=$buf_stages lane01=$lane01_stages seed=$seed_run"
    exit 2
  }
  set seed_ddc "$PROJECT_DIR/outputs/$seed_run/CMRRouter.ddc"
  if {![file exists $seed_ddc]} {
    puts "CMR_DC_FAIL missing_seed_ddc=$seed_ddc"
    exit 2
  }
  read_ddc $seed_ddc
  current_design CMRRouter
  link
  puts "CMR_ROUTER_INCREMENTAL seed=$seed_run buf_stages=$buf_stages lane01_stages=$lane01_stages unit=$rcu_unit_ps"
} else {
  set dut_v "$RTL_DIR/CMRRouter.v"
  if {[info exists ::env(CMR_DUT_V)] && $::env(CMR_DUT_V) ne ""} {
    set dut_v $::env(CMR_DUT_V)
  }
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
    "$RTL_DIR/LanePhaseAdapter.v" \
    "$RTL_DIR/WriteControlUnit.v" \
    "$RTL_DIR/WriteCounter.v" \
    "$RTL_DIR/WriteAckGenerator.v" \
    "$RTL_DIR/ReadControlUnit.v" \
    "$RTL_DIR/ReadCounter.v" \
    "$RTL_DIR/ReadRequestGenerator.v" \
    "$RTL_DIR/ReadPhaseSelector.v" \
    "$RTL_DIR/ReadAckGenerator.v" \
    $dut_v]
  elaborate CMRRouter -work WORK
  current_design CMRRouter
  uniquify
  link
}
check_design > "$REPORT_DIR/check_design_pre.rpt"

# Each RCU OPM Selector contains four reset-dominant paper SR states.  They
# must map to the single-clear implementation; a dual CDN/SDN latch has an
# illegal crossover window when TailPassed releases while RouteSel is high.
set path_latches_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]
set selector_dual_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]
set path_latch_pre_count [sizeof_collection $path_latches_pre]
set selector_dual_pre_count [sizeof_collection $selector_dual_pre]
if {$path_latch_pre_count != $expected_path_latches || $selector_dual_pre_count != 0} {
  puts "CMR_DC_FAIL path_latch_pre clear=$path_latch_pre_count expected=$expected_path_latches dual=$selector_dual_pre_count"
  exit 2
}
set_dont_touch $path_latches_pre true

set clear_latches_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set set_latches_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]
set clear_latch_pre_count [sizeof_collection $clear_latches_pre]
set set_latch_pre_count [sizeof_collection $set_latches_pre]
if {$clear_latch_pre_count == 0 || $set_latch_pre_count == 0} {
  puts "CMR_DC_FAIL phase_latch_pre_count clear=$clear_latch_pre_count set=$set_latch_pre_count"
  exit 2
}
set_dont_touch $clear_latches_pre true
set_dont_touch $set_latches_pre true

source "$RTL_DIR/async_cmr_router.sdc"
source "$RTL_DIR/async_primitives.tcl"

set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
set_critical_range 0.05 [current_design]

if {$seed_run ne ""} {
  if {$buf_stages >= 1} {
    cmr_router_insert_matched_bufs $buf_stages $expected_ports $rcu_unit_ps
  } else {
    puts "CMR_RCU_MATCHED_BUF skipped stages=0"
  }
  if {$lane01_stages >= 1} {
    cmr_router_insert_lane01_bufs $lane01_stages $expected_adapters
  } else {
    puts "CMR_LANE01_ACKLATCH_BUF skipped stages=0"
  }
  compile_ultra -incremental -no_autoungroup
} else {
  # Mat cone: dest Q -> RouteSelAnd.A1.  Make AddressRegister Q a startpoint
  # and give compile a 0.20 ns max so the L1 vs-constant decode is sized.
  set mat_max_ns 0.20
  if {[info exists ::env(CMR_RCU_MAT_MAX_NS)] && $::env(CMR_RCU_MAT_MAX_NS) ne ""} {
    set mat_max_ns $::env(CMR_RCU_MAT_MAX_NS)
  }
  set ::CMR_RCU_MAT_LATCHES ""
  set ::CMR_RCU_MAT_PAIRS {}
  set rcus [get_cells -hierarchical -quiet -filter {
    full_name =~ *InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*
  }]
  set mat_latch_init 0
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set latches [get_cells -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell"]
    if {[sizeof_collection $latches] > 0} {
      if {$mat_latch_init == 0} {
        set ::CMR_RCU_MAT_LATCHES $latches
        set mat_latch_init 1
      } else {
        set ::CMR_RCU_MAT_LATCHES [add_to_collection $::CMR_RCU_MAT_LATCHES $latches]
      }
    }
    set req_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
    set dest_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/Q"]
    set dest_q [remove_from_collection $dest_q $req_q]
    set dest_names [get_object_name $dest_q]
    foreach bit {0 1 2 3} {
      set anda [get_pins -quiet "$root/RouteComputation/RouteSelAnd_${bit}/g/A1"]
      if {[sizeof_collection $anda] != 1} {
        set anda [get_pins -quiet -hierarchical -filter "full_name =~ $root/*RouteSelAnd_${bit}*/g/A1"]
      }
      if {[llength $dest_names] == 24 && [sizeof_collection $anda] == 1} {
        lappend ::CMR_RCU_MAT_PAIRS [list $dest_names [get_object_name $anda]]
      }
    }
  }
  if {$mat_latch_init} {
    set_disable_timing $::CMR_RCU_MAT_LATCHES
  }
  set mat_pairs 0
  set expected_mat_pairs [expr {4 * $expected_ports}]
  foreach pair $::CMR_RCU_MAT_PAIRS {
    set_max_delay $mat_max_ns -from [get_pins [lindex $pair 0]] -to [get_pins [lindex $pair 1]]
    incr mat_pairs
  }
  puts "CMR_RCU_MAT_MAX ns=$mat_max_ns pairs=$mat_pairs expected=$expected_mat_pairs rcus=[sizeof_collection $rcus]"
  if {$mat_pairs != $expected_mat_pairs} {
    puts "CMR_DC_FAIL mat_pairs=$mat_pairs expected=$expected_mat_pairs"
    exit 2
  }
  compile_ultra -no_autoungroup
  foreach pair $::CMR_RCU_MAT_PAIRS {
    catch { reset_path -from [get_pins [lindex $pair 0]] -to [get_pins [lindex $pair 1]] }
  }
  if {$mat_latch_init} {
    catch { remove_disable_timing $::CMR_RCU_MAT_LATCHES }
  }
}
check_design > "$REPORT_DIR/check_design_post.rpt"

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]

set ipm_count [sizeof_collection [get_cells -quiet InputPortModules_*]]
set opm_count [sizeof_collection [get_cells -quiet OutputPortModules_*]]
set mutex4_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex4*}]]
set mutex2_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex2*}]]
set reset_latch_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]]
set sr_latch_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCSNDQD*}]]
set path_latch_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]]
set selector_dual_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]]
set set_reset_latch_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]]
set close_event_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ V2CloseEvent* || full_name =~ *RegClose*}]]
set handshake_complete_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ HandshakeComplete*}]]
set del050_rcu [sizeof_collection [cmr_router_matched_leaves 50]]
set del075_rcu [sizeof_collection [cmr_router_matched_leaves 75]]
set del100_rcu [sizeof_collection [cmr_router_matched_leaves 100]]
set del150_rcu [sizeof_collection [cmr_router_matched_leaves 150]]
set ackin_glob [cmr_router_matched_leaf_glob $opm_ackin_unit_ps]
set ackin_del [sizeof_collection [get_cells -hierarchical -quiet -filter "ref_name =~ DEL*D1* && full_name =~ *AckinDelay*"]]
if {$ackin_use_buf} {
  set ackin_delayed [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ BUFFD0* && full_name =~ *AckinDelay*}]]
} else {
  set ackin_delayed [sizeof_collection [get_cells -hierarchical -quiet -filter "ref_name =~ $ackin_glob && full_name =~ *AckinDelay*"]]
}
set matched_buf [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]]
set adapter_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]]
set acklatch_e_count [sizeof_collection [cmr_router_acklatch_e_pins]]
set lane01_buf [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *lane01_acklatch_e_buf_s*}]]

set structure_fd [open "$REPORT_DIR/cmr_structure.rpt" w]
puts $structure_fd "IPM_COUNT=$ipm_count"
puts $structure_fd "OPM_COUNT=$opm_count"
puts $structure_fd "MUTEX4_COUNT=$mutex4_count"
puts $structure_fd "MUTEX2_COUNT=$mutex2_count"
puts $structure_fd "RESET_LATCH_COUNT=$reset_latch_count"
puts $structure_fd "SR_LATCH_COUNT=$sr_latch_count"
puts $structure_fd "PATH_LATCH_CLEAR_COUNT=$path_latch_count"
puts $structure_fd "PATH_LATCH_DUAL_COUNT=$selector_dual_count"
puts $structure_fd "SET_RESET_LATCH_COUNT=$set_reset_latch_count"
puts $structure_fd "V2_CLOSE_EVENT_COUNT=$close_event_count"
puts $structure_fd "HANDSHAKE_COMPLETE_COUNT=$handshake_complete_count"
puts $structure_fd "LEGAL_REQ_EDGES=$expected_edges"
puts $structure_fd "UTURN_EDGES=0"
puts $structure_fd "RCU_DEL050_COUNT=$del050_rcu"
puts $structure_fd "RCU_DEL075_COUNT=$del075_rcu"
puts $structure_fd "RCU_DEL100_COUNT=$del100_rcu"
puts $structure_fd "RCU_DEL150_COUNT=$del150_rcu"
puts $structure_fd "ADAPTER_COUNT=$adapter_count"
puts $structure_fd "ACKLATCH_E_COUNT=$acklatch_e_count"
puts $structure_fd "LANE01_ACKLATCH_BUF_COUNT=$lane01_buf"
puts $structure_fd "LANE01_BUF_STAGES=$lane01_stages"
puts $structure_fd "OPM_ACKIN_DELAY_COUNT=$ackin_delayed"
puts $structure_fd "OPM_ACKIN_DELAY_UNIT_PS=$opm_ackin_unit_ps"
puts $structure_fd "OPM_ACKIN_DELAY_STEPS=$opm_ackin_steps"
puts $structure_fd "OPM_ACKIN_USE_BUF=$ackin_use_buf"
puts $structure_fd "OPM_ACKIN_DEL_COUNT=$ackin_del"
puts $structure_fd "RCU_MATCHED_BUF_COUNT=$matched_buf"
puts $structure_fd "RCU_MATCHED_BUF_STAGES=$buf_stages"
puts $structure_fd "RCU_MATCHED_DELAY_UNIT_PS=$rcu_unit_ps"
puts $structure_fd "RCU_MATCHED_DELAY_STEPS=$rcu_steps"
close $structure_fd
puts "CMR_STRUCTURE IPM=$ipm_count OPM=$opm_count MUTEX4=$mutex4_count MUTEX2=$mutex2_count ADAPTER=$adapter_count ACKLATCH_E=$acklatch_e_count LANE01_BUF=$lane01_buf stages=$lane01_stages RESET_LATCH=$reset_latch_count SET_RESET_LATCH=$set_reset_latch_count SR_LATCH=$sr_latch_count CLOSE_EVENT=$close_event_count COMPLETE=$handshake_complete_count DEL050=$del050_rcu DEL075=$del075_rcu DEL100=$del100_rcu DEL150=$del150_rcu ACKIN_DELAY=$ackin_delayed ACKIN_UNIT=$opm_ackin_unit_ps ACKIN_STEPS=$opm_ackin_steps ACKIN_BUF=$ackin_use_buf ACKIN_DEL=$ackin_del BUF=$matched_buf stages=$buf_stages"

if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}
if {$ipm_count != $expected_ports || $opm_count != $expected_ports} {
  puts "CMR_DC_FAIL router_structure"
  exit 2
}
if {$handshake_complete_count != 0} {
  puts "CMR_DC_FAIL obsolete_handshake_complete actual=$handshake_complete_count expected=0"
  exit 2
}
if {$reset_latch_count == 0 || $close_event_count == 0} {
  puts "CMR_DC_FAIL async_storage_structure"
  exit 2
}
if {$path_latch_count != $expected_path_latches || $selector_dual_count != 0} {
  puts "CMR_DC_FAIL path_latch_post clear=$path_latch_count expected=$expected_path_latches dual=$selector_dual_count"
  exit 2
}
if {$reset_latch_count != $clear_latch_pre_count || $set_reset_latch_count != $set_latch_pre_count} {
  puts "CMR_DC_FAIL phase_latch_structure clear=$reset_latch_count expected_clear=$clear_latch_pre_count set=$set_reset_latch_count expected_set=$set_latch_pre_count"
  exit 2
}
if {$rcu_steps == 0} {
  if {$del050_rcu != 0 || $del075_rcu != 0 || $del100_rcu != 0 || $del150_rcu != 0} {
    puts "CMR_DC_FAIL rcu_matched_removed DEL050=$del050_rcu DEL075=$del075_rcu DEL100=$del100_rcu DEL150=$del150_rcu"
    exit 2
  }
} elseif {$rcu_steps == 1} {
  set expected_unit_count $expected_ports
  set other050 $del050_rcu
  set other075 $del075_rcu
  set other100 $del100_rcu
  set other150 $del150_rcu
  switch -- $rcu_unit_ps {
    50  { set other050 0 }
    75  { set other075 0 }
    100 { set other100 0 }
    150 { set other150 0 }
    default {
      puts "CMR_DC_FAIL rcu_unit_unsupported unit=$rcu_unit_ps"
      exit 2
    }
  }
  set actual_unit [sizeof_collection [cmr_router_matched_leaves $rcu_unit_ps]]
  if {$actual_unit != $expected_unit_count || $other050 != 0 || $other075 != 0 || $other100 != 0 || $other150 != 0} {
    puts "CMR_DC_FAIL rcu_matched_unit unit=$rcu_unit_ps actual=$actual_unit expected=$expected_unit_count DEL050=$del050_rcu DEL075=$del075_rcu DEL100=$del100_rcu DEL150=$del150_rcu"
    exit 2
  }
}
if {$ackin_use_buf} {
  set expected_ackin_delayed $expected_ports
  if {$ackin_delayed != $expected_ackin_delayed || $ackin_del != 0} {
    puts "CMR_DC_FAIL opm_ackin_buf actual=$ackin_delayed expected=$expected_ackin_delayed del=$ackin_del"
    exit 2
  }
} else {
  set expected_ackin_delayed [expr {$expected_ports * $opm_ackin_steps}]
  if {$ackin_delayed != $expected_ackin_delayed} {
    puts "CMR_DC_FAIL opm_ackin_delay actual=$ackin_delayed expected=$expected_ackin_delayed unit=$opm_ackin_unit_ps"
    exit 2
  }
}
set expected_buf [expr {$expected_ports * $buf_stages}]
if {$matched_buf != $expected_buf} {
  puts "CMR_DC_FAIL rcu_matched_buf actual=$matched_buf expected=$expected_buf stages=$buf_stages"
  exit 2
}
if {$expected_adapters > 0 && $acklatch_e_count != $expected_adapters} {
  puts "CMR_DC_FAIL acklatch_e_count actual=$acklatch_e_count expected=$expected_adapters"
  exit 2
}
set expected_lane01_buf [expr {$expected_adapters * $lane01_stages}]
if {$lane01_buf != $expected_lane01_buf} {
  puts "CMR_DC_FAIL lane01_acklatch_buf actual=$lane01_buf expected=$expected_lane01_buf stages=$lane01_stages"
  exit 2
}

async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 50 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 50 > "$REPORT_DIR/timing_min.rpt"

write -hierarchy -format ddc -output "$OUTPUT_DIR/CMRRouter.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/CMRRouter_post.v"
write_sdf "$OUTPUT_DIR/CMRRouter.sdf"
write_sdc "$OUTPUT_DIR/CMRRouter.sdc"
exec sha256sum "$OUTPUT_DIR/CMRRouter.ddc" "$OUTPUT_DIR/CMRRouter_post.v" \
  "$OUTPUT_DIR/CMRRouter.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_DC_PASS output=$OUTPUT_DIR"
quit
