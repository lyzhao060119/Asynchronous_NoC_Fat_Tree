create_clock -name CLK -period 10.0 [get_ports clock]
set_clock_latency 0.3 [get_clocks CLK]
set_clock_transition 0.1 [get_clocks CLK]
set_clock_uncertainty 0.1 [get_clocks CLK]
set_dont_touch_network [get_ports clock]
set_ideal_network [get_ports reset]

# CMR has no RTL delay lines. Paired bundled-data requirements are recorded in
# docs/CMR_DC_Timing_Intent.md and are applied once characterized bounds are
# available for the target library and physical implementation.
