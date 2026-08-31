# High Performance Async Router Rebuild Plan

Last updated: 2026-07-25

## 1. Summary

The current RouterL1 line has reached a structural limit: many stages are
implemented as `control combo -> DelayElement -> pulse/clock`, so the intentional
delay is serialized after the control decision. Further local optimization can
still help, but it is not the clean path to a low-latency bundled-data router.

This document defines a parallel rebuild track for a high-performance async
router. The goal is to move toward a structure where:

```text
source event
  |-> matched delay / fire chain
  |-> data path and control path in parallel
```

The existing debug2/RouterL1 line remains the correctness reference and SDF
fallback. The new router should be developed as a separate implementation, not
as incremental edits to the old `AsyncFork`/`ACG` pulse-clock path.

## 2. Stage Roadmap

### Stage 1: Minimal Wormhole Router

Goal: build the smallest useful high-performance router that can validate the
new timing model.

Structure:

- No VC.
- One physical lane per direction.
- One depth-1 input buffer per input direction/lane.
- One depth-1 output buffer per output direction/lane.
- Keep the current routing algorithm and multicast destination semantics.
- Head reserves output directions; body/tail reuse the head reservation until
  tail releases it.
- Multicast commit is all-or-nothing: if any requested output cannot be acquired,
  no holder/state/input ack is committed for that attempt.

Timing model:

- Fire delay starts from the input event or buffer-valid event, not from the
  fully resolved `canLaunch`/`launchCond`.
- Route decode, destination mask generation, output availability checks, and
  data movement run in parallel with the matched fire delay.
- Commit fires only when both are true:
  - the matched delay/fire token has arrived;
  - all required data/control predicates are stable and true.

Atomic arbitration rule:

```text
tentative grant / availability observation
  -> all requested outputs available?
       yes: commit holder + output buffer + input ack
       no : commit nothing; retry on the next eligible event
```

Do not implement rollback by first updating real holders and then undoing them.
Only the final commit may update architectural state.

Expected reusable pieces:

- `HS_Packet` and packet/flit field definitions.
- Existing route computation and multicast destination decode, if separable from
  the old reqGen/fork pipeline.
- Existing testbench case format, smoke cases, and remote DC/GLS wrapper style.
- Existing debug2 cases as functional references where the no-VC semantics apply.

Expected new pieces:

- A new router module name, for example `RouterWormholeMinimal`, with a matching
  generator entry point.
- A new depth-1 bundled-data buffer primitive suitable for the new timing style.
- A new atomic commit controller that does not use old `AsyncForkRequestBlock`
  launch semantics.
- New stage probes that report fire chain, control path, data path, and commit
  time for each handshake domain.

Stage 1 acceptance:

- Local RTL/Vivado smoke passes for unicast and multicast.
- No-VC compatible directed cases pass; VC-specific mixed interleaving cases are
  either rewritten for no-VC semantics or marked out of scope for Stage 1.
- Remote DC completes with `GTECH=0`.
- Router SDF GLS smoke passes.
- Report lists every Stage 1 handshake domain with:
  - fire chain source and sink;
  - data path source and sink;
  - control predicate path;
  - holder/state commit point;
  - measured SDF edge timing.

### Stage 2: Multiple Physical Lanes Per Direction

Goal: increase throughput while preserving the low-latency Stage 1 timing style.

Structure:

- Still no VC.
- Each direction may have multiple physical lanes.
- Each physical lane has its own depth-1 output buffer and holder state.
- Head chooses one lane per requested direction; body/tail reuse the chosen lanes.

Lane allocation direction:

- Avoid the old conservative approach where each input picks arbitrarily and OPM
  later resolves everything. That creates wasted attempts and extra arbitration
  latency.
- Use a per-direction coordinated lane allocator before commit:
  - collect head requests by direction;
  - observe free lanes in that direction;
  - assign unique lanes to winning inputs;
  - multicast input commits only if every requested direction receives a lane.
- Use round-robin only as a fairness policy over inputs, not as a long serial
  search in the critical path.

Recommended Stage 2 allocator shape:

```text
per direction:
  request vector from inputs
  free lane vector
  priority base / RR rotate
  combinational winner-rank and free-lane-rank match
  tentative lane assignment

per input:
  all requested directions assigned?
    yes: atomic commit selected lane set
    no : no commit
```

Important implementation preference:

- Keep lane allocation combinational and parallel by direction.
- Do not add a new handshake domain just to perform lane allocation unless STA
  proves the combinational cone cannot meet the fire-delay model.
- Preserve the same all-or-nothing multicast commit rule from Stage 1.

Stage 2 acceptance:

- Stage 1 tests still pass with one lane.
- Multi-lane directed tests show two independent inputs can use different lanes
  of the same direction when capacity exists.
- Multicast lane assignment is atomic across all requested directions.
- STA/SDF reports identify whether lane allocation or output commit is the new
  performance bottleneck.

### Stage 3: Optional VC Per Physical Lane

Goal: recover concurrency under mixed/interleaved traffic and reduce head-of-line
blocking after the low-latency physical-lane router is stable.

Structure:

- Each physical lane may contain multiple VCs.
- VC is added below the lane abstraction, not before the Stage 1/2 timing model.
- Head allocates `(direction, physical lane, VC)`.
- Body/tail use packet id or context to return to the same allocated VC.

Why optional:

- VC improves blocked-packet tolerance, but it adds allocation state, context
  banking, and another potential arbitration layer.
- Adding VC before validating the new low-latency base router risks recreating
  the old structural complexity.

Stage 3 acceptance:

- Mixed/interleaving cases that require multiple in-flight packets per input pass.
- A blocked VC does not consume or overwrite another packet's state.
- VC allocation and release are covered by RTL randomized tests and SDF smoke.
- Timing reports show whether VC adds an acceptable latency/area cost.

## 3. Design Rules For The Rebuild

Rules that should not be violated:

- Do not reuse the old pattern `large control combo -> DelayElement -> clock` as
  the primary timing structure for new fire paths.
- Do not update real holder/context/output state before the all-or-nothing
  commit decision.
- Do not let a failed multicast attempt leave partial grants or stale holders.
- Do not optimize away backpressure correctness to win one smoke case.

Preferred timing structure:

```text
input/buffer valid event
  |-> fire delay chain
  |-> route/mask/output-free/data path
          |
          v
       commit gate
```

Per-domain reports must explicitly separate:

- `fire_chain`: event to matched delay output.
- `control_chain`: route, mask, allocation, output availability.
- `data_chain`: flit data movement into the commit/output latch point.
- `state_chain`: holder/context update and release.
- `ack_chain`: when upstream ack is allowed to toggle.

## 4. Stage 1 Implementation Plan

Recommended implementation order:

1. Add the new module in parallel with existing RouterL1. Keep old RouterL1
   untouched except for shared helper extraction if absolutely necessary.
2. Define a minimal no-VC config: `dirs=parent+children`, `lanesPerDir=1`,
   input/output buffer depth 1.
3. Implement one input path and one output path first, then generalize over all
   directions.
4. Add multicast destination mask generation using the current route semantics.
5. Add holder/context state:
   - head writes requested output directions;
   - body/tail reuse stored mask;
   - tail releases stored holder state after successful commit.
6. Add all-or-nothing commit:
   - no output free, no input ack;
   - partial output availability does not update state;
   - successful commit updates output buffers and holder/context together.
7. Add local RTL tests:
   - single unicast packet;
   - single multicast packet;
   - blocked output retry;
   - multicast partial-block retry;
   - body/tail reuse of head route;
   - tail release followed by another head.
8. Add remote DC/SDF flow and probes only after RTL behavior is stable.

## 5. Evaluation And Risks

Feasibility:

- Stage 1 is feasible and should be much smaller than the existing VC RouterL1.
- It intentionally trades throughput and HOL-blocking tolerance for a clean
  timing experiment.
- It gives a clear answer to whether the new timing model can beat the old
  RouterL1 path.

Main risks:

- No VC means some current mixed/interleaving tests are not valid Stage 1
  requirements.
- Atomic multicast can starve under heavy contention unless fairness is added.
- Commit gating can accidentally become a new long control cone if route,
  allocation, output-free, and holder checks are implemented as one flat tree.
- SDF correctness still depends on pulse width and state update ordering, so
  gate-level probes are mandatory.

Optimization suggestions beyond the initial idea:

- In Stage 1, keep route/mask predecode small and local; do not instantiate the
  full old `LaneReservation` machinery for a single-lane design.
- For multicast, represent requested outputs as a compact direction mask first;
  expand to physical lane mask only at the output buffer boundary.
- Keep body/tail fast path separate from head path: body/tail should not rerun
  head allocation logic.
- Design the Stage 1 holder/context format so Stage 2 can extend it from
  `direction mask` to `(direction, lane)` without rewriting the packet flow.

## 6. Current Recommendation

Proceed with Stage 1 as a new parallel Router implementation:

```text
RouterWormholeMinimal
  no VC
  one lane per direction
  depth-1 buffers
  multicast all-or-nothing commit
  parallel fire/control/data timing model
```

Keep debug2 RouterL1 as the correctness fallback and regression reference.
Do not continue trying to turn the old RouterL1 pipeline into the high-performance
router by small patches; use it only for comparison, tests, and known-good
semantic behavior.
