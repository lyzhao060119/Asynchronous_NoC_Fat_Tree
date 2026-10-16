# 256 vs 64 scale-out summary (CASE_TICK_NS=1)

Sources:

- 64: `figures/paper64/e1_ur_three_dut_20260915_112228/saturation_summary.csv`
- 256: `figures/paper256/e1_ur_three_dut256_tick1_20260916_005414/summary.csv`

Near-lossless on 256 uses the tick1 filter: PASS + no unexpected + injected==delivered + latency ≤ max(3× low-load, low-load+50 ns).

| Scale | DUT | Near-lossless load (MFlit/port/s setpoint) | Near-lossless delivered | Notes |
|---|---|---:|---:|---|
| 64 | PROP_temp64 | 420 | 302.2 | paper64 sat summary |
| 64 | PFAT64 | 160 | 127.0 | early cliff |
| 64 | FM64 | 280 | 199.2 | |
| 256 | PROP_temp256 | 40 | 5.28 | latency rises fast; many higher loads TB FAIL (unexpected) |
| 256 | PFAT_temp256 | 50 | 7.16 | m600 TB FAIL unexpected=5 |
| 256 | FM256 | 200 | 18.70 | holds under 3× latency filter longest |

Reading: with correct tick=1, 256-node absolute near-lossless throughputs are far below 64-node per-port peaks (multi-tile / diameter effect). FM256 retains the largest near-lossless window; PROP_temp256 saturates earliest on the latency / correctness filters.

E2 F16 (tick1, loads M5/M20/M40): native 3/3 PASS; repeated high (M40) **FAIL** (timeout / missing). Archive: `e2_f16_cross_tier256_tick1_20260916_010639`.
