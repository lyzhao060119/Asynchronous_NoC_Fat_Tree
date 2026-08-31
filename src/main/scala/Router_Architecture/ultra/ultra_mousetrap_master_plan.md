# Ultra/Mousetrap Router Master Plan

Last updated: 2026-07-28

This is the controlling document for the Ultra/Mousetrap router work. The
paper-derived circuit specification is
`docs/ultra_mousetrap_paper_architecture.md`; future implementation must follow
that document first, then this document, then the stage-specific task document.

## Non-Negotiable Interface Rule

Do not add, remove, rename, or reinterpret module ports unless the change is
first recorded in this document or in the active stage task document.

This rule exists because earlier work introduced extra helper interfaces such
as `activeMask`, `allComplete`, `reqX`, and `pathActive` without approval. That
must not happen again.

Allowed implementation work:

- implement exactly the ports listed for the active stage;
- add internal wires, comments, and local helper functions if they do not alter
  the public interface;
- add tests that observe existing ports.

Forbidden without an explicit document update:

- adding debug/probe ports;
- adding convenience masks, completion flags, valid bits, or path state ports;
- creating Router, NoC, IPM, or OPM shells before their stage;
- changing signal polarity to make a test pass;
- replacing a paper primitive with a functional shortcut.

If an interface seems insufficient, stop and update the plan first. Do not
"temporarily" add ports in code.

## Signal Naming And Polarity

Use paper-style names for Stage0 and Stage1 modules:

```text
RS, Req, Ack, Done, Grant, MG, PPE, ReqX, AckX
```

Meanings:

- `RS`: RouteSelected pulse/transition source for one Request Generator.
- `Req`: request output from one Request Generator to one OPM.
- `Ack`: acknowledge returned from the associated OPM.
- `Done`: active-high pending level, `Req ^ Ack`.
- `Grant`: active-high raw arbiter grant from OPM.
- `MG`: active-high masked grant from OPM grant masking.
- `PPE`: packet path enable.
- `ReqX`: source IPM request event/level entering AckGenerator.
- `AckX`: source IPM acknowledge event/level returned by AckGenerator.

The ReqGenerator C3 is asymmetric, not a normal symmetric C3:

```text
set PPE   when Done=1 and Grant=0
reset PPE when Done=0 and MG=0
hold PPE  otherwise
```

## Stage0: Primitive And Small Paper Blocks

Purpose: implement only the basic paper-level blocks needed before building
IPM/OPM.

Allowed files/modules:

- Verilog primitives under `src/main/resources/ASYNC/`:
  - `MullerC2`
  - asymmetric `MullerC3`
  - `DLatchBank`
  - `MousetrapStage`
  - `Mutex4`
  - `GrantMask`
- Chisel small modules under `Router_Architecture.ultra`:
  - `ReqGenAsymC3`
  - `PacketRouteSelector`
  - `ReqGenerator`
  - `AckGenerator`
- Primitive and small-module smoke tests.

Stage0 public interfaces:

```text
ReqGenerator:
  inputs : RS, ReqX, Ack, Grant, MG
  outputs: Req, Done, PPE

AckGenerator:
  inputs : ReqX, Done[N-1:0]
  outputs: AckX

PacketRouteSelector:
  inputs : RoutingInfo, ReqX, AckX
  outputs: RS[K-1:0], PRSReady

MousetrapStage:
  parameters: WIDTH
  inputs    : reset, ReqIn, DataIn[WIDTH-1:0], AckX, PRSReady
  outputs   : ReqX, DataOut[WIDTH-1:0]

  IPM binding: AckIn := ReqX, DataX := DataOut
```

`PacketRouteSelector` must contain the paper's ReqX/AckX XOR2 conversion,
matched delay, RoutingLogic, per-output AND2 barriers, and the `PRSReady`
active/release path. The old `packetValid`/raw-route-mask interface is invalid
and must not be used for integration.

Stage0 forbidden work:

- no Router shell;
- no NoC shell;
- no IPM Admission Stage;
- no OPM;
- no RequestSelection;
- no packet forwarding;
- no hidden path state;
- no extra debug/probe ports.

Completion criteria:

- Stage0 modules compile.
- Primitive Verilog elaborates.
- Stage0 task document is consistent with actual module interfaces.
- No Router/NoC files are introduced.

## Stage1: IPM Admission Stage

Purpose: build the input-side paper structure and the project multi-flit
request lifecycle after Stage0 is stable. OPM and arbitration remain absent.

Expected blocks:

- input Mousetrap/latch stage;
- PacketRouteSelector integration;
- one ReqGenerator per legal target OPM;
- AckGenerator over the exact Done set produced by those ReqGenerators;
- PRSReady/reopen control;
- multi-flit `ReqX` phase propagation through a selected branch;
- `PPE` persistence from Head until the future OPM withdraws `MG` after Tail.

Stage1 IPM interface:

```text
parameters: router config, coordinates, router level, physical ingress
inputs    : ReqIn, DataIn, Ack[K], Grant[K], MG[K]
outputs   : AckIn, DataX, Req[K], PPE[K]
```

`K` is the static ordered legal-output count for this ingress. Ultra uses a
no-U-turn topology: same-direction physical outputs are omitted during
elaboration, not gated with `canConnect`. In the current single-lane 5-port
baseline this gives four ReqGenerators per IPM. `ReqX`, `AckX`, `RS[K]`,
`Done[K]`, and `PRSReady` are internal. `ReqGenerator`
adds the documented Fig. 3 input `ReqX`; its full interface is
`RS, ReqX, Ack, Grant, MG -> Req, Done, PPE`.

For multicast, non-selected ReqGenerators hold `Req=Ack`; do not implement the
Transition paper's single-target `AckOthers` feedback XOR. The IPM has no
`TailPassed` port. Its release contract is: after the Tail Ack has completed,
the future OPM withdraws `MG`, and the existing asymmetric C3 clears `PPE` when
`Done=0 && MG=0`.

Interface rule:

- Stage1 may introduce IPM-level ports only after the paper architecture
  specification lists them.
- Do not add path-state, context, mask, or debug outputs unless documented.

Completion criteria:

- IPM-only smoke passes Head/Body/Tail single-target and multicast sequences
  with a branch responder test stub for `Ack/Grant/MG`.
- AckGenerator advances only after all selected branch Done levels clear.
- Tail completion followed by `MG` withdrawal clears selected PPE; unselected
  branches remain `Req=Ack`, `Done=0`, and `PPE=0`.
- No OPM or Router top is introduced in Stage1 unless the architecture
  specification is
  explicitly updated.

## Stage2: OPM And Arbitration

Purpose: build the output-side paper structure.

Expected blocks:

- Head-only atomic multicast admission before ReqGenerator, with static
  local-RS to global-output-mask mapping;
- packet-set holder: all outputs selected by one Head remain owned by that
  input until all selected OPMs report Tail completion;
- Mutex4-based arbitration;
- GrantMasking;
- RequestSelection;
- output Mousetrap/latch stage;
- TailPassed/holder behavior only if multi-flit support is in the Stage2 task
  document.

Interface rule:

- OPM ports must be defined before implementation.
- Do not add convenience grants, winners, holders, or debug vectors unless the
  Stage2 task document says so.
- Implement the packet-set arbitration requirements in
  `ultra_mousetrap_paper_architecture.md`; independent OPM grant aggregation is
  not an allowed replacement for atomic Head admission.

Completion criteria:

- OPM-only smoke passes single request, concurrent request, grant masking, and
  downstream busy cases.
- `Grant`/`MG` polarity matches the ReqGenerator C3 rule.
- Set-arbitration smoke proves no overlapping Head mask partially commits,
  disjoint masks coexist, owners persist through Body/Tail, and no output
  releases before every selected Tail branch completes.

### Stage2-A Completed: Independent OPM

The independent local OPM is implemented before fabric integration:

- `OPM(config, egressPort)` exposes only
  `Req[4], PPE[4], DataX[4], AckOut -> Ack[4], Grant[4], MG[4], ReqOut,
  DataOut, TailPassed[4]`.
- It composes the Fig. 5(b) Mutex4, GrantMasking, RequestSelection, Xbar Mux,
  and Modified Mousetrap V2 with Transition Fig. 4 local Head-to-Tail hold.
- The realized OPM is Chisel and `Mutex4` is its only primitive blackbox.
  `DataOut.isTail` is used directly with one-hot `MG` to form the Fig. 4
  per-source `TailPassed[4]` vector; no pass-through TailDetector module exists.
- Cross-OPM multicast TailJoin and packet-set holder release remain a later
  substage. No AtomicMulticastAdmission change, IPM/OPM fabric, Router, or NoC
  is part of this OPM-only substage.

## Stage3: IPM/OPM Integration

Purpose: connect the Stage1 IPM and Stage2 OPM blocks without yet building a
full NoC.

Expected behavior:

- one input can route to one or more OPMs;
- all selected branches must complete before `AckX`;
- OPM arbitration chooses one requester per output;
- no extra packet/context policy is added beyond the active stage document.

Completion criteria:

- integrated single-router internal smoke passes unicast and multicast.
- no Router top compatible with external NoC wrappers is introduced unless the
  Stage3 task document explicitly defines it.

## Stage4: Router Baseline

Purpose: create the first real Router module only after Stage0-3 are complete.

Allowed work:

- define external `RouterDirGroupedHSIO(1,1)` interface;
- instantiate IPM/OPM blocks;
- expose only documented probes;
- reuse current `RoutingLogic`.

Forbidden:

- no NoC16 integration in Stage4.

Completion criteria:

- single Router RTL smoke passes.
- no Stage1 baseline behavior changes.

## Stage5: NoC16 And Remote Flow

Purpose: integrate the completed Router into NoC16 and then run synthesis/GLS.

Allowed work:

- NoC16 topology wrapper;
- local NoC16 smoke;
- remote DC/GLS/SDF scripts only after local smoke passes.

Completion criteria:

- local single Router smoke passes;
- local NoC16 smoke passes;
- remote DC has `GTECH=0`;
- remote func GLS and SDF GLS pass.

## Change Procedure

When a module needs an interface change:

1. Update this document or the active stage task document first.
2. State why the existing interface is insufficient.
3. List the exact port changes and polarity.
4. Only then update code.
5. Run the stage's compile/smoke checks.

No undocumented interface change is acceptable, even if it makes the code easier
to write.
