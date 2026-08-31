# Ultra/Mousetrap Paper Architecture Specification

Last updated: 2026-07-31

2026-07-31 correction: the IPM's raw `RS` terminates at central Atomic
admission. ReqGenerator receives only the arbitration result (`admittedRS`),
not a separate raw-RS/`Admit` pair.

NoC16 wrapper 的 TAB/VCTM 调试过程、Transition Part III-F 时序约束，
以及 Fig.6/Fig.7 circular FIFO 的静态评估见
[Ultra NoC16 TAB/VCTM 调试、时序约束与 FIFO 静态评估](../../../../../docs/Ultra_NoC16_TAB_VCTM_Debug_Timing_FIFO_Review.md)。

This document is the sole architectural source for the Ultra/Mousetrap work.
It records the circuit structure visible in:

- Su et al., *An Ultra-Low-Cost and Multicast-Enabled Asynchronous NoC for
  Neuromorphic Edge Computing*, Fig. 3(b), Fig. 4, and Fig. 5.
- Bjerregaard et al., *A transition-signaling bundled-data NoC switch
  architecture for cost-effective GALS multicore systems*, Fig. 1, Fig. 2,
  Fig. 3, and Fig. 4.

The Ultra paper is a **single-flit** architecture. The transition-signaling
paper supplies the separately documented multi-flit extension. No module may
blend those two designs, add a port, or invent state without first adding the
exact change to this document.

## Mandatory Design Discipline

1. Reproduce the named paper signals and their shown connectivity before
   introducing an abstraction.
2. A signal absent from the diagrams and text is not an implementation
   convenience signal. It must not be added as a public port.
3. An RTL reset is allowed only as initialization infrastructure. It must not
   replace a paper protocol signal such as `PRSReady`, `AckX`, `Grant`, or
   `MG`.
4. A paper circuit whose gate equation is not unambiguously recoverable from
   the figure is recorded as a structural netlist requirement. It must be
   resolved from the figure/paper before RTL is written; it must not be
   replaced by a guessed Boolean equation.
5. Every module implementation review must identify its source figure and
   name every external signal exactly as this document does.

## Common Protocol And Datapath Model

Both papers use single-rail bundled data with a two-phase, non-return-to-zero
Req/Ack protocol.

- A data transfer is represented by a transition of `Req`; `Ack` completes
  the transfer by making a corresponding transition.
- The bundled-data relative timing constraint is one-sided: the request
  control path must arrive after the associated data has become stable.
- A baseline Mousetrap stage uses a bank of level-sensitive D-latches and a
  simple XNOR control relationship. The latch is normally transparent and
  temporarily opaque while its flit is protected.
- A matched delay line is a timing primitive, not a functional pipeline
  register. Its delay must cover the routed combinational cone it enables.

## Ultra Paper: Top-Level Switch Structure

Ultra Fig. 4 is an `N x N` organization of Input Port Modules (IPMs) and
Output Port Modules (OPMs). The figure illustrates `4 x 4`.

```text
external input
  -> IPM: Modified Mousetrap V1 -> DataX / ReqX / AckX
  -> Packet Route Selector -> RS[i]
  -> ReqGenerator[i] -> Req[i], PPE[i]
  -> OPM[i]: Arbiter -> Grant[i] -> GrantMasking -> MG[i]
              -> RequestSelection + XbarMux -> Modified Mousetrap V2
  -> external output

ReqGenerator Done[i] -> AckGenerator -> AckX
PRSReady ---------------------------------> Modified Mousetrap V1 reopen gate
```

For a multicast flit, every addressed OPM operates independently: it grants,
captures, and acknowledges its own branch. The source IPM emits `AckX` only
after every activated branch has completed.

## Ultra IPM Admission Stage: Exact Structural Blocks

### Modified Mousetrap Stage V1

Paper-facing external signals:

```text
inputs : ReqIn, DataIn, AckX, PRSReady
outputs: ReqX, DataX

IPM binding: AckIn := ReqX
```

`ReqIn/AckIn` is the external two-phase pair: V1 receives `ReqIn` and returns
the acknowledgement transition on `AckIn`. `ReqX/AckX` is the corresponding
internal two-phase pair: V1 emits `ReqX` and receives the completion transition
on `AckX`. As shown in Fig. 5(a), `AckIn := ReqX`: this is one acknowledgement
transition forked to the external input channel and to the internal IPM path,
not two independently generated acknowledgements.

Visible circuit elements in Ultra Fig. 5(a):

- one bank of level-sensitive D-latches for `DataIn -> DataX`;
- the baseline Mousetrap XNOR-style control network for the input two-phase
  transfer;
- one additional AND2 in the reopen control path;
- `ReqX` forked to AckGenerator and Packet Route Selector; the ReqGenerators
  are activated by their respective `RS[i]` signals;
- `AckX` returning from AckGenerator;
- `PRSReady` returning from the Packet Route Selector.

The additional AND2 is mandatory. `PRSReady` is active high while the current
packet has entered the routing/selection window, so it closes the normally
transparent input latch. The input register may reopen only after both
concurrent completion paths have settled:

```text
path A: AckX completes the packet transaction / normal Mousetrap reopen path
path B: the Packet Route Selector has withdrawn RS and PRSReady has returned low
```

Equivalently, the current V1 RTL control expression
`latch_en = reset | (~(ReqIn ^ AckX) & ~PRSReady)` has the intended direction:
the latch is transparent only when the two-phase transaction is idle and PRS is
no longer active. This prevents a fast next `DataIn` value from crossing the
routing logic and its AND2 barriers before those barriers have closed.
`PRSReady` is therefore a protocol input to V1, not an optional probe or valid
bit.

### Packet Route Selector (PRS)

The PRS in Ultra Fig. 5(a), together with the transition-paper Fig. 2 routing
barrier, has this paper-facing interface:

```text
inputs : RoutingInfo, ReqX, AckX
outputs: RS[0..K-1], PRSReady
```

`K` is the compile-time number of legal physical outputs for this IPM. The
project adopts a no-U-turn routing invariant: an ingress never returns a flit
to any physical output in its own direction. Therefore the instance parameter
`ingressPort` determines an ordered, static `legalOutputPorts` list, and every
`RS[i]` corresponds to physical OPM port `legalOutputPorts[i]`. This is an RTL
structural reduction, not a run-time `canConnect` gate. For the current
single-lane 5-port router, `K=4` for every ingress.

Project binding of `RoutingInfo`:

- It is the routing-relevant portion of the buffered `DataX` flit.
- The current project routing algorithm may receive the complete `Packet`
  bundle as this input.
- The physical ingress identity is an IPM instance parameter, not a new
  run-time PRS port. This preserves the paper interface while allowing the
  current `RoutingLogic` to suppress illegal return directions.

PRS circuit composition:

```text
ReqX ----\
          Matched Delay Line --\
                                XOR2 -> route enable -------|-> RS[i]
AckX -------------------------/                             |
RoutingInfo -> combinational Routing Logic -> route[i] ---- AND2 -> RS[i]
                                                           for every i
                                                               \\-> PRSReady
```

- `ReqX` first traverses the matched delay line. The XOR2 then converts the
  delayed request and `AckX` into a level representing the active local
  transfer.
- `Routing Logic` is synchronous-style combinational logic and may glitch.
- One AND2 barrier exists for every legal `RS[i]`; no raw routing-logic output may
  directly drive a ReqGenerator.
- The matched delay creates the barrier enable only after the routing logic
  has settled for the active request. `AckX` is intentionally not delayed by
  this line; it immediately clears the XOR2 level once it catches up with the
  delayed request.
- `PRSReady` is this delayed-request XOR active window. It rises after routing
  has settled and remains high while `RS` may be active. Modified Mousetrap V1
  uses this high level to keep its input latch closed.

`RS[i]` is an active-high, hazard-free level. It is not a request transition,
not a packet-valid signal, and not a stored route mask. The PRS contains no
invented route/context register.

The obsolete Stage0 `PacketRouteSelector(packet, packetValid, ingressPort ->
routeMask, routeSelected)` interface is nonconforming and must not reappear.
The implemented PRS uses only the interface and structural subblocks specified
above.

The Stage0 implementation binds the current project `Packet` to
`RoutingInfo`, uses a fixed physical ingress as an instance parameter, and
implements the following multi-flit PRS behavior without extra PRS state:

```text
head: delayed ReqX ^ AckX enables the PRS window; routing decision passes the
      per-output AND2 barriers and asserts RS for all selected multicast paths.
body: the PRS window still protects Mousetrap V1, but isHead=0, so all
      RS outputs remain low. PPE retains the previously selected path.
tail: identical to body at PRS level; the later OPM TailPassed mechanism clears
      PPE and releases the path. In the project IPM boundary this effect is
      represented by future-OPM MG withdrawal after Tail acknowledgement.
```

The RTL instantiates one `DelayElement` tap on `ReqX` before the XOR2. The
physical delay value is a relative-timing parameter to be closed against the
RoutingLogic cone in the later synthesis stage; it is not a functional state
element.

### Request Generator: One Per IPM-to-OPM Branch

Ultra Fig. 5(a) shows one generator for each candidate OPM.

For the Ultra single-flit circuit the visible inputs are `RS[i]`, `Ack[i]`,
`Grant[i]`, and `MG[i]`. The project multi-flit extension also connects the
Fig. 3 input-pipeline request, `ReqX`, to every generator:

```text
inputs : RS[i], ReqX, Ack[i], Grant[i], MG[i]
outputs: Req[i], Done[i], PPE[i]
```

With central atomic set admission, IPM raw `RS[i]` is an Atomic input only.
Atomic returns the sole ReqGenerator `RS[i]`: a losing input receives zero;
a winning input receives its unchanged four-bit route-selection mask. Thus the
ReqGenerator sees precisely the paper-level RouteSelected signal, but only
after complete multicast-set admission. No separate `Admit` signal exists.

Visible circuit elements:

- an `RS[i]`-clocked D flip-flop that samples `Ack[i]` to produce the correct
  two-phase polarity for `Req[i]`;
- XOR2: `Done[i] = Req[i] xor Ack[i]`;
- one asymmetric three-input C-element producing `PPE[i]`.

The C-element is the merger of two asymmetric C-elements described by Ultra:

```text
set PPE[i]   when Done[i] = 1 and Grant[i] = 0
reset PPE[i] when Done[i] = 0 and MG[i]    = 0
hold PPE[i] otherwise
```

`Grant` is the raw arbiter monitoring signal. `MG` is the masked one-hot grant
from GrantMasking. Their roles are not interchangeable.

### Project Multi-Flit Request Generator Extension

This extension combines Ultra Fig. 5(a) with the phase-conversion path in
transition-paper Fig. 3. It is required for multicast and intentionally does
not copy Fig. 3's `AckOthers` XOR feedback: that feedback makes sense only for
one selected output and would generate extra phase transitions when more than
one multicast target acknowledges.

Each branch contains these state and combinational elements:

- the existing `RS`-edge D flip-flop captures the phase value needed to make
  the Head's local `Req` differ from `Ack`;
- the asymmetric C3 retains `PPE` as the packet-path state;
- an XOR2 programmable inverter produces `ReqX xor phase`;
- a 2:1 mux selects that converted request while `RS | PPE` is high, and
  otherwise selects `Ack`.

The Atomic-produced `RS` programs the phase flip-flop and opens all winning
branches together. After C3 sets `PPE`, every later Body/Tail `ReqX`
transition therefore produces exactly one `Req` transition on each selected
branch. A branch not selected by the Head has `RS=PPE=0`, hence the mux holds
`Req=Ack` and `Done=0`.

The phase register data is `ReqX xor !Ack`, sampled on the `RS` transition.
Consequently, immediately after Head selection, `Req=ReqX xor phase=!Ack` and
the first two-phase request is emitted. `PPE` retains that phase selection
until the packet is released.

There is no fixed `DelayElement`, `admissionBlocked`, or `Admit` input inside
the Request Generator. Relative timing of the bundled-data paths remains a
physical constraint, not functional state inserted into this block.

The RTL therefore connects `Atomic.admittedRS` directly to the
ReqGeneratorBank `RS` input. Atomic must
continue to capture the raw Head mask internally while it is pending, then
emit the accepted mask as the self-timed ReqGenerator event.

`IPMAdmissionStage` has no `TailPassed` input. The future OPM owns the
physical tail detector; its `TailPassed[o]` level is connected to the separate
atomic multicast admission block, not added as an IPM convenience port. The
OPM follows this required release contract:

```text
Head accepted:  Ack follows Req; MG remains high while the packet owns output.
Body accepted:  Ack follows Req; MG remains high.
Tail accepted:  Ack follows Req; then OPM withdraws MG.
MG low + Done low: asymmetric C3 clears PPE; Req mux returns to Ack.
```

This retains Ultra's per-flit multicast completion atomicity: AckGenerator
does not change `AckX` until every selected branch has `Done=0`. It does not
claim that an IPM can arbitrate or detect a safe Tail release; that remains an
OPM responsibility.

### Ack Generator: One Per IPM

```text
inputs : ReqX, Done[0..N-1]
outputs: AckX
```

Circuit composition in Ultra Fig. 5(a):

- a NOR reduction over every `Done[i]`;
- an edge-triggered D flip-flop clocked by the all-complete condition;
- the flip-flop samples `ReqX` and produces `AckX`.

No `activeMask`, `allComplete` output, or extra completion port exists in the
paper interface. Inactive generators naturally have `Done=0`; the NOR covers
the complete fixed branch set.

## Project Requirement: Atomic Multicast Packet-Set Arbitration

This section is mandatory for the multi-flit multicast extension. It extends
the single-output packet holder in transition-paper Fig. 4 to a packet's full
multicast output set.

### Static Request Masks

- The current router has five physical directions. No-U-turn routing gives
  every IPM four local `RS` branches.
- Local `RS[3:0]` vectors are not globally comparable. The arbiter must first
  apply static `legalOutputPorts` mapping to create
  `requestMask[input][4:0]`, with the ingress-direction bit clear.
- The set arbiter handles one Head mask from each physical input. Each OPM
  still has at most four legal sources and retains its 4-way local structure.

### Admission Invariant

Each Head's complete `requestMask` is admitted or rejected as one unit;
partial admission is forbidden. For every pair of active packets:

```text
packetMask[i] & packetMask[j] == 0
```

Each admission epoch must produce a work-conserving maximal conflict-free set:
multiple pending Heads may pass only when all masks are pairwise disjoint and
all requested outputs are free. Maximum-independent-set optimization is not a
requirement.

Independent OPM grants must not commit data-path ownership before a complete
Head mask is admitted. This project does not use independent-grant aggregation
or a tentative-reservation/rollback protocol.

### Packet-Set Holder

Head commit establishes these state elements:

```text
outputOwner[o]  = none | inputId
packetMask[i]   = committed multicast mask
packetActive[i] = packet lifetime state
```

Before admitted RS reaches ReqGenerator, every output in `packetMask[i]` must
record owner `i`. While `packetActive[i]=1`:

- a new Head intersecting an occupied `outputOwner` is blocked;
- Body/Tail bypass Head admission and may use only outputs owned by `i`;
- selected OPMs preserve owner `i`, mux select, request latch/holder, and MG;
- selected outputs never release or change owner independently.

This is the multicast equivalent of the transition paper's Head-to-Tail mutex,
latch, and mux persistence.

### Tail Release

Each selected OPM raises `TailPassed[o]` only after its Tail flit is safely
accepted and branch Ack has caught Req. For packet `i`:

```text
allTailPassed[i] = AND over o selected by packetMask[i] of TailPassed[o]
```

Only this all-target condition releases the set: all selected `outputOwner`
entries clear, all selected OPMs withdraw MG, then C3 clears PPE from
`Done=0 && MG=0`. A faster branch keeps its holder and MG until every selected
Tail branch is complete. A released output remains unavailable while its
`TailPassed[o]` level is high, so an old level cannot release a newly admitted
packet.

### Asynchronous Arbitration And Fairness

- No periodic global clock or synchronous priority encoder is permitted.
- This project implements the rotating token with Chisel event-derived state:
  an internal self-timed ACG/DelayElement scan event clocks only the current
  scan step. The top-level clock is not used by arbitration state.
- A pending Head commits only if its entire mask is free and disjoint from masks
  already committed in the pass; token continuation permits non-overlapping
  Heads to coexist.
- Each complete five-cell scan moves the one-hot start token forward by one
  input, providing work-conserving round-robin fairness among conflicting ready
  Heads. Version one does not promise a strict starvation bound for adversarial
  changing masks.

### IPM/OPM Connection Rules

```text
PRS RS -> static mask map -> atomic admission -> admittedRS -> ReqGenerator
```

`AtomicMulticastAdmission` is a standalone five-input/five-output block in
this iteration. Its only public signals are `RS[5][4]`, `TailPassed[5]`,
`admittedRS[5][4]`, `admissionPending[5]`, and `outputOwner[5]` (`5` means
none). It does not add ports to `IPMAdmissionStage`, AckGenerator, PRS, or
ReqGenerator. Integration into the AckX hold path is a later fabric task.

`AtomicMulticastAdmissionVerilog` is the matching Verilog black-box version.
It has exactly this interface and preserves the same static mask mapping,
ACG/DelayElement scan event, one-hot token rule, packet-set holder, and
`TailPassed` re-allocation barrier. The Chisel module remains the executable
reference; any functional change must update and smoke-test both versions.

ReqGenerator receives only `admittedRS`; an unadmitted Head sends no Req to any
OPM. AckGenerator remains the paper circuit: the reduction-NOR of all branch
`Done` levels is an event clock for the Ack-following DFF. Its initial or
steady high level does not sample `ReqX`; branch activity must first lower the
event clock, and only the final `Done` 1-to-0 transition raises it. Atomic
admission therefore does not add a level-sensitive hold, latch, or pending
input to the AckGenerator path.

OPMs retain Ultra Fig. 5's Mutex4, GrantMasking, RequestSelection, mux, and V2
structure. Packet-set ownership prevents conflicting Heads reaching an OPM;
Mutex4 remains the paper-derived local asynchronous safety and Grant/MG source.

## Ultra OPM: Exact Structural Blocks

For each OPM `j`, Fig. 5(b) contains one input-side branch from every IPM.

Paper-facing OPM inputs:

```text
Req[0..N-1], PPE[0..N-1], DataX[0..N-1], AckOut
```

Paper-facing OPM outputs:

```text
Ack[0..N-1], Grant[0..N-1], MG[0..N-1], ReqOut, DataOut
```

Structural blocks and connectivity:

1. `N`-way asynchronous arbiter, shown as a 4-way arbiter in the paper.
   It receives the competing requests and produces raw `Grant[i]` monitoring
   signals. The Stage0 4-way form is structurally three `Mutex2` plus four
   `MullerC2` elements.
2. `GrantMasking` receives all raw grants and produces one-hot `MG[i]`, even
   during raw grant overlap.
3. `MG[i]` drives both the Xbar Mux select and RequestSelection enable.
4. `RequestSelection` admits only the winning request into Modified Mousetrap
   V2; all other request branches remain blocked.
5. The Xbar Mux chooses the matching `DataX[i]`.
6. Modified Mousetrap V2 captures the selected request/data and performs the
   output two-phase `ReqOut/AckOut` handshake. It contains dedicated internal
   Req/Ack coupling for every possible source IPM.
7. The acknowledgement belonging to the selected source returns as `Ack[i]`
   to that IPM's ReqGenerator.

Ultra is explicitly single-flit. It does not define `TailPassed`, holder state,
or route persistence in its OPM.

### Stage2-A Local OPM Realization

The project now realizes one independent `OutputPortModule(config, egressPort)`
with the fixed local four-source interface of Ultra Fig. 5(b):

```text
inputs : Req[4], PPE[4], DataX[4], AckOut
outputs: Ack[4], Grant[4], MG[4], ReqOut, DataOut, TailPassed[4]
```

It keeps the paper's `Mutex4 -> GrantMasking -> RequestSelection -> Xbar Mux
-> Modified Mousetrap V2` order. The realized `OPM` is fully expressed in
Chisel, with `Mutex4` as its only blackbox and every local state point written
using event-derived `withClockAndReset` storage. The OPM uses `DataOut.isTail`
directly with the existing one-hot `MG[4]` to produce only the selected
`TailPassed[i]`; there is no standalone TailDetector module. `TailPassed[i]`
closes only `L_i` and falls when `MG[i]` falls.

This is the Transition Fig. 4 local OPM behavior only. Cross-OPM multicast
TailJoin, sticky collection of different OPM completion times, and release of
the AtomicMulticastAdmission packet set remain a separately specified stage.

## Transition-Signaling Paper: Multi-Flit Extension

The following section is an intentional project extension, derived from the
transition-signaling paper. It is not claimed to be part of Ultra.

### IPM and Packet Route Selector

The transition paper Fig. 1/2 uses:

```text
input register outputs: Data, ReqX
acknowledgement return : AckX
PRS inputs             : routing/flit-type information, ReqX, AckX
PRS outputs            : RouteSelected[i]
```

Its PRS uses the same essential circuit as above: XOR2 converts `ReqX/AckX`
to a level, a matched delay line protects combinational routing, and AND2
barriers produce hazard-free `RouteSelected[i]` levels.

Packet behavior is split across modules:

```text
head: PRS computes RouteSelected; selected ReqGenerators assert PPE
body: PRS does not select a new path; PPE keeps the selected path active
tail: future OPM completes Ack then withdraws MG[i]; ReqGenerator C3 clears PPE[i]
```

The target Request Generator receives `RouteSelected[i]`, enters packet
processing mode, and holds `PacketPathEnabled/PPE` high. In this project's
multicast extension, a non-target generator holds `Req=Ack` instead of using
the single-target `AckOthers` phase-restoration network.

### Transition Request Generator

For one branch, Fig. 3 contains:

- `RouteSelected[i]` from PRS;
- `TailPassed[i]` from the OPM tail detector in the original single-target
  design; the project maps its safe release effect to `MG` withdrawal;
- acknowledgements from all OPMs for phase selection in the original
  single-target design; this is replaced by branch-local `Ack` for multicast;
- a latch storing packet-processing mode / `PacketPathEnabled[i]`;
- a programmable inverter (XOR2) selecting the polarity of `Req[i]` from
  `ReqX` and the stored mode;
- a matched delay on the request path.

`PPE` is set by the head and remains asserted for all body flits. In the
project extension, `MG` withdrawal after Tail completion clears it, releases
the future OPM mutex, and ends the path reservation.

### Transition OPM

Fig. 4 contains:

- a 4-input mutex;
- one request latch per input (`L1..L4`), initially opaque;
- per-input `PPE[i]` and `TailPassed[i]` control;
- an input mux selected once at packet start and held until tail;
- an output Mousetrap-like latch (`L5`) and data register;
- a Tail Detector;
- `ReqOut/AckOut` output handshake.

After the selected head, the mux and selected input latch remain programmed.
Each body flit propagates directly when the prior downstream `AckOut` has
arrived. Once the tail is transmitted, the Tail Detector produces
`TailPassed[i]`, which closes the selected request latch and causes the source
ReqGenerator to deassert `PPE[i]`.

### IPM Admission Stage: Project Integration Boundary

The Stage1 IPM admission stage has the following paper-facing boundary:

```text
parameters: router config, coordinates, router level, physical ingress
inputs    : ReqIn, DataIn, Ack[0..K-1], Grant[0..K-1], MG[0..K-1]
outputs   : AckIn, DataX, Req[0..K-1], PPE[0..K-1]
```

Internal-only wires are `ReqX`, `AckX`, `RS[]`, `Done[]`, and `PRSReady`.
`DataX` is shared bundled data for the future OPM branches. No `TailPassed`,
route-mask, all-complete, active-mask, or debug signal crosses this boundary.
The branch index to physical OPM-port mapping is the same static
`legalOutputPorts` instance parameter used by PRS; it is not carried as a
run-time signal.

## Stage Status And Prohibited Shortcuts

Current Stage0 status is **not complete**. The following shortcuts are
explicitly prohibited:

- treating `packetValid` as a replacement for the `ReqX/AckX` two-phase pair;
- omitting `PRSReady` from Modified Mousetrap V1;
- exposing a raw `routeMask` instead of barrier-protected `RS[i]`;
- inserting hidden PRS context/state for multi-flit support;
- adding `activeMask`, `allComplete`, `pathActive`, or debug/probe ports not
  present in the documented interfaces; `ReqX` is permitted only on the
  explicitly documented multi-flit ReqGenerator interface;
- using a functional priority encoder in place of the structural Mutex4;
- claiming Ultra supports tail handling before the transition extension is
  explicitly implemented.

## Required Review Checklist

Before a module is added or changed, the implementation review must answer:

1. Which paper figure defines this module?
2. What are its exact paper-facing ports and polarities?
3. Which internal cells are present: latch, DFF, XOR2/XNOR2, AND2, delay,
   C-element, mutex, mux, or tail detector?
4. Which relative-timing constraint protects each bundled-data or hazard-prone
   path?
5. Is this Ultra single-flit behavior or an explicitly documented
   transition-style multi-flit extension?

No implementation proceeds until all five answers are written in the active
stage task document.
