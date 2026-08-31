# Run with Vivado:
#   vivado -mode batch -source sim/AsyncNoC/run_noc16_all_cases_vivado.tcl
#
# Optional environment variables:
#   ASYNC_NOC16_REPO_ROOT     repository root, if auto-detect is not enough
#   ASYNC_NOC16_RTL           optional explicit NoC_16nodes RTL path
#   ASYNC_NOC16_GROUP_GLOB    only run case groups matching this Tcl glob
#   ASYNC_NOC16_CASE_GLOB     only run case names matching this Tcl glob
#   ASYNC_NOC16_CASE_LIST     optional comma/space separated exact case names
#   ASYNC_NOC16_CASE_ROOT     optional alternate case root
#   ASYNC_NOC16_SUMMARY_ROOT  override summary output root
#   ASYNC_NOC16_TRUNCATE_CSV  1 to clear CSVs before running, 0 to append
#   ASYNC_NOC16_VIVADO_BIN    Vivado bin directory containing xvlog/xelab/xsim
#   ASYNC_NOC16_WORK_DIR      override xsim work directory
#   ASYNC_NOC16_SIM_MODE      axi (default) or direct
#   ASYNC_PRIMITIVES          sim (default), fpga, or synth async primitive models
#   ASYNC_NOC16_MUTEX_MODEL   sim (default) or structural; structural is
#                             required by the current Ultra Mutex5Anchor RTL
#   ASYNC_NOC16_XELAB_DEBUG   typical (default) or all for hierarchy probes
#   ASYNC_NOC16_XSIM_PLUSARGS space-separated test plusargs for debug runs
#   ASYNC_NOC16_DEBUG_MAX_PKT_SEQ inclusive packet-sequence prefix limit

proc unix_path {path} {
  return [string map {\\ /} [file normalize $path]]
}

proc getenv_default {name default_value} {
  if {[info exists ::env($name)]} {
    return $::env($name)
  }
  return $default_value
}

proc async_primitive_sources {repo_root} {
  set profile [string tolower [getenv_default ASYNC_PRIMITIVES sim]]
  set mutex_model [string tolower [getenv_default ASYNC_NOC16_MUTEX_MODEL sim]]
  set async_dir [file join $repo_root src main resources ASYNC]
  set shared_sources [list \
    [file join $async_dir DLatchBank.v] \
    [file join $async_dir V2CloseEvent.v] \
    [file join $async_dir MousetrapStage.v] \
    [file join $async_dir MullerC3.v]]

  switch -- $profile {
    sim {
      if {$mutex_model eq "structural"} {
        set mutex_source [file join $async_dir Mutex2.v]
      } elseif {$mutex_model eq "sim"} {
        set mutex_source [file join $async_dir Mutex2_sim.v]
      } else {
        error "Unsupported ASYNC_NOC16_MUTEX_MODEL=$mutex_model; expected sim or structural"
      }
      return [concat [list \
        [file join $async_dir DelayElement_sim.v] \
        $mutex_source \
        [file join $async_dir MrGo.v] \
        [file join $async_dir MullerC2.v] \
        [file join $async_dir TAC2.v] \
        [file join $async_dir Mutex3Grant.v] \
        [file join $async_dir Mutex5Anchor.v]] $shared_sources]
    }
    fpga -
    synth {
      return [concat [list \
        [file join $async_dir DelayElement_FPGA.v] \
        [file join $async_dir Mutex2_fpga.v] \
        [file join $async_dir MrGo.v]] $shared_sources]
    }
    asic {
      return [concat [list \
        [file join $async_dir DelayElement_ASIC.v] \
        [file join $async_dir Mutex2_ASIC.v] \
        [file join $async_dir MrGo.v]] $shared_sources]
    }
    default {
      error "Unsupported ASYNC_PRIMITIVES=$profile; expected sim, fpga, synth, or asic"
    }
  }
}

proc find_vivado_tool {name} {
  set candidates {}

  if {[info exists ::env(ASYNC_NOC16_VIVADO_BIN)]} {
    lappend candidates [file join $::env(ASYNC_NOC16_VIVADO_BIN) "${name}.bat"]
    lappend candidates [file join $::env(ASYNC_NOC16_VIVADO_BIN) $name]
    lappend candidates [file join $::env(ASYNC_NOC16_VIVADO_BIN) "${name}.exe"]
  }

  if {[info exists ::env(XILINX_VIVADO)]} {
    lappend candidates [file join $::env(XILINX_VIVADO) bin "${name}.bat"]
    lappend candidates [file join $::env(XILINX_VIVADO) bin $name]
    lappend candidates [file join $::env(XILINX_VIVADO) bin "${name}.exe"]
  }

  foreach candidate $candidates {
    if {[file exists $candidate]} {
      return [list [file normalize $candidate]]
    }
  }

  set found [auto_execok $name]
  if {$found ne ""} {
    return $found
  }

  error "Cannot find $name. Add Vivado bin to PATH or set ASYNC_NOC16_VIVADO_BIN."
}

proc run_cmd {cmd} {
  puts "> [join $cmd { }]"
  if {[catch {exec {*}$cmd} output options]} {
    if {$output ne ""} {
      puts $output
    }
    puts "Command failed: [dict get $options -errorcode]"
    return 0
  }
  if {$output ne ""} {
    puts $output
  }
  return 1
}

proc noc16_rtl_candidates {repo_root} {
  return [list \
    [file join $repo_root generated NoC_16nodes.v] \
    [file join $repo_root generated NoC_16nodes.sv] \
    [file join $repo_root sim AsyncNoC NoC_16nodes.v] \
    [file join $repo_root sim AsyncNoC NoC_16nodes.sv]]
}

proc resolve_noc16_rtl {repo_root} {
  if {[info exists ::env(ASYNC_NOC16_RTL)]} {
    return [file normalize $::env(ASYNC_NOC16_RTL)]
  }
  foreach candidate [noc16_rtl_candidates $repo_root] {
    if {[file exists $candidate]} {
      return [file normalize $candidate]
    }
  }
  return ""
}

proc find_repo_root {start_dir} {
  set cur [file normalize $start_dir]
  while {1} {
    if {[file exists [file join $cur sim AsyncNoC testbench tb_noc16_async.sv]] &&
        [file exists [file join $cur sim AsyncNoC testbench async_hs_port.sv]]} {
      return $cur
    }

    set parent [file dirname $cur]
    if {$parent eq $cur} {
      return ""
    }
    set cur $parent
  }
}

proc read_text_file {path} {
  set fd [open $path r]
  set text [read $fd]
  close $fd
  return $text
}

proc case_top_port_violation {path} {
  set fd [open $path r]
  set line_no 0
  while {[gets $fd raw_line] >= 0} {
    incr line_no
    set line [string trim [lindex [split $raw_line "#"] 0]]
    if {$line eq ""} {
      continue
    }

    if {[regexp {^input[ \t]+[0-9]+[ \t]+([0-9]+)[ \t]+} $line -> port]} {
      if {$port >= 16} {
        close $fd
        return "line $line_no uses input top port $port"
      }
    }

    if {[regexp {^expect[ \t]+([0-9a-fA-F]+)[ \t]+} $line -> mask_hex]} {
      scan $mask_hex %x mask
      for {set port 16} {$port < 20} {incr port} {
        if {($mask & (1 << $port)) != 0} {
          close $fd
          return "line $line_no expects output top port $port mask=0x$mask_hex"
        }
      }
    }
  }
  close $fd
  return ""
}

proc truncate_file {path} {
  file mkdir [file dirname $path]
  set fd [open $path w]
  close $fd
}

proc csv_for_case {group case_name} {
  global summary_root

  switch -- $group {
    VCTM_16 {
      return [file join $summary_root VCTM_16 VCTM_16.csv]
    }
    TAB_16 {
      return [file join $summary_root TAB_16 TAB_16.csv]
    }
    default {
      return [file join $summary_root misc "${group}.csv"]
    }
  }
}

proc run_case {case_path csv_path} {
  global XSIM snapshot log_dir work_dir
  set debug_on_fail [getenv_default ASYNC_NOC16_DEBUG_ON_FAIL 1]

  set case_name [file rootname [file tail $case_path]]
  set group [file tail [file dirname $case_path]]
  set log_path [file join $log_dir $group "${case_name}.log"]
  set wdb_path [file join $log_dir $group "${case_name}.wdb"]
  set cfg_path [file join $work_dir noc16_xsim_case.cfg]
  set debug_max_pkt_seq [getenv_default ASYNC_NOC16_DEBUG_MAX_PKT_SEQ -1]

  puts "RUN $case_name"
  puts "  CASE [unix_path $case_path]"
  puts "  CSV  [unix_path $csv_path]"

  set top_violation [case_top_port_violation $case_path]
  if {$top_violation ne ""} {
    puts "FAIL $case_name: Stage1 NoC16 core-only check failed: $top_violation"
    return 0
  }

  file mkdir [file dirname $csv_path]
  file mkdir [file dirname $log_path]

  set cfg_fd [open $cfg_path w]
  puts $cfg_fd "CASE [unix_path $case_path]"
  puts $cfg_fd "CSV [unix_path $csv_path]"
  puts $cfg_fd "DEBUG_MAX_PKT_SEQ $debug_max_pkt_seq"
  close $cfg_fd

  set cmd [concat $XSIM [list $snapshot \
    --runall \
    --onerror quit \
    --onfinish quit]]
  if {$debug_on_fail == 0} {
    lappend cmd --testplusarg "ASYNC_NOC16_DEBUG_ON_FAIL_OFF"
  }
  foreach plusarg [split [getenv_default ASYNC_NOC16_XSIM_PLUSARGS ""] " "] {
    if {$plusarg ne ""} {
      # xsim --testplusarg consumes the bare argument; unlike VCS it does
      # not accept a leading '+'.
      lappend cmd --testplusarg $plusarg
    }
  }
  set cmd [concat $cmd [list \
    --log [unix_path $log_path] \
    --wdb [unix_path $wdb_path]]]

  if {![run_cmd $cmd]} {
    puts "FAIL $case_name: xsim command failed"
    return 0
  }

  if {![file exists $log_path]} {
    puts "FAIL $case_name: missing log [unix_path $log_path]"
    return 0
  }

  set log_text [read_text_file $log_path]
  if {[string first "TB_RESULT PASS" $log_text] < 0} {
    puts "FAIL $case_name: TB_RESULT PASS not found"
    return 0
  }
  if {[regexp {TB_FATAL|TB_RESULT FAIL|ERROR:|FATAL_ERROR|Fatal:} $log_text]} {
    puts "FAIL $case_name: fatal/fail pattern found in log"
    return 0
  }

  puts "PASS $case_name"
  return 1
}

if {[info exists ::env(ASYNC_NOC16_REPO_ROOT)]} {
  set repo_root [file normalize $::env(ASYNC_NOC16_REPO_ROOT)]
} else {
  set repo_root [find_repo_root [pwd]]
  if {$repo_root eq ""} {
    set repo_root [find_repo_root [file dirname [file normalize [info script]]]]
  }
}

if {$repo_root eq ""} {
  puts "Cannot locate repository root. Set ASYNC_NOC16_REPO_ROOT and rerun."
  exit 1
}

set sim_root     [file normalize [file join $repo_root sim AsyncNoC]]
set noc16_rtl    [resolve_noc16_rtl $repo_root]
set case_root    [file normalize [getenv_default ASYNC_NOC16_CASE_ROOT [file join $sim_root testbench generated_cases]]]
set summary_root [file normalize [getenv_default ASYNC_NOC16_SUMMARY_ROOT [file join $sim_root summary]]]
set work_dir     [file normalize [getenv_default ASYNC_NOC16_WORK_DIR [file join $repo_root sim xsim work_asyncnoc16_all]]]
set log_dir      [file normalize [file join $work_dir logs]]

if {$noc16_rtl eq "" || ![file exists $noc16_rtl]} {
  puts "Cannot locate async NoC_16nodes RTL. Generate it with:"
  puts {  sbt "runMain NoC.NoC_16nodes --target-dir generated"}
  puts "Expected one of: [noc16_rtl_candidates $repo_root]"
  exit 1
}

set sim_mode [getenv_default ASYNC_NOC16_SIM_MODE axi]
if {$sim_mode eq "axi"} {
  set top tb_noc16_async_axi_bram
  set snapshot tb_noc16_async_axi_bram_sim
  set tb_sources [list \
    [file join $sim_root async_noc16_axi_bram_wrapper.sv] \
    [file join $sim_root testbench tb_noc16_async_axi_bram.sv]]
} elseif {$sim_mode eq "direct"} {
  set top tb_noc16_async
  set snapshot tb_noc16_async_sim
  set tb_sources [list \
    [file join $sim_root testbench async_hs_port.sv] \
    [file join $sim_root testbench tb_noc16_async.sv]]
} else {
  puts "Unsupported ASYNC_NOC16_SIM_MODE=$sim_mode; expected axi or direct"
  exit 1
}
set truncate_csv [getenv_default ASYNC_NOC16_TRUNCATE_CSV 1]
set stop_on_fail [getenv_default ASYNC_NOC16_STOP_ON_FAIL 1]
set group_glob [getenv_default ASYNC_NOC16_GROUP_GLOB *]
set case_glob [getenv_default ASYNC_NOC16_CASE_GLOB *]
set case_list {}

if {[info exists ::env(ASYNC_NOC16_CASE_LIST)]} {
  set case_list [split [string map {"," " "} $::env(ASYNC_NOC16_CASE_LIST)] " "]
}

set XVLOG [find_vivado_tool xvlog]
set XELAB [find_vivado_tool xelab]
set XSIM  [find_vivado_tool xsim]

file mkdir $work_dir
file mkdir $log_dir
cd $work_dir

set compile_log [file join $log_dir xvlog.log]
set elab_log [file join $log_dir xelab.log]

puts "Compiling async NoC16 $sim_mode simulation with Vivado xsim..."
set compile_cmd [concat $XVLOG [list --sv --work work --log [unix_path $compile_log]]]
if {[getenv_default ASYNC_NOC16_ULTRA_TRACE 0] eq "1"} {
  lappend compile_cmd -d ASYNC_NOC16_ULTRA_TRACE
  if {[getenv_default ASYNC_NOC16_ULTRA_TRACE_POST 0] eq "1"} {
    lappend compile_cmd -d ASYNC_NOC16_ULTRA_TRACE_POST
  }
}
set noc16_rtl_text [read_text_file $noc16_rtl]
if {[string first "io_debug_l1InputValid_0" $noc16_rtl_text] >= 0} {
  lappend compile_cmd -d ASYNC_NOC16_STAGE1_DEBUG_PORTS
}
lappend compile_cmd [unix_path $noc16_rtl]
# Ultra emits structural BlackBox resources adjacent to the selected top RTL.
# Include them conditionally so legacy NoC16 tops remain usable while the
# wrapper/TB itself stays architecture-neutral.
set ultra_resource_dir [file dirname $noc16_rtl]
foreach resource_name {UltraHeadCaptureCell.v AsyncRoundMembershipCell.v AsyncArbiterTransactionController.v AsyncRoundDecisionCell.v} {
  set resource_path [file join $ultra_resource_dir $resource_name]
  if {[file exists $resource_path]} {
    lappend compile_cmd [unix_path $resource_path]
  }
}
foreach source_path [async_primitive_sources $repo_root] {
  lappend compile_cmd [unix_path $source_path]
}
foreach source_path $tb_sources {
  lappend compile_cmd [unix_path $source_path]
}
if {![run_cmd $compile_cmd]} {
  exit 1
}

puts "Elaborating $top..."
set xelab_debug [getenv_default ASYNC_NOC16_XELAB_DEBUG typical]
set elab_cmd [concat $XELAB [list --timescale 1ns/1ps --debug $xelab_debug --snapshot $snapshot --log [unix_path $elab_log] work.$top]]
if {![run_cmd $elab_cmd]} {
  exit 1
}

set case_paths [lsort -dictionary [concat \
  [glob -nocomplain -types f [file join $case_root VCTM_16 *.case]] \
  [glob -nocomplain -types f [file join $case_root TAB_16 *.case]] \
  [glob -nocomplain -types f [file join $case_root *.case]]]]
set run_list {}
set csv_paths {}

foreach case_path $case_paths {
  set case_name [file rootname [file tail $case_path]]
  if {[llength $case_list] > 0 && [lsearch -exact $case_list $case_name] < 0} {
    continue
  }
  if {![string match $case_glob $case_name]} {
    continue
  }

  set group [file tail [file dirname $case_path]]
  if {![string match $group_glob $group]} {
    continue
  }
  set csv_path [csv_for_case $group $case_name]
  lappend run_list [list $case_path $csv_path]
  if {[lsearch -exact $csv_paths $csv_path] < 0} {
    lappend csv_paths $csv_path
  }
}

if {[llength $run_list] == 0} {
  puts "No async NoC16 cases matched ASYNC_NOC16_GROUP_GLOB=$group_glob ASYNC_NOC16_CASE_GLOB=$case_glob ASYNC_NOC16_CASE_LIST=$case_list"
  exit 1
}

if {$truncate_csv} {
  puts "Clearing CSV outputs..."
  foreach csv_path $csv_paths {
    truncate_file $csv_path
  }
}

set pass_count 0
set fail_count 0
set failed_cases {}

foreach item $run_list {
  set case_path [lindex $item 0]
  set csv_path [lindex $item 1]
  if {[run_case $case_path $csv_path]} {
    incr pass_count
  } else {
    incr fail_count
    lappend failed_cases [file rootname [file tail $case_path]]
    if {$stop_on_fail} {
      break
    }
  }
}

puts "Async NoC16 Vivado all-case simulation finished: pass=$pass_count fail=$fail_count"
if {$fail_count != 0} {
  puts "Failed cases: $failed_cases"
  exit 1
}

exit 0
