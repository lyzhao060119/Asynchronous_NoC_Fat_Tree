# Report post-route timing for synthesizable async primitives.
#
# Usage inside an opened routed Vivado design:
#   source scripts/async/report_async_primitive_timing.tcl
#
# Optional variables:
#   set async_report_dir reports/async

if {![info exists async_report_dir]} {
  set async_report_dir [file normalize "reports/async"]
}
file mkdir $async_report_dir

set delay_cells [get_cells -hier -quiet -filter {REF_NAME == LUT1 && NAME =~ *DelayUnit_delay*}]
set mutex_cells [get_cells -hier -quiet -filter {REF_NAME == LUT2 && (NAME =~ *q0_nand* || NAME =~ *q1_nand*)}]

set summary_path [file join $async_report_dir async_primitive_summary.csv]
set fd [open $summary_path w]
puts $fd "primitive,count,notes"
puts $fd "DelayElement_LUT1,[llength $delay_cells],post-route timing report required for per-chain values"
puts $fd "Mutex2_LUT2,[llength $mutex_cells],mutex resolution time must be characterized separately"
close $fd

proc async_delay_parent {cell_obj} {
  set cell_name [get_property NAME $cell_obj]
  if {[regexp {(.+)/DelayUnit_delay\[[0-9]+\]\.D0$} $cell_name -> parent]} {
    return $parent
  }
  return [file dirname $cell_name]
}

proc async_delay_index {cell_obj} {
  set cell_name [get_property NAME $cell_obj]
  if {[regexp {DelayUnit_delay\[([0-9]+)\]\.D0$} $cell_name -> idx]} {
    return $idx
  }
  return 0
}

proc async_delay_cell_compare {left right} {
  set left_idx [async_delay_index $left]
  set right_idx [async_delay_index $right]
  if {$left_idx < $right_idx} {
    return -1
  }
  if {$left_idx > $right_idx} {
    return 1
  }
  return [string compare [get_property NAME $left] [get_property NAME $right]]
}

proc async_safe_filename {name} {
  return [string map {"/" "_" "\\" "_" "[" "_" "]" "_" "." "_" ":" "_"} $name]
}

set delay_chain_csv [file join $async_report_dir delay_element_chains.csv]
set delay_fd [open $delay_chain_csv w]
puts $delay_fd "delay_instance,lut_count,start_pin,end_pin,timing_report,delay_calc_report,notes"

array unset delay_groups
foreach cell $delay_cells {
  set parent [async_delay_parent $cell]
  lappend delay_groups($parent) $cell
}

foreach parent [lsort -dictionary [array names delay_groups]] {
  set cells [lsort -command async_delay_cell_compare $delay_groups($parent)]
  set lut_count [llength $cells]
  set first_cell [lindex $cells 0]
  set last_cell [lindex $cells end]
  set first_name [get_property NAME $first_cell]
  set last_name [get_property NAME $last_cell]
  set start_pin [get_pins -quiet "${first_name}/I0"]
  set end_pin [get_pins -quiet "${last_name}/O"]
  set safe_name [async_safe_filename $parent]
  set timing_report [file join $async_report_dir "delay_chain_${safe_name}.rpt"]
  set delay_calc_report [file join $async_report_dir "delay_calc_${safe_name}.rpt"]
  set notes ""

  if {[llength $start_pin] == 0 || [llength $end_pin] == 0} {
    set notes "missing_start_or_end_pin"
    puts $delay_fd "\"$parent\",$lut_count,\"$start_pin\",\"$end_pin\",\"\",\"\",\"$notes\""
    continue
  }

  if {[catch {
    report_timing \
      -from $start_pin \
      -to $end_pin \
      -delay_type min_max \
      -max_paths 1 \
      -file $timing_report
  } timing_err]} {
    set notes "report_timing_failed:$timing_err"
  }

  if {[llength [info commands report_delay_calculation]] > 0} {
    if {[catch {
      report_delay_calculation \
        -from $start_pin \
        -to $end_pin \
        -file $delay_calc_report
    } delay_err]} {
      if {$notes eq ""} {
        set notes "report_delay_calculation_failed:$delay_err"
      } else {
        append notes ";report_delay_calculation_failed:$delay_err"
      }
    }
  } else {
    set delay_calc_report ""
    if {$notes eq ""} {
      set notes "report_delay_calculation_unavailable"
    } else {
      append notes ";report_delay_calculation_unavailable"
    }
  }

  puts $delay_fd "\"$parent\",$lut_count,\"$start_pin\",\"$end_pin\",\"$timing_report\",\"$delay_calc_report\",\"$notes\""
}
close $delay_fd

if {[llength $delay_cells] > 0} {
  report_timing \
    -through $delay_cells \
    -delay_type min_max \
    -max_paths 200 \
    -file [file join $async_report_dir delay_element_min_max_timing.rpt]
}

if {[llength $mutex_cells] > 0} {
  report_timing \
    -through $mutex_cells \
    -delay_type min_max \
    -max_paths 200 \
    -file [file join $async_report_dir mutex2_min_max_timing.rpt]
}

puts "Async primitive timing summary: $summary_path"
puts "Delay chain timing index: $delay_chain_csv"
