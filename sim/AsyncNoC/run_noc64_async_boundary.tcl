# Clockless NoC64 async-boundary smoke runner.
# Environment:
#   CMR_FAT_LANE_PROFILE=1248|1222 (default 1248)
#   NOC64_CASE_FILE=path to .case (default same-L1 smoke)
#   NOC64_GEN_DIR=generated_cmr/fat_tree_noc64_<profile>
# First-gun network case:
#   NOC64_CASE_FILE=sim/AsyncNoC/testbench/generated_cases_noc64/TAB_64/TAB-NET-UR-3f-r0p50.case
set repo_root [file normalize [file join [pwd] "../.."]]
set profile "1248"
if {[info exists ::env(CMR_FAT_LANE_PROFILE)]} { set profile $::env(CMR_FAT_LANE_PROFILE) }
if {$profile eq "FatLane1222" || $profile eq "1222" || $profile eq "1-2-2-2"} {
  set profile "1222"
  set top tb_noc64_async_boundary_1222
} else {
  set profile "1248"
  set top tb_noc64_async_boundary
}
set gen_dir [file join $repo_root "generated_cmr" "fat_tree_noc64_$profile"]
if {[info exists ::env(NOC64_GEN_DIR)]} { set gen_dir [file normalize $::env(NOC64_GEN_DIR)] }
set tb_dir [file join [pwd] "testbench"]
set async_dir [file join $repo_root "src/main/resources/ASYNC"]
set cmr_dir [file join $async_dir "CMR"]

if {![file exists [file join $gen_dir "NoC_64nodes.v"]]} {
  error "missing $gen_dir/NoC_64nodes.v; run NoC.CMR.CMRFatTreeNoC64Main with CMR_FAT_LANE_PROFILE=$profile"
}

if {[file exists work]} { file delete -force work }
if {[file exists xsim.dir]} { file delete -force xsim.dir }

set sources [list \
  [file join $gen_dir NoC_64nodes.v]]
foreach extra [glob -nocomplain [file join $gen_dir "*.v"]] {
  if {[file tail $extra] ne "NoC_64nodes.v"} {
    lappend sources $extra
  }
}
lappend sources \
  [file join $async_dir DelayElement_sim.v] \
  [file join $async_dir Mutex2_sim.v] \
  [file join $async_dir Mutex4.v] \
  [file join $async_dir MullerC2.v] \
  [file join $cmr_dir CMRMutexN.v] \
  [file join $cmr_dir CMRFlattenedTAC.v] \
  [file join $cmr_dir LanePhaseAdapter.v] \
  [file join [pwd] async_noc64_port_adapter.sv] \
  [file join $tb_dir tb_noc64_async_boundary.sv]

exec xvlog -sv -work work {*}$sources
exec xelab -timescale 1ns/1ps -debug typical work.$top -s noc64_async_boundary_sim

set case_file [file join [pwd] testbench small_cases noc64_00_to_10_3flit.case]
if {[info exists ::env(NOC64_CASE_FILE)]} { set case_file [file normalize $::env(NOC64_CASE_FILE)] }
file mkdir results/async_boundary_noc64/$profile
set cfg [open async_boundary_noc64_run.tcl w]
puts $cfg "run all"
puts $cfg "quit"
close $cfg
exec xsim noc64_async_boundary_sim -tclbatch async_boundary_noc64_run.tcl \
  -testplusarg CASE_FILE=[string map {\\ /} [file normalize $case_file]] \
  -testplusarg RESULT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile summary.csv]]] \
  -testplusarg EVENT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile events.csv]]] \
  -testplusarg LATENCY_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile latency.csv]]] \
  -testplusarg RX_CAPTURE_NS=0.05
