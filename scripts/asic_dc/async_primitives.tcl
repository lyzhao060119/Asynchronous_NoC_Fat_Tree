# Preserve ASIC async primitives and break intentional mutex combinational loops.
# Source after elaborate / link, before compile_ultra.

proc async_apply_primitive_dont_touch {} {
  set delay_hier [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement*}]
  if {[sizeof_collection $delay_hier] == 0} {
    set delay_hier [get_cells -hierarchical -quiet -filter {full_name =~ *DelayElement*}]
  }
  if {[sizeof_collection $delay_hier] > 0} {
    set_dont_touch $delay_hier
    puts "INFO: set_dont_touch on [sizeof_collection $delay_hier] DelayElement hierarch(y/ies)"
  } else {
    puts "INFO: no DelayElement cells found for set_dont_touch"
  }

  set ackin_buf_hier [get_cells -hierarchical -quiet -filter {ref_name =~ DontTouchBuf*}]
  if {[sizeof_collection $ackin_buf_hier] == 0} {
    set ackin_buf_hier [get_cells -hierarchical -quiet -filter {full_name =~ *AckinDelay*}]
  }
  if {[sizeof_collection $ackin_buf_hier] > 0} {
    set_dont_touch $ackin_buf_hier
    puts "INFO: set_dont_touch on [sizeof_collection $ackin_buf_hier] AckinDelay/DontTouchBuf hierarch(y/ies)"
  }
  set ackin_buf_cells [get_cells -hierarchical -quiet -filter {full_name =~ *AckinDelay* && ref_name =~ BUFFD0*}]
  if {[sizeof_collection $ackin_buf_cells] > 0} {
    set_dont_touch $ackin_buf_cells
    puts "INFO: set_dont_touch on [sizeof_collection $ackin_buf_cells] AckinDelay BUFFD0 cells"
  }
  set grant_hold_buf_cells [get_cells -hierarchical -quiet -filter {full_name =~ *GrantHoldBuf* && ref_name =~ BUFFD0*}]
  if {[sizeof_collection $grant_hold_buf_cells] > 0} {
    set_dont_touch $grant_hold_buf_cells
    puts "INFO: set_dont_touch on [sizeof_collection $grant_hold_buf_cells] GrantHoldBuf BUFFD0 cells"
  }

  set del_cells [get_cells -hierarchical -quiet -filter {ref_name =~ DEL*}]
  if {[sizeof_collection $del_cells] > 0} {
    set_dont_touch $del_cells
    puts "INFO: set_dont_touch on [sizeof_collection $del_cells] DEL* delay cells"
  }

  set head_predictor_hier [get_cells -hierarchical -quiet -filter {ref_name =~ HeadPredictor*}]
  if {[sizeof_collection $head_predictor_hier] > 0} {
    set_dont_touch $head_predictor_hier
    puts "INFO: set_dont_touch on [sizeof_collection $head_predictor_hier] CMR HeadPredictor hierarch(y/ies)"
  }
  set phase_selector_hier [get_cells -hierarchical -quiet -filter {ref_name =~ PhaseSelector*}]
  if {[sizeof_collection $phase_selector_hier] > 0} {
    set_dont_touch $phase_selector_hier
    puts "INFO: set_dont_touch on [sizeof_collection $phase_selector_hier] CMR PhaseSelector hierarch(y/ies)"
  }
  set routesel_and_hier [get_cells -hierarchical -quiet -filter {ref_name =~ RouteSelAnd2*}]
  if {[sizeof_collection $routesel_and_hier] > 0} {
    set_dont_touch $routesel_and_hier
    puts "INFO: set_dont_touch on [sizeof_collection $routesel_and_hier] CMR RouteSelAnd2 hierarch(y/ies)"
  } else {
    puts "WARN: no RouteSelAnd2 cells found for set_dont_touch"
  }
  set routesel_and_cells [get_cells -hierarchical -quiet -filter {full_name =~ *RouteSelAnd* && ref_name =~ AN2D0BWP12T30P140}]
  if {[sizeof_collection $routesel_and_cells] > 0} {
    set_dont_touch $routesel_and_cells
    puts "INFO: set_dont_touch on [sizeof_collection $routesel_and_cells] RouteSel AN2D0 cells"
  }

  set mutex_hier [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex2*}]
  if {[sizeof_collection $mutex_hier] == 0} {
    set mutex_hier [get_cells -hierarchical -quiet -filter {full_name =~ *Mutex2*}]
  }

  # DLatchBank is deliberately entered as a direct T28 asynchronous-clear
  # latch.  Retain the cell and its CDN arc: replacing it with a plain latch
  # plus reset mux would recreate the D/E coupling seen in earlier GLS runs.
  set reset_latch_cells [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
  if {[sizeof_collection $reset_latch_cells] > 0} {
    set_dont_touch $reset_latch_cells
    puts "INFO: set_dont_touch on [sizeof_collection $reset_latch_cells] LHCNDQD resettable latches"
  } else {
    puts "WARN: no LHCNDQD resettable latches found"
  }

  # The physical V2 close edge is intentionally one inverter downstream of
  # the latches' actual E input.  Preserve that named implementation point.
  set close_event_hier [get_cells -hierarchical -quiet -filter {full_name =~ *closeEvent*}]
  if {[sizeof_collection $close_event_hier] > 0} {
    set_dont_touch $close_event_hier
    puts "INFO: set_dont_touch on [sizeof_collection $close_event_hier] V2CloseEvent hierarch(y/ies)"
  }

  if {[sizeof_collection $mutex_hier] > 0} {
    set_dont_touch $mutex_hier
    puts "INFO: set_dont_touch on [sizeof_collection $mutex_hier] Mutex2 hierarch(y/ies)"
  } else {
    puts "WARN: no Mutex2 cells found for set_dont_touch"
  }

  set nand_cells [get_cells -hierarchical -quiet -filter {(full_name =~ *q0_nand* || full_name =~ *q1_nand*) && (ref_name =~ ND2D1BWP12T30P140 || ref_name =~ ND2D2BWP12T30P140)}]
  if {[sizeof_collection $nand_cells] > 0} {
    set_dont_touch $nand_cells
    puts "INFO: set_dont_touch on [sizeof_collection $nand_cells] mutex NAND cells"
  }

  # The NOR4 cells are intentionally used as tied-input physical
  # metastability filters, not ordinary logic inversions.  Preserve their
  # implementation, instance identity and sizing through compile_ultra.
  set mutex_filter_cells [get_cells -hierarchical -quiet -filter {ref_name =~ NR4D1BWP12T30P140 && (full_name =~ *gnt0_filter* || full_name =~ *gnt1_filter*)}]
  if {[sizeof_collection $mutex_filter_cells] > 0} {
    set_dont_touch $mutex_filter_cells
    puts "INFO: set_dont_touch on [sizeof_collection $mutex_filter_cells] Mutex2 NR4D1 filter cells"
  } else {
    puts "WARN: no Mutex2 NR4D1 filter cells found"
  }
}

proc async_break_mutex_loops {} {
  # Break one timing arc of the cross-coupled NAND pair so DC/STA can proceed.
  set q1_nands [get_cells -hierarchical -quiet -filter {full_name =~ *q1_nand*}]
  set n_disabled 0
  foreach_in_collection cell $q1_nands {
    # set_disable_timing needs the cell as object_list; -from/-to are pin names.
    set a2 [get_pins -quiet -of_objects $cell -filter {name == A2}]
    set zn [get_pins -quiet -of_objects $cell -filter {name == ZN}]
    if {[sizeof_collection $a2] > 0 && [sizeof_collection $zn] > 0} {
      set_disable_timing -from A2 -to ZN $cell
      incr n_disabled
    }
  }
  puts "INFO: set_disable_timing on $n_disabled / [sizeof_collection $q1_nands] Mutex2 q1_nand A2->ZN arcs"
}

# Intentional ND2D1/ND2D2 mismatch so simultaneous both-request edges
# resolve under SDF (Mutex2_sim 0.10/0.11 ns).  Keep DC from resizing
# either side of the pair.
proc async_mutex2_drive_symmetry_ok {} {
  set q0_d1 [get_cells -hierarchical -quiet -filter {full_name =~ *q0_nand* && ref_name =~ ND2D1BWP12T30P140}]
  set q1_d2 [get_cells -hierarchical -quiet -filter {full_name =~ *q1_nand* && ref_name =~ ND2D2BWP12T30P140}]
  set q0_all [get_cells -hierarchical -quiet -filter {full_name =~ *q0_nand*}]
  set q1_all [get_cells -hierarchical -quiet -filter {full_name =~ *q1_nand*}]
  set n0 [sizeof_collection $q0_d1]
  set n1 [sizeof_collection $q1_d2]
  set n0_all [sizeof_collection $q0_all]
  set n1_all [sizeof_collection $q1_all]
  puts "INFO: Mutex2 NAND drive mismatch q0_ND2D1=$n0/$n0_all q1_ND2D2=$n1/$n1_all"
  if {$n0 == 0 || $n0 != $n1 || $n0 != $n0_all || $n1 != $n1_all} {
    return 0
  }
  return 1
}

proc async_mutex2_drive_mismatch_ok {} {
  return [async_mutex2_drive_symmetry_ok]
}

proc async_report_primitive_counts {report_path} {
  set fd [open $report_path w]
  puts $fd "primitive,count"
  puts $fd "DelayElement_hier,[sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *DelayElement*}]]"
  puts $fd "DEL_delay,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL*}]]"
  puts $fd "DEL050_delay,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL050D1*}]]"
  puts $fd "DEL075_delay,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL075D1*}]]"
  puts $fd "DEL100_delay,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL100D1*}]]"
  puts $fd "DEL150_delay,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL150D1*}]]"
  puts $fd "DEL250_delay,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL250D1*}]]"
  puts $fd "Mutex2_hier,[sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Mutex2*}]]"
  puts $fd "ND2D1_mutex_q0,[sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *q0_nand* && ref_name =~ ND2D1BWP12T30P140}]]"
  puts $fd "ND2D2_mutex_q1,[sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *q1_nand* && ref_name =~ ND2D2BWP12T30P140}]]"
  puts $fd "ND2D1_mutex,[sizeof_collection [get_cells -hierarchical -quiet -filter {(full_name =~ *q0_nand* || full_name =~ *q1_nand*) && (ref_name =~ ND2D1BWP12T30P140 || ref_name =~ ND2D2BWP12T30P140)}]]"
  puts $fd "NR4D1_mutex_filter,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ NR4D1BWP12T30P140 && (full_name =~ *gnt0_filter* || full_name =~ *gnt1_filter*)}]]"
  puts $fd "LHCNDQD_resettable_latch,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]]"
  puts $fd "V2CloseEvent_hier,[sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *closeEvent*}]]"
  puts $fd "RouteSelAnd2_hier,[sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ RouteSelAnd2*}]]"
  puts $fd "RouteSel_AN2D0,[sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *RouteSelAnd* && ref_name =~ AN2D0BWP12T30P140}]]"
  close $fd
  puts "INFO: wrote $report_path"
}

async_apply_primitive_dont_touch
async_break_mutex_loops
