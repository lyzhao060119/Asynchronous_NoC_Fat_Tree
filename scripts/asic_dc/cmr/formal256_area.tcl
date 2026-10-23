# Read-only area extraction from the frozen full-network DDC.
set root $::env(FORMAL256_ROOT)
set project /home/ghy19/Asynchronous_Router_CMR
set design $::env(FORMAL256_DESIGN)
if {$design eq "Mesh256"} {
  set run 20261018_123500_mesh256_xfirsty_tt_resynth_r1
  set top CMRMeshNoC
} elseif {$design eq "M16_256"} {
  set run 20261019_085616_m16_dc256_tt_r1
  set top PROP_temp256_m16
} else {error "unknown design"}
set ::env(CMR_LIBRARY_CORNER) tt0p8v25c
source "$project/rtl/tech_t28ss.tcl"
file mkdir "$root/area/$design"
read_ddc "$project/outputs/$run/$top.ddc"
current_design $top
if {![link]} {error "DDC link failed"}
redirect "$root/area/$design/area.rpt" {report_area -hierarchy}
redirect "$root/area/$design/references.rpt" {report_reference -hierarchy}
set n [sizeof_collection [get_cells -hierarchical -filter {is_hierarchical == false}]]
set report_file [open "$root/area/$design/area.rpt" r]
set area_report [read $report_file]
close $report_file
if {![regexp {Total cell area:\s+([0-9]+\.[0-9]+)} $area_report unused a]} {
  error "report_area has no numeric total cell area"
}
if {![string is double -strict $a] || $a <= 0 || $n <= 0} {error "empty area or leaf-cell count"}
set f [open "$root/area/$design/area.csv" w]
puts $f "design,run_id,corner,cell_area_um2,leaf_cells"
puts $f "$design,$run,tt0p8v25c,$a,$n"
close $f
puts "FORMAL256_AREA_PASS design=$design area=$a leaf_cells=$n"
quit
