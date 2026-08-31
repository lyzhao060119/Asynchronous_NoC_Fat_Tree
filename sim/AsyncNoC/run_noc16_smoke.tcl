# Vivado xsim smoke run for async NoC_16nodes AXI/BRAM wrapper
set repo_root [file normalize [file join [pwd] "../.."]]
set gen_dir [file join $repo_root "generated"]
set tb_dir [file join [pwd] "testbench"]
set async_res_dir [file join $repo_root "src/main/resources/ASYNC"]

proc getenv_default {name default_value} {
  if {[info exists ::env($name)]} {
    return $::env($name)
  }
  return $default_value
}

proc async_primitive_sources {async_res_dir} {
  set profile [string tolower [getenv_default ASYNC_PRIMITIVES sim]]
  switch -- $profile {
    sim {
      return [list \
        [file join $async_res_dir DelayElement_sim.v] \
        [file join $async_res_dir Mutex2_sim.v] \
        [file join $async_res_dir MrGo.v]]
    }
    fpga -
    synth {
      return [list \
        [file join $async_res_dir DelayElement_FPGA.v] \
        [file join $async_res_dir Mutex2_fpga.v] \
        [file join $async_res_dir MrGo.v]]
    }
    asic {
      return [list \
        [file join $async_res_dir DelayElement_ASIC.v] \
        [file join $async_res_dir Mutex2_ASIC.v] \
        [file join $async_res_dir MrGo.v]]
    }
    default {
      error "Unsupported ASYNC_PRIMITIVES=$profile; expected sim, fpga, synth, or asic"
    }
  }
}

if {[file exists work]} {
  catch {file delete -force work}
}
if {[file exists xsim.dir]} {
  catch {file delete -force xsim.dir}
}

set compile_cmd [list xvlog -sv -work work [file join $gen_dir NoC_16nodes.v]]
foreach source_path [async_primitive_sources $async_res_dir] {
  lappend compile_cmd $source_path
}
lappend compile_cmd [file join [pwd] async_noc16_axi_bram_wrapper.sv]
lappend compile_cmd [file join $tb_dir tb_noc16_async_axi_bram.sv]
exec {*}$compile_cmd

exec xelab -timescale 1ns/1ps -debug typical work.tb_noc16_async_axi_bram -s tb_noc16_async_axi_bram_sim

set case_rel "testbench/small_cases/noc16_00_to_33_3flit_smoke.case"
set case_file [file join [pwd] $case_rel]
if {![file exists $case_file]} {
  puts "ERROR: missing case file $case_file"
  puts "Expected small smoke case at testbench/small_cases/noc16_00_to_33_3flit_smoke.case"
  exit 1
}

file mkdir summary
set smoke_csv [file join [pwd] summary noc16_async_smoke.csv]
if {[file exists $smoke_csv]} {
  file delete -force $smoke_csv
}
set cfg_fd [open noc16_xsim_case.cfg w]
puts $cfg_fd "CASE [string map {\\ /} [file normalize $case_file]]"
puts $cfg_fd "CSV [string map {\\ /} [file normalize $smoke_csv]]"
close $cfg_fd

exec xsim tb_noc16_async_axi_bram_sim -tclbatch sim_run.tcl
