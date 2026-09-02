# DATE V3 256-node async key-case runner (PROP clustered or FM).
# Environment:
#   CMR_NOC256_KIND=prop|fm (default prop)
#   NOC256_CASE_FILE=path to V3 keycase .case
#   NOC256_GEN_DIR=generated Verilog directory
#   NOC256_V3_METRICS_CSV=optional V3 drain/backlog CSV
set repo_root [file normalize [file join [pwd] "../.."]]
set kind "prop"
if {[info exists ::env(CMR_NOC256_KIND)]} { set kind $::env(CMR_NOC256_KIND) }
set xvlog_define {}
if {$kind eq "fm" || $kind eq "FM256"} {
  set kind "fm"
  set xvlog_define "+define+CMR_NOC256_FM"
  set gen_dir [file join $repo_root "generated_cmr" "mesh_noc256_11"]
  set dut_name "CMRMeshNoC.v"
} else {
  set kind "prop"
  set gen_dir [file join $repo_root "generated_cmr" "clustered_noc_g2_m2"]
  set dut_name "NoC_256nodes.v"
}
if {[info exists ::env(NOC256_GEN_DIR)]} { set gen_dir [file normalize $::env(NOC256_GEN_DIR)] }
set tb_dir [file join [pwd] "testbench"]
set async_dir [file join $repo_root "src/main/resources/ASYNC"]
set cmr_dir [file join $async_dir "CMR"]
set dut_v [file join $gen_dir $dut_name]
if {![file exists $dut_v]} {
  error "missing $dut_v; emit CMRClusteredNoC(grid=2) or CMRMeshNoC(n=16) first"
}

if {[file exists work256]} { file delete -force work256 }
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
  [file join [pwd] async_noc256_port_adapter.sv] \
  [file join $tb_dir tb_noc256_async_keycase.sv]

if {$xvlog_define eq ""} {
  exec xvlog -sv -work work256 {*}$sources
} else {
  exec xvlog -sv -work work256 $xvlog_define {*}$sources
}
exec xelab -timescale 1ns/1ps -debug typical work256.tb_noc256_async_keycase -s noc256_async_keycase_sim

if {![info exists ::env(NOC256_CASE_FILE)]} {
  error "NOC256_CASE_FILE is required"
}
set case_file [file normalize $::env(NOC256_CASE_FILE)]
file mkdir results/async_keycase_noc256/$kind
set cfg [open async_keycase_noc256_run.tcl w]
puts $cfg "run all"
puts $cfg "quit"
close $cfg
set plusargs [list \
  -testplusarg CASE_FILE=[string map {\\ /} $case_file] \
  -testplusarg RESULT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_keycase_noc256 $kind summary.csv]]] \
  -testplusarg EVENT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_keycase_noc256 $kind events.csv]]] \
  -testplusarg LATENCY_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_keycase_noc256 $kind latency.csv]]] \
  -testplusarg V3_METRICS_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_keycase_noc256 $kind v3_metrics.csv]]] \
  -testplusarg RX_CAPTURE_NS=0.05]
if {[info exists ::env(NOC256_V3_METRICS_CSV)]} {
  lappend plusargs -testplusarg V3_METRICS_CSV=[string map {\\ /} [file normalize $::env(NOC256_V3_METRICS_CSV)]]
}
exec xsim noc256_async_keycase_sim -tclbatch async_keycase_noc256_run.tcl {*}$plusargs
