# Standalone structural smoke for AtomicMulticastArbiterV2.  The legacy
# AtomicMulticastAdmission and UltraRouter are deliberately not compiled here.
set repo_root [file normalize [file join [pwd] "../.."]]
set gen_dir [file join $repo_root "generated_ultra"]
set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set tb_dir [file join [pwd] "testbench"]

set sources [list \
  [file join $gen_dir AtomicMulticastArbiterV2.v] \
  [file join $gen_dir UltraHeadCaptureCell.v] \
  [file join $gen_dir AsyncRoundMembershipCell.v] \
  [file join $gen_dir AsyncRoundDecisionCell.v] \
  [file join $gen_dir AsyncArbiterTransactionController.v] \
  [file join $async_dir DelayElement_sim.v] \
  [file join $async_dir DLatchBank.v] \
  [file join $async_dir Mutex2.v] \
  [file join $async_dir MullerC2.v] \
  [file join $async_dir TAC2.v] \
  [file join $async_dir Mutex3Grant.v] \
  [file join $async_dir Mutex5Anchor.v]]

proc run_smoke {top tb sources tb_dir} {
  catch {file delete -force work}
  catch {file delete -force xsim.dir}
  exec xvlog -sv -work work {*}$sources [file join $tb_dir $tb]
  exec xelab -timescale 1ns/1ps work.$top -s ${top}_sim
  set sim_output [exec xsim ${top}_sim -runall]
  puts $sim_output
  if {[string first "TB_RESULT FAIL" $sim_output] >= 0} { error $sim_output }
}

run_smoke tb_async_round_decision_cell_smoke tb_async_round_decision_cell_smoke.sv $sources $tb_dir
run_smoke tb_async_round_membership_cell_smoke tb_async_round_membership_cell_smoke.sv $sources $tb_dir
run_smoke tb_ultra_head_capture_cell_smoke tb_ultra_head_capture_cell_smoke.sv $sources $tb_dir
run_smoke tb_async_arbiter_transaction_controller_smoke tb_async_arbiter_transaction_controller_smoke.sv $sources $tb_dir
run_smoke tb_atomic_multicast_admission_smoke tb_atomic_multicast_admission_smoke.sv $sources $tb_dir
puts "TB_RESULT PASS AtomicMulticastArbiterV2 structural smoke"
