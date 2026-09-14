# 2026-09-14 PROP_temp64 multicast and c1p4 Router results

This is a post-synthesis MAXIMUM-SDF experiment on the 64-node, 16-upper-port
`PROP_temp64` netlist `20260913_prop_temp64_asap_uc_m5_200`. It does not test
256-node Tree–Mesh boundary replication. The canonical trace uses seed 202701,
64 warmup plus 400 measurement original transactions, 1 ns case tick, five
flits per packet and exact AABB destinations excluding the source. Native
multicast injects one packet per original transaction; source repeated-unicast
enqueues one unicast packet per destination at the same original arrival.
Each scheme pair has the same original-event trace SHA-256.

The main tables are [native/multicast_main.csv](native/multicast_main.csv) and
[source_repeated_unicast/multicast_main.csv](source_repeated_unicast/multicast_main.csv).
Both use the mandated ten-column header, 13 load points (5–500, including
midpoints 60, 100 and 150), and rates in Mtransaction/s/source-port or
Mdestination-delivery/s/source-port. The F=2/4/8/16/32 M5 sweep is in
[multicast_fanout.csv](multicast_fanout.csv). The extended evidence tables keep
the completed counts, p95/p99, backlog and trace SHA-256. Exact case, run,
job, input hashes and individual acceptance results are in
[case_run_job_hash.csv](case_run_job_hash.csv).

All 36 archived multicast MAXIMUM-SDF cases have explicit `Total errors: 0`,
`TB_RESULT PASS` with zero missing/unexpected/timeout, and
`PROP_TEMP64_GLS_PASS`. **Abstract freeze (full-drain re-summary):** M5 F16 now counts all
measurement transactions after TB drain. Native vs source
repeated-unicast is **400/400**, backlog **0**, mean completion
**9.240 ns vs 148.602 ns** (**93.8%** reduction). The earlier half-open
window cut produced 399/400 and is obsolete for Abstract wording.

Legacy half-open note (superseded): the two M5 F16 cases completed
399/400 original transactions inside the half-open measurement interval.
Native mean last-destination-Tail completion was 9.242 ns versus
148.693 ns for source repeated-unicast (93.78% lower); measured-window
completed rate was equal at 0.343947 Mtransaction/s/port. The model-predicted inter-router
flit-link count was 19,197 versus 116,224 (83.48% fewer), **not an observed
link-handshake count**. At F16 M80, the respective completed rates were
5.3560 and 2.8861 Mtransaction/s/port, with backlogs of 1 and 185. Do not
quote the M80 throughput difference as a zero-backlog improvement.

The first knee according to two successively higher points with less than
5% throughput growth and increasing nonzero backlog is around M60 for
repeated-unicast (M80 and M100 confirm) and around M100 for Native (M120 and
M150 confirm). These are **finite-window indications**, not a steady-state
saturation capacity. The region cases are functional even at M500; none was
classified as saturation due to timeout or SDF failure.

The fanout M5 experiment has 399/400 in-window completed transactions and
backlog=1 on each F16/F32 side. This comes from closing the measurement
window at the last scheduled original arrival + 1 ns; it does not meet the
plan's literal zero-backlog selection rule. F32 M20 was separately checked
(Native 399/400, repeated 397/400). The present fanout table is exploratory.
The Poisson trace is sampled independently at each *different fanout*, while
Native and repeated are matched *within* a fanout. Consequently, absolute
rate comparisons across F reflect different observation durations.

The `link_traversals` column currently sums the route-oracle's inter-router
links for flits accepted at the source during the window. It excludes PE
injection/pop links, but the network TB does not observe internal
inter-router handshakes. It may overcount flits accepted at the source that
have not yet traversed all links at the measurement boundary. Therefore the
link-count and traffic-reduction percentages cannot be Abstract evidence
until the netlist supplies actual per-link accept events. Completion latency
uses only original transactions whose *last* intended destination Tail is
inside the observation interval; high-load latency distributions are
right-censored and should be interpreted with backlog and completion ratio.

The [router_summary.csv](router_summary.csv) comes from c1p4 Async DC job
12277801 (`20260914_cmr_prop_temp_c1p4_rpsdel050_r1`) and Sync DC job
12276801 (`20260914_cmr_sync_prop_temp_c1p4_1p0ns`). The first Async DC
attempt `20260914_cmr_prop_temp_c1p4_rpsdel050`, job 12276901, failed its
structure gate because it contained RCU DEL150 and is **not** a result.
The accepted Async netlist has eight RCU DEL50, eight OPM Ackin DEL50,
eight ports, four lane adapters and 44 legal edges. Sync uses a 1.0 ns
clock and the same T28 technology/PVT.

For four modes per Router, isolated/stream/idle/contention MAXIMUM-SDF GLS
showed `PPA_RESULT PASS` and `Total errors: 0`; corresponding PT-PX jobs
showed `PPA_POWER_PASS` and `check_power.rpt` ends in `0`. Job IDs and
netlist hashes are in [router_run_job_hash.csv](router_run_job_hash.csv).
PrimeTime also prints a startup `PT-063` warning/error that the Library
Compiler executable path is not set; the reported `check_power` result is
zero and the time-based power reports exist. This diagnostic needs review
before claiming a fully clean PT session.

Async/Sync c1p4 isolated Head-hop latency is 1.101/1.000 ns. Consecutive
Body egresses within stable 5-flit packets have average intervals of
1.08775/2.000 ns, so reciprocal service rates are 919.33/500.00 Mflit/s.
This within-packet rate is not sustained multi-packet throughput; the stream
test includes interpacket gaps. Cell areas are 12,601.68/11,374.10 um2.
For the stream active window, PT-PX total energy divided by 20 delivered
flits gives 2.1753/15.0511 pJ/flit. Dynamic power is Total minus Leakage
(0.8976/6.5265 mW), and leakage is 0.8044/0.6405 mW.

`paper_eligible=false` in the registry until link handshakes are measured
and a defensible zero-backlog fanout window is established. Existing
unicast scans and the two paused 256-node upload tasks were not modified.
