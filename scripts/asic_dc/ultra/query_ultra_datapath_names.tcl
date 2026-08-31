# Read-only seeded-DDC query used to bind Phase-3 SDC endpoints to the
# preserved gate-level hierarchy.  It deliberately performs no optimization
# and writes only a text inventory.
set ROOT [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set DDC [expr {[info exists ::env(ULTRA_QUERY_DDC)] ? $::env(ULTRA_QUERY_DDC) : "$ROOT/outputs/20260813_mem0_hc0_router/UltraRouter.ddc"}]
set OUT [expr {[info exists ::env(ULTRA_QUERY_OUT)] ? $::env(ULTRA_QUERY_OUT) : "$ROOT/reports/dc/phase3_name_query.txt"}]
file mkdir [file dirname $OUT]
define_design_lib WORK -path "$ROOT/work/dc_query_[pid]"
set_app_var search_path [list "/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db"]
set_app_var link_library "* /process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db"
read_ddc $DDC
current_design UltraRouter
link
set direct_opm_d [get_pins -hierarchical -quiet -regexp {^outputModules_0/dataOutLatch/resettable_latch\[[0-9]+\]\.latch_cell/D$}]
puts "DIRECT_OPM0_D=[sizeof_collection $direct_opm_d]"
redirect $OUT {
  puts "PIN_COUNT=[sizeof_collection [get_pins -hierarchical *]]"
  set self_match 0
  foreach_in_collection p [get_pins -hierarchical *] {
    set n [get_object_name $p]
    if {[string match "*outputModules_0/dataOutLatch/resettable_latch*/latch_cell/D" $n]} {
      incr self_match
    }
  }
  puts "SELF_MATCH_OPM0_D=$self_match"
  puts "PORTS"
  foreach_in_collection p [get_ports *] { puts [get_object_name $p] }
  puts "PINS_V1"
  foreach_in_collection p [get_pins -hierarchical *] {
    set n [get_object_name $p]
    if {[string match "*mousetrap/data_latch*" $n]} { puts $n }
  }
  puts "PINS_PRS"
  foreach_in_collection p [get_pins -hierarchical *] {
    set n [get_object_name $p]
    if {[string match "*inputModules_0/prs*" $n]} { puts $n }
  }
  puts "PINS_OPM"
  foreach_in_collection p [get_pins -hierarchical *] {
    set n [get_object_name $p]
    if {[string match "*outputModules_*/dataOutLatch*" $n] ||
        [string match "*outputModules_*/requestLatches_*" $n] ||
        [string match "*outputModules_*/io_DataX_*" $n] ||
        [string match "*outputModules_*/requestOutLatch*" $n] ||
        [string match "*outputModules_*/v2RequestMargin*" $n]} { puts $n }
  }
  puts "PINS_CAPTURE"
  foreach_in_collection p [get_pins -hierarchical *] {
    set n [get_object_name $p]
    if {[string match "*capture*" $n]} { puts $n }
  }
  puts "CELLS_OPM"
  foreach_in_collection c [get_cells -hierarchical *] {
    set n [get_object_name $c]
    if {[string match "*outputModules_*" $n] &&
        ([string match "*dataOutLatch*" $n] ||
         [string match "*requestOutLatch*" $n] ||
         [string match "*v2RequestMargin*" $n])} {
      puts "$n,[get_attribute $c ref_name]"
    }
  }
}
puts "ULTRA_QUERY_DONE $OUT"
exit
