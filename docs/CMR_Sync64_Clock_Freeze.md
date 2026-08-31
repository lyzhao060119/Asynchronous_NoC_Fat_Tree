# Sync 64-core clock freeze (1.0 ns)

Signed clocked `SyncNoC_64nodes` uses **1.0 ns** at TSMC 28 nm SS
(`ssg0p81v125c`), ZeroWireload.  That period is frozen for both Thin `(1,1)`
and Fat **1-2-2-2**.  Do not retarget these netlists, and do not cite 1.0 ns
as chip Fmax or as an async hop Head number.

SDC: 5% setup uncertainty, 0.02 ns hold uncertainty, 10% I/O delay, ideal
clock network.  Closed-loop check is MAXIMUM SDF TAB p50 + VCTM-MC5-NM p50.

## Why 1.0 ns is the freeze (not 0.90)

The critical path on both trees is **L2 `destReg` → bypass wire → L1 buffer
write** (Mat / flit, one clock).  Fat is the limiter.

| | Thin `(1,1)` | Fat 1-2-2-2 |
|---|---|---|
| Netlist | `20260831_014622_cmr_sync_noc64_thin_p50` | `20260831_084457_cmr_sync_noc64_fat1222_p50` |
| Arrival | 0.80 ns | **0.85 ns** |
| Required (1.0 − 0.05 unc. − 0.02 setup) | 0.93 ns | 0.93 ns |
| WNS | 0.134 ns | **0.083 ns** |
| WHS | 0.037 ns | 0.037 ns |
| Area | ~0.143 mm² | ~0.211 mm² |
| TAB p50 SDF | 3000 / 3000 | 3000 / 3000 |
| VCTM-MC5-NM p50 SDF | 3000 in / 4500 out | 3000 in / 4500 out |

Same mapping, scale period and 5% uncertainty, library setup held at 0.02 ns:

- Fat zero-slack period ≈ **0.92 ns** (`0.95·T − 0.02 = 0.85`)
- **0.90 ns** on this Fat mapping: required ≈ 0.835 ns &lt; 0.85 ns arrival → setup fail unless DC shortens the path
- **0.95 ns** might close with ~30 ps ZeroWireload slack; that remaining budget is what 1.0 ns leaves for real wires

1.0 ns is therefore tight for Fat (80 ps after uncertainty), not a loose 1.5–2 ns pad.  Dropping to 0.90 is below this netlist.  A 0.95 ns re-synth would spend the only remaining ZeroWireload margin and still not be P&R Fmax, so it is not a new signoff target.

## Frozen run IDs

Protected by `scripts/asic_dc/cmr/cmr_frozen_run_ids.py`.  Reuse with
`CMR_SYNC64_NETLIST_RUN_ID`; do not DC into the same id.  Thin and Fat
netlists are not interchangeable (`SyncNoC_64nodes` name is shared; remote
dirs and `TOP_LANES` differ).

| Geometry | DC / SDF netlist | Notes |
|---|---|---|
| Thin 16 L1 + 4 L2 + 1 L3, 105 ports, 1 top | `20260831_014622_cmr_sync_noc64_thin_p50` | VCTM GLS folder `20260831_074826_…` reused this netlist |
| Fat 1-2-2-2, 146 ports, 264 `SyncLaneSelector`, 2 top | `20260831_084457_cmr_sync_noc64_fat1222_p50` | |

Local copies: `scripts/asic_dc/cmr/results/<run_id>/`.

## What this number is not

- Not async hop Head (Thin hop Head 0.681 ns, Fat L2/L3 hop Head 0.956 ns on the locked DEL050 recipe).
- Not a placed-and-routed period.  STA is ZeroWireload; 80 ps Fat slack is the interconnect budget.
- Not an invitation to set `CMR_SYNC64_CLOCK_PERIOD_NS=0.9` on these ids.
