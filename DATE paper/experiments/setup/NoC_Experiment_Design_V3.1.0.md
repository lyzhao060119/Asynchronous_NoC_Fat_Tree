# NoC Experiment Design V3.1.0
## Whole-network logic synthesis and maximum-delay gate-level simulation

> **Superseded for execution by**
> [`NoC_Experiment_Design_V3.2.0.md`](NoC_Experiment_Design_V3.2.0.md).
> V3.2.0 removes field-programmable gate-array validation because the
> available target cannot fit the complete 64-node networks, and retains only
> a non-blocking, post-Gate-F spiking-neural-network trace replay option.
> This V3.1.0 file is historical.
>
> Historical V3.0.2 remains at
> [`NoC_Experiment_Design_V3.0.2.md`](NoC_Experiment_Design_V3.0.2.md).
> Machine identifiers (`design_id`, benchmark keys, run identifiers) are
> unchanged so existing hashes and registry rows stay valid.

This revision does two things:

1. Every name shown to a reader is a complete English phrase. Internal short keys stay in JSON, logs, and manifests only.
2. 256-node and 1024-node paper numbers must come from an independent whole-network gate netlist plus a slow-corner maximum-delay Standard Delay Format simulation. The software event network simulator is a predictor and cross-check, not a substitute.

No synchronous 256-node or 1024-node network is added. Large-scale comparison is asynchronous hierarchical versus asynchronous flat mesh.

---

## Experiment names and purpose

| Internal key | Display name | Purpose |
|---|---|---|
| THIN64 | Asynchronous narrow hierarchical network, 64 nodes | Narrow-lane hierarchical ablation |
| PROP64 | Asynchronous balanced hierarchical network, 64 nodes | Proposed 64-node hierarchical design |
| PFAT64 | Asynchronous progressively widened hierarchical network, 64 nodes | Upper bound on hierarchical widening |
| FM64 | Asynchronous flat mesh network, 64 nodes | 64-node flat-mesh baseline |
| SYNC_THIN64 | Synchronous narrow hierarchical network, 64 nodes | Clocked narrow counterpart (signed, 1.0 ns, one-cycle head) |
| SYNC_PROP64 | Synchronous balanced hierarchical network, 64 nodes | Clocked balanced counterpart (signed, 1.0 ns, one-cycle head) |
| PROP256 | Asynchronous balanced hierarchical network, 256 nodes | Hierarchical scale-out: 2-by-2 clusters of 64-node tiles |
| FM256 | Asynchronous flat mesh network, 256 nodes | 16-by-16 flat-mesh comparison at 256 nodes |
| PROP1024 | Asynchronous balanced hierarchical network, 1024 nodes | Hierarchical scale-out: 4-by-4 clusters of 64-node tiles |
| FM1024 | Asynchronous flat mesh network, 1024 nodes | 32-by-32 flat-mesh comparison at 1024 nodes |
| HREP1024 | Asynchronous balanced hierarchical network, 1024 nodes, boundary packet-replication comparison | Same netlist as the 1024-node hierarchical network; injection policy only |
| BF-STRESS64 | 64-node hierarchical-width stress traffic | Destinations leave the source level-2 subtree |
| TOPO-UR | Uniform random single-destination traffic, 64/256/1024 nodes | Fair unicast scalability |
| XMC-F16 | 1024-node fixed sixteen-destination cross-group multicast traffic | Native multicast versus packet replication |
| XMC10-G | 1024-node mixed single-destination and multicast traffic | Mixed load at a fixed offered point |

Four-lane top-mesh sanity is **unsupported**: router geometry (4,2) is not in the supported lane set. Single-lane top-mesh sanity is backup only. Neither is a paper-matrix netlist. Do not fabricate synthesis or delay-format results for an unsupported geometry.

---

## What logic synthesis and maximum-delay simulation prove, and what they do not

**Logic synthesis** (Synopsys Design Compiler) maps register-transfer-level Verilog onto the TSMC 28 nm high-performance-compact standard-cell library. The reports are post-synthesis cell area and timing under a zero-wire-load model.

**Maximum-delay Standard Delay Format gate-level simulation** annotates that netlist with the slow-corner **MAXIMUM** delays from synthesis. A passing run must show:

- delay annotation completed
- annotation errors = 0
- timing violations = 0
- no unknown or high-impedance values on handshake or data
- no loss, duplicate delivery, deadlock, or timeout

**They do not prove** place-and-route signoff, wire area, floorplan, or chip frequency. The available kit still lacks the physical-design technology files required for that. The paper remains **post-synthesis only**. Primitive cell-area multiplication is not a substitute for a whole-network synthesis netlist.

The **software event network simulator** (`model/des/`) estimates load points and checks delivery consistency. It must not appear as the 256-node or 1024-node paper result source. If a large-scale gate fails, stop, keep the evidence, and wait for a human decision. Do not silently replace the missing gate result with a model number.

---

## Independent whole-network netlist matrix

Each independent netlist must produce: a synthesis netlist, a maximum-delay file, area/timing/structure reports, input hashes, and a write-protected run manifest. Shared-netlist designs reuse that evidence; they do not re-synthesize.

| Display name | Independent netlist | Shares with | Paper matrix |
|---|---|---|---|
| Asynchronous narrow hierarchical network, 64 nodes | yes | — | yes |
| Asynchronous balanced hierarchical network, 64 nodes | yes | — | yes |
| Asynchronous progressively widened hierarchical network, 64 nodes | yes | — | yes |
| Asynchronous flat mesh network, 64 nodes | yes | — | yes |
| Synchronous narrow hierarchical network, 64 nodes | yes (already signed) | — | yes |
| Synchronous balanced hierarchical network, 64 nodes | yes (already signed) | — | yes |
| Asynchronous balanced hierarchical network, 256 nodes | yes | — | yes |
| Asynchronous flat mesh network, 256 nodes | yes | — | yes |
| Asynchronous balanced hierarchical network, 1024 nodes | yes | — | yes |
| Asynchronous flat mesh network, 1024 nodes | yes | — | yes |
| Boundary packet-replication comparison, 1024 nodes | no | 1024-node hierarchical | yes (policy only) |
| Two-lane top-mesh alias, 1024 nodes | no | 1024-node hierarchical | backup |
| Single-lane top-mesh sanity, 1024 nodes | yes, backup | — | no |
| Four-lane top-mesh variation, 1024 nodes | **unsupported** | — | no |

Machine freeze: [`configs/inventory/v31_network_matrix.json`](../configs/inventory/v31_network_matrix.json).

---

## Staged gates (64 then 256 then 1024)

Large jobs are not launched until the previous size is green.

- **Gate A — local readiness.** Scala network tests, route oracle, structure inventory, five-flit directed smoke, unified scoreboard, and a dry-run of the synthesis/simulation driver. Unsupported geometry is refused.
- **Gate B — 64-node template.** All six independent 64-node netlists complete synthesis. Directed, zero-load, medium-load, and near-saturation maximum-delay simulations pass. Synchronous 64-node networks already signed in Phase 2.5 count if their manifests remain write-protected and paper-eligible.
- **Gate C — 256-node pilot.** Synthesize both 256-node asynchronous networks. Check mapped cells, structure counts, and a valid timing report. Then one directed delay simulation each. Then representative zero-load / medium / near-saturation cases.
- **Gate D — 256-node formal.** Full three-seed formal load sweep at gate level. Those traces are the 256-node paper data.
- **Gate E — 1024-node pilot.** Only after Gate D. Synthesize both 1024-node asynchronous networks, review memory and runtime, then the same four delay-simulation classes in order. Any failure stops the remaining batch.
- **Gate F — 1024-node formal.** Full three-seed formal sweep, including hierarchical versus flat-mesh unicast and hierarchical native multicast versus boundary packet-replication. Resource shortage is recorded as Gate FAIL with evidence; it is not auto-replaced by the software event model.

Formal traffic: five-flit packets, 1,000 warm-up events, at least 10,000 measured events, seeds 202701 / 202702 / 202703.

---

## Result sources

| Paper item | Allowed evidence |
|---|---|
| Router implementation table | Frozen isolated-router synthesis, maximum-delay hop simulation, and power analysis |
| 64-node network figures | Corresponding whole-network synthesis netlist + maximum-delay simulation |
| 256-node network figures | Corresponding whole-network synthesis netlist + maximum-delay simulation |
| 1024-node network figures | Corresponding whole-network synthesis netlist + maximum-delay simulation |
| Software event model | Predictor / cross-check only |
| Field-programmable gate-array | Board hardware validation, not an ASIC delay-format substitute |

A 256-node or 1024-node paper point is invalid unless the audit can name: the whole-network netlist hash, the delay-file hash, the case and seed, and a gate-level log with zero annotation errors, zero timing violations, and a passing scoreboard.

---

## Current status (no shorthand)

Run `python DATE paper/experiments/scripts/print_v31_status.py` for a regenerated list. Snapshot at V3.1.0 freeze:

| Item | Status |
|---|---|
| Isolated asynchronous router primitives | Signed post-synthesis hop evidence (do not re-synthesize) |
| Isolated synchronous router primitives | Signed, one-cycle head, 1.0 ns |
| Synchronous narrow hierarchical network, 64 nodes | Signed whole-network maximum-delay simulation |
| Synchronous balanced hierarchical network, 64 nodes | Signed whole-network maximum-delay simulation |
| Asynchronous 64-node independent netlists | Gate B: template scripts exist; locked-delay five-flit whole-network delay traces are still missing, so 256-node jobs are blocked |
| Asynchronous balanced hierarchical network, 256 nodes | Driver ready; not started (Gate B hold) |
| Asynchronous flat mesh network, 256 nodes | Driver ready; not started (Gate B hold) |
| Asynchronous 1024-node networks | Driver ready; not started (Gate B hold) |
| Four-lane top-mesh variation | Unsupported; driver refuses; no fabricated results |
| Gate A local readiness | Passed (Scala network spec, inventory, five-flit traffic, driver input check) |
| Software event model | Calibrated hops; network paper-matrix flag remains false until Gate D/F traces exist |
| Place-and-route | Closed. Post-synthesis only |

---

## Compatibility

- Schema `date-v3-design-v1` / `date-v3-benchmark-v1` gain optional `display_name` and `display_description`.
- Those fields are excluded from `config_hash` so historical manifests stay valid.
- Directory `model/des/` is not renamed; user-facing text says “software event network simulator”.
- New synthesis and delay-simulation run identifiers must be dated and write-protected. Never overwrite a frozen directory.
