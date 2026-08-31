# Preserve CMR asynchronous structure through ICC2 / PrimeTime.
# Sourced after the design is linked and before place/route/compile.

proc cmr_pnr_collection {filter} {
  return [get_cells -hierarchical -quiet -filter $filter]
}

proc cmr_pnr_dont_touch {filter label} {
  set cells [cmr_pnr_collection $filter]
  set n [sizeof_collection $cells]
  if {$n > 0} {
    set_dont_touch $cells true
    catch { set_size_only $cells true }
    puts "CMR_PNR_PRESERVE $label $n"
  } else {
    puts "CMR_PNR_PRESERVE_MISS $label"
  }
  return $n
}

proc cmr_async_preserve {} {
  set_ungroup [current_design] false
  catch { set_app_options -name compile.auto_ungroup.area -value false }
  catch { set_app_options -name compile.auto_ungroup.delay -value false }
  catch { set_app_options -name place.legalize.enable_via_ladder -value false }

  cmr_pnr_dont_touch {ref_name =~ DelayElement*} DelayElement_hier
  cmr_pnr_dont_touch {ref_name =~ DEL050D1*} DEL050
  cmr_pnr_dont_touch {ref_name =~ DEL*} DEL_any
  cmr_pnr_dont_touch {full_name =~ *MatchedDelay*} MatchedDelay
  cmr_pnr_dont_touch {full_name =~ *AckinDelay*} AckinDelay
  cmr_pnr_dont_touch {ref_name =~ Mutex2*} Mutex2
  cmr_pnr_dont_touch {ref_name =~ Mutex4*} Mutex4
  cmr_pnr_dont_touch {full_name =~ *q0_nand* || full_name =~ *q1_nand*} MutexNand
  cmr_pnr_dont_touch {ref_name =~ NR4D1* && (full_name =~ *gnt0_filter* || full_name =~ *gnt1_filter*)} MutexFilter
  cmr_pnr_dont_touch {ref_name =~ MullerC*} MullerC
  cmr_pnr_dont_touch {ref_name =~ LHCNDQD*} LHCNDQD
  cmr_pnr_dont_touch {ref_name =~ LHSNDQD*} LHSNDQD
  cmr_pnr_dont_touch {ref_name =~ V2CloseEvent* || full_name =~ *closeEvent* || full_name =~ *RegClose*} V2CloseEvent
  cmr_pnr_dont_touch {ref_name =~ LanePhaseAdapter*} LanePhaseAdapter
  cmr_pnr_dont_touch {ref_name =~ HeadPredictor*} HeadPredictor
  cmr_pnr_dont_touch {ref_name =~ RouteSelAnd2*} RouteSelAnd2
  cmr_pnr_dont_touch {full_name =~ *Selector*PathLatch*sr_cell} PathLatch

  # Analysis-only mutex loop break.  Must not change the netlist.
  set q1 [cmr_pnr_collection {full_name =~ *q1_nand*}]
  set n_dis 0
  foreach_in_collection cell $q1 {
    if {![catch { set_disable_timing -from A2 -to ZN $cell }]} {
      incr n_dis
    }
  }
  puts "CMR_PNR_MUTEX_LOOP_CUT $n_dis"
}

proc cmr_pnr_write_structure {path} {
  set fd [open $path w]
  foreach {key filter} {
    DelayElement {ref_name =~ DelayElement*}
    DEL050 {ref_name =~ DEL050D1*}
    DEL_any {ref_name =~ DEL*}
    Mutex2 {ref_name =~ Mutex2*}
    Mutex4 {ref_name =~ Mutex4*}
    MullerC {ref_name =~ MullerC*}
    LHCNDQD {ref_name =~ LHCNDQD*}
    LHSNDQD {ref_name =~ LHSNDQD*}
    GTECH {ref_name =~ GTECH*}
    SEQGEN {ref_name =~ *SEQGEN*}
    LanePhaseAdapter {ref_name =~ LanePhaseAdapter*}
    V2CloseEvent {ref_name =~ V2CloseEvent* || full_name =~ *closeEvent*}
    IPM {ref_name =~ IPM* || full_name =~ InputPortModules_*}
    OPM {full_name =~ OutputPortModules_*}
  } {
    puts $fd "$key=[sizeof_collection [cmr_pnr_collection $filter]]"
  }
  close $fd
  puts "CMR_PNR_STRUCTURE $path"
}

proc cmr_pnr_gate_counts {expected_del050} {
  set gtech [sizeof_collection [cmr_pnr_collection {ref_name =~ GTECH*}]]
  set seq [sizeof_collection [cmr_pnr_collection {ref_name =~ *SEQGEN*}]]
  set del [sizeof_collection [cmr_pnr_collection {ref_name =~ DEL050D1*}]]
  set mutex [sizeof_collection [cmr_pnr_collection {ref_name =~ Mutex2*}]]
  set latch [sizeof_collection [cmr_pnr_collection {ref_name =~ LHCNDQD*}]]
  set fail 0
  if {$gtech != 0} { puts "CMR_PNR_FAIL GTECH=$gtech"; set fail 1 }
  if {$seq != 0} { puts "CMR_PNR_FAIL SEQGEN=$seq"; set fail 1 }
  if {$expected_del050 ne "" && $del != $expected_del050} {
    puts "CMR_PNR_FAIL DEL050=$del expected=$expected_del050"
    set fail 1
  }
  if {$mutex == 0} { puts "CMR_PNR_FAIL mutex_lost"; set fail 1 }
  if {$latch == 0} { puts "CMR_PNR_FAIL latch_lost"; set fail 1 }
  if {$fail} { return 0 }
  puts "CMR_PNR_STRUCTURE_OK DEL050=$del MUTEX2=$mutex LHCNDQD=$latch"
  return 1
}
