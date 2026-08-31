# CMR Circular FIFO Timing Intent

This document captures the relative-timing and bundled-data constraints for the
Transition-paper circular FIFO (`CircularFIFO`) used as the current thin NoC16
inter-level replacement (`CMR_USE_CIRCULAR_FIFO=1`).  The Scala emit default
remains the chained `AsyncFifo` unless that env is set.

## Architecture recap

The circular FIFO replaces a serial chain of MOUSETRAP registers with a ring of
parallel storage slots.  It is composed of:

- Fixed four-slot **CircularWriteCounter** and **CircularReadCounter** that
  advance on handshake-completion edges (`Reqin == Ackout` and `Reqout == Ackin`).
- Per-slot **WriteControlBlock** (Fig. 7a) and **ReadControlBlock** (Fig. 7b).
- Per-slot **DLatchBank** for the flit data.
- One-hot output mux driven by the raw read-counter pointer.
- XOR merge trees for global `Ackout` and `Reqout`.

The interface is the standard two-phase bundled-data channel:

| Signal   | Direction | Role                                   |
|----------|-----------|----------------------------------------|
| `Reqin`  | Input     | Upstream request transition            |
| `Ackout` | Output    | Upstream acknowledge transition        |
| `Data_in`| Input     | Upstream data bundle                   |
| `Reqout` | Output    | Downstream request transition          |
| `Ackin`  | Input     | Downstream acknowledge transition      |
| `Data_out`| Output   | Downstream data bundle                 |

## Timing constraints

| ID            | Data/state that must settle first | Control/close event | Required action |
|---------------|-----------------------------------|---------------------|-----------------|
| TCF-WD-01     | `Data_in` stable at `DLatchBank.D` | `En_i` falling (slot becomes full) | Bundled-data: data must settle before `Full_i` rises and closes the latch. |
| TCF-WP-01     | Write pointer rotation finished; next slot `En` open, current slot closed | Next `Reqin` transition and `Data_in` update | Paired max/min constraints as in CMR-WP-01. |
| TCF-RD-01     | `SlotData[i]` stable at mux input | `Reqout` transition visible downstream | Data held by closed latch; mux propagation must fit downstream bundled-data budget. |
| TCF-RP-01     | Read pointer rotation finished; next slot `ReqLatch.E` open, current slot frozen | Next `Reqout` transition | `ReadPointer` is gated by `~(Reqout ^ Ackin)`; ensure stable before downstream ack returns. |
| TCF-RE-01     | `Ackin` stable at `EmptyLatch.D` | `EmptyLatch.E` closing when `Req == Empty` | Min/max delay on ack return path; no glitch on `Empty_i`. |
| TCF-HS-01     | `Reqin`/`Ackout` equality at `WriteCounter` CK | Next `Reqin` toggle | Pulse width and recovery/removal at `WriteCounter` CK. |
| TCF-HS-02     | `Reqout`/`Ackin` equality at `ReadCounter` CK | Next read handshake | Same as TCF-HS-01 for read side. |

## Control-path details

### Write side

1. `FullNext = {Full_1, Full_3, Full_0, Full_2}` and
   `MatchedReq_i = Reqin ^ FullNext_i`.
2. `SlotEmpty_i = ~(Full_i ^ Empty_i)` and
   `WriteEnable_i = WritePointer_i & SlotEmpty_i`.
3. `Full_i` latch captures `MatchedReq_i` while enabled.
4. `Ackout_i = Full_i`; global `Ackout = ^Ackout_i`.
5. `En_i = WriteEnable_i`; the data latch uses the same enable as `Full_i`, so
   only the selected empty slot is transparent and both close when the slot
   becomes full.

The fixed Fig. 6 reset phase is `Full = Empty = Req = {slot3..slot0}=1100`;
the physical pointer sequence is `0 -> 1 -> 2 -> 3 -> 0`. The crossed
`FullNext` wires, rather than a Gray permutation of the physical pointer,
provide the required phase relation.

### Read side

1. `Req_i` latch captures `Full_i` with `ReadPointer_i` directly as enable.
2. `EmptyNext = {Empty_1, Empty_3, Empty_0, Empty_2}` and
   `MatchedAck_i = Ackin ^ EmptyNext_i`.
3. Global `Reqout = ^Req_i`.
4. `Empty_i` latch captures `MatchedAck_i` while `Req_i ^ Empty_i` is
   high; it closes once `Empty_i` catches `Req_i`.

`ReadPointer` is gated by `handshake_idle = ~(Reqout ^ Ackin)` so the selected
slot is frozen while a downstream handshake is pending.

## Synthesis / place-and-route notes

- Do **not** insert explicit `DelayElement` cells inside `WriteControlBlock`,
  `ReadControlBlock`, or the counters.
- Keep `PhaseResetDLatch` mapped to T28 `LHCNDQD1`/`LHSNDQD1` cells under
  `ASIC_T28`; prevent DC retiming across the asynchronous control loops.
- The `CircularFifo` black-box always emits the paper's `.DEPTH(4)` topology.
  `CMR_USE_CIRCULAR_FIFO=1` is accepted only on existing NoC links configured
  with depth 3; this is a compatibility selector, not the physical capacity.
  The unmodified four-slot paper circuit accepts four flits.

## Verification status

- Unit smoke: `sim/CMR/testbench/tb_circular_fifo_smoke.sv` verifies reset,
  four-flit full behavior, pending fifth-write release, pointer wrap,
  backpressure and concurrent read/write.
- Regression: included in `sim/CMR/run_smoke.tcl`.
- Thin NoC16 replacement is the current rollback baseline
  `20260827_cmr_cfifo_noc16_rd01_eco16_p50_01` (eight CircularFIFO links,
  TCF-HS-02 3×BUFFD0, TCF-RD-01 16×BUFFD0).  Strict SDF MAXIMUM TAB and
  VCTM r0p02–r0p90 all PASS.  Manifest:
  [`docs/timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_baseline_manifest.json`](timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_baseline_manifest.json).
- Earlier `20260823_cmr_thin_circfifo_dc_02` prefix `t105` stalled at
  `rx=24/651` and is not the baseline.  HS-02-only
  `20260826_cmr_cfifo_noc16_p50_01` failed TAB unexpected at 2376 ns.
  Fourteen-stage RD01 (`…rd01_p50_02`) missed the 10% RTM by 19.4 ps.

Step G (NoC16, after router inner/outer 5%) measures and constrains the
eight inter-level links and source/sink ports.  Pin-level IDs
`CMR-LINK-FWD-01` / `ENQ-01` / `ACK-01` / `IO-01` live in
[`CMR_DC_Timing_Intent.md`](CMR_DC_Timing_Intent.md).  TCF-RD-01 and
TCF-HS-02 stay the FIFO-internal ECOs; G does not re-insert them.
