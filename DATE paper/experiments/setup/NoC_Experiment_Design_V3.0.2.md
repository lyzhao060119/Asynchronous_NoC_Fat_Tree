# NoC 实验设计 V3.0.2
## Novelty-Driven Minimal Evaluation Plan for DATE 2027 — Execution Control Plane

> 历史版本：[`NoC_Experiment_Design_V3.0.1.md`](NoC_Experiment_Design_V3.0.1.md) 冻结技术主张、Design ID、benchmark 与 Go/No-Go。  
> V3.0.2 **不扩大**已删除的 benchmark 矩阵；只增补可复现执行计划、目录规范、模型校准口径、**物理口径冻结（post-synthesis only）** 与各阶段 Gate。
>
> 目标：在 DATE 6 页正文、Evaluation 约 1.7–2.0 页的约束下，只保留能够直接支撑论文核心 novelty 的实验。  
> 原则：**每一张图回答一个 reviewer 问题；不再追求 benchmark 数量，而追求变量隔离、对照公平和证据闭环。**

**正式性能方法（V3.0.2 冻结；2026-08-31 P&R pilot 后确认）：**

- 64-node：RTL + MAXIMUM-SDF，并由 FPGA 做完整硬件验证；
- 256-node：RTL 关键 case 校准；
- 64 / 256 / 1024 主 scalability 数据： **post-synthesis MAXIMUM-SDF** Router-primitive timing-calibrated discrete-event model；
- 1024 RTL 只在资源允许时做交叉验证，不阻塞主矩阵。

**不得称 post-layout。** 远端 ICC2 / Innovus license 可用，但 CLN28HPC+ 数字套件缺 tech LEF / `.tf` / NDM，ICC classic 无 `Galaxy-ICC` license。Phase 1 Gate FAIL 后 **DATE V3 不做 P&R 实验**（Router primitive 与 64/256/1024 网络均不做）。锁定文件：[`scripts/asic_pnr/cmr/locked_tool.json`](../../../scripts/asic_pnr/cmr/locked_tool.json)（`freeze: post-synthesis-only`）。网络总面积 = **post-synthesis** primitive cell area × 实例数。无 floorplan / link length 则不声称 wire area。日后若站点补齐 TSMC APR/PRTF，那是另开课题，不是本文的执行 Phase。

---

## 1. V3 的核心技术主张

严格 novelty search 后，论文不再把 CMR Buffer、IPM/OPM 基础结构或“异步 multicast”本身作为核心创新。实验集中证明以下三项：

### Claim A — Fixed-depth resource-efficient hierarchy

Flat PE-level Mesh 在规模增长时需要大量 Router，并增加端到端 Router traversal。  
本设计以固定深度 Q64 作为 local hierarchy，再通过 coarse-grained Top Mesh scale-out：

- 64 PE：1 × Q64
- 256 PE：2 × 2 Q64 clusters
- 1024 PE：4 × 4 Q64 clusters

要证明：

\[
\boxed{\text{fewer routers + fewer traversals + lower system-level router cost}}
\]

而不是只证明“单 Router 很快”。

### Claim B — Bounded fatness

Quadtree 减少 Router/hop，但产生 upper-level convergence。PAICORE 采用 progressive fattening 解决该问题；在 fully-asynchronous router 中继续扩大 lane 数会快速增加 OPM arbitration radix 和实现成本。

本设计冻结为：

\[
\boxed{1-2-2-2}
\]

而不是：

\[
1-2-4-8
\]

要证明：

\[
\boxed{\text{1-2-2-2 recovers most useful bandwidth at much lower PPA/arbitration cost}}
\]

### Claim C — Native cross-tier multicast

已有 hierarchical+mesh asynchronous systems（典型如 DYNAPs）已经存在，因此“Tree + Mesh”本身不是 novelty。关键区别应放在：

\[
\boxed{\text{one multicast transaction remains native multicast across both tiers}}
\]

即 packet 在 Top Mesh 中原生分叉，并在 Q64 内继续原生树状复制，而不是在 hierarchy/mesh 边界被拆成若干 global unicasts。

要证明：

\[
\boxed{\text{cross-tier native multicast reduces replicated global traffic and delivery time}}
\]

### Supporting claim — Fully asynchronous realization

Async 本身不是主要 novelty，但它是 event-driven target 的 enabling mechanism。只需证明：

- implementation competitive；
- low-load / idle power behavior合理；
- complete 64-node hardware can run robustly。

不再为 Async 单独占用大量 Network-Level figure space。

---

# 2. 实验对象与实现 Target 冻结

正式主实验只保留以下 Design ID。V3.0.2 进一步区分：

- **Router-level ASIC target**：真正需要 DC + MAXIMUM-SDF GLS + PT-PX，用于 PPA、timing、energy（**post-synthesis only**）；
- **Network-level configuration**：用于 64/256/1024 的 RTL / timing-aware network simulation；
- **FPGA image**：只用于 64-node hardware validation。

## 2.1 正式 Design ID

| ID | 设计 | 只回答什么问题 |
|---|---|---|
| **PROP** | Async；Q64；1-2-2-2；Top Mesh2；native cross-tier region multicast | Proposed |
| **SYNC** | 与 PROP Router 功能等价的同步 counterpart | Async implementation |
| **THIN** | Async；Q64；1-1-1-1；Top Mesh2；同 routing | bounded-fat ablation |
| **PFAT** | Async；Q64；1-2-4-8；同 routing | progressive-fat DSE 上界 |
| **H-REP** | 与 PROP topology/lane/local-multicast 相同，但跨 cluster multicast 在 Top Mesh 中拆成 per-target-cluster unicasts | cross-tier multicast ablation |
| **FM** | conventional flat 2-D Mesh；1 lane/link；同 flit width/buffer policy | flat topology baseline |

重要：

- **PROP vs FM**：只用于 topology/resource/unicast scalability；
- **PROP vs H-REP**：只用于 cross-tier native multicast；
- **PROP vs THIN/PFAT**：只用于 bounded-fat；
- **PROP/SYNC**：只用于 asynchronous implementation。

禁止在同一 pairwise comparison 中同时改变两个以上核心变量。

---

## 2.2 Router-Level ASIC Netlist Targets

真正需要生成 **post-synthesis** netlist（DC + MAXIMUM SDF，不做 P&R）的核心 Router target 如下。

### P0 — 必须

1. `Async_Thin_1x1`
2. `Sync_Thin_1x1`
3. `Async_Fat_1x2`
4. `Async_Fat_2x2`
5. `Async_Fat_2x4`
6. `Async_Fat_4x8`
7. `Async_TopMesh_Lane2`
8. `Async_FlatMesh_Lane1`

### P0+ — 强烈建议

9. `Sync_Fat_2x2`

理由：最终 Proposed 的关键高层 Router 是 multi-lane。如果只做 Thin Async/Sync，Reviewer 可能质疑异步对比是否能代表最终 Proposed。增加一个 `2x2` Fat Router 的 Sync counterpart，即可在不扩大同步实现矩阵的前提下给出第二组 head-to-head comparison。

### 合并原则

若不同层级的 Router 在以下方面完全一致：

- datapath width；
- arbitration structure；
- buffering；
- route-control depth；
- lane multiplicity；

仅地址位宽不同，则不重复综合多个“同构 Router”。

例如：

- Thin L1/L2/L3 若电路等价，可只保留一个 representative `Thin_1x1`；
- Fat L2/L3 若都为 `2x2` 且结构等价，只综合一次 `Fat_2x2`。

---

## 2.3 Network-Level Configurations

### P0 — 主实验只需要 9 个 configuration

#### Flat-Mesh scalability

1. `FM64`：8×8 Flat Mesh
2. `FM256`：16×16 Flat Mesh
3. `FM1024`：32×32 Flat Mesh

#### Bounded-fat DSE

4. `THIN64`：1-1-1-1
5. `PROP64`：1-2-2-2
6. `PFAT64`：1-2-4-8

#### Proposed scale-up

7. `PROP256`：2×2 Q64 clusters + Mesh2
8. `PROP1024`：4×4 Q64 clusters + Mesh2

#### Routing novelty ablation

9. `HREP1024`

其中：

\[
Netlist_{\mathrm{HREP}} \equiv Netlist_{\mathrm{PROP}}
\]

H-REP 不需要新的 Router ASIC implementation；只需切换 Top-Mesh multicast policy / testbench mode，使跨 cluster multicast 在 hierarchy/mesh boundary 被拆成 per-target-cluster unicasts。

### 明确不做

不需要：

- `THIN256 / THIN1024`
- `PFAT256 / PFAT1024`
- `SYNC256 / SYNC1024`
- 任何 Router 或网络的 P&R / post-layout netlist

原因：

- THIN/PFAT 只回答为什么选择 `1-2-2-2`，64-node Q64 已足够；
- 256/1024 的核心变量是 architecture scalability，不再混入 Sync/Fatness；
- 大规模 PPA 通过 Router primitive 的 **post-synthesis cell area** 与实例数累加建模；DATE V3 不做 primitive P&R，也不做整网 P&R。

---

## 2.4 大规模 Area / Resource 统计方法

对于 64/256/1024，主文使用：

\[
A_{\mathrm{router,total}}
=
\sum_i N_i A_i
\]

其中 \(A_i\) 来自对应 Router primitive 的 **post-synthesis DC cell area**。

同时报告：

- Router count；
- total router logic area；
- inter-router lane-link count；
- total channel-bit count。

如后续能获得可靠 floorplan / physical link length，再增加：

\[
\sum_e W_eL_e
\]

否则不声称完整 wire-area 优势。

**注意**：1024-node 不要求完整 physical netlist 才能进行 resource comparison；V3.0.2 的 PPA 证据来自 primitive-level **post-synthesis** cell area + architecture-level instance accounting。禁止把累加面积写成 placed core / post-layout。

---

## 2.5 FPGA Images

FPGA 仅保留两套完整 64-node image：

1. `FPGA_Async_PROP64`
2. `FPGA_Sync_PROP64`

不做：

- FPGA Thin；
- FPGA PFAT；
- FPGA256；
- FPGA1024。

FPGA 只负责 hardware correctness、robustness 与 sustained-throughput validation，不再次承担 architecture DSE。

---

## 2.6 Optional Mesh-Lane Sanity Configurations

Top Mesh=2 的选择只做一次内部 sanity check：

1. `PROP1024_Mesh1`
2. `PROP1024_Mesh2`（即正式 PROP1024）
3. `PROP1024_Mesh4`

Network-level 只跑一个 100% inter-cluster stress benchmark。

若结果满足：

\[
T_{\mathrm{Mesh1}} \ll T_{\mathrm{Mesh2}}
\]

且：

\[
T_{\mathrm{Mesh4}} - T_{\mathrm{Mesh2}}
\]

明显小于：

\[
T_{\mathrm{Mesh2}} - T_{\mathrm{Mesh1}}
\]

则冻结 Mesh2。

只有在结果特别漂亮或 Reviewer 风险较高时，才额外综合 `TopMesh_Lane1 / Lane4` Router；否则不进入正文主结果。

# 3. 统一 Benchmark 与统计规则

## 3.1 主 packet

主实验统一：

\[
\boxed{5\text{-flit packet}}
\]

理由：与 Continuous/CMR 的 multi-flit network evaluation 对齐，并能真实激活 Head/Body/Tail 状态。

只在两个位置使用 1-flit：

1. FPGA 补充 event packet correctness；
2. 可选 SNN trace。

不再进行 1/3/5/8-flit 大规模 sweep。

## 3.2 统一 load 测试

- warm-up：1000 original events；
- measurement：至少 10000 original events；
- 3 random seeds；
- load sweep：先粗扫，再只在 saturation 附近加密；
- 所有成对实验共享完全相同 source/destination/event trace。

Network saturation 同时报告：

1. maximum sustained throughput；
2. 对应 average latency；
3. 不用单一“2×zero-load”规则替代原始曲线判断。

## 3.3 Multicast completion

对一个 original multicast event：

\[
T_{\max}
=
t(\text{last destination tail})
-
t(\text{source header injection})
\]

V3 主文只使用 **Tmax** 作为 multicast completion latency。  
Continuous 使用 Tmin/Tavg/Tmax 很完整，但正文空间有限；Tmin/Tavg 只保存在原始数据中，不进入主文。

---

# 4. Experiment 1 — Router Implementation Table
## 目的：证明实现是可信且具有竞争力，但不把 Router microarchitecture 伪装成核心 novelty

### Benchmark R-U5

- one 5-flit packet；
- initially empty；
- no contention；
- fixed input → output；
- continuous stream 用于 cycle time / energy。

### Baseline

**SYNC**：功能等价同步 Router。

### 实验组

只选择代表性 Router，不再把所有层级都画成多张图：

1. Thin/leaf Router；
2. PROP Fat L1；
3. PROP Fat L2/L3；
4. Top-Mesh Router；
5. 对应关键 SYNC counterpart。

### 必测指标

- Area (µm²)
- Head / Body / Tail latency (ns)
- cycle time (ns)
- sustained throughput (Mflit/s)
- energy/flit 或 H/B/T energy
- idle power
- active power（continuous 5-flit）

### 主文输出

**Table I：Implementation Summary**

面积与功耗来自 **DC ZeroWireload cell area + MAXIMUM-SDF GLS + PT-PX**；不得标 post-layout / placed core area。

不再单独画：

- Node fanout-energy curve；
- Leakage/Idle/Hotspot/Parallel 四组 power bar；
- 1/3/5/8-flit sensitivity。

这些数据可留作 backup，但不占正文。

### 对应论点

> The architecture is realized with a fully asynchronous multi-flit datapath at competitive hop latency and event-driven power behavior; the synchronous counterpart establishes a same-function implementation reference.

---

# 5. Experiment 2 — Bounded-Fat Design-Space Evaluation
## 目的：直接回答“为什么不是 Thin？为什么不是 PAICORE 式继续 1-2-4-8？”

这是 V3 的第一项 **novelty-critical ablation**。

## 5.1 Configurations

\[
\text{THIN}: 1-1-1-1
\]

\[
\text{PROP}: 1-2-2-2
\]

\[
\text{PFAT}: 1-2-4-8
\]

该 DSE **只在 64-node Q64 上做完整 network experiment**，不扩展至 256/1024。

Top Mesh lane 在该实验中固定，不与 local fatness 混合。

## 5.2 Benchmark BF-STRESS64

64-PE Q64，5-flit packet。

目的地约束：

> destination 必须位于与 source 不同的 L2 subtree。

因此绝大多数 packet 必须：

\[
L1 \rightarrow L2 \rightarrow L3 \rightarrow L2 \rightarrow L1
\]

形成明确的 high-level convergence stress。

对三种配置做 injection sweep 至 saturation。

## 5.3 Hardware cost

至少 **DC 综合** 各配置中最复杂的高层 Router（post-synthesis cell area + MAXIMUM-SDF latency/energy；不做 P&R）。

必测：

- representative L2/L3 area；
- Head latency；
- energy/flit；
- cycle time；
- maximum OPM arbitration fan-in / Mutex input count；
- estimated total Q64 router logic area（primitive cell area × 实例数）。

PFAT L3 `(4,8)` 若综合成本过高，最低可接受方案是：

- 网络模型完成 1-2-4-8 throughput；
- 实际综合最复杂 L2/L3 representative router；
- 明确报告 arbitration radix，而不是只用理论“lane多”。

## 5.4 主文输出

**Fig. A — Bounded-Fat Pareto**

推荐一个双轴/散点图：

- x：Normalized total router logic area 或 max arbitration fan-in；
- y：Saturation throughput；
- 点：THIN / PROP / PFAT。

旁边小表或 label 给出 Head latency / energy。

最希望出现的结果：

\[
T_{\mathrm{PROP}} \gg T_{\mathrm{THIN}}
\]

同时：

\[
T_{\mathrm{PFAT}} \approx T_{\mathrm{PROP}}
\quad \text{or only moderately better}
\]

但：

\[
Cost_{\mathrm{PFAT}} \gg Cost_{\mathrm{PROP}}
\]

这将直接支撑 bounded-fat 的 architecture choice。

---

# 6. Experiment 3 — Fixed-Depth Hierarchy Scalability
## 目的：证明 Q64+coarse Mesh 不是“换一种拓扑”，而是用较少硬件资源降低大规模通信距离

这是 V3 的第二项 **novelty-critical experiment**。

## 6.1 Scale

| N | PROP | FM |
|---:|---|---|
| 64 | 1 × Q64 | 8×8 flat Mesh |
| 256 | 2×2 Q64 clusters | 16×16 flat Mesh |
| 1024 | 4×4 Q64 clusters | 32×32 flat Mesh |

## 6.2 Benchmark TOPO-UR

- Uniform Random unicast；
- 5-flit；
- src ≠ dst；
- 同一 random trace；
- 64/256/1024 都执行。

该实验故意只用 unicast，避免把 topology 优势和 multicast mechanism 混在一起。

## 6.3 必测指标

### Static/resource metrics

- Router count
- Total synthesized router logic area

\[
A_{\mathrm{router,total}}
=
\sum_t N_t A_t
\]

- inter-router lane-link count
- total channel-bit count

\[
C_{\mathrm{bit}}
=
\sum_e (\text{lanes}_e\times\text{flit width})
\]

如能够获得可靠 floorplan/link length，再增加：

\[
\sum_e W_eL_e
\]

否则**不在主文声称 total wire area**。

其中 256/1024 的 total router area 由已完成 **post-synthesis** 的 Router primitive cell area 按实例数累加，不要求网络 P&R；Network performance 由 RTL / timing-aware simulator 获得。禁止写成 placed core / post-layout area。

### Performance metrics

- average router traversals；
- zero-load packet latency；
- saturation throughput。

完整 load-latency curve **只需要画 1024-node**。  
64/256 只报告 zero-load + saturation summary。

## 6.4 主文输出

**Fig. B — Scalability**

建议两子图：

**(a)** Router logic cost vs N  
PROP vs FM：Router count + total router logic area。

**(b)** Communication scalability vs N  
Average router traversals / zero-load latency；在 inset 或 marker 中标 saturation throughput。

另在正文一句给出 1024-node load-latency 的关键饱和点；若曲线差异非常漂亮，再将 Fig. B(b) 改成 1024 load-latency，hop/area 用表。

### 对应论点

> Fixing the local hierarchy at Q64 prevents router complexity from increasing with system size, while cluster-level mesh scale-out substantially reduces the number of PE-level routers and average traversal distance relative to a flat mesh.

---

# 7. Experiment 4 — Native Cross-Tier Multicast
## 目的：直接回答“为什么这不是 DYNAPs-style hierarchy + mesh？”

这是 V3 **最关键的 routing novelty experiment**。

## 7.1 Baseline

**H-REP**

保持以下全部与 PROP 相同：

- Q64 hierarchy；
- 1-2-2-2；
- Mesh2；
- asynchronous router；
- CMR-style local multicast；
- packet width / buffering。

唯一改变：

> 当 multicast destinations 分布在多个 Q64 clusters 时，在 hierarchy/mesh boundary 将 original event 拆成多个 target-cluster packet，在 Top Mesh 中分别 unicast；进入目标 Q64 后再执行 local multicast。

该 baseline 表征“local hierarchical multicast + global packet replication”的设计思想。

**H-REP 不要求额外 ASIC Router netlist。** 它与 PROP 使用同一套硬件结构，只改变跨层 multicast policy，因此实现为 network configuration / routing mode 即可。

## 7.2 Isolated benchmark XMC-F16

1024 PE，5-flit，固定：

\[
F=16\ \text{destination PEs}
\]

改变 destination cluster spread：

\[
S=1,\ 4,\ 16
\]

- S=1：全部目的 PE 位于一个 cluster；
- S=4：16 个目的 PE 分布于 4 clusters；
- S=16：每个目的 cluster 约 1 个目的 PE。

每种 S 至少 32 个随机 source/destination-set samples，报告平均值。

### 指标

- number of packets injected into Top Mesh；
- Top-Mesh link traversals；
- \(T_{\max}\)；
- energy/original event（若已有 network energy model）。

预期：

S=1 时 PROP 与 H-REP 接近；

随着：

\[
S\uparrow
\]

H-REP 的 replicated global traffic 增长，而 PROP 通过 native Mesh branching 共享路径。

## 7.3 Loaded benchmark XMC10-G

1024 PE：

- 90% UR unicast；
- 10% multicast；
- multicast fanout F=16；
- destination cluster spread 固定 S=4 或 S=16（主文只选一个，建议 S=4 作为 moderate global multicast）。

Injection sweep 至 saturation。

指标只保留：

- saturation throughput；
- average packet/event latency；
- \(T_{\max}\) at one fixed moderate load（建议 25% H-REP saturation）。

## 7.4 主文输出

**Fig. C — Cross-Tier Multicast**

两子图：

**(a)** Top-Mesh traffic / \(T_{\max}\) vs cluster spread S  
PROP vs H-REP。

**(b)** 1024-node XMC10-G throughput/latency summary  
推荐画 saturation throughput bar + fixed-load latency，而不是再放完整大曲线。

### 对应论点

> Native cross-tier replication prevents multicast from degenerating into multiple global unicasts at the hierarchy/mesh boundary.

---

# 8. Experiment 5 — 64-Node FPGA Hardware Validation
## 目的：增加 implementation credibility，不承担核心 novelty

V3 删除 Node-Level FPGA 大矩阵，只保留**完整 64-node network validation**。

## 8.1 FPGA designs

只生成两套完整 network image：

- `FPGA_Async_PROP64`
- `FPGA_Sync_PROP64`

不生成 Thin/PFAT 或 256/1024 FPGA 版本。

## 8.2 仅三个 case

### FPGA-1 Directed exhaustive unicast

全部：

\[
64\times63=4032
\]

有向 source-destination pairs。

要求：

- data correct；
- no packet loss；
- no timeout/deadlock。

### FPGA-2 Uniform Random

5-flit，三个 load points：

- low；
- medium；
- near max-stable。

每 case：

\[
\ge 10^6\ \text{original events}
\]

记录 latency、throughput、error count。

### FPGA-3 Multicast robustness

选择 5-flit：

- F=4；
- F=16；
- full Q64 broadcast。

重点验证 all-destination completion 与长期无死锁。

## 8.3 主文输出

不占独立 Figure。

放入 **Table I 或一个 4–5 行 Hardware Validation 小表**：

- FPGA device；
- Async/Sync resource；
- max stable throughput；
- total tested events；
- packet/data errors；
- timeout/deadlock。

如果 long-run 达到 \(10^7\) events 且零错误，正文直接一句突出。

---

# 9. Experiment 6 — Application Trace（Strongly Recommended, Not Blocking）
## 目的：证明 spatial/region multicast specialization 在真实 event workload 下不是人为 benchmark

如果能够在 **1 天内**拿到可重放 spike trace，则加入；否则不阻塞 V3 主实验。

优先顺序：

1. 已有/可直接获得的 NAV RSNN spike trace；
2. N-MNIST 或 DVS Gesture 的 convolutional SNN trace；
3. 现有项目中能够导出的 spike communication trace。

不需要实现完整 neuron PE，只 replay NoC traffic。

## 必测

- useful destination count；
- region-covered destination count；
- region efficiency：

\[
\eta_R=
\frac{N_{\mathrm{useful}}}{N_{\mathrm{region-covered}}}
\]

- total network link traversals；
- \(T_{\max}\)；
- energy/event（若可得）。

对照优先：

- PROP；
- H-REP；
- FM（只有在已有 multicast model 时加入，不为此重新造复杂 RTL）。

主文只有在结果明显支持 region/locality claim 时才放；否则留作 future work，绝不让 application trace 拖慢核心实验。

---

# 10. Mesh2 选择：只做内部 sanity check，不预留正文空间

旧 V2.1.2 的 Mesh1/2/4 sweep 不再作为主实验。

只执行一次：

- 1024 nodes；
- PROP local hierarchy 固定 1-2-2-2；
- 100% inter-cluster UR；
- Mesh lanes = 1 / 2 / 4；
- 测 saturation throughput 与 Top-Mesh router cost。

判据：

- Mesh1 明显形成 2→1 boundary bottleneck；
- Mesh2 消除主要 bottleneck；
- Mesh4 收益递减且 cost 增长。

满足该趋势后，正文只写一句：

> A two-lane global mesh is selected to match the two-lane Q64 egress bandwidth; a 1/2/4-lane sensitivity study confirmed diminishing returns beyond two lanes.

只有 reviewer 风险高或结果特别漂亮时才把该数据塞入 Fig. A inset。

---

# 11. V3 明确删除的实验

以下项目不再进入主实验计划：

1. Continuous 全部 8 类 synthetic benchmark 全扫；
2. Node-level F=1/2/3/4 multicast energy 全曲线；
3. Transition 式 Leakage/Idle/Hotspot/Parallel 四组完整 power 图；
4. 64-node Async/Sync × UR/BC/Hotspot/MC10 全套 Network curves；
5. 64/256/1024 所有 benchmark 全部 load sweep；
6. locality 0/25/50/75/100% 全 sweep；
7. 1/3/5/8-flit packet-length sweep；
8. Node-Level FPGA 多 benchmark；
9. 256/1024 FPGA；
10. Deep-tree、多个 Mesh-width、多个 FIFO-depth 等额外主 baseline。

这些实验不是“没价值”，而是**对当前 DATE 6 页论文的 marginal evidence 太低**。

---

# 12. 最终主文实验版面预算

Evaluation 最终目标只出现：

## Table I — Implementation & Hardware Validation
包含：

- representative Async/Sync Router PPA；
- FPGA64 validation summary。

## Fig. A — Why bounded fat?
THIN vs PROP vs PFAT：

- saturation throughput；
- area / arbiter complexity trade-off。

## Fig. B — Why fixed-depth hierarchy?
PROP vs Flat Mesh，64/256/1024：

- router logic cost；
- average traversal / zero-load latency；
- 1024 saturation point。

## Fig. C — Why native cross-tier multicast?
PROP vs H-REP：

- cluster spread；
- global traffic；
- \(T_{\max}\)；
- loaded multicast throughput。

## Optional small result
1 个真实 SNN trace，仅在结果强且版面允许时出现。

这三图一表必须形成一一对应：

| Reviewer question | Evidence |
|---|---|
| Is the implementation real and competitive? | Table I |
| Why not a thin tree or aggressively fat tree? | Fig. A |
| Why not a conventional flat Mesh? | Fig. B |
| Why is this different from prior hierarchical+mesh routing such as DYNAPs? | Fig. C |
| Does the specialization match actual event traffic? | Optional SNN trace |

---

# 13. 实验执行优先级

V3.0.1 将“先准备什么 implementation target”与“后跑什么 experiment”绑定。

## Step 0 — 先完成 Router Primitive Netlist

第一批：

1. Async Thin 1×1
2. Sync Thin 1×1
3. Async Fat 1×2
4. Async Fat 2×2
5. Async Fat 2×4
6. Async Fat 4×8
7. Async TopMesh Lane2
8. Async FlatMesh Lane1
9. Sync Fat 2×2（强烈建议）

这些 primitive 一旦拿到稳定的 **post-synthesis** PPA（DC cell area + MAXIMUM-SDF GLS + PT-PX），后续 64/256/1024 total-area / energy model 才有可信基础。DATE V3 不对 primitive 做 P&R。

## P0 — 决定论文 novelty 是否成立

1. **THIN64 / PROP64 / PFAT64：BF-STRESS64**
2. **FM64 / FM256 / FM1024 vs PROP64 / PROP256 / PROP1024：resource + traversal + zero-load**
3. **FM1024 vs PROP1024：UR saturation**
4. **PROP1024 vs HREP1024：XMC-F16-S{1,4,16}**
5. **PROP1024 vs HREP1024：XMC10-G loaded result**
6. **Router Async/Sync Implementation Table**

## P1 — 增加可信度

7. `FPGA_Async_PROP64`
8. `FPGA_Sync_PROP64`
9. FPGA exhaustive unicast
10. FPGA UR long-run
11. FPGA multicast robustness

## P2 — 只做 sanity / backup

12. `PROP1024_Mesh1 / Mesh2 / Mesh4`
13. SNN trace replay
14. 额外 packet-length / hotspot / power curves

# 14. Go / No-Go 判据

V3 不只是“列实验”，还用于尽早判断论文主张是否成立。

### Bounded-fat

如果：

\[
T_{\mathrm{PROP}}
\]

相对 THIN 没有明显提升，则 bounded-fat 不能作为核心 contribution。

如果 PFAT 大幅优于 PROP 且 PPA 增量很小，则必须重新审视 1-2-2-2 选择。

### Fixed-depth hierarchy

如果 PROP 的 total router logic area / traversal 相对 Flat Mesh 没有明显优势，不能使用“resource-efficient hierarchy”作为主 claim。

### Cross-tier multicast

如果 S 从 1→16 后：

\[
Traffic_{\mathrm{HREP}}
\approx
Traffic_{\mathrm{PROP}}
\]

或 \(T_{\max}\) 几乎没有差异，则 routing novelty 证据不足，必须检查 Top-Mesh multicast implementation 或重新定位。

### FPGA

FPGA 只要求 hardware correctness 和 robustness；FPGA absolute latency 不决定 ASIC claim。

---

# 15. Implementation Checklist

正式开跑实验前，建议目录至少包含：

```text
router_asic/
├── async_thin_1x1
├── sync_thin_1x1
├── async_fat_1x2
├── async_fat_2x2
├── sync_fat_2x2
├── async_fat_2x4
├── async_fat_4x8
├── async_topmesh_lane2
└── async_flatmesh_lane1

network_sim/
├── fm64
├── fm256
├── fm1024
├── thin64
├── prop64
├── pfat64
├── prop256
├── prop1024
└── hrep1024

network_optional/
├── prop1024_mesh1
└── prop1024_mesh4

fpga/
├── async_prop64
└── sync_prop64
```

其中 `network_sim` 可以是 parameterized RTL/elaboration target，不要求生成 gate-level P&R netlist。网络性能主链使用 RTL 与 **post-synthesis MAXIMUM-SDF** 校准后的 DES。

---

# 16. V3.0.1 最终实验逻辑

\[
\boxed{
\text{Flat Mesh}
}
\]

需要大量 PE-level routers，通信距离随规模增长

\[
\Downarrow
\]

\[
\boxed{
\text{Fixed-depth Q64 hierarchy}
}
\]

减少 router count 和 traversal

\[
\Downarrow
\]

但产生 upper-level convergence

\[
\Downarrow
\]

\[
\boxed{
\text{Bounded 1-2-2-2 backbone}
}
\]

恢复关键 aggregation bandwidth，同时限制异步 arbitration complexity

\[
\Downarrow
\]

大规模通过 coarse Mesh scale out，而非继续加深/加粗 tree

\[
\Downarrow
\]

跨 cluster multicast 若在边界拆包，又会重新产生 global replication

\[
\Downarrow
\]

\[
\boxed{
\text{Native cross-tier region multicast}
}
\]

在 Top Mesh 与 local tree 中保持同一 multicast transaction 的共享路径传播

\[
\Downarrow
\]

\[
\boxed{
\text{Fully asynchronous multi-flit realization + FPGA validation}
}
\]

最终形成面向 large-scale event-driven many-PE communication 的完整实现。

---

## 一句话筛选规则

后续任何新实验只有在能够直接回答以下四个问题之一时才执行：

1. **为什么不用 Flat Mesh？**
2. **为什么不是 Thin / 1-2-4-8？**
3. **为什么不是 DYNAPs-like local multicast + global replication？**
4. **这个设计是否真的能够以异步硬件稳定实现？**

回答不了其中任何一个的问题，不进入 DATE V3 主实验。


---

# 17. V3.0.1 相对 V3.0 的更新摘要

1. 明确区分 **Router-level ASIC netlist**、**Network-level configuration** 和 **FPGA image**；
2. 将 256/1024 的 Thin/PFAT/Sync 全部删除，避免无价值组合爆炸；
3. Fatness DSE 只保留 `THIN64 / PROP64 / PFAT64`；
4. Scale-up 只保留 `PROP vs Flat Mesh` 的 64/256/1024；
5. 新增 `Sync_Fat_2x2` 作为推荐 counterpart，避免 Async/Sync 只在 Thin Router 上比较；
6. 明确 H-REP 与 PROP 可复用同一硬件，只改变 cross-tier routing mode；
7. 1024-node PPA 使用 **post-synthesis** Router primitive cell area × instance count，不要求整网或 primitive P&R；
8. FPGA 只保留 Async/SYNC Proposed 64-node 两套 image；
9. Mesh1/2/4 降级为 Optional sanity check，不再进入正文主实验矩阵。

---

# 18. V3.0.2 相对 V3.0.1 的更新摘要

1. 冻结正式性能方法：64-node RTL/MAXIMUM-SDF + FPGA 完整验证；256-node RTL 关键 case 校准；64/256/1024 主 scalability 来自 **post-synthesis** Router-primitive timing-calibrated DES；1024 RTL 仅交叉验证。
2. 2026-08-31 P&R pilot **Gate FAIL 后关闭**（缺 tech LEF/NDM + ICC classic 无 license）；**DATE V3 不做 Router 或网络 P&R**；总面积 = post-synthesis primitive cell area × 实例数；禁止把数字写成 post-layout。
3. 建立可版本化实验控制面：`DATE paper/experiments/{configs,registry,raw,intermediate,curated,figures,scripts}`。
4. 定义 `date-experiment-run-v1` manifest；缺 manifest / config hash / trace hash / frozen-structure 校验的 run 禁止进入 `curated/`。
5. Phase 1 结案写入 §20；`scripts/asic_pnr/cmr/` 仅归档，orchestrator 不调用。所有论文数字标 `post-synthesis calibrated`。
6. 增补 DES 校准阈值与 `model_version + calibration_hash` 锁定规则。
7. 将总体执行计划与各阶段 Go/No-Go 写入本文，作为唯一实验调度口径。

---

# 19. 实验控制面与目录规范

仓库根下的实验树（相对 `DATE paper/experiments/`）：

```text
configs/
  schema/          JSON Schema（design / benchmark / seeds / manifest / registry / event）
  designs/         THIN64, PROP64, PFAT64, FM64/256/1024, PROP256/1024, HREP1024, Mesh1/2/4,
                   FPGA placeholders, Router primitive IDs
  benchmarks/      R-U5, BF-STRESS64, TOPO-UR, XMC-F16, XMC10-G, FPGA cases, Mesh sanity
  seeds/           v3_main_seeds.json（冻结 3 个主 seed）
  plans/           orchestrator 计划（import / P0 matrix；`pnr_pilot` 为已关闭记录）
registry/          design / benchmark / run ID / hash / status 的可版本化索引
raw/               VCD, SDF, SPEF, 完整日志, 逐事件 CSV；不入 Git
intermediate/      可从 raw 重算的合并表；不入 Git
curated/           Table I 与 Fig. A/B/C 的窄 CSV/JSON；入 Git；禁止手改数字
figures/           最终 PDF/SVG/PNG 与绘图 metadata；入 Git
scripts/           run_experiment.py（plan/run/resume/status/archive）
model/             Phase 5 DES（本版本只建立目录与校准 JSON 口径）
setup/             本文与结构冻结文档
```

编排入口：`DATE paper/experiments/scripts/run_experiment.py`。  
DC/GLS **复用** `scripts/asic_dc/cmr/run_remote_cmr_*`。`scripts/asic_pnr/cmr/` 仅归档 Phase 1 结案与 recovery 脚本，**不在 DATE V3 主链**，orchestrator 不得调用。orchestrator 不得复制 DC/GLS 实现。

### 19.1 `date-experiment-run-v1` manifest

每个正式 run 必须记录：

| 字段 | 含义 |
|---|---|
| `run_id` | 稳定 ID；冻结后禁止覆盖 |
| `git.sha` / `git.dirty` | 发射时仓库状态 |
| `config_hash` | 规范化 design JSON SHA-256 |
| `case_hash` / `trace_hash` | canonical event JSONL 或 `.case` 哈希；无流量的 primitive run 为 `null` |
| `netlist_hash` / `sdf_hash` / `spef_hash` | 网表与寄生 |
| `tool_versions` | DC / PT / VCS / Vivado（ICC2 / Innovus 仅出现在已关闭的 Phase 1 记录） |
| `pvt` | 库、corner、RC |
| `command` / `env` | 可复现命令（不含密码） |
| `lsf_jobs` | job id / queue / host |
| `status` | `planned \| running \| pass \| fail \| archived \| imported_readonly` |
| `frozen_structure_ok` | geometry + DEL 配方 + 禁止覆盖校验 |
| `paper_eligible` | 能否进入 curated |
| `physical_class` | `post-layout \| post-synthesis \| rtl \| fpga \| model \| archive-only` |
| `artifacts` | 远端与本地路径 |

`paper_eligible` 为 false 的典型原因：Ackin-250、CFifo/`BUFFD0`、legacy Ultra/`RouterTop`、3-flit 主结果、缺 hash、结构校验失败、自称 post-layout（DATE V3 无 P&R 签核）。

### 19.2 Orchestrator 行为

| 子命令 | 行为 |
|---|---|
| `plan` | 由 plan JSON 生成 run ID 与空 manifest；不提交 LSF |
| `run` | 执行 `planned`/`fail`；config+case+netlist hash 已匹配且 `pass` 则跳过 |
| `resume` | 只重跑 `running`/`fail`/部分 case；已 PASS 的 case 不重跑 |
| `status` | 打印 registry 汇总 |
| `archive` | 标记 archive-only，禁止进入 curated |

Gate：任一正式 run 缺 manifest、配置 hash、trace hash（流量实验）或 frozen-structure 校验，**禁止** 写入 `curated/`。

---

# 20. Phase 1 结案：DATE V3 不做 P&R 实验

DATE V3 **不再安排 Router 或网络 P&R**。论文 PPA / 时序 / 能量口径冻结为 **DC + MAXIMUM-SDF GLS + PT-PX**（`physical_class = post-synthesis`）。Table I / Fig. A/B/C / DES / 正文禁止写 post-layout、post-route、placed core area。面积 = DC cell area × 实例数。

`scripts/asic_pnr/cmr/` 只作归档；orchestrator **不调用**。日后若站点补齐 TSMC APR/PRTF，那是另开课题，不是本文的执行 Phase。

## 20.1 工具与 PDK 记录（已关闭，不再重跑）

远端 `login2` / C1，标准单元 `tcbn28hpcplusbwp12t30p140`：

- ICC2 `V-2023.12`（`/soft/synopsys/icc2/V-2023.12`）license **checkout PASS**（LSF，非 login node）；
- Innovus `21.35`（`/soft/cadence/INNOVUS21`）license **checkout PASS**；
- ICC classic `V-2023.12-SP5`：**无** `Galaxy-ICC`（`SEC-51`），不能从 MW FRAM 导出 NDM/frame；
- 套件有 cell LEF、MW FRAM/lib、GDS、CCS、QRC；
- cell LEF：`SITE` 后直接 `MACRO`，**没有 LAYER 表**；引脚层写了 `M1`；
- MW **没有** 独立 technology LEF、Synopsys `.tf` 或 NDM。

锁定文件：[`scripts/asic_pnr/cmr/locked_tool.json`](../../../scripts/asic_pnr/cmr/locked_tool.json)（`freeze: post-synthesis-only`，`locked_tool: null`）。不得把任何数字写入 Table I 并标成 post-layout。

## 20.2–20.4 Recovery scripts only

下列脚本保留在 `scripts/asic_pnr/cmr/`，**不是** DATE V3 评价步骤：

- `async_preserve.tcl`：`dont_touch` / size-only（`DelayElement`/`DEL050`、Mutex 反馈、Muller-C、latch、`V2CloseEvent`、`LanePhaseAdapter`）；
- `async_rtc_data_checks.tcl`：把 [`docs/CMR_DC_Timing_Intent.md`](../../../docs/CMR_DC_Timing_Intent.md) 的 paired RTC 转成 post-route `set_data_check`；
- ICC2 / Innovus / PT Tcl 与 `run_remote_cmr_pnr_pilot.py`。

Pilot Gate 清单（route 完成、结构计数、GTECH/SEQGEN=0、DEL/Mutex 保留、post-route RTC、post-route SDF、SPEF/DEF/GDS）**全部未执行**：Thin `(1,1)` 导入即失败，place/route 从未开始。Sync 主链 **没有** CTS；Table I 的 Sync 周期与功耗来自 DC 1.0 ns ZeroWireload，不是 clock-tree 实现。

## 20.5 Pilot 结果（2026-08-31，Gate FAIL → 关闭）

已在 LSF batch（非 login node）完成：

| 检查 | 结果 |
|---|---|
| ICC2 V-2023.12 license | PASS |
| Innovus 21.35 license | PASS |
| ICC classic V-2023.12-SP5 | FAIL：`SEC-51` 本站点无 `Galaxy-ICC` |
| Thin `(1,1)` ICC2 import | FAIL：cell LEF 无 LAYER（`LEFR-012`）；MW 不能当 NDM（`LIB-027`） |
| Thin `(1,1)` Innovus import | FAIL：`IMPLF-53` M1 未定义，`IMPLF-26` 需要 tech LEF 为第一文件 |
| `generate_frame_from_mw -mw_lib … <libname>` | 语法正确，但需要已授权的 Milkyway/ICC 可执行文件 |

**Definitive blocker：** `/process/tsmc/CLN28HPC+` 的 `tcbn28hpcplusbwp12t30p140` 套件有 cell LEF、MW FRAM、GDS、CCS、QRC，**没有** 独立 technology LEF、Synopsys `.tf` 或 NDM。

**冻结：** DATE V3 **不再做 P&R 实验**。签核停在 DC + MAXIMUM-SDF GLS + PT-PX。不把 hop 网表标成 post-layout。不手写假 LAYER 表、不把 MW FRAM 当 NDM 去骗过导入。

证据：[`scripts/asic_pnr/cmr/pilot_gate_report.json`](../../../scripts/asic_pnr/cmr/pilot_gate_report.json) 与 `results/20260831_06*_cmr_pnr_pilot/`。

---

# 21. 模型校准口径

DES 位于 `DATE paper/experiments/model/`（Phase 5 实现）。V3.0.2 先冻结验收阈值：

| 检查 | 阈值 |
|---|---|
| delivery / traversal | 与 RTL **逐事件完全一致** |
| zero-load median latency | 误差 ≤ 5% |
| loaded mean latency / throughput | 误差 ≤ 10% |
| predicted saturation | 与 RTL 相差不超过一个 fine load step **或** 10% |

64 校准：PROP64、THIN64、PFAT64、FM64；同一 directed / zero-load / 若干 loaded trace；对照 RTL 与 **post-synthesis MAXIMUM SDF**。**禁止用正式主 seed 调参。**

256 校准：PROP256 与 FM256 各跑 directed、低负载 UR、一个中负载关键 case。

锁定：`model_version + calibration_hash` 通过后才允许跑 64/256/1024 正式矩阵。**DC / MAXIMUM-SDF / 冻结 DEL 配方** 变更自动使旧正式结果 `stale` 并全量重跑。超阈值只允许修复可解释模型缺项，并保留 calibration log。

---

# 22. 分阶段执行与 Go/No-Go

任何阶段未过 Gate，不进入下一阶段的正式数据采集。可以并行开发后续脚本，但不得把未校准/未签核结果写进论文。

| Phase | 内容 | Gate |
|---|---|---|
| 0 | 文档、目录、schema、registry、gitignore、orchestrator | `run_experiment.py plan/status` 本地可跑；import 的 archive-only 标记正确 |
| 1 | P&R pilot（**已关闭**） | **2026-08-31 Gate FAIL**；冻结 post-synthesis only（§20）；不再重跑、不再等 PRTF |
| 2 | 全部 Router primitive：emit → geometry → RTL smoke → DC → MAXIMUM-SDF GLS → PT-PX（**不做 P&R**） | Thin/Fat/PFAT 同一 DEL 配方；Sync 1.0 ns；GLS 零 X/Z/timeout；synthesis `check_power` PASS |
| 3 | Thin64、CMR TopMesh、PROP256/1024、FM256/1024、H-REP policy | route oracle；64 directed exhaustive；256 directed+random；零 duplicate/loss/deadlock |
| 4 | V3 traffic / TB / 统一 `Tmax` 与 saturation | 5-flit；warm-up 1000 + measurement ≥10000；3 frozen seeds；同一 canonical trace |
| 5 | DES + 64/256 校准（post-synthesis MAXIMUM-SDF） | §21 阈值；锁定 calibration hash |
| 6 | Table I | 每个数字可回溯 manifest / DC+MAXIMUM-SDF report / VCD window；口径为 post-synthesis calibrated；拒绝 `post-layout` |
| 7 | Fig. A BF-STRESS64 | PROP 对 THIN 无吞吐提升则停止 bounded-fat 核心 claim；面积用 DC cell area × 实例 |
| 8 | Fig. B scalability | hierarchy 在 area/traversal 上无优势则停止 resource-efficient hierarchy 主张；面积同上 |
| 9 | Fig. C XMC | S 增大时 H-REP 与 PROP 无差异则先查 native branch，再按 V3 重定位 novelty |
| 10 | Mesh1/2/4 sanity | 趋势不成立则正文不写 Mesh2 选择句 |
| 11 | FPGA64 | 无实板时 bitstream 不能替代 hardware validation |
| 12 | 可选 SNN | 一天 timebox；不强则只归档 |
| 13 | 聚合、审计、clean-room replay | `validate_paper_results.py` 全绿后冻结 curated/figures；拒绝自称 post-layout 的 curated 行 |

实际执行顺序：文档与 orchestrator（Phase 0 已完成）→ Phase 1 **关闭** → primitive **post-synthesis** PPA → 网络 DUT → traffic/TB → 模型校准（MAXIMUM-SDF）→ P0 图（Table I → Fig. A → Fig. B → Fig. C）→ P1 FPGA → P2 backup → 审计。P&R 不进入该顺序。

---

# 23. 初始 registry 导入规则

只读导入、不得覆盖远端冻结目录：

| 来源 | run ID | paper_eligible | 说明 |
|---|---|---|---|
| 6× Async hop | `20260830_cmr_{thin,fat}_l{1,2,3}_hop_del050_ackin050` | 仅作 **post-synthesis** hop 对照 | 锁定 DEL 配方；这就是论文 hop 口径，不期待 post-route 替换 |
| Hop PPA 汇总 | `20260830_cmr_router_level_baseline_del050` | 同上 | 禁止覆盖 |
| Sync64 Thin | `20260831_014622_cmr_sync_noc64_thin_p50` | post-synthesis 网络 | 1.0 ns |
| Sync64 Fat 1222 | `20260831_084457_cmr_sync_noc64_fat1222_p50` | post-synthesis 网络 | 1.0 ns |
| 当前 mesh64 | registry 记录当时 `CMR_MESH64_RUN_ID` | 未签核前否 | 进行中/未完成不得进 curated |
| Ackin-250 NoC64 | `20260830_095259_cmr_noc64_p50_1222` | **false** | archive-only |
| Thin NoC16 CFifo | `20260828_cmr_cfifo_tp_nogrant_p50` | **false** | CFifo/`BUFFD0`，archive-only |
| P&R pilot blocker | `20260831_cmr_pnr_pilot_blocker` | **false** | 缺 tech LEF/NDM；DATE V3 锁 post-synthesis |

H-REP 不占用新的 Router ASIC run；与 PROP 共享 netlist hash，只改 boundary split policy。
