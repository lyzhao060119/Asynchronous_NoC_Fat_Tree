# Run all AsyncRouterL1 directed cases (compile once, sim each case).
set repo_root [file normalize [file join [pwd] "../.."]]
set gen_dir [file join $repo_root "generated"]
set async_dir [file join $repo_root "src" "main" "resources" "ASYNC"]
set tb_dir [file join [pwd] "testbench"]
set cases_dir [file join $tb_dir "cases"]

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
      error "Unsupported ASYNC_PRIMITIVES=$profile; expected sim, fpga, synth, or asic"
    }
  }
}

file mkdir [file join [pwd] "summary"]

if {![file exists [file join $gen_dir RouterL1.v]]} {
  puts "ERROR: run sbt \"runMain Router_Architecture.instantiation.RouterL1\" first"
  exit 1
}

if {[file exists work]} { catch {file delete -force work} }
if {[file exists xsim.dir]} { catch {file delete -force xsim.dir} }

set compile_cmd [list xvlog -sv -work work [file join $gen_dir RouterL1.v]]
foreach source_path [async_primitive_sources $async_dir] {
  lappend compile_cmd $source_path
}
lappend compile_cmd [file join $tb_dir fanin_debug_probe.sv]
lappend compile_cmd [file join $tb_dir tb_asyncrouter_l1.sv]
exec {*}$compile_cmd

exec xelab -timescale 1ns/1ps work.tb_asyncrouter_l1 -s tb_asyncrouter_l1_sim

set pass 0
set fail 0
set results {}

set all_case_paths [lsort [glob -nocomplain -directory $cases_dir *.case]]
set selected_case_paths {}
set case_list [getenv_default ASYNC_ROUTERL1_CASE_LIST ""]
set case_glob [getenv_default ASYNC_ROUTERL1_CASE_GLOB ""]

if {$case_list ne ""} {
  foreach token [regexp -all -inline {[^,; \t\r\n]+} $case_list] {
    set case_name $token
    if {![string match "*.case" $case_name]} {
      append case_name ".case"
    }
    set case_path [file join $cases_dir $case_name]
    if {![file exists $case_path]} {
      puts "ERROR: requested case not found: $case_name"
      exit 1
    }
    lappend selected_case_paths $case_path
  }
} elseif {$case_glob ne ""} {
  set selected_case_paths [lsort [glob -nocomplain -directory $cases_dir $case_glob]]
  if {[llength $selected_case_paths] == 0} {
    puts "ERROR: ASYNC_ROUTERL1_CASE_GLOB matched no cases: $case_glob"
    exit 1
  }
} else {
  set selected_case_paths $all_case_paths
}

foreach case_path $selected_case_paths {
  set case_name [file tail $case_path]
  set case_rel "testbench/cases/$case_name"
  set csv_rel "summary/$case_name"
  regsub {\.case$} $csv_rel ".csv" csv_rel

  set args_file [file join [pwd] "xsim.args"]
  set fd [open $args_file w]
  puts $fd "-tclbatch"
  puts $fd "sim_run.tcl"
  puts $fd "-testplusarg"
  puts $fd "CASE=$case_rel"
  puts $fd "-testplusarg"
  puts $fd "CSV=$csv_rel"
  close $fd

  puts "===== RUN $case_name ====="
  if {[catch {exec xsim tb_asyncrouter_l1_sim -f $args_file} err]} {
    puts $err
    incr fail
    lappend results "FAIL $case_name (xsim error)"
  } else {
    if {[regexp {TB_RESULT PASS} $err]} {
      incr pass
      lappend results "PASS $case_name"
    } elseif {[regexp {TB_RESULT FAIL} $err]} {
      incr fail
      lappend results "FAIL $case_name"
    } else {
      incr fail
      lappend results "FAIL $case_name (no TB_RESULT)"
    }
    puts $err
  }
}

puts "\n===== SUMMARY pass=$pass fail=$fail ====="
foreach r $results { puts $r }
if {$fail > 0} { exit 1 }
