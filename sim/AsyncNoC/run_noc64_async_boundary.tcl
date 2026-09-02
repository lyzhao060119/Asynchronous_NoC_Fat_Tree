# Clockless NoC64 async-boundary runner (DATE V3 async designs).
# Environment:
#   CMR_FAT_LANE_PROFILE=thin|1222|1248|mesh (default 1222)
#   NOC64_CASE_FILE=path to .case
#   NOC64_GEN_DIR=generated Verilog directory
#   NOC64_V3_METRICS_CSV=optional V3 drain/backlog CSV
set repo_root [file normalize [file join [pwd] "../.."]]
set profile "1222"
if {[info exists ::env(CMR_FAT_LANE_PROFILE)]} { set profile $::env(CMR_FAT_LANE_PROFILE) }
set xvlog_define {}
set extra_sv {}
if {$profile eq "FatLane1222" || $profile eq "1222" || $profile eq "1-2-2-2" || $profile eq "prop"} {
  set profile "1222"
  set top tb_noc64_async_boundary_1222
  set gen_dir [file join $repo_root "generated_cmr" "fat_tree_noc64_1222"]
  set adapter [file join [pwd] async_noc64_port_adapter.sv]
} elseif {$profile eq "thin" || $profile eq "111" || $profile eq "1-1-1-1"} {
  set profile "thin"
  set top tb_noc64_async_boundary_thin
  set gen_dir [file join $repo_root "generated_cmr" "fat_tree_noc64_thin"]
  set adapter [file join [pwd] async_noc64_port_adapter.sv]
} elseif {$profile eq "mesh" || $profile eq "fm64"} {
  set profile "mesh"
  set top tb_noc64_async_boundary_mesh
  set xvlog_define "+define+CMR_NOC64_MESH"
  set gen_dir [file join $repo_root "generated_cmr" "mesh_noc64_11"]
  set adapter [file join [pwd] async_noc64_mesh_port_adapter.sv]
} else {
  set profile "1248"
  set top tb_noc64_async_boundary
  set gen_dir [file join $repo_root "generated_cmr" "fat_tree_noc64_1248"]
  set adapter [file join [pwd] async_noc64_port_adapter.sv]
}
if {[info exists ::env(NOC64_GEN_DIR)]} { set gen_dir [file normalize $::env(NOC64_GEN_DIR)] }
set tb_dir [file join [pwd] "testbench"]
set async_dir [file join $repo_root "src/main/resources/ASYNC"]
set cmr_dir [file join $async_dir "CMR"]

set dut_v [file join $gen_dir "NoC_64nodes.v"]
if {$profile eq "mesh"} { set dut_v [file join $gen_dir "CMRMeshNoC.v"] }
if {![file exists $dut_v]} {
  error "missing $dut_v; emit the async DUT before running this TB"
}

if {[file exists work]} { file delete -force work }
if {[file exists xsim.dir]} { file delete -force xsim.dir }

set sources [list $dut_v]
foreach extra [glob -nocomplain [file join $gen_dir "*.v"]] {
  if {[file normalize $extra] ne [file normalize $dut_v]} {
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
  $adapter \
  [file join $tb_dir tb_noc64_async_boundary.sv]

if {$xvlog_define eq ""} {
  exec xvlog -sv -work work {*}$sources
} else {
  exec xvlog -sv -work work $xvlog_define {*}$sources
}
exec xelab -timescale 1ns/1ps -debug typical work.$top -s noc64_async_boundary_sim

set case_file [file join [pwd] testbench small_cases noc64_00_to_10_3flit.case]
if {[info exists ::env(NOC64_CASE_FILE)]} { set case_file [file normalize $::env(NOC64_CASE_FILE)] }
file mkdir results/async_boundary_noc64/$profile
set cfg [open async_boundary_noc64_run.tcl w]
puts $cfg "run all"
puts $cfg "quit"
close $cfg
set plusargs [list \
  -testplusarg CASE_FILE=[string map {\\ /} [file normalize $case_file]] \
  -testplusarg RESULT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile summary.csv]]] \
  -testplusarg EVENT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile events.csv]]] \
  -testplusarg LATENCY_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile latency.csv]]] \
  -testplusarg V3_METRICS_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary_noc64 $profile v3_metrics.csv]]] \
  -testplusarg RX_CAPTURE_NS=0.05]
if {[info exists ::env(NOC64_V3_METRICS_CSV)]} {
  lappend plusargs -testplusarg V3_METRICS_CSV=[string map {\\ /} [file normalize $::env(NOC64_V3_METRICS_CSV)]]
}
exec xsim noc64_async_boundary_sim -tclbatch async_boundary_noc64_run.tcl {*}$plusargs
