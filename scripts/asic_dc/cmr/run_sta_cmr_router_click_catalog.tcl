# Read-only paired timing characterization for the frozen RouterL1 CMR DDC.
# This script does not add production constraints or modify the design.
#
# RTCs measured from the current DFF-mapped hierarchy:
#   CMR-RCU-MAT-01  AddressRegister data/Req_rc Q -> RouteSelAnd2 data/control
#   CMR-OPM-Q-01    common RegEnable CP -> DataReg Q / Reqout Q
# The complete sequential-cell inventory is emitted separately.  Sequential
# state without an established data/control pairing remains explicitly pending.

set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_ROUTER_STA_BASELINE)
set RUN_ID $::env(CMR_PAIRED_STA_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
set WINDOW_NS 20.0
file mkdir $REPORT_DIR
file mkdir "$REPORT_DIR/paths"

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/CMRRouter.ddc"
current_design CMRRouter
link

proc cmr_csv {s} {
  if {[string match "*,*" $s] || [string match "*\"*" $s]} {
    return "\"[string map {\" \"\"} $s]\""
  }
  return $s
}

proc cmr_pin_path_time {from to dtype edge} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return NO_PATH
  }
  if {[catch {set_max_delay $::WINDOW_NS -from $from -to $to}]} {}
  if {[catch {set_min_delay 0.0 -from $from -to $to}]} {}
  if {[catch {
    if {$edge eq "rise"} {
      set paths [get_timing_paths -from $from -rise_to $to -delay_type $dtype -max_paths 128 -nworst 1]
    } elseif {$edge eq "fall"} {
      set paths [get_timing_paths -from $from -fall_to $to -delay_type $dtype -max_paths 128 -nworst 1]
    } else {
      set paths [get_timing_paths -from $from -to $to -delay_type $dtype -max_paths 128 -nworst 1]
    }
  } err]} {
    puts "CMR_STA_PATH_ERROR dtype=$dtype edge=$edge err=$err"
    catch {reset_path -from $from -to $to}
    return NO_PATH
  }
  set worst ""
  if {[info exists paths]} {
    foreach_in_collection p $paths {
      set a [get_attribute $p arrival]
      if {$a eq "" || ![string is double -strict $a]} { continue }
      if {$worst eq "" || ($dtype eq "max" && $a > $worst) || ($dtype eq "min" && $a < $worst)} {
        set worst $a
      }
    }
  }
  catch {reset_path -from $from -to $to}
  if {$worst eq ""} { return NO_PATH }
  return $worst
}

proc cmr_write_paired_row {fd id inst site data_edge ctrl_edge tdata tctrl data_from data_to ctrl_from ctrl_to} {
  set no_path 0
  set rtm NA
  set shortfall NA
  if {$tdata eq "NO_PATH" || $tctrl eq "NO_PATH"} {
    set no_path 1
  } else {
    set shortfall [expr {$tdata > $tctrl ? $tdata - $tctrl : 0.0}]
    set rtm [expr {$tdata == 0.0 ? 0.0 : 100.0 * ($tctrl - $tdata) / $tdata}]
    set shortfall [format "%.6f" $shortfall]
    set rtm [format "%.3f" $rtm]
    set tdata [format "%.6f" $tdata]
    set tctrl [format "%.6f" $tctrl]
  }
  puts $fd [join [list $id [cmr_csv $inst] $site $data_edge $ctrl_edge $tdata $tctrl $rtm $shortfall $no_path [cmr_csv $data_from] [cmr_csv $data_to] [cmr_csv $ctrl_from] [cmr_csv $ctrl_to]] ","]
}

proc cmr_dump_pair_path {path from to dtype edge} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return
  }
  if {[catch {set_max_delay $::WINDOW_NS -from $from -to $to}]} {}
  if {[catch {set_min_delay 0.0 -from $from -to $to}]} {}
  redirect $path {
    if {$edge eq "rise"} {
      report_timing -from $from -rise_to $to -delay_type $dtype -max_paths 1 -nworst 1 -nosplit -input_pins -nets
    } elseif {$edge eq "fall"} {
      report_timing -from $from -fall_to $to -delay_type $dtype -max_paths 1 -nworst 1 -nosplit -input_pins -nets
    } else {
      report_timing -from $from -to $to -delay_type $dtype -max_paths 1 -nworst 1 -nosplit -input_pins -nets
    }
  }
  catch {reset_path -from $from -to $to}
}

set paired "$REPORT_DIR/paired_click_catalog.csv"
set fd [open $paired w]
puts $fd "id,instance,site,data_edge,control_edge,tdata_max_ns,tctrl_min_ns,rtm_pct,shortfall_ns,no_path,data_from,data_to,control_from,control_to"
set paired_rows 0
set paired_no_path 0
set paired_shortfall 0

# RCU Fig. 6: the same AddressRegisterFire launches destination data and Req_rc.
# Compare the latest destination decode arrival at RouteSelAnd.A1 with the
# earliest matched Req/Ack bundling control at RouteSelAnd.A2.
set rcus [get_cells -hierarchical -quiet -filter {full_name =~ InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*}]
set rcu_count [sizeof_collection $rcus]
puts "CMR_STA_BIND class=CMR-RCU-MAT-01 instances=$rcu_count expected=5"
if {$rcu_count != 5} {
  puts "CMR_STA_COVERAGE_FAIL class=CMR-RCU-MAT-01 expected=5 actual=$rcu_count"
}
set rcu_dumped 0
foreach_in_collection rcu $rcus {
  set root [get_object_name $rcu]
  set dest_regs [get_cells -quiet -hierarchical -filter "full_name =~ $root/AddressRegister/*io_dest_FF_reg*"]
  set dest_cp [get_pins -quiet -of_objects $dest_regs -filter {name == CP}]
  set req_reg [get_cells -quiet "$root/AddressRegister/toggle_ff_reg"]
  set req_cp [get_pins -quiet -of_objects $req_reg -filter {name == CP}]
  puts "CMR_STA_BIND class=CMR-RCU-MAT-01 instance=$root dest_cp=[sizeof_collection $dest_cp] req_cp=[sizeof_collection $req_cp] expected_dest_cp=24 expected_req_cp=1"
  if {[sizeof_collection $dest_cp] != 24 || [sizeof_collection $req_cp] != 1} {
    puts "CMR_STA_COVERAGE_FAIL class=CMR-RCU-MAT-01 instance=$root endpoint_binding"
  }
  for {set bit 0} {$bit < 4} {incr bit} {
    set apin [get_pins -quiet -hierarchical -filter "full_name =~ $root/*RouteSelAnd_${bit}*/g/A1"]
    set bpin [get_pins -quiet -hierarchical -filter "full_name =~ $root/*RouteSelAnd_${bit}*/g/A2"]
    puts "CMR_STA_BIND class=CMR-RCU-MAT-01 instance=$root bit=$bit A1=[sizeof_collection $apin] A2=[sizeof_collection $bpin]"
    foreach data_edge {rise fall} {
      foreach ctrl_edge {rise fall} {
        set td [cmr_pin_path_time $dest_cp $apin max $data_edge]
        set tc [cmr_pin_path_time $req_cp $bpin min $ctrl_edge]
        cmr_write_paired_row $fd CMR-RCU-MAT-01 $root bit$bit $data_edge $ctrl_edge $td $tc \
          "AddressRegister.dest_FF.CP" "RouteSelAnd_${bit}.g/A1" \
          "AddressRegister.toggle_ff.CP" "RouteSelAnd_${bit}.g/A2"
        incr paired_rows
        if {$td eq "NO_PATH" || $tc eq "NO_PATH"} { incr paired_no_path }
        if {$td ne "NO_PATH" && $tc ne "NO_PATH" && $tc < $td} { incr paired_shortfall }
        if {$rcu_dumped == 0 && $data_edge eq "rise" && $ctrl_edge eq "rise"} {
          set safe [string map {/ _ [ _ ] _} $root]
          cmr_dump_pair_path "$REPORT_DIR/paths/${safe}_mat_rise_max.rpt" $dest_cp $apin max rise
          cmr_dump_pair_path "$REPORT_DIR/paths/${safe}_req_rise_min.rpt" $req_cp $bpin min rise
        }
      }
    }
  }
  incr rcu_dumped
}

# OPM Fig. 2 output rendezvous: DataReg and Reqout are both clocked by
# RegEnable.  Measure every data bit's clock-to-Q max against Reqout's
# clock-to-Q min for both request phases.  This directly tests whether the
# request can reach the boundary before the bundled flit.
set opms [get_cells -hierarchical -quiet -filter {full_name =~ OutputPortModules_* && ref_name =~ OPM*}]
set opm_count [sizeof_collection $opms]
puts "CMR_STA_BIND class=CMR-OPM-Q-01 instances=$opm_count expected=5"
if {$opm_count != 5} {
  puts "CMR_STA_COVERAGE_FAIL class=CMR-OPM-Q-01 expected=5 actual=$opm_count"
}
set opm_dumped 0
foreach_in_collection opm $opms {
  set root [get_object_name $opm]
  set data_regs [get_cells -quiet -hierarchical -filter "full_name =~ $root/DataReg_ff_reg*"]
  # Current emitted OPM RTL names this state Reqout_ff_reg; older generated
  # snapshots used io_Reqout_ff_reg. Bind the live DDC name, not the stale one.
  set req_reg [get_cells -quiet "$root/Reqout_ff_reg"]
  puts "CMR_STA_BIND class=CMR-OPM-Q-01 instance=$root data_ff=[sizeof_collection $data_regs] req_ff=[sizeof_collection $req_reg] expected_data_ff=28 expected_req_ff=1"
  if {[sizeof_collection $data_regs] != 28 || [sizeof_collection $req_reg] != 1} {
    puts "CMR_STA_COVERAGE_FAIL class=CMR-OPM-Q-01 instance=$root endpoint_binding"
    continue
  }
  set req_cp [get_pins -quiet -of_objects $req_reg -filter {name == CP}]
  set req_q [get_pins -quiet -of_objects $req_reg -filter {name == Q}]
  foreach_in_collection data_reg $data_regs {
    set data_cp [get_pins -quiet -of_objects $data_reg -filter {name == CP}]
    set data_q [get_pins -quiet -of_objects $data_reg -filter {name == Q}]
    set reg_name [get_object_name $data_reg]
    set bit "unknown"
    if {[regexp {DataReg_ff_reg\[([0-9]+)\]$} $reg_name -> b]} { set bit $b }
    foreach data_edge {rise fall} {
      foreach ctrl_edge {rise fall} {
        set td [cmr_pin_path_time $data_cp $data_q max $data_edge]
        set tc [cmr_pin_path_time $req_cp $req_q min $ctrl_edge]
        cmr_write_paired_row $fd CMR-OPM-Q-01 $root bit$bit $data_edge $ctrl_edge $td $tc \
          "$reg_name/CP" "$reg_name/Q" "$root/io_Reqout_ff_reg/CP" "$root/io_Reqout_ff_reg/Q"
        incr paired_rows
        if {$td eq "NO_PATH" || $tc eq "NO_PATH"} { incr paired_no_path }
        if {$td ne "NO_PATH" && $tc ne "NO_PATH" && $tc < $td} { incr paired_shortfall }
        if {$opm_dumped == 0 && $data_edge eq "rise" && $ctrl_edge eq "rise"} {
          set safe [string map {/ _ [ _ ] _} $root]
          cmr_dump_pair_path "$REPORT_DIR/paths/${safe}_data_c2q_rise_max.rpt" $data_cp $data_q max rise
          cmr_dump_pair_path "$REPORT_DIR/paths/${safe}_req_c2q_rise_min.rpt" $req_cp $req_q min rise
        }
      }
    }
  }
  incr opm_dumped
}
close $fd

# Inventory every mapped DFF-like state point.  Only the explicit paired
# classes above are promoted as RTCs; every other sequential state is listed
# for manual functional/library-check classification instead of being omitted.
set inventory "$REPORT_DIR/click_inventory.csv"
set ifd [open $inventory w]
puts $ifd "instance,ref_name,clock_pin,clock_net,d_pin,q_pin,classification,paired_rtc"
set seq_cells [get_cells -hierarchical -quiet -filter {ref_name =~ DFC* || ref_name =~ DFS*}]
set seq_count [sizeof_collection $seq_cells]
set pending_count 0
set unmeasured_count 0
array set class_counts {}
foreach_in_collection c $seq_cells {
  set name [get_object_name $c]
  set ref [get_attribute $c ref_name]
  set cp [get_pins -quiet -of_objects $c -filter {name == CP}]
  set dp [get_pins -quiet -of_objects $c -filter {name == D}]
  set qp [get_pins -quiet -of_objects $c -filter {name == Q}]
  set net ""
  if {[sizeof_collection $cp] == 1} {
    set ns [get_nets -quiet -of_objects $cp]
    if {[sizeof_collection $ns] > 0} { set net [get_object_name [index_collection $ns 0]] }
  }
  set class UNCLASSIFIED
  set rtc UNCLASSIFIED_REVIEW_REQUIRED
  if {[regexp {OutputPortModules_[0-9]+/DataReg_ff_reg} $name]} {
    set class OPM_DATA_OUTPUT
    set rtc CMR-OPM-Q-01
  } elseif {[regexp {OutputPortModules_[0-9]+/Reqout_ff_reg$} $name]} {
    set class OPM_REQ_OUTPUT
    set rtc CMR-OPM-Q-01
  } elseif {[regexp {InputPortModules_[0-9]+/RouteComputationUnit/AddressRegister/.*io_dest_FF_reg} $name]} {
    set class RCU_DEST_DATA
    set rtc CMR-RCU-MAT-01
  } elseif {[regexp {InputPortModules_[0-9]+/RouteComputationUnit/AddressRegister/toggle_ff_reg$} $name]} {
    set class RCU_REQ_PHASE
    set rtc CMR-RCU-MAT-01
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/StorageUnit_[0-9]+/dff_reg} $name]} {
    set class IPM_STORAGE_DATA
    set rtc UNMEASURED_CMR-IPM-WRITE-01
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/WriteInterface/Counter/} $name]} {
    set class IPM_WRITE_COUNTER_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/WriteInterface/ControlUnit_[0-9]+/} $name]} {
    set class IPM_WRITE_CONTROL_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/ReadInterface_[0-9]+/Counter/} $name]} {
    set class IPM_READ_COUNTER_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/ReadInterface_[0-9]+/ControlUnit_[0-9]+/} $name]} {
    set class IPM_READ_CONTROL_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/ReadInterface_[0-9]+/PhaseSelector/} $name]} {
    set class IPM_READ_PHASE_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/Buffer/ReadInterface_[0-9]+/AckGenerator/} $name]} {
    set class IPM_READ_ACK_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/RouteComputationUnit/Selector/} $name]} {
    set class RCU_PATH_SELECTOR_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {InputPortModules_[0-9]+/RouteComputationUnit/RouteComputation/InternalAck/} $name]} {
    set class RCU_INTERNAL_ACK_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {OutputPortModules_[0-9]+/TailPassed_[0-9]+_FF_reg$} $name]} {
    set class OPM_TAIL_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } elseif {[regexp {OutputPortModules_[0-9]+/FF[0-9]+_FF[0-9]+_[0-9]+_reg$} $name]} {
    set class OPM_ACK_STATE
    set rtc FUNCTIONAL_LIBRARY_CHECK_REQUIRED
    incr unmeasured_count
  } else {
    incr pending_count
  }
  if {[info exists class_counts($class)]} { incr class_counts($class) } else { set class_counts($class) 1 }
  puts $ifd [join [list [cmr_csv $name] [cmr_csv $ref] [cmr_csv [get_object_name $cp]] [cmr_csv $net] [cmr_csv [get_object_name $dp]] [cmr_csv [get_object_name $qp]] $class $rtc] ","]
}
close $ifd

set scope "$REPORT_DIR/scope.txt"
set sf [open $scope w]
puts $sf "baseline=$BASELINE"
puts $sf "design=CMRRouter RouterL1 child_lanes=1 parent_lanes=1"
puts $sf "corner=ssg0p81v125c"
puts $sf "top_level_io=excluded_external_budget_unavailable"
puts $sf "sequential_cells=$seq_count"
puts $sf "sequential_states_pending_classification=$pending_count"
puts $sf "sequential_states_classified_but_unmeasured=$unmeasured_count"
foreach class [lsort [array names class_counts]] {
  puts $sf "inventory_class.$class=$class_counts($class)"
}
puts $sf "paired_rows=$paired_rows"
puts $sf "paired_no_path_rows=$paired_no_path"
puts $sf "paired_rtm0_shortfall_rows=$paired_shortfall"
puts $sf "measured_classes=CMR-RCU-MAT-01,CMR-OPM-Q-01"
puts $sf "not_yet_measured=IPM_storage_write_bundle,IPM_write_counter/control_checks,IPM_read_counter/control/phase/ack_checks,RCU_path_selector/internal_ack_checks,OPM_tail/ack_checks,AddressRegister_input_bundle"
puts $sf "production_constraints=none"
close $sf

puts "CMR_STA_CLICK_INVENTORY sequential_cells=$seq_count pending_classification=$pending_count"
puts "CMR_STA_CLICK_CATALOG_DONE run_id=$RUN_ID paired_rows=$paired_rows no_path_rows=$paired_no_path shortfall_rows=$paired_shortfall"
quit
