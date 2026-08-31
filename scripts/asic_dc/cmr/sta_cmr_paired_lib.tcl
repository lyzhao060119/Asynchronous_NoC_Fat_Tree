# Analysis-only helpers for CMR step-C paired STA on a frozen DDC.
# Dummy set_max_delay / set_min_delay windows exist so unconstrained combo
# paths still report arrival.  They must not be copied into production SDC.
# Loop cuts are set_disable_timing only and must be removed before the next ID.

set CMR_STA_WINDOW_NS 20.0

proc cmr_sta_empty {} {
  return [get_pins -quiet __cmr_sta_no_such_pin__]
}

proc cmr_sta_csv_escape {s} {
  if {[string match "*,*" $s] || [string match "*\"*" $s]} {
    return "\"[string map {\" \"\"} $s]\""
  }
  return $s
}

proc cmr_sta_open_csv {path} {
  set ::CMR_PAIRED_CSV_PATH $path
  set ::CMR_PAIRED_CSV [open $path w]
  puts $::CMR_PAIRED_CSV "id,instance,site,edge,tdata_max_ns,tctrl_min_ns,rtm_pct,shortfall_ns,no_path,loop_cut,data_from,data_to,ctrl_from,ctrl_to,notes"
}

proc cmr_sta_close_csv {} {
  if {[info exists ::CMR_PAIRED_CSV]} {
    close $::CMR_PAIRED_CSV
    unset ::CMR_PAIRED_CSV
  }
}

proc cmr_sta_apply_window {from to} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return
  }
  catch { set_max_delay $::CMR_STA_WINDOW_NS -from $from -to $to }
  catch { set_min_delay 0.0 -from $from -to $to }
}

proc cmr_sta_reset_window {from to} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return
  }
  catch { reset_path -from $from -to $to }
}

proc cmr_sta_paths {from to dtype edge {through ""}} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return [cmr_sta_empty]
  }
  set has_through [expr {$through ne "" && [sizeof_collection $through] > 0}]
  if {[catch {
    if {$edge eq "rise"} {
      if {$has_through} {
        set paths [get_timing_paths -from $from -through $through -rise_to $to -delay_type $dtype -max_paths 16 -nworst 1]
      } else {
        set paths [get_timing_paths -from $from -rise_to $to -delay_type $dtype -max_paths 16 -nworst 1]
      }
    } elseif {$edge eq "fall"} {
      if {$has_through} {
        set paths [get_timing_paths -from $from -through $through -fall_to $to -delay_type $dtype -max_paths 16 -nworst 1]
      } else {
        set paths [get_timing_paths -from $from -fall_to $to -delay_type $dtype -max_paths 16 -nworst 1]
      }
    } else {
      if {$has_through} {
        set paths [get_timing_paths -from $from -through $through -to $to -delay_type $dtype -max_paths 16 -nworst 1]
      } else {
        set paths [get_timing_paths -from $from -to $to -delay_type $dtype -max_paths 16 -nworst 1]
      }
    }
  } err]} {
    puts "CMR_PAIRED_WARN paths edge=$edge through=$has_through err=$err"
    set paths [cmr_sta_empty]
  }
  # Combinational XNOR/buffer pins often have no rise/fall sense.  Retry
  # plain -to before calling the path a miss.
  if {![info exists paths] || [sizeof_collection $paths] == 0} {
    if {[catch {
      if {$has_through} {
        set paths [get_timing_paths -from $from -through $through -to $to -delay_type $dtype -max_paths 16 -nworst 1]
      } else {
        set paths [get_timing_paths -from $from -to $to -delay_type $dtype -max_paths 16 -nworst 1]
      }
    } err2]} {
      puts "CMR_PAIRED_WARN paths_fallback err=$err2"
      return [cmr_sta_empty]
    }
  }
  if {![info exists paths]} {
    return [cmr_sta_empty]
  }
  return $paths
}

proc cmr_sta_worst {from to dtype edge {through ""}} {
  set paths [cmr_sta_paths $from $to $dtype $edge $through]
  if {$through ne "" && [sizeof_collection $paths] == 0} {
    set paths [cmr_sta_paths $from $to $dtype $edge ""]
  }
  if {[sizeof_collection $paths] == 0} {
    return NO_PATH
  }
  set worst ""
  foreach_in_collection p $paths {
    set arr [get_attribute $p arrival]
    if {$arr eq "" || ![string is double -strict $arr]} {
      continue
    }
    if {$worst eq ""} {
      set worst $arr
    } elseif {$dtype eq "max" && $arr > $worst} {
      set worst $arr
    } elseif {$dtype eq "min" && $arr < $worst} {
      set worst $arr
    }
  }
  if {$worst eq ""} {
    return NO_PATH
  }
  return $worst
}

proc cmr_sta_dump {path from to dtype edge {through ""}} {
  redirect $path {
    if {$through ne "" && [sizeof_collection $through] > 0} {
      if {$edge eq "rise"} {
        report_timing -from $from -through $through -rise_to $to -delay_type $dtype -nworst 1 -max_paths 1 -nosplit -input_pins -nets
      } elseif {$edge eq "fall"} {
        report_timing -from $from -through $through -fall_to $to -delay_type $dtype -nworst 1 -max_paths 1 -nosplit -input_pins -nets
      } else {
        report_timing -from $from -through $through -to $to -delay_type $dtype -nworst 1 -max_paths 1 -nosplit -input_pins -nets
      }
    } else {
      if {$edge eq "rise"} {
        report_timing -from $from -rise_to $to -delay_type $dtype -nworst 1 -max_paths 1 -nosplit -input_pins -nets
      } elseif {$edge eq "fall"} {
        report_timing -from $from -fall_to $to -delay_type $dtype -nworst 1 -max_paths 1 -nosplit -input_pins -nets
      } else {
        report_timing -from $from -to $to -delay_type $dtype -nworst 1 -max_paths 1 -nosplit -input_pins -nets
      }
    }
  }
}

proc cmr_sta_emit {id inst site edge tdata tctrl loop_cut data_from data_to ctrl_from ctrl_to notes} {
  set no_path 0
  set rtm "NA"
  set shortfall "NA"
  set tdata_out $tdata
  set tctrl_out $tctrl
  if {$tdata eq "NO_PATH" || $tctrl eq "NO_PATH"} {
    set no_path 1
  } else {
    if {$tdata > $::CMR_STA_WINDOW_NS - 1.0e-6 || $tctrl > $::CMR_STA_WINDOW_NS - 1.0e-6} {
      append notes {; WINDOW_CLIP}
    }
    set sf [expr {$tdata > $tctrl ? $tdata - $tctrl : 0.0}]
    if {$tdata == 0.0} {
      set rtm_val [expr {$tctrl > 0.0 ? 1.0e9 : 0.0}]
    } else {
      set rtm_val [expr {100.0 * ($tctrl - $tdata) / $tdata}]
    }
    set rtm [format "%.3f" $rtm_val]
    set shortfall [format "%.6f" $sf]
    set tdata_out [format "%.6f" $tdata]
    set tctrl_out [format "%.6f" $tctrl]
  }
  set line [join [list \
    $id \
    [cmr_sta_csv_escape $inst] \
    $site \
    $edge \
    $tdata_out \
    $tctrl_out \
    $rtm \
    $shortfall \
    $no_path \
    [cmr_sta_csv_escape $loop_cut] \
    [cmr_sta_csv_escape $data_from] \
    [cmr_sta_csv_escape $data_to] \
    [cmr_sta_csv_escape $ctrl_from] \
    [cmr_sta_csv_escape $ctrl_to] \
    [cmr_sta_csv_escape $notes] \
  ] ","]
  puts $::CMR_PAIRED_CSV $line
  flush $::CMR_PAIRED_CSV
  puts "CMR_PAIRED id=$id inst=$inst site=$site edge=$edge tdata_max=$tdata_out tctrl_min=$tctrl_out rtm_pct=$rtm shortfall=$shortfall no_path=$no_path"
}

proc cmr_sta_rcu_and_pins {root bit} {
  set candidates [list \
    "$root/RouteComputation/RouteSelAnd_${bit}/g/A1" \
    "$root/RouteComputationLogic/RouteSelAnd_${bit}/g/A1" \
    "$root/RouteSelAnd_${bit}/g/A1" \
  ]
  set anda ""
  foreach pat $candidates {
    set anda [get_pins -quiet $pat]
    if {[sizeof_collection $anda] == 1} {
      break
    }
  }
  if {[sizeof_collection $anda] != 1} {
    set anda [get_pins -quiet -hierarchical -filter "full_name =~ $root/*RouteSelAnd_${bit}*/g/A1 || full_name =~ $root/*RouteSelAnd_${bit}*/A1"]
  }
  set andz ""
  if {[sizeof_collection $anda] == 1} {
    set cell [get_cells -of_objects $anda]
    set andz [get_pins -quiet -of_objects $cell -filter {name == Z || name == ZN}]
  }
  return [list $anda $andz]
}

proc cmr_sta_measure_rcu01 {report_dir} {
  file mkdir "$report_dir/rcu01"
  set rcus [get_cells -hierarchical -quiet -filter {
    full_name =~ *InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*
  }]
  set rcu_n [sizeof_collection $rcus]
  set expected_rcus 25
  if {[info exists ::env(CMR_STA_EXPECTED_RCUS)] && $::env(CMR_STA_EXPECTED_RCUS) ne ""} {
    set expected_rcus $::env(CMR_STA_EXPECTED_RCUS)
  }
  puts "CMR_PAIRED_STRUCTURE id=CMR-RCU-01 rcus=$rcu_n expected=$expected_rcus"
  if {$rcu_n != $expected_rcus} {
    puts "CMR_PAIRED_FAIL id=CMR-RCU-01 expected $expected_rcus RCUs got $rcu_n"
    exit 2
  }

  set first 1
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set latches [get_cells -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell"]
    if {[sizeof_collection $latches] != 25} {
      puts "CMR_PAIRED_FAIL id=CMR-RCU-01 latches rcu=$root n=[sizeof_collection $latches]"
      exit 2
    }
    if {$first} {
      set all_latches $latches
      set first 0
    } else {
      set all_latches [add_to_collection $all_latches $latches]
    }
  }
  set_disable_timing $all_latches
  set loop_cut "disable AddressRegister LatchReg latch_cell (dest/req Q startpoints)"

  set dumped 0
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set req_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
    set dest_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/Q"]
    set dest_q [remove_from_collection $dest_q $req_q]
    if {[sizeof_collection $req_q] != 1 || [sizeof_collection $dest_q] != 24} {
      puts "CMR_PAIRED_FAIL id=CMR-RCU-01 qpins rcu=$root dest=[sizeof_collection $dest_q] req=[sizeof_collection $req_q]"
      exit 2
    }
    foreach bit {0 1 2 3} {
      set pins [cmr_sta_rcu_and_pins $root $bit]
      set anda [lindex $pins 0]
      set andz [lindex $pins 1]
      if {[sizeof_collection $anda] != 1 || [sizeof_collection $andz] != 1} {
        foreach edge {rise fall} {
          cmr_sta_emit CMR-RCU-01 $root bit$bit $edge NO_PATH NO_PATH $loop_cut \
            destQ RouteSelAnd.g/A1 reqQ RouteSelAnd.g/Z \
            "and_pins anda=[sizeof_collection $anda] andz=[sizeof_collection $andz]"
        }
        continue
      }
      cmr_sta_apply_window $dest_q $anda
      cmr_sta_apply_window $req_q $andz
      foreach edge {rise fall} {
        set tdata [cmr_sta_worst $dest_q $anda max $edge]
        set tctrl [cmr_sta_worst $req_q $andz min $edge]
        cmr_sta_emit CMR-RCU-01 $root bit$bit $edge $tdata $tctrl $loop_cut \
          destQ RouteSelAnd.g/A1 reqQ RouteSelAnd.g/Z \
          "critical opening is Z rise with Mat already stable"
        if {$dumped == 0} {
          set safe [string map {/ _ [ _ ] _} $root]
          cmr_sta_dump "$report_dir/rcu01/${safe}_bit${bit}_data_${edge}_max.rpt" $dest_q $anda max $edge
          cmr_sta_dump "$report_dir/rcu01/${safe}_bit${bit}_ctrl_${edge}_min.rpt" $req_q $andz min $edge
        }
      }
      cmr_sta_reset_window $dest_q $anda
      cmr_sta_reset_window $req_q $andz
    }
    incr dumped
  }
  catch { remove_disable_timing $all_latches }
  puts "CMR_PAIRED_ID_DONE id=CMR-RCU-01"
}

proc cmr_sta_opm_cells {} {
  set n 0
  foreach_in_collection c [get_cells -hierarchical -quiet -filter {ref_name =~ OPM*}] {
    set name [get_object_name $c]
    if {[regexp {OutputPortModules_[0-9]+$} $name]} {
      if {$n == 0} {
        set ::CMR_STA_OPMS $c
      } else {
        set ::CMR_STA_OPMS [add_to_collection $::CMR_STA_OPMS $c]
      }
      incr n
    }
  }
  set ::CMR_STA_OPM_N $n
  if {$n == 0} {
    set ::CMR_STA_OPMS [cmr_sta_empty]
  }
  return $n
}

# Inner-loop DDCs store production min/max on OPM XOR (L1_L4.Q->L5.D) and
# RCU Tctrl (LatchReg[24].Q->RouteSelAnd.Z).  reset_path -all is not
# portable; clear those so catalog E and unconstrained DEL delay are visible.
proc cmr_sta_reset_inner_exceptions {} {
  cmr_sta_opm_cells
  foreach_in_collection opm $::CMR_STA_OPMS {
    set root [get_object_name $opm]
    set l14_q [get_pins -quiet "$root/L1_L4_*/resettable_latch\[*\].latch_cell/Q"]
    set l5_d [get_pins -quiet "$root/L5/resettable_latch\[0\].latch_cell/D"]
    if {[sizeof_collection $l14_q] > 0 && [sizeof_collection $l5_d] == 1} {
      catch { reset_path -from $l14_q -to $l5_d }
    }
  }
  puts "CMR_PAIRED_RESET_PATH inner_opm_xor"
  set rcus [get_cells -hierarchical -quiet -filter {
    full_name =~ *InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*
  }]
  set n 0
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set req_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
    if {[sizeof_collection $req_q] != 1} {
      continue
    }
    foreach bit {0 1 2 3} {
      set pins [cmr_sta_rcu_and_pins $root $bit]
      set andz [lindex $pins 1]
      if {[sizeof_collection $andz] == 1} {
        catch { reset_path -from $req_q -to $andz }
        incr n
      }
    }
  }
  puts "CMR_PAIRED_RESET_PATH inner_rcu_tctrl pairs=$n"
  set n_ar 0
  foreach_in_collection rcu $rcus {
    set root [get_object_name $rcu]
    set hp_q [get_pins -quiet "$root/AddressRegister/HeadPredictorBlock/en_state_reg/Q"]
    set en [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/E"]
    if {[sizeof_collection $hp_q] == 1 && [sizeof_collection $en] > 0} {
      catch { reset_path -from $hp_q -to [index_collection $en 0] }
      incr n_ar
    }
  }
  puts "CMR_PAIRED_RESET_PATH inner_ar_en pairs=$n_ar"
}

proc cmr_sta_pins_of {cell filt} {
  return [get_pins -quiet -of_objects $cell -filter $filt]
}

proc cmr_sta_latch_bits {opm which bits} {
  set first 1
  set n 0
  foreach bit $bits {
    set p [get_pins -quiet "$opm/${which}/resettable_latch\[${bit}\].latch_cell/D"]
    if {[sizeof_collection $p] == 0} {
      continue
    }
    if {$first} {
      set all $p
      set first 0
    } else {
      set all [add_to_collection $all $p]
    }
    incr n
  }
  if {$n == 0} {
    return [cmr_sta_empty]
  }
  return $all
}

proc cmr_sta_measure_opm01 {report_dir} {
  file mkdir "$report_dir/opm01"
  set opm_n [cmr_sta_opm_cells]
  set opms $::CMR_STA_OPMS
  puts "CMR_PAIRED_STRUCTURE id=CMR-OPM-01 opms=$opm_n"
  if {$opm_n != 25} {
    puts "CMR_PAIRED_FAIL id=CMR-OPM-01 expected 25 OPMs got $opm_n"
    exit 2
  }

  set body_bits {}
  for {set i 0} {$i <= 25} {incr i} {
    lappend body_bits $i
  }

  set dumped 0
  foreach_in_collection opm $opms {
    set root [get_object_name $opm]
    set opm_cell [get_cells $root]
    set data_d [get_pins -quiet "$root/DataReg/resettable_latch\[*\].latch_cell/D"]
    set data_e [get_pins -quiet "$root/DataReg/resettable_latch\[*\].latch_cell/E"]
    set data_cells [get_cells -quiet "$root/DataReg/resettable_latch\[*\].latch_cell"]
    set l14_q [get_pins -quiet "$root/L1_L4_*/resettable_latch\[*\].latch_cell/Q"]
    set l14_cells [get_cells -quiet "$root/L1_L4_*/resettable_latch\[*\].latch_cell"]
    set l5_d [get_pins -quiet "$root/L5/resettable_latch\[0\].latch_cell/D"]
    set l5_e [get_pins -quiet "$root/L5/resettable_latch\[0\].latch_cell/E"]
    set datain [cmr_sta_pins_of $opm_cell {name =~ io_Datain_*flit*}]
    if {[sizeof_collection $datain] == 0} {
      set datain [get_pins -quiet -hierarchical -filter "full_name =~ $root/io_Datain*"]
    }
    puts "CMR_PAIRED_BIND id=CMR-OPM-01 inst=$root data_d=[sizeof_collection $data_d] data_e=[sizeof_collection $data_e] l14_q=[sizeof_collection $l14_q] l5_d=[sizeof_collection $l5_d] datain=[sizeof_collection $datain]"
    if {[sizeof_collection $data_d] != 28 || [sizeof_collection $data_e] < 1 || [sizeof_collection $l14_q] != 4 || [sizeof_collection $l5_d] != 1} {
      foreach site {head tail body} {
        foreach edge {rise fall} {
          cmr_sta_emit CMR-OPM-01 $root $site $edge NO_PATH NO_PATH \
            "bind fail" Datain DataReg.D L1_L4.Q DataReg.E \
            "data_d=[sizeof_collection $data_d] e=[sizeof_collection $data_e] l14=[sizeof_collection $l14_q] l5d=[sizeof_collection $l5_d]"
        }
      }
      continue
    }

    # Data leg: DataReg D is the endpoint.  Disable the latch cells so D is
    # not borrowed through Q.
    set_disable_timing $data_cells
    set loop_data "disable DataReg latch_cell (D endpoint)"

    set sites [list \
      [list head 27] \
      [list tail 26] \
      [list body $body_bits] \
    ]
    foreach site_spec $sites {
      set site [lindex $site_spec 0]
      set bits [lindex $site_spec 1]
      set d_pins [cmr_sta_latch_bits $root DataReg $bits]
      if {[sizeof_collection $d_pins] == 0} {
        set d_pins $data_d
      }
      cmr_sta_apply_window $datain $d_pins
      foreach edge {rise fall} {
        set tdata [cmr_sta_worst $datain $d_pins max $edge]
        set ::CMR_OPM_TDATA($root,$site,$edge) $tdata
      }
      if {$dumped == 0 && $site eq "head"} {
        set safe [string map {/ _ [ _ ] _} $root]
        cmr_sta_dump "$report_dir/opm01/${safe}_head_data_rise_max.rpt" $datain $d_pins max rise
      }
      cmr_sta_reset_window $datain $d_pins
    }
    catch { remove_disable_timing $data_cells }

    # Control leg: L1_L4.Q startpoints, L5.E cut so Q→XOR→E is not a latch loop.
    set_disable_timing $l14_cells
    if {[sizeof_collection $l5_e] == 1} {
      set_disable_timing $l5_e
    }
    set data_d_pins [get_pins -quiet "$root/DataReg/resettable_latch\[*\].latch_cell/D"]
    if {[sizeof_collection $data_d_pins] > 0} {
      catch { set_disable_timing $data_d_pins }
    }
    set loop_ctrl "disable L1_L4 latch_cell; disable L5.E (keep L5 D->Q); disable DataReg.D"
    set e_one [index_collection $data_e 0]
    set e_coll $e_one
    cmr_sta_apply_window $l14_q $e_coll
    set tctrl_rise [cmr_sta_worst $l14_q $e_coll min rise $l5_d]
    set tctrl_fall [cmr_sta_worst $l14_q $e_coll min fall $l5_d]
    set tctrl_note ""
    # XOR combo delay is not catalog Tctrl.  If E is still no-path, record
    # the L5.D segment in notes only and keep Tctrl as NO_PATH.
    if {$tctrl_fall eq "NO_PATH" && [sizeof_collection $l5_d] == 1} {
      cmr_sta_apply_window $l14_q $l5_d
      set xor_rise [cmr_sta_worst $l14_q $l5_d min rise]
      set xor_fall [cmr_sta_worst $l14_q $l5_d min fall]
      set tctrl_note "; XOR L1_L4.Q->L5.D min rise=$xor_rise fall=$xor_fall (not catalog Tctrl)"
      cmr_sta_reset_window $l14_q $l5_d
    }
    set ::CMR_OPM_TCTRL($root,rise) $tctrl_rise
    set ::CMR_OPM_TCTRL($root,fall) $tctrl_fall

    if {$dumped == 0} {
      set safe [string map {/ _ [ _ ] _} $root]
      cmr_sta_dump "$report_dir/opm01/${safe}_ctrl_fall_min.rpt" $l14_q $e_coll min fall $l5_d
    }

    cmr_sta_reset_window $l14_q $e_coll
    catch { remove_disable_timing $l14_cells }
    if {[sizeof_collection $l5_e] == 1} {
      catch { remove_disable_timing $l5_e }
    }
    if {[sizeof_collection $data_d_pins] > 0} {
      catch { remove_disable_timing $data_d_pins }
    }

    foreach site {head tail body} {
      foreach edge {rise fall} {
        set tdata $::CMR_OPM_TDATA($root,$site,$edge)
        # Close event is E falling.  Pair both data polarities against E fall;
        # still record E rise as a non-close observation in notes.
        set tctrl $tctrl_fall
        set note "data $edge vs E fall (OPM V2 close); E_rise_min=$tctrl_rise$tctrl_note"
        if {$edge eq "rise" && $tctrl_rise ne "NO_PATH"} {
          append note {; E rise is reopen, not this RTC}
        }
        cmr_sta_emit CMR-OPM-01 $root $site $edge $tdata $tctrl \
          "$loop_data; $loop_ctrl" \
          io_Datain_flit DataReg.D L1_L4.Q DataReg.E $note
      }
    }
    incr dumped
  }
  puts "CMR_PAIRED_ID_DONE id=CMR-OPM-01"
}

proc cmr_sta_measure_opm01_ce {report_dir} {
  file mkdir "$report_dir/opm01_ce"
  set opm_n [cmr_sta_opm_cells]
  set opms $::CMR_STA_OPMS
  puts "CMR_PAIRED_STRUCTURE id=CMR-OPM-01-CE opms=$opm_n"
  if {$opm_n != 25} {
    puts "CMR_PAIRED_FAIL id=CMR-OPM-01-CE expected 25 OPMs got $opm_n"
    exit 2
  }
  set dumped 0
  foreach_in_collection opm $opms {
    set root [get_object_name $opm]
    set close_zn [get_pins -quiet "$root/RegClose/close_event_inv/ZN"]
    set close_i [get_pins -quiet "$root/RegClose/close_event_inv/I"]
    if {[sizeof_collection $close_zn] != 1 || [sizeof_collection $close_i] != 1} {
      set close_zn [get_pins -quiet "$root/RegClose/close_clock"]
      set close_i [get_pins -quiet "$root/RegClose/latch_enable"]
    }
    if {[sizeof_collection $close_zn] != 1} {
      set close_zn [get_pins -quiet -hierarchical -filter "full_name =~ $root/RegClose* && (name == ZN || name == close_clock)"]
    }
    if {[sizeof_collection $close_i] != 1} {
      set close_i [get_pins -quiet -hierarchical -filter "full_name =~ $root/RegClose* && (name == I || name == latch_enable)"]
    }
    set ack_d [get_pins -quiet "$root/FF0_FF3*/D"]
    if {[sizeof_collection $ack_d] == 0} {
      set ack_d [get_pins -quiet -hierarchical -filter "full_name =~ $root/* && name == D && (full_name =~ *FF0_FF3* || full_name =~ *Ackout*)"]
    }
    set tp_d [get_pins -quiet "$root/TailPassed*/D"]
    if {[sizeof_collection $tp_d] == 0} {
      set tp_d [get_pins -quiet -hierarchical -filter "full_name =~ $root/* && name == D && full_name =~ *TailPassed*"]
    }
    set l14_q [get_pins -quiet "$root/L1_L4_*/resettable_latch\[*\].latch_cell/Q"]
    set tail_q [get_pins -quiet "$root/DataReg/resettable_latch\[26\].latch_cell/Q"]
    set l14_cells [get_cells -quiet "$root/L1_L4_*/resettable_latch\[*\].latch_cell"]
    set data_cells [get_cells -quiet "$root/DataReg/resettable_latch\[*\].latch_cell"]
    puts "CMR_PAIRED_BIND id=CMR-OPM-01-CE inst=$root close_zn=[sizeof_collection $close_zn] ack_d=[sizeof_collection $ack_d] tp_d=[sizeof_collection $tp_d]"

    set loop_cut "disable L1_L4 and DataReg latch cells for Q startpoints; CE is a segment check, not an inner-loop ID"
    if {[sizeof_collection $l14_cells] > 0} {
      set_disable_timing $l14_cells
    }
    if {[sizeof_collection $data_cells] > 0} {
      set_disable_timing $data_cells
    }

    # Ackout D vs close_clock: data from L1_L4.Q, clock from inverter ZN.
    if {[sizeof_collection $ack_d] > 0 && [sizeof_collection $l14_q] > 0} {
      cmr_sta_apply_window $l14_q $ack_d
      set tdata [cmr_sta_worst $l14_q $ack_d max rise]
      cmr_sta_reset_window $l14_q $ack_d
    } else {
      set tdata NO_PATH
    }
    if {[sizeof_collection $close_i] == 1 && [sizeof_collection $close_zn] == 1} {
      cmr_sta_apply_window $close_i $close_zn
      set tctrl [cmr_sta_worst $close_i $close_zn min rise]
      cmr_sta_reset_window $close_i $close_zn
    } else {
      set tctrl NO_PATH
    }
    cmr_sta_emit CMR-OPM-01-CE $root ackout rise $tdata $tctrl $loop_cut \
      L1_L4.Q Ackout.D close_event_inv.I close_event_inv.ZN \
      "segment only; Tctrl is inverter I→ZN, not a second RTC class"

    if {[sizeof_collection $tp_d] > 0 && [sizeof_collection $tail_q] > 0} {
      cmr_sta_apply_window $tail_q $tp_d
      set tdata_tp [cmr_sta_worst $tail_q $tp_d max rise]
      cmr_sta_reset_window $tail_q $tp_d
    } else {
      set tdata_tp NO_PATH
    }
    cmr_sta_emit CMR-OPM-01-CE $root tailpassed rise $tdata_tp $tctrl $loop_cut \
      DataReg.Q[26] TailPassed.D close_event_inv.I close_event_inv.ZN \
      "segment only; same close_clock as Ackout"

    if {$dumped == 0 && [sizeof_collection $close_i] == 1 && [sizeof_collection $close_zn] == 1} {
      set safe [string map {/ _ [ _ ] _} $root]
      cmr_sta_dump "$report_dir/opm01_ce/${safe}_inv_rise.rpt" $close_i $close_zn min rise
    }
    if {[sizeof_collection $l14_cells] > 0} {
      catch { remove_disable_timing $l14_cells }
    }
    if {[sizeof_collection $data_cells] > 0} {
      catch { remove_disable_timing $data_cells }
    }
    incr dumped
  }
  puts "CMR_PAIRED_ID_DONE id=CMR-OPM-01-CE"
}

proc cmr_sta_link_fifo_sites {} {
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

proc cmr_sta_link_core_sites {} {
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

proc cmr_sta_cell_pins {cell filt} {
  set obj [get_cells -quiet $cell]
  if {[sizeof_collection $obj] != 1} {
    return [cmr_sta_empty]
  }
  return [get_pins -quiet -of_objects $obj -filter $filt]
}

proc cmr_sta_ports {name} {
  set p [get_ports -quiet $name]
  if {[sizeof_collection $p] == 0} {
    set p [get_ports -quiet ${name}*]
  }
  if {[sizeof_collection $p] == 0} {
    return [cmr_sta_empty]
  }
  return $p
}

proc cmr_sta_emit_pair {id inst site data_from data_to ctrl_from ctrl_to loop notes} {
  set dfc [sizeof_collection $data_from]
  set dtc [sizeof_collection $data_to]
  set cfc [sizeof_collection $ctrl_from]
  set ctc [sizeof_collection $ctrl_to]
  if {$dfc == 0 || $dtc == 0 || $cfc == 0 || $ctc == 0} {
    foreach edge {rise fall} {
      cmr_sta_emit $id $inst $site $edge NO_PATH NO_PATH $loop \
        data_from data_to ctrl_from ctrl_to \
        "bind dfrom=$dfc dto=$dtc cfrom=$cfc cto=$ctc; $notes"
    }
    return
  }
  cmr_sta_apply_window $data_from $data_to
  cmr_sta_apply_window $ctrl_from $ctrl_to
  foreach edge {rise fall} {
    set tdata [cmr_sta_worst $data_from $data_to max $edge]
    set tctrl [cmr_sta_worst $ctrl_from $ctrl_to min $edge]
    cmr_sta_emit $id $inst $site $edge $tdata $tctrl $loop \
      [get_object_name [index_collection $data_from 0]] \
      [get_object_name [index_collection $data_to 0]] \
      [get_object_name [index_collection $ctrl_from 0]] \
      [get_object_name [index_collection $ctrl_to 0]] \
      $notes
  }
  cmr_sta_reset_window $data_from $data_to
  cmr_sta_reset_window $ctrl_from $ctrl_to
}

proc cmr_sta_reset_link_exceptions {} {
  set n 0
  foreach site [cmr_sta_link_fifo_sites] {
    set bb [lindex $site 0]
    set opm [lindex $site 3]
    set ipm [lindex $site 4]
    set data_out [cmr_sta_cell_pins $bb {name =~ Data_out*}]
    set reqout [cmr_sta_cell_pins $bb {name == Reqout}]
    set data_in [cmr_sta_cell_pins $bb {name =~ Data_in*}]
    set reqin [cmr_sta_cell_pins $bb {name == Reqin}]
    set ackin [cmr_sta_cell_pins $bb {name == Ackin}]
    set ipm_d [cmr_sta_cell_pins $ipm {name =~ io_Datain_flit*}]
    set ipm_r [cmr_sta_cell_pins $ipm {name == io_Reqin}]
    set ipm_a [cmr_sta_cell_pins $ipm {name == io_Ackout}]
    set opm_d [cmr_sta_cell_pins $opm {name =~ io_Dataout_flit*}]
    set opm_r [cmr_sta_cell_pins $opm {name == io_Reqout}]
    set cps [cmr_sta_read_counter_cp $bb]
    if {[sizeof_collection $data_out] > 0 && [sizeof_collection $ipm_d] > 0} {
      catch { reset_path -from $data_out -to $ipm_d }
    }
    if {[sizeof_collection $reqout] > 0 && [sizeof_collection $ipm_r] > 0} {
      catch { reset_path -from $reqout -to $ipm_r }
    }
    if {[sizeof_collection $opm_d] > 0 && [sizeof_collection $data_in] > 0} {
      catch { reset_path -from $opm_d -to $data_in }
    }
    if {[sizeof_collection $opm_r] > 0 && [sizeof_collection $reqin] > 0} {
      catch { reset_path -from $opm_r -to $reqin }
    }
    if {[sizeof_collection $ipm_a] > 0 && [sizeof_collection $ackin] > 0} {
      catch { reset_path -from $ipm_a -to $ackin }
    }
    if {[sizeof_collection $reqout] > 0 && [sizeof_collection $cps] > 0} {
      catch { reset_path -from $reqout -to $cps }
    }
    if {[sizeof_collection $ipm_a] > 0 && [sizeof_collection $cps] > 0} {
      catch { reset_path -from $ipm_a -to $cps }
    }
    if {[sizeof_collection $ackin] > 0 && [sizeof_collection $cps] > 0} {
      catch { reset_path -from $ackin -to $cps }
    }
    set counter_req [cmr_sta_counter_req $bb]
    set xnor_a1 [cmr_sta_xnor_a1 $bb]
    set xnor_req [cmr_sta_xnor_req_pin $bb]
    if {[sizeof_collection $counter_req] > 0 && [sizeof_collection $xnor_req] > 0} {
      catch { reset_path -from $counter_req -to $xnor_req }
    }
    if {[sizeof_collection $ipm_a] > 0 && [sizeof_collection $xnor_a1] > 0} {
      catch { reset_path -from $ipm_a -to $xnor_a1 }
    }
    if {[sizeof_collection $ackin] > 0 && [sizeof_collection $xnor_a1] > 0} {
      catch { reset_path -from $ackin -to $xnor_a1 }
    }
    incr n
  }
  puts "CMR_PAIRED_RESET_PATH link_fifo sites=$n"
}

proc cmr_sta_measure_link_fwd {report_dir} {
  file mkdir "$report_dir/link_fwd"
  set n 0
  foreach site [cmr_sta_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set ipm [lindex $site 4]
    set data_out [cmr_sta_cell_pins $bb {name =~ Data_out*}]
    set reqout [cmr_sta_cell_pins $bb {name == Reqout}]
    set datain [cmr_sta_cell_pins $ipm {name =~ io_Datain_flit*}]
    set reqin [cmr_sta_cell_pins $ipm {name == io_Reqin}]
    cmr_sta_emit_pair CMR-LINK-FWD-01 $bb ${tag}${dir} \
      $data_out $datain $reqout $reqin \
      "none (FIFO Data_out/Reqout pins to IPM ports)" \
      "L1L2 forward; TCF-RD-01 is FIFO-internal SlotData vs Reqout"
    incr n
  }
  if {$n != 8} {
    puts "CMR_PAIRED_FAIL id=CMR-LINK-FWD-01 expected 8 FIFOs got $n"
    exit 2
  }
  puts "CMR_PAIRED_ID_DONE id=CMR-LINK-FWD-01"
}

proc cmr_sta_measure_link_enq {report_dir} {
  file mkdir "$report_dir/link_enq"
  set n 0
  foreach site [cmr_sta_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set opm [lindex $site 3]
    set dataout [cmr_sta_cell_pins $opm {name =~ io_Dataout_flit*}]
    set reqout [cmr_sta_cell_pins $opm {name == io_Reqout}]
    set data_in [cmr_sta_cell_pins $bb {name =~ Data_in*}]
    set reqin [cmr_sta_cell_pins $bb {name == Reqin}]
    cmr_sta_emit_pair CMR-LINK-ENQ-01 $bb ${tag}${dir} \
      $dataout $data_in $reqout $reqin \
      "none (OPM Dataout/Reqout to FIFO enq)" \
      "L1L2 enqueue; not DataReg.E / Ackin DEL"
    incr n
  }
  if {$n != 8} {
    puts "CMR_PAIRED_FAIL id=CMR-LINK-ENQ-01 expected 8 FIFOs got $n"
    exit 2
  }
  puts "CMR_PAIRED_ID_DONE id=CMR-LINK-ENQ-01"
}

proc cmr_sta_req_latch_q {bb} {
  set q [get_pins -hierarchical -quiet -filter "full_name =~ $bb*ReqLatch/q"]
  if {[sizeof_collection $q] == 0} {
    set q [get_pins -hierarchical -quiet -filter "full_name =~ $bb*ReqLatch/Q"]
  }
  if {[sizeof_collection $q] == 0} {
    set q [get_pins -hierarchical -quiet -filter "full_name =~ $bb*ReqLatch*latch_cell/Q"]
  }
  return $q
}

proc cmr_sta_slot_data_q {bb} {
  set q [get_pins -hierarchical -quiet -filter "full_name =~ $bb*data_reg* && name == Q"]
  if {[sizeof_collection $q] == 0} {
    set q [get_pins -hierarchical -quiet -filter "full_name =~ $bb*data_reg* && name == q"]
  }
  return $q
}

proc cmr_sta_read_counter_cp {bb} {
  set cps [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter* && name == CP"]
  if {[sizeof_collection $cps] == 0} {
    set cps [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter* && name == CK"]
  }
  return $cps
}

proc cmr_sta_counter_req {bb} {
  # FIFO Reqout is an output pin; paths from it go downstream, not back
  # into ReadCounter.  Use the counter input driven by that net.
  set p [get_pins -quiet $bb/read_counter/Reqout]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/Reqout"]
  }
  return $p
}

proc cmr_sta_xnor_a1 {bb} {
  set p [get_pins -quiet $bb/read_counter/U10/A1]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/U10/A1"]
  }
  return $p
}

proc cmr_sta_xnor_req_pin {bb} {
  set p [get_pins -quiet $bb/read_counter/U10/A2]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/U10/A2"]
  }
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -quiet -of_objects [get_cells -quiet $bb/read_counter/U10] -filter {name == Z || name == ZN}]
  }
  return $p
}

proc cmr_sta_leaf_drivers {pins} {
  if {[sizeof_collection $pins] == 0} {
    return [cmr_sta_empty]
  }
  set nets [get_nets -quiet -of_objects $pins]
  if {[sizeof_collection $nets] == 0} {
    return $pins
  }
  set d [get_pins -quiet -leaf -of_objects $nets -filter {direction == out}]
  if {[sizeof_collection $d] == 0} {
    set d [get_pins -quiet -leaf -of_objects $nets -filter {pin_direction == out}]
  }
  if {[sizeof_collection $d] == 0} {
    return $pins
  }
  return $d
}

proc cmr_sta_xnor_out {bb} {
  foreach name {ZN Z} {
    set p [get_pins -quiet $bb/read_counter/U10/$name]
    if {[sizeof_collection $p] == 1} {
      return $p
    }
  }
  set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/U10/ZN"]
  if {[sizeof_collection $p] == 1} {
    return $p
  }
  set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*read_counter/U10/Z"]
  if {[sizeof_collection $p] == 1} {
    return $p
  }
  return [cmr_sta_empty]
}

proc cmr_sta_hs02_buf_z {bb} {
  set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*cfifo_hs02_ack_counter_buf_s3* && name == Z"]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*cfifo_hs02_ack_counter_buf_s3*/Z"]
  }
  return $p
}

proc cmr_sta_hs02_buf_s1_z {bb} {
  set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*cfifo_hs02_ack_counter_buf_s1* && name == Z"]
  if {[sizeof_collection $p] == 0} {
    set p [get_pins -hierarchical -quiet -filter "full_name =~ $bb*cfifo_hs02_ack_counter_buf_s1*/Z"]
  }
  return $p
}

# U10 sits on the Reqout^Ackin combinational loop that clocks ReadCounter.
# DC drops unconstrained paths into that cell.  Cut only the XNOR output
# fanout (the four pointer flops) for the ACK/HS-02 pair, then restore.
proc cmr_sta_cut_xnor_loop {bb} {
  set out [cmr_sta_xnor_out $bb]
  set fan [cmr_sta_empty]
  if {[sizeof_collection $out] == 1} {
    catch { set_disable_timing $out }
    catch { set fan [all_fanout -from $out -only_cells -levels 1] }
    if {[sizeof_collection $fan] > 0} {
      catch { set_disable_timing $fan }
    }
  }
  return [list $out $fan]
}

proc cmr_sta_uncut_xnor_loop {cut} {
  set out [lindex $cut 0]
  set fan [lindex $cut 1]
  if {[sizeof_collection $fan] > 0} {
    catch { remove_disable_timing $fan }
  }
  if {[sizeof_collection $out] == 1} {
    catch { remove_disable_timing $out }
  }
}

proc cmr_sta_measure_link_ack {report_dir} {
  file mkdir "$report_dir/link_ack"
  set n 0
  foreach site [cmr_sta_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set ipm [lindex $site 4]
    set counter_req [cmr_sta_leaf_drivers [cmr_sta_xnor_req_pin $bb]]
    set xnor_req [cmr_sta_xnor_req_pin $bb]
    set buf_s1 [cmr_sta_hs02_buf_s1_z $bb]
    set buf_s3 [cmr_sta_hs02_buf_z $bb]
    set xnor_a1 [cmr_sta_xnor_a1 $bb]
    set ack_end $buf_s3
    set ack_note "deq Ack Tctrl is HS-02 ECO s1/Z->s3/Z; IPM Ackout->Ackin is ZeroWireload 0; U10/A1 is not a DC start/end across Ackin"
    set t_a1 [cmr_sta_worst $buf_s1 $xnor_a1 min rise]
    if {$t_a1 ne "NO_PATH"} {
      set ack_end $xnor_a1
      set ack_note "deq Ack Tctrl is HS-02 ECO s1/Z->U10/A1; IPM Ackout->Ackin is ZeroWireload 0"
    }
    cmr_sta_emit_pair CMR-LINK-ACK-01 $bb ${tag}${dir} \
      $counter_req $xnor_req $buf_s1 $ack_end \
      "Ackin is not a DC startpoint; measure leaf Req (U8/ZN->A2) vs ECO chain; TCF-HS-02 3xBUFFD0 stay dont_touch" \
      $ack_note
    if {$n == 0} {
      cmr_sta_dump "$report_dir/link_ack/up0_ack_min.rpt" $buf_s1 $ack_end min ""
      cmr_sta_dump "$report_dir/link_ack/up0_req_max.rpt" $counter_req $xnor_req max ""
    }
    incr n
  }
  if {$n != 8} {
    puts "CMR_PAIRED_FAIL id=CMR-LINK-ACK-01 expected 8 FIFOs got $n"
    exit 2
  }
  puts "CMR_PAIRED_ID_DONE id=CMR-LINK-ACK-01"
}

proc cmr_sta_measure_link_io {report_dir} {
  file mkdir "$report_dir/link_io"
  set n 0
  foreach site [cmr_sta_link_core_sites] {
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
    set data_in [cmr_sta_ports $dport]
    set req_in [cmr_sta_ports $rport]
    set data_out [cmr_sta_ports $dout]
    set req_out [cmr_sta_ports $rout]
    set ipm_d [cmr_sta_cell_pins $ipm {name =~ io_Datain_flit*}]
    set ipm_r [cmr_sta_cell_pins $ipm {name == io_Reqin}]
    set opm_d [cmr_sta_cell_pins $opm {name =~ io_Dataout_flit*}]
    set opm_r [cmr_sta_cell_pins $opm {name == io_Reqout}]
    set inst ${kind}${idx}:${router}
    cmr_sta_emit_pair CMR-LINK-IO-01 $inst src \
      $data_in $ipm_d $req_in $ipm_r \
      "none; WP-01 endpoint 0.20 ns is not in this NoC-only compile" \
      "source boundary Data-before-Req; dummy top_input 1-3 not in this table"
    cmr_sta_emit_pair CMR-LINK-IO-01 $inst snk \
      $opm_d $data_out $opm_r $req_out \
      "none; OPM-01 D vs E is the inner close, not this pin pair" \
      "sink boundary Dataout vs Reqout at NoC port"
    incr n
  }
  if {$n != 17} {
    puts "CMR_PAIRED_FAIL id=CMR-LINK-IO-01 expected 17 sites got $n"
    exit 2
  }
  puts "CMR_PAIRED_ID_DONE id=CMR-LINK-IO-01"
}

proc cmr_sta_measure_tcf_rd01 {report_dir} {
  file mkdir "$report_dir/tcf_rd01"
  set n 0
  foreach site [cmr_sta_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set data_q [cmr_sta_slot_data_q $bb]
    set data_out [cmr_sta_cell_pins $bb {name =~ Data_out*}]
    set req_q [cmr_sta_req_latch_q $bb]
    set reqout [cmr_sta_cell_pins $bb {name == Reqout}]
    set loop "none; TCF-RD-01 ECO is 16xBUFFD0 on $bb/U2/A*"
    cmr_sta_emit_pair TCF-RD-01 $bb ${tag}${dir} \
      $data_q $data_out $req_q $reqout $loop \
      "SlotData Q vs ReqLatch Q at Reqout; Req control uses XOR A* ECO not EmptyEnable"
    incr n
  }
  if {$n != 8} {
    puts "CMR_PAIRED_FAIL id=TCF-RD-01 expected 8 FIFOs got $n"
    exit 2
  }
  puts "CMR_PAIRED_ID_DONE id=TCF-RD-01"
}

proc cmr_sta_measure_tcf_hs02 {report_dir} {
  file mkdir "$report_dir/tcf_hs02"
  set n 0
  foreach site [cmr_sta_link_fifo_sites] {
    set bb [lindex $site 0]
    set tag [lindex $site 1]
    set dir [lindex $site 2]
    set counter_req [cmr_sta_leaf_drivers [cmr_sta_xnor_req_pin $bb]]
    set xnor_req [cmr_sta_xnor_req_pin $bb]
    set buf_s1 [cmr_sta_hs02_buf_s1_z $bb]
    set buf_s3 [cmr_sta_hs02_buf_z $bb]
    set xnor_a1 [cmr_sta_xnor_a1 $bb]
    set ack_end $buf_s3
    set notes "Ackin is not a DC startpoint; Tctrl is ECO s1/Z->s3/Z (s1 cell not in this pair)"
    set t_a1 [cmr_sta_worst $buf_s1 $xnor_a1 min rise]
    if {$t_a1 ne "NO_PATH"} {
      set ack_end $xnor_a1
      set notes "Tctrl is ECO s1/Z->U10/A1"
    }
    set loop "FIFO Ackin pin is not a startpoint; IPM Ackout->Ackin is ZeroWireload 0; TCF-HS-02 ECO 3xBUFFD0 dont_touch"
    cmr_sta_emit_pair TCF-HS-02 $bb ${tag}${dir} \
      $counter_req $xnor_req $buf_s1 $ack_end $loop $notes
    if {$n == 0} {
      cmr_sta_dump "$report_dir/tcf_hs02/up0_ack_min.rpt" $buf_s1 $ack_end min ""
      cmr_sta_dump "$report_dir/tcf_hs02/up0_req_max.rpt" $counter_req $xnor_req max ""
    }
    incr n
  }
  if {$n != 8} {
    puts "CMR_PAIRED_FAIL id=TCF-HS-02 expected 8 FIFOs got $n"
    exit 2
  }
  puts "CMR_PAIRED_ID_DONE id=TCF-HS-02"
}

proc cmr_sta_measure_links {report_dir} {
  cmr_sta_reset_link_exceptions
  cmr_sta_measure_tcf_rd01 $report_dir
  cmr_sta_measure_tcf_hs02 $report_dir
  cmr_sta_measure_link_fwd $report_dir
  cmr_sta_measure_link_enq $report_dir
  cmr_sta_measure_link_ack $report_dir
  cmr_sta_measure_link_io $report_dir
}

