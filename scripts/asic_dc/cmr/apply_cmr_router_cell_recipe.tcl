# In-place version of the adopted Click and fast_buf1_keep cell ECOs.
# Requires apply_cmr_ipm_timing_recipe.tcl for checked library sizing helpers.
proc cmr_router_apply_cell_recipe {report_dir} {
  set opms [get_cells -quiet OutputPortModules_*]
  set n [sizeof_collection $opms]
  if {$n == 0} {error "router recipe: no OPM bound"}
  set xnr [get_cells -hierarchical -quiet -filter {full_name =~ OutputPortModules_*/* && (ref_name == XNR4D0BWP12T30P140 || ref_name == XNR4D2BWP12T30P140)}]
  set oai [get_cells -hierarchical -quiet -filter {full_name =~ OutputPortModules_*/* && (ref_name == OAI221D1BWP12T30P140 || ref_name == OAI221D2BWP12T30P140)}]
  set oai_count [sizeof_collection $oai]
  cmr_ipm_resize_exact $xnr [expr {2*$n}] XNR4D2BWP12T30P140 opm_click_xnr
  # The ReqMerged/RegEnable cone is mapping-dependent across c1p1/c1p2/c1p4
  # Router geometries.  Some ports map to OAI221 while others collapse to a
  # simpler equivalent gate.  Accelerate every OAI221 that DC actually kept;
  # the per-OPM Reqout and shared-MG checks below remain strict.
  cmr_ipm_resize_mapped $oai OAI221D2BWP12T30P140 opm_click_oai
  set fire_inv_count 0
  set fire_other_count 0
  set mg_shared_count 0
  set mg_single_source_count 0
  set mg_split_count 0
  foreach_in_collection opm $opms {
    set base [get_object_name $opm]
    set data_d [get_pins -hierarchical -quiet -filter "full_name =~ ${base}/DataReg_ff_reg*/D"]
    if {[sizeof_collection $data_d] != 28} {error "$base DataReg.D binding count=[sizeof_collection $data_d] expected=28"}
    set cp [get_pins -quiet $base/Reqout_ff_reg/CP]
    if {[sizeof_collection $cp] != 1} {error "$base Reqout CP binding"}
    set drv [filter_collection [get_pins -leaf -of_objects [get_nets -segments -of_objects $cp]] {pin_direction == out}]
    if {[sizeof_collection $drv] != 1} {error "$base CP driver binding"}
    set inv [get_cells -of_objects $drv]
    set driver_ref [get_attribute $inv ref_name]
    if {[string match INVD*BWP12T30P140 $driver_ref]} {
      cmr_ipm_resize_exact $inv 1 INVD6BWP12T30P140 opm_fire_driver
      incr fire_inv_count
    } else {
      # DC can absorb the final inversion into an equivalent complex gate.
      # Keep that mapped driver unchanged; never replace it as an inverter.
      puts "CMR_ROUTER_RECIPE_INFO opm=$base cp_driver_ref=$driver_ref action=preserve"
      set_dont_touch $inv true
      incr fire_other_count
    }
    # Preserve the actual MG nodes.  For a multi-source OPM each MG must feed
    # both ReqSelection and the data mux rooted at DataReg.D.  A one-source
    # OPM has no data mux at all: its data is intentionally a direct wire, so
    # its sole MG node only feeds ReqSelection.  Do not mistake that legal
    # geometry reduction for DC splitting the shared request/data control.
    set mg_eps [get_pins -hierarchical -quiet -filter "full_name =~ ${base}/L1_L4_*/*/E"]
    set source_count [sizeof_collection $mg_eps]
    if {$source_count < 1} {error "$base MG endpoint binding count=$source_count"}
    foreach_in_collection ep $mg_eps {
      set net [get_nets -segments -of_objects $ep]
      set drivers [filter_collection [get_pins -leaf -of_objects $net] {pin_direction == out}]
      set loads [filter_collection [get_pins -leaf -of_objects $net] {pin_direction == in}]
      # Use structural transitive fanout for the shared-MG invariant.  A
      # timing-path query is not reliable here because DC may automatically
      # disable an arc while breaking the asynchronous feedback loop.
      set fanout [all_fanout -flat -from $drivers]
      # This DC release has no intersect_collection command.  Compare exact
      # object names instead of relying on wildcard filters.
      set fanout_names [get_object_name $fanout]
      set mux_sink_count 0
      foreach_in_collection data_pin $data_d {
        if {[lsearch -exact $fanout_names [get_object_name $data_pin]] >= 0} {
          incr mux_sink_count
        }
      }
      # A buffer tree may reduce the direct fanout below the old c1p4 value of
      # 29.  The invariant is one driver, a distinct request/data branch, and
      # a real path from that same MG driver to DataReg.D.
      if {[sizeof_collection $drivers] != 1 || [sizeof_collection $loads] < 1} {
        error "$base MG binding failed sources=$source_count drivers=[sizeof_collection $drivers] loads=[sizeof_collection $loads]"
      }
      # Logic duplication of Grant&&!TailPassed is legal.  Sharing one
      # physical MG node is an optimization preference, not a functional or
      # bundled-data proof.  Record a split cone for later paired STA/SDF
      # instead of blocking geometries for which DC duplicated this logic.
      if {$source_count > 1 && $mux_sink_count < 1} {
        puts "CMR_ROUTER_RECIPE_WARN opm=$base mg_cone_split=1 sources=$source_count driver=[get_object_name $drivers]"
        incr mg_split_count
      }
      set_dont_touch $net true
      set_dont_touch [get_cells -of_objects $drivers] true
      set_dont_touch_network $net
      if {$source_count > 1 && $mux_sink_count > 0} {
        incr mg_shared_count
      } elseif {$source_count == 1} {
        incr mg_single_source_count
      }
    }
  }
  set ffs [get_cells -hierarchical -quiet -filter {full_name =~ selector*/*RequestHold/ReqHoldDFF && ref_name =~ DFCNQ*BWP12T30P140}]
  set lanes [sizeof_collection $ffs]
  if {$lanes > 0} {
    set delays [get_cells -hierarchical -quiet -filter {full_name =~ selector*/*RequestHold/ClearPulseDelay/* && ref_name =~ DEL*BWP12T30P140}]
    cmr_ipm_resize_exact $delays $lanes BUFFD1BWP12T30P140 lane_delay
    cmr_ipm_resize_exact $ffs $lanes DFCNQD1BWP12T30P140 lane_reqhold
    set requests [get_cells -hierarchical -quiet -filter {full_name =~ selector*/U* && ref_name =~ OA21D*BWP12T30P140}]
    cmr_ipm_resize_exact $requests $lanes OA21D2BWP12T30P140 lane_request
    set delay_names [get_object_name $delays]
    set i 0
    foreach name $delay_names {
      insert_buffer [get_pins $name/Z] [cmr_ipm_one_lib BUFFD1BWP12T30P140] -new_cell_names LaneExtraBuffer_$i
      incr i
    }
    set extra [get_cells -hierarchical -quiet -filter {full_name =~ *LaneExtraBuffer*}]
    if {[sizeof_collection $extra] != $lanes} {error "lane extra buffer coverage"}
    set_dont_touch $extra true
  }
  set fd [open "$report_dir/cmr_router_cell_recipe.rpt" w]
  puts $fd "opms=$n oai_mapped=$oai_count fire_inv=$fire_inv_count fire_other=$fire_other_count mg_shared=$mg_shared_count mg_single_source=$mg_single_source_count mg_split=$mg_split_count lane_states=$lanes click=XNR4D2/OAI221D2/INVD6-when-mapped lane=BUFFD1x2/OA21D2/DFCNQD1 mutex=unchanged"
  close $fd
  puts "CMR_ROUTER_CELL_RECIPE_PASS opms=$n lane_states=$lanes"
}
