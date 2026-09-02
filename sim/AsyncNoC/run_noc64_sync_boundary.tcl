# Clocked NoC64 sync-boundary runner (DATE V3 SYNC_THIN64 / SYNC_PROP64).
# Environment:
#   CMR_SYNC64_PROFILE=thin|fat1222 (default thin)
#   NOC64_CASE_FILE=path to .case
#   NOC64_GEN_DIR=generated Verilog directory
#   NOC64_V3_METRICS_CSV=optional V3 drain/backlog CSV
#   CLOCK_PERIOD_NS=frozen Sync64 clock (default 1.0)
set repo_root [file normalize [file join [pwd] "../.."]]
set profile "thin"
if {[info exists ::env(CMR_SYNC64_PROFILE)]} { set profile $::env(CMR_SYNC64_PROFILE) }
set xvlog_define {}
if {$profile eq "fat1222" || $profile eq "1222" || $profile eq "1-2-2-2" || $profile eq "prop" || $profile eq "fat"} {
  set profile "fat1222"
  set top tb_noc64_sync_boundary
  set xvlog_define "+define+CMR_SYNC64_TOP2"
  set gen_dir [file join $repo_root "generated_sync_cmr" "fat_tree_noc64_1222"]
} else {
  set profile "thin"
  set top tb_noc64_sync_boundary
  set gen_dir [file join $repo_root "generated_sync_cmr" "fat_tree_noc64_thin"]
}
if {[info exists ::env(NOC64_GEN_DIR)]} { set gen_dir [file normalize $::env(NOC64_GEN_DIR)] }
set tb_dir [file join [pwd] "testbench"]
set adapter [file join [pwd] sync_noc64_port_adapter.sv]

set dut_v [file join $gen_dir "SyncNoC_64nodes.v"]
if {![file exists $dut_v]} {
  error "missing $dut_v; emit the Sync64 DUT before running this TB"
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
  $adapter \
  [file join $tb_dir tb_noc64_sync_boundary.sv]

if {$xvlog_define eq ""} {
  exec xvlog -sv -work work {*}$sources
} else {
  exec xvlog -sv -work work $xvlog_define {*}$sources
}
exec xelab -timescale 1ns/1ps -debug typical work.$top -s noc64_sync_boundary_sim

set case_file [file join [pwd] testbench small_cases noc64_00_to_10_3flit.case]
if {[info exists ::env(NOC64_CASE_FILE)]} { set case_file [file normalize $::env(NOC64_CASE_FILE)] }
set clock_ns 1.0
if {[info exists ::env(CLOCK_PERIOD_NS)]} { set clock_ns $::env(CLOCK_PERIOD_NS) }
file mkdir results/sync_boundary_noc64/$profile
set cfg [open sync_boundary_noc64_run.tcl w]
puts $cfg "run all"
puts $cfg "quit"
close $cfg
set plusargs [list \
  -testplusarg CASE_FILE=[string map {\\ /} [file normalize $case_file]] \
  -testplusarg RESULT_CSV=[string map {\\ /} [file normalize [file join [pwd] results sync_boundary_noc64 $profile summary.csv]]] \
  -testplusarg EVENT_CSV=[string map {\\ /} [file normalize [file join [pwd] results sync_boundary_noc64 $profile events.csv]]] \
  -testplusarg LATENCY_CSV=[string map {\\ /} [file normalize [file join [pwd] results sync_boundary_noc64 $profile latency.csv]]] \
  -testplusarg V3_METRICS_CSV=[string map {\\ /} [file normalize [file join [pwd] results sync_boundary_noc64 $profile v3_metrics.csv]]] \
  -testplusarg CLOCK_PERIOD_NS=$clock_ns]
if {[info exists ::env(NOC64_V3_METRICS_CSV)]} {
  lappend plusargs -testplusarg V3_METRICS_CSV=[string map {\\ /} [file normalize $::env(NOC64_V3_METRICS_CSV)]]
}
exec xsim noc64_sync_boundary_sim -tclbatch sync_boundary_noc64_run.tcl {*}$plusargs
