# 256 节点分轮执行笔记（2026-09-15）

配合 [`256节点网表实验计划_精简版.md`](../../256节点网表实验计划_精简版.md) 与 Cursor 四轮计划。正式 Proposed = **PROP_temp256 B8**，禁止把历史 `PROP256`/`NoC_256nodes` 当作正式 DUT。

> **2026-09-15 tick=1 restart（完成）：** 此前 `CASE_TICK_NS=20` 的 E1/E2 结果全部作废。本轮 GLS 固定 `CASE_TICK_NS=1`，跳过单独 smoke。Round 1–2 冻结网表仍有效（SKIP_DC）。
>
> 对照表：[`256_vs_64_scaleout_summary_tick1.md`](256_vs_64_scaleout_summary_tick1.md)

## Round 1 — PROP_temp256 冻结门 + smoke

| 项 | 值 |
|---|---|
| 冻结网表 | `20260914_prop_temp256_b8_hier_dc_06`（`FROZEN_PROP_TEMP256_NETLIST_RUN_ID`） |
| 远程产物 | `PROP_temp256_post.v` / `.sdf` / `.ddc`；`CMR_NOC64_DC_PASS top=PROP_temp256` |
| 结构门 | `python scripts/asic_dc/cmr/check_prop_temp_structure.py`；`check_paper256_structure.py` |
| Smoke | `python scripts/asic_dc/cmr/run_r1_prop_temp256_smoke.py all` → **PASS** run `20260915_120729_cmr_prop_temp256_smoke` |
| Cases | `scripts/asic_dc/cmr/generated_cases/20260915_prop_temp256_smoke_202701/` |
| 归档 | [`raw/paper256/r1_prop_temp256_smoke_20260915_120729/RESULTS.md`](../raw/paper256/r1_prop_temp256_smoke_20260915_120729/RESULTS.md) |

完成判据：~~KEY-256 + TOPO-UR M5…~~ **已满足（2/2 PASS）**。

## Round 2 — 基线 RTL + 授权门

| DUT | RTL | DC |
|---|---|---|
| **PFAT_temp256** | `generated_cmr/pfat_temp256/PFAT_temp256.v` | **完成** 冻结 + smoke 2/2 |
| **FlatMesh256** | `generated_cmr/mesh_noc256_11/CMRMeshNoC.v` | **完成** 冻结 + smoke 2/2 |

授权门全文：[`256node_r2_dc_auth_gate.md`](256node_r2_dc_auth_gate.md)。

发射：

```text
set CMR_RCU_MATCHED_DELAY_UNIT_PS=50
set CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS=150
sbt "runMain NoC.CMR.PFATtemp256Main"
```

DC 入口（授权后，新时间戳）：

```text
# FM256
set CMR_HIER_KIND=mesh256
set CMR_HIER_STITCH_RUN_ID=<new_stamp>_cmr_mesh256_hier_dc
set CMR_HIER_SKIP_GLS=1
python scripts/asic_dc/cmr/run_remote_cmr_hier_dc.py

# PFAT_temp256（需 hier kind 扩展 pfat_temp256）
set CMR_HIER_KIND=pfat_temp256
set CMR_HIER_STITCH_RUN_ID=<new_stamp>_cmr_pfat_temp256_hier_dc
set CMR_HIER_SKIP_GLS=1
python scripts/asic_dc/cmr/run_remote_cmr_hier_dc.py
```

配方：Tree RCU DEL050、Mesh RCU DEL150、Ackin DEL050、bypass FIFO。未获明确授权前不提交。

## Round 3 — 256-E1 Global UR

| 项 | 值 |
|---|---|
| DUTs | PROP_temp256 / PFAT_temp256 / FM256 |
| Runner | `python scripts/asic_dc/cmr/run_e1_ur_three_dut256.py` |
| Cases | `generated_cases/20260915_paper256_ur_tick1_m5_800_202701` |
| GLS | `CASE_TICK_NS=1`；`-W 720`；SKIP_DC；run `20260915_tick1_cmr_e1_ur_three_dut256` |
| 负载 | coarse `(5,20,40,80,120,160,200,280,400,600)` + fine `(50,60,70,90,100,110,140,180,240,320)` |
| Fig.256-1 | `figures/paper256/e1_ur_three_dut256_tick1_20260916_005414/` |
| 状态 | **tick1 完成**；旧 tick=20 作废 |

要点：PROP near-lossless 约停在 m40；PFAT m600 FAIL（unexpected）；FM near-lossless 延至 ~m200。

## Round 4 — 256-E2 F16 cross-tier

| 项 | 值 |
|---|---|
| DUT | 仅 PROP_temp256 |
| Runner | `python scripts/asic_dc/cmr/run_e2_f16_cross_tier256.py` |
| Cases | `generated_cases/20260915_prop_temp256_f16_cross_tier_tick1` |
| Loads | M5 / M20 / M40（按 E1 PROP pre-sat 校准） |
| Run | `20260915_tick1_cmr_e2_f16_cross_tier256` |
| Fig.256-2 | `figures/paper256/e2_f16_cross_tier256_tick1_20260916_010639/` |
| 状态 | native 3/3 PASS；**high repeated FAIL**（timeout/missing）；旧 tick=20 作废 |

## 明确不做

Forced Inter-Tile、BC/Hotspot、Async–Sync、fanout sweep、256 PT-PX。
