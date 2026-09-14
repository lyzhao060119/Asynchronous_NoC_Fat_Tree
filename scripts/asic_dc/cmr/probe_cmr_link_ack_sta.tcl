# One-FIFO ACK/HS-02 path probe on the frozen F DDC. Analysis only.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set BASELINE $::env(CMR_NOC16_BASELINE)
set RUN_ID $::env(CMR_PAIRED_STA_RUN_ID)
set REPORT_DIR "$PROJECT_DIR/reports/sta/$RUN_ID"
file mkdir $REPORT_DIR

set STA_DIR [file dirname [info script]]
source "$STA_DIR/sta_cmr_paired_lib.tcl"
source "$PROJECT_DIR/rtl/tech_t28ss.tcl"
read_ddc "$PROJECT_DIR/outputs/$BASELINE/NoC_16nodes.ddc"
current_design NoC_16nodes
link

proc cmr_probe_try {label from to} {
  puts "CMR_LINK_PROBE try $label from=[sizeof_collection $from] to=[sizeof_collection $to]"
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    puts "CMR_LINK_PROBE $label BIND_MISS"
    return
  }
  puts "CMR_LINK_PROBE $label from_pin=[get_object_name [index_collection $from 0]] to_pin=[get_object_name [index_collection $to 0]]"
  if {[catch {set_max_delay $::CMR_STA_WINDOW_NS -from $from -to $to} err]} {
    puts "CMR_LINK_PROBE $label set_max_delay FAIL $err"
  } else {
    puts "CMR_LINK_PROBE $label set_max_delay OK"
  }
  if {[catch {set_min_delay 0.0 -from $from -to $to} err]} {
    puts "CMR_LINK_PROBE $label set_min_delay FAIL $err"
  } else {
    puts "CMR_LINK_PROBE $label set_min_delay OK"
  }
  foreach spec [list {max ""} {min ""} {max rise} {min rise} {max fall} {min fall}] {
    set dtype [lindex $spec 0]
    set edge [lindex $spec 1]
    set val [cmr_sta_worst $from $to $dtype $edge]
    puts "CMR_LINK_PROBE $label dtype=$dtype edge='$edge' val=$val"
  }
  catch { reset_path -from $from -to $to }
}

set bb upwardLinkFifos_0/bb
set ipm routerL2/InputPortModules_0
set req [cmr_sta_counter_req $bb]
set ackin [cmr_sta_cell_pins $bb {name == Ackin}]
set a1 [cmr_sta_xnor_a1 $bb]
set a2 [cmr_sta_xnor_req_pin $bb]
set z [cmr_sta_xnor_out $bb]
set bufz [cmr_sta_hs02_buf_z $bb]
set ipm_ack [cmr_sta_cell_pins $ipm {name == io_Ackout}]
puts "CMR_LINK_PROBE bind req=[sizeof_collection $req] ackin=[sizeof_collection $ackin] a1=[sizeof_collection $a1] a2=[sizeof_collection $a2] z=[sizeof_collection $z] bufz=[sizeof_collection $bufz] ipm_ack=[sizeof_collection $ipm_ack]"
if {[sizeof_collection $z] == 1} {
  puts "CMR_LINK_PROBE xnor_out=[get_object_name $z]"
}
if {[sizeof_collection $bufz] > 0} {
  puts "CMR_LINK_PROBE bufz=[get_object_name [index_collection $bufz 0]] n=[sizeof_collection $bufz]"
}
if {[sizeof_collection $a1] == 1} {
  catch {
    set fanin [all_fanin -to $a1 -flat -startpoints_only]
    puts "CMR_LINK_PROBE a1_fanin_n=[sizeof_collection $fanin]"
    set i 0
    foreach_in_collection p $fanin {
      if {$i < 12} {
        puts "CMR_LINK_PROBE a1_fanin=[get_object_name $p]"
      }
      incr i
    }
  }
}
if {[sizeof_collection $bufz] == 1} {
  catch {
    set fanin [all_fanin -to $bufz -flat -startpoints_only]
    puts "CMR_LINK_PROBE bufz_fanin_n=[sizeof_collection $fanin]"
    set i 0
    foreach_in_collection p $fanin {
      if {$i < 12} {
        puts "CMR_LINK_PROBE bufz_fanin=[get_object_name $p]"
      }
      incr i
    }
  }
}

puts "CMR_LINK_PROBE --- leaf drivers ---"
set req_leaf [cmr_sta_leaf_drivers $req]
set ackin_leaf [cmr_sta_leaf_drivers $ackin]
set ipm_leaf [cmr_sta_leaf_drivers $ipm_ack]
set a2_leaf [cmr_sta_leaf_drivers $a2]
puts "CMR_LINK_PROBE req_leaf_n=[sizeof_collection $req_leaf] ackin_leaf_n=[sizeof_collection $ackin_leaf] ipm_leaf_n=[sizeof_collection $ipm_leaf] a2_drv_n=[sizeof_collection $a2_leaf]"
if {[sizeof_collection $req_leaf] > 0} {
  puts "CMR_LINK_PROBE req_leaf0=[get_object_name [index_collection $req_leaf 0]]"
}
if {[sizeof_collection $ackin_leaf] > 0} {
  puts "CMR_LINK_PROBE ackin_leaf0=[get_object_name [index_collection $ackin_leaf 0]]"
}
if {[sizeof_collection $ipm_leaf] > 0} {
  puts "CMR_LINK_PROBE ipm_leaf0=[get_object_name [index_collection $ipm_leaf 0]]"
}
if {[sizeof_collection $a2_leaf] > 0} {
  puts "CMR_LINK_PROBE a2_drv0=[get_object_name [index_collection $a2_leaf 0]]"
}
cmr_probe_try io_ack $ipm_ack $ackin
cmr_probe_try leaf_hs02_req $req_leaf $a2
cmr_probe_try leaf_hs02_ack $ackin_leaf $a1
cmr_probe_try leaf_ack_ipm $ipm_leaf $a1
cmr_probe_try leaf_ack_bufz $ipm_leaf $bufz
cmr_probe_try a2drv_a2 $a2_leaf $a2

puts "CMR_LINK_PROBE --- no loop cut ---"
cmr_probe_try hs02_req_a2 $req $a2
cmr_probe_try hs02_ack_a1 $ackin $a1
cmr_probe_try ack_ipm_a1 $ipm_ack $a1
cmr_probe_try ack_ipm_bufz $ipm_ack $bufz
cmr_probe_try hs02_ack_bufz $ackin $bufz
cmr_probe_try hs02_req_z $req $z
cmr_probe_try hs02_ack_z $ackin $z

puts "CMR_LINK_PROBE --- EmptyLatch disable ---"
set elatch [get_cells -hierarchical -quiet -filter "full_name =~ $bb*EmptyLatch*latch_cell*"]
puts "CMR_LINK_PROBE elatch_n=[sizeof_collection $elatch]"
if {[sizeof_collection $elatch] > 0} {
  catch { set_disable_timing $elatch }
}
set b1z [get_pins -hierarchical -quiet -filter "full_name =~ $bb*cfifo_hs02_ack_counter_buf_s1* && name == Z"]
puts "CMR_LINK_PROBE b1z_n=[sizeof_collection $b1z]"
cmr_probe_try leaf_ack_bufz_el $ipm_leaf $bufz
cmr_probe_try leaf_ack_a1_el $ipm_leaf $a1
cmr_probe_try leaf_req_a2_el $req_leaf $a2
cmr_probe_try buf1_buf3 $b1z $bufz
if {[sizeof_collection $elatch] > 0} {
  catch { remove_disable_timing $elatch }
}

set cut [cmr_sta_cut_xnor_loop $bb]
puts "CMR_LINK_PROBE --- with U10 loop cut ---"
cmr_probe_try hs02_req_a2 $req $a2
cmr_probe_try hs02_ack_a1 $ackin $a1
cmr_probe_try ack_ipm_a1 $ipm_ack $a1
cmr_probe_try ack_ipm_bufz $ipm_ack $bufz
cmr_probe_try hs02_ack_bufz $ackin $bufz
cmr_probe_try hs02_req_z $req $z
cmr_probe_try hs02_ack_z $ackin $z
cmr_sta_uncut_xnor_loop $cut

puts "CMR_LINK_PROBE_DONE baseline=$BASELINE"
quit
