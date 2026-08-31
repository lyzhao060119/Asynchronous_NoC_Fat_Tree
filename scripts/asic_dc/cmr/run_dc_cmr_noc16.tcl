# CMR NoC16 DC entry: four L1 routers, one L2 router and eight depth-3
# inter-level asynchronous FIFOs.
set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID $::env(CMR_NOC16_RUN_ID)
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID"
set WORK_LIB "$PROJECT_DIR/work/dc_noc16_$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR
file mkdir $WORK_LIB

set expected_fifos 8
if {[info exists ::env(CMR_BYPASS_INTERLEVEL_FIFO)] && $::env(CMR_BYPASS_INTERLEVEL_FIFO) eq "1"} {
  set expected_fifos 0
}

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB

proc cmr_circular_fifo_count {} {
  set wcb [get_cells -hierarchical -quiet -filter {ref_name =~ WriteControlBlock*}]
  set n [sizeof_collection $wcb]
  if {$n == 0} {
    return 0
  }
  if {[expr {$n % 4}] != 0} {
    puts "CMR_NOC16_DC_FAIL circular_wcb_alignment wcb=$n"
    exit 2
  }
  return [expr {$n / 4}]
}

proc cmr_lib_cell {name} {
  set lib [get_lib_cells -quiet */$name]
  if {[sizeof_collection $lib] == 0} {
    return ""
  }
  return [get_object_name [index_collection $lib 0]]
}

proc cmr_rcu_delay_index {name} {
  if {[regexp {DelayUnit_delay\[([0-9]+)\]} $name -> idx]} {
    return $idx
  }
  return -1
}

proc cmr_rcu_matched_del150 {} {
  return [get_cells -hierarchical -quiet -filter {ref_name =~ DEL150D1* && full_name =~ *MatchedDelay*}]
}

proc cmr_rcu_steps_after {} {
  if {[info exists ::env(CMR_RCU_MATCHED_DELAY_STEPS)] && $::env(CMR_RCU_MATCHED_DELAY_STEPS) ne ""} {
    return $::env(CMR_RCU_MATCHED_DELAY_STEPS)
  }
  return 4
}

proc cmr_rcu_buf_stages {} {
  if {[info exists ::env(CMR_RCU_MATCHED_BUF_STAGES)] && $::env(CMR_RCU_MATCHED_BUF_STAGES) ne ""} {
    return $::env(CMR_RCU_MATCHED_BUF_STAGES)
  }
  return 0
}

proc cmr_rcu_matched_unit_ps {} {
  if {[info exists ::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)] && $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS) ne ""} {
    return $::env(CMR_RCU_MATCHED_DELAY_UNIT_PS)
  }
  return 150
}

proc cmr_opm_ackin_steps {} {
  if {[info exists ::env(CMR_OPM_ACKIN_DELAY_STEPS)] && $::env(CMR_OPM_ACKIN_DELAY_STEPS) ne ""} {
    return $::env(CMR_OPM_ACKIN_DELAY_STEPS)
  }
  return 1
}

proc cmr_opm_ackin_unit_ps {} {
  if {[info exists ::env(CMR_OPM_ACKIN_DELAY_UNIT_PS)] && $::env(CMR_OPM_ACKIN_DELAY_UNIT_PS) ne ""} {
    return $::env(CMR_OPM_ACKIN_DELAY_UNIT_PS)
  }
  return 250
}

proc cmr_opm_ackin_leaf_ref {unit} {
  switch -- $unit {
    50  { return DEL050D1BWP12T30P140 }
    75  { return DEL075D1BWP12T30P140 }
    100 { return DEL100D1BWP12T30P140 }
    150 { return DEL150D1BWP12T30P140 }
    250 { return DEL250D1BWP12T30P140 }
    default {
      puts "CMR_NOC16_DC_FAIL ackin_unit $unit"
      exit 2
    }
  }
}

proc cmr_opm_ackin_leaf_glob {unit} {
  switch -- $unit {
    50  { return "DEL050D1*" }
    75  { return "DEL075D1*" }
    100 { return "DEL100D1*" }
    150 { return "DEL150D1*" }
    250 { return "DEL250D1*" }
    default {
      puts "CMR_NOC16_DC_FAIL ackin_unit $unit"
      exit 2
    }
  }
}

proc cmr_opm_ackin_expected_de {} {
  if {[cmr_opm_ackin_steps] > 0} {
    return 25
  }
  return 0
}

proc cmr_opm_ackin_expected_leaf {} {
  return [expr {25 * [cmr_opm_ackin_steps]}]
}

proc cmr_opm_ackin_expected_del250 {} {
  if {[cmr_opm_ackin_unit_ps] == 250} {
    return [cmr_opm_ackin_expected_leaf]
  }
  return 0
}

proc cmr_opm_ackin_delay_elements {} {
  return [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement* && full_name =~ *AckinDelay*}]
}

proc cmr_opm_ackin_leaves {} {
  return [get_cells -hierarchical -quiet -filter {ref_name =~ DEL*D1* && full_name =~ *AckinDelay*}]
}

proc cmr_opm_e_max_ns {} {
  if {[info exists ::env(CMR_OPM_E_MAX_NS)] && $::env(CMR_OPM_E_MAX_NS) ne ""} {
    return $::env(CMR_OPM_E_MAX_NS)
  }
  return ""
}

proc cmr_del_shrink_cell_load_names {cell} {
  set name [get_object_name $cell]
  set z_pin [get_pins -quiet "$name/Z"]
  if {[sizeof_collection $z_pin] != 1} {
    puts "CMR_NOC16_DC_FAIL del_shrink_z_pin $name"
    exit 2
  }
  set z_net [get_nets -of_objects $z_pin]
  set loads [remove_from_collection [get_pins -of_objects $z_net] $z_pin]
  if {[sizeof_collection $loads] == 0} {
    puts "CMR_NOC16_DC_FAIL del_shrink_no_load $name"
    exit 2
  }
  set names {}
  foreach_in_collection p $loads {
    lappend names [get_object_name $p]
  }
  return $names
}

proc cmr_del_shrink_bypass {cell} {
  set name [get_object_name $cell]
  set_dont_touch $cell false
  set is_hier 0
  catch { set is_hier [get_attribute $cell is_hierarchical] }
  if {!$is_hier} {
    if {![catch {remove_buffer $cell} err]} {
      set still [get_cells -quiet $name]
      if {[sizeof_collection $still] == 0} {
        puts "CMR_DEL_SHRINK remove_buffer $name"
        return 1
      }
      puts "CMR_DEL_SHRINK remove_buffer_noop $name"
    }
  }
  set i_pin [get_pins -quiet "$name/I"]
  if {[sizeof_collection $i_pin] != 1} {
    set i_pin [get_pins -quiet "$name/io_I"]
  }
  set z_pin [get_pins -quiet "$name/Z"]
  if {[sizeof_collection $z_pin] != 1} {
    set z_pin [get_pins -quiet "$name/io_Z"]
  }
  if {[sizeof_collection $i_pin] != 1 || [sizeof_collection $z_pin] != 1} {
    puts "CMR_NOC16_DC_FAIL del_shrink_pins $name"
    exit 2
  }
  set i_net [get_nets -of_objects $i_pin]
  set z_net [get_nets -of_objects $z_pin]
  set loads [remove_from_collection [get_pins -of_objects $z_net] $z_pin]
  if {[sizeof_collection $loads] == 0} {
    puts "CMR_NOC16_DC_FAIL del_shrink_no_load $name"
    exit 2
  }
  disconnect_net $z_net $loads
  connect_net $i_net $loads
  if {[catch {remove_cell $cell} err]} {
    puts "CMR_NOC16_DC_FAIL del_shrink_remove_cell $name error=$err"
    exit 2
  }
  puts "CMR_DEL_SHRINK splice_remove $name"
  return 1
}

proc cmr_del_shrink_insert_bufs {load_names nbuf} {
  set lib_name [cmr_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL rcu_matched_missing_buffd0"
    exit 2
  }
  set inserted 0
  for {set stage 1} {$stage <= $nbuf} {incr stage} {
    foreach pin_name $load_names {
      set pin [get_pins -quiet $pin_name]
      if {[sizeof_collection $pin] != 1} {
        puts "CMR_NOC16_DC_FAIL rcu_matched_buf_pin $pin_name"
        exit 2
      }
      if {[catch {insert_buffer $pin $lib_name -new_cell_names rcu_matched_buf_s${stage}} err]} {
        puts "CMR_NOC16_DC_FAIL rcu_matched_buf_insert stage=$stage pin=$pin_name error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]
  set expected [expr {[llength $load_names] * $nbuf}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC16_DC_FAIL rcu_matched_buf_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  puts "CMR_DEL_SHRINK buf_inserts=$inserted stages=$nbuf loads=[llength $load_names] lib=$lib_name"
}

proc cmr_rcu_matched_leaves {} {
  set unit [cmr_rcu_matched_unit_ps]
  set glob [cmr_opm_ackin_leaf_glob $unit]
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *MatchedDelay*"]
}

proc cmr_noc16_insert_matched_bufs {nbuf} {
  if {$nbuf < 1} {
    puts "CMR_RCU_MATCHED_BUF skipped stages=0"
    return
  }
  set lib_name [cmr_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL rcu_matched_missing_buffd0"
    exit 2
  }
  set leaves [cmr_rcu_matched_leaves]
  set n [sizeof_collection $leaves]
  if {$n != 25} {
    puts "CMR_NOC16_DC_FAIL rcu_matched_leaf_before actual=$n expected=25 unit=[cmr_rcu_matched_unit_ps]"
    exit 2
  }
  set load_names {}
  foreach_in_collection c $leaves {
    set name [get_object_name $c]
    set z_pin [get_pins -quiet "$name/Z"]
    if {[sizeof_collection $z_pin] != 1} {
      puts "CMR_NOC16_DC_FAIL rcu_matched_z_pin $name"
      exit 2
    }
    set z_net [get_nets -of_objects $z_pin]
    set loads [remove_from_collection [get_pins -of_objects $z_net] $z_pin]
    if {[sizeof_collection $loads] == 0} {
      puts "CMR_NOC16_DC_FAIL rcu_matched_no_load $name"
      exit 2
    }
    foreach_in_collection p $loads {
      lappend load_names [get_object_name $p]
    }
  }
  if {[llength $load_names] != 25} {
    puts "CMR_NOC16_DC_FAIL rcu_matched_buf_loads actual=[llength $load_names] expected=25"
    exit 2
  }
  set inserted 0
  for {set stage 1} {$stage <= $nbuf} {incr stage} {
    foreach pin_name $load_names {
      set pin [get_pins -quiet $pin_name]
      if {[sizeof_collection $pin] != 1} {
        puts "CMR_NOC16_DC_FAIL rcu_matched_buf_pin $pin_name"
        exit 2
      }
      if {[catch {insert_buffer $pin $lib_name -new_cell_names rcu_matched_buf_s${stage}} err]} {
        puts "CMR_NOC16_DC_FAIL rcu_matched_buf_insert stage=$stage pin=$pin_name error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]
  set expected [expr {25 * $nbuf}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC16_DC_FAIL rcu_matched_buf_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  puts "CMR_RCU_MATCHED_BUF inserts=$inserted stages=$nbuf loads=[llength $load_names] lib=$lib_name"
}

proc cmr_del_shrink_remove_ackin {} {
  set wrappers [cmr_opm_ackin_delay_elements]
  set n [sizeof_collection $wrappers]
  if {$n != 25} {
    puts "CMR_NOC16_DC_FAIL del_shrink_ackin_count actual=$n expected=25"
    exit 2
  }
  foreach_in_collection w $wrappers {
    set name [get_object_name $w]
    set kids [get_cells -hierarchical -quiet -filter "full_name =~ $name/*"]
    if {[sizeof_collection $kids] > 0} {
      set_dont_touch $kids false
    }
    set_dont_touch $w false
    cmr_del_shrink_bypass $w
  }
  set left [sizeof_collection [cmr_opm_ackin_delay_elements]]
  set del250 [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL250D1* && full_name =~ *AckinDelay*}]]
  puts "CMR_DEL_SHRINK role=OPM_ACKIN removed=$n remaining_de=$left remaining_del250=$del250"
  if {$left != 0 || $del250 != 0} {
    puts "CMR_NOC16_DC_FAIL del_shrink_ackin_remaining de=$left del250=$del250"
    exit 2
  }
}

proc cmr_del_shrink_resize_ackin {} {
  set unit [cmr_opm_ackin_unit_ps]
  set ref [cmr_opm_ackin_leaf_ref $unit]
  set glob [cmr_opm_ackin_leaf_glob $unit]
  set lib_name [cmr_lib_cell $ref]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL ackin_resize_missing_lib $ref"
    exit 2
  }
  set wrappers [cmr_opm_ackin_delay_elements]
  if {[sizeof_collection $wrappers] != 25} {
    puts "CMR_NOC16_DC_FAIL del_shrink_ackin_count actual=[sizeof_collection $wrappers] expected=25"
    exit 2
  }
  set leaves [cmr_opm_ackin_leaves]
  set n [sizeof_collection $leaves]
  if {$n != 25} {
    puts "CMR_NOC16_DC_FAIL del_shrink_ackin_leaf_count actual=$n expected=25"
    exit 2
  }
  set_dont_touch $wrappers false
  set_dont_touch $leaves false
  set resized 0
  foreach_in_collection c $leaves {
    set name [get_object_name $c]
    set cur [get_attribute $c ref_name]
    if {[string match $glob $cur]} {
      continue
    }
    if {[catch {size_cell $c $lib_name} err]} {
      puts "CMR_NOC16_DC_FAIL ackin_size_cell $name from=$cur to=$lib_name error=$err"
      exit 2
    }
    incr resized
    puts "CMR_DEL_SHRINK size_cell $name $cur -> $lib_name"
  }
  set after [sizeof_collection [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *AckinDelay*"]]
  set left [sizeof_collection [cmr_opm_ackin_leaves]]
  set_dont_touch [cmr_opm_ackin_leaves] true
  set_dont_touch [cmr_opm_ackin_delay_elements] true
  puts "CMR_DEL_SHRINK role=OPM_ACKIN_RESIZE unit=$unit target=$ref resized=$resized after=$after leaves=$left"
  if {$after != 25 || $left != 25} {
    puts "CMR_NOC16_DC_FAIL ackin_resize_after actual=$after leaves=$left expected=25"
    exit 2
  }
}

proc cmr_opm_e_net_buf_count {} {
  set n 0
  set e_pins [get_pins -hierarchical -quiet -filter {
    full_name =~ *OutputPortModules_*/DataReg/resettable_latch*.latch_cell/E ||
    full_name =~ *OutputPortModules_*/L5/resettable_latch*.latch_cell/E
  }]
  if {[sizeof_collection $e_pins] == 0} {
    return -1
  }
  set nets [get_nets -of_objects $e_pins]
  set pins [get_pins -of_objects $nets]
  foreach_in_collection p $pins {
    set dir [get_attribute $p direction]
    if {$dir ne "out"} {
      continue
    }
    set c [get_cells -of_objects $p]
    if {[sizeof_collection $c] != 1} {
      continue
    }
    set ref [get_attribute $c ref_name]
    if {[string match "BUFF*" $ref] || [string match "CKBD*" $ref] || [string match "DEL*" $ref]} {
      incr n
      puts "CMR_OPM_E_BUF cell=[get_object_name $c] ref=$ref pin=[get_object_name $p]"
    }
  }
  return $n
}

proc cmr_rcu_matched_leaves_by_glob {glob} {
  return [get_cells -hierarchical -quiet -filter "ref_name =~ $glob && full_name =~ *MatchedDelay*"]
}

proc cmr_del_shrink_resize_rcu_matched {unit} {
  if {$unit != 50} {
    puts "CMR_NOC16_DC_FAIL rcu_resize_unit $unit"
    exit 2
  }
  set ref [cmr_opm_ackin_leaf_ref $unit]
  set glob [cmr_opm_ackin_leaf_glob $unit]
  set lib_name [cmr_lib_cell $ref]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL rcu_resize_missing_lib $ref"
    exit 2
  }
  set leaves [cmr_rcu_matched_del150]
  set n [sizeof_collection $leaves]
  if {$n != 25} {
    puts "CMR_NOC16_DC_FAIL rcu_resize_before actual=$n expected=25"
    exit 2
  }
  set wrappers [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement* && full_name =~ *MatchedDelay*}]
  set_dont_touch $wrappers false
  set_dont_touch $leaves false
  set resized 0
  foreach_in_collection c $leaves {
    set name [get_object_name $c]
    set cur [get_attribute $c ref_name]
    if {[string match $glob $cur]} {
      continue
    }
    if {[catch {size_cell $c $lib_name} err]} {
      puts "CMR_NOC16_DC_FAIL rcu_size_cell $name from=$cur to=$lib_name error=$err"
      exit 2
    }
    incr resized
    puts "CMR_DEL_SHRINK size_cell $name $cur -> $lib_name"
  }
  set after [sizeof_collection [cmr_rcu_matched_leaves_by_glob $glob]]
  set left [sizeof_collection [cmr_rcu_matched_del150]]
  set_dont_touch [cmr_rcu_matched_leaves_by_glob $glob] true
  set_dont_touch $wrappers true
  puts "CMR_DEL_SHRINK role=RCU_SIZE_TO_DEL050 unit=$unit target=$ref resized=$resized after=$after remaining_del150=$left"
  if {$after != 25 || $left != 0} {
    puts "CMR_NOC16_DC_FAIL rcu_resize_after actual=$after remaining_del150=$left expected=25/0"
    exit 2
  }
}

proc cmr_rcu_matched_buf_stage {stage} {
  set glob "*rcu_matched_buf_s${stage}*"
  set later "*rcu_matched_buf_s${stage}\[0-9]*"
  return [get_cells -hierarchical -quiet -filter "full_name =~ $glob && full_name !~ $later"]
}

proc cmr_del_shrink_add_rcu_bufs {target} {
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]
  set n [sizeof_collection $cells]
  if {$n == 0} {
    cmr_noc16_insert_matched_bufs $target
    return
  }
  if {[expr {$n % 25}] != 0} {
    puts "CMR_NOC16_DC_FAIL rcu_add_buf_mod actual=$n"
    exit 2
  }
  set current [expr {$n / 25}]
  if {$target <= $current} {
    puts "CMR_NOC16_DC_FAIL rcu_add_keep target=$target current=$current"
    exit 2
  }
  set last [cmr_rcu_matched_buf_stage $current]
  if {[sizeof_collection $last] != 25} {
    puts "CMR_NOC16_DC_FAIL rcu_add_last_stage stage=$current actual=[sizeof_collection $last]"
    exit 2
  }
  set_dont_touch $cells false
  set load_names {}
  foreach_in_collection c $last {
    set name [get_object_name $c]
    set z_pin [get_pins -quiet "$name/Z"]
    if {[sizeof_collection $z_pin] != 1} {
      puts "CMR_NOC16_DC_FAIL rcu_add_z_pin $name"
      exit 2
    }
    set z_net [get_nets -of_objects $z_pin]
    set loads [remove_from_collection [get_pins -of_objects $z_net] $z_pin]
    if {[sizeof_collection $loads] == 0} {
      puts "CMR_NOC16_DC_FAIL rcu_add_no_load $name"
      exit 2
    }
    foreach_in_collection p $loads {
      lappend load_names [get_object_name $p]
    }
  }
  if {[llength $load_names] != 25} {
    puts "CMR_NOC16_DC_FAIL rcu_add_loads actual=[llength $load_names] expected=25"
    exit 2
  }
  set lib_name [cmr_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL rcu_add_missing_buffd0"
    exit 2
  }
  set inserted 0
  for {set stage [expr {$current + 1}]} {$stage <= $target} {incr stage} {
    foreach pin_name $load_names {
      set pin [get_pins -quiet $pin_name]
      if {[sizeof_collection $pin] != 1} {
        puts "CMR_NOC16_DC_FAIL rcu_add_buf_pin $pin_name"
        exit 2
      }
      if {[catch {insert_buffer $pin $lib_name -new_cell_names rcu_matched_buf_s${stage}} err]} {
        puts "CMR_NOC16_DC_FAIL rcu_add_insert stage=$stage pin=$pin_name error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set left [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]]
  set expected [expr {25 * $target}]
  if {$left != $expected} {
    puts "CMR_NOC16_DC_FAIL rcu_add_after actual=$left expected=$expected inserted=$inserted"
    exit 2
  }
  set_dont_touch [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}] true
  puts "CMR_DEL_SHRINK role=RCU_ADD_BUF inserted=$inserted from=$current keep=$target left=$left"
}

proc cmr_del_shrink_trim_rcu_bufs {keep_stages} {
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]
  set n [sizeof_collection $cells]
  if {$n == 0} {
    puts "CMR_NOC16_DC_FAIL rcu_trim_no_bufs"
    exit 2
  }
  if {[expr {$n % 25}] != 0} {
    puts "CMR_NOC16_DC_FAIL rcu_trim_buf_mod actual=$n"
    exit 2
  }
  set current [expr {$n / 25}]
  if {$keep_stages < 0 || $keep_stages >= $current} {
    puts "CMR_NOC16_DC_FAIL rcu_trim_keep keep=$keep_stages current=$current"
    exit 2
  }
  set_dont_touch $cells false
  set removed 0
  for {set stage $current} {$stage > $keep_stages} {incr stage -1} {
    set batch [cmr_rcu_matched_buf_stage $stage]
    if {[sizeof_collection $batch] != 25} {
      puts "CMR_NOC16_DC_FAIL rcu_trim_stage stage=$stage actual=[sizeof_collection $batch]"
      exit 2
    }
    foreach_in_collection c $batch {
      set name [get_object_name $c]
      if {[catch {remove_buffer $c} err]} {
        puts "CMR_NOC16_DC_FAIL rcu_trim_remove $name error=$err"
        exit 2
      }
      incr removed
    }
  }
  set left [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]]
  set expected [expr {25 * $keep_stages}]
  if {$left != $expected} {
    puts "CMR_NOC16_DC_FAIL rcu_trim_after actual=$left expected=$expected removed=$removed"
    exit 2
  }
  if {$left > 0} {
    set_dont_touch [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}] true
  }
  puts "CMR_DEL_SHRINK role=RCU_TRIM_BUF removed=$removed keep=$keep_stages left=$left"
}

proc cmr_del_shrink_role {role} {
  set role [string toupper $role]
  if {$role eq "NONE" || $role eq ""} {
    puts "CMR_DEL_SHRINK skipped role=$role"
    return
  }
  if {$role eq "OPM_ACKIN"} {
    cmr_del_shrink_remove_ackin
    return
  }
  if {$role eq "OPM_ACKIN_RESIZE"} {
    cmr_del_shrink_resize_ackin
    return
  }
  if {$role eq "RCU_SIZE_TO_DEL050"} {
    cmr_del_shrink_resize_rcu_matched 50
    return
  }
  if {$role eq "RCU_TRIM_BUF"} {
    cmr_del_shrink_trim_rcu_bufs [cmr_rcu_buf_stages]
    return
  }
  if {$role eq "RCU_ADD_BUF"} {
    cmr_del_shrink_add_rcu_bufs [cmr_rcu_buf_stages]
    return
  }
  if {$role ne "RCU_DEL150" && $role ne "RCU_DEL150_TO_BUF"} {
    puts "CMR_NOC16_DC_FAIL del_shrink_unsupported_role $role"
    exit 2
  }
  set steps_after [cmr_rcu_steps_after]
  set nbuf [cmr_rcu_buf_stages]
  if {$role eq "RCU_DEL150_TO_BUF" && $nbuf < 1} {
    puts "CMR_NOC16_DC_FAIL del_shrink_buf_stages nbuf=$nbuf"
    exit 2
  }
  set matched [cmr_rcu_matched_del150]
  set before [sizeof_collection $matched]
  set expected_before [expr {25 * ($steps_after + 1)}]
  if {$before != $expected_before} {
    puts "CMR_NOC16_DC_FAIL del_shrink_before actual=$before expected=$expected_before steps_after=$steps_after"
    exit 2
  }
  set hi -1
  foreach_in_collection c $matched {
    set idx [cmr_rcu_delay_index [get_object_name $c]]
    if {$idx > $hi} {
      set hi $idx
    }
  }
  if {$hi < 0} {
    puts "CMR_NOC16_DC_FAIL del_shrink_no_delay_index"
    exit 2
  }
  set cells ""
  set n 0
  foreach_in_collection c $matched {
    if {[cmr_rcu_delay_index [get_object_name $c]] == $hi} {
      if {$n == 0} {
        set cells $c
      } else {
        set cells [add_to_collection $cells $c]
      }
      incr n
    }
  }
  if {$n != 25} {
    puts "CMR_NOC16_DC_FAIL del_shrink_rcu_tail_count actual=$n expected=25 index=$hi"
    exit 2
  }
  set load_names {}
  foreach_in_collection c $cells {
    if {$role eq "RCU_DEL150_TO_BUF"} {
      set load_names [concat $load_names [cmr_del_shrink_cell_load_names $c]]
    }
    cmr_del_shrink_bypass $c
  }
  if {$role eq "RCU_DEL150_TO_BUF"} {
    if {[llength $load_names] != 25} {
      puts "CMR_NOC16_DC_FAIL rcu_matched_buf_loads actual=[llength $load_names] expected=25"
      exit 2
    }
    cmr_del_shrink_insert_bufs $load_names $nbuf
  }
  set left [sizeof_collection [cmr_rcu_matched_del150]]
  set expected_left [expr {25 * $steps_after}]
  puts "CMR_DEL_SHRINK role=$role removed=$n index=$hi remaining_rcu_del150=$left expected=$expected_left buf_stages=$nbuf"
  if {$left != $expected_left} {
    puts "CMR_NOC16_DC_FAIL del_shrink_remaining actual=$left expected=$expected_left"
    exit 2
  }
}

set incremental_mode 0
if {[info exists ::env(CMR_DATAPATH_SEED_DDC)] && $::env(CMR_DATAPATH_SEED_DDC) ne ""} {
  set incremental_mode 1
}

if {$incremental_mode} {
  # Step D/E/F/G incremental: start from a frozen mapped NoC16 DDC.  Do not
  # re-elaborate RTL.  Step D sizes Address/Mat, OPM Mux1H and FIFO data
  # cones.  Step E adds control min/max for one RTC class at RTM 0%.
  # Step F reapplies those windows at RTM 5% (CMR-OUTER-RTM5).  Step G
  # sources the link overlay after inner: data max-delay, then Req
  # min-delay, then Ack-return as a separate class.  A later F shrink
  # knife may drop the highest remaining MatchedDelay DEL150, replace
  # that tail cell with BUFFD0, size_cell OPM AckinDelay leaves,
  # splice-remove OPM AckinDelay, or apply L5.Q→DataReg.E max-delay,
  # before compile.
  set SEED_DDC $::env(CMR_DATAPATH_SEED_DDC)
  if {![file exists $SEED_DDC]} {
    puts "CMR_NOC16_DC_FAIL missing_datapath_seed=$SEED_DDC"
    exit 2
  }
  read_ddc $SEED_DDC
  current_design NoC_16nodes
  link
  puts "CMR_DATAPATH_INCREMENTAL seed=$SEED_DDC"
} else {
  analyze -format verilog -define ASIC_T28 -work WORK [list \
    "$RTL_DIR/DelayElement_ASIC.v" \
    "$RTL_DIR/Mutex2_ASIC.v" \
    "$RTL_DIR/Mutex4.v" \
    "$RTL_DIR/MullerC2.v" \
    "$RTL_DIR/CMRFlattenedTAC.v" \
    "$RTL_DIR/CMRMutexN.v" \
    "$RTL_DIR/DLatchBank.v" \
    "$RTL_DIR/V2CloseEvent.v" \
    "$RTL_DIR/Toggle.v" \
    "$RTL_DIR/HeadPredictor.v" \
    "$RTL_DIR/PhaseSelector.v" \
    "$RTL_DIR/AddressRegisterUnit.v" \
    "$RTL_DIR/InternalAckModule.v" \
    "$RTL_DIR/RouteSelAnd2.v" \
    "$RTL_DIR/OPMSelector.v" \
    "$RTL_DIR/PhaseResetDLatch.v" \
    "$RTL_DIR/WriteControlUnit.v" \
    "$RTL_DIR/WriteCounter.v" \
    "$RTL_DIR/WriteAckGenerator.v" \
    "$RTL_DIR/ReadControlUnit.v" \
    "$RTL_DIR/ReadCounter.v" \
    "$RTL_DIR/ReadRequestGenerator.v" \
    "$RTL_DIR/ReadPhaseSelector.v" \
    "$RTL_DIR/ReadAckGenerator.v" \
    "$RTL_DIR/WriteControlBlock.v" \
    "$RTL_DIR/ReadControlBlock.v" \
    "$RTL_DIR/CircularWriteCounter.v" \
    "$RTL_DIR/CircularReadCounter.v" \
    "$RTL_DIR/CircularFIFO.v" \
    "$RTL_DIR/NoC_16nodes.v"]
  elaborate NoC_16nodes -work WORK
  current_design NoC_16nodes
  uniquify
  link
}
check_design > "$REPORT_DIR/check_design_pre.rpt"

set sr_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCSNDQD*}]
set clear_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set set_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]
set sr_pre_count [sizeof_collection $sr_pre]
set clear_pre_count [sizeof_collection $clear_pre]
set set_pre_count [sizeof_collection $set_pre]
set expected_path_latches 100
set adapter_pre [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]
set adapter_pre_count [sizeof_collection $adapter_pre]
if {$adapter_pre_count != 0} {
  puts "CMR_NOC16_DC_FAIL unexpected_lane_phase_adapter count=$adapter_pre_count"
  exit 2
}
set path_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]
set selector_dual_pre [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]
set path_pre_count [sizeof_collection $path_pre]
set selector_dual_pre_count [sizeof_collection $selector_dual_pre]
set non_path_clear_pre_count [expr {$clear_pre_count - $path_pre_count}]
set circular_fifo_count [cmr_circular_fifo_count]
# Four-slot CircularFIFO adds 118 LHCNDQD and 6 LHSNDQD per instance
# (112 data + 6 control-clear; 6 control-set). AsyncFifo chain adds none.
set expected_non_path_clear [expr {5625 + 118 * $circular_fifo_count}]
set expected_set [expr {450 + 6 * $circular_fifo_count}]
puts "CMR_NOC16_LATCH_PRE CLEAR=$clear_pre_count SET=$set_pre_count SR=$sr_pre_count PATH_CLEAR=$path_pre_count PATH_DUAL=$selector_dual_pre_count CIRCULAR_FIFO=$circular_fifo_count EXPECTED_CLEAR=$expected_non_path_clear EXPECTED_SET=$expected_set"
if {$path_pre_count != $expected_path_latches || $selector_dual_pre_count != 0 || $non_path_clear_pre_count != $expected_non_path_clear || $set_pre_count != $expected_set} {
  puts "CMR_NOC16_DC_FAIL latch_pre_structure"
  exit 2
}
set_dont_touch $clear_pre true
set_dont_touch $set_pre true

source "$RTL_DIR/async_primitives.tcl"
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
if {$incremental_mode} {
  if {![info exists ::env(CMR_DATAPATH_OVERLAY)] || $::env(CMR_DATAPATH_OVERLAY) eq "" ||
      ![file exists $::env(CMR_DATAPATH_OVERLAY)]} {
    puts "CMR_NOC16_DC_FAIL missing_datapath_overlay"
    exit 2
  }
  source $::env(CMR_DATAPATH_OVERLAY)
  if {[info exists ::env(CMR_INNER_OVERLAY)] && $::env(CMR_INNER_OVERLAY) ne ""} {
    if {![file exists $::env(CMR_INNER_OVERLAY)]} {
      puts "CMR_NOC16_DC_FAIL missing_inner_overlay"
      exit 2
    }
    puts "CMR_INNER_SOURCE overlay=$::env(CMR_INNER_OVERLAY)"
    source $::env(CMR_INNER_OVERLAY)
  }
  if {[info exists ::env(CMR_LINK_OVERLAY)] && $::env(CMR_LINK_OVERLAY) ne ""} {
    if {![file exists $::env(CMR_LINK_OVERLAY)]} {
      puts "CMR_NOC16_DC_FAIL missing_link_overlay"
      exit 2
    }
    puts "CMR_LINK_SOURCE overlay=$::env(CMR_LINK_OVERLAY)"
    source $::env(CMR_LINK_OVERLAY)
  }
  if {[info exists ::env(CMR_DEL_SHRINK_ROLE)] && $::env(CMR_DEL_SHRINK_ROLE) ne ""} {
    cmr_del_shrink_role $::env(CMR_DEL_SHRINK_ROLE)
  }
  compile_ultra -incremental -no_autoungroup
  set e_max [cmr_opm_e_max_ns]
  if {$e_max ne ""} {
    set e_buf [cmr_opm_e_net_buf_count]
    puts "CMR_OPM_E_BUF_COUNT=$e_buf max_ns=$e_max"
    if {$e_buf != 0} {
      puts "CMR_NOC16_DC_FAIL opm_e_buffers count=$e_buf"
      exit 2
    }
  }
} else {
  compile_ultra -no_autoungroup
}

proc cmr_wp_lib_cell {name} {
  return [cmr_lib_cell $name]
}

proc cmr_wp_insert_req_del250 {} {
  set lib_name [cmr_wp_lib_cell DEL250D1BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL wp_missing_del250_lib"
    exit 2
  }
  set reqs [get_pins -hierarchical -quiet -filter {full_name =~ *WriteInterface*Counter*/Reqin}]
  if {[sizeof_collection $reqs] != 25} {
    puts "CMR_NOC16_DC_FAIL wp_req_bind [sizeof_collection $reqs]"
    exit 2
  }
  set n 0
  foreach_in_collection req $reqs {
    if {[catch {insert_buffer $req $lib_name -new_cell_names wp_hs02_req_dly} err]} {
      puts "CMR_NOC16_DC_FAIL wp_insert_buffer [get_object_name $req] $err"
      exit 2
    }
    incr n
  }
  set dly [get_cells -hierarchical -quiet -filter {full_name =~ *wp_hs02_req_dly*}]
  puts "CMR_WP_REQ_DEL250 inserts=$n cells=[sizeof_collection $dly] lib=$lib_name"
  if {$n != 25 || [sizeof_collection $dly] != 25} {
    puts "CMR_NOC16_DC_FAIL wp_del250_count inserts=$n cells=[sizeof_collection $dly]"
    exit 2
  }
  foreach_in_collection d $dly {
    set i_pin [get_pins -of_objects $d -filter {name == I}]
    set z_pin [get_pins -of_objects $d -filter {name == Z}]
    set i_net [get_object_name [get_nets -of_objects $i_pin]]
    if {![regexp {Reqin} $i_net] || [regexp {Ackout} $i_net]} {
      puts "CMR_NOC16_DC_FAIL wp_del250_not_reqin cell=[get_object_name $d] i_net=$i_net"
      exit 2
    }
    set z_sinks [all_fanout -from $z_pin -flat -endpoints_only]
    foreach_in_collection s $z_sinks {
      set sn [get_object_name $s]
      if {[regexp {CellFull} $sn]} {
        puts "CMR_NOC16_DC_FAIL wp_del250_hits_cellfull $sn"
        exit 2
      }
    }
  }
  set_dont_touch $dly true
}

# Historical CMR-HS-02 experiment.  A Reqin-only delay at WriteCounter does
# not preserve the Fig. 7 input bundle and did not remove the Thin SDF
# failure.  Keep it available for controlled comparison only; a normal DC run
# must be a clean RTL baseline.
set wp_req_del250_enable 0
if {[info exists ::env(CMR_WP_REQ_DEL250_ENABLE)] && $::env(CMR_WP_REQ_DEL250_ENABLE) eq "1"} {
  set wp_req_del250_enable 1
}
if {$wp_req_del250_enable && !$incremental_mode} {
  cmr_wp_insert_req_del250
} else {
  puts "CMR_WP_REQ_DEL250 disabled (clean baseline)"
}

# CMR-CFIFO-04.  The standalone CircularFIFO strict-SDF qualification closed
# TCF-HS-02 with a three-BUFFD0 local chain on only the Ackin -> ReadCounter
# XNOR A1 leg.  Replicate that *qualified physical ECO* for every inter-level
# CircularFIFO.  It intentionally does not touch the Ackin fanout to the RCB
# EmptyLatches, and it is absent whenever the ACG FIFO implementation is used.
proc cmr_cfifo_insert_hs02_ack_counter_buffers {} {
  set circular [cmr_circular_fifo_count]
  if {$circular == 0} {
    puts "CMR_CFIFO_HS02 disabled (no CircularFIFO)"
    return
  }
  if {$circular != 8} {
    puts "CMR_NOC16_DC_FAIL cfifo_hs02_fifo_count actual=$circular expected=8"
    exit 2
  }
  set targets [get_pins -hierarchical -quiet -filter {full_name =~ *read_counter/U10/A1}]
  if {[sizeof_collection $targets] != $circular} {
    puts "CMR_NOC16_DC_FAIL cfifo_hs02_bind actual=[sizeof_collection $targets] expected=$circular"
    exit 2
  }
  set lib_name [cmr_wp_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL cfifo_hs02_missing_buffd0"
    exit 2
  }
  set inserted 0
  for {set stage 1} {$stage <= 3} {incr stage} {
    foreach_in_collection target $targets {
      if {[catch {insert_buffer $target $lib_name -new_cell_names cfifo_hs02_ack_counter_buf_s${stage}} err]} {
        puts "CMR_NOC16_DC_FAIL cfifo_hs02_insert stage=$stage pin=[get_object_name $target] error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_hs02_ack_counter_buf_s*}]
  set expected [expr {$circular * 3}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC16_DC_FAIL cfifo_hs02_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  puts "CMR_CFIFO_HS02 buffers=[sizeof_collection $cells] stages=3 fifos=$circular lib=$lib_name"
}

if {!$incremental_mode} {
  cmr_cfifo_insert_hs02_ack_counter_buffers
  cmr_noc16_insert_matched_bufs [cmr_rcu_buf_stages]
} else {
  puts "CMR_DATAPATH_SKIP_ECO cfifo_hs02"
}

# CMR-CFIFO-RD-01.  Preserve the unit-qualified Transition Fig. 6 bundled
# data relation at every CircularFifo boundary: the selected slot data must
# cross the internal output mux before its CellReq contribution may emerge at
# bb/Reqout.  The final XOR inputs are an isolated copy of CellReq, so this
# ECO deliberately leaves the RCB Req -> EmptyEnable/EmptyLatch feedback
# topology intact.
proc cmr_cfifo_apply_rd01_constraints {report_dir} {
  set circular [cmr_circular_fifo_count]
  if {$circular == 0} {
    set ::CMR_CFIFO_RD01_REQUIRED 0.0
    set ::CMR_CFIFO_RD01_MAXIMUM 0.0
    puts "CMR_CFIFO_RD01 disabled (no CircularFIFO)"
    return
  }
  # Chisel preserves the Verilog generate index as slot[0], slot[1], ... .
  # Brackets are glob metacharacters in a DC filter, so bind through the
  # enclosing CircularFifo bb instance rather than attempting to glob slot*.
  set data_q [get_pins -hierarchical -quiet -filter {full_name =~ *bb*data_reg* && name == Q}]
  set data_out [get_pins -hierarchical -quiet -filter {full_name =~ *bb/Data_out*}]
  set req_q [get_pins -hierarchical -quiet -filter {full_name =~ *bb*ReqLatch/q}]
  set reqout [get_pins -hierarchical -quiet -filter {full_name =~ *bb/Reqout}]
  set expected_data [expr {$circular * 112}]
  set expected_dout [expr {$circular * 28}]
  set expected_req [expr {$circular * 4}]
  if {[sizeof_collection $data_q] != $expected_data ||
      [sizeof_collection $data_out] != $expected_dout ||
      [sizeof_collection $req_q] != $expected_req ||
      [sizeof_collection $reqout] != $circular} {
    puts "CMR_NOC16_DC_FAIL cfifo_rd01_bind data_q=[sizeof_collection $data_q] data_out=[sizeof_collection $data_out] req_q=[sizeof_collection $req_q] reqout=[sizeof_collection $reqout]"
    exit 2
  }
  set data_paths [get_timing_paths -from $data_q -to $data_out -delay_type max -max_paths 32]
  if {[sizeof_collection $data_paths] == 0} {
    puts "CMR_NOC16_DC_FAIL cfifo_rd01_no_data_path"
    exit 2
  }
  set tdata 0.0
  foreach_in_collection p $data_paths {
    set arrival [get_attribute $p arrival]
    if {$arrival > $tdata} { set tdata $arrival }
  }
  set required [expr {$tdata * 1.10}]
  set maximum [expr {$required + 0.100}]
  set_min_delay $required -from $req_q -to $reqout
  set_max_delay $maximum -from $req_q -to $reqout
  set ::CMR_CFIFO_RD01_TDATA $tdata
  set ::CMR_CFIFO_RD01_REQUIRED $required
  set ::CMR_CFIFO_RD01_MAXIMUM $maximum
  report_timing -from $data_q -to $data_out -delay_type max -max_paths 32 > "$report_dir/cfifo_rd01_data_max_pre.rpt"
  report_timing -from $req_q -to $reqout -delay_type min -max_paths 32 > "$report_dir/cfifo_rd01_control_min_pre.rpt"
  puts [format "CMR_CFIFO_RD01_PRE data_max_ns=%.6f required_min_ns=%.6f maximum_ns=%.6f fifos=%d" $tdata $required $maximum $circular]
}

proc cmr_cfifo_insert_rd01_reqout_buffers {} {
  set circular [cmr_circular_fifo_count]
  if {$circular == 0} { return }
  # U2 is the mapped XOR4 (CellReq[3:0] -> Reqout), verified in the
  # qualifying unit netlist.  Its A pins occur once per CellReq branch.
  set targets [get_pins -hierarchical -quiet -filter {full_name =~ *bb/U2/A*}]
  set expected_targets [expr {$circular * 4}]
  if {[sizeof_collection $targets] != $expected_targets} {
    puts "CMR_NOC16_DC_FAIL cfifo_rd01_xor_bind actual=[sizeof_collection $targets] expected=$expected_targets"
    exit 2
  }
  set lib_name [cmr_wp_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL cfifo_rd01_missing_buffd0"
    exit 2
  }
  # NoC post-map measurement is intentionally authoritative here: its
  # SlotData->bb.Data_out path is 295.973 ps, so the 10% RTM target is
  # 325.570 ps.  Fourteen stages reached 306.142 ps; add two symmetric
  # stages to close the measured 19.428 ps deficit while preserving the
  # 425.570 ps max-delay cap.
  set stages 16
  set inserted 0
  for {set stage 1} {$stage <= $stages} {incr stage} {
    foreach_in_collection target $targets {
      if {[catch {insert_buffer $target $lib_name -new_cell_names cfifo_rd01_reqout_buf_s${stage}} err]} {
        puts "CMR_NOC16_DC_FAIL cfifo_rd01_insert stage=$stage pin=[get_object_name $target] error=$err"
        exit 2
      }
      incr inserted
    }
  }
  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_rd01_reqout_buf_s*}]
  set expected [expr {$expected_targets * $stages}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC16_DC_FAIL cfifo_rd01_buffer_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true
  set ::CMR_CFIFO_RD01_STAGES $stages
  puts "CMR_CFIFO_RD01_ECO buffers=[sizeof_collection $cells] stages=$stages fifos=$circular lib=$lib_name"
}

proc cmr_cfifo_report_rd01 {report_dir} {
  set circular [cmr_circular_fifo_count]
  if {$circular == 0} { return }
  set req_q [get_pins -hierarchical -quiet -filter {full_name =~ *bb*ReqLatch/q}]
  set reqout [get_pins -hierarchical -quiet -filter {full_name =~ *bb/Reqout}]
  set paths [get_timing_paths -from $req_q -to $reqout -delay_type min -max_paths 32]
  set tctrl 1.0e9
  foreach_in_collection p $paths {
    set arrival [get_attribute $p arrival]
    if {$arrival < $tctrl} { set tctrl $arrival }
  }
  set slack [expr {$tctrl - $::CMR_CFIFO_RD01_REQUIRED}]
  report_timing -from $req_q -to $reqout -delay_type min -max_paths 32 > "$report_dir/cfifo_rd01_control_min_post.rpt"
  set fd [open "$report_dir/cfifo_rd01.json" w]
  puts $fd "{"
  puts $fd [format "  \"constraint\": \"TCF-RD-01\","]
  puts $fd [format "  \"fifo_data_max_ns\": %.6f," $::CMR_CFIFO_RD01_TDATA]
  puts $fd "  \"rtm\": 0.10,"
  puts $fd [format "  \"control_required_min_ns\": %.6f," $::CMR_CFIFO_RD01_REQUIRED]
  puts $fd [format "  \"control_max_ns\": %.6f," $::CMR_CFIFO_RD01_MAXIMUM]
  puts $fd [format "  \"control_min_ns\": %.6f," $tctrl]
  puts $fd [format "  \"buffer_stages_per_branch\": %d," $::CMR_CFIFO_RD01_STAGES]
  puts $fd [format "  \"buffer_count\": %d," [expr {$circular * 4 * $::CMR_CFIFO_RD01_STAGES}]]
  puts $fd [format "  \"slack_ns\": %.6f" $slack]
  puts $fd "}"
  close $fd
  puts [format "CMR_CFIFO_RD01_POST control_min_ns=%.6f required_min_ns=%.6f slack_ns=%.6f" $tctrl $::CMR_CFIFO_RD01_REQUIRED $slack]
  if {$slack < 0.0} {
    puts "CMR_NOC16_DC_FAIL cfifo_rd01_unmet"
    exit 2
  }
}

if {!$incremental_mode} {
  cmr_cfifo_apply_rd01_constraints $REPORT_DIR
  cmr_cfifo_insert_rd01_reqout_buffers
  compile_ultra -incremental -no_autoungroup
  cmr_cfifo_report_rd01 $REPORT_DIR
} else {
  puts "CMR_DATAPATH_SKIP_ECO cfifo_rd01_and_second_compile"
  if {[info commands cmr_dp_report_tdata] ne ""} {
    cmr_dp_report_tdata "$REPORT_DIR/datapath_constraint_pairs.rpt"
  }
  if {[info commands cmr_inner_report] ne ""} {
    cmr_inner_report "$REPORT_DIR/inner_constraint_pairs.rpt"
  }
  if {[info commands cmr_link_report] ne ""} {
    cmr_link_report "$REPORT_DIR/link_constraint_pairs.rpt"
  }
  report_constraint -all_violators > "$REPORT_DIR/datapath_constraints_postcompile.rpt"
}

# CMR-HS-01 experimental branch-delay study.  It is deliberately opt-in: the
# Head/Tail-only form separates those flags from the undelayed address/Reqin
# bundle and is therefore not a production implementation.  It exists only
# to measure the phase-reg timing window without editing RTL.
set hs01_branch_buffer_enable 0
if {[info exists ::env(CMR_HS01_BRANCH_BUFFER_ENABLE)] && $::env(CMR_HS01_BRANCH_BUFFER_ENABLE) eq "1"} {
  set hs01_branch_buffer_enable 1
}
proc cmr_hs01_lib_cell {name} {
  set lib [get_lib_cells -quiet */$name]
  if {[sizeof_collection $lib] == 0} {
    return ""
  }
  return [get_object_name [index_collection $lib 0]]
}

proc cmr_hs01_insert_branch_buffers {} {
  set lib_name [cmr_hs01_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL hs01_missing_buffer_lib"
    exit 2
  }

  set head_pins [get_pins -hierarchical -quiet -filter {full_name =~ *PhaseSelectorBlock/Head}]
  set tail_pins [get_pins -hierarchical -quiet -filter {full_name =~ *HeadPredictorBlock/Tail}]
  if {[sizeof_collection $head_pins] != 25 || [sizeof_collection $tail_pins] != 25} {
    puts "CMR_NOC16_DC_FAIL hs01_bind head=[sizeof_collection $head_pins] tail=[sizeof_collection $tail_pins]"
    exit 2
  }

  set head_inserts 0
  foreach_in_collection pin $head_pins {
    if {[catch {insert_buffer $pin $lib_name -new_cell_names hs01_head_hold_buf} err]} {
      puts "CMR_NOC16_DC_FAIL hs01_head_insert [get_object_name $pin] $err"
      exit 2
    }
    incr head_inserts
  }
  set tail_inserts 0
  foreach_in_collection pin $tail_pins {
    if {[catch {insert_buffer $pin $lib_name -new_cell_names hs01_tail_hold_buf} err]} {
      puts "CMR_NOC16_DC_FAIL hs01_tail_insert [get_object_name $pin] $err"
      exit 2
    }
    incr tail_inserts
  }

  set head_cells [get_cells -hierarchical -quiet -filter {full_name =~ *hs01_head_hold_buf*}]
  set tail_cells [get_cells -hierarchical -quiet -filter {full_name =~ *hs01_tail_hold_buf*}]
  puts "CMR_HS01_BRANCH_BUFFER head_inserts=$head_inserts head_cells=[sizeof_collection $head_cells] tail_inserts=$tail_inserts tail_cells=[sizeof_collection $tail_cells] lib=$lib_name"
  if {$head_inserts != 25 || $tail_inserts != 25 || [sizeof_collection $head_cells] != 25 || [sizeof_collection $tail_cells] != 25} {
    puts "CMR_NOC16_DC_FAIL hs01_buffer_count"
    exit 2
  }
  set_dont_touch $head_cells true
  set_dont_touch $tail_cells true

  set audit [open "$REPORT_DIR/hs01_branch_buffer_audit.rpt" w]
  foreach_in_collection cell [add_to_collection $head_cells $tail_cells] {
    set i_net [get_object_name [get_nets -of_objects [get_pins -of_objects $cell -filter {name == I}]]]
    set z_pin [get_pins -of_objects $cell -filter {name == Z}]
    set sinks [all_fanout -from $z_pin -flat -endpoints_only]
    puts $audit "CELL=[get_object_name $cell] I_NET=$i_net SINKS=[get_object_name $sinks]"
  }
  close $audit
}

if {$hs01_branch_buffer_enable && !$incremental_mode} {
  cmr_hs01_insert_branch_buffers
} else {
  puts "CMR_HS01_BRANCH_BUFFER disabled (bundle-safe implementation pending)"
}

# CMR-HS-03 production timing repair.  The input-side IPM Ackout has two
# distinct observation points: locally it closes the RCU handshake-complete
# detector, and
# externally it permits the upstream source to launch the next *complete*
# Reqin/Data/Head/Tail bundle.  Only delay the external branch by inserting at
# the IPM output pin, after all local IPM consumers.  Do not use this mechanism
# on individual data or control fields.
# Disabled by default until an end-to-end CMR packet regression establishes
# that this otherwise bundle-safe external-ack ECO preserves all tail paths.
# Experimental runs must opt in explicitly with 1 or 2 stages.
set ack_feedback_buffer_stages 0
if {[info exists ::env(CMR_ACK_FEEDBACK_BUFFER_STAGES)]} {
  set ack_feedback_buffer_stages $::env(CMR_ACK_FEEDBACK_BUFFER_STAGES)
}
set ack_feedback_scope all
if {[info exists ::env(CMR_ACK_FEEDBACK_SCOPE)]} {
  set ack_feedback_scope $::env(CMR_ACK_FEEDBACK_SCOPE)
}
if {$ack_feedback_buffer_stages != 0 && $ack_feedback_buffer_stages != 1 && $ack_feedback_buffer_stages != 2} {
  puts "CMR_NOC16_DC_FAIL ack_feedback_invalid_stages=$ack_feedback_buffer_stages"
  exit 2
}
if {$ack_feedback_scope ne "all" && $ack_feedback_scope ne "boundary"} {
  puts "CMR_NOC16_DC_FAIL ack_feedback_invalid_scope=$ack_feedback_scope"
  exit 2
}

proc cmr_hs03_insert_ack_feedback_buffers {stages scope} {
  if {$stages == 0} {
    puts "CMR_ACK_FEEDBACK_BUFFER disabled"
    return
  }
  set lib_name [cmr_hs01_lib_cell BUFFD0BWP12T30P140]
  if {$lib_name eq ""} {
    puts "CMR_NOC16_DC_FAIL ack_feedback_missing_buffer_lib"
    exit 2
  }

  # "all" covers five ingress IPMs in each Thin NoC16 router.  "boundary"
  # deliberately covers only the 17 NoC injection ingress ports: child[0:3]
  # of the four L1 routers plus parent[0] of L2.  The eight remaining IPMs
  # terminate the inter-level links and must not have their FIFO feedback
  # phase altered by a CMR write-pointer turnaround guard.
  # io_Ackout is the output pin of the IPM; its local RCU/Buffer consumers are
  # inside the IPM and are therefore upstream of this ECO point.
  # DC glob matching allows '*' to cross hierarchy separators.  Filter the
  # complete pin collection with an anchored regexp so Read/OPM-internal
  # io_Ackout pins are never mistaken for the IPM boundary output.
  set all_ack_pins [get_pins -hierarchical -quiet -filter {name == io_Ackout}]
  set targets ""
  foreach_in_collection candidate $all_ack_pins {
    set candidate_name [get_object_name $candidate]
    set include 0
    if {$scope eq "all" && [regexp {(^|/)InputPortModules_[0-4]/io_Ackout$} $candidate_name]} {
      set include 1
    }
    if {$scope eq "boundary" && [regexp {^routerL1_[01]_[01]/InputPortModules_[0-3]/io_Ackout$} $candidate_name]} {
      set include 1
    }
    if {$scope eq "boundary" && [regexp {^routerL2/InputPortModules_4/io_Ackout$} $candidate_name]} {
      set include 1
    }
    if {$include} {
      set targets [add_to_collection $targets $candidate]
    }
  }
  set expected_targets [expr {$scope eq "boundary" ? 17 : 25}]
  if {[sizeof_collection $targets] != $expected_targets} {
    puts "CMR_NOC16_DC_FAIL ack_feedback_bind scope=$scope actual=[sizeof_collection $targets] expected=$expected_targets"
    exit 2
  }
  set inserted 0
  for {set stage 1} {$stage <= $stages} {incr stage} {
    set next_targets [list]
    foreach_in_collection target $targets {
      if {[catch {insert_buffer $target $lib_name -new_cell_names hs01_ack_feedback_buf_s${stage}} err]} {
        puts "CMR_NOC16_DC_FAIL ack_feedback_insert stage=$stage pin=[get_object_name $target] error=$err"
        exit 2
      }
      incr inserted
    }
    set stage_cells [get_cells -hierarchical -quiet -filter "full_name =~ *hs01_ack_feedback_buf_s${stage}*"]
    if {[sizeof_collection $stage_cells] != $expected_targets} {
      puts "CMR_NOC16_DC_FAIL ack_feedback_stage_count stage=$stage actual=[sizeof_collection $stage_cells] expected=$expected_targets"
      exit 2
    }
    # A possible second stage must be inserted after the first stage, never at
    # a different input-bundle pin.
    set targets [get_pins -of_objects $stage_cells -filter {name == Z}]
    if {$stage < $stages && [sizeof_collection $targets] != $expected_targets} {
      puts "CMR_NOC16_DC_FAIL ack_feedback_stage_output_bind stage=$stage actual=[sizeof_collection $targets] expected=$expected_targets"
      exit 2
    }
  }

  set cells [get_cells -hierarchical -quiet -filter {full_name =~ *hs01_ack_feedback_buf_s*}]
  set expected [expr {$expected_targets * $stages}]
  if {$inserted != $expected || [sizeof_collection $cells] != $expected} {
    puts "CMR_NOC16_DC_FAIL ack_feedback_total_count inserts=$inserted cells=[sizeof_collection $cells] expected=$expected"
    exit 2
  }
  set_dont_touch $cells true

  set audit [open "$REPORT_DIR/hs01_ack_feedback_buffer_audit.rpt" w]
  foreach_in_collection cell $cells {
    set i_pin [get_pins -of_objects $cell -filter {name == I}]
    set z_pin [get_pins -of_objects $cell -filter {name == Z}]
    set i_net [get_object_name [get_nets -of_objects $i_pin]]
    set z_net [get_object_name [get_nets -of_objects $z_pin]]
    set immediate [get_pins -of_objects [get_nets -of_objects $z_pin]]
    set immediate_names [get_object_name $immediate]
    puts $audit "CELL=[get_object_name $cell] I_NET=$i_net Z_NET=$z_net IMMEDIATE=$immediate_names"
    if {![regexp {InputPortModules_.*io_Ackout|InputPortModules_[0-4]_io_Ackout} $i_net]} {
      puts "CMR_NOC16_DC_FAIL ack_feedback_not_ipm_ack cell=[get_object_name $cell] i_net=$i_net"
      close $audit
      exit 2
    }
    if {[regexp {Reqin|Datain|AddressRegister|CMRBuffer} $immediate_names]} {
      puts "CMR_NOC16_DC_FAIL ack_feedback_forbidden_sink cell=[get_object_name $cell] sinks=$immediate_names"
      close $audit
      exit 2
    }
  }
  close $audit
  puts "CMR_ACK_FEEDBACK_BUFFER scope=$scope stages=$stages inserts=$inserted cells=[sizeof_collection $cells] lib=$lib_name"
}

if {!$incremental_mode} {
  cmr_hs03_insert_ack_feedback_buffers $ack_feedback_buffer_stages $ack_feedback_scope
} else {
  puts "CMR_DATAPATH_SKIP_ECO ack_feedback"
}
check_design > "$REPORT_DIR/check_design_post.rpt"

source "$RTL_DIR/assert_no_gtech.tcl"
set n_gtech [async_assert_no_gtech $REPORT_DIR]
set n_unmapped [async_assert_no_seqgen $REPORT_DIR]

set router_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ CMRRouter*}]]
set async_fifo_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ AsyncFifo*}]]
set circular_fifo_count [cmr_circular_fifo_count]
set fifo_count [expr {$async_fifo_count + $circular_fifo_count}]
set ipm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ IPM*}]]
set opm_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ OPM* && ref_name !~ OPMSelector*}]]
set mutex4_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex4*}]]
set mutex2_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ Mutex2*}]]
set adapter_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LanePhaseAdapter*}]]
set clear_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]]
set set_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHSNDQD*}]]
set sr_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ LHCSNDQD*}]]
set path_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCNDQD*}]]
set selector_dual_count [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *Selector*PathLatch*sr_cell && ref_name =~ LHCSNDQD*}]]
set non_path_clear_count [expr {$clear_count - $path_count}]
set close_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ V2CloseEvent* || full_name =~ *RegClose*}]]
set handshake_complete_count [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ HandshakeComplete*}]]
set rcu_matched_steps [cmr_rcu_steps_after]
set rcu_buf_stages [cmr_rcu_buf_stages]
set rcu_matched_unit [cmr_rcu_matched_unit_ps]
if {$rcu_matched_unit == 50} {
  set expected_rcu_del150 0
  set expected_rcu_del050 [expr {25 * $rcu_matched_steps}]
} else {
  set expected_rcu_del150 [expr {25 * $rcu_matched_steps}]
  set expected_rcu_del050 0
}
set expected_rcu_buf [expr {25 * $rcu_buf_stages}]
set rcu_de [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement* && full_name =~ *MatchedDelay*}]]
set del050_rcu [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL050D1* && full_name =~ *MatchedDelay*}]]
set del150_rcu [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL150D1* && full_name =~ *MatchedDelay*}]]
set rcu_matched_buf [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *rcu_matched_buf_s*}]]
set opm_ackin_de [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DelayElement* && full_name =~ *AckinDelay*}]]
set opm_ackin_del250 [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL250D1* && full_name =~ *AckinDelay*}]]
set ackin_unit [cmr_opm_ackin_unit_ps]
set ackin_glob [cmr_opm_ackin_leaf_glob $ackin_unit]
set opm_ackin_leaf [sizeof_collection [get_cells -hierarchical -quiet -filter "ref_name =~ $ackin_glob && full_name =~ *AckinDelay*"]]
set opm_ackin_any_del [sizeof_collection [cmr_opm_ackin_leaves]]
set del250_eco [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *wp_hs02_req_dly*}]]
set hs01_head_buffers [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *hs01_head_hold_buf*}]]
set hs01_tail_buffers [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *hs01_tail_hold_buf*}]]
set ack_feedback_buffers [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *hs01_ack_feedback_buf_s*}]]
set cfifo_hs02_buffers [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_hs02_ack_counter_buf_s*}]]
set cfifo_rd01_buffers [sizeof_collection [get_cells -hierarchical -quiet -filter {full_name =~ *cfifo_rd01_reqout_buf_s*}]]

set fd [open "$REPORT_DIR/cmr_noc16_structure.rpt" w]
puts $fd "ROUTER_COUNT=$router_count"
puts $fd "INTERLEVEL_FIFO_COUNT=$fifo_count"
puts $fd "EXPECTED_INTERLEVEL_FIFO_COUNT=$expected_fifos"
puts $fd "ASYNC_FIFO_COUNT=$async_fifo_count"
puts $fd "CIRCULAR_FIFO_COUNT=$circular_fifo_count"
puts $fd "IPM_COUNT=$ipm_count"
puts $fd "OPM_COUNT=$opm_count"
puts $fd "MUTEX4_COUNT=$mutex4_count"
puts $fd "MUTEX2_COUNT=$mutex2_count"
puts $fd "LANE_PHASE_ADAPTER_COUNT=$adapter_count"
puts $fd "RESET_LATCH_COUNT=$clear_count"
puts $fd "SET_RESET_LATCH_COUNT=$set_count"
puts $fd "SR_LATCH_COUNT=$sr_count"
puts $fd "PATH_LATCH_CLEAR_COUNT=$path_count"
puts $fd "PATH_LATCH_DUAL_COUNT=$selector_dual_count"
puts $fd "V2_CLOSE_EVENT_COUNT=$close_count"
puts $fd "HANDSHAKE_COMPLETE_COUNT=$handshake_complete_count"
puts $fd "RCU_DELAY_ELEMENT_COUNT=$rcu_de"
puts $fd "RCU_DEL050_COUNT=$del050_rcu"
puts $fd "RCU_DEL150_COUNT=$del150_rcu"
puts $fd "RCU_MATCHED_DELAY_UNIT_PS=$rcu_matched_unit"
puts $fd "RCU_MATCHED_BUF_COUNT=$rcu_matched_buf"
puts $fd "RCU_MATCHED_BUF_STAGES=$rcu_buf_stages"
puts $fd "OPM_ACKIN_DELAY_ELEMENT_COUNT=$opm_ackin_de"
puts $fd "OPM_ACKIN_DEL250_COUNT=$opm_ackin_del250"
puts $fd "OPM_ACKIN_DEL_UNIT_PS=$ackin_unit"
puts $fd "OPM_ACKIN_LEAF_COUNT=$opm_ackin_leaf"
puts $fd "WP_REQ_DEL250_COUNT=$del250_eco"
puts $fd "HS01_HEAD_BUFFER_COUNT=$hs01_head_buffers"
puts $fd "HS01_TAIL_BUFFER_COUNT=$hs01_tail_buffers"
puts $fd "ACK_FEEDBACK_BUFFER_STAGES=$ack_feedback_buffer_stages"
puts $fd "ACK_FEEDBACK_BUFFER_COUNT=$ack_feedback_buffers"
puts $fd "CFIFO_HS02_ACK_COUNTER_BUFFER_COUNT=$cfifo_hs02_buffers"
puts $fd "CFIFO_RD01_REQOUT_BUFFER_COUNT=$cfifo_rd01_buffers"
close $fd

# CMR-WP-01 spans the NoC boundary.  This NoC-only compile deliberately does
# not contain the source endpoint, so it must not claim an internal Ack-to-next
# Req timing number.  Emit the ownership and required paired measurements in a
# machine-readable report; the structural endpoint SDF partition supplies the
# source-side minimum.
set wp01_fd [open "$REPORT_DIR/cmr_wp01_turnaround.rpt" w]
puts $wp01_fd "CMR_WP01_OWNER=AsyncEndpointBank20.source_turnaround_delay"
puts $wp01_fd "CMR_WP01_SOURCE_CELLS=DEL150D1BWP12T30P140,DEL050D1BWP12T30P140"
puts $wp01_fd "CMR_WP01_SOURCE_NOMINAL_NS=0.200"
puts $wp01_fd "CMR_WP01_NOC_TOP_SOURCE_ENDPOINT_PRESENT=0"
puts $wp01_fd "CMR_WP01_REQUIRED_MAX_PATH=complete_to_old_CellFullLatch_E_fall"
puts $wp01_fd "CMR_WP01_REQUIRED_MIN_PATH=Ackout_at_input_pin_to_source_latch_reopen_to_next_ReqData"
puts $wp01_fd "CMR_WP01_ACCEPTANCE=Tmin(source_path)>Tmax(pointer_path)+latch_margin"
close $wp01_fd
puts "CMR_NOC16_STRUCTURE ROUTER=$router_count FIFO=$fifo_count EXPECTED_FIFO=$expected_fifos ASYNC_FIFO=$async_fifo_count CIRCULAR_FIFO=$circular_fifo_count IPM=$ipm_count OPM=$opm_count MUTEX4=$mutex4_count MUTEX2=$mutex2_count ADAPTER=$adapter_count CLEAR=$clear_count SET=$set_count SR=$sr_count CLOSE=$close_count COMPLETE=$handshake_complete_count RCU_DE=$rcu_de RCU_DEL050=$del050_rcu RCU_DEL150=$del150_rcu RCU_UNIT=$rcu_matched_unit RCU_MATCHED_BUF=$rcu_matched_buf OPM_ACKIN_DE=$opm_ackin_de OPM_ACKIN_DEL250=$opm_ackin_del250 OPM_ACKIN_UNIT=$ackin_unit OPM_ACKIN_LEAF=$opm_ackin_leaf WP_DEL250=$del250_eco HS01_HEAD_BUF=$hs01_head_buffers HS01_TAIL_BUF=$hs01_tail_buffers ACK_FEEDBACK_SCOPE=$ack_feedback_scope ACK_FEEDBACK_STAGES=$ack_feedback_buffer_stages ACK_FEEDBACK_BUF=$ack_feedback_buffers CFIFO_HS02_BUF=$cfifo_hs02_buffers CFIFO_RD01_BUF=$cfifo_rd01_buffers"

if {$n_gtech > 0 || $n_unmapped > 0} {
  puts "CMR_NOC16_DC_FAIL unmapped gtech=$n_gtech generic=$n_unmapped"
  exit 2
}
if {$router_count != 5 || $fifo_count != $expected_fifos || $ipm_count != 25 || $opm_count != 25 || $mutex4_count != 25 || $mutex2_count != 75} {
  puts "CMR_NOC16_DC_FAIL router_or_fifo_structure fifo=$fifo_count expected_fifo=$expected_fifos"
  exit 2
}
if {$adapter_count != 0} {
  puts "CMR_NOC16_DC_FAIL unexpected_lane_phase_adapter count=$adapter_count"
  exit 2
}
if {$path_count != $expected_path_latches || $selector_dual_count != 0 || $non_path_clear_count != $expected_non_path_clear || $set_count != $expected_set || $close_count != 50} {
  puts "CMR_NOC16_DC_FAIL async_storage_structure"
  exit 2
}
if {$handshake_complete_count != 0} {
  puts "CMR_NOC16_DC_FAIL obsolete_handshake_complete actual=$handshake_complete_count expected=0"
  exit 2
}
if {$rcu_de != 25 || $del150_rcu != $expected_rcu_del150 || $del050_rcu != $expected_rcu_del050} {
  puts "CMR_NOC16_DC_FAIL rcu_matched_delay DelayElement=$rcu_de del150=$del150_rcu/$expected_rcu_del150 del050=$del050_rcu/$expected_rcu_del050 steps=$rcu_matched_steps unit=$rcu_matched_unit"
  exit 2
}
if {$rcu_matched_buf != $expected_rcu_buf} {
  puts "CMR_NOC16_DC_FAIL rcu_matched_buf actual=$rcu_matched_buf expected=$expected_rcu_buf stages=$rcu_buf_stages"
  exit 2
}
set expected_ackin_de [cmr_opm_ackin_expected_de]
set expected_ackin_leaf [cmr_opm_ackin_expected_leaf]
if {$opm_ackin_de != $expected_ackin_de || $opm_ackin_leaf != $expected_ackin_leaf || $opm_ackin_any_del != $expected_ackin_leaf} {
  puts "CMR_NOC16_DC_FAIL opm_ackin_delay DelayElement=$opm_ackin_de leaf=$opm_ackin_leaf any_del=$opm_ackin_any_del expected_de=$expected_ackin_de expected_leaf=$expected_ackin_leaf unit=$ackin_unit steps=[cmr_opm_ackin_steps]"
  exit 2
}
if {$wp_req_del250_enable && $del250_eco != 25} {
  puts "CMR_NOC16_DC_FAIL wp_req_del250 actual=$del250_eco expected=25"
  exit 2
}
if {!$wp_req_del250_enable && $del250_eco != 0} {
  puts "CMR_NOC16_DC_FAIL clean_baseline_contains_wp_req_del250 actual=$del250_eco"
  exit 2
}
if {$hs01_branch_buffer_enable && ($hs01_head_buffers != 25 || $hs01_tail_buffers != 25)} {
  puts "CMR_NOC16_DC_FAIL hs01_branch_buffer_count head=$hs01_head_buffers tail=$hs01_tail_buffers"
  exit 2
}
set ack_feedback_target_count [expr {$ack_feedback_scope eq "boundary" ? 17 : 25}]
set expected_ack_feedback_buffers [expr {$ack_feedback_target_count * $ack_feedback_buffer_stages}]
if {$ack_feedback_buffers != $expected_ack_feedback_buffers} {
  puts "CMR_NOC16_DC_FAIL ack_feedback_buffer_count actual=$ack_feedback_buffers expected=$expected_ack_feedback_buffers"
  exit 2
}
set expected_cfifo_hs02_buffers [expr {$circular_fifo_count * 3}]
if {$cfifo_hs02_buffers != $expected_cfifo_hs02_buffers} {
  puts "CMR_NOC16_DC_FAIL cfifo_hs02_buffer_count actual=$cfifo_hs02_buffers expected=$expected_cfifo_hs02_buffers"
  exit 2
}
set expected_cfifo_rd01_buffers [expr {$circular_fifo_count * 4 * 16}]
if {$cfifo_rd01_buffers != $expected_cfifo_rd01_buffers} {
  puts "CMR_NOC16_DC_FAIL cfifo_rd01_buffer_count actual=$cfifo_rd01_buffers expected=$expected_cfifo_rd01_buffers"
  exit 2
}
if {![async_mutex2_drive_symmetry_ok]} {
  puts "CMR_NOC16_DC_FAIL mutex2_nand_drive_symmetry"
  exit 2
}
if {$incremental_mode} {
  set del050_total [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL050D1*}]]
  set del075_total [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL075D1*}]]
  set del100_total [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL100D1*}]]
  set del150_total [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL150D1*}]]
  set fifo_del150 [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL150D1* && full_name =~ *outReqDelay*}]]
  set del250_total [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ DEL250D1*}]]
  set expected_del050 0
  set expected_del075 0
  set expected_del100 0
  set expected_del150 $expected_rcu_del150
  set expected_del250 0
  switch -- $ackin_unit {
    50  { set expected_del050 $expected_ackin_leaf }
    75  { set expected_del075 $expected_ackin_leaf }
    100 { set expected_del100 $expected_ackin_leaf }
    150 { set expected_del150 [expr {$expected_rcu_del150 + $expected_ackin_leaf}] }
    250 { set expected_del250 $expected_ackin_leaf }
  }
  set expected_del050 [expr {$expected_del050 + $expected_rcu_del050}]
  puts "CMR_DATAPATH_DEL_FREEZE DEL050=$del050_total DEL075=$del075_total DEL100=$del100_total DEL150=$del150_total FIFO_DEL150=$fifo_del150 DEL250=$del250_total HS02=$cfifo_hs02_buffers RD01=$cfifo_rd01_buffers expected_rcu_del150=$expected_rcu_del150 expected_rcu_del050=$expected_rcu_del050 expected_ackin_leaf=$expected_ackin_leaf ackin_unit=$ackin_unit rcu_unit=$rcu_matched_unit"
  if {[info exists ::CMR_INNER_CLASS]} {
    puts "CMR_INNER_DEL_FREEZE class=$::CMR_INNER_CLASS DEL150=$del150_total DEL250=$del250_total expected_rcu_del150=$expected_rcu_del150 ackin_unit=$ackin_unit expected_ackin_leaf=$expected_ackin_leaf"
  }
  if {$del050_total != $expected_del050 || $del075_total != $expected_del075 || $del100_total != $expected_del100 || $del150_total != $expected_del150 || $fifo_del150 != 0 || $del250_total != $expected_del250} {
    puts "CMR_NOC16_DC_FAIL datapath_del_changed DEL050=$del050_total/$expected_del050 DEL075=$del075_total/$expected_del075 DEL100=$del100_total/$expected_del100 DEL150=$del150_total/$expected_del150 FIFO_DEL150=$fifo_del150 DEL250=$del250_total/$expected_del250 ackin_unit=$ackin_unit"
    exit 2
  }
  if {$circular_fifo_count != 8 || $async_fifo_count != 0} {
    puts "CMR_NOC16_DC_FAIL datapath_fifo_kind circular=$circular_fifo_count async=$async_fifo_count"
    exit 2
  }
  if {$cfifo_hs02_buffers != 24 || $cfifo_rd01_buffers != 512} {
    puts "CMR_NOC16_DC_FAIL datapath_cfifo_eco_changed HS02=$cfifo_hs02_buffers RD01=$cfifo_rd01_buffers"
    exit 2
  }
}

async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
write -hierarchy -format ddc -output "$OUTPUT_DIR/NoC_16nodes.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/NoC_16nodes_post.v"
write_sdf "$OUTPUT_DIR/NoC_16nodes.sdf"
write_sdc "$OUTPUT_DIR/NoC_16nodes.sdc"
exec sha256sum "$OUTPUT_DIR/NoC_16nodes.ddc" "$OUTPUT_DIR/NoC_16nodes_post.v" "$OUTPUT_DIR/NoC_16nodes.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "CMR_NOC16_DC_PASS output=$OUTPUT_DIR"
quit
