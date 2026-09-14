# Pin-level audit of Fig. 7 WritePointer completion (CMR-WP-01 / HS-02 / HS-01).
# Reads the frozen post-DC DDC; does not compile or write a netlist.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_NOC16_BASELINE)
set RUN_ID $::env(CMR_WP_RTM_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
current_design NoC_16nodes
link

proc cmr_wp_pins {filter} {
  return [get_pins -hierarchical -quiet -filter $filter]
}

proc cmr_wp_dump {path coll {limit 12}} {
  set fd [open $path w]
  set n [sizeof_collection $coll]
  puts $fd "COUNT=$n"
  set i 0
  foreach_in_collection obj $coll {
    puts $fd [get_object_name $obj]
    incr i
    if {$i >= $limit} {
      break
    }
  }
  close $fd
}

proc cmr_wp_worst_arrival {from to dtype max_paths} {
  set paths [get_timing_paths -from $from -to $to -delay_type $dtype -max_paths $max_paths]
  if {[sizeof_collection $paths] == 0} {
    return "NA"
  }
  set worst ""
  foreach_in_collection path $paths {
    set arr [get_attribute $path arrival]
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
    return "NA"
  }
  return [format "%.4f" $worst]
}

set counters [get_cells -hierarchical -quiet -filter {ref_name =~ WriteCounter*}]
if {[sizeof_collection $counters] == 0} {
  set counters [get_cells -hierarchical -quiet -filter {full_name =~ *WriteInterface*Counter*}]
}
set wcu [get_cells -hierarchical -quiet -filter {ref_name =~ WriteControlUnit*}]
set phase_reg [get_cells -hierarchical -quiet -filter {full_name =~ *PhaseSelectorBlock/phase_reg && ref_name =~ DF*}]
if {[sizeof_collection $phase_reg] == 0} {
  set phase_reg [get_cells -hierarchical -quiet -filter {full_name =~ *PhaseSelector*/phase_reg*}]
}

set ck [cmr_wp_pins {full_name =~ *WriteInterface*Counter* && (name == CP || name == CK)}]
if {[sizeof_collection $ck] == 0} {
  set ck [cmr_wp_pins {full_name =~ *WriteCounter* && (name == CP || name == CK)}]
}
set e_pins [cmr_wp_pins {full_name =~ *WriteInterface*ControlUnit_*CellFullLatch* && name == E}]
if {[sizeof_collection $e_pins] == 0} {
  set e_pins [cmr_wp_pins {full_name =~ *WriteInterface*ControlUnit_* && name == E}]
}
set wp_q [cmr_wp_pins {full_name =~ *WriteInterface*Counter*WritePointer* && (name == Q || name == QN)}]
if {[sizeof_collection $wp_q] == 0} {
  set wp_q [cmr_wp_pins {full_name =~ *WriteInterface*Counter* && name == Q}]
}
set req_ck [cmr_wp_pins {full_name =~ *WriteInterface*Counter*/Reqin}]
if {[sizeof_collection $req_ck] == 0} {
  set req_ck [cmr_wp_pins {full_name =~ *WriteCounter*/Reqin}]
}
set ack_ck [cmr_wp_pins {full_name =~ *WriteInterface*Counter*/Ackout}]
if {[sizeof_collection $ack_ck] == 0} {
  set ack_ck [cmr_wp_pins {full_name =~ *WriteCounter*/Ackout}]
}
set head_d [cmr_wp_pins {full_name =~ *PhaseSelectorBlock/phase_reg/D}]
if {[sizeof_collection $head_d] == 0} {
  set head_d [cmr_wp_pins {full_name =~ *PhaseSelector*/phase_reg*/D}]
}
set ps_cp [cmr_wp_pins {full_name =~ *PhaseSelectorBlock/phase_reg/CP}]
if {[sizeof_collection $ps_cp] == 0} {
  set ps_cp [cmr_wp_pins {full_name =~ *PhaseSelector*/phase_reg*/CP}]
}
set ps_head [cmr_wp_pins {full_name =~ *PhaseSelectorBlock/Head}]
if {[sizeof_collection $ps_head] == 0} {
  set ps_head [cmr_wp_pins {full_name =~ *PhaseSelector*/Head}]
}

set n_counter [sizeof_collection $counters]
set n_wcu [sizeof_collection $wcu]
set n_phase [sizeof_collection $phase_reg]
set n_ck [sizeof_collection $ck]
set n_e [sizeof_collection $e_pins]
set n_q [sizeof_collection $wp_q]
set n_req [sizeof_collection $req_ck]
set n_ack [sizeof_collection $ack_ck]
set n_head_d [sizeof_collection $head_d]
set n_ps_cp [sizeof_collection $ps_cp]
set n_ps_head [sizeof_collection $ps_head]

puts "CMR_WP_RTM_STRUCTURE counters=$n_counter wcu=$n_wcu phase_reg=$n_phase ck=$n_ck e=$n_e q=$n_q req=$n_req ack=$n_ack head_d=$n_head_d ps_cp=$n_ps_cp ps_head=$n_ps_head"

cmr_wp_dump "$REPORT_DIR/pins_counter.rpt" $counters 25
cmr_wp_dump "$REPORT_DIR/pins_ck.rpt" $ck 20
cmr_wp_dump "$REPORT_DIR/pins_e.rpt" $e_pins 20
cmr_wp_dump "$REPORT_DIR/pins_req.rpt" $req_ck 10
cmr_wp_dump "$REPORT_DIR/pins_ack.rpt" $ack_ck 10
cmr_wp_dump "$REPORT_DIR/pins_phase_reg.rpt" $phase_reg 10

if {$n_counter != 25 || $n_wcu != 125 || $n_ck < 25 || $n_e != 125 || $n_req != 25 || $n_ack != 25} {
  puts "CMR_WP_RTM_FAIL pin_bind counters=$n_counter wcu=$n_wcu ck=$n_ck e=$n_e req=$n_req ack=$n_ack"
  exit 2
}

# Analysis-only dummy windows so unconstrained combo paths still report arrival.
if {$n_q > 0} {
  set_max_delay 10.0 -from $wp_q -to $e_pins
} else {
  set_max_delay 10.0 -from $ck -to $e_pins
}
set_max_delay 10.0 -from $req_ck -to $ck
set_max_delay 10.0 -from $ack_ck -to $ck
set_min_delay 0.0 -from $req_ck -to $ck
set_min_delay 0.0 -from $ack_ck -to $ck
if {$n_q > 0} {
  set_min_delay 0.0 -from $wp_q -to $e_pins
}

set ptr_from $ck
if {$n_q > 0} {
  set ptr_from $wp_q
}

redirect "$REPORT_DIR/ptr_max.rpt" {
  report_timing -from $ptr_from -to $e_pins -delay_type max -max_paths 50 -nosplit
}
redirect "$REPORT_DIR/ptr_min.rpt" {
  report_timing -from $ptr_from -to $e_pins -delay_type min -max_paths 50 -nosplit
}
redirect "$REPORT_DIR/req_to_ck_max.rpt" {
  report_timing -from $req_ck -to $ck -delay_type max -max_paths 50 -nosplit
}
redirect "$REPORT_DIR/req_to_ck_min.rpt" {
  report_timing -from $req_ck -to $ck -delay_type min -max_paths 50 -nosplit
}
redirect "$REPORT_DIR/ack_to_ck_max.rpt" {
  report_timing -from $ack_ck -to $ck -delay_type max -max_paths 50 -nosplit
}
redirect "$REPORT_DIR/ack_to_ck_min.rpt" {
  report_timing -from $ack_ck -to $ck -delay_type min -max_paths 50 -nosplit
}

if {$n_ps_head > 0 && $n_head_d > 0} {
  set_max_delay 10.0 -from $ps_head -to $head_d
  redirect "$REPORT_DIR/hs01_head_to_d_max.rpt" {
    report_timing -from $ps_head -to $head_d -delay_type max -max_paths 25 -nosplit
  }
}

set ptr_max [cmr_wp_worst_arrival $ptr_from $e_pins max 50]
set ptr_min [cmr_wp_worst_arrival $ptr_from $e_pins min 50]
set req_max [cmr_wp_worst_arrival $req_ck $ck max 50]
set req_min [cmr_wp_worst_arrival $req_ck $ck min 50]
set ack_max [cmr_wp_worst_arrival $ack_ck $ck max 50]
set ack_min [cmr_wp_worst_arrival $ack_ck $ck min 50]
set head_max "NA"
if {$n_ps_head > 0 && $n_head_d > 0} {
  set head_max [cmr_wp_worst_arrival $ps_head $head_d max 25]
}

puts "CMR_WP_RTM ptr_max_ns=$ptr_max ptr_min_ns=$ptr_min req_to_ck_max_ns=$req_max req_to_ck_min_ns=$req_min ack_to_ck_max_ns=$ack_max ack_to_ck_min_ns=$ack_min head_to_d_max_ns=$head_max"
puts "CMR_WP_RTM_STA_DONE report=$REPORT_DIR"
quit
