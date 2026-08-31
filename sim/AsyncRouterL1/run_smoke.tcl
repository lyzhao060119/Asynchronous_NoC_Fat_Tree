# Vivado xsim smoke run for async RouterL1 (toggle handshake TB)
set repo_root [file normalize [file join [pwd] "../.."]]
set gen_dir [file join $repo_root "generated"]
set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set tb_dir [file join [pwd] "testbench"]

proc getenv_default {name default_value} {
  if {[info exists ::env($name)]} {
    return $::env($name)
  }
  return $default_value
}

proc async_primitive_sources {async_dir} {
  set profile [string tolower [getenv_default ASYNC_PRIMITIVES sim]]
  switch -- $profile {
    sim {
      return [list \
        [file join $async_dir DelayElement_sim.v] \
        [file join $async_dir Mutex2_sim.v]]
    }
    structural {
      return [list \
        [file join $async_dir DelayElement_sim.v] \
        [file join $async_dir Mutex2.v]]
    }
    fpga -
    synth {
      return [list \
        [file join $async_dir DelayElement_FPGA.v] \
        [file join $async_dir Mutex2_fpga.v]]
    }
    asic {
      return [list \
        [file join $async_dir DelayElement_ASIC.v] \
        [file join $async_dir Mutex2_ASIC.v]]
    }
    default {
      error "Unsupported ASYNC_PRIMITIVES=$profile; expected sim, structural, fpga, synth, or asic"
    }
  }
}

foreach d [list $gen_dir] {
  if {![file exists [file join $d RouterL1.v]]} {
    puts "ERROR: missing generated/RouterL1.v — run: sbt \"runMain Router_Architecture.instantiation.RouterL1\""
    exit 1
  }
}

file mkdir [file join [pwd] "summary"]

if {[file exists work]} {
  catch {file delete -force work}
}
if {[file exists xsim.dir]} {
  catch {file delete -force xsim.dir}
}

set compile_cmd [list xvlog -sv -work work [file join $gen_dir RouterL1.v]]
foreach source_path [async_primitive_sources $async_dir] {
  lappend compile_cmd $source_path
}
lappend compile_cmd [file join $tb_dir fanin_debug_probe.sv]
lappend compile_cmd [file join $tb_dir tb_asyncrouter_l1.sv]
exec {*}$compile_cmd

exec xelab -timescale 1ns/1ps -debug typical work.tb_asyncrouter_l1 -s tb_asyncrouter_l1_sim

set args_file [file join [pwd] "xsim.args"]
set fd [open $args_file w]
puts $fd "-tclbatch"
puts $fd "sim_run.tcl"
puts $fd "-testplusarg"
puts $fd "CASE=testbench/cases/smoke_directed.case"
puts $fd "-testplusarg"
puts $fd "CSV=summary/smoke_directed.csv"
close $fd

exec xsim tb_asyncrouter_l1_sim -f $args_file
