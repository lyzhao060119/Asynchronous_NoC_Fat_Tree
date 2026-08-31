create_clock -name CLK -period 10.0 [get_ports clock]
set_clock_latency 0.3 [get_clocks CLK]
set_clock_transition 0.1 [get_clocks CLK]
set_clock_uncertainty 0.1 [get_clocks CLK]
set_dont_touch_network [get_ports clock]
set_ideal_network [get_ports reset]
set del_pins [get_pins -hierarchical -quiet -of_objects [get_cells -hierarchical -quiet -filter {ref_name =~ DEL*}] -filter {name == I}]
if {[sizeof_collection $del_pins] > 0} { set_max_delay 6.5 -through $del_pins; set_min_delay 0.175 -through $del_pins }
