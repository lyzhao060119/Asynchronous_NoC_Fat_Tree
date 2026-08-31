set repo_root [file normalize [file join [pwd] "../.."]]
set resource_dir [file join $repo_root "src" "main" "resources" "ASYNC" "CMR"]
set tb [file join [pwd] "testbench" "tb_opm_selector_path_latch_smoke.sv"]

catch {file delete -force work}
catch {file delete -force xsim.dir}
exec xvlog -sv -work work [file join $resource_dir "OPMSelector.v"] $tb
exec xelab -timescale 1ns/1ps work.tb_opm_selector_path_latch_smoke \
  -s tb_opm_selector_path_latch_smoke_sim
set result [exec xsim tb_opm_selector_path_latch_smoke_sim -runall]
puts $result
if {[string first "TB_RESULT PASS" $result] < 0 ||
    [string first "TB_RESULT FAIL" $result] >= 0} {
  error "PathLatch RTL smoke did not pass"
}
