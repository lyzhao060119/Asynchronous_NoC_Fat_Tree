# DATE 2027 实验清单（Codex 执行版）

> 目标：在当前已经冻结的 64-node headline results 基础上，补齐论文所需的 **严格消融、benchmark 多样性、256-node cross-tier 验证、1024-node scalability**。
>
> 核心论文机制：
>
> - **M1 — Parallel-Path Hierarchical Fabric**
> - **M2 — Cross-Tier Native Multicast**
> - **M3 — Phase-Adaptive / Dynamic Multi-Lane Control**
>
> 本文件是“执行清单”，不是论文文字。Codex 应按优先级逐项完成，并在每个实验后产出统一格式的原始数据、汇总 CSV、图和 `RESULTS.md`。

---

## 0. 当前已冻结结果：禁止覆盖、禁止重新解释

当前远程仓库已冻结以下 Abstract 数据。执行新实验时不得覆盖这些目录或修改其统计口径。

### M1：64-node unicast

- PROP_temp64 peak delivered throughput: **379.2 Mflit/s/port**
- FlatMesh64 peak delivered throughput: **239.0 Mflit/s/port**
- improvement: **+58.7%**
- PROP cell area: **520533 um²**
- FlatMesh cell area: **469899 um²**
- area overhead: **+10.8%**

### M2：64-node F16 multicast full-drain

- fanout: **16**
- measurement transactions: **400**
- full-drain completion: **400/400**
- backlog: **0**
- Native mean completion latency: **9.240 ns**
- Repeated-unicast mean completion latency: **148.602 ns**
- reduction: **93.8%**

### M3：Router multi-lane aggregate throughput

统一条件：

- 4 concurrent child sources
- 1000 packets/source
- 5 flits/packet
- total = 20000 flits
- full-drain
- MAXIMUM-SDF
- 0 failures

结果：

- c1p1: **1.197483 Gflit/s**
- c1p2: **1.874664 Gflit/s**
- c1p4: **3.001346 Gflit/s**
- four-lane scaling efficiency: **62.7%**

### 特别说明：919 Mflit/s 的口径

`919.33 Mflit/s` 是 c1p4 单源、单 lane、包内 consecutive Body flit 的 body-pitch reciprocal。

它只能称为：

> single-lane body-flit service rate / router micro-benchmark

禁止与 `1.197 / 1.875 / 3.001 Gflit/s` aggregate throughput 混表、混图或直接比较。

---

# 1. 全局实验规范

Codex 在新增任何实验前，先执行以下规则。

## 1.1 版本与归档

- 先 `git pull` 并记录当前 commit SHA。
- 以当前 `main` 最新提交为基础；若晚于 `21fb2ac4659a75bc4bb7ed95f77d70bb68cc7002`，以最新提交为准。
- 不修改已有 frozen raw data。
- 新实验全部使用新的 timestamp/run-id。
- 每个实验目录必须保存：
  - commit SHA
  - DUT/netlist hash
  - testbench hash
  - seed
  - command line
  - SDF path / timing-model source
  - run log
  - raw CSV
  - summary CSV
  - `RESULTS.md`

## 1.2 正确性 gate

任意实验在进入性能统计前必须满足：

- `Total errors: 0`
- no missing flits
- no unexpected flits
- no timeout
- sent == received after full drain
- multicast：所有 intended destinations 都收到完整 packet
- 禁止在 correctness FAIL 的 run 上统计 throughput/latency

一旦 correctness FAIL：

1. 停止该 configuration 的批量扫描；
2. 保留失败日志；
3. 修复后从 smoke test 重新开始；
4. 不得静默跳过错误点。

## 1.3 统一 packet 与统计

除非某实验明确写明，否则：

- packet length = **5 flits**
- primary seed = **202701**
- comparative pairs 必须使用相同 transaction trace
- 正式 latency 结果必须 **full-drain**
- throughput:
  - network level：Mflit/s/port
  - router aggregate：Gflit/s
  - multicast 可额外报告 useful destination-delivery rate，但必须明确单位

### Latency 使用规则

高负载 finite-window latency 有 right-censoring 风险。

因此：

- 正文 latency curve 优先只使用 delivery ratio >= 99% 且 backlog 很小的点；
- 已明显 saturation 的点可以保留 throughput，但 latency 必须标为 censored / exploratory；
- 不允许因为高负载下 observed mean latency 下降而声称延迟改善。

## 1.4 Multicast 公平性

Native vs repeated-unicast：

- 必须共享完全相同的 **original transaction arrivals**
- destination sets 完全相同
- Native：每个 original transaction 注入 1 个 multicast packet
- Repeated：同一 original transaction 在 source 端展开为 N 个 unicast packet
- 最终 full-drain 后比较 completion latency / useful throughput / backlog

`link_traversals` 若仍来自 route oracle，只能标为 **model-estimated**，不得写成 measured traffic。
若要写 measured link traffic，必须先在 DUT/TB 中增加真实 inter-router accept/handshake counter。

---

# 2. P0：必须完成

---

## E1. 64-node 严格 M3 消融：Dynamic-4Lane vs Static-4Lane

### 目的

证明 c1p4 的收益不只是“有 4 条物理 lane”，而是 dynamic lane selection 能实际提高 lane 利用率和 aggregate throughput。

### 核心原则

`Static-4Lane` 必须与 FULL c1p4 保持：

- 相同 router geometry
- 相同 4 条 parent physical lanes
- 相同 datapath
- 相同 packet format
- 相同 delay cells
- 相同 buffer depth
- 尽可能相同 Adapter/phase-state implementation

唯一主要变化：

- FULL：Selector 根据 lane availability 动态选 lane
- Static：禁止 availability-based fallback，使用 deterministic lane mapping

### 推荐 static mapping

优先使用最自然且稳定的 deterministic mapping，例如：

`lane = source/input index mod 4`

若当前结构更适合 path-index mapping，则可使用固定 path index，但必须：

- 不依据当前 lane busy/free 状态改变；
- 同一输入/branch 的映射可复现；
- 在 `RESULTS.md` 写清楚映射规则。

### Benchmark

沿用现有 M3 aggregate TB：

- 4 concurrent sources
- 每 source 1000 × 5-flit packets
- continuous injection
- full drain
- parent logical direction
- MAXIMUM-SDF

### 比较

- `Dynamic-c1p4`
- `Static-c1p4`

### 输出指标

必须：

- aggregate throughput
- sent/received flits
- total runtime
- per-lane delivered flits
- per-lane utilization
- max/min/mean lane utilization
- lane imbalance

建议：

`imbalance = max(U_i) / mean(U_i)`

### Acceptance

- 两个版本均 correctness PASS
- 都收到 20000/20000 flits
- Static 版本确认 4 条 lane 均存在，不能退化成 c1p1
- 生成一张 bar chart：
  - Dynamic aggregate throughput
  - Static aggregate throughput
- 生成一张 4-lane utilization chart

### 结果目录建议

`DATE paper/experiments/raw/ablation_m3_static4/<timestamp>/`

---

## E2. 64-node benchmark 补充：BC + Hotspot10

### 目的

当前新的 PROP64 headline 基本来自 Uniform Random。补充两个 benchmark，避免结论只成立于 UR。

### DUT

至少：

- PROP_temp64 / 当前正式 proposed 64-node architecture
- FlatMesh64

如旧 PFAT64 可以直接复用同一测试框架，可一并加入，但不是本任务 blocker。

### E2-A Bit Complement

定义：

- 100% unicast
- 对 64 node address 做 bit complement
- source != destination
- 5-flit packet

做 offered-load sweep，从低负载扫到明显 saturation。

建议采用“粗扫 + knee 附近细扫”：

1. 先粗扫
2. 自动检测 throughput knee
3. 在 knee 前后补点

### E2-B Hotspot10

定义：

- 100% unicast transaction
- 10% traffic 指向固定 hotspot node / hotspot set
- 其余 90% 使用 UR
- hotspot 定义必须固定并写入 metadata

若仓库已有 Continuous-compatible Hotspot10 定义，优先复用，不自行发明另一套。

同样做完整 load sweep。

### 指标

- offered load
- delivered throughput
- delivery ratio
- mean latency
- p95/p99 latency
- backlog
- timeout/errors

### 输出

每个 benchmark：

- throughput-vs-offered-load 图
- latency-vs-offered-load 图
- saturation summary CSV

### Acceptance

- 至少 PROP64 与 FlatMesh64 共享完全相同 trace
- benchmark generation reproducible
- saturation 后 latency 不做正向结论

### 结果目录建议

`DATE paper/experiments/raw/paper64/benchmark_bc_<timestamp>/`

`DATE paper/experiments/raw/paper64/benchmark_hotspot10_<timestamp>/`

---

## E3. 256-node Global Uniform Random：核心 scalability

### 目的

验证 4 × 64-node tiles 接入 upper Mesh 后，proposed architecture 在全局随机通信下的 scale-out 性能。

### DUT

- PROP256：4 × 64-node tiles + upper Mesh
- FlatMesh256：16 × 16 Mesh

注意：

- 必须使用当前 proposed tile，而不是仓库中已经过时的旧 `1222` topology。
- 若现有 `network_matrix.py` 的 `PROP256` 仍指向旧架构，不得直接拿它当最终结果。
- 先检查 generated topology，确认 64-node tile 内部结构与当前 PROP_temp64 / 正式 proposed architecture 一致。
- 如不一致，先更新 generator / config，再 smoke test。

### Traffic

Global Uniform Random：

- source：所有 256 PEs
- destination：从其余 255 PEs uniform random
- 5-flit packet
- Poisson / 当前统一 continuous-time injection model
- seed 202701

### 流程

1. elaboration / structure check
2. directed smoke test
3. low-load correctness
4. medium-load
5. coarse saturation sweep
6. knee 附近细扫
7. full-drain selected paper points

### 仿真精度

优先：

- PROP256 / FM256：post-synthesis MAXIMUM-SDF network GLS

若 whole-network DC/GLS 确实成为不可接受的 runtime bottleneck：

- 不得自行降低精度后继续假装为 GLS；
- 先生成 runtime report；
- 明确切换为 hierarchical/calibrated network simulation，并在结果 metadata 中标注 simulation level；
- 64-node 与 256-node 不同仿真层级时，论文中必须明确。

### 指标

- peak delivered throughput
- near-lossless sustainable throughput
- saturation knee
- latency before saturation
- backlog
- delivery ratio

推荐同时冻结两个数字：

1. peak delivered throughput
2. highest point with delivery ratio >= 99%（或预先冻结的 near-lossless criterion）

### 输出图

- PROP256 vs FlatMesh256 throughput-load
- PROP256 vs FlatMesh256 latency-load
- 64 vs 256 saturation/near-lossless throughput summary

### 结果目录建议

`DATE paper/experiments/raw/paper256/global_ur_<timestamp>/`

---

## E4. 256-node Forced Inter-Tile UR

### 目的

专门压力测试 upper Mesh，排除“优势只是来自 local traffic 被 tile 吃掉”的解释。

### Traffic

对每个 source：

- destination tile != source tile
- 在其他 3 个 tiles 的 PEs 中 uniform random
- 100% packet 必须跨 tile
- 5 flits/packet

### DUT

- PROP256
- FlatMesh256

### 必须新增/统计

PROP256：

- upper-Mesh total traffic
- 每个 Mesh plane 的 delivered flits
- 每 plane utilization
- plane imbalance
- tile-to-upper-Mesh injection counts

如果内部 handshake 目前无法直接计数，至少统计能从 top-level/upper-plane interface 观察到的真实 accepted flits。

### 输出

- throughput-load
- latency-load
- per-plane utilization
- plane imbalance summary

### Acceptance

- 确认所有 generated destinations 都在不同 tile
- 正确性 full-drain PASS
- 不能使用 route-oracle count 冒充真实 plane traffic

### 结果目录建议

`DATE paper/experiments/raw/paper256/intertile_ur_<timestamp>/`

---

## E5. 256-node Cross-Tier Multicast：F16

### 目的

这是 M2 在 256-node 上最重要的实验：真正验证 multicast 穿越 local tree → upper Mesh → remote tile/local tree。

64-node multicast 不足以验证跨 tile boundary。

### 主 benchmark

`All-MC-F16`

- 100% original transactions 为 multicast
- fanout = 16
- destinations 可跨 tile
- Native vs source repeated-unicast
- matched original trace
- 5-flit packet
- full-drain

### 必须做 destination spread 三组

保持 fanout=16，只改变 16 个目的 PE 的 tile 分布：

1. **Spread-1**：全部目的地在 1 个 destination tile
2. **Spread-2**：目的地分布在 2 个 tiles
3. **Spread-4**：目的地分布在 4 个 tiles

源节点与 destination tile 的关系需要明确；推荐至少保证 Spread-2/4 包含 remote tile，以触发 upper Mesh。

### Load

P0 不要求每个 spread 都完整扫很多点。

最低要求：

- low load full-drain
- medium load
- near-congestion representative point

若时间允许，再做完整 sweep。

### 指标

- original transaction completion latency
- p95/p99 completion latency
- useful destination-delivery rate
- source injected packet/flit count
- backlog
- completion ratio
- upper-Mesh accepted traffic（如果真实可观测）

### 比较

- Native
- Repeated Unicast

### Acceptance

- low-load headline 必须 full-drain、zero backlog
- Native/repeated 使用完全相同 original trace
- completion 定义为：last intended destination 收到 Tail

### 结果目录建议

`DATE paper/experiments/raw/paper256/multicast_f16_spread_<timestamp>/`

---

## E6. 256-node MC10 + FULL Ablation

### 目的

用一个同时触发 topology、multicast、lane contention 的 mixed workload，做整篇论文的机制级 ablation。

### Benchmark：MC10

建议定义：

- 90% original transactions = unicast
- 10% original transactions = multicast
- multicast fanout = 16
- destination 全局随机，可跨 tile
- 统一 5-flit packet
- matched trace across all variants

若已有 Continuous-compatible MC10 定义，优先复用。

### 四个版本

#### FULL

- M1 ✓
- M2 ✓
- M3 ✓

#### -M1

目标：移除新的 parallel-path topology。

优先 baseline：

- 旧 PFAT / 1-2-4-8 hierarchy 的 256-node scale-out counterpart

要求：

- 尽量保持 multicast routing 和 asynchronous router family 不变；
- 若旧 PFAT256 不存在，Codex 不得临时构造一个无法验证的“假 baseline”；
- 先报告缺失，并给出最小实现方案。

#### -M2

- topology 与 FULL 完全相同
- M3 完全相同
- Native multicast → source repeated-unicast
- original transaction trace 完全相同

#### -M3

- topology 与 FULL 完全相同
- multicast 与 FULL 完全相同
- 仍保留 4 physical lanes
- Dynamic lane selection → Static deterministic lane mapping
- 不允许退化成 c1p1

### Load 选择

先用 FULL 做 MC10 load sweep，找到 FULL saturation knee。

正式 ablation 至少选：

- low load
- ~50% of FULL saturation
- ~75–80% of FULL saturation

不要只选已经严重 saturation 的点。

### 指标

统一输出：

- useful delivered throughput
- mean transaction latency
- multicast completion latency
- backlog
- delivery ratio
- upper-Mesh traffic
- lane/plane utilization（可用时）

### 论文主图

生成 normalized ablation bar chart：

- FULL = 1.0
- -M1
- -M2
- -M3

至少分别画：

1. normalized useful throughput
2. normalized latency

### 结果目录建议

`DATE paper/experiments/raw/paper256/ablation_mc10_<timestamp>/`

---

# 3. P1：强烈建议完成

---

## E7. 256-node Locality Sweep

### 目的

验证 hierarchical organization 能否利用 communication locality，减少 global/upper-Mesh traffic。

### 参数

同一总 offered load 下：

`P_local = 0%, 25%, 50%, 75%, 100%`

定义：

- local：destination 位于 source 的同一 64-node tile
- remote：destination 位于其他 tile

### DUT

- PROP256
- FlatMesh256（至少做关键点）

### 指标

- delivered throughput
- latency
- upper-Mesh traffic
- backlog
- delivery ratio

### 预期要回答的问题

随着 locality 增加：

- PROP upper-Mesh traffic 是否下降？
- PROP throughput / latency 是否改善？
- 与 FlatMesh 的差距是否扩大？

### 输出

- throughput vs locality
- latency vs locality
- upper-Mesh traffic vs locality

---

## E8. 64-node multicast fanout sweep 清理为 full-drain

当前 F=2/4/8/16/32 sweep 属于 exploratory，部分 measurement window 有 backlog/right-censoring。

### 任务

重做/重汇总：

`F = 2, 4, 8, 16, 32`

统一：

- low load
- 400 measurement original transactions
- full drain
- backlog = 0
- Native/repeated trace matched within fanout

### 输出

- completion latency vs fanout
- Native / repeated
- optional useful throughput vs fanout

目标是得到可直接进正文的 clean fanout-scaling figure。

---

## E9. Router PPA 清理

当前 Router PPA 已有：

- c1p4 Async/Sync area
- isolated / stream / idle / contention GLS
- PT-PX power/energy
- 但 PrimeTime 启动存在 `PT-063` Library Compiler path diagnostic

### 任务

- 修复或明确确认 `PT-063`
- 重跑 paper-facing energy case
- `check_power.rpt` 必须 clean
- 保存完整 PT command/log/library/PVT

### 输出

Router-level PPA table：

- geometry
- area
- body pitch（micro-benchmark）
- sustained single-stream throughput（若保留）
- energy/flit
- leakage/dynamic power

注意：

- 919 Mflit/s 只放 micro-benchmark
- aggregate throughput 仍用 1.197/1.875/3.001

---

# 4. P2：1024-node scalability，只做 calibrated network simulation

## 总原则

**禁止 1024-node full DC / P&R / PrimeTime PX。**

1024 的任务只有一个：

> 证明 64 → 256 → 1024 scale-out 后 proposed architecture 的 performance scaling。

1024 不承担详细 PPA、机制电路分析或完整 benchmark matrix。

---

## E10. 1024 Global UR

### Topology

- 16 × 64-node tiles
- 4 × 4 tile arrangement
- upper Mesh 按当前正式 architecture
- FlatMesh1024 = 32 × 32 Mesh

### 仿真方式

使用：

> timing-calibrated RTL / network-level simulation

要求：

- router/link delay 参数来自已经接受的 64/256 block/netlist measurements；
- 所有 calibration constants 必须写入 manifest；
- 不得把 calibrated result 标成 post-synthesis whole-network GLS。

### Traffic

Global UR：

- 1024 sources
- destination uniform among other 1023 nodes
- 5-flit packet
- same injection semantics as 64/256

### Sweep

粗扫到 saturation，再在 knee 附近补点。

### 输出

- PROP1024 vs FlatMesh1024 throughput-load
- pre-saturation latency-load
- saturation / near-lossless throughput

### 最终 scalability figure

一张主图：

`Network size = 64 / 256 / 1024`

分别画：

- PROP saturation/near-lossless throughput
- FlatMesh saturation/near-lossless throughput

如果 64/256 与 1024 simulation level 不同，在图注中明确注明。

---

## E11. 1024 Forced Inter-Tile UR

只做少量代表性 load points：

- low
- medium
- ~75–80% of PROP1024 saturation

Traffic：

- source/destination 必须位于不同 64-node tile

指标：

- throughput
- latency
- plane utilization
- imbalance

---

## E12. 1024 MC10

只做 3 个代表性 load points，不做完整大矩阵。

- low
- medium
- near-high but pre-saturation

目标：

- 验证 16 tiles / 1024 nodes 下 cross-tier native multicast 仍能正确运行
- 不要求再做 FULL/-M1/-M2/-M3

---

# 5. 不做 / 暂停的实验

除非后续人工明确要求，否则 Codex 不要主动扩展：

- 1024-node full DC
- 1024 P&R
- 1024 PrimeTime PX
- 1024 全 benchmark sweep
- 1024 ablation matrix
- 新的 packet length sweep
- 新的 buffer-depth sweep
- 4-lane top Mesh（当前 repo 明确 unsupported）
- 用 route-oracle link count 冒充 measured internal traffic
- 把 919 Mflit/s 与 aggregate throughput 混合
- 在 saturated/right-censored 区域比较 mean latency 优劣
- 为了“补数据”随意改变 delay cells、packet format、buffer depth 或 injection semantics

---

# 6. 建议执行顺序

严格按照以下顺序，前一项 correctness 不通过时不要开始后一项的大规模扫描。

1. **E1 — 64 Dynamic4 vs Static4**
2. **E2 — 64 BC + Hotspot10**
3. **E3 — 256 Global UR**
4. **E4 — 256 Forced Inter-Tile UR**
5. **E5 — 256 F16 Cross-Tier Multicast**
6. **E6 — 256 MC10 + FULL Ablation**
7. **E7 — 256 Locality Sweep**
8. **E8 — 64 clean fanout sweep**
9. **E9 — Router PPA cleanup**
10. **E10 — 1024 Global UR**
11. **E11 — 1024 Inter-Tile**
12. **E12 — 1024 MC10**

如果 DATE 时间不足，优先确保 **E1–E6** 完成。

---

# 7. 每个实验必须交付的统一文件

每个 experiment directory 至少：

```text
<experiment>/
├── README.md
├── manifest.json
├── commands.txt
├── hashes.txt
├── raw/
│   ├── *.csv
│   └── *.log
├── summary/
│   ├── summary.csv
│   └── acceptance.csv
├── figures/
│   ├── throughput_*.pdf
│   ├── latency_*.pdf
│   └── *.png
└── RESULTS.md
```

`manifest.json` 至少写：

```json
{
  "git_commit": "...",
  "design": "...",
  "nodes": 64,
  "simulation_level": "MAXIMUM-SDF GLS",
  "seed": 202701,
  "packet_flits": 5,
  "benchmark": "...",
  "netlist": "...",
  "sdf": "...",
  "full_drain": true
}
```

---

# 8. RESULTS.md 统一模板

每个任务结束后按下面格式输出，便于人工快速审核。

```markdown
# <Experiment Name>

## Purpose
一句话：本实验要证明什么。

## DUTs
- Proposed:
- Baseline:

## Traffic
- benchmark:
- nodes:
- packet length:
- seed:
- injection:
- fanout:
- locality/spread:

## Simulation
- level:
- netlist:
- SDF/timing model:
- full-drain:
- commit:

## Correctness
- PASS/FAIL
- sent:
- received:
- missing:
- unexpected:
- timeout:

## Main Results
| design | offered | delivered | delivery ratio | latency | backlog |
|---|---:|---:|---:|---:|---:|

## Key Claim
只写由本数据直接支持的 claim，不扩大解释。

## Caveats
right-censoring / estimated counters / simulation-level difference 等。

## Paper Usage
建议用于 Fig./Table/Section 的位置。
```

---

# 9. 论文最终希望得到的实验图表

Codex 完成全部任务后，再统一生成下列 paper-facing figures/tables。

## Fig. A — Router Multi-Lane Scaling

- c1p1 / c1p2 / c1p4 aggregate throughput
- Dynamic4 vs Static4

## Fig. B — 64-node Network Performance

- UR throughput-load
- BC throughput-load
- Hotspot10 throughput-load
- 对应 pre-saturation latency

## Fig. C — Multicast

- Native vs repeated F16
- completion latency vs fanout
- 256 spread-1/2/4

## Fig. D — 256 Ablation

- FULL / -M1 / -M2 / -M3
- normalized throughput
- normalized latency

## Fig. E — Scalability

- 64 / 256 / 1024
- PROP vs FlatMesh
- saturation or near-lossless throughput

## Table I — Router PPA / Micro-benchmark

严格区分：
- body pitch
- sustained single-stream
- aggregate multi-lane throughput

## Table II — Network Summary

- 64 / 256 / 1024
- topology
- simulation level
- peak / near-lossless throughput
- area（只在有可信 synthesis 的规模填写）
- multicast support

---

# 10. Codex 特别注意：当前仓库的旧配置可能过时

当前仓库存在历史 V3.1/V3.2 实验框架，其中 `PROP64`/`PROP256` 可能仍指向旧的 `1222` progressive-fat profile。

当前论文 proposed architecture 已经更新为新的 parallel-path / distributed hierarchy。

因此任何 256/1024 实验开始前必须：

1. 检查 generator 输出结构；
2. 对照当前正式 64-node proposed architecture；
3. 确认 L1/L2/L3、parallel physical path indices、upper Mesh planes 与当前设计一致；
4. 若不一致，先更新 generator/config；
5. 通过小规模 structural smoke test 后才能开始正式仿真；
6. 禁止仅因为文件名叫 `PROP256` 就默认它是当前 proposed design。

---

# 11. 最终完成判据

P0 完成的最低标准：

- [ ] E1 Dynamic4 vs Static4 PASS
- [ ] E2 BC + Hotspot10 完成
- [ ] E3 PROP256 vs FlatMesh256 Global UR 完成
- [ ] E4 256 forced inter-tile 完成
- [ ] E5 256 cross-tier F16 multicast 完成
- [ ] E6 256 MC10 FULL/-M1/-M2/-M3 完成
- [ ] 所有 P0 paper-facing points full-drain / correctness PASS
- [ ] 所有比较使用 matched trace / matched benchmark definition
- [ ] 所有数据有 manifest/hash/log/raw CSV
- [ ] 生成 paper-ready summary figures
- [ ] 不覆盖 2026-09-14 已冻结 Abstract 数据

完成 P0 后，再执行 P1/P2。
