# AsyncNoC16 AXI/BRAM FPGA constraints.
#
# Intended top levels:
#   - async_noc16_axi_bram_wrapper: clock port is s_axi_aclk
#   - NoC_16nodes: clock port is clock
#
# The clock period is 20 ns = 50 MHz. The async DelayElement/Mutex structures
# intentionally contain delay chains and local combinational feedback; protect
# them from optimization and allow the feedback loops explicitly.

set async_noc_clk_period_ns 20.000

set async_noc_axi_clk [get_ports -quiet s_axi_aclk]
if {[llength $async_noc_axi_clk] > 0} {
  create_clock -name s_axi_aclk -period $async_noc_clk_period_ns $async_noc_axi_clk
}

set async_noc_raw_clk [get_ports -quiet clock]
if {[llength $async_noc_raw_clk] > 0} {
  create_clock -name noc_clock -period $async_noc_clk_period_ns $async_noc_raw_clk
}

set async_noc_resets [get_ports -quiet {s_axi_aresetn reset}]
if {[llength $async_noc_resets] > 0} {
  set_false_path -from $async_noc_resets
}

# Preserve FPGA delay chains. DelayElement_FPGA.v maps DelayValue to a LUT1
# buffer chain whose physical delay must be measured after implementation.
set async_delay_lut_cells [get_cells -hier -quiet -filter {REF_NAME == LUT1 && NAME =~ *DelayUnit_delay*}]
if {[llength $async_delay_lut_cells] > 0} {
  set_property DONT_TOUCH true $async_delay_lut_cells
  set_property KEEP true $async_delay_lut_cells
}

set async_delay_hier_cells [get_cells -hier -quiet -filter {NAME =~ *DelayElement*}]
if {[llength $async_delay_hier_cells] > 0} {
  set_property DONT_TOUCH true $async_delay_hier_cells
  set_property KEEP_HIERARCHY true $async_delay_hier_cells
}

set async_delay_nets [get_nets -hier -quiet -filter {NAME =~ *DelayElement* || NAME =~ *DelayUnit_delay* || NAME =~ *d_tmp*}]
if {[llength $async_delay_nets] > 0} {
  set_property DONT_TOUCH true $async_delay_nets
  set_property KEEP true $async_delay_nets
  set_property ALLOW_COMBINATORIAL_LOOPS true $async_delay_nets
}

# Preserve and allow the intentional cross-coupled mutex loop.
set async_mutex_lut_cells [get_cells -hier -quiet -filter {REF_NAME == LUT2 && (NAME =~ *q0_nand* || NAME =~ *q1_nand*)}]
if {[llength $async_mutex_lut_cells] > 0} {
  set_property DONT_TOUCH true $async_mutex_lut_cells
  set_property KEEP true $async_mutex_lut_cells
}

set async_mutex_hier_cells [get_cells -hier -quiet -filter {NAME =~ *Mutex2*}]
if {[llength $async_mutex_hier_cells] > 0} {
  set_property DONT_TOUCH true $async_mutex_hier_cells
  set_property KEEP_HIERARCHY true $async_mutex_hier_cells
}

set async_mutex_nets [get_nets -hier -quiet -filter {NAME =~ *Mutex2* || NAME =~ *q0* || NAME =~ *q1* || NAME =~ *gnt0* || NAME =~ *gnt1*}]
if {[llength $async_mutex_nets] > 0} {
  set_property DONT_TOUCH true $async_mutex_nets
  set_property KEEP true $async_mutex_nets
  set_property ALLOW_COMBINATORIAL_LOOPS true $async_mutex_nets
}

# ACG and handshake controllers may form local self-timed feedback around delay
# elements. Mark candidate feedback nets as legal combinational loops so Vivado
# does not fail DRC on intentional async control paths.
set async_acg_feedback_nets [get_nets -hier -quiet -filter {NAME =~ *ACG* || NAME =~ *fire* || NAME =~ *fire_o* || NAME =~ *launchPulse* || NAME =~ *completePulse* || NAME =~ *stateEvent*}]
if {[llength $async_acg_feedback_nets] > 0} {
  set_property ALLOW_COMBINATORIAL_LOOPS true $async_acg_feedback_nets
}

# Keep async primitive timing visible in reports, but do not use these numbers
# as final design claims until calibrated on the target device.
# Example optional bounds after calibration:
#
# set_max_delay -datapath_only 2.000 -through $async_delay_lut_cells
# set_min_delay -datapath_only 0.050 -through $async_delay_lut_cells
