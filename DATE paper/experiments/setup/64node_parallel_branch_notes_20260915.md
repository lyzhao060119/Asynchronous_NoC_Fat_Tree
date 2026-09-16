# 64 节点并行支线入口与阻塞项（2026-09-15）

配合 [`DATE2027_总实验执行计划_重排版.md`](../DATE2027_总实验执行计划_重排版.md)。本笔记只登记入口，不把未完成项写成 PASS。

## E1 — PFAT64 UR 补点（已收尾）

| 项 | 值 |
|---|---|
| 缺口 | ~~M220–M800~~ **已补齐**；三 DUT 30 点齐全 |
| 冻结网表 | DC `20260915_080229_cmr_pfat64_rpsdel050_1248`（fill GLS 用该网表） |
| 远程状态（2026-09-15） | **DC PASS**；**fill GLS 18/18 PASS**；**三 DUT 归档** [`e1_ur_three_dut_20260915_103331`](../raw/paper64/e1_ur_three_dut_20260915_103331/RESULTS.md) |
| 图 | `experiments/figures/paper64/e1_ur_three_dut_20260915_103331/` |
| 收尾脚本 | `python scripts/asic_dc/cmr/finalize_e1_ur_three_dut.py` |
| 共同 traces | `scripts/asic_dc/cmr/generated_cases/20260913_paper64_asap_m5_500_202701/traces` |
| 12 点审计 | `python scripts/asic_dc/cmr/audit_e1_ur_common_grid.py` |
| 仍缺 | 代表点 PT-PX（M100 + 共同最高 near-lossless） |

## E2 — Sync B8

| 项 | 状态 |
|---|---|
| 前置检查 | [`setup/E2_Sync_PROP_temp64_B8_preflight.md`](setup/E2_Sync_PROP_temp64_B8_preflight.md) |
| 阻塞 | 无 `SyncPROPtemp64` RTL；缺综合授权 |
| 禁止 | 用 Sync1222 / Sync1248 充当严格对照 |

## E4 — F16 full-drain load sweep

| 项 | 状态 |
|---|---|
| 已有 | M5 Native/Repeated `400/400`（emergency archive） |
| 入口 | `scripts/asic_dc/cmr/run_emergency_multicast.py` / fanout 相关 remote runners |
| 阻塞 | 其余负载需统一 full-drain 窗口；旧半开窗 exploratory |
| 能量 | 先 M5；须无 PT-063 的 clean PT-PX |

## E5 — Fanout F2/4/8/16/32

| 项 | 状态 |
|---|---|
| 现况 | 10 点多为 `399/400`、backlog=1 → exploratory |
| 门槛 | 每点 `400/400` 且 final backlog=0；同 original trace |
| `link_traversals` | 仅 model estimate |

## E6 — Router PT-063

| 项 | 状态 |
|---|---|
| GLS | c1p1/2/4 aggregate MAXIMUM-SDF 已有 |
| 功耗 | `PT-063` Library Compiler path；`check_power` 未干净 |
| 下一步 | 修环境 → 确认 VCD 窗口 → 重跑 PT-PX（新时间戳） |

## E3 — PFAT64 BC/Hotspot10

| 项 | 状态 |
|---|---|
| 已完成 | PROP_temp64 + FM64：`compact64_20260915_000440` |
| 缺口 | PFAT64 两组扫描；可复用 E3 runner，扩展 `FROZEN` 增加 PFAT64 |
| 入口 | `scripts/asic_dc/cmr/run_e2_bc_hotspot64.py`（脚本名 E2 = 计划 E3） |
