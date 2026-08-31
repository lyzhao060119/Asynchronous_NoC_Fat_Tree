# Dedicated UltraRouter DC flow. PROJECT_DIR is supplied by the remote runner.
set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RTL_DIR "$PROJECT_DIR/rtl"
set REPORT_DIR "$PROJECT_DIR/reports/dc/$::env(ULTRA_RUN_ID)"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$::env(ULTRA_RUN_ID)"
set WORK_LIB "$PROJECT_DIR/work/dc_$::env(ULTRA_RUN_ID)"
file mkdir $REPORT_DIR; file mkdir $OUTPUT_DIR; file mkdir $WORK_LIB
source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB

proc ultra_structural_fingerprint {file phase} {
  set fd [open $file w]
  puts $fd "PHASE=$phase"
  foreach_in_collection cell [get_cells -hierarchical -quiet *] {
    puts $fd "[get_object_name $cell],[get_attribute $cell ref_name]"
  }
  close $fd
}

set incremental_mode [expr {[info exists ::env(ULTRA_DATAPATH_SEED_DDC)] && $::env(ULTRA_DATAPATH_SEED_DDC) ne ""}]
if {$incremental_mode} {
  # Phase-3 datapath-first flow starts from a frozen, mapped Router macro.
  # Do not re-elaborate RTL: the only legal freedom below is sizing/buffering
  # in ordinary data logic under the overlay constraints.
  set SEED_DDC $::env(ULTRA_DATAPATH_SEED_DDC)
  if {![file exists $SEED_DDC]} {
    puts "ULTRA_DC_FAIL missing_datapath_seed=$SEED_DDC"
    exit 2
  }
  read_ddc $SEED_DDC
  current_design UltraRouter
  link
  puts "ULTRA_DATAPATH_INCREMENTAL seed=$SEED_DDC"
} else {
  analyze -format verilog -define ASIC_T28 -work WORK [list \
    "$RTL_DIR/DelayElement_ASIC.v" "$RTL_DIR/Mutex2_ASIC.v" \
    "$RTL_DIR/MullerC2.v" "$RTL_DIR/MullerC3.v" "$RTL_DIR/DLatchBank.v" "$RTL_DIR/V2CloseEvent.v" \
    "$RTL_DIR/MousetrapStage.v" "$RTL_DIR/TAC2.v" "$RTL_DIR/Mutex3Grant.v" \
    "$RTL_DIR/Mutex5Anchor.v" "$RTL_DIR/UltraHeadCaptureCell.v" \
    "$RTL_DIR/AsyncRoundMembershipCell.v" \
    "$RTL_DIR/AsyncRoundDecisionCell.v" "$RTL_DIR/AsyncArbiterTransactionController.v" \
    "$RTL_DIR/UltraRouter.v"]
  elaborate UltraRouter -work WORK
  current_design UltraRouter
  uniquify; link
}
check_design > "$REPORT_DIR/check_design_pre.rpt"
ultra_structural_fingerprint "$REPORT_DIR/structure_pre_map.csv" pre_map
source "$RTL_DIR/async_ultra_router.sdc"
source "$RTL_DIR/async_primitives.tcl"
set dfire0_profile 0
set dfire150_profile 0
set dfire100_profile 0
set dfire50_profile 0
set prs150_profile 0
set prs50_profile 0
if {[info exists ::env(ASYNC_DELAY_PROFILE)]} {
  if {[string match "*_DFIRE0" $::env(ASYNC_DELAY_PROFILE)]} {
    set dfire0_profile 1
  }
  if {[string match "*_DFIRE150" $::env(ASYNC_DELAY_PROFILE)]} {
    set dfire150_profile 1
  }
  if {[string match "*_DFIRE100" $::env(ASYNC_DELAY_PROFILE)]} {
    set dfire100_profile 1
  }
  if {[string match "*_DFIRE50" $::env(ASYNC_DELAY_PROFILE)] ||
      [string match "*_DFIRE50_*" $::env(ASYNC_DELAY_PROFILE)]} {
    set dfire50_profile 1
  }
  if {[string match "*_PRS150" $::env(ASYNC_DELAY_PROFILE)]} {
    set prs150_profile 1
  }
  if {[string match "*_PRS50" $::env(ASYNC_DELAY_PROFILE)]} {
    set prs50_profile 1
  }
}
if {$dfire0_profile} {
  # async_primitives.tcl dont_touch's every DelayElement.  DFIRE0 keeps the
  # named fire_o_Dfire hierarchy but must let compile_ultra insert ordinary
  # buffers on Start→fire.  Other delay roles stay protected.
  set dfire_hier [get_cells -hierarchical -quiet -filter {full_name =~ *commitController*fire_o_Dfire*}]
  if {[sizeof_collection $dfire_hier] == 0} {
    puts "ULTRA_DC_FAIL missing_dfire_hierarchy_for_dont_touch_release"
    exit 2
  }
  set_dont_touch $dfire_hier false
  puts "ULTRA_DFIRE_DONT_TOUCH_RELEASE count=[sizeof_collection $dfire_hier]"
}
if {[info exists ::env(ULTRA_DATAPATH_OVERLAY)] && $::env(ULTRA_DATAPATH_OVERLAY) ne ""} {
  if {![file exists $::env(ULTRA_DATAPATH_OVERLAY)]} {
    puts "ULTRA_DC_FAIL missing_datapath_overlay=$::env(ULTRA_DATAPATH_OVERLAY)"
    exit 2
  }
  source $::env(ULTRA_DATAPATH_OVERLAY)
}
if {[info exists ::env(ULTRA_OPM_CONTROL_OVERLAY)] && $::env(ULTRA_OPM_CONTROL_OVERLAY) ne ""} {
  if {![file exists $::env(ULTRA_OPM_CONTROL_OVERLAY)]} {
    puts "ULTRA_DC_FAIL missing_opm_control_overlay=$::env(ULTRA_OPM_CONTROL_OVERLAY)"
    exit 2
  }
  source $::env(ULTRA_OPM_CONTROL_OVERLAY)
}
set dfire_overlay ""
if {[info exists ::env(ULTRA_DFIRE_CONTROL_OVERLAY)] && $::env(ULTRA_DFIRE_CONTROL_OVERLAY) ne ""} {
  set dfire_overlay $::env(ULTRA_DFIRE_CONTROL_OVERLAY)
} elseif {($dfire0_profile || $dfire150_profile || $dfire100_profile || $dfire50_profile) && [file exists "$RTL_DIR/async_ultra_router_dfire_control.sdc"]} {
  # DFIRE0 needs the overlay to supply the min-delay that DC would not infer.
  # DFIRE150/100/50 keep a real DEL cell; the overlay is only a Start→fire guard.
  set dfire_overlay "$RTL_DIR/async_ultra_router_dfire_control.sdc"
}
if {$dfire_overlay ne ""} {
  if {![file exists $dfire_overlay]} {
    puts "ULTRA_DC_FAIL missing_dfire_control_overlay=$dfire_overlay"
    exit 2
  }
  source $dfire_overlay
} elseif {$dfire0_profile || $dfire150_profile || $dfire100_profile || $dfire50_profile} {
  puts "ULTRA_DC_FAIL missing_dfire_control_overlay_for_DFIRE"
  exit 2
}
# Ultra Part VII design entry: retain module boundaries and prevent DC from
# moving logic across them.  The permitted implementation freedom is mapping,
# drive-size selection and insertion of buffers/inverters, not re-timing or
# hierarchy collapse.
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
if {$incremental_mode} {
  compile_ultra -incremental -no_autoungroup
} else {
  compile_ultra -no_autoungroup
}
check_design > "$REPORT_DIR/check_design_post.rpt"
source "$RTL_DIR/assert_no_gtech.tcl"
set ng [async_assert_no_gtech $REPORT_DIR]
set nu [async_assert_no_seqgen $REPORT_DIR]
# The OPM V2 margin is a structural RTL DelayElement.  Verify its mapped
# DEL-chain count so a sweep cannot silently become a no-delay netlist.
set opm_margin_ps 0
set opm_synth_profile 0
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0*" $::env(ASYNC_DELAY_PROFILE)]} {
  # OPM_SYNTH retains v2RequestMargin hierarchy but deliberately contains no
  # DEL cell.  ANC0, FB0 and FB0_RC0 inherit this zero-DEL OPM contract.
  set opm_synth_profile 1
  set opm_margin_ps 0
}
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    ([regexp {ULTRA_P250_PRS_ACG_OPM(0|50|75|100|150|250)} $::env(ASYNC_DELAY_PROFILE) -> opm_margin_ps] ||
     $opm_synth_profile)} {
  if {$opm_margin_ps == 0} {
    set expected_opm_del 0
  } else {
    set expected_opm_del 5
  }
  # Count only cells beneath the named RTL margin hierarchy.  A global
  # ref_name query is not reliable after DC preserves/uniquifies black-box
  # hierarchy, while this hierarchy is intentionally stable design entry.
  set margin_hier [get_cells -hierarchical -quiet -filter {full_name =~ *v2RequestMargin*}]
  set actual_opm_del 0
  set opm_margin_cell_ps [format "%03d" $opm_margin_ps]
  set margin_manifest [open "$REPORT_DIR/opm_v2_margin_cells.rpt" w]
  foreach_in_collection cell $margin_hier {
    set ref [get_attribute $cell ref_name]
    puts $margin_manifest "[get_object_name $cell],$ref"
    if {[string match "DEL${opm_margin_cell_ps}D1*" $ref]} { incr actual_opm_del }
  }
  close $margin_manifest
  puts "ULTRA_OPM_RTM_MARGIN_PS=$opm_margin_ps EXPECTED_DEL=$expected_opm_del ACTUAL_DEL=$actual_opm_del"
  if {$actual_opm_del != $expected_opm_del} {
    puts "ULTRA_DC_FAIL opm_rtm_delay_count"
    exit 2
  }
  if {$opm_synth_profile} {
    # Report the ordinary standard cells introduced below the five preserved
    # margin hierarchies.  DEL cells are excluded: their count is asserted
    # above to be zero.  This makes the DC-controlled replacement auditable.
    set control_fd [open "$REPORT_DIR/opm_v2_control_cells.rpt" w]
    puts $control_fd "cell,ref_name"
    set control_cells 0
    foreach_in_collection cell $margin_hier {
      set ref [get_attribute $cell ref_name]
      if {![string match "DEL*" $ref]} {
        puts $control_fd "[get_object_name $cell],$ref"
        incr control_cells
      }
    }
    close $control_fd
    puts "ULTRA_OPM_SYNTH_CONTROL_CELLS=$control_cells"
    # A local OPM V2 D/E RTC can prove that the zero-delay implementation is
    # already safe.  Only an explicitly supplied, data-derived window may
    # request added ordinary control buffering; never invent one here.
    if {[info exists ::ULTRA_OPM_CTRL_MIN_NS] && [info exists ::ULTRA_OPM_CTRL_MAX_NS]} {
      set windows "$REPORT_DIR/opm_v2_control_windows_postcompile.rpt"
      set wfd [open $windows w]
      puts $wfd "output,source_q_count,l5_d_count,min_ns,max_ns"
      for {set o 0} {$o < 5} {incr o} {
        set src ""
        set dst ""
        foreach_in_collection pin [get_pins -hierarchical *] {
          set pin_name [get_object_name $pin]
          for {set s 0} {$s < 4} {incr s} {
            if {[string equal [format {outputModules_%d/requestLatches_%d/resettable_latch[0].latch_cell/Q} $o $s] $pin_name]} {
              if {$src eq ""} { set src $pin } else { set src [add_to_collection $src $pin] }
            }
          }
          if {[string equal [format {outputModules_%d/requestOutLatch/resettable_latch[0].latch_cell/D} $o] $pin_name]} {
            set dst $pin
          }
        }
        puts $wfd "$o,[sizeof_collection $src],[sizeof_collection $dst],$::ULTRA_OPM_CTRL_MIN_NS,$::ULTRA_OPM_CTRL_MAX_NS"
        report_timing -delay_type min -from $src -to $dst -max_paths 4 >> $windows
        report_timing -delay_type max -from $src -to $dst -max_paths 4 >> $windows
      }
      close $wfd
    } else {
      puts "ULTRA_OPM_SYNTH_CONTROL_WINDOW=NONE local_DE_RTC_passes_without_added_buffer"
    }
  }
}
ultra_structural_fingerprint "$REPORT_DIR/structure_post_eco.csv" post_eco
async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"
set reset_latches [get_cells -hierarchical -quiet -filter {ref_name =~ LHCNDQD*}]
set reset_latch_count [sizeof_collection $reset_latches]
set v2_plain_latches [get_cells -hierarchical -quiet -filter {full_name =~ *requestOutLatch* && ref_name =~ LHQ*}]
set v2_plain_latch_count [sizeof_collection $v2_plain_latches]
set close_events [get_cells -hierarchical -quiet -filter {full_name =~ *closeEvent*}]
set close_event_count [sizeof_collection $close_events]
puts "ULTRA_RESETTABLE_LATCH_COUNT=$reset_latch_count V2_PLAIN_LATCH_COUNT=$v2_plain_latch_count V2_CLOSE_EVENT_COUNT=$close_event_count"
if {$reset_latch_count == 0 || $v2_plain_latch_count != 0 || $close_event_count == 0} {
  puts "ULTRA_DC_FAIL resettable_latch_or_close_event_structure"
  exit 2
}
# Phase-2 timing-role decomposition is intentionally value-equivalent to the
# former shared UltraArbiterDecision DEL250.  Keep an auditable hierarchy
# report so future one-role experiments cannot silently add, bypass, or merge
# a protected boundary delay.
set role_fd [open "$REPORT_DIR/arbiter_delay_role_cells.csv" w]
puts $role_fd "role,expected_delay_cells,actual_delay_cells,hierarchy_pattern"
set membership_expected 4
set headcapture_expected 5
set anchor_expected 1
set round_close_expected 1
set final_builder_expected 1
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    ($::env(ASYNC_DELAY_PROFILE) eq "ULTRA_P250_PRS_ACG_OPM75_MEM0" ||
     $::env(ASYNC_DELAY_PROFILE) eq "ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0" ||
     [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0*" $::env(ASYNC_DELAY_PROFILE)])} {
  set membership_expected 0
}
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    ($::env(ASYNC_DELAY_PROFILE) eq "ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0" ||
     [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0*" $::env(ASYNC_DELAY_PROFILE)])} {
  set headcapture_expected 0
}
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    ($::env(ASYNC_DELAY_PROFILE) eq "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_ANC0" ||
     [string match "*_ANCST0*" $::env(ASYNC_DELAY_PROFILE)])} {
  set anchor_expected 0
}
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0*" $::env(ASYNC_DELAY_PROFILE)]} {
  set final_builder_expected 0
}
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0*" $::env(ASYNC_DELAY_PROFILE)]} {
  set round_close_expected 0
}
foreach {role expected pattern} [list \
  HeadCapture $headcapture_expected "*head_margin*" \
  Anchor $anchor_expected "*anchor_margin*" \
  RoundClose $round_close_expected "*round_close_margin*" \
  MembershipClose $membership_expected "*member*/close_margin*" \
  FinalBuilder $final_builder_expected "*final_builder_margin*" \
  Return 1 "*return_margin*"] {
  set cells [get_cells -hierarchical -quiet -filter "full_name =~ $pattern"]
  set hierarchy_count [sizeof_collection $cells]
  set actual 0
  foreach_in_collection cell $cells {
    set ref [get_attribute $cell ref_name]
    if {[string match "DEL250D1*" $ref]} { incr actual }
  }
  puts $role_fd "$role,$expected,$actual,$pattern"
  puts "ULTRA_ARBITER_ROLE=$role EXPECTED_DEL250=$expected ACTUAL_DEL250=$actual HIERARCHY_COUNT=$hierarchy_count"
  # The first split run records the physical hierarchy emitted by DC.  A
  # mismatch is evidence to review, not a reason to discard an otherwise
  # valid mapped netlist solely because hierarchy names changed at uniquify.
  if {$actual != $expected} { puts "ULTRA_ARBITER_ROLE_REVIEW=$role" }
  if {$role eq "MembershipClose" && $hierarchy_count != 4} {
    puts "ULTRA_DC_FAIL membership_close_hierarchy_count=$hierarchy_count"
    exit 2
  }
  # Each retained HeadCapture wrapper contributes its wrapper cell plus its
  # named head_margin child in the mapped hierarchy.  Count the explicit
  # DEL250 cells above for timing identity; this structural count is only a
  # lower-bound guard against accidental removal of all five wrappers.
  if {$role eq "HeadCapture" && $hierarchy_count < 5} {
    puts "ULTRA_DC_FAIL head_capture_hierarchy_count=$hierarchy_count"
    exit 2
  }
  if {$role eq "Anchor" && $hierarchy_count < 1} {
    puts "ULTRA_DC_FAIL anchor_margin_hierarchy_count=$hierarchy_count"
    exit 2
  }
  if {$role eq "FinalBuilder" && $hierarchy_count < 1} {
    puts "ULTRA_DC_FAIL final_builder_margin_hierarchy_count=$hierarchy_count"
    exit 2
  }
  if {$role eq "RoundClose" && $hierarchy_count < 1} {
    puts "ULTRA_DC_FAIL round_close_margin_hierarchy_count=$hierarchy_count"
    exit 2
  }
}
# Commit has two separately named DEL250 chains: the ACG Dfire arm and its
# commit-Ack return.  Count them separately so a CACK0 run cannot silently
# keep the Ack DEL or lose the Dfire DEL.
set commit_dfire_cells [get_cells -hierarchical -quiet -filter {full_name =~ *commitController*fire_o_Dfire*}]
set commit_ack_cells [get_cells -hierarchical -quiet -filter {full_name =~ *commitAckDelay*}]
set commit_dfire_expected 1
set commit_dfire_ref "DEL250D1*"
if {$dfire0_profile} {
  set commit_dfire_expected 0
  set commit_dfire_ref "DEL*"
} elseif {$dfire150_profile} {
  set commit_dfire_expected 1
  set commit_dfire_ref "DEL150D1*"
} elseif {$dfire100_profile} {
  set commit_dfire_expected 1
  set commit_dfire_ref "DEL100D1*"
} elseif {$dfire50_profile} {
  set commit_dfire_expected 1
  set commit_dfire_ref "DEL050D1*"
}
set commit_dfire_actual 0
set commit_dfire_control_cells 0
set dfire_cell_fd [open "$REPORT_DIR/dfire_control_cells.rpt" w]
puts $dfire_cell_fd "cell,ref_name"
foreach_in_collection cell $commit_dfire_cells {
  set ref [get_attribute $cell ref_name]
  puts $dfire_cell_fd "[get_object_name $cell],$ref"
  if {[string match $commit_dfire_ref $ref]} { incr commit_dfire_actual }
  if {![string match "DEL*" $ref] && ![string match "DelayElement*" $ref]} {
    incr commit_dfire_control_cells
  }
}
close $dfire_cell_fd
puts "ULTRA_DFIRE_SYNTH_CONTROL_CELLS=$commit_dfire_control_cells"
set commit_ack_expected 1
if {[info exists ::env(ASYNC_DELAY_PROFILE)] &&
    [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0*" $::env(ASYNC_DELAY_PROFILE)]} {
  set commit_ack_expected 0
}
set commit_ack_actual 0
foreach_in_collection cell $commit_ack_cells {
  if {[string match "DEL250D1*" [get_attribute $cell ref_name]]} { incr commit_ack_actual }
}
puts $role_fd "CommitDfire,$commit_dfire_expected,$commit_dfire_actual,commitController.fire_o_Dfire"
puts $role_fd "CommitAck,$commit_ack_expected,$commit_ack_actual,commitAckDelay"
puts "ULTRA_ARBITER_ROLE=CommitDfire EXPECTED_DELAY=$commit_dfire_expected ACTUAL_DELAY=$commit_dfire_actual REF=$commit_dfire_ref"
puts "ULTRA_ARBITER_ROLE=CommitAck EXPECTED_DEL250=$commit_ack_expected ACTUAL_DEL250=$commit_ack_actual"
if {$dfire0_profile && $commit_dfire_actual != $commit_dfire_expected} {
  puts "ULTRA_DC_FAIL commit_dfire_delay_count expected=$commit_dfire_expected actual=$commit_dfire_actual"
  exit 2
}
if {$dfire150_profile && $commit_dfire_actual != $commit_dfire_expected} {
  puts "ULTRA_DC_FAIL commit_dfire_del150_count expected=$commit_dfire_expected actual=$commit_dfire_actual"
  exit 2
}
if {$dfire100_profile && $commit_dfire_actual != $commit_dfire_expected} {
  puts "ULTRA_DC_FAIL commit_dfire_del100_count expected=$commit_dfire_expected actual=$commit_dfire_actual"
  exit 2
}
if {$dfire50_profile && $commit_dfire_actual != $commit_dfire_expected} {
  puts "ULTRA_DC_FAIL commit_dfire_del050_count expected=$commit_dfire_expected actual=$commit_dfire_actual"
  exit 2
}
set prs_cells [get_cells -hierarchical -quiet -filter {full_name =~ *prs*matchedDelay*}]
set prs_hierarchy_count [sizeof_collection $prs_cells]
set prs_expected 5
set prs_ref "DEL250D1*"
if {$prs50_profile} {
  set prs_ref "DEL050D1*"
} elseif {$prs150_profile} {
  set prs_ref "DEL150D1*"
}
set prs_actual 0
foreach_in_collection cell $prs_cells {
  set ref [get_attribute $cell ref_name]
  if {[string match $prs_ref $ref]} { incr prs_actual }
}
puts $role_fd "PrsMatched,$prs_expected,$prs_actual,prs.matchedDelay"
puts "ULTRA_ARBITER_ROLE=PrsMatched EXPECTED_DELAY=$prs_expected ACTUAL_DELAY=$prs_actual REF=$prs_ref HIERARCHY_COUNT=$prs_hierarchy_count"
if {$prs150_profile && ($prs_actual != $prs_expected || $prs_hierarchy_count < 5)} {
  puts "ULTRA_DC_FAIL prs_matched_del150_count expected=$prs_expected actual=$prs_actual hierarchy=$prs_hierarchy_count"
  exit 2
}
if {$prs50_profile && ($prs_actual != $prs_expected || $prs_hierarchy_count < 5)} {
  puts "ULTRA_DC_FAIL prs_matched_del050_count expected=$prs_expected actual=$prs_actual hierarchy=$prs_hierarchy_count"
  exit 2
}
if {$prs_actual != $prs_expected} { puts "ULTRA_ARBITER_ROLE_REVIEW=PrsMatched" }
if {$commit_dfire_actual != $commit_dfire_expected} { puts "ULTRA_ARBITER_ROLE_REVIEW=CommitDfire" }
if {$commit_ack_actual != $commit_ack_expected} { puts "ULTRA_ARBITER_ROLE_REVIEW=CommitAck" }
close $role_fd
report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 50 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 50 > "$REPORT_DIR/timing_min.rpt"
if {$ng > 0 || $nu > 0} { puts "ULTRA_DC_FAIL gtech=$ng unmapped=$nu"; exit 2 }
write -hierarchy -format ddc -output "$OUTPUT_DIR/UltraRouter.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/UltraRouter_post.v"
write_sdf "$OUTPUT_DIR/UltraRouter.sdf"
write_sdc "$OUTPUT_DIR/UltraRouter.sdc"
exec sha256sum "$OUTPUT_DIR/UltraRouter.ddc" "$OUTPUT_DIR/UltraRouter_post.v" "$OUTPUT_DIR/UltraRouter.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "ULTRA_DC_PASS output=$OUTPUT_DIR"
quit
