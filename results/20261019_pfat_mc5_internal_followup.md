# PFAT MC5 internal replay

- Candidate: `20261019_174318_archive_pfat64_tailrel100buf0_tt_r1`.
- Case: `MULTICAST5-AABB_n64_s202702_m260_PFAT64_top8.case`.
- Replay job: `14565201`.
- Remote evidence: `/home/ghy19/Asynchronous_Router_CMR/diagnostics/20261019_pfat_mc5_s202702_m260`.
- Sources: `trace.vcd`, `boundary_anomalies.jsonl`, `suspect_boundary.jsonl`, `l2_internal.jsonl`.

All times below are ns. No DUT changes were made during diagnosis.

## Boundary failure

Router `routersL2_0_1`, output `child_2_1` (`OutputPortModules_5`) sends Req up at 923.143 and down at 923.247 with the same observed Head `0x8704707`. Downstream `routersL1_0_3.parent_1` returns Ack at 923.857. The scan of all router boundaries through 940 ns finds this as the first Req transition while an earlier request remains pending. This establishes the earliest observed boundary protocol violation, not necessarily the earliest internal fault or first causal packet.

## Upstream lane/adapter evidence

| Signal | Event |
|---|---|
| selector_9.LaneSelect[1] | rises 922.503; stays high through 924 |
| adapter_9.OPMReqIn[1] / OPM5.Reqin_2 | rises once 922.603 |
| selector_46.LaneSelect[1] | rises 922.553; stays high through 924 |
| adapter_46.OPMReqIn[1] / OPM5.Reqin_9 | rises once 922.654 |
| adapter_9.AwaitAck | rises 922.710 |
| adapter_46.AwaitAck | rises 922.761 |
| OPM5.Ackout_2 / Ackout_9 | remain 0 throughout window |

The inspected lane selections and adapted requests do not show a second transition preceding the boundary glitch. Other sources and earlier history have not been exhaustively cleared.

## Simultaneous OPM arbitration grants

| OPM5 signal | Event |
|---|---|
| Arbiter.req[3] | falls 922.140 |
| Arbiter.grant[3] | falls 922.320 |
| Arbiter.req[2] | rises 922.539 |
| Arbiter.req[8] | rises 922.585 |
| Arbiter.req[9] | rises 922.588 |
| Arbiter.req[5] | rises 922.603 |
| Arbiter.grant[2] | rises 922.757; stays high through 924 |
| Arbiter.grant[9] | rises 922.873; stays high through 924 |
| L1_L4_2.en | rises 922.879 |
| L1_L4_2.q / _ReqMerged_T[2] | rises 922.964 |
| L1_L4_9.en | rises 922.994 |
| L1_L4_9.q / _ReqMerged_T[9] | rises 923.077 |
| L5.en / DataReg.en | rises 922.974 |
| L5.d | rises 923.078; falls 923.189 |
| L5.q / Reqout | rises 923.143; falls 923.247 |

Both grants are aliases of actual `Arbiter.grant` pins. This is persistent overlapping authorization in the measured window, not an inference from LaneSelect. Two independently settling request-latch outputs precede the merged-request pulse. The next root-cause investigation is inside the frozen OPM5 arbiter (Mutex/TAC), including mapped connectivity and old-winner release/new-request overlap. Unicast success does not establish mutual exclusion for these concurrent request arrivals. This evidence alone does not distinguish source arbitration design, synthesis mapping, and relative-timing failure.

## Root and C-element drill-down

Remote evidence: `arbiter_internal.jsonl` and its `.inventory`, extracted from the same frozen VCD, window 921.5–924 ns.

| Signal | Events (ns) |
|---|---|
| flat.req0 | rises 922.566, stays high |
| flat.req2 | rises 922.622, stays high |
| flat.req1 | rises 922.637, stays high |
| root.req0_effective | rises 922.601, falls 922.702, rises 922.739 |
| root.ab0 | rises 922.655, falls 922.740 |
| root.ca0 | rises 922.637, falls 922.729 |
| flat.root0 / root.arbo[0] | rises 922.684, falls 922.750 (66 ps pulse) |
| flat.root2 / root.arbo[2] | rises 922.802, stays high |
| leaf0.join2.A | rises 922.645, stays high |
| leaf0.join2.B | same 66 ps root0 pulse |
| leaf0.join2.Z / grant[2] | rises 922.757, stays high |
| leaf2.join3.A | rises 922.686, stays high |
| leaf2.join3.B | rises 922.802, stays high |
| leaf2.join3.Z / grant[9] | rises 922.873, stays high |

The root0/root2 grants do not overlap. The pulse on root0 is sufficient to set leaf0's C-element; afterward A=1/B=0 holds grant[2] indefinitely while leaf2 receives root2 and sets grant[9]. Thus the immediate failure is a transient root winner being committed by a state-holding leaf join.

The source `CMRMutex3Core` uses `cyclic_partial = !reset && (&req) && !(|arbo)` to suppress requester 0. Three root requests arrive within 71 ps. The mapped root's no-winner detector responds before the group winner settles and the delayed suppression of req0_effective withdraws a winner that has already propagated into a leaf. This is a dynamic hazard in the correction/commit interaction; root pairwise Mutex2 outputs shown in this window have no dual-high overlap. No conclusion about analogue metastability immunity is made from SDF.

Frozen router type is `CMRRouter_17`, OPM type `CMRRouter_17_OPM_96_2`, arbiter type `CMRRouter_17_CMRMutexN_WIDTH10_2`, flat type `CMRRouter_17_CMRFlatArbiter10_2`. No DUT modification has been applied.
