# Fig. 6 inner-loop / Fig. 7 outer-RTM overlay for the thin CircularFIFO NoC16 DDC.
#
# Sourced after async_cmr_noc16_datapath.sdc.  Applies control min/max:
#   Tctrl_min = Tdata_max * (1 + RTM)
#   Tctrl_max = Tctrl_min + extra_slack
#
# Step E: exactly one RTC class (OPM-01 / RCU-01 / AR-01), RTM 0%.
# Step F: class CMR-OUTER-RTM5 reapplies every closable window at RTM 5%.
# No set_disable_timing (production SDC).  No DEL resize in this overlay.
# No Ackin DEL250 as Tctrl.  OPM-01 constrains L1_L4.Q -> L5.D only, never
# shared RegEnable, unless CMR_OPM_E_MAX_NS sets max-delay-only on
# L5.Q -> DataReg.E (no min-delay, no insert_buffer on E).
# Mutex / latches / existing DEL / RouteSelAnd2 stay frozen.

if {![info exists ::CMR_DP_APPLIED] || $::CMR_DP_APPLIED < 58} {
  puts "CMR_INNER_FAIL datapath overlay must be sourced first (datapath-first)"
  exit 2
}
if {![info exists ::env(CMR_INNER_TARGET_FILE)] ||
    ![file exists $::env(CMR_INNER_TARGET_FILE)]} {
  puts "CMR_INNER_FAIL missing target file"
  exit 2
}
source $::env(CMR_INNER_TARGET_FILE)

if {[info exists ::env(CMR_INNER_RTC_CLASS)] && $::env(CMR_INNER_RTC_CLASS) ne ""} {
  set ::CMR_INNER_CLASS $::env(CMR_INNER_RTC_CLASS)
}
if {![info exists ::CMR_INNER_CLASS] || $::CMR_INNER_CLASS eq ""} {
  puts "CMR_INNER_FAIL missing class"
  exit 2
}
if {![info exists ::CMR_INNER_RTM]} { set ::CMR_INNER_RTM 0.0 }
if {![info exists ::CMR_INNER_EXTRA_SLACK_NS]} { set ::CMR_INNER_EXTRA_SLACK_NS 0.100 }
if {![info exists ::CMR_INNER_NEAR_FLOOR_NS]} { set ::CMR_INNER_NEAR_FLOOR_NS 0.020 }

if {[info exists ::env(CMR_INNER_REPORT_DIR)] && $::env(CMR_INNER_REPORT_DIR) ne ""} {
  set inner_report_dir $::env(CMR_INNER_REPORT_DIR)
} elseif {[info exists ::env(CMR_DATAPATH_REPORT_DIR)] && $::env(CMR_DATAPATH_REPORT_DIR) ne ""} {
  set inner_report_dir $::env(CMR_DATAPATH_REPORT_DIR)
} elseif {[info exists REPORT_DIR]} {
  set inner_report_dir $REPORT_DIR
} else {
  puts "CMR_INNER_FAIL missing_report_dir"
  exit 2
}
file mkdir $inner_report_dir

set ::CMR_INNER_APPLIED 0
set ::CMR_INNER_SKIP 0
set ::CMR_INNER_SHORTFALL 0
set ::CMR_INNER_PAIRS [list]
set ::CMR_INNER_OPM_N 0
set ::CMR_INNER_RCU_N 0
set ::CMR_INNER_AR_N 0
set ::CMR_INNER_OPM_E_N 0

proc cmr_inner_fail {args} {
  puts "CMR_INNER_FAIL [join $args { }]"
  exit 2
}

proc cmr_inner_measure {from to dtype} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return -1.0
  }
  set worst -1.0
  if {[catch {set paths [get_timing_paths -from $from -to $to -delay_type $dtype -max_paths 8 -nworst 1]}]} {
    return -1.0
  }
  foreach_in_collection p $paths {
    set arr [get_attribute $p arrival]
    if {[string is double -strict $arr]} {
      if {$worst < 0.0} {
        set worst $arr
      } elseif {$dtype eq "max" && $arr > $worst} {
        set worst $arr
      } elseif {$dtype eq "min" && $arr < $worst} {
        set worst $arr
      }
    }
  }
  return $worst
}

proc cmr_inner_apply {id inst from to min_ns max_ns note} {
  set fc [sizeof_collection $from]
  set tc [sizeof_collection $to]
  if {$fc == 0 || $tc == 0} {
    puts $::inner_fd "$id,$inst,$min_ns,$max_ns,$fc,$tc,NO_BIND $note"
    close $::inner_fd
    cmr_inner_fail bind id=$id inst=$inst from=$fc to=$tc
  }
  if {$min_ns < 0.0 || $max_ns < $min_ns} {
    puts $::inner_fd "$id,$inst,$min_ns,$max_ns,$fc,$tc,SKIP_WINDOW $note"
    incr ::CMR_INNER_SKIP
    return 0
  }
  set_min_delay $min_ns -from $from -to $to
  set_max_delay $max_ns -from $from -to $to
  incr ::CMR_INNER_APPLIED
  lappend ::CMR_INNER_PAIRS [list $id $inst $min_ns $max_ns $note]
  puts $::inner_fd "$id,$inst,$min_ns,$max_ns,$fc,$tc,$note"
  puts "CMR_INNER_CONSTRAINT id=$id inst=$inst min_ns=$min_ns max_ns=$max_ns from=$fc to=$tc $note"
  return 1
}

proc cmr_inner_rcus {} {
  set rcus [get_cells -hierarchical -quiet -filter {
    full_name =~ *InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*
  }]
  if {[sizeof_collection $rcus] != 25} {
    cmr_inner_fail rcu_count actual=[sizeof_collection $rcus] expected=25
  }
  return $rcus
}

proc cmr_inner_opms {} {
  set n 0
  set opms ""
  foreach_in_collection c [get_cells -hierarchical -quiet -filter {ref_name =~ OPM*}] {
    set name [get_object_name $c]
    if {[regexp {OutputPortModules_[0-9]+$} $name]} {
      if {$n == 0} {
        set opms $c
      } else {
        set opms [add_to_collection $opms $c]
      }
      incr n
    }
  }
  if {$n != 25} {
    cmr_inner_fail opm_count actual=$n expected=25
  }
  return $opms
}

proc cmr_inner_rcu_andz {root bit} {
  set candidates [list \
    "$root/RouteComputation/RouteSelAnd_${bit}/g/Z" \
    "$root/RouteComputationLogic/RouteSelAnd_${bit}/g/Z" \
    "$root/RouteSelAnd_${bit}/g/Z" \
  ]
  set andz ""
  foreach pat $candidates {
    set andz [get_pins -quiet $pat]
    if {[sizeof_collection $andz] == 1} {
      return $andz
    }
  }
  set anda [get_pins -quiet -hierarchical -filter "full_name =~ $root/*RouteSelAnd_${bit}*/g/A1 || full_name =~ $root/*RouteSelAnd_${bit}*/A1"]
  if {[sizeof_collection $anda] == 1} {
    set cell [get_cells -of_objects $anda]
    set andz [get_pins -quiet -of_objects $cell -filter {name == Z || name == ZN}]
    if {[sizeof_collection $andz] == 1} {
      return $andz
    }
  }
  return [get_pins -quiet __cmr_inner_no_andz__]
}

proc cmr_inner_apply_opm01 {} {
  if {![info exists ::CMR_INNER_OPM_MIN_NS] || $::CMR_INNER_OPM_MIN_NS <= 0.0} {
    cmr_inner_fail invalid OPM min
  }
  if {![info exists ::CMR_INNER_OPM_MAX_NS] || $::CMR_INNER_OPM_MAX_NS < $::CMR_INNER_OPM_MIN_NS} {
    cmr_inner_fail invalid OPM max
  }
  set opms [cmr_inner_opms]
  foreach_in_collection opm $opms {
    set root [get_object_name $opm]
    set l14_q [get_pins -quiet "$root/L1_L4_*/resettable_latch\[*\].latch_cell/Q"]
    set l5_d [get_pins -quiet "$root/L5/resettable_latch\[0\].latch_cell/D"]
    set data_e [get_pins -quiet "$root/DataReg/resettable_latch\[*\].latch_cell/E"]
    if {[sizeof_collection $l14_q] != 4 || [sizeof_collection $l5_d] != 1 || [sizeof_collection $data_e] < 1} {
      cmr_inner_fail opm_bind inst=$root l14_q=[sizeof_collection $l14_q] l5_d=[sizeof_collection $l5_d] data_e=[sizeof_collection $data_e]
    }
    # Combo XOR segment DC can size (Ultra: XOR -> L5.D).  Do not constrain
    # DataReg.E / L5.E: that is shared RegEnable; buffering it desynchronizes
    # the V2 close.  STA still measures the catalog D vs E pair.
    cmr_inner_apply CMR-OPM-01 $root $l14_q $l5_d \
      $::CMR_INNER_OPM_MIN_NS $::CMR_INNER_OPM_MAX_NS \
      "XOR combo L1_L4.Q->L5.D; not Ackin DEL; not RegEnable"
    incr ::CMR_INNER_OPM_N
  }
  if {$::CMR_INNER_OPM_N != 25} {
    cmr_inner_fail opm_applied $::CMR_INNER_OPM_N
  }
}

proc cmr_inner_apply_rcu01 {} {
  if {![info exists ::CMR_INNER_RCU_MIN_NS] || $::CMR_INNER_RCU_MIN_NS <= 0.0} {
    cmr_inner_fail invalid RCU min
  }
  if {![info exists ::CMR_INNER_RCU_MAX_NS] || $::CMR_INNER_RCU_MAX_NS < $::CMR_INNER_RCU_MIN_NS} {
    cmr_inner_fail invalid RCU max
  }
  set rcus [cmr_inner_rcus]
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set req_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
    if {[sizeof_collection $req_q] != 1} {
      cmr_inner_fail rcu_req_q inst=$root n=[sizeof_collection $req_q]
    }
    set nbit 0
    foreach bit {0 1 2 3} {
      set andz [cmr_inner_rcu_andz $root $bit]
      if {[sizeof_collection $andz] != 1} {
        cmr_inner_fail rcu_andz inst=$root bit=$bit
      }
      cmr_inner_apply CMR-RCU-01 ${root}/bit${bit} $req_q $andz \
        $::CMR_INNER_RCU_MIN_NS $::CMR_INNER_RCU_MAX_NS \
        "Req_rc Q -> RouteSelAnd.Z; 4xDEL150 frozen, not squeezed"
      incr nbit
    }
    if {$nbit != 4} {
      cmr_inner_fail rcu_bits inst=$root n=$nbit
    }
    incr ::CMR_INNER_RCU_N
  }
  if {$::CMR_INNER_RCU_N != 25} {
    cmr_inner_fail rcu_applied $::CMR_INNER_RCU_N
  }
}

proc cmr_inner_apply_ar01 {} {
  set rcus [cmr_inner_rcus]
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set addr_d [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/D"]
    set req_d [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/D"]
    set addr_d [remove_from_collection $addr_d $req_d]
    set en [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/E"]
    set hp_q [get_pins -quiet "$root/AddressRegister/HeadPredictorBlock/en_state_reg/Q"]
    set ipm [file dirname $root]
    set ipm_cell [get_cells -quiet $ipm]
    set datain [get_pins -quiet -of_objects $ipm_cell -filter {name =~ io_Datain_flit*}]
    if {[sizeof_collection $addr_d] != 24 || [sizeof_collection $en] < 1 || [sizeof_collection $hp_q] != 1} {
      cmr_inner_fail ar_bind inst=$root addr_d=[sizeof_collection $addr_d] en=[sizeof_collection $en] hp_q=[sizeof_collection $hp_q]
    }
    set tdata [cmr_inner_measure $datain $addr_d max]
    set min_ns $::CMR_INNER_AR_MIN_NS
    set max_ns $::CMR_INNER_AR_MAX_NS
    if {$min_ns <= 0.0} {
      if {$tdata < 0.0} {
        set tdata 0.0
      }
      if {$tdata < $::CMR_INNER_NEAR_FLOOR_NS} {
        puts $::inner_fd "CMR-AR-01,$root,0,0,[sizeof_collection $hp_q],[sizeof_collection $en],SKIP_NEAR_FLOOR tdata=$tdata"
        puts "CMR_INNER_SKIP id=CMR-AR-01 inst=$root near_floor tdata=$tdata"
        incr ::CMR_INNER_SKIP
        continue
      }
      set min_ns [expr {double($tdata) * (1.0 + $::CMR_INNER_RTM)}]
      set max_ns [expr {$min_ns + $::CMR_INNER_EXTRA_SLACK_NS}]
    }
    set e_one [index_collection $en 0]
    cmr_inner_apply CMR-AR-01 $root $hp_q $e_one $min_ns $max_ns \
      "HeadPredictor.Q -> LatchReg.E; no RTL DEL on En"
    incr ::CMR_INNER_AR_N
  }
}

proc cmr_inner_apply_opm_e_max {} {
  set max_ns ""
  if {[info exists ::env(CMR_OPM_E_MAX_NS)] && $::env(CMR_OPM_E_MAX_NS) ne ""} {
    set max_ns $::env(CMR_OPM_E_MAX_NS)
  } elseif {[info exists ::CMR_INNER_OPM_E_MAX_NS] && $::CMR_INNER_OPM_E_MAX_NS > 0.0} {
    set max_ns $::CMR_INNER_OPM_E_MAX_NS
  }
  if {$max_ns eq ""} {
    return
  }
  if {$max_ns <= 0.0} {
    cmr_inner_fail invalid OPM E max $max_ns
  }
  set opms [cmr_inner_opms]
  foreach_in_collection opm $opms {
    set root [get_object_name $opm]
    set l5_q [get_pins -quiet "$root/L5/resettable_latch\[0\].latch_cell/Q"]
    set data_e [get_pins -quiet "$root/DataReg/resettable_latch\[*\].latch_cell/E"]
    if {[sizeof_collection $l5_q] != 1 || [sizeof_collection $data_e] < 1} {
      cmr_inner_fail opm_e_bind inst=$root l5_q=[sizeof_collection $l5_q] data_e=[sizeof_collection $data_e]
    }
    # Max-delay only.  Do not set_min_delay and do not insert_buffer on
    # DataReg.E / L5.E: shared RegEnable; buffers desynchronize V2.
    set_max_delay $max_ns -from $l5_q -to $data_e
    incr ::CMR_INNER_OPM_E_N
    puts "CMR_INNER_OPM_E_MAX inst=$root max_ns=$max_ns from=L5.Q to=DataReg.E (no min-delay)"
  }
  if {$::CMR_INNER_OPM_E_N != 25} {
    cmr_inner_fail opm_e_applied $::CMR_INNER_OPM_E_N
  }
}

set inner_fd [open "$inner_report_dir/inner_constraints_precompile.rpt" w]
puts $inner_fd "id,instance,min_ns,max_ns,from_count,to_count,note"
set ::inner_fd $inner_fd

puts "CMR_INNER_INCREMENTAL class=$::CMR_INNER_CLASS rtm=$::CMR_INNER_RTM extra_slack=$::CMR_INNER_EXTRA_SLACK_NS"

switch -- $::CMR_INNER_CLASS {
  CMR-OPM-01 -
  OPM-01 {
    set ::CMR_INNER_CLASS CMR-OPM-01
    cmr_inner_apply_opm01
  }
  CMR-RCU-01 -
  RCU-01 {
    set ::CMR_INNER_CLASS CMR-RCU-01
    cmr_inner_apply_rcu01
  }
  CMR-AR-01 -
  AR-01 {
    set ::CMR_INNER_CLASS CMR-AR-01
    cmr_inner_apply_ar01
  }
  CMR-OUTER-RTM5 -
  OUTER-RTM5 -
  OUTER {
    set ::CMR_INNER_CLASS CMR-OUTER-RTM5
    cmr_inner_apply_opm01
    cmr_inner_apply_rcu01
    cmr_inner_apply_ar01
  }
  default {
    close $inner_fd
    cmr_inner_fail unsupported_class $::CMR_INNER_CLASS
  }
}

cmr_inner_apply_opm_e_max

close $inner_fd
puts "CMR_INNER_CONSTRAINT_COUNT=$::CMR_INNER_APPLIED class=$::CMR_INNER_CLASS OPM=$::CMR_INNER_OPM_N RCU=$::CMR_INNER_RCU_N AR=$::CMR_INNER_AR_N E_MAX=$::CMR_INNER_OPM_E_N SKIP=$::CMR_INNER_SKIP"

if {$::CMR_INNER_CLASS eq "CMR-OPM-01" && $::CMR_INNER_APPLIED != 25} {
  cmr_inner_fail opm_pair_count $::CMR_INNER_APPLIED expected=25
}
if {$::CMR_INNER_CLASS eq "CMR-RCU-01" && $::CMR_INNER_APPLIED != 100} {
  cmr_inner_fail rcu_pair_count $::CMR_INNER_APPLIED expected=100
}
if {$::CMR_INNER_CLASS eq "CMR-AR-01" && $::CMR_INNER_APPLIED == 0 && $::CMR_INNER_SKIP != 25} {
  cmr_inner_fail ar_neither_applied_nor_floor_skip applied=$::CMR_INNER_APPLIED skip=$::CMR_INNER_SKIP
}
if {$::CMR_INNER_CLASS eq "CMR-OUTER-RTM5"} {
  if {$::CMR_INNER_OPM_N != 25 || $::CMR_INNER_RCU_N != 25} {
    cmr_inner_fail outer_opm_rcu OPM=$::CMR_INNER_OPM_N RCU=$::CMR_INNER_RCU_N
  }
  if {$::CMR_INNER_APPLIED != 125} {
    cmr_inner_fail outer_pair_count $::CMR_INNER_APPLIED expected=125
  }
}

proc cmr_inner_report {path} {
  set fd [open $path w]
  puts $fd "id,instance,min_ns,max_ns,note"
  foreach quad $::CMR_INNER_PAIRS {
    puts $fd [join $quad ,]
  }
  close $fd
  set json [file join [file dirname $path] inner_loop_windows.json]
  set jf [open $json w]
  puts $jf "{"
  puts $jf "  \"class\": \"$::CMR_INNER_CLASS\","
  puts $jf "  \"rtm\": $::CMR_INNER_RTM,"
  puts $jf "  \"applied\": $::CMR_INNER_APPLIED,"
  puts $jf "  \"skipped\": $::CMR_INNER_SKIP,"
  puts $jf "  \"opm_sites\": $::CMR_INNER_OPM_N,"
  puts $jf "  \"rcu_sites\": $::CMR_INNER_RCU_N,"
  puts $jf "  \"ar_sites\": $::CMR_INNER_AR_N,"
  puts $jf "  \"opm_e_sites\": $::CMR_INNER_OPM_E_N"
  puts $jf "}"
  close $jf
  puts "CMR_INNER_TCTRL_REPORT $path pairs=[llength $::CMR_INNER_PAIRS] json=$json"
  puts "CMR_INNER_PASS class=$::CMR_INNER_CLASS applied=$::CMR_INNER_APPLIED e_max=$::CMR_INNER_OPM_E_N skip=$::CMR_INNER_SKIP"
}
