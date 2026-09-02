# DATE 2027 Paper Structure Freeze

> Status: **FROZEN FOR DRAFTING — REVISION 2**  
> Date: 2026-09-01  
> Scope: six pages of main text plus one references page  
> Purpose: lock the paper story, section/page budget, figure plan, hardware-microarchitecture contribution, claim-evidence mapping, and writing boundaries before prose drafting.

---

## 1. Paper thesis

### One-sentence thesis

For sparse and bursty event-driven many-core communication, the proposed network preserves one native multicast transaction across a fixed-depth local hierarchy and a global mesh, while a phase-safe multi-lane arbitration microarchitecture enables bounded fattening without losing two-phase handshake correctness.

### Short packaging phrase

> **Preserve multicast across scale, without unbounded router complexity.**

### Recommended title direction

Primary candidate:

> **Preserving Multicast Across Scale: A Bounded-Fat Asynchronous Hierarchical NoC for Event-Driven Many-Cores**

Backup candidate:

> **A Multicast-Preserving Bounded-Fat Asynchronous NoC for Scalable Event-Driven Systems**

The final title is not frozen until the main results pass their evidence gates.

---

## 2. Gap and contribution hierarchy

### 2.1 Core gap

Representative asynchronous multicast work mainly improves replication inside a router or a local network, while scalable hierarchical networks mainly address topology growth. A gap remains between them: when a multicast crosses a local/global hierarchy boundary, it may be split into multiple global unicast packets, losing common-path sharing. Avoiding that loss by widening a tree introduces a second unresolved problem: one logical CMR branch must dynamically bind to one of several physical lanes whose two-phase acknowledgements may have different phase histories. A direct combinational lane multiplexer can therefore create a false transition or lose handshake state, while aggressive widening also creates high-radix asynchronous arbitration and large implementation cost.

The paper therefore asks:

> How can a large event-driven NoC preserve end-to-end multicast semantics across hierarchy tiers, safely map logical multicast branches onto multiple physical lanes, reduce router traversal relative to a flat mesh, and bound the implementation cost of asynchronous fattening?

### 2.2 Contribution hierarchy

The contributions are deliberately asymmetric.

1. **Primary system contribution: multicast-preserving fixed-depth hierarchy.** One original multicast transaction remains native while traversing the Top Mesh and destination Q64 trees. It is not split into one global packet per target cluster.
2. **Hardware-microarchitecture contribution: phase-safe multi-lane CMR expansion.** A `ContinuousLaneSelector`, packet-lifetime `WormholeLaneLock`, second-stage OPM `Commit`, and `LanePhaseAdapter` jointly bind one logical multicast branch to an available physical lane while preserving its two-phase Req/Ack history. Exact-width `CMRMutexN` instances support the topology-required arbitration cardinalities without padding to a larger virtual radix.
3. **Architectural design-space contribution: bounded fatness.** Fixed Q64 clusters scale through a coarse-grained Top Mesh, and the 1-2-2-2 lane profile bounds maximum OPM fan-in while recovering useful upper-level bandwidth. Post-synthesis area and MAXIMUM-SDF evaluation quantify this choice.
4. **Implementation evidence.** Standard-cell synthesis, MAXIMUM-SDF timing/functional validation, and matched-function synchronous evidence establish credibility. Asynchrony itself is not claimed as the novelty.

### 2.3 Claims that are explicitly not novel

- CMR Buffer or continuous-time replication by itself.
- Independent CMR read branches or heterogeneous branch backpressure by itself.
- The original CMR `OPMSelector`, which opens and releases packet-lifetime direction paths.
- Dynamic asynchronous channel/virtual-channel allocation in general.
- Two-phase protocol conversion in general.
- Asynchronous multicast by itself.
- A Tree+Mesh or two-tier topology by itself.
- Generic low-power benefits of asynchronous circuits.
- Support for arbitrary destination sets; the target semantics are spatial/region multicast.
- Support for arbitrary arbitration width. The frozen implementation supports exact topology-required widths: 1/2/4/8 physical lanes and `CMRMutexN` widths 1/2/4/5/8/10/16/20.

---

## 3. End-to-end logic chain

The paper must preserve the following order.

1. Event-driven many-core workloads generate sparse, bursty, short-message, spatial multicast traffic.
2. A flat PE-level mesh scales structurally but increases router count and remote traversal distance.
3. A hierarchical tree reduces traversal, but a thin tree converges and an aggressively widened tree raises asynchronous arbitration and adapter cost.
4. A conventional hierarchy may additionally terminate native multicast at the local/global boundary and inject repeated global unicasts.
5. Multi-lane fattening cannot safely use a direct Ack multiplexer because candidate physical lanes may hold different two-phase histories.
6. The proposed phase-safe lane-binding path performs continuous lane selection, locks the first selected lane for the packet lifetime, waits for the physical OPM grant, and translates Req/Ack phase only after `Commit`.
7. The complete design combines fixed Q64 clusters, bounded 1-2-2-2 fattening, phase-safe multi-lane arbitration, and native Top-Mesh-to-Q64 replication.
8. The design should reduce structural cost and traversal relative to a flat mesh, recover useful bandwidth relative to a thin hierarchy, and reduce replicated global traffic relative to boundary packet replication.
9. Post-synthesis directed arbitration/phase cases, Table I, and Figs. 3-5 test these mechanisms one variable at a time.

The evaluation must not be introduced as a collection of benchmarks. Each result answers one reviewer question.

---

## 4. Global page and word budget

Target PDF-extracted text density, including abstract, captions, and table text: **4,200-4,400 words** across the six main pages.

Target prose excluding captions and table contents: **3,800-3,950 words**.

| Section | Prose budget | Approx. pages | Required message |
| --- | ---: | ---: | --- |
| Abstract | 170-190 words | 0.20-0.25 | Problem, unified design, evidence-backed results, scope |
| I. Introduction | 550-620 | 0.75-0.85 | Application, scaling conflict, precise gap, solution, contributions |
| II. Background, Motivation, and Related Work | 400-470 | 0.60-0.70 | What prior CMR solves, what scaling and multi-lane binding break, novelty boundary |
| III. Architecture | 900-1,000 | 1.40-1.50 | Fixed Q64, phase-safe multi-lane arbitration, bounded fatness, native cross-tier path |
| IV. Implementation and Evaluation Methodology | 420-500 | 0.65-0.80 | DUTs, fairness, tools/corner, traffic, metrics, evidence gates |
| V. Evaluation | 1,150-1,300 | 1.80-2.10 | Implementation, bounded-fat, scalability, cross-tier multicast |
| VI. Conclusion | 100-140 | 0.15-0.20 | One-paragraph answer to the paper question |
| Captions, table text, equations | 350-450 | distributed | Self-contained setup and takeaway |

Hard constraints:

- Evaluation receives approximately two full pages.
- Architecture receives no more than 1.5 pages.
- Related Work is integrated into Section II rather than placed in a separate late section.
- Conclusion is one paragraph.
- References start on page 7.

---

## 5. Page-by-page layout freeze

### Page 1 — Problem and thesis

- Title, authors, Abstract.
- Section I: workload communication property and scaling problem.
- Establish that local multicast efficiency does not automatically survive network scale-out.
- End with the proposed unified principle and contributions.
- No large figure unless final typesetting leaves a clean two-column-width slot at the bottom.

Target: Abstract 180 words + Introduction approximately 600 words.

### Page 2 — Gap, positioning, and visual overview

- Finish Section I if needed.
- Section II: CMR background, hierarchy/mesh alternatives, precise gap, related-work positioning.
- Start Section III with the full system overview.
- Place **Fig. 1** across two columns, preferably in the upper or middle half of the page.

Target visual occupancy: 0.38-0.48 page.

### Page 3 — Architecture details

- Complete Section III.
- Explain fixed-depth Q64 scale-out.
- Explain why 1-2-2-2 is bounded fatness rather than arbitrary lane selection.
- Explain the `ContinuousLaneSelector -> WormholeLaneLock -> OPM Commit -> LanePhaseAdapter` path.
- Show why different physical Ack phases make a direct lane MUX unsafe.
- Explain one PROP multicast path and the H-REP boundary split.
- Place **Fig. 2**, using multiple panels rather than separate small figures.

Target visual occupancy: 0.35-0.45 page.

### Page 4 — Implementation evidence and bounded-fat result

- Section IV methodology in approximately 0.6-0.8 page.
- Start Section V.
- Place **Table I** and **Fig. 3**.
- Report the compact post-synthesis phase/arbitration validation matrix before the bounded-fat system result.
- The page must answer: Is the multi-lane mechanism correct and implementable, and why is 1-2-2-2 selected?

Target visual occupancy: 0.50-0.60 page in total.

### Page 5 — Scalability result

- Evaluation subsection on fixed-depth hierarchy versus flat mesh.
- Place **Fig. 4** as the dominant figure.
- Discuss structural scaling first, then latency/throughput consequences.
- Include failure cases or crossover behavior if present; do not claim the hierarchy always wins.

Target visual occupancy: 0.42-0.52 page.

### Page 6 — Cross-tier multicast and conclusion

- Place **Fig. 5** as the dominant figure.
- Explain why benefit grows with destination-cluster spread.
- Include the loaded mixed-multicast result.
- State limitations and evidence scope in 2-4 sentences.
- End with the one-paragraph Section VI Conclusion.

Target visual occupancy: 0.40-0.50 page.

### Page 7 — References only

- No main-text paragraph may spill onto page 7.
- References should be compact but readable and use the DATE template style.

---

## 6. Figure and table plan

### Fig. 1 — Multicast-preserving hierarchy overview

**Role:** teaser figure and paper-level visual thesis.

Recommended panels:

- (a) Flat PE-level Mesh at scale.
- (b) Fixed-depth Q64 clusters plus Top Mesh.
- (c) One original region-multicast transaction branching across the Top Mesh and destination Q64 trees.
- (d) Boundary replication contrast: the same event becomes multiple global packets.

The figure should visually communicate the paper before the reader reaches the detailed architecture.

Caption takeaway:

> Scale-out should preserve multicast common paths rather than terminate multicast at the hierarchy boundary.

### Fig. 2 — Phase-safe bounded-fat asynchronous architecture

**Role:** explain the mechanism without reproducing the complete prior CMR paper.

Recommended panels:

- (a) Q64 levels and the 1-2-2-2 lane profile.
- (b) Two-stage path: direction-level CMR branch -> `ContinuousLaneSelector` -> `WormholeLaneLock` -> physical-lane OPM arbitration and `Commit`.
- (c) `LanePhaseAdapter` timing example with two candidate lanes holding opposite Ack phases; show phase-offset capture before `Commit` and translated Req after `Commit`.
- (d) PROP versus PFAT fan-in growth, highlighting maximum OPM fan-in 8 versus 20. Independent branch progress may be annotated as an enabling property rather than given a separate panel.

Caption must define the five-slot buffer, supported lane profile, packet-lifetime lane lock, `Commit`, phase translation, and bounded arbitration point. It must state that the supported physical lane counts are 1/2/4/8 rather than claim arbitrary width.

### Table I — Post-synthesis implementation summary

**Reviewer question:** Is the design implemented and credible?

Candidate rows:

- Async Thin `(1,1)`.
- Async Fat L1 `(1,2)`.
- Async PROP `(2,2)`.
- Async PFAT `(2,4)` and `(4,8)` if space permits.
- Sync Thin `(1,1)`.
- Sync PROP `(2,2)`.

Candidate columns:

- Geometry.
- Maximum OPM fan-in.
- Cell area.
- Head/Body/Tail latency or cycle.
- Active/idle power.
- Energy per five-flit packet.
- Selector/PhaseAdapter presence or count where it helps explain the Thin-to-Fat cost.
- Evidence/run identifier in a compact footnote or artifact reference.

Mandatory label: **post-synthesis, zero wire load, TSMC 28 nm slow corner**. Never label these values post-layout.

### Fig. 3 — Why bounded fat?

**Reviewer question:** Why not a thin tree or a progressively widened tree?

Configurations: THIN64, PROP64, PFAT64 under paired BF-STRESS64 traces.

Recommended panels:

- (a) Saturation throughput or load-latency curves.
- (b) Whole-network cell area and/or energy cost.
- (c) Pareto view using throughput against area or maximum OPM fan-in.

Required conclusion, only if supported:

> 1-2-2-2 recovers most of the useful upper-level bandwidth while avoiding the implementation cost of 1-2-4-8.

Go/No-Go gate: if PROP provides no meaningful improvement over THIN, or PFAT provides large gains at small cost, bounded fatness cannot remain a core contribution.

### Fig. 4 — Why fixed-depth hierarchy?

**Reviewer question:** Why not a conventional flat mesh?

Configurations: PROP64/256/1024 versus FM64/256/1024 with paired TOPO-UR traces.

Recommended panels:

- (a) Whole-network router count and cell area versus node count.
- (b) Mean router/link traversals and zero-load latency.
- (c) 1024-node load-latency or saturation throughput.

Static router-count expectations may illustrate structure, but all paper PPA points require their allowed evidence source. Do not turn primitive multiplication into a whole-network synthesis claim.

Required conclusion, only if supported:

> Fixing the local hierarchy at Q64 reduces PE-level routing resources and remote traversal growth relative to a flat mesh.

Go/No-Go gate: if whole-network cost or traversal does not improve meaningfully, the resource-efficient hierarchy claim must be weakened or removed.

### Fig. 5 — Why native cross-tier multicast?

**Reviewer question:** Why is the design different from local multicast plus a global hierarchy/mesh?

Configurations: PROP1024 versus H-REP1024. They must share the same netlist and delay file; only the injection policy differs.

Recommended panels:

- (a) Top-Mesh packet injections or link traversals versus target-cluster spread `S`.
- (b) Multicast completion latency `Tmax` versus `S`.
- (c) Energy per original event versus `S`.
- (d) Loaded XMC10-G throughput or latency at the frozen offered point.

The expected causal chain is:

```text
one native transaction
  -> fewer replicated global packets
  -> fewer Top-Mesh traversals and arbitration events
  -> lower Tmax and energy per original event
```

Required conclusion, only if supported:

> Native cross-tier replication prevents multicast from degenerating into repeated global unicasts, with benefits increasing as destinations span more clusters.

Go/No-Go gate: if PROP and H-REP do not diverge as `S` increases, the primary novelty is not experimentally established.

### Optional application inset

One real SNN trace may be added only if:

- it uses a documented mapping and trace source;
- the region/locality property is clearly measured;
- it supports the same mechanism as Fig. 5;
- it does not displace any of Figs. 3-5.

Otherwise it remains supplementary/future work.

---

## 7. Section-level reverse outline

### Abstract

1. Event-driven many-core systems require scalable spatial multicast.
2. Existing local multicast and scalable hierarchy solutions do not jointly preserve multicast across tiers with bounded implementation cost.
3. Present the fixed-depth, bounded-fat, multicast-preserving asynchronous hierarchy.
4. State only evidence-backed implementation and network results.
5. End with the implication for scalable event-driven interconnects.

### I. Introduction

1. Application communication is sparse, bursty, short-message, and region-multicast dominated.
2. Flat meshes and conventional hierarchical alternatives expose different scaling costs.
3. Local multicast can lose common-path sharing when crossing a hierarchy boundary.
4. The design insight is to preserve multicast semantics while separately bounding topology and router complexity.
5. Present the architecture at a high level.
6. List the three contributions in primary/secondary/enabling order.

### II. Background, Motivation, and Related Work

1. Define CMR capabilities already established by prior work.
2. Explain fixed-depth hierarchy and fattening pressure.
3. Explain why asynchronous OPM fan-in is a physical implementation concern.
4. Contrast native cross-tier multicast with boundary packet replication.
5. Position against asynchronous multicast routers, fat quadtrees, Tree+Mesh systems, and two-tier multicast NoCs.
6. End with the precise unresolved gap, not a literature list.

### III. Architecture

1. Give the system overview and address/region semantics.
2. Explain Q64 construction and 64/256/1024 scale-out.
3. Explain the 1-2-2-2 lane profile and bounded fan-in.
4. Explain one packet's native path across both tiers.
5. Explain H-REP as a policy-only contrast using the same hardware.
6. Explain asynchronous branch independence only where it supports cross-tier progress.
7. State assumptions: five-slot Router buffer, 28-bit flit, no inter-level FIFO in the frozen DUT, and no-U-turn routing.

### IV. Implementation and Evaluation Methodology

1. Define post-synthesis evidence scope and the TSMC 28 nm slow corner.
2. Define MAXIMUM-SDF pass gates and forbid post-layout terminology.
3. Define pairwise baseline fairness and paired traces.
4. Define five-flit packets, warm-up/measurement counts, and seeds.
5. Define saturation, zero-load latency, traversals, `Tmax`, and energy per original event.
6. Identify which result comes from isolated Router evidence and which requires a whole-network netlist.

### V. Evaluation

1. Phase-safe multi-lane correctness and implementation credibility: directed MAXIMUM-SDF matrix plus Table I.
2. Bounded-fat trade-off: Fig. 3.
3. Fixed-depth hierarchy scalability: Fig. 4.
4. Native cross-tier multicast: Fig. 5.
5. Limitations and scope: supported exact widths, no bounded-wait fairness claim, post-synthesis only, region multicast target, and any observed crossover/failure cases.

### VI. Conclusion

1. Re-answer the paper question in one paragraph.
2. Mention the three design choices as one system, not as a list of modules.
3. State only the strongest verified result and its implication.

---

## 8. Claim-evidence freeze

| Claim | Required evidence | Current status |
| --- | --- | --- |
| The architecture is implementable using standard cells | Frozen Router DC, MAXIMUM-SDF hop simulation, power analysis | **Supported for isolated primitives** by `20260901_cmr_primitive_hop_ppa_ru5` |
| The phase-safe lane-binding mechanism preserves two-phase handshakes across dynamic lane selection | Directed MAXIMUM-SDF cases covering lane counts 1/2/4/8, opposite initial Ack phases, consecutive packets switching lanes, contention, and downstream backpressure; require zero loss/duplicate/X/timing violation | **Evaluation evidence required in the paper; post-synthesis simulation is the acceptance gate** |
| A packet cannot migrate between physical lanes after arbitration | `WormholeLaneLock` packet-lifetime cases from Head through Tail under changing `OtherGrant` | **Evaluation evidence required in the paper** |
| Exact-width arbitration avoids unnecessary padded radix for the frozen topology | Structure counts plus isolated Router area/timing for required `CMRMutexN` widths 1/2/4/5/8/10/16/20 | **Supported structurally; quantify cost in Table I/Evaluation** |
| The synchronous comparison is one-cycle at 1.0 ns | Signed Sync Router and Sync64 manifests | **Supported** for frozen synchronous evidence |
| 1-2-2-2 is a better bounded-fat point than 1-1-1-1 and 1-2-4-8 | BF-STRESS64 whole-network throughput plus area/energy/fan-in | **Needs evidence** |
| Fixed-depth hierarchy scales better than flat mesh | 64/256/1024 independent whole-network synthesis and MAXIMUM-SDF traces | **Needs evidence** |
| Native cross-tier multicast reduces repeated global traffic | Same-netlist PROP1024/H-REP1024 XMC-F16 results | **Needs evidence** |
| Native cross-tier multicast improves completion and energy under load | Same-netlist loaded XMC10-G results | **Needs evidence** |
| The design is post-layout or physically signed off | P&R evidence | **Unsupported and prohibited** |
| The design supports arbitrary multicast destination sets | Matching routing/encoding evidence | **Unsupported; use region multicast wording** |
| The design supports arbitrary-N arbitration | Generalized implementation and validation outside the frozen exact-width set | **Unsupported and prohibited; use parameterized exact-width wording** |

Abstract and Introduction quantitative claims must be regenerated from this table after Figs. 3-5 are complete.

---

## 9. Terminology freeze

Use consistently:

- **event-driven many-core system** for the application class;
- **spatial/region multicast** for the routing semantics;
- **fixed-depth Q64 hierarchy** for the local tree organization;
- **bounded-fat 1-2-2-2 lane profile** for the proposed width choice;
- **direction-level CMR branch** for the logical multicast read channel before physical-lane expansion;
- **phase-safe multi-lane arbitration** for the complete Selector/Lock/Commit/Adapter mechanism;
- **continuous lane selection** for `ContinuousLaneSelector`;
- **packet-lifetime lane binding** for `WormholeLaneLock` behavior;
- **commit-gated phase translation** for `LanePhaseAdapter` behavior;
- **exact-width asynchronous arbitration** for `CMRMutexN`; never use arbitrary-N arbitration;
- **Top Mesh** for the cluster-level mesh;
- **native cross-tier multicast** for PROP behavior;
- **boundary packet replication** for H-REP behavior;
- **original event** versus **injected packet**;
- **multicast completion latency (`Tmax`)** for last intended destination tail minus source head injection;
- **post-synthesis cell area** and **MAXIMUM-SDF gate-level simulation** for ASIC evidence.

Do not alternate among `Fat-Tree`, `fat tree`, `hierarchical tree`, and `quadtree` without defining their relationship. Pick one primary term per level.

---

## 10. Evidence and wording gates

Before inserting a number into the paper, record:

- design/configuration;
- benchmark and seed;
- packet length and load definition;
- tool, library, PVT corner, and physical class;
- run identifier;
- netlist/SDF/trace hashes where required;
- annotation, timing, X, stall, timeout, and scoreboard status.

Current hard boundaries:

- V3.1 whole-network paper numbers require independent synthesis netlists and MAXIMUM-SDF simulations.
- The software event network simulator is a predictor/cross-check, not the source of 256/1024 paper points.
- A submit-only `summary.json` is not a passing paper manifest.
- The multi-lane microarchitecture claim requires post-synthesis MAXIMUM-SDF cases that exercise phase mismatch, lane reassignment between packets, contention, and backpressure; RTL-only smoke is insufficient for the paper claim.
- The evaluation must report zero annotation errors, zero timing violations, no X/Z, and no loss/duplicate/timeout for the directed phase/arbitration matrix.
- Empty curated CSVs mean the corresponding claim remains `needs evidence`.
- Do not write `post-layout`, `post-route`, `physical signoff`, or wire/floorplan claims.
- Do not use a historical 3-flit run as a substitute for the frozen five-flit formal matrix.

---

## 11. Space-cutting order

If the paper exceeds six pages, cut in this order:

1. Optional application trace/inset.
2. Secondary packet-length, hotspot, or backpressure curves.
3. Detailed equations already evident from the architecture figure.
4. Extra Router primitive rows in Table I.
5. Background implementation details that can be cited.
6. Repeated numerical discussion already visible in a figure.

Never cut:

- the precise gap;
- the phase-safe Selector/Lock/Commit/Adapter mechanism and its post-synthesis validation;
- the PROP/H-REP same-netlist explanation;
- baseline fairness;
- evidence scope and post-synthesis limitation;
- any of Figs. 3-5 if its corresponding claim remains in the contributions.

---

## 12. Drafting order

The prose should be written in this order, not paper order:

1. Freeze the directed post-synthesis phase/arbitration validation matrix, final Figs. 3-5, and Table I.
2. Write Section V Evaluation from verified claims.
3. Write Section III Architecture against Figs. 1-2.
4. Write Section IV Methodology.
5. Write Section II Background/Related Work.
6. Write Section I Introduction.
7. Write Conclusion.
8. Write Abstract last.

After each section, perform a reverse outline and verify that every paragraph supports exactly one message in Section 7 of this document.
