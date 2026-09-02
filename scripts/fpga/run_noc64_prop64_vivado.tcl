# Batch FPGA synthesis/implementation for the standalone PROP64 AXI IP.
#
# Usage:
#   vivado -mode batch -source scripts/fpga/run_noc64_prop64_vivado.tcl
#
# This flow builds only the reusable PL IP.  It intentionally does not create
# a Zynq block design, assign board pins, or program a board.
set repo_root [file normalize [file join [file dirname [info script]] "../.."]]
set build_dir [file join $repo_root build fpga_noc64_prop64]
set gen_dir [file join $repo_root generated_cmr fat_tree_noc64_1222]
set async_dir [file join $repo_root src main resources ASYNC]
file mkdir $build_dir

set part xc7z020clg400-1
set sources [list \
  [file join $gen_dir NoC_64nodes.v] \
  [file join $async_dir DelayElement_FPGA.v] \
  [file join $async_dir Mutex2_fpga.v] \
  [file join $async_dir Mutex4.v] \
  [file join $async_dir MullerC2.v] \
  [file join $async_dir DLatchBank.v] \
  [file join $async_dir V2CloseEvent.v] \
  [file join $async_dir MousetrapStage.v] \
  [file join $async_dir MullerC3.v] \
  [file join $async_dir MrGo.v] \
  [file join $repo_root sim AsyncNoC async_noc64_port_adapter.sv] \
  [file join $repo_root sim AsyncNoC fpga_noc64_axi_wrapper.sv]]
set sources [concat $sources [glob -nocomplain [file join $async_dir CMR *.v]]]
foreach source $sources {
  if {![file isfile $source]} { error "missing RTL source: $source" }
  read_verilog -sv $source
}
read_xdc [file join $repo_root constraints async_noc64_axi_fpga.xdc]

synth_design -top fpga_noc64_axi_wrapper -part $part -flatten_hierarchy none
report_utilization -file [file join $build_dir utilization_synth.rpt]
report_utilization -hierarchical -file [file join $build_dir utilization_synth_hier.rpt]
report_drc -file [file join $build_dir drc_synth.rpt]
write_checkpoint -force [file join $build_dir post_synth.dcp]

opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $build_dir utilization_impl.rpt]
report_utilization -hierarchical -file [file join $build_dir utilization_impl_hier.rpt]
report_timing_summary -delay_type min_max -max_paths 100 -file [file join $build_dir timing_impl.rpt]
report_route_status -file [file join $build_dir route_status.rpt]
report_drc -file [file join $build_dir drc_impl.rpt]
set async_report_dir [file join $build_dir async_timing]
source [file join $repo_root scripts async report_async_primitive_timing.tcl]
write_checkpoint -force [file join $build_dir post_route.dcp]
write_verilog -force -mode timesim -file [file join $build_dir fpga_noc64_prop64_timesim.v]
write_sdf -force -mode timesim -file [file join $build_dir fpga_noc64_prop64_max.sdf]
puts "FPGA_NOC64_PROP64_IMPLEMENTATION_PASS $build_dir"
