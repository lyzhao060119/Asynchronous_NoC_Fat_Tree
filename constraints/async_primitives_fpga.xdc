# FPGA constraint template for synthesizable asynchronous primitives.
#
# Use with ASYNC_PRIMITIVES=fpga/synth builds. This file intentionally protects
# structural delay/mutex primitives, but it does not by itself prove asynchronous
# timing correctness. Fill the min/max delay numbers from post-route reports or
# board calibration for the target device and placement.

set async_delay_cells [get_cells -hier -quiet -filter {REF_NAME == LUT1 && NAME =~ *DelayUnit_delay*}]
if {[llength $async_delay_cells] > 0} {
  set_property DONT_TOUCH true $async_delay_cells
  set_property KEEP_HIERARCHY true [get_cells -hier -quiet -filter {NAME =~ *DelayElement*}]
}

set async_mutex_cells [get_cells -hier -quiet -filter {REF_NAME == LUT2 && (NAME =~ *q0_nand* || NAME =~ *q1_nand*)}]
if {[llength $async_mutex_cells] > 0} {
  set_property DONT_TOUCH true $async_mutex_cells
  set_property KEEP_HIERARCHY true [get_cells -hier -quiet -filter {NAME =~ *Mutex2*}]
}

# Cross-coupled mutex LUTs intentionally create combinational feedback.
set async_mutex_nets [get_nets -hier -quiet -filter {NAME =~ *Mutex2* || NAME =~ *q0* || NAME =~ *q1*}]
if {[llength $async_mutex_nets] > 0} {
  set_property ALLOW_COMBINATORIAL_LOOPS true $async_mutex_nets
}

# Optional placement template. Replace SLICE_X/Y locations after choosing a
# target FPGA and confirming congestion.
#
# set_property LOC SLICE_X0Y0 [get_cells -hier -filter {NAME =~ *DelayUnit_delay[0].D0*}]
# set_property LOC SLICE_X0Y1 [get_cells -hier -filter {NAME =~ *q0_nand*}]
# set_property LOC SLICE_X0Y1 [get_cells -hier -filter {NAME =~ *q1_nand*}]

# Optional timing template. Replace numbers with calibrated values.
#
# set async_min_delay_ns 0.050
# set async_max_delay_ns 2.000
# set_max_delay -datapath_only $async_max_delay_ns -through $async_delay_cells
# set_min_delay -datapath_only $async_min_delay_ns -through $async_delay_cells
