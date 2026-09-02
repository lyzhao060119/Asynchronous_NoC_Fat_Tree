# NoC Experiment Design V3.2.0
## Whole-network gate-level evaluation without field-programmable gate-array validation

> This is the current execution document. V3.1.0 remains a historical record
> at [`NoC_Experiment_Design_V3.1.0.md`](NoC_Experiment_Design_V3.1.0.md).
> Internal design keys, benchmark keys, and run identifiers remain compatibility
> keys and do not change historical hashes.

## Decision and evidence hierarchy

The available field-programmable gate-array target cannot fit either complete
64-node balanced hierarchical network within its lookup-table capacity.
Therefore V3.2.0 removes field-programmable gate-array validation from this
paper. A reduced 4-by-4 prototype must not be described as, compared against,
or substituted for the 64-node network.

The required evidence hierarchy is:

1. Logic synthesis maps the full register-transfer-level network to a
   standard-cell gate netlist and reports post-synthesis area and timing.
2. Maximum-delay Standard Delay Format gate-level simulation applies the
   slow-corner maximum delays to that same netlist and checks delay annotation,
   timing violations, unknown values, loss, duplication, deadlock, and timeout.
3. The software event network simulator predicts pilot loads and cross-checks
   delivery only. It is never the source of 256-node or 1024-node paper data.

This remains post-synthesis evidence, not place-and-route signoff. It does not
prove wire area, floorplan, or chip frequency.

## Required experiment matrix

The required matrix is unchanged by removal of field-programmable gate-array
work:

| Claim | Required comparison | Required evidence |
|---|---|---|
| Bounded hierarchical width | 64-node narrow, balanced, and progressively widened asynchronous hierarchical networks | Independent full-network synthesis and maximum-delay gate simulation |
| Fixed-depth hierarchy | Balanced hierarchical versus flat mesh at 64, 256, and 1024 nodes | Independent full-network synthesis and maximum-delay gate simulation |
| Native cross-group multicast | 1024-node balanced hierarchical network versus its boundary packet-replication injection policy | One shared signed netlist and paired maximum-delay gate simulations |
| Synchronous reference | 64-node synchronous narrow and balanced hierarchical networks | Signed 1.0 ns, one-cycle-head whole-network evidence |

No synchronous 256-node or 1024-node network is added. The four-lane top-mesh
variation is unsupported and has no synthesis or delay-format result.

## Optional spiking-neural-network trace replay

One spiking-neural-network trace replay may be considered only after all
required 64-node, 256-node, and 1024-node gates are green. It is optional
application evidence; it neither creates a fourth architectural claim nor
blocks the paper.

The trace must be frozen, versioned, and accompanied by:

- a source node, ordered event time or sequence, packet-flit count, and
  nonempty destination set for every original event;
- a declared one-to-one mapping from logical endpoints to the 1024-node
  network endpoints;
- a source hash and license/provenance record; and
- preservation of one spike event as one multicast injection. A trace flattened
  into independent unicasts is not eligible for the native-multicast comparison.

Replay only the signed 1024-node balanced hierarchical netlist and its
shared-netlist boundary packet-replication comparison. Do not add a flat-mesh
multicast baseline unless it has equivalent, independently validated multicast
semantics; implementing that baseline is outside this paper.

The one-pilot time box measures useful destinations, region-covered
destinations, region efficiency, global-link traversals, final-destination
completion latency, and energy per original event where signed power inputs
exist. Include an inset only if it passes the same gate-level correctness and
timing checks and materially confirms reduced replicated global traffic or
completion time. Otherwise archive the evidence and omit it.

## Gate order and stopping rule

1. Gate A: local structure, route oracle, five-flit traffic, and testbench
   readiness.
2. Gate B: all independent 64-node networks synthesize and pass directed,
   zero-load, medium-load, and near-saturation maximum-delay gate simulations.
3. Gate C/D: 256-node pilot then formal three-seed gate-level sweep.
4. Gate E/F: 1024-node pilot then formal three-seed gate-level sweep.
5. Aggregate Table I and Figures A–C from signed manifests only.
6. Optionally run the frozen spiking-neural-network trace pilot after Gate F.
7. Clean replay, audit, and paper freeze.

Each failed gate stops the next size and preserves netlist, delay-file, case,
log, tool-version, resource-use, and manifest evidence. No failed or omitted
gate can be replaced by a software-model result, a field-programmable
gate-array prototype, or an unvalidated application trace.

## Current status

- Gate A local readiness has passed.
- The asynchronous 64-node whole-network maximum-delay traces required by Gate
  B are still missing; 256-node and 1024-node submissions remain blocked.
- Field-programmable gate-array validation is cancelled due to lookup-table
  capacity, not interpreted as a network-performance failure.
- No spiking-neural-network trace has been selected, frozen, or run.
