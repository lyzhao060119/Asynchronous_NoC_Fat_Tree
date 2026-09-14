# Step D datapath-first overlay for the frozen CircularFIFO thin NoC16 DDC.
#
# Only maximum-delay on ordinary bundled-data cones:
#   CMR-AR-01   Address_field -> LatchReg.D[23:0]
#   CMR-RCU-01  dest Q -> RouteSelAnd2.g/A1  (Mat)
#   CMR-OPM-01  Datain -> Mux1H -> DataReg.D
#   TCF-RD-01   SlotData Q -> bb.Data_out     (CircularFIFO output mux)
#   TCF-WD-01   Data_in -> slot data_reg.D    (measure-on-seed; skip if floor)
#
# Never constrains Req, Ack, DEL, Mutex, latch E, RouteSelAnd2 Z, close-event,
# WriteCounter, CircularFIFO counters/WCB/RCB, or the TCF-HS-02 / TCF-RD-01
# ECO buffer chains.  No control min-delay.  No DEL resize.

if {![info exists ::env(CMR_DATAPATH_TARGET_FILE)] ||
    ![file exists $::env(CMR_DATAPATH_TARGET_FILE)]} {
  puts "CMR_DATAPATH_FAIL missing target file"
  exit 2
}
source $::env(CMR_DATAPATH_TARGET_FILE)

if {![info exists ::CMR_DP_TARGET_SCALE]} { set ::CMR_DP_TARGET_SCALE 0.95 }
if {![info exists ::CMR_DP_NEAR_FLOOR_NS]} { set ::CMR_DP_NEAR_FLOOR_NS 0.020 }

set ::CMR_DP_APPLIED 0
set ::CMR_DP_MAT_N 0
set ::CMR_DP_OPM_N 0
set ::CMR_DP_AR_N 0
set ::CMR_DP_AR_SKIP 0
set ::CMR_DP_RD01_N 0
set ::CMR_DP_WD01_N 0
set ::CMR_DP_WD01_SKIP 0
set ::CMR_DP_PAIRS [list]

if {[info exists ::env(CMR_DATAPATH_REPORT_DIR)] && $::env(CMR_DATAPATH_REPORT_DIR) ne ""} {
  set dp_report_dir $::env(CMR_DATAPATH_REPORT_DIR)
} elseif {[info exists REPORT_DIR]} {
  set dp_report_dir $REPORT_DIR
} else {
  puts "CMR_DATAPATH_FAIL missing_report_dir"
  exit 2
}
file mkdir $dp_report_dir

proc cmr_dp_freeze {filt label expected} {
  set cells [get_cells -hierarchical -quiet -filter $filt]
  set n [sizeof_collection $cells]
  if {$n > 0} {
    set_dont_touch $cells true
  }
  puts "CMR_DATAPATH_FREEZE $label count=$n expected=$expected"
  if {$expected >= 0 && $n != $expected} {
    puts "CMR_DATAPATH_FAIL freeze_count $label actual=$n expected=$expected"
    exit 2
  }
  return $n
}

proc cmr_dp_measure_max {from to} {
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    return -1.0
  }
  catch { set_max_delay 20.0 -from $from -to $to }
  set worst -1.0
  if {![catch {set paths [get_timing_paths -from $from -to $to -delay_type max -max_paths 8 -nworst 1]}]} {
    foreach_in_collection p $paths {
      set arr [get_attribute $p arrival]
      if {[string is double -strict $arr]} {
        if {$worst < 0.0 || $arr > $worst} {
          set worst $arr
        }
      }
    }
  }
  catch { reset_path -from $from -to $to }
  return $worst
}

proc cmr_dp_scale_target {measured fallback} {
  if {$fallback > 0.0} {
    return $fallback
  }
  if {$measured < 0.0} {
    return -1.0
  }
  if {$measured < $::CMR_DP_NEAR_FLOOR_NS} {
    return $measured
  }
  return [expr {double($measured) * $::CMR_DP_TARGET_SCALE}]
}

proc cmr_dp_apply {id inst from to target_ns measured note} {
  global dp_fd
  set fc [sizeof_collection $from]
  set tc [sizeof_collection $to]
  if {$fc == 0 || $tc == 0} {
    puts $dp_fd "$id,$inst,$target_ns,$measured,$fc,$tc,NO_BIND $note"
    puts "CMR_DATAPATH_FAIL bind id=$id inst=$inst from=$fc to=$tc"
    close $dp_fd
    exit 2
  }
  if {$target_ns <= 0.0} {
    puts $dp_fd "$id,$inst,$target_ns,$measured,$fc,$tc,SKIP_NONPOS $note"
    return 0
  }
  set_max_delay $target_ns -from $from -to $to
  incr ::CMR_DP_APPLIED
  lappend ::CMR_DP_PAIRS [list $id $inst $target_ns]
  puts $dp_fd "$id,$inst,$target_ns,$measured,$fc,$tc,$note"
  puts "CMR_DATAPATH_CONSTRAINT id=$id inst=$inst target_ns=$target_ns from=$fc to=$tc measured=$measured"
  return 1
}

# Hierarchy / async-structure freeze.  Combinational Address/Mat, OPM Mux1H
# and CircularFIFO output-mux cells stay free to size and buffer.
# DEL_cells = 25 * Ackin leaf DELs on the *seed* + 25 * RCU DEL150 on the seed.
# A shrink knife drops or resizes cells after this overlay, so the seed still has
# steps_after+1 RCU DEL150 when CMR_DEL_SHRINK_ROLE is RCU_*, still has
# 25 Ackin DEL250 when the role is OPM_ACKIN (splice-remove) or
# OPM_ACKIN_RESIZE (size_cell keeps the leaf count).
set dp_rcu_steps 4
if {[info exists ::env(CMR_RCU_MATCHED_DELAY_STEPS)] && $::env(CMR_RCU_MATCHED_DELAY_STEPS) ne ""} {
  set dp_rcu_steps $::env(CMR_RCU_MATCHED_DELAY_STEPS)
}
set dp_buf_stages 0
if {[info exists ::env(CMR_RCU_MATCHED_BUF_STAGES)] && $::env(CMR_RCU_MATCHED_BUF_STAGES) ne ""} {
  set dp_buf_stages $::env(CMR_RCU_MATCHED_BUF_STAGES)
}
set dp_ackin_steps 1
if {[info exists ::env(CMR_OPM_ACKIN_DELAY_STEPS)] && $::env(CMR_OPM_ACKIN_DELAY_STEPS) ne ""} {
  set dp_ackin_steps $::env(CMR_OPM_ACKIN_DELAY_STEPS)
}
set dp_shrink_role ""
if {[info exists ::env(CMR_DEL_SHRINK_ROLE)]} {
  set dp_shrink_role [string toupper $::env(CMR_DEL_SHRINK_ROLE)]
}
set dp_rcu_del_on_seed $dp_rcu_steps
if {$dp_shrink_role eq "RCU_DEL150" || $dp_shrink_role eq "RCU_DEL150_TO_BUF"} {
  set dp_rcu_del_on_seed [expr {$dp_rcu_steps + 1}]
}
set dp_ackin_on_seed $dp_ackin_steps
if {$dp_shrink_role eq "OPM_ACKIN" || $dp_shrink_role eq "OPM_ACKIN_RESIZE"} {
  set dp_ackin_on_seed 1
}
set dp_expected_del [expr {25 * $dp_rcu_del_on_seed + 25 * $dp_ackin_on_seed}]
set dp_expected_rcu_buf 0
if {$dp_shrink_role eq "RCU_ADD_BUF" || $dp_shrink_role eq "RCU_TRIM_BUF"} {
  # Seed still has the pre-ECO buffer count; the knife changes it after freeze.
  set dp_expected_rcu_buf -1
} elseif {$dp_shrink_role ne "RCU_DEL150_TO_BUF"} {
  set dp_expected_rcu_buf [expr {25 * $dp_buf_stages}]
}
cmr_dp_freeze {ref_name =~ WriteCounter*} WriteCounter 25
cmr_dp_freeze {ref_name =~ WriteAckGenerator*} WriteAckGenerator 25
cmr_dp_freeze {ref_name =~ HeadPredictor*} HeadPredictor 25
cmr_dp_freeze {ref_name =~ RouteSelAnd2*} RouteSelAnd2 100
cmr_dp_freeze {ref_name =~ Mutex2*} Mutex2 75
cmr_dp_freeze {ref_name =~ Mutex4*} Mutex4 25
cmr_dp_freeze {ref_name =~ LHCNDQD*} LHCNDQD 6669
cmr_dp_freeze {ref_name =~ LHSNDQD*} LHSNDQD 498
cmr_dp_freeze {ref_name =~ DEL*} DEL_cells $dp_expected_del
cmr_dp_freeze {ref_name =~ DelayElement*} DelayElement -1
cmr_dp_freeze {ref_name =~ CircularWriteCounter*} CircularWriteCounter 8
cmr_dp_freeze {ref_name =~ CircularReadCounter*} CircularReadCounter 8
cmr_dp_freeze {ref_name =~ WriteControlBlock*} WriteControlBlock 32
cmr_dp_freeze {ref_name =~ ReadControlBlock*} ReadControlBlock 32
cmr_dp_freeze {full_name =~ *cfifo_hs02_ack_counter_buf_s*} TCF_HS02_BUF 24
cmr_dp_freeze {full_name =~ *cfifo_rd01_reqout_buf_s*} TCF_RD01_BUF 512
cmr_dp_freeze {full_name =~ *rcu_matched_buf_s*} RCU_MATCHED_BUF $dp_expected_rcu_buf

set dp_fd [open "$dp_report_dir/datapath_constraints_precompile.rpt" w]
puts $dp_fd "id,instance,target_ns,measured_ns,from_count,to_count,note"

# ---- CMR-RCU-01 Mat: dest Q -> RouteSelAnd2.g/A1 ----
if {![info exists ::CMR_DP_MAT_NS] || $::CMR_DP_MAT_NS <= 0.0} {
  puts "CMR_DATAPATH_FAIL invalid MAT target"
  close $dp_fd
  exit 2
}
set rcus [get_cells -hierarchical -quiet -filter {
  full_name =~ *InputPortModules_*/RouteComputationUnit && ref_name =~ RCU*
}]
if {[sizeof_collection $rcus] != 25} {
  puts "CMR_DATAPATH_FAIL rcu_count actual=[sizeof_collection $rcus] expected=25"
  close $dp_fd
  exit 2
}
foreach_in_collection rcu $rcus {
  set root [get_object_name $rcu]
  set req_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/Q"]
  set dest_q [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/Q"]
  set dest_q [remove_from_collection $dest_q $req_q]
  set anda [get_pins -quiet -hierarchical -filter "full_name =~ $root/*RouteSelAnd_*/g/A1 || full_name =~ $root/*RouteSelAnd_*/A1"]
  if {[sizeof_collection $dest_q] != 24 || [sizeof_collection $anda] != 4} {
    puts "CMR_DATAPATH_FAIL mat_bind rcu=$root dest_q=[sizeof_collection $dest_q] anda=[sizeof_collection $anda]"
    close $dp_fd
    exit 2
  }
  cmr_dp_apply CMR-RCU-01 $root $dest_q $anda $::CMR_DP_MAT_NS NA \
    "Mat cone only; RouteSelAnd2 frozen; not Req_rc/Z"
  incr ::CMR_DP_MAT_N
}

# ---- CMR-OPM-01 Mux1H: Datain -> DataReg.D ----
if {![info exists ::CMR_DP_OPM_NS] || $::CMR_DP_OPM_NS <= 0.0} {
  puts "CMR_DATAPATH_FAIL invalid OPM target"
  close $dp_fd
  exit 2
}
set opm_n 0
set opms ""
foreach_in_collection c [get_cells -hierarchical -quiet -filter {ref_name =~ OPM*}] {
  set name [get_object_name $c]
  if {[regexp {OutputPortModules_[0-9]+$} $name]} {
    if {$opm_n == 0} {
      set opms $c
    } else {
      set opms [add_to_collection $opms $c]
    }
    incr opm_n
  }
}
if {$opm_n != 25} {
  puts "CMR_DATAPATH_FAIL opm_count actual=$opm_n expected=25"
  close $dp_fd
  exit 2
}
foreach_in_collection opm $opms {
  set root [get_object_name $opm]
  set data_d [get_pins -quiet "$root/DataReg/resettable_latch\[*\].latch_cell/D"]
  set datain [get_pins -quiet -of_objects $opm -filter {name =~ io_Datain_*flit*}]
  if {[sizeof_collection $datain] == 0} {
    set datain [get_pins -quiet -hierarchical -filter "full_name =~ $root/io_Datain*flit*"]
  }
  if {[sizeof_collection $data_d] != 28 || [sizeof_collection $datain] < 28} {
    puts "CMR_DATAPATH_FAIL opm_bind inst=$root data_d=[sizeof_collection $data_d] datain=[sizeof_collection $datain]"
    close $dp_fd
    exit 2
  }
  cmr_dp_apply CMR-OPM-01 $root $datain $data_d $::CMR_DP_OPM_NS NA \
    "Mux1H to DataReg.D; not E/L5/Ackin"
  incr ::CMR_DP_OPM_N
}

# ---- CMR-AR-01 Address: Datain.flit[25:2] -> LatchReg.D[23:0] ----
set ar_target_fixed 0
if {[info exists ::CMR_DP_AR_NS] && $::CMR_DP_AR_NS > 0.0} {
  set ar_target_fixed 1
}
foreach_in_collection rcu $rcus {
  set root [get_object_name $rcu]
  set addr_d [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[*\].latch_cell/D"]
  set req_d [get_pins -quiet "$root/AddressRegister/LatchReg/resettable_latch\[24\].latch_cell/D"]
  set addr_d [remove_from_collection $addr_d $req_d]
  set ipm [file dirname $root]
  set ipm_cell [get_cells -quiet $ipm]
  set datain [get_pins -quiet -of_objects $ipm_cell -filter {name =~ io_Datain_flit*}]
  if {[sizeof_collection $datain] == 0} {
    set datain [get_pins -quiet "$root/AddressRegister/Address_field*"]
  }
  if {[sizeof_collection $addr_d] != 24} {
    puts "CMR_DATAPATH_FAIL ar_bind rcu=$root addr_d=[sizeof_collection $addr_d] datain=[sizeof_collection $datain]"
    close $dp_fd
    exit 2
  }
  set measured [cmr_dp_measure_max $datain $addr_d]
  set target [cmr_dp_scale_target $measured $::CMR_DP_AR_NS]
  set note "address bits only; not En/Req_pc"
  if {$measured >= 0.0 && $measured < $::CMR_DP_NEAR_FLOOR_NS && !$ar_target_fixed} {
    append note {; near-floor ceiling, no 5pct squeeze}
    incr ::CMR_DP_AR_SKIP
  }
  if {$target <= 0.0} {
    puts $dp_fd "CMR-AR-01,$root,$target,$measured,[sizeof_collection $datain],[sizeof_collection $addr_d],SKIP $note"
    incr ::CMR_DP_AR_SKIP
    continue
  }
  cmr_dp_apply CMR-AR-01 $root $datain $addr_d $target $measured $note
  incr ::CMR_DP_AR_N
}

# ---- TCF-RD-01 / TCF-WD-01 on eight CircularFIFO bb instances ----
if {![info exists ::CMR_DP_FIFO_NS]} { set ::CMR_DP_FIFO_NS 0.0 }
set fifos ""
set fifo_n 0
foreach_in_collection c [get_cells -hierarchical -quiet -filter {
  full_name =~ *upwardLinkFifos_*/bb || full_name =~ *downwardLinkFifos_*/bb
}] {
  set n [get_object_name $c]
  if {[regexp {(upward|downward)LinkFifos_[0-9]+/bb$} $n]} {
    if {$fifo_n == 0} {
      set fifos $c
    } else {
      set fifos [add_to_collection $fifos $c]
    }
    incr fifo_n
  }
}
if {$fifo_n != 8} {
  puts "CMR_DATAPATH_FAIL circular_bb_count actual=$fifo_n expected=8"
  close $dp_fd
  exit 2
}
foreach_in_collection fifo $fifos {
  set root [get_object_name $fifo]
  set data_q [get_pins -hierarchical -quiet -filter "full_name =~ $root*data_reg* && name == Q"]
  set data_out [get_pins -quiet -of_objects $fifo -filter {name =~ Data_out*}]
  if {[sizeof_collection $data_out] == 0} {
    set data_out [get_pins -quiet -hierarchical -filter "full_name =~ $root/Data_out*"]
  }
  if {[sizeof_collection $data_q] != 112 || [sizeof_collection $data_out] != 28} {
    puts "CMR_DATAPATH_FAIL rd01_bind fifo=$root data_q=[sizeof_collection $data_q] data_out=[sizeof_collection $data_out]"
    close $dp_fd
    exit 2
  }
  set measured [cmr_dp_measure_max $data_q $data_out]
  set target [cmr_dp_scale_target $measured $::CMR_DP_FIFO_NS]
  if {$target <= 0.0} {
    puts "CMR_DATAPATH_FAIL rd01_target fifo=$root measured=$measured"
    close $dp_fd
    exit 2
  }
  cmr_dp_apply TCF-RD-01 $root $data_q $data_out $target $measured \
    "SlotData Q to Data_out mux; Reqout/U2 ECO frozen"
  incr ::CMR_DP_RD01_N

  set data_in [get_pins -quiet -of_objects $fifo -filter {name =~ Data_in*}]
  set data_d [get_pins -hierarchical -quiet -filter "full_name =~ $root*data_reg* && name == D"]
  if {[sizeof_collection $data_in] == 0 || [sizeof_collection $data_d] != 112} {
    puts $dp_fd "TCF-WD-01,$root,0,[sizeof_collection $data_in],[sizeof_collection $data_d],SKIP bind"
    incr ::CMR_DP_WD01_SKIP
    continue
  }
  set wd_measured [cmr_dp_measure_max $data_in $data_d]
  set wd_target [cmr_dp_scale_target $wd_measured 0.0]
  set wd_note "write capture Data_in to slot D; not En"
  if {$wd_measured >= 0.0 && $wd_measured < $::CMR_DP_NEAR_FLOOR_NS} {
    append wd_note {; near-floor ceiling}
    incr ::CMR_DP_WD01_SKIP
  }
  if {$wd_target <= 0.0} {
    puts $dp_fd "TCF-WD-01,$root,$wd_target,$wd_measured,[sizeof_collection $data_in],[sizeof_collection $data_d],SKIP $wd_note"
    incr ::CMR_DP_WD01_SKIP
    continue
  }
  cmr_dp_apply TCF-WD-01 $root $data_in $data_d $wd_target $wd_measured $wd_note
  incr ::CMR_DP_WD01_N
}

close $dp_fd

puts "CMR_DATAPATH_CONSTRAINT_COUNT=$::CMR_DP_APPLIED MAT=$::CMR_DP_MAT_N OPM=$::CMR_DP_OPM_N AR=$::CMR_DP_AR_N AR_SKIP=$::CMR_DP_AR_SKIP RD01=$::CMR_DP_RD01_N WD01=$::CMR_DP_WD01_N WD01_SKIP=$::CMR_DP_WD01_SKIP"
if {$::CMR_DP_MAT_N != 25 || $::CMR_DP_OPM_N != 25 || $::CMR_DP_RD01_N != 8} {
  puts "CMR_DATAPATH_FAIL cone_count MAT=$::CMR_DP_MAT_N OPM=$::CMR_DP_OPM_N RD01=$::CMR_DP_RD01_N"
  exit 2
}
if {$::CMR_DP_APPLIED < 58} {
  puts "CMR_DATAPATH_FAIL too_few_constraints=$::CMR_DP_APPLIED"
  exit 2
}

proc cmr_dp_report_tdata {path} {
  set fd [open $path w]
  puts $fd "id,instance,target_ns"
  foreach triple $::CMR_DP_PAIRS {
    puts $fd [join $triple ,]
  }
  close $fd
  puts "CMR_DATAPATH_TDATA_REPORT $path pairs=[llength $::CMR_DP_PAIRS]"
}
