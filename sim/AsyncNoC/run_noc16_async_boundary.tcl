# Clockless NoC16 async-boundary smoke runner.
# Environment: NOC16_ENDPOINT_MODE=behavioral|structural (default behavioral)
set repo_root [file normalize [file join [pwd] "../.."]]
set gen_dir [file join $repo_root "generated_ultra"]
set tb_dir [file join [pwd] "testbench"]
set async_dir [file join $repo_root "src/main/resources/ASYNC"]
set mode "behavioral"
if {[info exists ::env(NOC16_ENDPOINT_MODE)]} { set mode [string tolower $::env(NOC16_ENDPOINT_MODE)] }
if {$mode ni {behavioral structural}} { error "NOC16_ENDPOINT_MODE must be behavioral or structural" }
set endpoint_ack_delay_ps 50
if {[info exists ::env(ULTRA_ENDPOINT_ACK_DELAY_PS)]} { set endpoint_ack_delay_ps $::env(ULTRA_ENDPOINT_ACK_DELAY_PS) }
if {$endpoint_ack_delay_ps ni {50 75 100 150 250}} { error "ULTRA_ENDPOINT_ACK_DELAY_PS must be 50,75,100,150,250" }

if {[file exists work]} { file delete -force work }
if {[file exists xsim.dir]} { file delete -force xsim.dir }

set sources [list \
  [file join $gen_dir NoC_16nodes.v] \
  [file join $async_dir DelayElement_sim.v] \
  [file join $async_dir AsyncEndpointAckDelay.v] \
  [file join $async_dir DLatchBank.v] \
  [file join $async_dir MousetrapStage.v] \
  [file join $async_dir MullerC2.v] \
  [file join $async_dir MullerC3.v] \
  [file join $async_dir Mutex2.v] \
  [file join $async_dir TAC2.v] \
  [file join $async_dir Mutex3Grant.v] \
  [file join $async_dir Mutex5Anchor.v] \
  [file join $async_dir UltraHeadCaptureCell.v] \
  [file join $async_dir AsyncRoundMembershipCell.v] \
  [file join $async_dir AsyncArbiterTransactionController.v] \
  [file join $async_dir V2CloseEvent.v] \
  [file join [pwd] async_noc16_port_adapter.sv] \
  [file join [pwd] async_endpoint_bank20.sv] \
  [file join [pwd] async_noc16_boundary_dut.sv] \
  [file join $tb_dir tb_noc16_async_boundary.sv]]
set endpoint_ack_define [format "ASYNC_ENDPOINT_ACK_DELAY_%03d" $endpoint_ack_delay_ps]
exec xvlog -sv -d $endpoint_ack_define -work work {*}$sources

if {$mode eq "structural"} {
  set top tb_noc16_async_boundary_structural
} else {
  set top tb_noc16_async_boundary
}
exec xelab -timescale 1ns/1ps -debug typical work.$top -s noc16_async_boundary_sim

set case_file [file join [pwd] testbench small_cases noc16_00_to_33_3flit_smoke.case]
if {[info exists ::env(NOC16_CASE_FILE)]} { set case_file [file normalize $::env(NOC16_CASE_FILE)] }
file mkdir results/async_boundary/$mode
set cfg [open async_boundary_run.tcl w]
puts $cfg "run all"
puts $cfg "quit"
close $cfg
exec xsim noc16_async_boundary_sim -tclbatch async_boundary_run.tcl \
  -testplusarg CASE_FILE=[string map {\\ /} [file normalize $case_file]] \
  -testplusarg RESULT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary $mode summary.csv]]] \
  -testplusarg EVENT_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary $mode events.csv]]] \
  -testplusarg LATENCY_CSV=[string map {\\ /} [file normalize [file join [pwd] results async_boundary $mode latency.csv]]]
