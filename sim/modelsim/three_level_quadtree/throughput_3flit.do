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

proc build_packet {destX destY id} {
  return [list \
    [mk_flit 1 0 $destX $destY 0 0 $id] \
    [mk_flit 0 0 $destX $destY 0 0 $id] \
    [mk_flit 0 1 $destX $destY 0 0 $id] \
  ]
}

proc init_flow {name srcIdx dstIdx destX destY id} {
  global flow_src flow_dst flow_id flow_req flow_wait flow_flit_idx flow_sent_pkts flow_inj_flits flow_pkt flow_meas_pkts flow_meas_flits
  set flow_src($name) $srcIdx
  set flow_dst($name) $dstIdx
  set flow_id($name)  $id
  set flow_req($name) 0
  set flow_wait($name) 0
  set flow_flit_idx($name) 0
  set flow_sent_pkts($name) 0
  set flow_inj_flits($name) 0
  set flow_meas_pkts($name) 0
  set flow_meas_flits($name) 0
  set flow_pkt($name) [build_packet $destX $destY $id]
}

proc drive_sources {} {
  global flow_names flow_src flow_req flow_wait flow_flit_idx flow_pkt flow_sent_pkts flow_inj_flits flow_meas_pkts flow_meas_flits
  global sim_ps measure_start_ps

  foreach name $flow_names {
    set reqSig  [req_path core inputs $flow_src($name)]
    set ackSig  [ack_path core inputs $flow_src($name)]
    set dataSig [data_path core inputs $flow_src($name)]

    if {$flow_wait($name)} {
      set ack [get_bit $ackSig]
      if {$ack == $flow_req($name)} {
        set flow_wait($name) 0
        set doneFlit [expr {$flow_flit_idx($name) + 1}]
        set flow_flit_idx($name) $doneFlit
        incr flow_inj_flits($name)
        if {$sim_ps >= $measure_start_ps} {
          incr flow_meas_flits($name)
        }
        if {$doneFlit == 3} {
          set flow_flit_idx($name) 0
          incr flow_sent_pkts($name)
          if {$sim_ps >= $measure_start_ps} {
            incr flow_meas_pkts($name)
          }
        }
      }
    }

    if {!$flow_wait($name)} {
      set idx $flow_flit_idx($name)
      set flit [lindex $flow_pkt($name) $idx]
      set flow_req($name) [expr {1 - $flow_req($name)}]
      force -deposit $dataSig [format "16#%06X" $flit]
      force -deposit $reqSig $flow_req($name)
      set flow_wait($name) 1
    }
  }
}

proc handle_outputs {} {
  global flow_names flow_dst flow_id sim_ps measure_start_ps
  global recv_flits recv_pkts recv_flows_pkts recv_flows_flits unexpected_top_flits

  foreach name $flow_names {
    set idx $flow_dst($name)
    set reqSig  [req_path core outputs $idx]
    set ackSig  [ack_path core outputs $idx]
    set dataSig [data_path core outputs $idx]

    set req [get_bit $reqSig]
    set ack [get_bit $ackSig]
    if {$req >= 0 && $ack >= 0 && $req != $ack} {
      set data [get_uint $dataSig]
      force -deposit $ackSig $req

      if {$sim_ps >= $measure_start_ps} {
        incr recv_flits
        incr recv_flows_flits($name)
        if {[expr {($data >> 20) & 1}] == 1} {
          incr recv_pkts
          incr recv_flows_pkts($name)
        }
      }
    }
  }

  for {set idx 0} {$idx < 8} {incr idx} {
    set req [get_bit [req_path top output $idx]]
    set ack [get_bit [ack_path top output $idx]]
    if {$req >= 0 && $ack >= 0 && $req != $ack} {
      force -deposit [ack_path top output $idx] $req
      if {$sim_ps >= $measure_start_ps} {
        incr unexpected_top_flits
      }
    }
  }
}

set flow_names {f0 f1 f2 f3}
array set flow_src {}
array set flow_dst {}
array set flow_id {}
array set flow_req {}
array set flow_wait {}
array set flow_flit_idx {}
array set flow_sent_pkts {}
array set flow_inj_flits {}
array set flow_pkt {}
array set flow_meas_pkts {}
array set flow_meas_flits {}
array set recv_flows_pkts {}
array set recv_flows_flits {}

init_flow f0 0  63 7 7 0
init_flow f1 7  56 0 7 1
init_flow f2 56 7  7 0 2
init_flow f3 63 0  0 0 3

set recv_flits 0
set recv_pkts 0
set unexpected_top_flits 0

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

set warmup_ps 100000
set measure_ps 500000
set measure_start_ps [expr {$sim_ps + $warmup_ps}]
set measure_end_ps   [expr {$measure_start_ps + $measure_ps}]
set step_ps 2000

while {$sim_ps < $measure_end_ps} {
  drive_sources
  run [format "%d ps" $step_ps]
  incr sim_ps $step_ps
  handle_outputs
}

set measure_ns [ns $measure_ps]
set flits_per_ns   [expr {$recv_flits / $measure_ns}]
set pkts_per_ns    [expr {$recv_pkts  / $measure_ns}]
set bits_per_ns    [expr {$recv_flits * 22.0 / $measure_ns}]
set gbps_equiv     $bits_per_ns

puts ""
puts "=== Throughput Summary ==="
puts [format "Window        : %.1f ns" $measure_ns]
puts [format "Recv flits    : %d" $recv_flits]
puts [format "Recv packets  : %d" $recv_pkts]
puts [format "Flits / ns    : %.6f" $flits_per_ns]
puts [format "Packets / ns  : %.6f" $pkts_per_ns]
puts [format "Bits / ns     : %.6f" $bits_per_ns]
puts [format "Gbps equiv.   : %.6f" $gbps_equiv]
puts [format "Unexpected top flits  : %d" $unexpected_top_flits]

foreach name $flow_names {
  puts [format "Flow %-2s src=%2d dst=%2d injected=%5d pkt received=%5d pkt received_flit=%5d" \
    $name $flow_src($name) $flow_dst($name) $flow_meas_pkts($name) $recv_flows_pkts($name) $recv_flows_flits($name)]
}

if {$unexpected_top_flits != 0} {
  error "throughput benchmark observed unexpected traffic"
}
