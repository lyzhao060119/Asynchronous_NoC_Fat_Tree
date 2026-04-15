proc ns_from_ps {ps} {
  return [expr {$ps / 1000.0}]
}

proc bit_path {kind dir idx field} {
  return [format "/three_level_quadtree/io_%s_%s_%d_%s" $kind $dir $idx $field]
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
  set value [string trim [get_value -radix bin $path]]
  if {[regexp {[xXzZ]} $value]} {
    return -1
  }
  return [expr {$value eq "1" ? 1 : 0}]
}

proc get_uint {path} {
  set value [string trim [get_value -radix unsigned $path]]
  if {[regexp {[xXzZ]} $value]} {
    return -1
  }
  return [expr {$value + 0}]
}

proc set_bit {path value} {
  set_value -radix bin $path $value
}

proc set_hex {path value} {
  set_value -radix hex $path [format "%07X" $value]
}

proc mk_flit_rect {isHead isTail treeId xMin xMax yMin yMax id} {
  return [expr {
    (($isHead & 1) << 27) |
    (($isTail & 1) << 26) |
    (($yMax   & 63) << 20) |
    (($xMax   & 63) << 14) |
    (($yMin   & 63) << 8)  |
    (($xMin   & 63) << 2)  |
    ($id & 3)
  }]
}

set src_idx 0
set tree_id 0
set pkt_id 1
set x_min 6
set x_max 7
set y_min 6
set y_max 7

set packet [list \
  [mk_flit_rect 1 0 $tree_id $x_min $x_max $y_min $y_max $pkt_id] \
  [mk_flit_rect 0 0 $tree_id $x_min $x_max $y_min $y_max $pkt_id] \
  [mk_flit_rect 0 1 $tree_id $x_min $x_max $y_min $y_max $pkt_id] \
]

set expected_dsts {54 55 62 63}
array set expected_map {}
foreach idx $expected_dsts {
  set expected_map($idx) 1
}

array set out_flits {}
array set out_pkts {}
for {set idx 0} {$idx < 64} {incr idx} {
  set out_flits($idx) 0
  set out_pkts($idx) 0
}
set unexpected_top_flits 0

for {set idx 0} {$idx < 64} {incr idx} {
  set_bit [req_path core inputs $idx] 0
  set_hex [data_path core inputs $idx] 0
  set_bit [ack_path core outputs $idx] 0
}
for {set idx 0} {$idx < 8} {incr idx} {
  set_bit [req_path top input $idx] 0
  set_hex [data_path top input $idx] 0
  set_bit [ack_path top output $idx] 0
}

set_bit /three_level_quadtree/reset 1
set sim_ps 0
run 20 ns
set sim_ps 20000
set_bit /three_level_quadtree/reset 0
puts [format {\[%6.1f ns\] reset released} [ns_from_ps $sim_ps]]

set src_req 0
set src_wait 0
set flit_idx 0
set step_ps 2000
set timeout_ps 600000
set end_ps [expr {$sim_ps + $timeout_ps}]

while {$sim_ps < $end_ps} {
  if {$src_wait} {
    set ack [get_bit [ack_path core inputs $src_idx]]
    if {$ack == $src_req} {
      set src_wait 0
      incr flit_idx
    }
  }

  if {!$src_wait && $flit_idx < 3} {
    set src_req [expr {1 - $src_req}]
    set_hex [data_path core inputs $src_idx] [lindex $packet $flit_idx]
    set_bit [req_path core inputs $src_idx] $src_req
    set src_wait 1
  }

  run [format "%dps" $step_ps]
  incr sim_ps $step_ps

  for {set idx 0} {$idx < 64} {incr idx} {
    set reqSig [req_path core outputs $idx]
    set ackSig [ack_path core outputs $idx]
    set req [get_bit $reqSig]
    set ack [get_bit $ackSig]
    if {$req >= 0 && $ack >= 0 && $req != $ack} {
      set data [get_uint [data_path core outputs $idx]]
      set_bit $ackSig $req
      incr out_flits($idx)
      if {[expr {($data >> 26) & 1}] == 1} {
        incr out_pkts($idx)
      }
    }
  }

  for {set idx 0} {$idx < 8} {incr idx} {
    set reqSig [req_path top output $idx]
    set ackSig [ack_path top output $idx]
    set req [get_bit $reqSig]
    set ack [get_bit $ackSig]
    if {$req >= 0 && $ack >= 0 && $req != $ack} {
      set_bit $ackSig $req
      incr unexpected_top_flits
    }
  }

  set done 1
  foreach idx $expected_dsts {
    if {$out_pkts($idx) < 1} {
      set done 0
      break
    }
  }
  if {$done && $flit_idx >= 3 && !$src_wait} {
    break
  }
}

puts ""
puts "=== Multicast Rectangle Smoke Summary ==="
puts [format "Elapsed : %.1f ns" [ns_from_ps [expr {$sim_ps - 20000}]]]
puts [format "Src core: %d, rect=(x:%d..%d, y:%d..%d), pktId=%d" $src_idx $x_min $x_max $y_min $y_max $pkt_id]
puts [format "Unexpected top flits: %d" $unexpected_top_flits]

set failures 0
for {set idx 0} {$idx < 64} {incr idx} {
  set f $out_flits($idx)
  set p $out_pkts($idx)
  if {[info exists expected_map($idx)]} {
    puts [format "dst core %2d: flits=%d pkts=%d (expected flits=3 pkts=1)" $idx $f $p]
    if {$f != 3 || $p != 1} {
      incr failures
    }
  } elseif {$f != 0 || $p != 0} {
    puts [format "UNEXPECTED dst core %2d: flits=%d pkts=%d" $idx $f $p]
    incr failures
  }
}

if {$unexpected_top_flits != 0} {
  incr failures
}
if {$flit_idx < 3} {
  puts "Source did not finish sending all flits before timeout."
  incr failures
}

if {$failures != 0} {
  error [format "multicast_rect_smoke failed with %d error(s)" $failures]
}

puts "multicast_rect_smoke PASSED"
