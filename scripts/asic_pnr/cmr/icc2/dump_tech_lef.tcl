# icc2_lm_shell: convert TSMC MW frame library into NDM + technology LEF.
# generate_frame_from_mw requires -mw_lib and a positional library_name.

set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set PNR_ROOT [file normalize [file join [file dirname [info script]] ..]]
source "$PNR_ROOT/tech_t28hpc_pnr.tcl"

set OUT_LEF "$PROJECT_DIR/work/tcbn28hpcplusbwp12t30p140_tech.lef"
set OUT_TF  "$PROJECT_DIR/work/tcbn28hpcplusbwp12t30p140.tf"
set OUT_NDM "$PROJECT_DIR/work/ndm_tcbn28hpcplusbwp12t30p140"
file mkdir [file dirname $OUT_LEF]
catch { file delete -force $OUT_NDM $OUT_LEF $OUT_TF }

set mw $CMR_PNR_MW
set libname $CMR_PNR_LIBNAME
puts "CMR_PNR_DUMP mw=$mw libname=$libname"

puts "===== ENV ====="
puts "PATH=$::env(PATH)"
foreach v {ICC_HOME SYNOPSYS} {
  if {[info exists ::env($v)]} { puts "$v=$::env($v)" }
}
foreach bin {icc_shell Milkyway mw_shell} {
  set found [file dirname [file normalize [info nameofexecutable]]]
  catch { puts "WHICH_$bin=[exec which $bin]" }
}
puts "===== HELP -verbose generate_frame_from_mw ====="
catch { help -verbose generate_frame_from_mw }
puts "===== APP OPTIONS icc/mw/frame ====="
catch {
  foreach spec [get_app_option_specs] {
    set n [get_attribute $spec name]
    if {[regexp -nocase {icc|mw|milky|frame|lef} $n]} {
      puts "APP $n"
    }
  }
}
puts "===== RELATED COMMANDS ====="
foreach c [lsort [info commands]] {
  if {[regexp -nocase {mw|milky|tech|lef|workspace|frame|ndm} $c]} {
    puts "CMD $c"
  }
}

proc cmr_try {label argv} {
  puts "CMR_PNR_TRY $label : $argv"
  if {![catch { uplevel 1 $argv } err]} {
    puts "CMR_PNR_OK $label"
    return 1
  }
  puts "CMR_PNR_WARN $label $err"
  return 0
}

set loaded 0
if {[cmr_try direct_ndm [list generate_frame_from_mw -mw_lib $mw -output $OUT_NDM $libname]]} {
  set loaded 1
}
if {!$loaded && [cmr_try direct_libname [list generate_frame_from_mw -mw_lib $mw $libname]]} {
  set loaded 1
}

if {!$loaded} {
  catch { remove_workspace -force cmr_t28_ws }
  if {![cmr_try create_ws {create_workspace -flow physical cmr_t28_ws}]} {
    if {![cmr_try create_ws_frame {create_workspace -flow frame cmr_t28_ws}]} {
      puts "CMR_PNR_FAIL create_workspace"
      exit 2
    }
  }
  if {$CMR_PNR_DB ne ""} {
    catch { read_db $CMR_PNR_DB }
  }
  if {[cmr_try ws_mw_out [list generate_frame_from_mw -mw_lib $mw -output $OUT_NDM $libname]]} {
    set loaded 1
  } elseif {[cmr_try ws_mw [list generate_frame_from_mw -mw_lib $mw $libname]]} {
    set loaded 1
  } elseif {[cmr_try ws_mw_only [list generate_frame_from_mw -mw_lib $mw]]} {
    set loaded 1
  } else {
    puts "CMR_PNR_FAIL generate_frame_from_mw"
    exit 2
  }
}

catch { check_workspace }
if {![file exists $OUT_NDM] && ![file isdirectory $OUT_NDM]} {
  catch { file delete -force $OUT_NDM }
  catch { commit_workspace -output $OUT_NDM }
}
if {[file exists $OUT_NDM] || [file isdirectory $OUT_NDM]} {
  puts "CMR_PNR_NDM_OK $OUT_NDM"
}

catch { write_tech_file $OUT_TF }
catch { write_lef -technology $OUT_LEF }
catch { write_lef -tech $OUT_LEF }
catch { write_lef $OUT_LEF }
if {[file exists $OUT_LEF]} {
  puts "CMR_PNR_TECH_LEF_OK $OUT_LEF size=[file size $OUT_LEF]"
}
if {[file exists $OUT_TF]} {
  puts "CMR_PNR_TECH_TF_OK $OUT_TF size=[file size $OUT_TF]"
}
if {![file exists $OUT_LEF] && ![file exists $OUT_TF] && ![file exists $OUT_NDM] && ![file isdirectory $OUT_NDM]} {
  puts "CMR_PNR_FAIL no_physical_library_emitted"
  exit 2
}
exit 0
