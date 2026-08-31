# Local functional diagnostic.  Mutex2_sim adds its documented 10 ps physical
# mismatch, so this run validates the harness and non-synchronous scenarios;
# strict symmetric behavior is decided only by the ASIC SDF run.
set repo_root [file normalize [file join [pwd] "../.."]]
set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set cmr_dir [file join $async_dir "CMR"]
set tb_dir [file join [pwd] "testbench"]
catch {file delete -force work}
catch {file delete -force xsim.dir}
exec xvlog -sv -work work \
  [file join $async_dir "Mutex2_sim.v"] \
  [file join $async_dir "Mutex4.v"] \
  [file join $async_dir "MullerC2.v"] \
  [file join $cmr_dir "CMRMutexN.v"] \
  [file join $cmr_dir "CMRFlattenedTAC.v"] \
  [file join $tb_dir "CMRLaneSelectorMutex2Harness.v"] \
  [file join $tb_dir "tb_cmr_lane_mutex_contention.sv"]
exec xelab -timescale 1ns/1ps work.tb_cmr_lane_mutex_contention -s cmr_lane_mutex_contention_sim
set result [exec xsim cmr_lane_mutex_contention_sim -runall]
puts $result
if {[string first "TB_RESULT PASS" $result] < 0 || [string first "TB_FAIL" $result] >= 0} {
  error "CMR lane-mutex local diagnostic failed"
}
puts "TB_RESULT PASS CMR lane-mutex local diagnostic"
