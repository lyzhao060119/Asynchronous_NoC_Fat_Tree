# PFAT multicast router localization, 2026-10-19

Frozen DUT: `20261014_archive_v1_pfat64_1248_tt_r1` (archive PFAT, not latest Click RTL).
Post-netlist SHA256: `e2c78bed8b7ff590100d8b6128cbfd7dfc79d39a2f4a06b7f4ad50438f026b75`.
SDF SHA256: `d8d82028aef575a9cf4ec20c9f07e6f5140e0d8750c702d808605a47a6b178dc`.
Replay directory: `/prjtemp/ghy19/date2027_formal64/20261019_162609_pfat_prefix_router_diag`.
Jobs 14549101 and 14549201 finished. Scheduler DONE is not functional PASS.

## Reproduction

- MC5 seed202701 m5 prefix354: PASS, injected1770, delivered2615, missing0, unexpected0.
- Same trace prefix355: STALL at64020ns; received2550/2620 expected flits. Source62 pending Tail `0x4033942`.
- Historical packet354 alone and selected two/three-packet tests passed; interaction history matters.
- Prefix355 waveform retained remotely, approximately88MB. No RTL or assertion changes.

## Final pending router boundaries

VCD timescale is ps. Last waveform event13534.496ns; simulation later terminates on idle timeout.

| Sender | Receiver | Flit | Pending Req transition ns |
|---|---|---|---:|
| routerL3 outputs_child_3_3 | routersL2_0_0 inputs_parent_3 | 0x4096941 | 6072.049 |
| routersL2_1_1 outputs_parent_3 | routerL3 inputs_child_0_3 | 0x4025942 | 6183.942 |
| routersL1_3_3 outputs_parent_1 | routersL2_1_1 inputs_child_0_1 | 0x415e943 | 6189.344 |
| source62 | routersL1_3_3 inputs_child_2_0 | 0x4033942 | 6794.477 |

Sender/receiver pairing here uses identical Req/Ack transition times and flit values; validate explicit net connectivity before calling this a proven dependency graph.
All1008 router boundary signals were enumerated across21 router instances.
The oldest remaining boundary request enters routersL2_0_0, which has no pending output boundary at the final snapshot. This makes that router the first internal probe target, not yet a proven root cause.

## Next checks

Trace routersL2_0_0 inputs_parent_3 into its IPM; inspect storage Tail, branch completion/CellEmpty, RouteSel, LaneSelect/adapter and OPM ownership over the preceding transactions. Distinguish internal completion loss, wrong cancellation and resource dependency from a physical timing violation. Historical RTL-only stall is auxiliary evidence, not proof of the same mechanism.

## Internal diagnosis: confirmed phase corruption at L3

The downstream L2 is a victim, not the first fault. Frozen-waveform analysis identifies
`tree.routerL3.InputPortModules_3.Buffer.ReadInterface_2.PhaseSelector`.
Its branch connects through adapter_14 lane3 to OutputPortModules_15 source3,
then outputs_child_3_3 -> routersL2_0_0.inputs_parent_3 (IPM11).

Archive ReadPhaseSelector implements:
`WrongPath = !PathEnabledLocal & OtherPathEnabled`,
`CancelEnable = WrongPath & (Reqout ^ Ackin)`,
`Reqout = ReqX ^ CorrectionPhase`.
OtherPathEnabled is delayed by DEL050. This delays falling as well as rising edges.

| Event | Time ns |
|---|---:|
| L3 IPM3 PathEnabled_2 falls after preceding multicast Tail | 5933.057 |
| Adapter IPMAckIn / branch Ackin falls to0 | 5933.093 |
| CancelEnable rises spuriously | 5933.098 |
| Delayed OtherPathEnabled falls | 5933.107 |
| CancelEnable falls (18ps pulse) | 5933.116 |
| LaneSelect[3] clears | 5933.146 |
| CorrectionPhase toggles1->0 | 5933.155 |
| Reqout toggles0->1 with no ReqX transition | 5933.205 |

Thus a previously valid multicast branch is momentarily classified as wrong during
Tail teardown. The cancel pulse changes persistent correction state. Idle Reqout=1,
Ackin=0 remains until the next packet; this is not downstream backpressure.

Next transaction (payload packet tag150):

| Event | Time ns |
|---|---:|
| IPM3 branch2 data Head becomes1 | 6066.483 |
| ReqX toggles to0 | 6066.636 |
| Reqout toggles to0, matching stale Ackin=0 | 6066.676 |
| AckGenerator equality net n2 rises | 6066.721 |
| AckX toggles although no adapter Ack has arrived | 6066.782 |
| ReadPointer advances to slot1 | 6066.890 |
| Local PathEnabled rises | 6066.960 |
| LaneSelect[3] rises | 6067.268 |
| Head bit falls as reader has moved to Body | 6067.431 |
| OPM15 Grant3 rises | 6067.777 |
| First OPM15 request to L2 carries Body 0x0096341, not Head | 6068.239 |
| First actual adapter Ack arrives | 6068.771 |

L2 receives Body1/2/3/Tail (0x0096341,0x0096541,0x0096741,0x4096941)
without a Head. It cannot establish RouteSel/PathEnabled; all four read requests
remain unacknowledged and the Tail stalls upstream.

Conclusion: in this archived PFAT candidate, multicast-tail teardown skew causes a
spurious ReadPhaseSelector cancellation and persistent phase corruption, then loss
of the next Head. This is not evidence for increasing RCU DEL or for a Mesh-like
routing dependency deadlock. No DUT modification or protective ECO was performed.
A fix still requires independently validated teardown/cancellation protection;
simply increasing OtherPathDelay can lengthen the falling-edge hazard window.
