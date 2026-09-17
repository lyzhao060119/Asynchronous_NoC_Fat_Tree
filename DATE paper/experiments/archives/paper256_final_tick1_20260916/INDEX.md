# 256-node paper results — FINAL archive (CASE_TICK_NS=1)

**Status:** complete (2026-09-16)  
**Canonical entry for this package:** this folder  
`DATE paper/experiments/archives/paper256_final_tick1_20260916/`

Old `CASE_TICK_NS=20` E1/E2 figures under `figures/paper256/` **without `_tick1_`** are obsolete. Do not cite them.

---

## 1. Paper figures (authoritative)

| Figure | Contents | Path |
|---|---|---|
| **Fig.256-1** | Three-DUT Global UR thr–latency (pre-sat / near-lossless) | [`fig256-1/`](fig256-1/) · also `figures/paper256/e1_ur_three_dut256_tick1_20260916_005414/` |
| **Fig.256-2** | PROP F16 Native vs Repeated | [`fig256-2/`](fig256-2/) · also `figures/paper256/e2_f16_cross_tier256_tick1_20260916_010639/` |

Files in each fig folder: `*.png`, `*.pdf`, `summary.csv`, `README.md`.

---

## 2. Raw GLS CSVs

| Experiment | Run ID | Raw archive |
|---|---|---|
| E1 UR (coarse+fine) | `20260915_tick1_cmr_e1_ur_three_dut256` | `raw/paper256/e1_ur_three_dut256_tick1_20260916_005414/` |
| E2 F16 | `20260915_tick1_cmr_e2_f16_cross_tier256` | `raw/paper256/e2_f16_cross_tier256_tick1_20260916_010639/` |

---

## 3. Frozen netlists (SKIP_DC)

| DUT | Netlist run_id | Delay recipe |
|---|---|---|
| PROP_temp256 | `20260914_prop_temp256_b8_hier_dc_06` | Tree RCU DEL050 / Mesh RCU DEL150 / Ackin DEL050 |
| PFAT_temp256 | `20260915_122347_cmr_pfat_temp256_hier_dc` | same |
| FM256 | `20260915_122347_cmr_mesh256_hier_dc` | Mesh RCU DEL150 / Ackin DEL050 |

---

## 4. Case bundles

| Bundle | Role |
|---|---|
| `scripts/asic_dc/cmr/generated_cases/20260915_paper256_ur_tick1_m5_800_202701` | E1 TOPO-UR |
| `scripts/asic_dc/cmr/generated_cases/20260915_prop_temp256_f16_cross_tier_tick1` | E2 F16 (M5/M20/M40) |

Injection: `v3_exp_header_asap_body`, `case_tick_ns=1.0`.

---

## 5. Headline numbers

### E1 near-lossless (tick=1 filter)

| DUT | Near-lossless setpoint | Delivered thr. | Low-load m5 |
|---|---:|---:|---|
| PROP_temp256 | ~40 | ~5.28 | PASS, ~11.3 ns |
| PFAT_temp256 | ~50 | ~7.16 | PASS, ~13.9 ns |
| FM256 | ~200 | ~18.7 | PASS, ~13.5 ns |

### E2 F16 (PROP only)

| Load | Native | Repeated |
|---|---|---|
| low M5 | PASS | PASS |
| med M20 | PASS | PASS |
| high M40 | PASS | **FAIL** (timeout) |

Native useful throughput ≫ repeated at all PASS points.

---

## 6. Related docs in this package

- [`summaries/256node_round_plan_20260915.md`](summaries/256node_round_plan_20260915.md) — round execution log  
- [`summaries/256_vs_64_scaleout_summary_tick1.md`](summaries/256_vs_64_scaleout_summary_tick1.md) — 64↔256 table  

Plan (scope): `DATE paper/256节点网表实验计划_精简版.md`  
Out of scope (not run): BC/Hotspot, Async–Sync, fanout, 256 PT-PX.

---

## 7. Obsolete (do not use)

- `figures/paper256/e1_ur_three_dut256_coarse_20260915_200955/` (tick=20)
- `figures/paper256/e2_f16_cross_tier256_20260915_181113/` (tick=20)
- Any `e1_*` / `e2_*` dirs under `figures/paper256/` or `raw/paper256/` **without** `tick1` in the name, from the 2026-09-15 tick=20 attempt
