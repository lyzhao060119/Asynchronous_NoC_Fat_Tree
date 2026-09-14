# Async NoC_16nodes timing constraints for TSMC 28nm DC (Phase-1).
# Baseline global clock matches Synchronous_Router NoC16 (10 ns).
# Relative delay-chain constraints for DelayElement DEL* cells (DEL250).

set CLOCK_PERIOD_NS 10.0
set DEL_NS 0.25

create_clock -name CLK -period $CLOCK_PERIOD_NS [get_ports clock]
set_clock_latency 0.3 [get_clocks CLK]
set_clock_transition 0.1 [get_clocks CLK]
set_clock_uncertainty 0.1 [get_clocks CLK]
set_dont_touch_network [get_ports clock]

if {[sizeof_collection [get_ports -quiet reset]] > 0} {
  set_ideal_network [get_ports reset]
  set_dont_touch_network [get_ports reset]
}

set del_cells [get_cells -hierarchical -quiet -filter {ref_name =~ DEL*}]
if {[sizeof_collection $del_cells] > 0} {
  set max_through [expr {$DEL_NS * 20.0 * 1.3}]
  set min_through [expr {$DEL_NS * 1.0 * 0.7}]
  set del_pins [get_pins -quiet -of_objects $del_cells -filter {name == I}]
  if {[sizeof_collection $del_pins] == 0} {
    set del_pins [get_pins -quiet -of_objects $del_cells -filter {direction == in}]
  }
  if {[sizeof_collection $del_pins] > 0} {
    set_max_delay $max_through -through $del_pins
    set_min_delay $min_through -through $del_pins
    puts "INFO: set_max_delay $max_through / set_min_delay $min_through -through DEL* pins"
  } else {
    set_max_delay $max_through -through $del_cells
    set_min_delay $min_through -through $del_cells
    puts "WARN: fell back to cell -through for DEL* constraints"
  }
} else {
  puts "WARN: no DEL* cells for relative delay constraints"
}
