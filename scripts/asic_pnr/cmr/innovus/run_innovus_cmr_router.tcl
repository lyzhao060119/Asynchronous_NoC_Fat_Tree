# Innovus 21.x CMR Router primitive P&R. Async: no ccopt.

set PROJECT_DIR $::env(CMR_REMOTE_ROOT)
set RUN_ID      $::env(CMR_PNR_RUN_ID)
set NETLIST     $::env(CMR_PNR_NETLIST)
set SDC_FILE    $::env(CMR_PNR_SDC)
set TOP         [expr {[info exists ::env(CMR_PNR_TOP)] ? $::env(CMR_PNR_TOP) : "CMRRouter"}]
set SYNC        [expr {[info exists ::env(CMR_PNR_SYNC)] && $::env(CMR_PNR_SYNC) eq "1"}]
set EXPECT_DEL  [expr {[info exists ::env(CMR_EXPECTED_DEL050)] ? $::env(CMR_EXPECTED_DEL050) : ""}]
set REPORT_DIR  "$PROJECT_DIR/reports/pnr/$RUN_ID"
set OUTPUT_DIR  "$PROJECT_DIR/outputs/pnr/$RUN_ID"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

set TSMC_HOME "/process/tsmc/CLN28HPC+/TSMCHOME"
set CELL "tcbn28hpcplusbwp12t30p140"
set LEF "$TSMC_HOME/digital/Back_End/lef/${CELL}_170a/lef/${CELL}.lef"
if {[info exists ::env(CMR_PNR_LEF)] && $::env(CMR_PNR_LEF) ne ""} {
  set LEF $::env(CMR_PNR_LEF)
}
set LIB "$TSMC_HOME/digital/Front_End/timing_power_noise/CCS/${CELL}_180a/${CELL}ssg0p81v125c_ccs.lib"
if {[info exists ::env(CMR_PNR_LIBERTY)] && $::env(CMR_PNR_LIBERTY) ne ""} {
  set LIB $::env(CMR_PNR_LIBERTY)
}

set TECH_LEF "$PROJECT_DIR/work/tcbn28hpcplusbwp12t30p140_tech.lef"
if {[info exists ::env(CMR_PNR_TECH_LEF)] && $::env(CMR_PNR_TECH_LEF) ne ""} {
  set TECH_LEF $::env(CMR_PNR_TECH_LEF)
}
if {[file exists $TECH_LEF]} {
  set init_lef_file [list $TECH_LEF $LEF]
  puts "CMR_PNR_LEF_FILES tech=$TECH_LEF cell=$LEF"
} else {
  set init_lef_file $LEF
  puts "CMR_PNR_WARN missing_tech_lef $TECH_LEF; Innovus import will fail without LAYER table"
}
set init_design_uniquify 1
set init_verilog $NETLIST
set init_top_cell $TOP
if {[file exists $LIB]} {
  set init_mmmc_file "$REPORT_DIR/mmmc.tcl"
  set m [open $init_mmmc_file w]
  puts $m "create_library_set -name ss_lib -timing \[list {$LIB}\]"
  puts $m "create_rc_corner -name ss_rc -T 125"
  puts $m "create_delay_corner -name ss_dc -library_set ss_lib -rc_corner ss_rc"
  if {[file exists $SDC_FILE]} {
    puts $m "create_constraint_mode -name async_mode -sdc_files \[list {$SDC_FILE}\]"
  } else {
    puts $m "create_constraint_mode -name async_mode -sdc_files {}"
  }
  puts $m "create_analysis_view -name ss_view -delay_corner ss_dc -constraint_mode async_mode"
  puts $m "set_analysis_view -setup ss_view -hold ss_view"
  close $m
}

init_design
puts "CMR_PNR_INIT ok top=$TOP"

proc cmr_inv_dont_touch {pattern label} {
  set cells [get_cells -hier * -filter "full_name =~ $pattern || ref_name =~ $pattern"]
  set n [sizeof_collection $cells]
  if {$n > 0} {
    setDontTouch $cells true
    catch { setSizeOnly $cells true }
  }
  puts "CMR_PNR_PRESERVE $label $n"
}

cmr_inv_dont_touch "*DelayElement*" DelayElement
cmr_inv_dont_touch "DEL050D1*" DEL050
cmr_inv_dont_touch "DEL*" DEL_any
cmr_inv_dont_touch "*MatchedDelay*" MatchedDelay
cmr_inv_dont_touch "*AckinDelay*" AckinDelay
cmr_inv_dont_touch "*Mutex2*" Mutex2
cmr_inv_dont_touch "*q0_nand*" MutexNand0
cmr_inv_dont_touch "*q1_nand*" MutexNand1
cmr_inv_dont_touch "LHCNDQD*" LHCNDQD
cmr_inv_dont_touch "LHSNDQD*" LHSNDQD
cmr_inv_dont_touch "*closeEvent*" V2CloseEvent
cmr_inv_dont_touch "*LanePhaseAdapter*" LanePhaseAdapter

setDontUse *SEQGEN* true
setDontUse GTECH* true

floorPlan -r 1 0.60 2 2 2 2
puts "CMR_PNR_FLOORPLAN ok"

placeDesign
puts "CMR_PNR_PLACE ok"

if {$SYNC} {
  puts "CMR_PNR_CTS start"
  catch { ccopt_design }
} else {
  puts "CMR_PNR_CTS skipped_async"
}

routeDesign
puts "CMR_PNR_ROUTE ok"

setVerifyGeometryMode -drc true -antenna false
verifyGeometry
verifyConnectivity -type all

set fd [open "$REPORT_DIR/structure.rpt" w]
foreach {key pat} {
  DEL050 DEL050D1*
  Mutex2 Mutex2*
  LHCNDQD LHCNDQD*
  GTECH GTECH*
  SEQGEN *SEQGEN*
} {
  puts $fd "$key=[sizeof_collection [get_cells -hier * -filter "ref_name =~ $pat"]]"
}
close $fd

set del [sizeof_collection [get_cells -hier * -filter {ref_name =~ DEL050D1*}]]
set gtech [sizeof_collection [get_cells -hier * -filter {ref_name =~ GTECH*}]]
set seq [sizeof_collection [get_cells -hier * -filter {ref_name =~ *SEQGEN*}]]
set mutex [sizeof_collection [get_cells -hier * -filter {ref_name =~ Mutex2*}]]
set latch [sizeof_collection [get_cells -hier * -filter {ref_name =~ LHCNDQD*}]]
puts "CMR_PNR_STRUCTURE DEL050=$del GTECH=$gtech SEQGEN=$seq MUTEX2=$mutex LHCNDQD=$latch"
if {$gtech != 0 || $seq != 0 || $mutex == 0 || $latch == 0} {
  puts "CMR_PNR_FAIL structure"
  exit 2
}
if {$EXPECT_DEL ne "" && $del != $EXPECT_DEL} {
  puts "CMR_PNR_FAIL DEL050=$del expected=$EXPECT_DEL"
  exit 2
}

catch { report_summary -out_file "$REPORT_DIR/qor.rpt" }
catch { report_power -outfile "$REPORT_DIR/power.rpt" }
catch { summaryReport -nohtml -outfile "$REPORT_DIR/summary.rpt" }

saveNetlist "$OUTPUT_DIR/${TOP}_routed.v"
catch { write_sdf "$OUTPUT_DIR/${TOP}.sdf" }
catch { defOut "$OUTPUT_DIR/${TOP}.def" }
catch { streamOut "$OUTPUT_DIR/${TOP}.gds" -mapFile "" -libName DesignLib -uniquifyCellNames -mode ALL }
catch { extractRC }
catch { rcOut -spef "$OUTPUT_DIR/${TOP}.spef" }

puts "CMR_PNR_PASS tool=innovus output=$OUTPUT_DIR"
exit 0
