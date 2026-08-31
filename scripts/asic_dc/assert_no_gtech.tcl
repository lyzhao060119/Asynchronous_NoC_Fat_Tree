# Assert no leftover GTECH / SEQGEN / synthetic ops after compile; remap if needed.
# Source after compile_ultra / design-rule compile, before write.

proc async_assert_no_gtech {report_dir} {
  set gtech_cells [get_cells -hierarchical -quiet -filter {ref_name =~ GTECH*}]
  set n [sizeof_collection $gtech_cells]
  puts "INFO: GTECH cell count after compile = $n"
  set fd [open "$report_dir/gtech_cell_count.txt" w]
  puts $fd "gtech_count,$n"
  close $fd

  if {$n == 0} {
    return 0
  }

  puts "WARN: remapping $n GTECH_* cells via compile_ultra -incremental"
  compile_ultra -incremental
  set gtech_cells [get_cells -hierarchical -quiet -filter {ref_name =~ GTECH*}]
  set n [sizeof_collection $gtech_cells]
  puts "INFO: GTECH cell count after incremental = $n"
  set fd [open "$report_dir/gtech_cell_count.txt" w]
  puts $fd "gtech_count,$n"
  close $fd

  if {$n > 0} {
    set_dont_touch $gtech_cells false
    compile_ultra -incremental
    set gtech_cells [get_cells -hierarchical -quiet -filter {ref_name =~ GTECH*}]
    set n [sizeof_collection $gtech_cells]
    puts "INFO: GTECH cell count after force remap = $n"
    set fd [open "$report_dir/gtech_cell_count.txt" w]
    puts $fd "gtech_count,$n"
    close $fd
  }

  if {$n > 0} {
    puts "ERROR: still have $n GTECH_* cells — gate-level SDF E2E will be incomplete"
    report_reference -nosplit > "$report_dir/gtech_leftover_refs.rpt"
    set gfd [open "$report_dir/gtech_instances.rpt" w]
    foreach_in_collection gc $gtech_cells {
      puts $gfd "[get_attribute $gc full_name],[get_attribute $gc ref_name]"
    }
    close $gfd
  }
  return $n
}

proc async_assert_no_seqgen {report_dir} {
  set seq [get_cells -hierarchical -quiet -filter {ref_name =~ *SEQGEN*}]
  set n_seq [sizeof_collection $seq]
  set n_eq [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ *EQ_UNS_OP*}]]
  set n_add [sizeof_collection [get_cells -hierarchical -quiet -filter {ref_name =~ *ADD_UNS_OP*}]]
  set fd [open "$report_dir/unmapped_cell_count.txt" w]
  puts $fd "seqgen_count,$n_seq"
  puts $fd "eq_uns_op_count,$n_eq"
  puts $fd "add_uns_op_count,$n_add"
  close $fd
  puts "INFO: SEQGEN=$n_seq EQ_UNS_OP=$n_eq ADD_UNS_OP=$n_add"
  if {$n_seq > 0 || $n_eq > 0} {
    puts "ERROR: unmapped generic cells remain — refusing clean GLS netlist"
    return 1
  }
  return 0
}
