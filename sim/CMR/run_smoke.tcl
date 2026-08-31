# Local CMR OPM/RCU/Fig.7/Fig.8/Router smoke suite. Run from sim/CMR with:
#   vivado -mode batch -source run_smoke.tcl

set repo_root [file normalize [file join [pwd] "../.."]]
set opm_dir [file join $repo_root "generated_cmr" "opm"]
set rcu_dir [file join $repo_root "generated_cmr" "rcu_l1"]
set write_dir [file join $repo_root "generated_cmr" "write_interface"]
set read_dir [file join $repo_root "generated_cmr" "read_interface_0"]
set buffer_dir [file join $repo_root "generated_cmr" "buffer"]
set router_dir [file join $repo_root "generated_cmr" "router_l1"]
set tb_dir [file join [pwd] "testbench"]

if {![file exists [file join $opm_dir "OPM.v"]]} {
  error "missing generated_cmr/opm/OPM.v; run Router_Architecture.CMR.OPMMain"
}
if {![file exists [file join $rcu_dir "RCU.v"]]} {
  error "missing generated_cmr/rcu_l1/RCU.v; run Router_Architecture.CMR.RCUMain 1"
}
if {![file exists [file join $write_dir "WriteInterfaceControl.v"]]} {
  error "missing generated_cmr/write_interface/WriteInterfaceControl.v; run Router_Architecture.CMR.WriteInterfaceControlMain"
}
if {![file exists [file join $read_dir "ReadInterfaceControl.v"]]} {
  error "missing generated_cmr/read_interface_0/ReadInterfaceControl.v; run Router_Architecture.CMR.ReadInterfaceControlMain 0"
}
if {![file exists [file join $buffer_dir "CMRBuffer.v"]]} {
  error "missing generated_cmr/buffer/CMRBuffer.v; run Router_Architecture.CMR.CMRBufferMain"
}
if {![file exists [file join $router_dir "CMRRouter.v"]]} {
  error "missing generated_cmr/router_l1/CMRRouter.v; run Router_Architecture.CMR.CMRRouterMain 1"
}

proc run_cmr_smoke {top generated sources tb_dir tb} {
  catch {file delete -force work}
  catch {file delete -force xsim.dir}
  exec xvlog -sv -work work $generated {*}$sources [file join $tb_dir $tb]
  exec xelab -timescale 1ns/1ps work.$top -s ${top}_sim
  set result [exec xsim ${top}_sim -runall]
  puts $result
  if {[string first "TB_RESULT FAIL" $result] >= 0 ||
      [string first "TB_RESULT PASS" $result] < 0} {
    error "$top did not report a clean TB_RESULT PASS"
  }
}

set opm_sources [list \
  [file join $opm_dir "Mutex2_sim.v"] \
  [file join $opm_dir "Mutex4.v"] \
  [file join $opm_dir "MullerC2.v"] \
  [file join $opm_dir "CMRMutexN.v"] \
  [file join $opm_dir "CMRFlattenedTAC.v"] \
  [file join $opm_dir "DLatchBank.v"] \
  [file join $opm_dir "V2CloseEvent.v"]]

set rcu_sources [list \
  [file join $rcu_dir "DelayElement_sim.v"] \
  [file join $rcu_dir "Toggle.v"] \
  [file join $rcu_dir "HeadPredictor.v"] \
  [file join $rcu_dir "PhaseSelector.v"] \
  [file join $rcu_dir "DLatchBank.v"] \
  [file join $rcu_dir "AddressRegisterUnit.v"] \
  [file join $rcu_dir "InternalAckModule.v"] \
  [file join $rcu_dir "OPMSelector.v"]]

set write_sources [list \
  [file join $write_dir "PhaseResetDLatch.v"] \
  [file join $write_dir "Toggle.v"] \
  [file join $write_dir "WriteControlUnit.v"] \
  [file join $write_dir "WriteCounter.v"] \
  [file join $write_dir "WriteAckGenerator.v"]]

set read_sources [list \
  [file join $read_dir "PhaseResetDLatch.v"] \
  [file join $read_dir "Toggle.v"] \
  [file join $read_dir "ReadControlUnit.v"] \
  [file join $read_dir "ReadCounter.v"] \
  [file join $read_dir "ReadRequestGenerator.v"] \
  [file join $read_dir "ReadPhaseSelector.v"] \
  [file join $read_dir "ReadAckGenerator.v"]]

set buffer_sources [list \
  [file join $buffer_dir "DLatchBank.v"] \
  [file join $buffer_dir "PhaseResetDLatch.v"] \
  [file join $buffer_dir "Toggle.v"] \
  [file join $buffer_dir "WriteControlUnit.v"] \
  [file join $buffer_dir "WriteCounter.v"] \
  [file join $buffer_dir "WriteAckGenerator.v"] \
  [file join $buffer_dir "ReadControlUnit.v"] \
  [file join $buffer_dir "ReadCounter.v"] \
  [file join $buffer_dir "ReadRequestGenerator.v"] \
  [file join $buffer_dir "ReadPhaseSelector.v"] \
  [file join $buffer_dir "ReadAckGenerator.v"]]

set router_sources [list \
  [file join $router_dir "DelayElement_sim.v"] \
  [file join $router_dir "Mutex2_sim.v"] \
  [file join $router_dir "Mutex4.v"] \
  [file join $router_dir "MullerC2.v"] \
  [file join $router_dir "CMRMutexN.v"] \
  [file join $router_dir "CMRFlattenedTAC.v"] \
  [file join $router_dir "DLatchBank.v"] \
  [file join $router_dir "V2CloseEvent.v"] \
  [file join $router_dir "Toggle.v"] \
  [file join $router_dir "HeadPredictor.v"] \
  [file join $router_dir "PhaseSelector.v"] \
  [file join $router_dir "AddressRegisterUnit.v"] \
  [file join $router_dir "InternalAckModule.v"] \
  [file join $router_dir "OPMSelector.v"] \
  [file join $router_dir "PhaseResetDLatch.v"] \
  [file join $router_dir "WriteControlUnit.v"] \
  [file join $router_dir "WriteCounter.v"] \
  [file join $router_dir "WriteAckGenerator.v"] \
  [file join $router_dir "ReadControlUnit.v"] \
  [file join $router_dir "ReadCounter.v"] \
  [file join $router_dir "ReadRequestGenerator.v"] \
  [file join $router_dir "ReadPhaseSelector.v"] \
  [file join $router_dir "ReadAckGenerator.v"]]

set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set cmr_dir [file join $async_dir "CMR"]
set circular_fifo_sources [list \
  [file join $async_dir "DLatchBank.v"] \
  [file join $cmr_dir "PhaseResetDLatch.v"] \
  [file join $cmr_dir "CircularWriteCounter.v"] \
  [file join $cmr_dir "CircularReadCounter.v"] \
  [file join $cmr_dir "WriteControlBlock.v"] \
  [file join $cmr_dir "ReadControlBlock.v"]]

run_cmr_smoke tb_opm_smoke [file join $opm_dir "OPM.v"] $opm_sources $tb_dir "tb_opm_smoke.sv"
run_cmr_smoke tb_rcu_smoke [file join $rcu_dir "RCU.v"] $rcu_sources $tb_dir "tb_rcu_smoke.sv"
run_cmr_smoke tb_cmr_counter_handshake_smoke \
  [file join $write_dir "WriteCounter.v"] \
  [list [file join $read_dir "ReadCounter.v"]] $tb_dir \
  "tb_cmr_counter_handshake_smoke.sv"
run_cmr_smoke tb_write_interface_control_smoke \
  [file join $write_dir "WriteInterfaceControl.v"] $write_sources $tb_dir \
  "tb_write_interface_control_smoke.sv"
run_cmr_smoke tb_read_interface_control_smoke \
  [file join $read_dir "ReadInterfaceControl.v"] $read_sources $tb_dir \
  "tb_read_interface_control_smoke.sv"
run_cmr_smoke tb_cmr_buffer_smoke \
  [file join $buffer_dir "CMRBuffer.v"] $buffer_sources $tb_dir \
  "tb_cmr_buffer_smoke.sv"
run_cmr_smoke tb_cmr_router_smoke \
  [file join $router_dir "CMRRouter.v"] $router_sources $tb_dir \
  "tb_cmr_router_smoke.sv"
run_cmr_smoke tb_circular_fifo_smoke \
  [file join $cmr_dir "CircularFIFO.v"] $circular_fifo_sources $tb_dir \
  "tb_circular_fifo_smoke.sv"

puts "TB_RESULT PASS CMR local smoke suite"
