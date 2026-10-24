# Synchronous Router clock-gating comparison

Paired frozen RTL; TT 0.8 V 25 C, 1 ns clock. Post-synthesis; no extracted routing or physical CTS.
Latency: mean input-to-output acceptance across five isolated low-switching flits. Power: random five-flit single packet, three seeds; whole DUT internal+switching+leakage, 50ps slew,5fF load; 140 transported bits/packet.
Guard5 includes tail release and 5 ns extension. Idle is tail+10..20 ns. Gating inserted automatically using mapped integrated gates.

|Config|ICGs|Area um2|Isolated ns|Active mW|Packet pJ|pJ/bit|Guard5 pJ|Idle mW|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|sync_c1p1_ungated|0|6749.231938|1.000000|4.111000|20.555000|0.146821|37.836667|3.509667|
|sync_c1p1_cg|65|6139.055926|1.000000|1.380333|6.901667|0.049298|10.486667|0.630400|
|sync_c1p4_ungated|0|11483.135891|1.000000|6.572333|32.861667|0.234726|61.380000|5.839000|
|sync_c1p4_cg|112|10503.527870|1.000000|1.963333|9.816667|0.070119|15.890000|1.139000|

Acceptance: **FINAL_AUDIT_PASS**: 4 DC, 20 GLS, 12 PT-PX runs / 48 windows;
100% net activity annotation. All random Body patterns have adjacent transitions.

All four testbenches hold input valid/data until the falling edge following
acceptance. This replaces the historical 1ps hold that violated delayed gated
clock endpoints. No cycles are added to continuous injection. Failed runs are preserved.

ICG coverage: Thin 65 cells / 985 of1135 registers (86.78%); c1p4 112 cells /
1632 of1888 registers (86.44%). The clock source remains running. Idle power
includes ungated registers, gating control and leakage. Explicit before/test_mode
style matches library latch_posedge_precontrol; final DC has no PWR-191 or Error.

DC gating-specific report options are unsupported; files named clock_gating_setup
and clock_gating_hold contain verbose all-violators reports. Positive register
setup/hold slack and clean MAX-SDF GLS are verified. Design-rule/power-target
warnings remain; this is not physical timing signoff.

Area reductions reflect synthesis remapping with gating, including enable mux
changes; they do not imply ICG cells themselves have negative area.
