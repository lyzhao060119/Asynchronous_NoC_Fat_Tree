# Run the routed NoC64 FPGA timing netlist against the AXI smoke test.
#
# Required environment:
#   FPGA_NOC64_TIMESIM : write_verilog -mode timesim result
#   FPGA_NOC64_SDF     : corresponding MAXIMUM SDF result
#
# The default build paths match scripts/fpga/run_noc64_prop64_vivado.tcl.
set repo_root [file normalize [file join [file dirname [info script]] "../.."]]
set build_dir [file join $repo_root build fpga_noc64_prop64]
if {[info exists ::env(FPGA_NOC64_TIMESIM)]} {
  set netlist $::env(FPGA_NOC64_TIMESIM)
} else {
  set netlist [file join $build_dir fpga_noc64_prop64_timesim.v]
}
if {[info exists ::env(FPGA_NOC64_SDF)]} {
  set sdf $::env(FPGA_NOC64_SDF)
} else {
  set sdf [file join $build_dir fpga_noc64_prop64_max.sdf]
}
if {![file isfile $netlist]} { error "missing timing netlist: $netlist" }
if {![file isfile $sdf]} { error "missing maximum SDF: $sdf" }

set work_dir [file join $build_dir xsim_postroute]
file delete -force $work_dir
file mkdir $work_dir
set tb [file join $repo_root sim AsyncNoC testbench tb_fpga_noc64_axi_smoke.sv]

exec xvlog -sv -work $work_dir $netlist $tb
# The SDF instance path is the wrapper DUT inside the smoke testbench.
exec xelab -debug typical -L unisims_ver -sdfmax tb_fpga_noc64_axi_smoke/dut=$sdf \
  -timescale 1ns/1ps $work_dir.tb_fpga_noc64_axi_smoke -s fpga_noc64_postroute_sim
set run_tcl [file join $work_dir run.tcl]
set fd [open $run_tcl w]
puts $fd "run all"
puts $fd "quit"
close $fd
exec xsim fpga_noc64_postroute_sim -tclbatch $run_tcl
