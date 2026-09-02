# Sync 64-core clock freeze (1.0 ns)

Clocked `SyncNoC_64nodes` signoff is **1.0 ns** at TSMC 28 nm SS
(`ssg0p81v125c`), ZeroWireload, for both Thin `(1,1)` and Fat **1-2-2-2**.
Do not cite 1.0 ns as chip Fmax or as an async hop Head number.

Phase 2.5 changes isolated Head from 2/3 clocks to **one clock**
(`liveGrant` + combinational `LaneSelect`).  That lengthens the Fat limiter
cone (LaneSelect and OPM PE now sit on `destReg` → L1).  **2026-09-01 Gate
PASS** at 1.0 ns: do not retarget, and never set
`CMR_SYNC64_CLOCK_PERIOD_NS=0.9` to chase async Head.

SDC: 5% setup uncertainty, 0.02 ns hold uncertainty, 10% I/O delay, ideal
clock network.  Closed-loop check is MAXIMUM SDF TAB p50 + VCTM-MC5-NM p50
(Fat) / TAB p50 (Thin).

## Phase 2 archive (2/3-cycle Head) — do not overwrite

These numbers are **not** Table I / DES inputs after Phase 2.5.

| | Thin `(1,1)` | Fat 1-2-2-2 |
|---|---|---|
| Netlist | `20260831_014622_cmr_sync_noc64_thin_p50` | `20260831_084457_cmr_sync_noc64_fat1222_p50` |
| Arrival | 0.80 ns | **0.85 ns** |
| Required (1.0 − 0.05 unc. − 0.02 setup) | 0.93 ns | 0.93 ns |
| WNS | 0.134 ns | **0.083 ns** |
| Isolated Head | 2.000 ns | hop PROP 3.000 ns (router, not this NoC64 STA) |

On that mapping Fat zero-slack ≈ 0.92 ns.  0.90 ns would fail setup.

## Phase 2.5 signed run IDs (paper)

Protected by `scripts/asic_dc/cmr/cmr_frozen_run_ids.py`.  Reuse with
`CMR_SYNC64_NETLIST_RUN_ID`; do not DC into the same id.  Thin and Fat
netlists are not interchangeable (`SyncNoC_64nodes` name is shared; remote
dirs and `TOP_LANES` differ).

| Geometry | DC / SDF netlist | Isolated Head | DC WNS |
|---|---|---|---|
| Sync Thin hop 1-cycle | `20260901_cmr_sync_thin_1x1_1p0ns` | 1.000 ns | 0.261 ns |
| Sync PROP hop 1-cycle | `20260901_cmr_sync_prop_2x2_1p0ns` | 1.000 ns | 0.0026 ns |
| hop PPA (Sync rows 1-cycle; Async reused) | `20260901_cmr_primitive_hop_ppa_ru5` | — | — |
| Thin 16 L1 + 4 L2 + 1 L3, 105 ports, 1 top | `20260901_cmr_sync_noc64_thin_p50` | — | 0.000667 ns |
| Fat 1-2-2-2, 146 ports, 264 `SyncLaneSelector`, 2 top | `20260901_cmr_sync_noc64_fat1222_p50` | — | 0.000033 ns |

Fat TAB and VCTM MAXIMUM-SDF both PASS; Thin TAB MAXIMUM-SDF PASS.
Structure counts match the freeze table (21 routers; 0 Mutex / DEL /
LanePhaseAdapter).  ZeroWireload slack on the 64-core maps is essentially
zero; keep 1.0 ns and do not speed up.

Local copies: `scripts/asic_dc/cmr/results/<run_id>/`.

## What this number is not

- Not async hop Head (Thin hop Head 0.681 ns, Fat L2/L3 hop Head 0.956 ns on the locked DEL050 recipe).
- Not a placed-and-routed period.  STA is ZeroWireload.
- Not an invitation to set `CMR_SYNC64_CLOCK_PERIOD_NS=0.9`.
