# UltraRouter local structural-primitive smoke suite.
# This runner intentionally compiles Mutex2.v, not Mutex2_sim.v.  The latter
# remains available only for legacy delay-model experiments.
set repo_root [file normalize [file join [pwd] "../.."]]
set gen_dir [file join $repo_root "generated_ultra"]
set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set tb_dir [file join [pwd] "testbench"]

set common_sources [list \
  [file join $gen_dir UltraRouter.v] \
  [file join $async_dir DelayElement_sim.v] \
  [file join $async_dir Mutex2.v] \
  [file join $async_dir Mutex4.v] \
  [file join $async_dir DLatchBank.v] \
  [file join $async_dir V2CloseEvent.v] \
  [file join $async_dir MousetrapStage.v] \
  [file join $async_dir MullerC2.v] \
  [file join $async_dir MullerC3.v] \
  [file join $async_dir TAC2.v] \
  [file join $async_dir Mutex3Grant.v] \
  [file join $async_dir Mutex5Anchor.v] \
  [file join $async_dir UltraHeadCaptureCell.v] \
  [file join $async_dir AsyncRoundMembershipCell.v] \
  [file join $async_dir AsyncRoundDecisionCell.v] \
  [file join $async_dir AsyncArbiterTransactionController.v]]

if {![file exists [file join $gen_dir UltraRouter.v]]} {
  error "missing generated_ultra/UltraRouter.v; run UltraRouterMain first"
}

proc run_smoke {name tb common_sources tb_dir} {
  catch {file delete -force work}
  catch {file delete -force xsim.dir}
  exec xvlog -sv -d ULTRA_TRACE_RTL -work work {*}$common_sources [file join $tb_dir $tb]
  exec xelab -timescale 1ns/1ps work.$name -s ${name}_sim
  exec xsim ${name}_sim -runall
}

proc run_boundary_case {case_name common_sources tb_dir} {
  set tb tb_ultra_router_boundary_smoke.sv
  set top tb_ultra_router_boundary_smoke
  set snapshot "${top}_${case_name}_sim"
  catch {file delete -force work}
  catch {file delete -force xsim.dir}
  exec xvlog -sv -d ULTRA_TRACE_RTL -work work {*}$common_sources [file join $tb_dir $tb]
  exec xelab -debug all -timescale 1ns/1ps work.$top -s $snapshot
  set args_file "${snapshot}.args"
  set fd [open $args_file w]
  puts $fd "-testplusarg"
  puts $fd "SMOKE_CASE=$case_name"
  puts $fd "-testplusarg"
  puts $fd "DUMP_VCD=ultra_router_${case_name}.vcd"
  puts $fd "-runall"
  close $fd
  exec xsim $snapshot -f $args_file
}

run_smoke tb_muller_c2_smoke tb_muller_c2_smoke.sv $common_sources $tb_dir
run_smoke tb_muller_c3_smoke tb_muller_c3_smoke.sv $common_sources $tb_dir
run_smoke tb_ultra_primitives_smoke tb_ultra_primitives_smoke.sv $common_sources $tb_dir
run_smoke tb_mutex5_anchor_smoke tb_mutex5_anchor_smoke.sv $common_sources $tb_dir
run_smoke tb_ipm_smoke tb_ipm_smoke.sv $common_sources $tb_dir
# AtomicMulticastArbiterV2 has its own generated top-level and standalone
# runner.  In this Router build its clock is intentionally pruned because the
# reservation bank is exclusively clocked by ACG.fire_o; compile it there,
# rather than against the inlined Router copy.
run_smoke tb_request_generator_bank_smoke tb_request_generator_bank_smoke.sv $common_sources $tb_dir
foreach case_name {unicast3 mc_single3 mc_disjoint_parallel3 uc_overlap_release3 mc_overlap_tailjoin3 b_alone_head a_then_b_head_parallel} {
  run_boundary_case $case_name $common_sources $tb_dir
}
run_smoke tb_ultra_router_rtc_all_edges tb_ultra_router_rtc_all_edges.sv $common_sources $tb_dir

puts "TB_RESULT PASS UltraRouter structural smoke suite"
