# Phase-3 OPM-only datapath overlay.
#
# This is intentionally narrower than the historical broad overlay: its
# endpoints were verified against the mapped MEM0_HC0 DDC inventory, and it
# binds exactly five OPMs × four local data sources.  It constrains only the
# bundled-data cone from an OPM DataX port through the existing Mux to the V2
# data latch D pins.  Request/Ack/MG/L5/close-event/reset are excluded.

if {![info exists ::env(ULTRA_DATAPATH_TARGET_FILE)] ||
    ![file exists $::env(ULTRA_DATAPATH_TARGET_FILE)]} {
  puts "ULTRA_DATAPATH_FAIL missing target file"
  exit 2
}
source $::env(ULTRA_DATAPATH_TARGET_FILE)
if {![info exists ::ULTRA_DP_OPM_NS] || $::ULTRA_DP_OPM_NS <= 0.0} {
  puts "ULTRA_DATAPATH_FAIL invalid OPM target"
  exit 2
}

set ::ULTRA_DP_APPLIED 0
set ::ULTRA_DP_ENDPOINTS 0
set dp_report "$::env(ULTRA_DATAPATH_REPORT_DIR)/opm_datapath_constraints_precompile.rpt"
set dp_fd [open $dp_report w]
puts $dp_fd "id,target_ns,from_count,to_count"

for {set o 0} {$o < 5} {incr o} {
  # Obtain pins from cell objects instead of reparsing mapped bus names.
  # The latter contain ``[n]`` and were interpreted as glob character
  # classes by DC, producing a false empty collection in the initial r1.
  set opm [get_cells -hierarchical -quiet -filter "full_name =~ *outputModules_${o}"]
  if {[sizeof_collection $opm] != 1} {
    puts "ULTRA_DATAPATH_FAIL OPM_HIERARCHY output=$o actual=[sizeof_collection $opm] expected=1"
    close $dp_fd
    exit 2
  }
  set data_latches [get_cells -hierarchical -quiet -filter "full_name =~ *outputModules_${o}/dataOutLatch/resettable_latch*"]
  set to [get_pins -quiet -of_objects $data_latches -filter {name == D}]
  if {[sizeof_collection $to] != 28} {
    puts "ULTRA_DATAPATH_FAIL OPM_D_ENDPOINTS output=$o actual=[sizeof_collection $to] expected=28"
    close $dp_fd
    exit 2
  }
  for {set s 0} {$s < 4} {incr s} {
    set from [get_pins -quiet -of_objects $opm -filter "name =~ io_DataX_${s}_flit*"]
    if {[sizeof_collection $from] != 28} {
      puts "ULTRA_DATAPATH_FAIL OPM_DATA_SOURCE output=$o source=$s actual=[sizeof_collection $from] expected=28"
      close $dp_fd
      exit 2
    }
    set id "OPM_V2_O${o}_S${s}"
    set_max_delay $::ULTRA_DP_OPM_NS -from $from -to $to
    puts $dp_fd "$id,$::ULTRA_DP_OPM_NS,[sizeof_collection $from],[sizeof_collection $to]"
    incr ::ULTRA_DP_APPLIED
    incr ::ULTRA_DP_ENDPOINTS [sizeof_collection $to]
  }
}
close $dp_fd
puts "ULTRA_DATAPATH_CONSTRAINT_COUNT=$::ULTRA_DP_APPLIED OPM_ENDPOINTS=$::ULTRA_DP_ENDPOINTS"
if {$::ULTRA_DP_APPLIED != 20} {
  puts "ULTRA_DATAPATH_FAIL unexpected_constraint_count=$::ULTRA_DP_APPLIED"
  exit 2
}
