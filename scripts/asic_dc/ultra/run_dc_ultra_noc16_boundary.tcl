# Unified DC entry for NoC16 plus the structural asynchronous endpoint bank.
# One elaborate/write operation prevents parameter-specialized Verilog modules
# from being redefined by separately synthesized partitions during GLS.
set PROJECT_DIR [expr {[info exists ::env(ULTRA_REMOTE_ROOT)] ? $::env(ULTRA_REMOTE_ROOT) : "/home/ghy19/Asynchronous_Router_ultra"}]
set RTL_DIR "$PROJECT_DIR/rtl"
set RUN_ID $::env(ULTRA_NOC16_RUN_ID)
set ENDPOINT_ACK_DELAY_PS [expr {[info exists ::env(ULTRA_ENDPOINT_ACK_DELAY_PS)] ? $::env(ULTRA_ENDPOINT_ACK_DELAY_PS) : 50}]
if {$ENDPOINT_ACK_DELAY_PS ni {50 75 100 150 250}} {
  puts "ULTRA_BOUNDARY_DC_FAIL invalid_endpoint_ack_delay_ps=$ENDPOINT_ACK_DELAY_PS"
  exit 2
}
set REPORT_DIR "$PROJECT_DIR/reports/dc/$RUN_ID/boundary"
set OUTPUT_DIR "$PROJECT_DIR/outputs/$RUN_ID/boundary"
set WORK_LIB "$PROJECT_DIR/sim/work/dc_boundary_$RUN_ID"
file mkdir $REPORT_DIR; file mkdir $OUTPUT_DIR; file mkdir $WORK_LIB

source "$RTL_DIR/tech_t28ss.tcl"
define_design_lib WORK -path $WORK_LIB
set ENDPOINT_ACK_DELAY_DEFINE [format "ASYNC_ENDPOINT_ACK_DELAY_%03d" $ENDPOINT_ACK_DELAY_PS]
# DC accepts one -define list.  Two separate -define switches leave ASIC_T28
# inactive in this tool version, which turns every V2CloseEvent into GTECH_NOT.
set RTL_DEFINES [list ASIC_T28 $ENDPOINT_ACK_DELAY_DEFINE]
analyze -format sverilog -define $RTL_DEFINES -work WORK [list \
  "$RTL_DIR/DelayElement_ASIC.v" "$RTL_DIR/Mutex2_ASIC.v" \
  "$RTL_DIR/MullerC2.v" "$RTL_DIR/MullerC3.v" "$RTL_DIR/DLatchBank.v" "$RTL_DIR/V2CloseEvent.v" \
  "$RTL_DIR/AsyncEndpointAckDelay.v" \
  "$RTL_DIR/MousetrapStage.v" "$RTL_DIR/TAC2.v" "$RTL_DIR/Mutex3Grant.v" \
  "$RTL_DIR/Mutex5Anchor.v" "$RTL_DIR/UltraHeadCaptureCell.v" \
  "$RTL_DIR/AsyncRoundMembershipCell.v" "$RTL_DIR/AsyncRoundDecisionCell.v" \
  "$RTL_DIR/AsyncArbiterTransactionController.v" "$RTL_DIR/NoC_16nodes.v" \
  "$RTL_DIR/AsyncEndpointBank20.sv" "$RTL_DIR/async_noc16_port_adapter.sv" \
  "$RTL_DIR/AsyncNoC16BoundaryDUT.sv"]
elaborate AsyncNoC16BoundaryDUT -work WORK
current_design AsyncNoC16BoundaryDUT
uniquify; link
check_design > "$REPORT_DIR/check_design_pre.rpt"
source "$RTL_DIR/async_primitives.tcl"
set_ungroup [get_designs *] false
set_boundary_optimization [get_designs *] false
compile_ultra -no_autoungroup
check_design > "$REPORT_DIR/check_design_post.rpt"
source "$RTL_DIR/assert_no_gtech.tcl"
set ng [async_assert_no_gtech $REPORT_DIR]
set nu [async_assert_no_seqgen $REPORT_DIR]
async_report_primitive_counts "$REPORT_DIR/async_primitives.csv"

# Preserve the zero-delay experimental hierarchy: the physical DEL cells may
# disappear, but every HeadCapture/Member margin boundary must remain visible
# in the mapped NoC so this cannot silently become an unrelated optimization.
set profile [expr {[info exists ::env(ASYNC_DELAY_PROFILE)] ? $::env(ASYNC_DELAY_PROFILE) : "UNSET"}]
set hc_expected_del 25
set member_expected_del 20
set fb_expected_del 5
set rc_expected_del 5
if {$profile eq "ULTRA_P250_PRS_ACG_OPM75_MEM0" ||
    $profile eq "ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0" ||
    [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0*" $profile]} {
  set member_expected_del 0
}
if {$profile eq "ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0" ||
    [string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0*" $profile]} {
  set hc_expected_del 0
}
if {[string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0*" $profile]} {
  set fb_expected_del 0
}
if {[string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0*" $profile]} {
  set rc_expected_del 0
}
set hc_cells [get_cells -hierarchical -quiet -filter {full_name =~ *head_margin*}]
set member_cells [get_cells -hierarchical -quiet -filter {full_name =~ *member*/close_margin*}]
set fb_cells [get_cells -hierarchical -quiet -filter {full_name =~ *final_builder_margin*}]
set rc_cells [get_cells -hierarchical -quiet -filter {full_name =~ *round_close_margin*}]
set commit_ack_cells [get_cells -hierarchical -quiet -filter {full_name =~ *commitAckDelay*}]
set commit_dfire_cells [get_cells -hierarchical -quiet -filter {full_name =~ *commitController*fire_o_Dfire*}]
set hc_hierarchy_count [sizeof_collection $hc_cells]
set member_hierarchy_count [sizeof_collection $member_cells]
set fb_hierarchy_count [sizeof_collection $fb_cells]
set rc_hierarchy_count [sizeof_collection $rc_cells]
set commit_ack_hierarchy_count [sizeof_collection $commit_ack_cells]
set hc_actual_del 0
foreach_in_collection cell $hc_cells {
  if {[string match "DEL250D1*" [get_attribute $cell ref_name]]} { incr hc_actual_del }
}
set member_actual_del 0
foreach_in_collection cell $member_cells {
  if {[string match "DEL250D1*" [get_attribute $cell ref_name]]} { incr member_actual_del }
}
set fb_actual_del 0
foreach_in_collection cell $fb_cells {
  if {[string match "DEL250D1*" [get_attribute $cell ref_name]]} { incr fb_actual_del }
}
set rc_actual_del 0
foreach_in_collection cell $rc_cells {
  if {[string match "DEL250D1*" [get_attribute $cell ref_name]]} { incr rc_actual_del }
}
set commit_ack_expected_del 5
if {[string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0*" $profile]} {
  set commit_ack_expected_del 0
}
set commit_ack_actual_del 0
foreach_in_collection cell $commit_ack_cells {
  if {[string match "DEL250D1*" [get_attribute $cell ref_name]]} { incr commit_ack_actual_del }
}
set commit_dfire_hierarchy_count [sizeof_collection $commit_dfire_cells]
set commit_dfire_expected_del 5
set commit_dfire_ref "DEL250D1*"
if {[string match "*_DFIRE0" $profile]} {
  set commit_dfire_expected_del 0
  set commit_dfire_ref "DEL*"
} elseif {[string match "*_DFIRE150" $profile]} {
  set commit_dfire_expected_del 5
  set commit_dfire_ref "DEL150D1*"
} elseif {[string match "*_DFIRE100" $profile]} {
  set commit_dfire_expected_del 5
  set commit_dfire_ref "DEL100D1*"
} elseif {[string match "*_DFIRE50" $profile] || [string match "*_DFIRE50_*" $profile]} {
  set commit_dfire_expected_del 5
  set commit_dfire_ref "DEL050D1*"
}
set commit_dfire_actual_del 0
foreach_in_collection cell $commit_dfire_cells {
  if {[string match $commit_dfire_ref [get_attribute $cell ref_name]]} { incr commit_dfire_actual_del }
}
puts "ULTRA_BOUNDARY_ARBITER_MARGIN PROFILE=$profile HC_EXPECTED_DEL250=$hc_expected_del HC_ACTUAL_DEL250=$hc_actual_del HC_HIERARCHY_COUNT=$hc_hierarchy_count MEMBER_EXPECTED_DEL250=$member_expected_del MEMBER_ACTUAL_DEL250=$member_actual_del MEMBER_HIERARCHY_COUNT=$member_hierarchy_count FB_EXPECTED_DEL250=$fb_expected_del FB_ACTUAL_DEL250=$fb_actual_del FB_HIERARCHY_COUNT=$fb_hierarchy_count RC_EXPECTED_DEL250=$rc_expected_del RC_ACTUAL_DEL250=$rc_actual_del RC_HIERARCHY_COUNT=$rc_hierarchy_count CACK_EXPECTED_DEL250=$commit_ack_expected_del CACK_ACTUAL_DEL250=$commit_ack_actual_del CACK_HIERARCHY_COUNT=$commit_ack_hierarchy_count DFIRE_EXPECTED_DELAY=$commit_dfire_expected_del DFIRE_ACTUAL_DELAY=$commit_dfire_actual_del DFIRE_REF=$commit_dfire_ref DFIRE_HIERARCHY_COUNT=$commit_dfire_hierarchy_count"
if {$hc_hierarchy_count != 25 || $member_hierarchy_count != 20 ||
    $hc_actual_del != $hc_expected_del || $member_actual_del != $member_expected_del} {
  puts "ULTRA_BOUNDARY_DC_FAIL arbiter_margin_structure"
  exit 2
}
if {[string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0*" $profile] &&
    ($fb_hierarchy_count < 5 || $fb_actual_del != $fb_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL final_builder_margin_structure hierarchy=$fb_hierarchy_count del=$fb_actual_del expected=$fb_expected_del"
  exit 2
}
if {[string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0*" $profile] &&
    ($rc_hierarchy_count < 5 || $rc_actual_del != $rc_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL round_close_margin_structure hierarchy=$rc_hierarchy_count del=$rc_actual_del expected=$rc_expected_del"
  exit 2
}
if {[string match "ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0*" $profile] &&
    ($commit_ack_hierarchy_count < 5 || $commit_ack_actual_del != $commit_ack_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL commit_ack_margin_structure hierarchy=$commit_ack_hierarchy_count del=$commit_ack_actual_del expected=$commit_ack_expected_del"
  exit 2
}
if {[string match "*_DFIRE0" $profile] &&
    ($commit_dfire_hierarchy_count < 5 || $commit_dfire_actual_del != $commit_dfire_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL commit_dfire_margin_structure hierarchy=$commit_dfire_hierarchy_count del=$commit_dfire_actual_del expected=$commit_dfire_expected_del"
  exit 2
}
if {[string match "*_DFIRE150" $profile] &&
    ($commit_dfire_hierarchy_count < 5 || $commit_dfire_actual_del != $commit_dfire_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL commit_dfire_del150_structure hierarchy=$commit_dfire_hierarchy_count del=$commit_dfire_actual_del expected=$commit_dfire_expected_del"
  exit 2
}
if {[string match "*_DFIRE100" $profile] &&
    ($commit_dfire_hierarchy_count < 5 || $commit_dfire_actual_del != $commit_dfire_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL commit_dfire_del100_structure hierarchy=$commit_dfire_hierarchy_count del=$commit_dfire_actual_del expected=$commit_dfire_expected_del"
  exit 2
}
if {[string match "*_DFIRE50" $profile] || [string match "*_DFIRE50_*" $profile]} {
  if {$commit_dfire_hierarchy_count < 5 || $commit_dfire_actual_del != $commit_dfire_expected_del} {
    puts "ULTRA_BOUNDARY_DC_FAIL commit_dfire_del050_structure hierarchy=$commit_dfire_hierarchy_count del=$commit_dfire_actual_del expected=$commit_dfire_expected_del"
    exit 2
  }
}
set prs_cells [get_cells -hierarchical -quiet -filter {full_name =~ *prs*matchedDelay*}]
set prs_hierarchy_count [sizeof_collection $prs_cells]
set prs_expected_del 25
set prs_ref "DEL250D1*"
if {[string match "*_PRS50" $profile]} {
  set prs_ref "DEL050D1*"
} elseif {[string match "*_PRS150" $profile]} {
  set prs_ref "DEL150D1*"
}
set prs_actual_del 0
foreach_in_collection cell $prs_cells {
  if {[string match $prs_ref [get_attribute $cell ref_name]]} { incr prs_actual_del }
}
puts "ULTRA_BOUNDARY_PRS PROFILE=$profile PRS_EXPECTED_DELAY=$prs_expected_del PRS_ACTUAL_DELAY=$prs_actual_del PRS_REF=$prs_ref PRS_HIERARCHY_COUNT=$prs_hierarchy_count"
if {[string match "*_PRS150" $profile] &&
    ($prs_hierarchy_count < 25 || $prs_actual_del != $prs_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL prs_matched_del150_structure hierarchy=$prs_hierarchy_count del=$prs_actual_del expected=$prs_expected_del"
  exit 2
}
if {[string match "*_PRS50" $profile] &&
    ($prs_hierarchy_count < 25 || $prs_actual_del != $prs_expected_del)} {
  puts "ULTRA_BOUNDARY_DC_FAIL prs_matched_del050_structure hierarchy=$prs_hierarchy_count del=$prs_actual_del expected=$prs_expected_del"
  exit 2
}

report_qor > "$REPORT_DIR/qor.rpt"
report_timing -delay_type max -max_paths 100 > "$REPORT_DIR/timing_max.rpt"
report_timing -delay_type min -max_paths 100 > "$REPORT_DIR/timing_min.rpt"
if {$ng > 0 || $nu > 0} { puts "ULTRA_BOUNDARY_DC_FAIL gtech=$ng unmapped=$nu"; exit 2 }
write -hierarchy -format ddc -output "$OUTPUT_DIR/AsyncNoC16BoundaryDUT.ddc"
write -hierarchy -format verilog -output "$OUTPUT_DIR/AsyncNoC16BoundaryDUT_post.v"
write_sdf "$OUTPUT_DIR/AsyncNoC16BoundaryDUT.sdf"
write_sdc "$OUTPUT_DIR/AsyncNoC16BoundaryDUT.sdc"
set post_file "$OUTPUT_DIR/AsyncNoC16BoundaryDUT_post.v"
set prsready_text [exec grep -c "PRSReady" $post_file]
set endpoint_text [exec grep -c "AsyncEndpointBank20" $post_file]
set latch_text [exec grep -c "LHCNDQD" $post_file]
set ack_delay_text [exec grep -c "sink_ack_delay" $post_file]
set ack_cell_text [exec grep -c "DEL0${ENDPOINT_ACK_DELAY_PS}D1BWP12T30P140" $post_file]
puts "ULTRA_BOUNDARY_STRUCTURE PRSREADY_TEXT=$prsready_text ENDPOINT_TEXT=$endpoint_text LATCH_TEXT=$latch_text ACK_DELAY_TEXT=$ack_delay_text ACK_DELAY_PS=$ENDPOINT_ACK_DELAY_PS ACK_CELL_TEXT=$ack_cell_text"
if {$prsready_text == 0 || $endpoint_text == 0 || $latch_text < 40 || $ack_delay_text < 20 || $ack_cell_text < 20} {
  puts "ULTRA_BOUNDARY_DC_FAIL missing_prsready_or_endpoint_latches"
  exit 2
}
exec sha256sum "$OUTPUT_DIR/AsyncNoC16BoundaryDUT.ddc" "$OUTPUT_DIR/AsyncNoC16BoundaryDUT_post.v" "$OUTPUT_DIR/AsyncNoC16BoundaryDUT.sdf" > "$REPORT_DIR/post_hashes.sha256"
puts "ULTRA_BOUNDARY_DC_PASS output=$OUTPUT_DIR"
quit
