# E2 Sync PROP_temp64 B8 前置检查（无 DC）

日期：2026-09-15  
范围：RTL / 结构 / 匹配条件；**不启动新综合**。  
结论：**blocked_pending_rtl_and_authorization** — 尚无同构 Sync B8 网络 DUT。

## 1. Async 基准（必须对齐的对象）

| 项 | Async PROP_temp64 B8 |
|---|---|
| 源码 | [`src/main/scala/NoC/CMR/PROPtemp.scala`](../../src/main/scala/NoC/CMR/PROPtemp.scala) `PROPtemp64` / `PROPtempTile` |
| 设计 JSON | [`DATE paper/experiments/configs/designs/prop_temp64.json`](../configs/designs/prop_temp64.json) |
| 结构 | 16×L1(1,4) + 16×L2(1,4) + 16×L3(1,1)；top ports = **16** |
| 路由 | quadtree（单 tile，无上挂 Mesh） |
| flit / buffer | 28-bit / 5 slots |
| delay | Tree RCU DEL050；Mesh RCU DEL150（emit lock） |
| 冻结网表 | `20260913_prop_temp64_asap_uc_m5_200`（已有 UR） |

## 2. 现有 Sync 网络（明确不是严格对照）

| DUT | 结构 | 为何不能替代 Sync B8 |
|---|---|---|
| `SYNC_PROP64` / Fat **1222** | L1(1,2)+L2(2,2)+L3(2,2)，top=**2** | 旧 hierarchy；与 B8 parallel-plane 不同 |
| Sync Fat **1248** | L1(1,2)+L2(2,4)+L3(4,8)，top=**8** | PFAT 同步版，不是 PROP_temp B8 |
| 历史 Sync1222 GLS/PT-PX | 上述 1222 网表 | 计划明确禁止作为 B8 严格对照 |

源码入口：[`SyncCmrFatTree.scala`](../../src/main/scala/NoC/CMR/SyncCmrFatTree.scala)（`SyncCmrFatTreeNoC64Fat1222` / `...Fat1248`）。  
设计 JSON：[`sync_prop64.json`](../configs/designs/sync_prop64.json)（`lane_profile: 1-2-2-2`，`paired_trace_with: PROP64` 旧异步 balanced，不是 `PROP_temp64`）。

## 3. 匹配条件检查表（授权 DC 前必须全绿）

| 条件 | Async B8 | 所需 Sync B8 | 状态 |
|---|---|---|---|
| topology / hierarchy | L1/L2(1,4) + L3(1,1)×16 | 同构 Sync routers | **缺 RTL** |
| physical lanes / top ports | 16 | 16 | **缺** |
| routing | quadtree tile | 同 | **缺** |
| flit width | 28 | 28 | Sync 原语已支持 |
| buffer depth | 5 | 5 | Sync 原语已支持 |
| packet length | 5-flit ASAP | 同 traces | 可复用后绑定 |
| traffic trace | TOPO-UR s202701 | `paired_trace_with: PROP_temp64` | 未配置 |
| technology / PVT | TSMC28 既有 flow | 同 | flow 在；DUT 不在 |
| clock target | N/A (async) | STA 后决定；预检不得假设 | **待授权 DC/STA** |

## 4. 授权门槛（本文件不越过）

1. 实现并 emit `SyncPROPtemp64`（结构镜像 `PROPtempTile`，使用 `SyncCmrRouter`）。  
2. 增加 design JSON：`SYNC_PROP_temp64`，`paired_trace_with: PROP_temp64`，`paper_eligible_default: false` 直至 GLS 验收。  
3. **单独授权**后才可提交 DC/STA；本检查通过 ≠ 授权综合。  
4. 授权前不得把 Sync1222 / Sync1248 数字填入 Async–Sync B8 论文表。

## 5. 下一步（仍无 DC）

1. 起草 `SyncPROPtempTile` / `SyncPROPtemp64` Scala（结构复制 + Sync IO）。  
2. 本地 `emitVerilog` + 结构计数对照 Async `expected_structure`（routers=48, top_ports=16）。  
3. 用户明确授权后再跑 DC/STA/GLS。

记录：本检查不修改网表、不提交 bsub、不改历史 `paper_eligible`。
