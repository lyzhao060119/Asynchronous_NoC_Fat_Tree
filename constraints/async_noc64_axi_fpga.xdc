# FPGA PROP64 AXI wrapper constraints for xc7z020clg400-1.
#
# Board pins and the Zynq processing-system configuration intentionally do not
# live here.  The Block Design owns those constraints; this file constrains the
# reusable PL IP only.

create_clock -name s_axi_aclk -period 20.000 [get_ports -quiet s_axi_aclk]
set_false_path -from [get_ports -quiet s_axi_aresetn]

# Keep physical asynchronous delay elements intact.  DelayUnitPs is an ASIC
# selector and has no FPGA-time meaning: actual LUT-chain delays are reported
# after route and subsequently calibrated.
set fpga_delay_luts [get_cells -hier -quiet -filter {REF_NAME == LUT1 && NAME =~ *DelayUnit_delay*}]
set_property DONT_TOUCH true $fpga_delay_luts
set_property KEEP true $fpga_delay_luts
set_property KEEP_HIERARCHY true [get_cells -hier -quiet -filter {NAME =~ *DelayElement*}]

set fpga_mutex_luts [get_cells -hier -quiet -filter {REF_NAME == LUT2 && (NAME =~ *q0_nand* || NAME =~ *q1_nand*)}]
set_property DONT_TOUCH true $fpga_mutex_luts
set_property KEEP true $fpga_mutex_luts
set_property KEEP_HIERARCHY true [get_cells -hier -quiet -filter {NAME =~ *Mutex2*}]

# The NoC uses intentional self-timed feedback.  Limit the exception to the
# known asynchronous-control hierarchy; ordinary synchronous AXI paths remain
# timed by s_axi_aclk.
set fpga_async_feedback [get_nets -hier -quiet -filter {
  NAME =~ *DelayElement* || NAME =~ *DelayUnit_delay* || NAME =~ *Mutex2* ||
  NAME =~ *q0* || NAME =~ *q1* || NAME =~ *fire* || NAME =~ *launchPulse* ||
  NAME =~ *completePulse* || NAME =~ *stateEvent*
}]
set_property ALLOW_COMBINATORIAL_LOOPS true $fpga_async_feedback
