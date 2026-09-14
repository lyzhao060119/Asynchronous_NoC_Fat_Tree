# Step G NoC-link overlay for the thin CircularFIFO NoC16 DDC.
#
# Sourced after datapath + inner (CMR-OUTER-RTM5) overlays.  Router inner
# windows stay frozen.  Order inside this file:
#   1. set_max_delay on link data cones (freeze Data)
#   2. set_min_delay / finite max on exported Req only
#   3. Ack-return as a separate class: freeze Reqout->ReadCounter CP,
#      then min-delay IPM Ackout->CP (not OPM Ackin DEL, not Req)
#
# CMR_LINK_PHASE = datapath | req | ack | all
# No set_disable_timing.  No DEL resize.  No min-delay on ReqLatch Q
# (that node also feeds EmptyEnable).  Req control is bb.Reqout / OPM
# io_Reqout only.  OPM Ackin DEL is not this overlay's Tctrl.

if {![info exists ::CMR_INNER_APPLIED] || $::CMR_INNER_APPLIED < 125} {
  puts "CMR_LINK_FAIL inner overlay must close OUTER-RTM5 first"
  exit 2
}
if {![info exists ::env(CMR_LINK_TARGET_FILE)] ||
    ![file exists $::env(CMR_LINK_TARGET_FILE)]} {
  puts "CMR_LINK_FAIL missing target file"
  exit 2
}
source $::env(CMR_LINK_TARGET_FILE)

if {![info exists ::CMR_LINK_FWD_01_TDATA_NS]} { set ::CMR_LINK_FWD_01_TDATA_NS 0.0 }
if {![info exists ::CMR_LINK_FWD_01_MIN_NS]} { set ::CMR_LINK_FWD_01_MIN_NS 0.0 }
if {![info exists ::CMR_LINK_FWD_01_MAX_NS]} { set ::CMR_LINK_FWD_01_MAX_NS 0.0 }
if {![info exists ::CMR_LINK_ENQ_01_TDATA_NS]} { set ::CMR_LINK_ENQ_01_TDATA_NS 0.0 }
if {![info exists ::CMR_LINK_ENQ_01_MIN_NS]} { set ::CMR_LINK_ENQ_01_MIN_NS 0.0 }
if {![info exists ::CMR_LINK_ENQ_01_MAX_NS]} { set ::CMR_LINK_ENQ_01_MAX_NS 0.0 }
if {![info exists ::CMR_LINK_IO_01_TDATA_NS]} { set ::CMR_LINK_IO_01_TDATA_NS 0.0 }
if {![info exists ::CMR_LINK_IO_01_MIN_NS]} { set ::CMR_LINK_IO_01_MIN_NS 0.0 }
if {![info exists ::CMR_LINK_IO_01_MAX_NS]} { set ::CMR_LINK_IO_01_MAX_NS 0.0 }
if {![info exists ::CMR_LINK_ACK_01_TDATA_NS]} { set ::CMR_LINK_ACK_01_TDATA_NS 0.0 }
if {![info exists ::CMR_LINK_ACK_01_MIN_NS]} { set ::CMR_LINK_ACK_01_MIN_NS 0.0 }
if {![info exists ::CMR_LINK_ACK_01_MAX_NS]} { set ::CMR_LINK_ACK_01_MAX_NS 0.0 }

if {[info exists ::env(CMR_LINK_PHASE)] && $::env(CMR_LINK_PHASE) ne ""} {
  set ::CMR_LINK_PHASE $::env(CMR_LINK_PHASE)
}
if {![info exists ::CMR_LINK_PHASE] || $::CMR_LINK_PHASE eq ""} {
  set ::CMR_LINK_PHASE all
}
if {![info exists ::CMR_LINK_RTM]} { set ::CMR_LINK_RTM 0.05 }
if {![info exists ::CMR_LINK_EXTRA_SLACK_NS]} { set ::CMR_LINK_EXTRA_SLACK_NS 0.100 }
if {![info exists ::CMR_LINK_NEAR_FLOOR_NS]} { set ::CMR_LINK_NEAR_FLOOR_NS 0.020 }

if {[info exists ::env(CMR_LINK_REPORT_DIR)] && $::env(CMR_LINK_REPORT_DIR) ne ""} {
  set link_report_dir $::env(CMR_LINK_REPORT_DIR)
} elseif {[info exists ::env(CMR_INNER_REPORT_DIR)] && $::env(CMR_INNER_REPORT_DIR) ne ""} {
  set link_report_dir $::env(CMR_INNER_REPORT_DIR)
} elseif {[info exists REPORT_DIR]} {
  set link_report_dir $REPORT_DIR
} else {
  puts "CMR_LINK_FAIL missing_report_dir"
  exit 2
}
file mkdir $link_report_dir

set ::CMR_LINK_APPLIED 0
set ::CMR_LINK_SKIP 0
set ::CMR_LINK_DATA_N 0
set ::CMR_LINK_REQ_N 0
set ::CMR_LINK_ACK_N 0
set ::CMR_LINK_PAIRS [list]

proc cmr_link_fail {args} {
  puts "CMR_LINK_FAIL [join $args { }]"
  exit 2
}

proc cmr_link_do_data {} {
  return [expr {$::CMR_LINK_PHASE eq "datapath" || $::CMR_LINK_PHASE eq "all" ||
    $::CMR_LINK_PHASE eq "req" || $::CMR_LINK_PHASE eq "ack"}]
}

proc cmr_link_do_req {} {
  return [expr {$::CMR_LINK_PHASE eq "req" || $::CMR_LINK_PHASE eq "all" ||
    $::CMR_LINK_PHASE eq "ack"}]
}

proc cmr_link_do_ack {} {
  return [expr {$::CMR_LINK_PHASE eq "ack" || $::CMR_LINK_PHASE eq "all"}]
}

proc cmr_link_measure {from to dtype} {
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

proc cmr_link_window {fixed_min fixed_max tdata} {
  set min_ns $fixed_min
  set max_ns $fixed_max
  if {$min_ns <= 0.0} {
    if {$tdata < 0.0} {
      set tdata 0.0
    }
    if {$tdata < $::CMR_LINK_NEAR_FLOOR_NS} {
      return [list 0.0 0.0 SKIP]
    }
    set min_ns [expr {double($tdata) * (1.0 + $::CMR_LINK_RTM)}]
    set max_ns [expr {$min_ns + $::CMR_LINK_EXTRA_SLACK_NS}]
  }
  return [list $min_ns $max_ns OK]
}

proc cmr_link_apply_max {id inst from to target_ns note} {
  set fc [sizeof_collection $from]
  set tc [sizeof_collection $to]
  if {$fc == 0 || $tc == 0} {
    puts $::link_fd "$id,$inst,max,$target_ns,NA,$fc,$tc,NO_BIND $note"
    close $::link_fd
    cmr_link_fail bind id=$id inst=$inst from=$fc to=$tc
  }
  if {$target_ns <= 0.0} {
    puts $::link_fd "$id,$inst,max,$target_ns,NA,$fc,$tc,SKIP $note"
    incr ::CMR_LINK_SKIP
    return 0
  }
  set_max_delay $target_ns -from $from -to $to
  incr ::CMR_LINK_APPLIED
  incr ::CMR_LINK_DATA_N
  lappend ::CMR_LINK_PAIRS [list $id $inst max $target_ns NA $note]
  puts $::link_fd "$id,$inst,max,$target_ns,NA,$fc,$tc,$note"
  puts "CMR_LINK_CONSTRAINT id=$id inst=$inst max_ns=$target_ns from=$fc to=$tc $note"
  return 1
}

proc cmr_link_apply_minmax {id inst from to min_ns max_ns note} {
  set fc [sizeof_collection $from]
  set tc [sizeof_collection $to]
  if {$fc == 0 || $tc == 0} {
    puts $::link_fd "$id,$inst,minmax,$min_ns,$max_ns,$fc,$tc,NO_BIND $note"
    close $::link_fd
    cmr_link_fail bind id=$id inst=$inst from=$fc to=$tc
  }
  if {$min_ns <= 0.0 || $max_ns < $min_ns} {
    puts $::link_fd "$id,$inst,minmax,$min_ns,$max_ns,$fc,$tc,SKIP $note"
    incr ::CMR_LINK_SKIP
    return 0
  }
  set_min_delay $min_ns -from $from -to $to
  set_max_delay $max_ns -from $from -to $to
  incr ::CMR_LINK_APPLIED
  lappend ::CMR_LINK_PAIRS [list $id $inst minmax $min_ns $max_ns $note]
  puts $::link_fd "$id,$inst,minmax,$min_ns,$max_ns,$fc,$tc,$note"
  puts "CMR_LINK_CONSTRAINT id=$id inst=$inst min_ns=$min_ns max_ns=$max_ns from=$fc to=$tc $note"
  return 1
}

proc cmr_link_fifo_sites {} {
  # bb, dir_tag, dir, src_opm, dst_ipm
  return [list \
    [list upwardLinkFifos_0/bb up 0 routerL1_1_1/OutputPortModules_4 routerL2/InputPortModules_0] \
    [list upwardLinkFifos_1/bb up 1 routerL1_1_0/OutputPortModules_4 routerL2/InputPortModules_1] \
    [list upwardLinkFifos_2/bb up 2 routerL1_0_1/OutputPortModules_4 routerL2/InputPortModules_2] \
    [list upwardLinkFifos_3/bb up 3 routerL1_0_0/OutputPortModules_4 routerL2/InputPortModules_3] \
    [list downwardLinkFifos_0/bb down 0 routerL2/OutputPortModules_0 routerL1_1_1/InputPortModules_4] \
    [list downwardLinkFifos_1/bb down 1 routerL2/OutputPortModules_1 routerL1_1_0/InputPortModules_4] \
    [list downwardLinkFifos_2/bb down 2 routerL2/OutputPortModules_2 routerL1_0_1/InputPortModules_4] \
    [list downwardLinkFifos_3/bb down 3 routerL2/OutputPortModules_3 routerL1_0_0/InputPortModules_4] \
  ]
}

proc cmr_link_core_sites {} {
  set sites {}
  for {set x 0} {$x < 2} {incr x} {
    for {set y 0} {$y < 2} {incr y} {
      for {set dir 0} {$dir < 4} {incr dir} {
        set selector [expr {(~$dir) & 3}]
        set localX [expr {($selector >> 1) & 1}]
        set localY [expr {$selector & 1}]
        set core [expr {2 * $x + $localX + 4 * (2 * $y + $localY)}]
        lappend sites [list $core routerL1_${x}_${y} InputPortModules_$dir OutputPortModules_$dir core]
      }
    }
  }
  lappend sites [list 0 routerL2 InputPortModules_4 OutputPortModules_4 top]
  return $sites
}

proc cmr_link_pins {cell filt} {
  if {$cell eq ""} {
    return [get_pins -quiet __cmr_link_no_pin__]
  }
  set obj [get_cells -quiet $cell]
  if {[sizeof_collection $obj] != 1} {
    return [get_pins -quiet __cmr_link_no_pin__]
  }
  return [get_pins -quiet -of_objects $obj -filter $filt]
}

proc cmr_link_read_counter_cp {bb} {
  set cps [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter* && name == CP"]
  if {[sizeof_collection $cps] == 0} {
    set cps [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter* && name == CK"]
  }
  return $cps
}

proc cmr_link_counter_req {bb} {
  set p [get_pins -quiet $bb/read_counter/Reqout]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/Reqout"]
  }
  return $p
}

proc cmr_link_xnor_a1 {bb} {
  set p [get_pins -quiet $bb/read_counter/U10/A1]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/U10/A1"]
  }
  return $p
}

proc cmr_link_xnor_req_pin {bb} {
  set p [get_pins -quiet $bb/read_counter/U10/A2]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/U10/A2"]
  }
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -quiet -of_objects [get_cells -quiet $bb/read_counter/U10] -filter {name == Z || name == ZN}]
  }
  return $p
}

proc cmr_link_port {name} {
  set p [get_ports -quiet $name]
  if {[sizeof_collection $p] == 0} {
    set p [get_ports -quiet ${name}*]
  }
  return $p
}

proc cmr_link_apply_fwd {} {
  if {![info exists ::CMR_LINK_FWD_01_MIN_NS]} { set ::CMR_LINK_FWD_01_MIN_NS 0.0 }
  if {![info exists ::CMR_LINK_FWD_01_MAX_NS]} { set ::CMR_LINK_FWD_01_MAX_NS 0.0 }
  set n 0
  foreach site [cmr_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set ipm [lindex $site 4]
    set fifo [get_cells -quiet $bb]
    if {[sizeof_collection $fifo] != 1} {
      cmr_link_fail fifo_bind $bb
    }
    set data_out [cmr_link_pins $bb {name =~ Data_out*}]
    set reqout [cmr_link_pins $bb {name == Reqout}]
    set datain [cmr_link_pins $ipm {name =~ io_Datain_flit*}]
    set reqin [cmr_link_pins $ipm {name == io_Reqin}]
    if {[sizeof_collection $data_out] == 0 || [sizeof_collection $datain] == 0} {
      cmr_link_fail fwd_data_bind $bb data_out=[sizeof_collection $data_out] datain=[sizeof_collection $datain]
    }
    if {[sizeof_collection $reqout] != 1 || [sizeof_collection $reqin] != 1} {
      cmr_link_fail fwd_req_bind $bb reqout=[sizeof_collection $reqout] reqin=[sizeof_collection $reqin]
    }
    set inst ${bb}:${tag}${dir}
    set tdata [cmr_link_measure $data_out $datain max]
    if {[cmr_link_do_data]} {
      set target $::CMR_LINK_FWD_01_TDATA_NS
      if {$target <= 0.0} {
        if {$tdata >= $::CMR_LINK_NEAR_FLOOR_NS} {
          set target $tdata
        } else {
          set target 0.0
        }
      }
      set note "L1L2 FWD Data_out->IPM Datain; freeze data; $tag$dir"
      if {$tdata < $::CMR_LINK_NEAR_FLOOR_NS} {
        append note {; near-floor}
        incr ::CMR_LINK_SKIP
      } else {
        cmr_link_apply_max CMR-LINK-FWD-01 $inst $data_out $datain $target $note
      }
    }
    if {[cmr_link_do_req]} {
      set win [cmr_link_window $::CMR_LINK_FWD_01_MIN_NS $::CMR_LINK_FWD_01_MAX_NS $tdata]
      set min_ns [lindex $win 0]
      set max_ns [lindex $win 1]
      set st [lindex $win 2]
      set note "exported Reqout->IPM Reqin only; not ReqLatch Q; $tag$dir"
      if {$st eq "SKIP"} {
        puts $::link_fd "CMR-LINK-FWD-01,$inst,minmax,0,0,1,1,SKIP_NEAR_FLOOR tdata=$tdata $note"
        puts "CMR_LINK_SKIP id=CMR-LINK-FWD-01 inst=$inst near_floor tdata=$tdata"
        incr ::CMR_LINK_SKIP
      } else {
        if {[cmr_link_apply_minmax CMR-LINK-FWD-01 $inst $reqout $reqin $min_ns $max_ns $note]} {
          incr ::CMR_LINK_REQ_N
        }
      }
    }
    incr n
  }
  if {$n != 8} {
    cmr_link_fail fwd_count $n
  }
}

proc cmr_link_apply_enq {} {
  if {![info exists ::CMR_LINK_ENQ_01_MIN_NS]} { set ::CMR_LINK_ENQ_01_MIN_NS 0.0 }
  if {![info exists ::CMR_LINK_ENQ_01_MAX_NS]} { set ::CMR_LINK_ENQ_01_MAX_NS 0.0 }
  set n 0
  foreach site [cmr_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set opm [lindex $site 3]
    set dataout [cmr_link_pins $opm {name =~ io_Dataout_flit*}]
    set reqout [cmr_link_pins $opm {name == io_Reqout}]
    set data_in [cmr_link_pins $bb {name =~ Data_in*}]
    set reqin [cmr_link_pins $bb {name == Reqin}]
    if {[sizeof_collection $dataout] == 0 || [sizeof_collection $data_in] == 0} {
      cmr_link_fail enq_data_bind $bb dataout=[sizeof_collection $dataout] data_in=[sizeof_collection $data_in]
    }
    if {[sizeof_collection $reqout] != 1 || [sizeof_collection $reqin] != 1} {
      cmr_link_fail enq_req_bind $bb reqout=[sizeof_collection $reqout] reqin=[sizeof_collection $reqin]
    }
    set inst ${bb}:${tag}${dir}
    set tdata [cmr_link_measure $dataout $data_in max]
    if {[cmr_link_do_data]} {
      set target $::CMR_LINK_ENQ_01_TDATA_NS
      if {$target <= 0.0} {
        if {$tdata >= $::CMR_LINK_NEAR_FLOOR_NS} {
          set target $tdata
        } else {
          set target 0.0
        }
      }
      set note "OPM Dataout->FIFO Data_in; freeze data; $tag$dir"
      if {$tdata < $::CMR_LINK_NEAR_FLOOR_NS} {
        append note {; near-floor}
        incr ::CMR_LINK_SKIP
        puts $::link_fd "CMR-LINK-ENQ-01,$inst,max,0,$tdata,[sizeof_collection $dataout],[sizeof_collection $data_in],SKIP $note"
      } else {
        cmr_link_apply_max CMR-LINK-ENQ-01 $inst $dataout $data_in $target $note
      }
    }
    if {[cmr_link_do_req]} {
      set win [cmr_link_window $::CMR_LINK_ENQ_01_MIN_NS $::CMR_LINK_ENQ_01_MAX_NS $tdata]
      set min_ns [lindex $win 0]
      set max_ns [lindex $win 1]
      set st [lindex $win 2]
      set note "OPM Reqout->FIFO Reqin; not DataReg.E; $tag$dir"
      if {$st eq "SKIP"} {
        puts $::link_fd "CMR-LINK-ENQ-01,$inst,minmax,0,0,1,1,SKIP_NEAR_FLOOR tdata=$tdata $note"
        puts "CMR_LINK_SKIP id=CMR-LINK-ENQ-01 inst=$inst near_floor tdata=$tdata"
        incr ::CMR_LINK_SKIP
      } else {
        if {[cmr_link_apply_minmax CMR-LINK-ENQ-01 $inst $reqout $reqin $min_ns $max_ns $note]} {
          incr ::CMR_LINK_REQ_N
        }
      }
    }
    incr n
  }
  if {$n != 8} {
    cmr_link_fail enq_count $n
  }
}

proc cmr_link_apply_io {} {
  if {![info exists ::CMR_LINK_IO_01_MIN_NS]} { set ::CMR_LINK_IO_01_MIN_NS 0.0 }
  if {![info exists ::CMR_LINK_IO_01_MAX_NS]} { set ::CMR_LINK_IO_01_MAX_NS 0.0 }
  set n 0
  foreach site [cmr_link_core_sites] {
    set idx [lindex $site 0]
    set router [lindex $site 1]
    set ipm_leaf [lindex $site 2]
    set opm_leaf [lindex $site 3]
    set kind [lindex $site 4]
    if {$kind eq "core"} {
      set dport io_core_inputs_${idx}_Data_flit
      set rport io_core_inputs_${idx}_HS_Req
      set dout io_core_outputs_${idx}_Data_flit
      set rout io_core_outputs_${idx}_HS_Req
    } else {
      set dport io_top_input_${idx}_Data_flit
      set rport io_top_input_${idx}_HS_Req
      set dout io_top_output_${idx}_Data_flit
      set rout io_top_output_${idx}_HS_Req
    }
    set ipm ${router}/${ipm_leaf}
    set opm ${router}/${opm_leaf}
    set data_in [cmr_link_port $dport]
    set req_in [cmr_link_port $rport]
    set data_out [cmr_link_port $dout]
    set req_out [cmr_link_port $rout]
    set ipm_d [cmr_link_pins $ipm {name =~ io_Datain_flit*}]
    set ipm_r [cmr_link_pins $ipm {name == io_Reqin}]
    set opm_d [cmr_link_pins $opm {name =~ io_Dataout_flit*}]
    set opm_r [cmr_link_pins $opm {name == io_Reqout}]
    set inst ${kind}${idx}:${router}
    if {[sizeof_collection $data_in] == 0 || [sizeof_collection $ipm_d] == 0 ||
        [sizeof_collection $req_in] != 1 || [sizeof_collection $ipm_r] != 1} {
      cmr_link_fail io_src_bind $inst din=[sizeof_collection $data_in] ipm_d=[sizeof_collection $ipm_d]
    }
    if {[sizeof_collection $data_out] == 0 || [sizeof_collection $opm_d] == 0 ||
        [sizeof_collection $req_out] != 1 || [sizeof_collection $opm_r] != 1} {
      cmr_link_fail io_snk_bind $inst dout=[sizeof_collection $data_out] opm_d=[sizeof_collection $opm_d]
    }
    foreach pair [list \
      [list src $data_in $ipm_d $req_in $ipm_r "source Data->IPM Datain / Req->IPM Reqin"] \
      [list snk $opm_d $data_out $opm_r $req_out "sink OPM Dataout->port / Reqout->port"] \
    ] {
      set site_id [lindex $pair 0]
      set df [lindex $pair 1]
      set dt [lindex $pair 2]
      set cf [lindex $pair 3]
      set ct [lindex $pair 4]
      set note [lindex $pair 5]
      set tdata [cmr_link_measure $df $dt max]
      if {[cmr_link_do_data]} {
        set target $::CMR_LINK_IO_01_TDATA_NS
        if {$target <= 0.0} {
          if {$tdata >= $::CMR_LINK_NEAR_FLOOR_NS} {
            set target $tdata
          } else {
            set target 0.0
          }
        }
        if {$tdata < $::CMR_LINK_NEAR_FLOOR_NS} {
          puts $::link_fd "CMR-LINK-IO-01,${inst}:${site_id},max,0,$tdata,[sizeof_collection $df],[sizeof_collection $dt],SKIP_NEAR_FLOOR $note"
          incr ::CMR_LINK_SKIP
        } else {
          cmr_link_apply_max CMR-LINK-IO-01 ${inst}:${site_id} $df $dt $target $note
        }
      }
      if {[cmr_link_do_req]} {
        set win [cmr_link_window $::CMR_LINK_IO_01_MIN_NS $::CMR_LINK_IO_01_MAX_NS $tdata]
        set min_ns [lindex $win 0]
        set max_ns [lindex $win 1]
        set st [lindex $win 2]
        if {$st eq "SKIP"} {
          puts $::link_fd "CMR-LINK-IO-01,${inst}:${site_id},minmax,0,0,1,1,SKIP_NEAR_FLOOR tdata=$tdata $note"
          incr ::CMR_LINK_SKIP
        } else {
          if {[cmr_link_apply_minmax CMR-LINK-IO-01 ${inst}:${site_id} $cf $ct $min_ns $max_ns $note]} {
            incr ::CMR_LINK_REQ_N
          }
        }
      }
    }
    incr n
  }
  if {$n != 17} {
    cmr_link_fail io_count $n
  }
}

proc cmr_link_apply_ack {} {
  if {![info exists ::CMR_LINK_ACK_01_MIN_NS]} { set ::CMR_LINK_ACK_01_MIN_NS 0.0 }
  if {![info exists ::CMR_LINK_ACK_01_MAX_NS]} { set ::CMR_LINK_ACK_01_MAX_NS 0.0 }
  set n 0
  foreach site [cmr_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set ipm [lindex $site 4]
    set reqout [cmr_link_counter_req $bb]
    set ackout [cmr_link_pins $ipm {name == io_Ackout}]
    set xnor_req [cmr_link_xnor_req_pin $bb]
    set xnor_a1 [cmr_link_xnor_a1 $bb]
    if {[sizeof_collection $reqout] != 1 || [sizeof_collection $ackout] != 1 ||
        [sizeof_collection $xnor_req] == 0 || [sizeof_collection $xnor_a1] != 1} {
      cmr_link_fail ack_bind $bb req=[sizeof_collection $reqout] ackout=[sizeof_collection $ackout] xnor_req=[sizeof_collection $xnor_req] a1=[sizeof_collection $xnor_a1]
    }
    set inst ${bb}:${tag}${dir}
    # Tdata is counter Reqout -> XNOR A2.  bb.Reqout is an output pin and
    # does not path back to CP.  U10/A1 is the TCF-HS-02 ECO load.
    set tdata [cmr_link_measure $reqout $xnor_req max]
    if {[cmr_link_do_data]} {
      set target $::CMR_LINK_ACK_01_TDATA_NS
      if {$target <= 0.0} {
        if {$tdata >= $::CMR_LINK_NEAR_FLOOR_NS} {
          set target $tdata
        } else {
          set target 0.0
        }
      }
      set note "freeze read_counter/Reqout->U10/A2; not OPM Ackin DEL; $tag$dir"
      if {$tdata < $::CMR_LINK_NEAR_FLOOR_NS} {
        puts $::link_fd "CMR-LINK-ACK-01,$inst,max,0,$tdata,1,[sizeof_collection $xnor_req],SKIP_NEAR_FLOOR $note"
        incr ::CMR_LINK_SKIP
      } else {
        cmr_link_apply_max CMR-LINK-ACK-01 $inst $reqout $xnor_req $target $note
      }
    }
    set win [cmr_link_window $::CMR_LINK_ACK_01_MIN_NS $::CMR_LINK_ACK_01_MAX_NS $tdata]
    set min_ns [lindex $win 0]
    set max_ns [lindex $win 1]
    set st [lindex $win 2]
    set note "IPM Ackout->U10/A1; includes L1L2 Ack wire + TCF-HS-02; not Ackin DEL shrink; $tag$dir"
    if {$st eq "SKIP"} {
      puts $::link_fd "CMR-LINK-ACK-01,$inst,minmax,0,0,1,1,SKIP_NEAR_FLOOR tdata=$tdata $note"
      puts "CMR_LINK_SKIP id=CMR-LINK-ACK-01 inst=$inst near_floor tdata=$tdata"
      incr ::CMR_LINK_SKIP
    } else {
      if {[cmr_link_apply_minmax CMR-LINK-ACK-01 $inst $ackout $xnor_a1 $min_ns $max_ns $note]} {
        incr ::CMR_LINK_ACK_N
      }
    }
    incr n
  }
  if {$n != 8} {
    cmr_link_fail ack_count $n
  }
}

set link_fd [open "$link_report_dir/link_constraints_precompile.rpt" w]
puts $link_fd "id,instance,kind,min_or_max_ns,max_ns,from_count,to_count,note"
set ::link_fd $link_fd

puts "CMR_LINK_INCREMENTAL phase=$::CMR_LINK_PHASE rtm=$::CMR_LINK_RTM extra_slack=$::CMR_LINK_EXTRA_SLACK_NS"

cmr_link_apply_fwd
cmr_link_apply_enq
cmr_link_apply_io
if {[cmr_link_do_ack]} {
  cmr_link_apply_ack
}

close $link_fd
puts "CMR_LINK_CONSTRAINT_COUNT=$::CMR_LINK_APPLIED DATA=$::CMR_LINK_DATA_N REQ=$::CMR_LINK_REQ_N ACK=$::CMR_LINK_ACK_N SKIP=$::CMR_LINK_SKIP"

proc cmr_link_report {path} {
  set fd [open $path w]
  puts $fd "id,instance,kind,a_ns,b_ns,note"
  foreach row $::CMR_LINK_PAIRS {
    puts $fd [join $row ,]
  }
  close $fd
  set json [file join [file dirname $path] link_loop_windows.json]
  set jf [open $json w]
  puts $jf "{"
  puts $jf "  \"phase\": \"$::CMR_LINK_PHASE\","
  puts $jf "  \"rtm\": $::CMR_LINK_RTM,"
  puts $jf "  \"applied\": $::CMR_LINK_APPLIED,"
  puts $jf "  \"skipped\": $::CMR_LINK_SKIP,"
  puts $jf "  \"data_sites\": $::CMR_LINK_DATA_N,"
  puts $jf "  \"req_sites\": $::CMR_LINK_REQ_N,"
  puts $jf "  \"ack_sites\": $::CMR_LINK_ACK_N,"
  puts $jf "  \"synth_closed\": true,"
  puts $jf "  \"phys_closed\": false"
  puts $jf "}"
  close $jf
  puts "CMR_LINK_TCTRL_REPORT $path pairs=[llength $::CMR_LINK_PAIRS] json=$json"
  puts "CMR_LINK_PASS phase=$::CMR_LINK_PHASE applied=$::CMR_LINK_APPLIED skip=$::CMR_LINK_SKIP"
}
