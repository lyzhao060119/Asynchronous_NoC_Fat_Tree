# Phase 3 datapath-first overlay for the frozen UltraRouter macro.
#
# This file intentionally contains *only* maximum-delay / electrical
# constraints on ordinary bundled-data cones.  It never constrains a request,
# Ack, DEL, Mutex, C-element, state latch, reset, or close-event path.  Those
# relative timing constraints are introduced only in the later RTC phase.
#
# Targets are derived by create_ultra_datapath_targets.py from the frozen
# Phase-1 common-event measurements.  The default scale is 0.95.

if {![info exists ::env(ULTRA_DATAPATH_TARGET_FILE)] ||
    ![file exists $::env(ULTRA_DATAPATH_TARGET_FILE)]} {
  puts "ULTRA_DATAPATH_FAIL missing target file"
  exit 2
}
source $::env(ULTRA_DATAPATH_TARGET_FILE)

proc ultra_dp_apply_max {id from_pat to_pat target_ns} {
  # A seeded DDC preserves the Chisel instance names but represents buses as
  # individual ``foo[bit]`` pins.  Query via ``full_name`` filters instead
  # of passing a bracket-containing bus expression to Tcl/glob parsing.
  set from [get_pins -hierarchical * -quiet -filter "full_name =~ $from_pat"]
  if {[sizeof_collection $from] == 0} {
    set from [get_ports * -quiet -filter "full_name =~ $from_pat"]
  }
  set to [get_pins -hierarchical * -quiet -filter "full_name =~ $to_pat"]
  if {[sizeof_collection $to] == 0} {
    set to [get_ports * -quiet -filter "full_name =~ $to_pat"]
  }
  if {[sizeof_collection $from] == 0 || [sizeof_collection $to] == 0} {
    puts "ULTRA_DATAPATH_NO_PATH id=$id from=$from_pat to=$to_pat"
    return
  }
  set_max_delay $target_ns -from $from -to $to
  incr ::ULTRA_DP_APPLIED
  puts "ULTRA_DATAPATH_CONSTRAINT id=$id target_ns=$target_ns from=$from_pat to=$to_pat"
}

set ::ULTRA_DP_APPLIED 0

# V1 data capture and route descriptor.  The V1 Q is the stable bundled-data
# launch point; constraining from it deliberately excludes the environment's
# input setup interval.
for {set i 0} {$i < 5} {incr i} {
  ultra_dp_apply_max "V1_CAPTURE_I$i" \
    "io_inputs_*_${i}_*_Data_flit*" \
    "*inputModules_${i}/mousetrap/data_latch/resettable_latch*/latch_cell/D" $::ULTRA_DP_V1_NS
  ultra_dp_apply_max "PRS_DESCRIPTOR_I$i" \
    "*inputModules_${i}/mousetrap/data_latch/resettable_latch*/latch_cell/Q" \
    "*inputModules_${i}/prs/io_RS_*" $::ULTRA_DP_PRS_NS
}

# Atomic descriptor cones end at protocol-controlled data latches.  These
# endpoints are not control endpoints; the later round-close constraints will
# compare their measured stability to the matching control boundary.
for {set i 0} {$i < 5} {incr i} {
  ultra_dp_apply_max "HEAD_CAPTURE_I$i" \
    "*inputModules_${i}/prs/io_RS_*" \
    "*admission/*capture*/mask_latch/resettable_latch*/latch_cell/D" $::ULTRA_DP_HEADCAP_NS
}
ultra_dp_apply_max "ATOMIC_BUILDER_DESCRIPTOR" \
  "*admission/*capture*/mask_latch/resettable_latch*/latch_cell/Q" \
  "*admission/*transaction*/**/D" $::ULTRA_DP_ATOMIC_NS

# OPM V2 mux/data capture across all legal local sources.  We constrain D,
# not the request latch or ReqOut, so this cannot compensate control timing.
for {set o 0} {$o < 5} {incr o} {
  for {set s 0} {$s < 4} {incr s} {
    ultra_dp_apply_max "OPM_V2_O${o}_S${s}" \
      "*outputModules_${o}/io_DataX_${s}_flit*" \
      "*outputModules_${o}/dataOutLatch/resettable_latch*/latch_cell/D" $::ULTRA_DP_OPM_NS
  }
}

# Use library DRC limits only.  No hand-picked cap/transition value is added.
set ULTRA_DP_CONSTRAINED_CELLS [get_cells -hierarchical -quiet \
  -filter {full_name =~ *mousetrap* || full_name =~ *prs* || full_name =~ *headCaptures* || full_name =~ *transactionController* || full_name =~ *dataOutLatch*}]
if {[sizeof_collection $ULTRA_DP_CONSTRAINED_CELLS] > 0} {
  report_constraint -all_violators > "$::env(ULTRA_DATAPATH_REPORT_DIR)/datapath_constraints_precompile.rpt"
}
puts "ULTRA_DATAPATH_CONSTRAINT_COUNT=$::ULTRA_DP_APPLIED"
if {$::ULTRA_DP_APPLIED == 0} {
  puts "ULTRA_DATAPATH_FAIL no_path_constraints_applied"
  exit 2
}
