# CMR DC Relative-Timing Intent

Fig. 6 `RouteComputationLogic` keeps an explicit `DelayElement` on `Req_rc`
so `Mat` settles before `RouteSel`.  The **locked Fat vs Thin hop recipe**
(2026-08-30) is **1×`DEL050` on RCU, zero `rcu_matched_buf`, 1×`DEL050` on
OPM Ackin for Fat and Thin**; see
[`CURRENT_HOP_DELAY_BASELINE.json`](timing_baselines/CURRENT_HOP_DELAY_BASELINE.json)
and **Paper hop delay recipe** below.  Historical Thin NoC16 freeze text still
records 4×`DEL150` / Ackin `DEL250` / 16×`BUFFD0` as the CFifo catalog.  Do
not cite those, or Fat network Ackin 250, as the hop delay comparison.

WriteCounter, AddressRegister, and the write-interface RTL do not contain
`DelayElement`.  Pin-level inequalities for the thin NoC16 freeze are in
**Pin-level RTC catalog (step A freeze)**
below; remaining bundled-data relationships are a handoff to DC/P&R and
must be measured for both two-phase transitions and sign-off PVT corners
before SDF regression is accepted.

The fat-tree still instantiates an inter-level FIFO between routers.  The
current thin rollback netlist uses the Transition Fig. 6/7 four-slot
`CircularFIFO` (`CMR_USE_CIRCULAR_FIFO=1`).  The Scala emit default is
still the shared `AsyncFifo`/`ACG` chain unless that env is set.  The
archived predecessor `20260826_cmr_thin_1lane_rs_dc_01` is the last
AsyncFifo thin rollback.  Router CMR RTL is unchanged.  FIFO-output
bundled-data is a FIFO-side constraint, not an RCU/HeadPredictor delay.
On this DUT that is `TCF-RD-01` (16×`BUFFD0` on the Reqout XOR).  On
`AsyncStage` it remains `CMR-FIFO-01` (1×`DEL150` on `Out.Req`).

| ID | Thin? | Data/state that must settle first | Control/close event | Required implementation action |
|---|---|---|---|---|
| CMR-AR-01 | yes | `Address_field[23:0]` at `AddressRegisterUnit.LatchReg.D` | Head completion that closes `LatchReg.En`, then `Req_rc = LatchQ[24]` | Constrain the address path to settle before latch closure; preserve the common direct capture topology. |
| CMR-RCU-01 | yes | `RoutingLogic` result `Mat[i]` at `RouteSelAnd2.g/A1` | delayed `Req_rc ^ Ack_rc` at `RouteSelAnd2.g/Z` | Explicit `DelayElement` on `Req_rc` (default 4 × `DEL150`).  Do not replace this with WritePointer SDC.  Existing STA only samples L2 IPM0; step C must cover all 25 RCUs. |
| CMR-OPM-01 | yes | Mux1H flit at `DataReg.D` | `L1–L4.Q → XOR → L5.Q → RegEnable → DataReg.E↓` | **Primary V2 RTC** (Ultra OPM V2). Same paired form as `dataOutLatch.D` vs `E↓`. No `v2RequestMargin`; close by DC. Ackin DEL250 is not Tctrl. |
| CMR-OPM-01-CE | yes | `Ackout` / `TailPassed` DFF D | `V2CloseEvent.close_clock↑` | Same-close **measurement** sub-clause, not an inner-loop ID. Pulse width is a functional floor (Ackin 1×DEL250), not this RTC. |
| CMR-TP-01 | yes | `TailPassed` at `OPMSelector.PathLatch.R` and `MG = Grant & !TP` closing L1–L4 | next `PktPathEnable` / `Reqin` into that OPM | **New ID.** Packet-lifetime release must beat the next packet.  No explicit DEL. |
| CMR-LANE-01 | **N/A** | `SelectedAck ^ PhaseOffset` at `LanePhaseAdapter.AckLatch.D` | `Assigned` closing `AckLatch` | Fat-tree / multi-lane only.  Thin DUT has `ADAPTER=0`. |
| CMR-HS-01 | yes | whole input flit (`Head`/`Tail`/`Address`/`Reqin`) at the AddressRegister complete CP | `HeadPredictor.en_state_reg.CP` = `~(Reqin^Ackout)` | Preserve the **whole** bundle.  Head/Tail-only buffer experiment is disabled.  Never delay `complete`.  Current `PhaseSelector` has no `phase_reg`. |
| CMR-HS-02 | yes | `HandshakeComplete` `0→1` at `WriteCounter` CK | next `Reqin` returning complete to 0 | Library pulse width / recovery at CK.  Do not `+neg_tchk`.  Do not global min-delay `Reqin → CellFull.D`. |
| CMR-WP-01 | yes | `WritePointer` rotation finished (`CellFullLatch.E` closed/next open; next `CellFull` still current `Reqin`) | next `Reqin`/`Datain`/`Head`/`Tail` at any still-transparent `D` | Endpoint `DEL150+DEL050` = 0.20 ns (and TB `ACK_TO_NEXT_REQ_GUARD_NS`).  Do not change Fig. 7 XOR or add write-interface `DelayElement`. |
| CMR-XOR-01 | yes | unselected `AckoutCell` bits unchanged at `WritePointer[next]↑` | extra XOR of five cell Acks after the channel is already equal | Corollary of WP-01.  Not a separate data cone or optimization ID. |
| CMR-RP-01 | yes | `ReadPointer` rotation finished at next `ReqLatch.E` | next `ReqX`/`AckX` handshake toggle | Symmetric with WP-01 on `ReadCounter`.  Defined; not yet measured. |
| CMR-MTX-01 | yes | cross-coupled `Mutex2` NAND feedback | grant observation through NR4 filters | Preserve `ND2D1`+`ND2D2`+`NR4D1`.  **Not** a delay RTM.  Loop-break is analysis-only. |
| CMR-FIFO-01 | **N/A** | every `AsyncStage` `io.out.Data` Q | delayed `io.out.HS.Req` Q/`Z` | AsyncFifo-only.  Predecessor DUT.  Explicit 1×`DEL150` (`outReqDelay`).  Do not delay `fire_o`, RCU, or HeadPredictor. |
| TCF-HS-02 | yes | `Reqout`/`Ackin` equality at `ReadCounter` CK | next read handshake | 3×`BUFFD0` on Ackin → `*read_counter/U10/A1` only.  See [`CMR_Circular_FIFO_Timing_Intent.md`](CMR_Circular_FIFO_Timing_Intent.md). |
| TCF-RD-01 | yes | `SlotData` at mux / `bb.Data_out` | `bb.Reqout` | 16×`BUFFD0` on `*bb/U2/A*`.  Do not delay RCU or HeadPredictor.  Pin list in the Circular FIFO intent. |
| CMR-LINK-FWD-01 | yes | `bb.Data_out` at downstream IPM `Datain` | `bb.Reqout` at IPM `Reqin` | Step G.  L1↔L2 forward through the 8 FIFOs.  Freeze data, then min-delay exported Req only. |
| CMR-LINK-ENQ-01 | yes | OPM `Dataout` at `bb.Data_in` | OPM `Reqout` at `bb.Reqin` | Step G.  L1/L2 enqueue.  Not `DataReg.E`. |
| CMR-LINK-ACK-01 | yes | `read_counter.Reqout` at `U10/A2` | IPM `Ackout` at `U10/A1` | Step G.  Separate from Req.  Do not shrink OPM Ackin DEL from this ID. |
| CMR-LINK-IO-01 | yes | NoC port `Data_flit` | NoC port `HS.Req` | Step G.  16 cores + `top_input/output_0`.  Dummy top 1–3 N/A. |

Functional asynchronous state remains explicit in RTL: resettable `LHCNDQD`
latches, V2 close-event logic, counters, C-elements, the mutex feedback
topology, and the RCU `Req_rc` matched-delay chain.  They must be
preserved/mapped as their corresponding library primitives.  Fig. 7 write
timing must not be encoded as a `DelayElement` in `WriteCounter.v`.

## Pin-level RTC catalog (step A freeze)

This section is the **only** pin list step C may measure.  It does not
change RTL, SDC, DEL cells, or the netlist.  Numerical windows stay empty
until paired STA on the frozen DDC.

**DUT.** Thin NoC16 `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`: 5 routers
(4×L1 + 1×L2), 25 IPM / 25 OPM / 25 RCU, 8× four-slot `CircularFIFO`,
`LanePhaseAdapter` count = 0, `AsyncFifo` off.  Hierarchy prefixes:

```text
routerL1_{0,1}_{0,1}.InputPortModules_{0..4}.RouteComputationUnit
routerL2.InputPortModules_{0..4}.RouteComputationUnit
*.OutputPortModules_{0..4}
upwardLinkFifos_{0..3}.bb   downwardLinkFifos_{0..3}.bb
```

The AsyncFifo predecessor (`*.stages_{0..2}`) remains archived as
`20260826_cmr_thin_1lane_rs_dc_01`.

**How to read an entry.** `Tdata_max` is the latest data/state arrival
(rise and fall reported separately).  `Tctrl_min` is the earliest control
or close-event arrival of the stated polarity.  RTM uses the same launch
reference on both legs.  `no-path` is a fail for that ID, not a skip.
Loop cuts are analysis-only (`set_disable_timing` on the named launch
cells); they must not appear in production SDC.

**Human decisions frozen here (review before step B):**

1. **CMR-TP-01 is a new ID** (approved 2026-08-26).  Not folded into
   OPM-01 or RCU-01.  OPM-01 is same-flit data vs `E↓`.  TP-01 is
   packet-lifetime Tail release vs the next packet's `PktPathEnable`/`Reqin`.
2. **CMR-OPM-01 is the OPM inner-loop RTC** (approved 2026-08-27), same
   pair Ultra used: Mux → `DataReg.D` before XOR → L5.Q → `E↓`.
   Ultra STA/SDF closed this D/E check after deleting `v2RequestMargin`
   (zero OPM DEL075, Head D-stable-to-`E↓` 264 ps vs 5% of 194 ps) and
   did **not** put E-low pulse into the router RTM table; pulse lived on
   the sink endpoint (`DEL075`).  CMR therefore treats Ackin 1×`DEL250`
   and OPM-01-CE as the same-close **pulse/DFF floor and measurement**,
   not a second optimization class.  If thin GLS/STA fails, try OPM-01
   first, not a fatter Ackin DEL.
3. **`InternalAck` OR4 and the Fig. 7 5-XOR stay implementation notes**
   (approved 2026-08-26).  Not new IDs.

Deferred (not in this DUT's measurement set): fat-tree / LANE-01 /
Muller-C grant-join; remaining CircularFIFO IDs `TCF-WD/WP/RP/RE/HS-01`
(HS-02 and RD-01 are implemented on this DDC); P&R; 7%/10% outer RTM;
withdrawn WP `create_clock` + `Reqin→CellFull.D` min-delay.
`CMR-FIFO-01` is N/A on this DUT.  Inter-level link RTCs are step G
(`CMR-LINK-FWD/ENQ/ACK/IO-01`) on the F-closed DDC.

### CMR-AR-01  |  thin: yes

```text
Inequality
  Tmax(Address_field stable at LatchReg.D[23:0])
    < Tmin(En falling at LatchReg.E)
  After that close, Req_rc = LatchQ[24] is the RCU-01 launch.

data (max):  *AddressRegister/LatchReg/resettable_latch[0..23].latch_cell/D
             launch = IPM Datain.flit[25:2]  (PacketLayout X0Lo..Y1Hi)
             end    = those D pins
ctrl (min):  *AddressRegister/HeadPredictorBlock/en_state_reg/Q
             -> *AddressRegister/LatchReg/resettable_latch[*].latch_cell/E
             polarity = E fall (HeadPredictor captures Tail=0 on Head
             complete, En 1→0)
rise/fall:   address bits both edges; close is E fall only
loop cut:    none beyond ordinary latch-D analysis
existing:    none (no DelayElement in AddressRegisterUnit)
forbid:      do not add RTL DEL on En, Req_pc, or Address_field;
             do not retarget this constraint onto WritePointer
```

`LatchD = {Req_pc, Address_field}` so `latch_cell[24]` is phase-corrected
`Req_pc`, not an address bit.  `Req_rc` visibility is `latch_cell[24]/Q`.

### CMR-RCU-01  |  thin: yes

```text
Inequality
  Tmax(dest Q → RouteSelAnd_i.g/A1)     # Mat[i]
    < Tmin(Req_rc Q → RouteSelAnd_i.g/Z) # delayed Req_rc ^ Ack_rc through AND2

data (max):  start *AddressRegister/LatchReg/resettable_latch[0..23].latch_cell/Q
             end   *RouteComputation/RouteSelAnd_{0..3}/g/A1     (AN2 .A1 = Mat)
ctrl (min):  start *AddressRegister/LatchReg/resettable_latch[24].latch_cell/Q
             end   *RouteComputation/RouteSelAnd_{0..3}/g/Z
             BundlingSignal = MatchedDelay(Req_rc) ^ Ack_rc  →  g/A2
rise/fall:   both edges of dest Q and Req_rc Q; RouteSel is a pulse
             (opening while Mat is already stable is the critical edge)
loop cut:    set_disable_timing on the 25 AddressRegister latch cells so
             dest/req Q are startpoints (see run_sta_cmr_rcu_rtm.tcl)
existing:    4×DEL150 on Req_rc
             *RouteComputation/MatchedDelay/DelayUnit_chain_150/DelayUnit_delay[0..3].D0
             25 RCU × 4 cells = 100 DEL150 (role rcu matched delay)
STA today:   step C `20260827_092048_cmr_thin_paired_sta` on DDC
             `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01` reports per-bit
             A1 vs Z, rise and fall, on all 25 RCUs.  Predecessor AsyncFifo
             STA `20260827_003240_cmr_thin_paired_sta` is archived, not current.
forbid:      do not move this delay onto WritePointer / HS-02 / FIFO;
             do not replace RouteSelAnd2 with a shared AOI/OA decode
```

### CMR-OPM-01  |  thin: yes  (**primary V2 RTC**)

This is Ultra §4.4 / OPM V2, with CMR names.  Ultra’s accepted check
(`Ultra_Timing_Optimization_Log` §13) is the only OPM RTM used to drop
`v2RequestMargin`:

```text
Ultra:  DataX → MG Mux → dataOutLatch.D     before
        request Q → XOR4 → L5.Q → dataOutLatch.E↓

CMR:    Datain → Mux1H → DataReg.D          before
        L1_L4.Q → xorR → L5.D/Q → RegEnable → DataReg.E↓
```

`Reqout` / `Dataout` pin skew is **not** the RTM endpoint.  `L5.D` sits
on the **control** leg (the XOR arrival is what makes transparent L5.Q
flip and pull `E` down).  It is not a second data cone.

```text
Inequality
  Tmax(Mux1H at DataReg.D[*])  <  Tmin(XOR/L5.Q feedback at DataReg.E falling)

data (max):  start  *OutputPortModules_*/io_Datain_*_flit[*]
                    (or L1_L4 sibling Datain after MG Mux1H)
             end    *OutputPortModules_*/DataReg/resettable_latch[*].latch_cell/D
ctrl (min):  start  *OutputPortModules_*/L1_L4_*/resettable_latch[0].latch_cell/Q
             through xor-reduction → L5/resettable_latch[0].latch_cell/D then Q
             end    *OutputPortModules_*/DataReg/resettable_latch[*].latch_cell/E
                    (same net as L5.E = RegEnable)
             A mapped sample named that net n70 on one OPM; STA binds the
             hierarchical E pins, not a global net name.
polarity:    data both edges; close is E fall only
loop cut:    L5.Q → XOR with AckinDelay.Z → E.  Analysis-only disable of
             L5/DataReg when launching from D, or break Reqout↔E.
existing:    **no CMR RTL DEL on this pair.**  Ultra first had
             `v2RequestMargin` on XOR4→L5.D, then OPM_SYNTH steps=0 and
             still met 5% local D/E (Head 264 ps vs 194 ps required) with
             ordinary mapping, no XOR→L5 buffer.  CMR never instantiated
             that cell (`OPM.scala`: mux settling is DC/P&R).
             Ackin 1×DEL250 is **not** Tctrl: it delays E **rise** only.
STA today:   step C `20260827_092048_cmr_thin_paired_sta` on DDC
             `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`.  All 25 OPMs,
             Head/Body/Tail, rise/fall vs E fall.  See the Step C table.
             Predecessor AsyncFifo STA is archived, not current.
forbid:      do not add RTL DEL on Mux or XOR to fake this ID;
             do not use end-to-end Dataout/Reqout as the RTM;
             do not substitute a fatter Ackin DEL for a short D/E margin
```

Thin SourceCount = 4.  XOR-tree mapping is an implementation note.

Ultra passed router/NoC SDF **without** an OPM pulse-width RTM: pulse was
a sink-endpoint `DEL075` contract, listed under flow §4.5 as a check, not
as the inner-loop pair.  CMR keeps Ackin 1×DEL250 as that functional
floor (`*AckinDelay/DelayUnit_chain_250/DelayUnit_delay[0].D0`).  Shrink
only in step F, role `OPM_ACKIN`, after OPM-01 D/E is closed.

### CMR-OPM-01-CE  |  thin: yes  (measurement sub-clause, not inner-loop)

Same `E↓` as OPM-01, then `V2CloseEvent` `INVD0` → Ack/TP DFF CP.  Ultra
§4.5 lists DFF setup and E-low pulse as checks beside D/E; they were
**not** the OPM RTM used to accept OPM_SYNTH.  Measure with OPM-01; do
not open a DEL/sizing experiment.

```text
Inequality (report only)
  Tsetup(Ackout DFF D = L1_L4.Q)          vs close_clock↑
  Tsetup(TailPassed DFF D = DataReg.Q[26]) vs close_clock↑
  width(E low) / width(close_clock high)  ≥ library min pulse

data (max):  *OutputPortModules_*/FF0_FF3*/D
             TailPassed FF D  (DataReg.Q[26])
ctrl:        *OutputPortModules_*/RegClose/close_event_inv/ZN
             mapped DDC fallback: RegClose/latch_enable → close_clock
polarity:    close_clock rise (= E fall)
existing:    pulse floor = Ackin 1×DEL250 (reopen delay);
             inverter = sequencing only, not matched delay
STA today:   step C `20260827_092048_cmr_thin_paired_sta` bound the
             mapped fallback on all 25 OPMs; Tdata=0 after latch disable
             so RTM is n/a.  Not an inner-loop ID; see the Step C table.
forbid:      do not treat CE or pulse as a second RTC class;
             do not add Ackin/Reqout DEL to “fix” D vs E↓
```

### CMR-TP-01  |  thin: yes  (**new ID**)

Transition Tail release: `TailPassed` must drop the packet-lifetime path
and close the OPM request latches before the next packet is admitted.

```text
Inequality
  Tmax(TailPassed → PathLatch.R asserted
       AND MG = Grant & !TailPassed → L1_L4.E fallen)
    < Tmin(next PktPathEnable at Mutex.req / PathLatch.S
           and next Reqin at L1_L4.D)

data/state (max):
  start  TailPassed FF Q  (clocked by close_clock in OPM-01-CE)
  end-a  *RouteComputationUnit/Selector/selector[i].PathLatch/sr_cell/CDN
         R = TailPassed;  Clear = reset | R;  CDN = ~Clear
         (asserting R pulls CDN low on LHCNDQD sr_cell)
  end-b  *OutputPortModules_*/L1_L4_*/resettable_latch[0].latch_cell/E
         MG[i] = Grant[i] & !TailPassed[i]
ctrl (min):
  next PathLatch.S = RouteSel[i]
       *Selector/selector[i].PathLatch/sr_cell/E
  next PktPathEnable = PathEnabled at OPM Mutex req
       *OutputPortModules_*/Arbiter* req*  /  io_PktPathEnable_*
  next Reqin at *L1_L4_*/resettable_latch[0].latch_cell/D  while E is low
polarity:    PathLatch R / CDN falling; L1_L4 E falling;
             next RouteSel/PPE/Reqin either two-phase edge
existing:    none (no DelayElement on TailPassed, MG, or PathLatch)
forbid:      do not add RTL DEL on TailPassed to hide a GLS race;
             do not treat slow PPE deassert through the mutex as a
             substitute for MG closing L1–L4;
             PathLatch must remain reset-dominant LHCNDQD (not LHCSNDQD)
```

Router wiring (thin, laneCount = 1): `ipm.TailPassed(branch) :=
opm.Grant(source) && opm.TailPassed(source)`.  Measure at the OPM-local
`TailPassed` Q and at the RCU `Selector` R pin.

### CMR-LANE-01  |  thin: **N/A**

```text
DUT:         LanePhaseAdapter count must be 0 on this freeze.
data (max):  AckLatch.D = SelectedAck ^ PhaseOffset
             *LanePhaseAdapter/AckLatch/latch_cell/D
ctrl (min):  Assigned closing AckLatch.E
             *LanePhaseAdapter/AckLatch/latch_cell/E
existing:    none (comment in LanePhaseAdapter.v: paired RTC, not RTL buffer)
forbid:      do not instantiate adapters on the thin DUT to "exercise" this ID
deferred:    fat-tree / L1 1→2 and above (step H)
```

### CMR-HS-01  |  thin: yes

The current `PhaseSelector` is combinational Head-gating plus `Toggle`;
there is **no** `phase_reg`.  Older STA looking for
`PhaseSelectorBlock/phase_reg/D` is stale.  The complete CP that must see
the whole flit is `HeadPredictor.en_state_reg` (and the sibling
`WriteCounter` CK of HS-02).

`AddressRegisterUnit` polarities:

```text
HeadPredictor.complete = ~(Reqin ^ Ackout)   # XNOR, posedge = handshake equal
PhaseSelector.complete =  (Reqin ^ Ackout)   # XOR,  pending window, not a DFF CP
```

```text
Inequality
  Tmax(Head, Tail, Address_field, Datain, Reqin stable at their sink pins)
    < Tmin(posedge HeadPredictor.complete)

data (max):  Head  *AddressRegister/PhaseSelectorBlock/Head
                   → HeadInv.I  (INVD) and PhaseEnableAnd.A1 via n_head
             Tail  *AddressRegister/HeadPredictorBlock/Tail
                   → en_state_reg/D  (DFSNQ D=Tail, SDN=~reset)
             Addr  LatchReg.D[23:0]  (same pins as AR-01)
             Reqin/Ackout at AddressRegister ports
             (same channel as WriteInterface.Reqin / AckGenerator.Ackout)
ctrl (min):  *AddressRegister/HeadPredictorBlock/en_state_reg/CP
             polarity = complete rise (XNOR 0→1)
rise/fall:   Head/Tail/address both edges; CP is posedge only
existing:    none on the production path.
             Opt-in DC Head/Tail-only BUFFD0 (`hs01_head_hold_buf` /
             `hs01_tail_hold_buf`) is disabled: it desynchronized the
             bundle and is not an implementation of this ID.
             Opt-in IPM-Ackout external buffers (`CMR-HS-03` in
             run_dc_cmr_noc16.tcl, default 0 stages) are also not a
             catalog ID.
forbid:      never delay `complete` / HandshakeComplete;
             never add a Reqin-only RTL delay;
             never delay Head or Tail without the rest of the flit
```

### CMR-HS-02  |  thin: yes

```text
Inequality
  width(HandshakeComplete high at WriteCounter CK)
    > library min pulse  AND  next Reqin must not collapse 1/1 then 0/0
      into a missed pointer edge

data/ctrl:   start  WriteInterface.Reqin and Ackout
             CK     *WriteInterface*Counter*  CP or CK
                    HandshakeComplete = ~(Reqin ^ Ackout)
             also   recovery/removal of Reqin/Ackout vs that CK
polarity:    complete rise clocks the pointer; falling complete is the
             trailing edge of the pulse
existing:    library pulse check.  Historical insert_buffer 1×DEL250 on
             each WriteCounter hierarchical Reqin pin (`wp_hs02_req_dly`,
             25 cells) is **disabled** on the clean baseline
             (CMR_WP_REQ_DEL250_ENABLE default 0).  CellFull.D stays on
             undelayed io_Reqin when that ECO is on.
forbid:      do not +neg_tchk;
             do not global set_min_delay Reqin → CellFull.D
             (that slows capture of the **current** flit);
             do not delay complete
```

### CMR-WP-01  |  thin: yes

```text
Inequality
  Tmax(complete → old CellFullLatch.E falling) + latch margin
    < Tmin(Ackout@NoC input pin → source latch reopen → next Req/Data)

data (max):  start  WriteCounter CK / WritePointer Q
             end    *WriteInterface*ControlUnit_*CellFullLatch*/latch_cell/E
                    (5 cells per IPM, INITIAL_PHASE [0,1,0,1,0])
ctrl (min):  NoC input Ackout port
             → AsyncEndpointBank20.endpoints[*].source_turnaround_delay
               DEL150D1.I → DEL050D1.Z  (nominal 0.200 ns)
             → source Mousetrap AckX → next ReqX / DataOut
             Direct-boundary TB floor ACK_TO_NEXT_REQ_GUARD_NS=0.20 is
             the same contract when no structural endpoint is compiled.
rise/fall:   pointer E fall on the old cell; next Reqin either edge
loop cut:    pointer→E is internal; Ack→next-Req is a chip/TB boundary
existing:    endpoint 0.20 ns + TB GUARD.  NoC-only DDC does not contain
             the endpoint; run_dc_cmr_noc16.tcl records ownership in
             cmr_wp01_turnaround.rpt
STA today:   run_sta_cmr_wp_rtm.tcl  (pointer and HS-02/HS-01 pins)
forbid:      do not edit Fig. 7 XOR, WriteAckGenerator, or WriteCounter.v;
             do not insert DelayElement in the write interface;
             do not restore withdrawn create_clock on complete
```

### CMR-XOR-01  |  thin: yes  (corollary of WP-01)

```text
Inequality:  none independent of WP-01.
observation: WriteAckGenerator.Ackout = ^AckoutCell[4:0]
             If WP-01 fails, an unselected cell whose CellFull still
             tracks the new Reqin XORs an extra channel Ack.
existing:    none
forbid:      do not create a separate data-cone experiment or dont_touch
             the 5-XOR solely to “fix” XOR-01
```

The 5-XOR **mapping** (tree vs `xorR`) is an implementation note, not this
ID.  Promote it only if STA shows the merge tree itself manufactures a
false Ack after WP-01 is closed.

### CMR-RP-01  |  thin: yes  (defined, not yet measured)

```text
Inequality  (symmetric with WP-01 on the read side)
  Tmax(ReadHandshakeComplete → next ReqLatch.E open / current closed)
    < Tmin(next ReqX toggle at the still-wrong cell)

data (max):  start  *ReadInterface*/Counter*  CP/CK
                    HandshakeComplete = ~(ReqX ^ AckX)
             end    *ReadInterface*/ControlUnit_*/ReqLatch/latch_cell/E
                    ReadPointer one-hot, INITIAL_PHASE [0,1,0,1,0]
ctrl (min):  next ReqX at ReadRequestGenerator (xor of five Req Q)
             and AckX at ReadAckGenerator
existing:    none (no DelayElement in ReadCounter / ReadControlUnit)
STA today:   not in run_sta_cmr_wp_rtm.tcl
forbid:      do not copy write-side Reqin DEL250 onto ReqX;
             do not change ReadRequestGenerator 5-XOR
```

### CMR-MTX-01  |  thin: yes  (**not** a delay RTM)

Thin OPM uses `CMRMutexN(4)` → `Mutex4` → three `Mutex2`.  No Muller-C on
this path (grant is combinational `leaf_gnt & group_gnt`).

```text
Preserve, do not time as Tdata/Tctrl:
  Mutex2.q0_nand  ND2D1BWP12T30P140  A1=req0, A2=q1, ZN=q0
  Mutex2.q1_nand  ND2D2BWP12T30P140  A1=req1, A2=q0, ZN=q1   # intentional mismatch
  Mutex2.gnt*_filter  NR4D1  all four inputs tied to the same q node

loop cut:    analysis-only break of the NAND cross-couple; never in
             production SDC
existing:    topology only
forbid:      do not Boolean-collapse NR4 to an inverter;
             do not “close” mutex with ordinary setup/hold;
             do not substitute delay cells for mutual exclusion
deferred:    Muller-C grant-join in CMRTAC2/FlatArbiter (fat-tree widths)
```

Counts on this DUT: 25×Mutex4, 75×Mutex2.

### CMR-FIFO-01  |  thin: N/A on current DUT

Applies only to `AsyncStage` of an `AsyncFifo` chain (8 × 3 = 24 stages
on the predecessor).  The current rollback has `ASYNC_FIFO=0` and no
`outReqDelay` cells.  Pin list kept for the archived AsyncFifo DDC.

```text
Inequality
  Tmax(fire_o → Data Q)  <  Tmin(fire_o → delayed Out.Req visible)

data (max):  start  ACG fire_o CP of the stage data RegNext
             end    *stages_*/ io.out.Data  Q  (28-bit flit, incl. [26] Tail)
ctrl (min):  start  ACG output-link Req FF Q  (same fire_o)
             end    *outReqDelay/DelayUnit_chain_150/DelayUnit_delay[0].D0/Z
                    = io.out.HS.Req
polarity:    both edges (two-phase Req and data bits)
existing:    predecessor only: 1×DEL150, role fifo_out_req
forbid:      do not delay fire_o, RCU, or HeadPredictor for this hole;
             do not re-introduce AsyncStage DEL on the CircularFIFO DUT
```

### TCF-HS-02 / TCF-RD-01  |  thin: yes

Pin-level inequalities live in
[`CMR_Circular_FIFO_Timing_Intent.md`](CMR_Circular_FIFO_Timing_Intent.md).
This DDC implements the unit-qualified ECOs (do not resize without a new
candidate):

```text
TCF-HS-02  3×BUFFD0  *read_counter/U10/A1     → 24 cells
TCF-RD-01  16×BUFFD0 *bb/U2/A* (XOR4 CellReq) → 512 cells
           DC POST slack +13.053 ps vs 10% RTM on SlotData→Data_out
```

Remaining `TCF-WD/WP/RP/RE/HS-01` are defined but not ECO'd on this netlist.

Step G measures Ack-return and L1↔L2 link RTCs on these same 8 FIFOs
(`CMR-LINK-FWD-01`, `CMR-LINK-ENQ-01`, `CMR-LINK-ACK-01`) plus source/sink
ports (`CMR-LINK-IO-01`).  Those IDs live below; they are not a rewrite of
TCF-RD-01 / TCF-HS-02.

### CMR-LINK-FWD-01  |  thin: yes  (L1↔L2 deq)

Eight CircularFIFO deq links.  TCF-RD-01 is FIFO-internal (`SlotData` vs
`Reqout`).  This ID is the same bundle **at the next IPM**.

```text
Inequality
  Tmax(bb.Data_out at downstream IPM Datain)
    < Tmin(bb.Reqout at downstream IPM Reqin)

data (max):  start  *upwardLinkFifos_*/bb/Data_out*  or
                    *downwardLinkFifos_*/bb/Data_out*
             end    downstream IPM io_Datain_flit[*]
ctrl (min):  start  *bb/Reqout     (exported XOR, after TCF-RD-01 ECO)
             end    downstream IPM io_Reqin
             Do not use ReqLatch.Q: that node also feeds EmptyEnable.
rise/fall:   both edges
loop cut:    none (FIFO output pins to IPM ports)
existing:    TCF-RD-01 16×BUFFD0 on *bb/U2/A*; ZeroWireload link wires
             may be near-floor (< 0.020 ns) — skip, do not invent delay
mapping:     up dir d: L1 parent OPM_4 → FIFO → L2 InputPortModules_d
             down dir d: L2 OutputPortModules_d → FIFO → L1 parent IPM_4
             L1 of dir 0..3 = routerL1_1_1, _1_0, _0_1, _0_0
forbid:      do not delay RCU / HeadPredictor / ReqLatch Q;
             do not add RTL DEL on Reqout
```

### CMR-LINK-ENQ-01  |  thin: yes  (L1↔L2 enq)

```text
Inequality
  Tmax(OPM Dataout at bb.Data_in)
    < Tmin(OPM Reqout at bb.Reqin)

data (max):  start  *OutputPortModules_*/io_Dataout_flit[*]
             end    *bb/Data_in*
ctrl (min):  start  *OutputPortModules_*/io_Reqout   (L5.Q)
             end    *bb/Reqin
polarity:    both edges
existing:    none on the wire.  OPM-01 D vs E is the inner close, not
             this pin pair.  TCF-WD-01 Data_in→slot D was near-floor.
forbid:      do not constrain DataReg.E / RegEnable;
             do not add enqueue RTL DEL
```

### CMR-LINK-ACK-01  |  thin: yes  (Ack return, not Req)

Separate from FWD/ENQ.  Apply only after data freeze and Req min-delay.

```text
Inequality (deq)
  Tmax(read_counter.Reqout → U10/A2)
    < Tmin(downstream IPM Ackout → U10/A1)

data (max):  *bb/read_counter/Reqout → *read_counter/U10/A2
             (bb.Reqout is an output pin; it does not path back to CP)
ctrl (min):  downstream IPM io_Ackout → *read_counter/U10/A1
             (L1↔L2 Ack wire plus TCF-HS-02 3×BUFFD0 on A1)
existing:    TCF-HS-02 3×BUFFD0 on *read_counter/U10/A1

Inequality (enq, measure only)
  FIFO Ackout → upstream OPM io_Ackin
  This is the OPM Ackin DEL path (pulse floor).  Not a shrink ID.

forbid:      do not shrink OPM Ackin DEL from this ID;
             do not min-delay Ack into EmptyLatch.D if that slows
             current-slot capture; EmptyLatch stays TCF-RE-01
```

### CMR-LINK-IO-01  |  thin: yes  (source / sink)

```text
Inequality (source)
  Tmax(NoC input Data_flit → L1/L2 IPM Datain)
    < Tmin(NoC input HS.Req → IPM Reqin)

Inequality (sink)
  Tmax(OPM Dataout → NoC output Data_flit)
    < Tmin(OPM Reqout → NoC output HS.Req)

data/ctrl:   io_core_inputs_{0..15}_*  ↔  L1 child IPM/OPM
             io_top_input_0_*         ↔  routerL2/InputPortModules_4
             io_top_output_0_*        ↔  routerL2/OutputPortModules_4
             io_top_{input,output}_{1..3} dummy (Req=Ack); N/A
existing:    WP-01 endpoint 0.20 ns is **not** in this NoC-only compile
             (STRUCTURAL_ENDPOINTS=0).  TB GUARD 0.20 is the source
             contract.  Near-floor skip if Tdata < 0.020 ns.
forbid:      do not restore WP create_clock;
             do not instantiate endpoints only to exercise this ID;
             do not global min-delay Reqin → CellFull.D
```

### Implementation notes (not IDs)

**InternalAck OR4.**  `InternalAckModule` does `RouteSelected = |RouteSel`
then `Toggle.AckToggle.state_reg.CP`.  One Head may assert several
`RouteSel` bits; OR collapses them to a single `Ack_rc` toggle which
closes `BundlingSignal`.  Do not `dont_touch` the OR4 or rewrite it as a
5-XOR unless a trace shows bit-skew creating a false `Ack_rc`.

**Fig. 7 5-XOR.**  `WriteAckGenerator` is `Ackout = ^AckoutCell`.  Read
`ReqX = ^Req`.  OPM `ReqMerged = xorR(ReqSelection)`.  Mapping/tree
balance is leftover DC work, not an RTC class.

**HS-03 Ackout ECO.**  `run_dc_cmr_noc16.tcl` may insert buffers on the
IPM `Ackout` output pin (external branch only).  Default 0 stages.  It is
a possible later implementation of the WP-01/HS-01 turnaround, not a
catalog ID.

### Step A completion / review gate

Every ID above has pins, thin applicability, existing implementation, and
prohibitions.  TP-01 is added; OPM-01-CE is a sub-clause; OR4 / 5-XOR are
notes.  Step A is closed.  Step B archived the netlist below.  Step C
measured this CircularFIFO DDC; it did not write production SDC numbers
or shrink DEL cells.

## Step B — frozen thin NoC16 rollback baseline

Machine-readable copy:
[`docs/timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_baseline_manifest.json`](timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_baseline_manifest.json).
Any later candidate that fails structure, RTC, SDF, or TAB/VCTM rolls back
to this run.  Do not mutate these artifacts.

**Run.** DC `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`, LSF `11440801`,
`CMR_NOC16_DC_PASS`.  1-lane thin NoC16, `ASYNC_PRIMITIVES=asic`, delay
profile `P150_BASELINE`, `CMR_USE_CIRCULAR_FIFO=1`, bypass off, WP Reqin
DEL250 ECO off, Ack-feedback buffers 0.  Qualified CircularFIFO ECOs:
TCF-HS-02 3×`BUFFD0` (24 cells) and TCF-RD-01 16×`BUFFD0` (512 cells,
POST slack +13.053 ps).  `async_cmr_router.sdc` is a clock stub and is
**not** sourced by this NoC16 compile.

**Remote artifacts** (`/home/ghy19/Asynchronous_Router_CMR/outputs/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01/`):

```text
NoC_16nodes_post.v  sha256 f4d266db5773a7935d2946c6ae814c1b040f796f3271e6ed38ab8a2820ba581a
NoC_16nodes.ddc     sha256 f93611f5e83748663b335cf98f43e504957a93d35932929d769aa74db41b4363
NoC_16nodes.sdf     sha256 8937eaec75124ab1ebc24be51d5faa845fd238b272230535ffdf2e8ccdffee28
```

Identity is those three hashes.  Workspace RTL/TB/Tcl hashes in the
manifest are the archive-time source tree; they do not replace the frozen
DDC.  Re-emit or re-compile is a new candidate, not a rollback.

**Structure** (from `cmr_noc16_structure.rpt` / `async_primitives.csv`):

```text
ROUTER=5  FIFO=8  ASYNC_FIFO=0  CIRCULAR_FIFO=8  ADAPTER=0
IPM=25  OPM=25  MUTEX4=25  MUTEX2=75
RCU_DE=25  RCU_DEL150=100          # CMR-RCU-01
OPM_ACKIN_DE=25  OPM_ACKIN_DEL250=25  # close-loop floor, not OPM-01 Tctrl
FIFO_DEL150=0  FIFO_DFIRE_DEL150=0    # no AsyncStage
DEL150_TOTAL=100  DEL250_TOTAL=25  WP_REQ_DEL250=0
CFIFO_HS02_BUF=24                  # TCF-HS-02
CFIFO_RD01_BUF=512                 # TCF-RD-01
CLEAR=6669  SET=498  PATH_LATCH=100  V2_CLOSE=50
  # CLEAR = 5625 + 8×118 + 100 path; SET = 450 + 8×6
Mutex2: ND2D1 q0=75, ND2D2 q1=75, NR4 filter=150
RouteSelAnd2=100
```

**GLS** on this netlist, fail-fast async TB, SDF MAXIMUM,
`RX_CAPTURE_NS=5`, `ACK_TO_NEXT_REQ_GUARD_NS=0.20`, no probes, no
structural endpoints.  Annotation errors=0 and timing_violation_count=0
on every accepted case.

| Evidence | Run | Result |
|---|---|---|
| Canonical TAB p50 | `20260827_cmr_cfifo_noc16_rd01_eco16_full_01` job 11441601 | PASS 3000/3000 |
| Canonical VCTM p50 | same full run job 11442601 | PASS 3366/3366 |
| Same-run TAB/VCTM p50 | `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01` jobs 11440901 / 11441001 | both PASS |
| TAB r0p02–r0p90 | same full run | 10/10 PASS, 3000/3000 each |
| VCTM r0p02–r0p90 | same full run | 10/10 PASS |

Not this baseline: `20260826_cmr_cfifo_noc16_p50_01` (HS-02 only, TAB
UNEXPECTED at 2376 ns) and `20260827_cmr_cfifo_noc16_rd01_p50_02`
(14-stage RD01, DC FAIL slack −19.4 ps).

TB SHA-256 used by the accepted GLS (matches the archive-time workspace
files):

```text
tb_cmr_noc16_async_boundary_failfast.sv  b212fb2e9a40294dd7e2608ebe232179b35798962819d6ad6b1e9d1e9c4d3027
tb_noc16_async_boundary.sv               6d5a9f11f7f672b6ab2ed0c1ed6003ec4ae4277f5bdbf8957dae6a7dd4679de4
```

DC Tcl hash at archive: `run_dc_cmr_noc16.tcl`
`bb64e7f8ba29c7537be2d339a830a8bc489f7eee2bcb9803121779609d9fbaf6`.
`CircularFIFO.v`
`50073662942f837ecb00b5d67925e2f0ac280848987acc4d71dc32b0f482efbb`.

### Predecessor (AsyncFifo, kept)

[`docs/timing_baselines/20260826_cmr_thin_1lane_rs_dc_01_baseline_manifest.json`](timing_baselines/20260826_cmr_thin_1lane_rs_dc_01_baseline_manifest.json)
is not the current rollback.  DC `20260826_cmr_thin_1lane_rs_dc_01`, LSF
`11419801`, `ASYNC_FIFO=8 CIRCULAR_FIFO=0`, `FIFO_DEL150=24`,
`DEL150_TOTAL=148`, `CLEAR=5725 SET=450`.

```text
NoC_16nodes_post.v  sha256 d7311c0632e2aa6cc8dffc32b0adcdb5b3b0495f557b8af075c9cdff21d3dac9
NoC_16nodes.ddc     sha256 0d02e1295e1c937f0c35295a0e5da0b851cf833704ad4efedefac2509a9c1cc5
NoC_16nodes.sdf     sha256 aa01bebafb8ecd69ab19deba36916ac9494b9e2e26607abd1e9bcbe733fddb68
```

## Step C — paired STA on the frozen DDC (measurement only)

Scripts (reuse / extend, no production SDC, no DEL resize):

- [`scripts/asic_dc/cmr/sta_cmr_paired_lib.tcl`](../scripts/asic_dc/cmr/sta_cmr_paired_lib.tcl)
- [`scripts/asic_dc/cmr/run_sta_cmr_paired_catalog.tcl`](../scripts/asic_dc/cmr/run_sta_cmr_paired_catalog.tcl)
- [`scripts/asic_dc/cmr/run_sta_cmr_rcu_rtm.tcl`](../scripts/asic_dc/cmr/run_sta_cmr_rcu_rtm.tcl) (all 25 RCUs, per-bit `A1` vs `Z`)
- [`scripts/asic_dc/cmr/run_sta_cmr_opm_rtm.tcl`](../scripts/asic_dc/cmr/run_sta_cmr_opm_rtm.tcl) (all 25 OPMs)
- [`scripts/asic_dc/cmr/run_sta_cmr_mat_routesel.tcl`](../scripts/asic_dc/cmr/run_sta_cmr_mat_routesel.tcl) (L2 IPM0 sample + rise/fall pair)
- [`scripts/asic_dc/cmr/run_remote_cmr_noc16_sta_paired.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_sta_paired.py)
- [`scripts/asic_dc/cmr/extract_cmr_paired_sta.py`](../scripts/asic_dc/cmr/extract_cmr_paired_sta.py)

Dummy `set_max_delay 20` / `set_min_delay 0` windows are analysis-only so
unconstrained combo paths report arrival.  Rise and fall are separate
rows.  `no-path` is a fail for that ID.  Loop cuts stay in the STA Tcl.
No production SDC was written.  No DelayElement was resized.

**Run.** STA `20260827_092048_cmr_thin_paired_sta`, LSF `11443201`,
DDC `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`, PVT `ssg0p81v125c` /
ZeroWireload.  400 CSV rows: 200 RCU-01 + 150 OPM-01 + 50 OPM-01-CE.

RTM here is the conservative static pair
`(Tctrl_min - Tdata_max) / Tdata_max`.  It is **not** a production window
and is **not** a reason to shrink the RCU 4×DEL150 or OPM Ackin DEL250
(those wait for step F).  Wire-load makes every OPM's D/E pair look the
same; RCU data cones still differ by address decode.

| ID | Status | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | Shortfall (ns) | no-path | Loop cut |
|---|---|---|---:|---:|---:|---:|---:|---|
| CMR-AR-01 | not_measured_this_run | - | - | - | - | - | - | - |
| CMR-RCU-01 | measured | 200 (25 RCU × 4 bit × 2) | 0.3468 | 0.8887 | 156.3 | 0 | 0 | disable AddressRegister LatchReg latch_cell |
| CMR-OPM-01 | measured | 150 (25 OPM × H/B/T × 2) | 0.0473 | 0.2149 | 354.1 | 0 | 0 | disable DataReg (D endpoint); L1_L4 Q start; L5.E cut |
| CMR-OPM-01-CE | measured_segment | 50 | 0.000 | 0.0848 | n/a (Tdata=0) | 0 | 0 | RegClose latch_enable → close_clock (INVD0) |
| CMR-TP-01 | not_measured_this_run | - | - | - | - | - | - | - |
| CMR-LANE-01 | n_a_thin | - | - | - | - | - | - | ADAPTER=0 |
| CMR-HS-01 | not_measured_this_run | - | - | - | - | - | - | - |
| CMR-HS-02 | not_measured_this_run | - | - | - | - | - | - | - |
| CMR-WP-01 | not_measured_this_run | - | - | - | - | - | - | prior `run_sta_cmr_wp_rtm.tcl` |
| CMR-XOR-01 | corollary_of_wp01 | - | - | - | - | - | - | not a separate cone |
| CMR-RP-01 | not_measured_this_run | - | - | - | - | - | - | - |
| CMR-MTX-01 | not_delay_rtm | - | - | - | - | - | - | topology only |
| CMR-FIFO-01 | n_a_circular_fifo | - | - | - | - | - | - | AsyncFifo predecessor only |
| TCF-HS-02 | not_measured_this_run | - | - | - | - | - | - | unit ECO already on this DDC |
| TCF-RD-01 | not_measured_this_run | - | - | - | - | - | - | unit ECO already on this DDC |

**CMR-RCU-01.** Worst row: `routerL1_1_1/InputPortModules_0` bit0 rise,
Tdata_max=0.3468 ns (dest Q → `RouteSelAnd.g/A1`), Tctrl_min=0.8888 ns
(Req_rc Q → 4×DEL150 → `RouteSelAnd.g/Z`).  Control is the matched-delay
floor (~0.89 ns) on every RCU.  Opening edge (Z rise) is the
catalog-critical polarity.  0 no-path.

**CMR-OPM-01.** Worst row: `routerL1_0_0/OutputPortModules_0` Tail fall,
Tdata_max=0.0473 ns (`io_Datain` → Mux1H → `DataReg.D`), Tctrl_min=0.2149 ns
(`L1_L4.Q` → XOR4 → `L5.D/Q` → `DataReg.E` fall).  Head/Body/Tail are
within 4 ps of each other.  0 no-path.  Ackin DEL250 is not this Tctrl.

**CMR-OPM-01-CE.** Not an inner-loop ID.  This re-run bound
`RegClose/latch_enable` → `close_clock` (INVD0, 84.8 ps).  After the
analysis latch disable, Ackout/TailPassed D arrivals are 0 ns, so RTM is
not a ratio.  The V2 close used for optimization remains OPM-01 `E↓`.
Do not open a DEL experiment from CE.

Per-row CSV:
[`docs/timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta.csv`](timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta.csv).
Summary:
[`docs/timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta_summary.json).

Predecessor AsyncFifo STA (`20260827_003240_cmr_thin_paired_sta` on
`20260826_cmr_thin_1lane_rs_dc_01`) remains at
[`20260826_cmr_thin_1lane_rs_dc_01_paired_sta.csv`](timing_baselines/20260826_cmr_thin_1lane_rs_dc_01_paired_sta.csv)
(RCU worst RTM 159%, OPM 354%).  Router cones moved only a few picoseconds;
do not mix the two tables.

## Step D — datapath-first incremental DC (frozen for E)

This DDC is step E's seed.  Step B
(`20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`) remains the rollback if E
fails.  Do not replace B with this run.

**Method.** `read_ddc` of the frozen B DDC (hash `f93611f5…`), then
[`async_cmr_noc16_datapath.sdc`](../scripts/asic_dc/cmr/async_cmr_noc16_datapath.sdc)
and `compile_ultra -incremental -no_autoungroup`.  No RTL re-elaborate.
No TCF-HS-02 / TCF-RD-01 re-insert.  No control `set_min_delay`.  No DEL
resize.  Mutex, latches, existing DEL, `RouteSelAnd2`, CircularFIFO
counters/WCB/RCB, and the 24+512 ECO buffers stay `dont_touch`.

Targets are 0.95 × step-C / baseline Tdata_max
([`create_cmr_datapath_targets.py`](../scripts/asic_dc/cmr/create_cmr_datapath_targets.py)):

| Cone | From | To | Baseline Tdata_max | Target |
|---|---|---|---:|---:|
| CMR-RCU-01 | dest Q | `RouteSelAnd2.g/A1` | 0.346751 ns | 0.329 ns |
| CMR-OPM-01 | `io_Datain` | Mux1H → `DataReg.D` | 0.047316 ns | 0.045 ns |
| TCF-RD-01 | SlotData Q | `bb.Data_out` | 0.295973 ns | 0.281 ns |
| CMR-AR-01 | Datain.flit | `LatchReg.D[23:0]` | not in C | skipped (seed arrival 0 ns, below 0.020 ns floor) |
| TCF-WD-01 | `Data_in` | slot `data_reg.D` | measure-on-seed | skipped (same floor) |

Applied **58** max-delay pairs (25 Mat + 25 OPM + 8 RD-01).  Not Req /
Ack / E / `RouteSelAnd2.Z` / `bb.Reqout`.

**Run.** DC `20260827_cmr_cfifo_datapath_r1`, LSF `11443401`,
`CMR_NOC16_DC_PASS`.  Structure identical to B:

```text
ROUTER=5 FIFO=8 ASYNC_FIFO=0 CIRCULAR_FIFO=8 ADAPTER=0
IPM=25 OPM=25 MUTEX4=25 MUTEX2=75
RCU_DEL150=100 OPM_ACKIN_DEL250=25 FIFO_DEL150=0
DEL150_TOTAL=100 DEL250_TOTAL=25
CFIFO_HS02_BUF=24 CFIFO_RD01_BUF=512
CLEAR=6669 SET=498 PATH_LATCH=100 V2_CLOSE=50 RouteSelAnd2=100
```

**Remote artifacts** (`/home/ghy19/Asynchronous_Router_CMR/outputs/20260827_cmr_cfifo_datapath_r1/`):

```text
NoC_16nodes.ddc     sha256 91f6168230fd1d76d73bffcac45f82243f5feb456eb87780a98480fcca4a954d
NoC_16nodes_post.v  sha256 d783285b38e4163faeb544c59d7a49d00f4e961d7f8332e410152c0e60efee77
NoC_16nodes.sdf     sha256 11bde5117d944cfb146019508fbe55532f70b05ba2aa996855f9015e1e354de1
```

**GLS** on this netlist, fail-fast TB, SDF MAXIMUM, `RX_CAPTURE_NS=5`,
`ACK_TO_NEXT_REQ_GUARD_NS=0.20`.  Annotation errors=0,
timing_violation_count=0.

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11443501 | PASS 3000/3000 |
| VCTM p50 | 11443601 | PASS 3366/3366 |

Machine-readable freeze:
[`20260827_cmr_cfifo_datapath_r1_datapath_freeze.json`](timing_baselines/20260827_cmr_cfifo_datapath_r1_datapath_freeze.json).
Launcher: [`run_remote_cmr_noc16_datapath.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_datapath.py).

## Step E — Fig. 6 inner loop, RTM 0% (one RTC class per run_id)

Seed is the step-D DDC above (hash `91f61682…`).  Step B remains the
rollback if any knife fails.  Do not replace B or D until structure, the
full paired RTC table, strict SDF, and TAB/VCTM all pass for that knife.

**Method.** Same incremental `read_ddc` path as D.  Re-source
[`async_cmr_noc16_datapath.sdc`](../scripts/asic_dc/cmr/async_cmr_noc16_datapath.sdc)
so the data cones stay frozen, then source
[`async_cmr_noc16_inner.sdc`](../scripts/asic_dc/cmr/async_cmr_noc16_inner.sdc)
for **exactly one** RTC class and `compile_ultra -incremental
-no_autoungroup`.  No RTL re-elaborate.  No TCF ECO re-insert.  No DEL
resize.  No `set_disable_timing` in this production overlay.  Loop cuts
stay in the STA Tcl only.

Windows from frozen step-C `Tdata_max`
([`create_cmr_inner_targets.py`](../scripts/asic_dc/cmr/create_cmr_inner_targets.py)):

```text
Tctrl_min = Tdata_max × (1 + RTM)          # RTM 0% => Tdata_max
Tctrl_max = Tctrl_min + extra_slack        # default extra_slack = 0.100 ns
```

Pass is `Tctrl_min >= Tdata_max` (shortfall 0).  Leftover max-delay
slack after a squeeze is extra_slack / next-iteration material, not a
reason to add ECO DEL.  Frozen DEL roles are never squeezed: RCU max is
floored at measured Tctrl so the 4×DEL150 chain is not a shrink target
(that wait is step F).  Ackin 1×DEL250 is still not OPM-01 Tctrl.

**One class per run_id**, suggested order:

| Order | Class | This DUT | Inner action |
|---|---|---|---|
| 1 | CMR-OPM-01 | yes | `L1_L4.Q` → `L5.D` only (XOR combo); min 0.047 ns, max 0.147 ns. Not `DataReg.E`/`RegEnable` |
| 2 | CMR-RCU-01 | yes | `LatchReg[24].Q` → `RouteSelAnd.g/Z`; min 0.347 ns, max 0.889 ns (DEL frozen) |
| 3 | CMR-AR-01 | yes | measure-on-seed; skip if Tdata < 0.020 ns.  No RTL DEL on En |
| 4 | CMR-FIFO-01 | **refuse** | N/A on CircularFIFO |
| 5–9 | HS-01/02, WP-01, RP-01, TP-01 | later | launcher refuses until the earlier closable knives pass |
| — | OPM-01-CE, MTX-01, XOR-01, LANE-01 | not inner-loop | refuse |

Launcher: [`run_remote_cmr_noc16_inner.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_inner.py).
Each knife is an independent `run_id`, then paired STA on that DDC
(`run_remote_cmr_noc16_sta_paired.py`) and strict-SDF TAB/VCTM.  Failure
rolls back to B; do not start the next class from a failed DDC.

```text
python scripts/asic_dc/cmr/run_remote_cmr_noc16_inner.py --class CMR-OPM-01 --rtm 0
python scripts/asic_dc/cmr/run_remote_cmr_noc16_inner.py --class CMR-RCU-01 --rtm 0
python scripts/asic_dc/cmr/run_remote_cmr_noc16_inner.py --class CMR-AR-01 --rtm 0
```

**First knife (closed).** `20260827_cmr_cfifo_inner_opm01_rtm0`, class
`CMR-OPM-01`, RTM 0%, extra_slack 0.100 ns.  LSF DC `11443801`,
`CMR_NOC16_DC_PASS`.  25 XOR combo windows (`L1_L4.Q`→`L5.D`, min 0.047 /
max 0.147).  Datapath 58 max-delay pairs re-sourced.  Structure identical
to D/B (`RCU_DEL150=100`, `OPM_ACKIN_DEL250=25`, `CFIFO_HS02_BUF=24`,
`CFIFO_RD01_BUF=512`).  Catalog Tctrl remains `DataReg.E` (0.2149 ns);
the XOR segment is only the sizing endpoint.  Paired STA must
`reset_path` that XOR window or E goes no-path.

```text
NoC_16nodes.ddc     sha256 670ec96a7ff881b0d662d766dfd52d0cddeb2cec0bd097f7a5d19fc08929ab16
NoC_16nodes_post.v  sha256 fedc833428f8e8426beb393a3a23ca627f7cde3aa25cc597471b189eb3844c77
NoC_16nodes.sdf     sha256 127b2575d234bcc42db564c38d7bee96d4263e74c3954718e7dde23ede1ebcd7
```

Paired STA `20260827_cmr_cfifo_inner_opm01_rtm0_paired_sta3`, LSF
`11444901`.  Shortfall 0 at RTM 0% on every measured catalog row.

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0480 | 0.2149 | 348.0 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3248 | 0.8887 | 173.8 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0848 | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11444001 | PASS 3000/3000 |
| VCTM p50 | 11444101 | PASS 3366/3366 |

Annotation errors=0, timing_violation_count=0.  Step B remains rollback.
This DDC is the seed for `CMR-RCU-01`, not a replacement of B.

Machine-readable freeze:
[`20260827_cmr_cfifo_inner_opm01_rtm0_inner_freeze.json`](timing_baselines/20260827_cmr_cfifo_inner_opm01_rtm0_inner_freeze.json).
Paired table:
[`20260827_cmr_cfifo_inner_opm01_rtm0_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_inner_opm01_rtm0_paired_sta_summary.json).

**Second knife (closed).** `20260827_cmr_cfifo_inner_rcu01_rtm0`, class
`CMR-RCU-01`, RTM 0%, extra_slack 0.100 ns.  Seed is the OPM-01 DDC above.
LSF DC `11445001`, `CMR_NOC16_DC_PASS`.  100 control windows
(`LatchReg[24].Q`→`RouteSelAnd.g/Z`, min 0.347 / max 0.889, 4×DEL150
frozen).  Structure identical to D/B (`RCU_DEL150=100`,
`OPM_ACKIN_DEL250=25`).  Paired STA resets the OPM XOR window and these
RCU Tctrl pairs before measuring unconstrained catalog delay.

```text
NoC_16nodes.ddc     sha256 abf891c90c43600c859ac2567352d257a52810d379461b213986768f2c716bd7
NoC_16nodes_post.v  sha256 7c270df955ce21ed0ffa1c9917a68c227e75b0f1d2c8c70c2d1e2bcd36026619
NoC_16nodes.sdf     sha256 ccd51432ebc4e70c667e15c7b0968a748c687acd0fada329cfe9cb36f5bf9766
```

Paired STA `20260827_cmr_cfifo_inner_rcu01_rtm0_paired_sta`.  Shortfall 0
at RTM 0% on every measured catalog row.  Unconstrained RCU Tctrl is
0.8729 ns (seed was 0.8887 ns): cells around the frozen DEL sized, DEL
count unchanged.

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0463 | 0.2166 | 368.2 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3155 | 0.8729 | 180.3 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0560 | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11445201 | PASS 3000/3000 |
| VCTM p50 | 11445301 | PASS 3366/3366 |

Annotation errors=0, timing_violation_count=0.  Step B remains rollback.
This DDC is the seed for `CMR-AR-01`, not a replacement of B.

Machine-readable freeze:
[`20260827_cmr_cfifo_inner_rcu01_rtm0_inner_freeze.json`](timing_baselines/20260827_cmr_cfifo_inner_rcu01_rtm0_inner_freeze.json).
Paired table:
[`20260827_cmr_cfifo_inner_rcu01_rtm0_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_inner_rcu01_rtm0_paired_sta_summary.json).

**Third knife (closed, skip).** `20260827_cmr_cfifo_inner_ar01_rtm0`, class
`CMR-AR-01`, RTM 0%.  Seed is the RCU-01 DDC above.  LSF DC `11445401`.
Measure-on-seed: all 25 sites `SKIP_NEAR_FLOOR` (`tdata=0`, same as the
step-D address-cone skip).  No `HeadPredictor.Q`→`LatchReg.E` window, no
RTL DEL on `En`.  Structure identical to D/B.  Catalog AR stays
`not_measured_this_run`; OPM/RCU shortfall remains 0.

```text
NoC_16nodes.ddc     sha256 b5cbd6b4fad40196e7957ba1abf06bfa77757a1c729fcb2ef2b829bc9c8bca9c
NoC_16nodes_post.v  sha256 20b6337b9e45355d91931006ceda1d8e0a27088c3fea140cfd3eb48b4f5914fd
NoC_16nodes.sdf     sha256 eb1a9be8ab7ada83092972c66a4a89c294d194a894278842b86e34f316ac0e05
```

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0463 | 0.2166 | 367.9 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3155 | 0.8729 | 180.3 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0560 | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11445601 | PASS 3000/3000 |
| VCTM p50 | 11445701 | PASS 3366/3366 |

Annotation errors=0, timing_violation_count=0.  Closable E classes at
RTM 0% are done.  Launcher still refuses FIFO-01 (CircularFIFO N/A) and
HS/WP/RP/TP (later).  Step B remains rollback.

Machine-readable freeze:
[`20260827_cmr_cfifo_inner_ar01_rtm0_inner_freeze.json`](timing_baselines/20260827_cmr_cfifo_inner_ar01_rtm0_inner_freeze.json).
Paired table:
[`20260827_cmr_cfifo_inner_ar01_rtm0_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_inner_ar01_rtm0_paired_sta_summary.json).

## Step F — outer RTM 5%, then one explicit DEL role

0% inner-loop shortfall is closed on the last E DDC
(`20260827_cmr_cfifo_inner_ar01_rtm0`, hash `b5cbd6b4…`).  Step B remains
the rollback.  7%/10% stay plan H.

**Raise the target first.** Incremental `read_ddc` from that E DDC, re-source
the datapath overlay, then
[`async_cmr_noc16_inner.sdc`](../scripts/asic_dc/cmr/async_cmr_noc16_inner.sdc)
class `CMR-OUTER-RTM5` (OPM-01 + RCU-01 windows; AR-01 still measure-on-seed
and floor-skip).  Windows from the last E paired STA, not a new Tdata hunt:

```text
Tctrl_min = Tdata_max × 1.05
Tctrl_max = Tctrl_min + extra_slack   # RCU max still floored at measured Tctrl
```

Pass is shortfall 0 at **5%** (`Tctrl_min >= 1.05 × Tdata_max`) plus
structure, the full paired table, and strict-SDF TAB/VCTM.  This knife does
**not** resize DEL cells.  Ackin 1×DEL250 is still not OPM-01 Tctrl.

Launcher:
[`run_remote_cmr_noc16_outer.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_outer.py).

```text
python scripts/asic_dc/cmr/run_remote_cmr_noc16_outer.py --rtm 0.05
```

**Only then ask STA if one explicit DEL is overdesigned.**  Plan order, one
role: RCU 4×DEL150, FIFO 1×DEL150, OPM Ackin DEL250, endpoint 0.20 ns.
[`create_cmr_del_overdesign.py`](../scripts/asic_dc/cmr/create_cmr_del_overdesign.py)
scores `Tctrl - 1.05×Tdata` against one library step.  FIFO is N/A
(CircularFIFO).  Ackin is the pulse floor, not the D/E pair — do not shrink
it from OPM-01 overdesign.  The 0.20 ns endpoint is not in this compile.

**5% knife (closed).** `20260827_cmr_cfifo_outer_rtm5`, class
`CMR-OUTER-RTM5`, RTM 5%, extra_slack 0.100 ns.  Seed is the last E DDC
above.  LSF DC `11445801`, `CMR_NOC16_DC_PASS`.  125 control windows
(25 OPM XOR + 100 RCU Req→Z) plus 25 AR `SKIP_NEAR_FLOOR`.  OPM min/max
0.049 / 0.149 ns; RCU min/max 0.331 / 0.873 ns (4×DEL150 still frozen).
Structure identical to E/D/B (`RCU_DEL150=100`, `OPM_ACKIN_DEL250=25`,
`CFIFO_HS02_BUF=24`, `CFIFO_RD01_BUF=512`).

```text
NoC_16nodes.ddc     sha256 dc1acd0fb88175030eebd3e80bd4d6e2cd84e91658cd3247d8b3a910a791373e
NoC_16nodes_post.v  sha256 00bdf7d0182521191c63f1994ebcd5fe27e2e0608287ec79202ee778f7f0bc93
NoC_16nodes.sdf     sha256 7d4cf19a27905dccc6c714b4b2c2f56a24e02c5fd1147b749431ce3db951f574
```

Paired STA `20260827_cmr_cfifo_outer_rtm5_paired_sta`, LSF `11445901`.
Shortfall 0 at RTM 5% on every measured catalog row.  Arrivals match E
(incremental windows already met).

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | 5% required | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0463 | 0.2166 | 367.9 | 0.0486 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3155 | 0.8729 | 180.3 | 0.3313 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0560 | n/a | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11446001 | PASS 3000/3000 |
| VCTM p50 | 11446101 | PASS 3366/3366 |

Annotation errors=0, timing_violation_count=0.

DEL overdesign at 5%
([`20260827_cmr_cfifo_outer_rtm5_del_overdesign.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_del_overdesign.json)):
RCU 4×DEL150 is 0.542 ns (~3.6 steps) over the 5% floor.  FIFO N/A.
Ackin DEL250 is not OPM-01 Tctrl.  Endpoint 0.20 ns is not in this compile.
First eligible role: **RCU_DEL150 4→3**.

Machine-readable freeze:
[`20260827_cmr_cfifo_outer_rtm5_outer_freeze.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_outer_freeze.json).
Paired table:
[`20260827_cmr_cfifo_outer_rtm5_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_paired_sta_summary.json).

**RCU shrink knife (closed, one role).** `20260827_cmr_cfifo_outer_rtm5_rcu3`.
Seed is the 5% DDC above.  `CMR_DEL_SHRINK_ROLE=RCU_DEL150` removes
`DelayUnit_delay[3]` on all 25 MatchedDelay chains before incremental
compile.  LSF DC `11446201`.  Structure otherwise identical
(`RCU_DEL150=75`, `OPM_ACKIN_DEL250=25`).  Same 5% windows re-applied.
RTL `RcuMatchedDelaySteps` default remains 4; this is a mapped ECO, not a
re-elaborate.  A later full compile must set `CMR_RCU_MATCHED_DELAY_STEPS=3`
to keep 75 cells.  Do not chain a second DEL role on this knife.

```text
NoC_16nodes.ddc     sha256 050675a382ef0528b9c28a51fda6eb00667f4be87f8b21e458e0822a67274e4e
NoC_16nodes_post.v  sha256 8fb53d3e2ce05917e8a89d9ea037d8420f440dde712f595d1fe5bdbc2a3da5c9
NoC_16nodes.sdf     sha256 f2185eef9d3e910a6dc90c163dd0a139c26fedf388afb2434d7a8a6a1eff8cf7
```

Paired STA `20260827_cmr_cfifo_outer_rtm5_rcu3_paired_sta`, LSF `11446301`.
RCU Tctrl 0.873 → 0.673 ns (worst RTM 180% → 107%).  Still 0 shortfall at
5% (required 0.341 ns).  OPM-01 unchanged in kind (388%, shortfall 0).

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | 5% required | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0441 | 0.2149 | 387.8 | 0.0463 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3248 | 0.6731 | 107.5 | 0.3411 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0848 | n/a | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11446401 | PASS 3000/3000 |
| VCTM p50 | 11446501 | PASS 3366/3366 |

Annotation errors=0, timing_violation_count=0.  Step B remains rollback.
Further F knives (RCU 3→2, tail DEL150→BUFFD0, OPM XOR extra_slack) continue
below.  Do not start G from this DDC.

Machine-readable freeze:
[`20260827_cmr_cfifo_outer_rtm5_rcu3_outer_freeze.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_rcu3_outer_freeze.json).
Paired table:
[`20260827_cmr_cfifo_outer_rtm5_rcu3_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_rcu3_paired_sta_summary.json).

**RCU 3→2 (closed).** `20260827_cmr_cfifo_outer_rtm5_rcu2`.  Seed is rcu3.
`CMR_DEL_SHRINK_ROLE=RCU_DEL150` drops the highest remaining
`DelayUnit_delay[2]` on all 25 MatchedDelay chains (75→50).  Windows rebuilt
from rcu3 STA (RCU max tracks 0.673 ns).  LSF DC `11447101`.
`RCU_DEL150=50`, `OPM_ACKIN_DEL250=25`.  Ackin / FIFO / WP untouched.

```text
NoC_16nodes.ddc     sha256 979d45ef98350656a9495c2bddb3a231f6d0c905a4869a7914e3fcdc7fe96358
NoC_16nodes_post.v  sha256 fba0496cffcfd651e477fa0c55d17613743bc72aaa61850cf637430a5d77f2b5
NoC_16nodes.sdf     sha256 033b035b013bae5df8a55553321d5fcccf0a31cb269e3e1b0f9a031e5a338373
```

Paired STA `20260827_cmr_cfifo_outer_rtm5_rcu2_paired_sta`, LSF `11447301`.
RCU Tctrl 0.673 → 0.466 ns (worst RTM 107% → 43.8%).  5% shortfall 0
(required 0.341 ns).  One measured DEL150 on this path is ~0.207 ns, so a
further full drop would undershoot; residual uses BUFFD0.

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | 5% required | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0441 | 0.2149 | 387.8 | 0.0463 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3248 | 0.4664 | 43.8 | 0.3411 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0848 | n/a | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11447501 | PASS 3000/3000 |
| VCTM p50 | 11447601 | PASS 3366/3366 |

Machine-readable freeze:
[`20260827_cmr_cfifo_outer_rtm5_rcu2_outer_freeze.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_rcu2_outer_freeze.json).
Paired table:
[`20260827_cmr_cfifo_outer_rtm5_rcu2_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_rcu2_paired_sta_summary.json).

**RCU tail DEL150 → 8×BUFFD0 (closed).** `20260827_cmr_cfifo_outer_rtm5_rcu1_buf8`.
Seed is rcu2.  `CMR_DEL_SHRINK_ROLE=RCU_DEL150_TO_BUF` bypasses
`DelayUnit_delay[1]` and inserts eight `BUFFD0BWP12T30P140` on each of the
25 tail loads.  LSF DC `11447701`.  Structure `RCU_DEL150=25`,
`RCU_MATCHED_BUF=200`.  RTL `RcuMatchedDelaySteps` still must stay ≥ 1 on a
later re-elaborate (`CMR_RCU_MATCHED_DELAY_STEPS=1`).

```text
NoC_16nodes.ddc     sha256 a873155e8eb444f67b50a9d74f4b879fe34b8cdf61dfacf57dec88e2b7da91d6
NoC_16nodes_post.v  sha256 3829892a696ef483d6b213e9bcf1c983f0d6d7e99edd28e6252c4826f3ee21a6
NoC_16nodes.sdf     sha256 0b58095223a1a76dd29b12a6bea278ec6bb1c2ad144879b9ee6eb7ede08671bb
```

Paired STA `20260827_cmr_cfifo_outer_rtm5_rcu1_buf8_paired_sta`, LSF `11447801`.
RCU Tctrl 0.466 → 0.389 ns (worst RTM 43.8% → 21.7%).  Leftover 0.048 ns is
less than one measured DEL150 and the last DEL150 cannot be removed
(`RcuMatchedDelaySteps > 0`).  RCU floor for this DUT.

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | 5% required | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0441 | 0.2149 | 387.8 | 0.0463 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3248 | 0.3894 | 21.7 | 0.3411 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0848 | n/a | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11447901 | PASS 3000/3000 |
| VCTM p50 | 11448001 | PASS 3366/3366 |

Machine-readable freeze:
[`20260827_cmr_cfifo_outer_rtm5_rcu1_buf8_outer_freeze.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_rcu1_buf8_outer_freeze.json).
Paired table:
[`20260827_cmr_cfifo_outer_rtm5_rcu1_buf8_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_rcu1_buf8_paired_sta_summary.json).

**OPM XOR extra_slack 0.100 → 0.050 (closed).** `20260827_cmr_cfifo_outer_rtm5_opm_x50`.
Seed is buf8.  No DEL change.  Window still `L1_L4.Q → L5.D` (not
RegEnable / Ackin).  LSF DC `11448101`.  STA D vs E Tctrl stays 0.215 ns
(the unconstrained L5.Q→E segment); OPM Tdata 0.044 → 0.047 ns, worst RTM
388% → 354%.  RCU 21.7% → 19.6%.  Shortfall 0.

```text
NoC_16nodes.ddc     sha256 3e480a389af2d841851b52036ea2c8d2c2ffc85b7b912bc582e57ad8adec637e
NoC_16nodes_post.v  sha256 004b7389b2915a0ce4f39eadbc13c6ecade2c827e3a423cc459cc548133dea76
NoC_16nodes.sdf     sha256 493d5698edfd6714b032e60eb9a7f6141df047cebb0462acc798290a0a13a7a7
```

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | 5% required | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0473 | 0.2149 | 354.3 | 0.0497 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3248 | 0.3873 | 19.6 | 0.3411 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0848 | n/a | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11448401 | PASS 3000/3000 |
| VCTM p50 | 11448501 | PASS 3366/3366 |

Machine-readable freeze:
[`20260827_cmr_cfifo_outer_rtm5_opm_x50_outer_freeze.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_opm_x50_outer_freeze.json).
Paired table:
[`20260827_cmr_cfifo_outer_rtm5_opm_x50_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_opm_x50_paired_sta_summary.json).

**OPM XOR extra_slack 0.050 → 0.020 (closed, F floor).** `20260827_cmr_cfifo_outer_rtm5_opm_x20`.
Seed is x50.  XOR window `[0.050, 0.070]` ns (min + near-floor).  LSF DC
`11448601`.  STA D vs E Tctrl 0.215 → 0.206 ns, worst RTM 354% → 336%.
That remainder is L5.Q → `DataReg.E` / `RegEnable`, which this overlay must
not constrain.  Ackin 1×DEL250 unchanged.  No further eligible F role.

```text
NoC_16nodes.ddc     sha256 24448454e6684b00839165ad1723abe2155d2bb0826b8d7519aecd88da66ed56
NoC_16nodes_post.v  sha256 e35c281dc3e7bb52fa2226c99334bf3ccb22130e75827f840c1f3f47955e2e74
NoC_16nodes.sdf     sha256 5e933b7e87890e88c3df79f35825dd0efa663b479d11c6389b2ac0369ae5615b
```

Paired STA `20260827_cmr_cfifo_outer_rtm5_opm_x20_paired_sta`, LSF `11448701`.

| ID | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | 5% required | Shortfall | no-path |
|---|---:|---:|---:|---:|---:|---:|---:|
| CMR-OPM-01 | 150 | 0.0473 | 0.2061 | 335.9 | 0.0497 | 0 | 0 |
| CMR-RCU-01 | 200 | 0.3248 | 0.3873 | 19.6 | 0.3411 | 0 | 0 |
| CMR-OPM-01-CE | 50 | 0 | 0.0848 | n/a | n/a | 0 | 0 |

| Evidence | Job | Result |
|---|---|---|
| TAB p50 | 11448801 | PASS 3000/3000 |
| VCTM p50 | 11448901 | PASS 3366/3366 |

Annotation errors=0, timing_violation_count=0.  Step B remains rollback.
This DDC is the F-closed seed for step G (link RTC).  7%/10% stay plan H.

Machine-readable freeze:
[`20260827_cmr_cfifo_outer_rtm5_opm_x20_outer_freeze.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_opm_x20_outer_freeze.json).
Paired table:
[`20260827_cmr_cfifo_outer_rtm5_opm_x20_paired_sta_summary.json`](timing_baselines/20260827_cmr_cfifo_outer_rtm5_opm_x20_paired_sta_summary.json).

## Step G — inter-level FIFO and L1/L2 link RTCs (SYNTH-CLOSED)

Closed on `20260827_cmr_cfifo_link_rtm5` (DDC `7078fade…`), seed
`20260827_cmr_cfifo_outer_rtm5_rcu_del050_buf16` (hash `64eaa1c3…`).
This DDC was the **working baseline** after TAB/VCTM r0p02–r0p90, then
superseded by the TailPassed-without-Grant re-elaborate below.
Step B (`20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`) remains the rollback
and is not mutated.  7%/10% and P&R stay plan H.  Status is
**SYNTH-CLOSED** (mapped DC, paired STA, post-synth SDF), not PHYS-CLOSED.

**Coverage.**  Eight CircularFIFO links (4 upward L1→L2, 4 downward
L2→L1), Ack return on those links, and the 16 core + `top_0` source/sink
ports.  Dummy `top_input/output_1..3` are out.

**Method.**  Measure first on the frozen F DDC.  Incremental `read_ddc`,
re-source datapath + `CMR-OUTER-RTM5`, then
[`async_cmr_noc16_link.sdc`](../scripts/asic_dc/cmr/async_cmr_noc16_link.sdc):

1. `set_max_delay` on link **data** (freeze Data_out / Dataout / port Data).
2. `set_min_delay` / finite max on exported **Req** only (`bb.Reqout`,
   OPM `io_Reqout`, port `HS.Req`).  Never `ReqLatch.Q`.
3. Ack-return as a **separate** control class.  Hierarchical FIFO `Ackin`
   is not a DC startpoint; paired STA reports Tctrl on the TCF-HS-02 ECO
   chain `cfifo_hs02_ack_counter_buf_s1/Z` → `s3/Z` (0.032 ns).  IPM
   `Ackout` → `bb.Ackin` is ZeroWireload 0.  Do not shrink OPM Ackin DEL
   from this ID.

Near-floor cones (`Tdata < 0.020 ns`, typical ZeroWireload net) are
skipped.  TCF-RD-01 / TCF-HS-02 ECO cells stay `dont_touch`.  No RTL DEL.

**Evidence (2026-08-28).**  Measure STA 11458501 on buf16: RCU Tdata 0.325 /
Tctrl 0.353 leftover 13.4%; FWD/ENQ/IO Tdata 0; ACK/HS-02 Tctrl 0.032.
DC 11458801 applied 84 IO pairs, skipped 32 FWD/ENQ/ACK.  Post-STA 11459101
RCU leftover 12.6%, OPM still closed.  TAB 11459601 3000/3000, VCTM 11459701
3366/3366.  Freeze:
[`20260827_cmr_cfifo_link_rtm5_link_freeze.json`](timing_baselines/20260827_cmr_cfifo_link_rtm5_link_freeze.json).

Launcher:
[`run_remote_cmr_noc16_link.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_link.py).

```text
python scripts/asic_dc/cmr/run_remote_cmr_noc16_link.py --phase measure
python scripts/asic_dc/cmr/run_remote_cmr_noc16_link.py --phase all --rtm 0.05
```

STA with `CMR_STA_MEASURE_LINKS=1` adds TCF-RD-01, TCF-HS-02, and the four
`CMR-LINK-*` IDs to the paired catalog.  Inner OPM/RCU 5% shortfall must
stay 0.

Seed env for the incremental compile (buf16 structure):
`CMR_RCU_MATCHED_DELAY_STEPS=1`, `CMR_RCU_MATCHED_BUF_STAGES=16`,
`CMR_RCU_MATCHED_DELAY_UNIT_PS=50`, `CMR_OPM_ACKIN_DELAY_UNIT_PS=50`.

**Rate sweep (2026-08-28).**  Frozen-netlist GLS
`20260828_cmr_cfifo_link_rtm5_p02_p90` (no re-DC).  TAB r0p02–r0p90
10/10 PASS 3000/3000.  VCTM r0p02–r0p90 10/10 PASS.  Annotation
errors=0, timing_violation_count=0.  Compact table:
[`20260828_cmr_cfifo_link_rtm5_p02_p90_gls.json`](timing_baselines/20260828_cmr_cfifo_link_rtm5_p02_p90_gls.json).
Baseline pointer (superseded 2026-08-28 by the TailPassed knife below):
[`CURRENT_THIN_NOC16_BASELINE.json`](timing_baselines/CURRENT_THIN_NOC16_BASELINE.json).
Manifest:
[`20260827_cmr_cfifo_link_rtm5_baseline_manifest.json`](timing_baselines/20260827_cmr_cfifo_link_rtm5_baseline_manifest.json).

## TailPassed without Grant (re-elaborate, p50 gate)

`Grant && TailPassed` on the 1-lane IPM assignment is redundant with
OPM's async TailDetector reset (`reset || !Grant`), but it is a
timing/ownership change (CMR-TP-01), so it cannot ride `read_ddc` of
`link_rtm5`.  From-scratch elaborate of the current Scala, same closed
recipe (`CMR_RCU_MATCHED_DELAY_STEPS=1`, `UNIT_PS=50`, 16×BUFFD0 on
MatchedDelay Z, Ackin DEL050, TCF-HS-02=24, TCF-RD-01=512), then
incremental datapath + `CMR-OUTER-RTM5` + link overlay.

**Evidence (2026-08-28).**  Elab DC 11463601
`20260828_cmr_cfifo_tp_nogrant_elab` (DDC `4b0c1a28…`).  Incremental G
DC 11464201 `20260828_cmr_cfifo_tp_nogrant_p50` (DDC `02d5497b…`).
Post-STA 11464301: RCU Tdata 0.148 / Tctrl 0.354 leftover large
(Tdata remapped vs predecessor 0.325; 16 bufs not trimmed).  OPM still
closed.  TAB 11464401 3000/3000, VCTM 11464501 3366/3366, annotation
errors=0, timing_violation_count=0.

This DDC is the **current working baseline**.  Step B
(`20260827_cmr_cfifo_noc16_rd01_eco16_p50_01`) remains the rollback and
is not mutated.  Predecessor working netlist is `link_rtm5`.  Rate sweep
r0p02–r0p90 was not re-run on this DDC.  7%/10% and P&R stay plan H.
Scala defaults in `CMRTypes.scala` unchanged.  OPM `io.MG` is no longer
a port; MG stays an internal wire.  `dontTouch(Grant)` remains.

Freeze:
[`20260828_cmr_cfifo_tp_nogrant_p50_link_freeze.json`](timing_baselines/20260828_cmr_cfifo_tp_nogrant_p50_link_freeze.json).
Manifest:
[`20260828_cmr_cfifo_tp_nogrant_p50_baseline_manifest.json`](timing_baselines/20260828_cmr_cfifo_tp_nogrant_p50_baseline_manifest.json).
Pointer:
[`CURRENT_THIN_NOC16_BASELINE.json`](timing_baselines/CURRENT_THIN_NOC16_BASELINE.json).

## Standalone Router L3 RCU (1×DEL050 + 2×BUFFD0)

Same recipe as standalone L1/L2.  Thin 5-port `CMRRouter(level=3)`.
`NoC_16nodes` still has no L3 instance, so this DDC is not in the chip
netlist.  Scala defaults unchanged.

0-buffer `20260828_cmr_router_l3_del050_unicast3`: Tdata 0.105 ns, Tctrl
0.100 ns, 5% shortfall 9.8 ps, unicast3 PASS.  Incremental 2×`BUFFD0`
`20260828_cmr_router_l3_del050_buf2_unicast3` (DC 11460701, SDF 11460801):
structure `RCU_DEL050=5`, `RCU_MATCHED_BUF=10`.  STA leftover 23.6 ps,
worst RTM 33.5%, shortfall 0.  unicast3 PASS.

Freeze:
[`20260828_cmr_router_l3_del050_buf2_router_freeze.json`](timing_baselines/20260828_cmr_router_l3_del050_buf2_router_freeze.json).

## Fig. 7 write-pointer completion (CMR-WP-01 / CMR-HS-02)

Pin bindings and the current thin implementation (endpoint 0.20 ns; HS-02
Reqin `DEL250` ECO off) are in the catalog above.  The numbers and ECO
history below stay as a record; they are not a second pin list.

The write interface protocol is already correct: a non-Tail cell acknowledges
from `CellFull`, and `WriteAckGenerator` XORs the five `AckoutCell` bits.  The
relative-timing hole is that `WriteCounter` clocks on `posedge` of
`~(Reqin^Ackout)`, while the next flit's `Reqin`/`Datain` may still see the
previous cell's transparent latch.

Inequality, same completion reference, latest pointer vs earliest next request:

```text
Tmax(complete↑ → WritePointer[next] at CellFull.E) + Tsetup_latch
  < Tmin(Ackout@pin → next Reqin at CellFull.D)
```

GLS fail signature: after Tail `1/1` and before the next `Reqin` toggle, the
pointer still selects the Tail cell; it only rotates on the following `0/0`.
The next cell then opens with `Reqin` already flipped, `CellFull` follows,
and the XOR produces an extra channel Ack after the handshake was already
equal.

How to close it in DC, not in Fig. 7 RTL:

1. Internal max-delay (make the pointer fast): `-from` the WriteCounter
   complete XNOR / CK `-to` the five `WriteControlUnit` `PhaseResetDLatch.E`
   pins.
2. I/O min-delay (make the next request slow): Ackout port to the next
   `Reqin`/`Datain`/`Tail` turnaround via `set_output_delay` / `set_input_delay`
   or an equivalent virtual Ack→Req path.  A testbench port floor such as
   `RX_CAPTURE_NS=5` does not close the internal complete pulse.
3. Pulse/hold at WriteCounter CK (`CMR-HS-02`): `set_min_pulse_width` or the
   library pulse check.  Hold of `Reqin` at `CellFull.D` relative to `E`
   switching so the current cell closes before next-beat data arrives.  Do not
   put a global min-delay on `Reqin → CellFull.D`; that would slow capture of
   the **current** flit.
4. Keep closing `CMR-HS-01` on the AddressRegister complete tree
   (`HeadPredictor.en_state_reg.CP`).  Current `PhaseSelector` has no
   `phase_reg`; that name is historical.

Numerical bounds from frozen matched4 STA
`20260822_cmr_thin_wp_sta_01` (DDC `20260822_cmr_thin_rcu_matched4_dc_01`,
ssg0p81v125c):

```text
Q → CellFull.E          Tptr_max = 0.00 ns  (direct net; WP-01 I/O already < 1 ns)
Reqin → WriteCounter CK  0.056–0.070 ns
Ackout → WriteCounter CK 0.055–0.071 ns
Head → phase_reg.D       0.026 ns (historical; PhaseSelector no longer has phase_reg)
```

WritePointer SDC (`async_cmr_wp_control.sdc`, `create_clock` on complete,
`set_min_delay` on `Reqin → CK`, complete pulse stretch) is withdrawn.
NoC16 DC no longer sources path constraints for Fig. 7.

HS-02 was tried as a **non-RTL** DC `insert_buffer` of one
`DEL250D1BWP12T30P140` on each WriteCounter hierarchical `Reqin` pin (25
cells, `dont_touch`).  After map the cell sits in `WriteInterfaceControl`
as `.I(io_Reqin), .Z(eco_net)` into `Counter`; `CellFull.D` stays on the
undelayed `io_Reqin`.  `WriteCounter.v` is unchanged.  That ECO is
**off** on the clean thin baseline (`CMR_WP_REQ_DEL250_ENABLE` default 0).
Do not min-delay `Reqin → CellFull.D`.  DC `20260822_cmr_thin_wp_del250_dc_03`
gated `RCU_DE=25` (MatchedDelay wrappers only; FIFO DelayElements are
excluded), `RCU_DEL150=100`, `WP_DEL250=25`.

RCU matched delay remains the explicit Fig. 6 exception: 25 × `DelayElement`
(`DelayValue=4`, `DelayUnitPs=150`) → 100 `DEL150` after map.

Prior TAB p50 SDF, fail-fast harness, `RX_CAPTURE_NS=5`:

| Netlist | First retreat | Result |
|---|---|---|
| `20260822_cmr_thin_wp_rtc_dc_01` (clocks, no buffers) | 2317 ns port 2 `in=0/1` | `TB_STALL_FAIL` @ 60.21 µs, `rx=753/3000` |
| `20260822_cmr_thin_wp_mindelay_dc_02` (Reqin `DEL150`) | 370 ns `in=1/0` Head | stall @ 51.21 µs, `rx=22` |
| `20260822_cmr_thin_wp_mindelay_dc_03` (Reqin `DEL100`) | 250 ns `in=1/0` Tail | stall @ 51.21 µs, `rx=7` |
| `20260822_cmr_thin_wp_stretch_dc_04` (complete stretcher) | 250 ns `in=1/0` Tail | stall @ 51.21 µs, `rx=7` |
| `20260822_cmr_thin_wp_del250_dc_03` (Reqin `DEL250`) | 2317 ns port 2 `in=0/1` | `TB_STALL_FAIL` @ 60.21 µs, `rx=753/3000` |

GLS `20260822_cmr_thin_wp_del250_tab_sdf_01` on that netlist: SDF MAXIMUM,
`annotation_errors=0`, 25 `DEL250` in both `NoC_16nodes_post.v` and SDF.
First `FUNC_ACK_RETREAT` / `IPM3_ACK_RETREAT` is still 2317 ns,
`routerL1_1_0.InputPortModules_3`, `in=0/1` (Head `8108108`).  Same
signature as matched4 / clocks-only, not the earlier `1/0` XOR collapse.
No further delay cells added.

The DC flow should attach concrete numerical `set_min_delay`/paired path
constraints only after post-layout characterization supplies each bound.  The
resulting reports must identify source pin, destination/close pin, polarity,
corner, required margin, achieved margin, and inserted cells.  A passing
functional elaboration or zero-delay RTL simulation is not timing sign-off.

## CMR-WP-01 source turnaround implementation (2026-08-24)

The owning implementation is the source endpoint, not the CMR write
interface.  `AsyncEndpointBank20` feeds each source Mousetrap's `AckX` through
`AsyncEndpointSourceTurnaroundDelay`; the latter is a protected direct-cell
chain `DEL150D1 + DEL050D1` in T28 ASIC builds (nominal 0.200 ns).  Thus a
returned NoC input Ack cannot reopen the source latch, and therefore cannot
change the next `ReqX` or its bundled `DataOut`, before the CMR old
`CellFullLatch` has closed.

The sign-off relation is evaluated at the same PVT corner:

```text
Tmin(Ackout@NoC input pin -> source latch reopen -> next Req/Data)
  > Tmax(complete -> old CellFullLatch.E falling) + latch margin
```

The direct-boundary testbench has the same `ACK_TO_NEXT_REQ_GUARD_NS=0.20`
default solely to enforce this interface contract when no structural endpoint
is instantiated.  It is not a substitute for the endpoint cells.  CMR
`WriteCounter`, `WriteAckGenerator`, WCU XOR and `CellFullLatch` wiring remain
unchanged.

Validation on frozen NoFIFO T28 MAX SDF (`20260824`): TAB p30 guard sweep
reproduced `CellFullLatch -> X` at 0.100 ns (two timing violations), passed
with zero timing violations at 0.120, 0.180 and 0.200 ns, and passed
functionally but retained five unrelated latch violations at 0.150 ns.
The implementation keeps the conservative 0.200 ns value.  Structural
endpoint run `20260824_cmr_thin_nofifo_endpoint200_struct_p30_02` passed TAB
p30 with `ACK_TO_NEXT_REQ_GUARD_NS=0.00`, 3000/3000 delivered, SDF annotation
errors=0 and timing violations=0; the physical endpoint delay, not the TB
guard, supplied the protection.

The same NoFIFO netlist still stalls on VCTM-MC5-NM-3f-r0p50 at 571/3366
deliveries with zero timing violations in both structural-endpoint and direct
0.200 ns modes.  This is a separate multicast flow-control issue and must not
be attributed to CMR-WP-01 or used to weaken its TAB acceptance.

Restoring depth-3 ACG FIFO without `CMR-FIFO-01` reproduced the 255 ns
dequeue X (`20260824_cmr_thin_acg_fifo3_dc_01`).  After `Out.Req` 1×DEL150
(`20260825_cmr_thin_acg_fifo3_outreqdel150_dc_01`) that X is gone; VCTM p50
then stalls at 586/3366 / 53.21 µs with L1 parent and L2 child decoupled.
See [`CMRRouter_Debug_Log.md`](CMRRouter_Debug_Log.md) §20–§22.

## Paper hop delay recipe (RCU 1×DEL050 / Buffer=0 / Ackin DEL050)

Fat vs Thin isolated-Router PPA uses the same delay on every level:

- RCU `MatchedDelay`: 1×`DEL050` (`CMR_RCU_MATCHED_DELAY_STEPS=1`, `UNIT_PS=50`)
- RCU matched buffer: **0** (not Thin CFifo 16×`BUFFD0`, not standalone `buf2`)
- OPM `AckinDelay`: **1×`DEL050` on Fat and Thin** (not Fat `DEL250`, not `CMR_OPM_ACKIN_USE_BUF=1`)
- LANE01: 0

Frozen netlists (do not overwrite):
`20260830_cmr_thin_{l1,l2,l3}_hop_del050_ackin050`,
`20260830_cmr_fat_{l1,l2,l3}_hop_del050_ackin050`.
PPA folder: `20260830_cmr_router_level_baseline_del050`.
Pointer:
[`CURRENT_HOP_DELAY_BASELINE.json`](timing_baselines/CURRENT_HOP_DELAY_BASELINE.json).

Not this recipe (archive only; not Fat vs Thin delay numbers):

- Thin NoC16 CURRENT `20260828_cmr_cfifo_tp_nogrant_p50` and standalone `*_del050_buf2`
- Thin hop `20260830_cmr_thin_l1_hop` (16×BUFFD0)
- Fat hop `20260830_cmr_fat_l1_hop` (Ackin DEL250)
- Fat NoC16 `20260829_cmr_ft_noc16_lane01_0` (Ackin 250)
- Fat NoC64 `20260830_095259_cmr_noc64_p50_1222` (network SDF PASS, Ackin DEL250)
- Clocked SyncNoC64 1.0 ns Thin `20260831_014622_cmr_sync_noc64_thin_p50` and
  Fat 1-2-2-2 `20260831_084457_cmr_sync_noc64_fat1222_p50`.  Valid/ready global
  clock, ZeroWireload.  See [`CMR_Sync64_Clock_Freeze.md`](CMR_Sync64_Clock_Freeze.md).
  Not hop Head.

DC/GLS launchers refuse those frozen run IDs unless `CMR_FORCE_OVERWRITE_FROZEN=1`.
