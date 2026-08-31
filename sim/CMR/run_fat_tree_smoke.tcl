set repo_root [file normalize [file join [pwd] "../.."]]
set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set cmr_dir [file join $async_dir "CMR"]
set tb_dir [file join [pwd] "testbench"]
set router_l1_dir [file join $repo_root "generated_cmr" "router_l1_c1_p2"]
set router_l2_dir [file join $repo_root "generated_cmr" "router_l2_c2_p4"]

proc run_test {top sources} {
  catch {file delete -force work}
  catch {file delete -force xsim.dir}
  exec xvlog -sv -work work {*}$sources
  exec xelab -timescale 1ns/1ps work.$top -s ${top}_sim
  set result [exec xsim ${top}_sim -runall]
  puts $result
  if {[string first "TB_RESULT FAIL" $result] >= 0 ||
      [string first "TB_RESULT PASS" $result] < 0} {
    error "$top did not report PASS"
  }
}

set common [list \
  [file join $async_dir "Mutex2_sim.v"] \
  [file join $async_dir "Mutex4.v"] \
  [file join $async_dir "MullerC2.v"] \
  [file join $cmr_dir "CMRMutexN.v"] \
  [file join $cmr_dir "CMRFlattenedTAC.v"]]

run_test tb_cmr_mutexn_smoke [concat $common [list [file join $tb_dir "tb_cmr_mutexn_smoke.sv"]]]
run_test tb_cmr_continuous_lane_smoke [concat $common [list [file join $tb_dir "tb_cmr_continuous_lane_smoke.sv"]]]
run_test tb_cmr_flattened_tac_smoke [concat $common [list [file join $tb_dir "tb_cmr_flattened_tac_smoke.sv"]]]
run_test tb_cmr_lane_phase_adapter_smoke [list \
  [file join $cmr_dir "PhaseResetDLatch.v"] \
  [file join $cmr_dir "LanePhaseAdapter.v"] \
  [file join $tb_dir "tb_cmr_lane_phase_adapter_smoke.sv"]]

if {![file exists [file join $router_l1_dir "CMRRouter.v"]]} {
  error "missing L1 multi-lane Router; run CMRRouterMain 1 1 2"
}
set router_sources [list \
  [file join $router_l1_dir "DelayElement_sim.v"] \
  [file join $router_l1_dir "Mutex2_sim.v"] \
  [file join $router_l1_dir "Mutex4.v"] \
  [file join $router_l1_dir "MullerC2.v"] \
  [file join $router_l1_dir "CMRMutexN.v"] \
  [file join $router_l1_dir "CMRFlattenedTAC.v"] \
  [file join $router_l1_dir "DLatchBank.v"] \
  [file join $router_l1_dir "V2CloseEvent.v"] \
  [file join $router_l1_dir "Toggle.v"] \
  [file join $router_l1_dir "HandshakeComplete.v"] \
  [file join $router_l1_dir "HeadPredictor.v"] \
  [file join $router_l1_dir "PhaseSelector.v"] \
  [file join $router_l1_dir "AddressRegisterUnit.v"] \
  [file join $router_l1_dir "InternalAckModule.v"] \
  [file join $router_l1_dir "OPMSelector.v"] \
  [file join $router_l1_dir "PhaseResetDLatch.v"] \
  [file join $router_l1_dir "LanePhaseAdapter.v"] \
  [file join $router_l1_dir "WriteControlUnit.v"] \
  [file join $router_l1_dir "WriteCounter.v"] \
  [file join $router_l1_dir "WriteAckGenerator.v"] \
  [file join $router_l1_dir "ReadControlUnit.v"] \
  [file join $router_l1_dir "ReadCounter.v"] \
  [file join $router_l1_dir "ReadRequestGenerator.v"] \
  [file join $router_l1_dir "ReadPhaseSelector.v"] \
  [file join $router_l1_dir "ReadAckGenerator.v"]]
run_test tb_cmr_router_l1_multilane_smoke [concat \
  [list [file join $router_l1_dir "CMRRouter.v"]] $router_sources \
  [list [file join $tb_dir "tb_cmr_router_l1_multilane_smoke.sv"]]]

if {![file exists [file join $router_l2_dir "CMRRouter.v"]]} {
  error "missing L2 multi-lane Router; run CMRRouterMain 2 2 4"
}
set router_l2_sources [list]
foreach source $router_sources {
  lappend router_l2_sources [file join $router_l2_dir [file tail $source]]
}
run_test tb_cmr_router_l2_multilane_smoke [concat \
  [list [file join $router_l2_dir "CMRRouter.v"]] $router_l2_sources \
  [list [file join $tb_dir "tb_cmr_router_l2_multilane_smoke.sv"]]]

# The same two-packet dynamic transaction is repeated through exact parent
# widths 2/4/8, exercising OPM Mutex5/10/20 and lane Mutex2/4/8 in situ.
foreach {level parents top} {
  1 2 tb_cmr_router_lane_l1_smoke
  2 4 tb_cmr_router_lane_l2_smoke
  3 8 tb_cmr_router_lane_l3_smoke
} {
  set harness_dir [file join $repo_root "generated_cmr" "lane_harness_l${level}"]
  set harness_verilog [file join $harness_dir "CMRRouterLaneSmokeHarness.v"]
  if {![file exists $harness_verilog]} {
    error "missing $harness_verilog; run CMRRouterLaneSmokeHarnessMain"
  }
  set harness_sources [list]
  foreach source $router_sources {
    lappend harness_sources [file join $harness_dir [file tail $source]]
  }
  run_test $top [concat [list $harness_verilog] $harness_sources \
    [list [file join $tb_dir "tb_cmr_router_lane_harness_smoke.sv"]]]
}

set tree_dir [file join $repo_root "generated_cmr" "fat_tree_smoke_harness"]
set tree_verilog [file join $tree_dir "CMRFatTreeSmokeHarness.v"]
if {![file exists $tree_verilog]} {
  error "missing $tree_verilog; run NoC.CMR.CMRFatTreeSmokeHarnessMain"
}
set tree_sources [list]
foreach source [glob -nocomplain [file join $tree_dir "*.v"]] {
  if {[file normalize $source] ne [file normalize $tree_verilog]} {
    lappend tree_sources $source
  }
}
run_test tb_cmr_fat_tree_smoke [concat [list $tree_verilog] $tree_sources \
  [list [file join $tb_dir "tb_cmr_fat_tree_smoke.sv"]]]

puts "TB_RESULT PASS CMR Fat-Tree primitive smoke suite"
