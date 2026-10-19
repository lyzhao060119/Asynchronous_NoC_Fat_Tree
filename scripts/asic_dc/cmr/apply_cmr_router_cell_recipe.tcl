# In-place version of the adopted Click and fast_buf1_keep cell ECOs.
# Requires apply_cmr_ipm_timing_recipe.tcl for checked library sizing helpers.
proc cmr_router_apply_cell_recipe {report_dir} {
  set opms [get_cells -quiet OutputPortModules_*]
  set n [sizeof_collection $opms]
  if {$n == 0} {error "router recipe: no OPM bound"}
  set xnr [get_cells -hierarchical -quiet -filter {full_name =~ OutputPortModules_*/* && (ref_name == XNR4D0BWP12T30P140 || ref_name == XNR4D2BWP12T30P140)}]
  set oai [get_cells -hierarchical -quiet -filter {full_name =~ OutputPortModules_*/* && (ref_name == OAI221D1BWP12T30P140 || ref_name == OAI221D2BWP12T30P140)}]
  cmr_ipm_resize_exact $xnr [expr {2*$n}] XNR4D2BWP12T30P140 opm_click_xnr
  cmr_ipm_resize_exact $oai $n OAI221D2BWP12T30P140 opm_click_oai
  foreach_in_collection opm $opms {
    set base [get_object_name $opm]
    set cp [get_pins -quiet $base/Reqout_ff_reg/CP]
    if {[sizeof_collection $cp] != 1} {error "$base Reqout CP binding"}
    set drv [filter_collection [get_pins -leaf -of_objects [get_nets -segments -of_objects $cp]] {pin_direction == out}]
    if {[sizeof_collection $drv] != 1} {error "$base CP driver binding"}
    set inv [get_cells -of_objects $drv]
    if {![string match INVD*BWP12T30P140 [get_attribute $inv ref_name]]} {error "$base CP driver is not inverter"}
    cmr_ipm_resize_exact $inv 1 INVD6BWP12T30P140 opm_fire_driver
    # Preserve the actual shared MG node; reject a split request/data source.
    foreach_in_collection ep [get_pins -hierarchical -quiet -filter "full_name =~ ${base}/L1_L4_*/*/E"] {
      set net [get_nets -segments -of_objects $ep]
      set drivers [filter_collection [get_pins -leaf -of_objects $net] {pin_direction == out}]
      set loads [filter_collection [get_pins -leaf -of_objects $net] {pin_direction == in}]
      if {[sizeof_collection $drivers] != 1 || [sizeof_collection $loads] < 29} {error "$base MG shared-load check failed"}
      set_dont_touch $net true
      set_dont_touch [get_cells -of_objects $drivers] true
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
  puts $fd "opms=$n lane_states=$lanes click=XNR4D2/OAI221D2/INVD6 lane=BUFFD1x2/OA21D2/DFCNQD1 mutex=unchanged"
  close $fd
  puts "CMR_ROUTER_CELL_RECIPE_PASS opms=$n lane_states=$lanes"
}
