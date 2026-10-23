# Async c2p4 / c4p8 single Router PPA

TT 0.8V 25C; same current async DC recipe as 20261022 c1p4. c2p4 is L2; c4p8 is L3.
Both final DC runs use private frozen scripts with the same size-only cell targets. The c1p4-specific XNR4 count assumption was replaced by mapped-count verification (32 for c2p4, 144 for c4p8); RTL, handshake equations and DEL settings were not changed.
28 bits/flit, five-flit unicast packet; one child0 source to parent, destination (8,8); input-handshake paced; three independent data seeds/reset runs.
Packet completion is first input Req to final output Req. Packet completion/5 is amortized time, not mean individual flit traversal latency.
Power uses whole DUT, 50ps input slew / 5fF output load, internal+switching+leakage, no idle subtraction. Active window ends at Tail capture, 90ps after Tail Req.
Post-synthesis zero-wire estimate: no extracted routing or physical CTS. Library extrapolation warnings remain.

Acceptance: 2 final DC PASS with nonempty DDC/netlist/SDF/SDC; 6/6 GLS runs each delivered 5/5 flits and passed post-drain settling, with zero SDF errors and no timing violation; 24/24 PT-PX windows pass with 100% net activity annotation.

|Router|Area um2|Packet ns|Packet/5 ns|Mean power mW|Packet pJ|pJ/transferred bit|
|---|---:|---:|---:|---:|---:|---:|
|async_c2p4|30105.936|5.572000|1.114400|1.657667|9.385709|0.067041|
|async_c4p8|77433.888|6.434000|1.286800|1.878000|12.252072|0.087515|

Tail+5ns window includes control release and idle; its packet energies are:
- async_c2p4: 10.512377 pJ, 0.075088 pJ/bit; last observed nonclock release 0.578000 ns after Tail capture.
- async_c4p8: 14.639321 pJ, 0.104567 pJ/bit; last observed nonclock release 0.616000 ns after Tail capture.
