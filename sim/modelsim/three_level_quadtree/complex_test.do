proc ns {ps} {
  return [expr {$ps / 1000.0}]
}

proc bit_path {kind dir idx field} {
  return [format "sim:/three_level_quadtree/io_%s_%s_%d_%s" $kind $dir $idx $field]
}

proc req_path {kind dir idx} {
  return [bit_path $kind $dir $idx "HS_Req"]
}

proc ack_path {kind dir idx} {
  return [bit_path $kind $dir $idx "HS_Ack"]
}

proc data_path {kind dir idx} {
  return [bit_path $kind $dir $idx "Data_flit"]
}

proc get_bit {path} {
  set value [string trim [examine -radix binary $path]]
  if {[regexp {[xXzZ]} $value]} {
    return -1
  }
  return [expr {$value eq "1" ? 1 : 0}]
}

proc get_uint {path} {
  set value [string trim [examine -radix unsigned $path]]
  if {[regexp {[xXzZ]} $value]} {
    return -1
  }
  return [expr {$value + 0}]
}

proc mk_flit {isHead isTail destX destY copyX copyY id} {
  return [expr {
    (($isHead & 1) << 21) |
    (($isTail & 1) << 20) |
    (($destX  & 63) << 14) |
    (($destY  & 63) << 8)  |
    (($copyX  & 7)  << 5)  |
    (($copyY  & 7)  << 2)  |
    ($id & 3)
  }]
}

proc mk_packet {destX destY copyX copyY id} {
  set head [mk_flit 1 0 $destX $destY $copyX $copyY $id]
  set body [mk_flit 0 0 $destX $destY $copyX $copyY $id]
  set tail [mk_flit 0 1 $destX $destY $copyX $copyY $id]
  return [list $head $body $tail]
}

proc core_index {x y} {
  return [expr {$x + 8 * $y}]
}

proc sink_delay_ps {idx} {
  return [expr {5000 + 5000 * ($idx % 4)}]
}

proc expect_add {coreList id count} {
  global expCount expected_total
  foreach idx $coreList {
    if {![info exists expCount($idx,$id)]} {
      set expCount($idx,$id) 0
    }
    incr expCount($idx,$id) $count
    incr expected_total $count
  }
}

proc all_sinks_idle {} {
  global sink_pending
  for {set idx 0} {$idx < 64} {incr idx} {
    if {$sink_pending($idx)} {
      return 0
    }
  }
  return 1
}

proc all_injections_done {} {
  global inject_events inject_done
  foreach event $inject_events {
    set label [lindex $event 0]
    if {!$inject_done($label)} {
      return 0
    }
  }
  return 1
}

proc handle_injections {} {
  global inject_events inject_done sim_ps

  foreach event $inject_events {
    set label [lindex $event 0]
    set fire_ps [lindex $event 1]
    set kind    [lindex $event 2]
    set dir     [lindex $event 3]
    set idx     [lindex $event 4]
    set reqVal  [lindex $event 5]
    set flit    [lindex $event 6]

    if {!$inject_done($label) && $sim_ps >= $fire_ps} {
      force -deposit [data_path $kind $dir $idx] [format "16#%06X" $flit]
      force -deposit [req_path  $kind $dir $idx] $reqVal
      puts [format {\[%6.1f ns\] inject %-8s -> %s/%s[%02d] data=0x%06X req=%d} \
        [ns $sim_ps] $label $kind $dir $idx $flit $reqVal]
      set inject_done($label) 1
    }
  }
}

proc handle_core_sinks {} {
  global gotCount got_total sink_pending sink_due_ps sink_target_ack sim_ps

  for {set idx 0} {$idx < 64} {incr idx} {
    set reqSig  [req_path core outputs $idx]
    set ackSig  [ack_path core outputs $idx]
    set dataSig [data_path core outputs $idx]

    if {$sink_pending($idx) && $sim_ps >= $sink_due_ps($idx)} {
      force -deposit $ackSig $sink_target_ack($idx)
      set sink_pending($idx) 0
    }

    if {!$sink_pending($idx)} {
      set req [get_bit $reqSig]
      set ack [get_bit $ackSig]
      if {$req >= 0 && $ack >= 0 && $req != $ack} {
        set data [get_uint $dataSig]
        set id [expr {$data & 3}]
        if {![info exists gotCount($idx,$id)]} {
          set gotCount($idx,$id) 0
        }
        incr gotCount($idx,$id)
        incr got_total

        set sink_pending($idx) 1
        set sink_due_ps($idx) [expr {$sim_ps + [sink_delay_ps $idx]}]
        set sink_target_ack($idx) $req

        puts [format {\[%6.1f ns\] sink core%02d recv id=%d flit=0x%06X delay=%4.1f ns} \
          [ns $sim_ps] $idx $id $data [ns [sink_delay_ps $idx]]]
      }
    }
  }
}

proc check_top_outputs {} {
  global sim_ps
  for {set idx 0} {$idx < 8} {incr idx} {
    set req [get_bit [req_path top output $idx]]
    set ack [get_bit [ack_path top output $idx]]
    if {$req >= 0 && $ack >= 0 && $req != $ack} {
      set data [get_uint [data_path top output $idx]]
      error [format {\[%6.1f ns\] unexpected top_output[%d] flit=0x%06X} [ns $sim_ps] $idx $data]
    }
  }
}

set pktA [mk_packet 4 4 3 3 1]
set pktB [mk_packet 0 0 3 3 2]
set pktC [mk_packet 6 6 1 1 3]

set dstA {}
for {set y 4} {$y < 8} {incr y} {
  for {set x 4} {$x < 8} {incr x} {
    lappend dstA [core_index $x $y]
  }
}

set dstB {}
for {set y 0} {$y < 4} {incr y} {
  for {set x 0} {$x < 4} {incr x} {
    lappend dstB [core_index $x $y]
  }
}

set dstC {}
foreach y {6 7} {
  foreach x {6 7} {
    lappend dstC [core_index $x $y]
  }
}

set expected_total 0
array set expCount {}
expect_add $dstA 1 3
expect_add $dstB 2 3
expect_add $dstC 3 3

set inject_events [list \
  [list A_head 40000 core inputs 0  1 [lindex $pktA 0]] \
  [list A_body 50000 core inputs 0  0 [lindex $pktA 1]] \
  [list A_tail 60000 core inputs 0  1 [lindex $pktA 2]] \
  [list B_head 45000 core inputs 63 1 [lindex $pktB 0]] \
  [list B_body 55000 core inputs 63 0 [lindex $pktB 1]] \
  [list B_tail 65000 core inputs 63 1 [lindex $pktB 2]] \
  [list C_head 55000 top  input  0  1 [lindex $pktC 0]] \
  [list C_body 65000 top  input  0  0 [lindex $pktC 1]] \
  [list C_tail 75000 top  input  0  1 [lindex $pktC 2]] \
]
array set inject_done {}
foreach event $inject_events {
  set inject_done([lindex $event 0]) 0
}

array set gotCount {}
set got_total 0

array set sink_pending {}
array set sink_due_ps {}
array set sink_target_ack {}
for {set idx 0} {$idx < 64} {incr idx} {
  set sink_pending($idx) 0
  set sink_due_ps($idx) 0
  set sink_target_ack($idx) 0
}

force -deposit sim:/three_level_quadtree/clock 0
force -deposit sim:/three_level_quadtree/reset 1

for {set idx 0} {$idx < 64} {incr idx} {
  force -deposit [req_path core inputs $idx] 0
  force -deposit [data_path core inputs $idx] 0
  force -deposit [ack_path core outputs $idx] 0
}
for {set idx 0} {$idx < 8} {incr idx} {
  force -deposit [req_path top input $idx] 0
  force -deposit [data_path top input $idx] 0
  force -deposit [ack_path top output $idx] 0
}

set sim_ps 0
run 20 ns
set sim_ps 20000
force -deposit sim:/three_level_quadtree/reset 0
puts [format {\[%6.1f ns\] reset released} [ns $sim_ps]]

set timeout_ps 400000
set step_ps 5000
set quiet_count 0
set quiet_goal 10

while {$sim_ps < $timeout_ps} {
  run [format "%d ps" $step_ps]
  incr sim_ps $step_ps

  handle_core_sinks
  check_top_outputs
  handle_injections

  if {$got_total > $expected_total && [all_injections_done]} {
    error [format "duplicate deliveries detected at %.1f ns, got %d / %d flits" [ns $sim_ps] $got_total $expected_total]
  }

  if {$got_total == $expected_total && [all_injections_done] && [all_sinks_idle]} {
    incr quiet_count
    if {$quiet_count >= $quiet_goal} {
      break
    }
  } else {
    set quiet_count 0
  }
}

if {$sim_ps >= $timeout_ps} {
  error [format "timeout at %.1f ns, got %d / %d flits" [ns $sim_ps] $got_total $expected_total]
}

set failures 0
for {set idx 0} {$idx < 64} {incr idx} {
  foreach id {1 2 3} {
    set expVal 0
    set gotVal 0
    if {[info exists expCount($idx,$id)]} {
      set expVal $expCount($idx,$id)
    }
    if {[info exists gotCount($idx,$id)]} {
      set gotVal $gotCount($idx,$id)
    }
    if {$expVal != $gotVal} {
      puts [format "MISMATCH core%02d id=%d expected=%d got=%d" $idx $id $expVal $gotVal]
      incr failures
    }
  }
}

puts [format "Observed %d flits, expected %d flits" $got_total $expected_total]
if {$failures != 0} {
  error [format "three_level_quadtree complex test failed with %d mismatches" $failures]
}

puts "three_level_quadtree complex test PASSED"
