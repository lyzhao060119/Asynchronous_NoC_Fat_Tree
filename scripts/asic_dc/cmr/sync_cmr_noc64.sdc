# Clocked SyncNoC_64nodes.  Signed period is 1.0 ns (Thin and Fat 1-2-2-2).
# See docs/CMR_Sync64_Clock_Freeze.md.  Override only for a new run_id.
# No DelayElement / Ackin cells.
set clk_ns 1.0
if {[info exists ::env(CMR_SYNC64_CLOCK_PERIOD_NS)] && $::env(CMR_SYNC64_CLOCK_PERIOD_NS) ne ""} {
  set clk_ns $::env(CMR_SYNC64_CLOCK_PERIOD_NS)
}
create_clock -name CLK -period $clk_ns [get_ports clock]
set_clock_latency 0.0 [get_clocks CLK]
set_clock_transition 0.05 [get_clocks CLK]
set_clock_uncertainty -setup [expr {$clk_ns * 0.05}] [get_clocks CLK]
set_clock_uncertainty -hold 0.02 [get_clocks CLK]
set_dont_touch_network [get_ports clock]
set_ideal_network [get_ports clock]
set_ideal_network [get_ports reset]
set_false_path -from [get_ports reset]

set io_pct 0.10
if {[info exists ::env(CMR_SYNC64_IO_DELAY_FRAC)] && $::env(CMR_SYNC64_IO_DELAY_FRAC) ne ""} {
  set io_pct $::env(CMR_SYNC64_IO_DELAY_FRAC)
}
set io_delay [expr {$clk_ns * $io_pct}]
set clk_ports [get_ports {clock reset}]
set data_in [remove_from_collection [all_inputs] $clk_ports]
if {[sizeof_collection $data_in] > 0} {
  set_input_delay $io_delay -clock CLK $data_in
}
if {[sizeof_collection [all_outputs]] > 0} {
  set_output_delay $io_delay -clock CLK [all_outputs]
}
