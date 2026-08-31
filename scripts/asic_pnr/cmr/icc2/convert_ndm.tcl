# Build a one-time NDM from TSMC 28HPC+ LEF + CCS DB for ICC2.
# Usage: icc2_lm_shell -batch -file convert_ndm.tcl

source [file join [file dirname [info script]] .. tech_t28hpc_pnr.tcl]

if {![info exists ::env(CMR_PNR_NDM_OUT)] || $::env(CMR_PNR_NDM_OUT) eq ""} {
  puts "CMR_PNR_FAIL missing CMR_PNR_NDM_OUT"
  exit 2
}
set ndm_out $::env(CMR_PNR_NDM_OUT)
if {[file exists $ndm_out]} {
  puts "CMR_NDM_EXISTS $ndm_out"
  exit 0
}
file mkdir [file dirname $ndm_out]

create_workspace -flow physical cmr_t28_bwp12t30p140
if {[catch { read_lef $CMR_PNR_LEF } err]} {
  puts "CMR_PNR_FAIL read_lef $err"
  exit 2
}
if {$CMR_PNR_DB ne ""} {
  if {[catch { read_db $CMR_PNR_DB } err]} {
    puts "CMR_PNR_WARN read_db $err"
    if {$CMR_PNR_LIBERTY ne "" && [catch { read_lib $CMR_PNR_LIBERTY } err2]} {
      puts "CMR_PNR_FAIL read_lib $err2"
      exit 2
    }
  }
} elseif {$CMR_PNR_LIBERTY ne ""} {
  if {[catch { read_lib $CMR_PNR_LIBERTY } err]} {
    puts "CMR_PNR_FAIL read_lib $err"
    exit 2
  }
} else {
  puts "CMR_PNR_FAIL no_timing_lib"
  exit 2
}
if {[catch { commit_workspace -output $ndm_out } err]} {
  puts "CMR_PNR_FAIL commit_workspace $err"
  exit 2
}
puts "CMR_NDM_OK $ndm_out"
exit
