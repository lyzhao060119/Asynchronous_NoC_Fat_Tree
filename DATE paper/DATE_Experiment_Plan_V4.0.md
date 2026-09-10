# 实验规划 V4.0

> 依据当前最新 Introduction 与 Background 重新整理  
> 论文主线：**在 fully asynchronous hierarchical NoC 中，使同一个 multi-flit multicast transaction 原生跨越 local tree 与 upper on-chip mesh，同时用有限 physical lanes 缓解层级汇聚带宽压力。**

---

## 0. 实验总目标

### Claim 1 — Cross-tier multicast continuity

同一个 multicast packet 在：

$$
\text{Source Tree}
\rightarrow
\text{Upper Mesh}
\rightarrow
\text{Destination Trees}
$$

之间连续传播，不在 Tree–Mesh boundary 转化为多个 destination-cluster-specific unicast packets。

**要证明的问题：**

> 相比 hierarchy boundary 处进行 packet replication 的方案，native cross-tier multicast 是否能减少 upper-mesh traffic，并降低 multicast completion latency / congestion cost？

---

### Claim 2 — Fully asynchronous multi-lane realization

Local tree 使用多个 physical lanes 增加可用带宽；在 two-phase asynchronous handshake 下，multicast branch 被分配到一条 lane，并保持到 packet 完成。

**要证明的问题：**

> 这种 multi-lane control 是否能够正确实现，并在 throughput 与 hardware cost 之间形成合理 trade-off？

---

### Claim 3 — Tree–Mesh scale-out organization

系统不持续加深单棵 hierarchy，而是将 PE 组织成固定深度 local tree clusters，再通过 upper on-chip 2-D mesh 扩展系统规模。

**要证明的问题：**

> 相比 flat mesh，这种组织在 64 → 256 → 1024 PE 扩展时，是否能降低 routing structure / traversal cost，并保持可接受甚至更好的 latency 和 throughput？

---

# 1. Proposed Configuration 冻结

正式 Proposed 在主实验中固定为：

$$
\boxed{\text{Local Tree: }1-2-2-2}
$$

$$
\boxed{\text{Upper Mesh: 2 physical lanes}}
$$

$$
\boxed{\text{Cluster size: }Q64}
$$

后续实验不得继续扫描 lane 数，避免引入过多自变量。

网络规模：

- 64 PE：1 × Q64
- 256 PE：4 × Q64
- 1024 PE：16 × Q64

其中 256 / 1024 用于 network-level scalability，不要求进行完整整网 ASIC P&R。

---

# 2. Baselines

主文只保留与论文 claim 直接相关的 baseline。

## 2.1 Flat Mesh

与 Proposed 使用：

- 相同 PE 数；
- 相同 flit / packet format；
- 相同 traffic generator；
- 相同 multicast destination set；
- 尽可能一致的 Router primitive / asynchronous implementation assumption。

用途：

$$
\boxed{\text{证明为什么需要 hierarchy}}
$$

主要比较 64 / 256 / 1024 PE 的：

- Router / routing logic resource；
- average router traversals；
- zero-load latency；
- saturation throughput；
- 可靠计算时再报告 total router logic area / link cost。

---

## 2.2 H-REP — Hierarchical Replication Baseline

H-REP 与 Proposed 使用**完全相同的硬件拓扑**：

- 相同 Q64 local trees；
- 相同 `1-2-2-2` lane 配置；
- 相同 upper Mesh；
- 相同 asynchronous Router；
- 相同 local-tree multicast；
- 相同 packet length / destination set。

唯一变量是：

### Proposed

一个 multicast transaction 原生跨 Tree–Mesh：

$$
MC
\rightarrow
Mesh\ replication
\rightarrow
Tree\ replication
$$

### H-REP

到 Tree–Mesh boundary 后，按照目标 cluster 生成独立 packet：

$$
MC
\rightarrow
\{P_1,P_2,\ldots,P_S\}
$$

其中 \(S\) 为包含 destination 的 cluster 数。

用途：

$$
\boxed{\text{隔离并验证 cross-tier multicast routing 的价值}}
$$

---

## 2.3 Lane Provisioning Baselines

只在 64-PE local hierarchy 上比较：

$$
\text{THIN}=1-1-1-1
$$

$$
\text{PROP}=1-2-2-2
$$

$$
\text{PFAT}=1-2-4-8
$$

用途：

$$
\boxed{\text{证明有限 lane 数的 bandwidth / cost trade-off}}
$$

此实验完成后，正式网络实验只使用 PROP。

---

## 2.4 Synchronous Counterpart

同步 counterpart 的职责只限于：

- implementation credibility；
- area / latency / power / energy 的参考；
- FPGA trend comparison。

它**不是论文 architecture novelty 的主 baseline**，因此不在所有 network benchmark 上重复完整 sweep。

---

# 3. Experiment A — Router Implementation and Correctness

## 3.1 目标

证明：

1. two-phase multi-lane Router 可以实现；
2. Head / Body / Tail 在 lane reservation 下连续正确传播；
3. arbitration 与 phase adaptation 不破坏 handshake state；
4. ASIC / FPGA flow 均可闭环。

---

## 3.2 Router ASIC Targets

优先准备以下 Router-level implementation target：

1. Async Thin 1×1
2. Async Fat 1×2
3. Async Fat 2×2
4. Async Fat 2×4
5. Async Fat 4×8
6. Async Top-Mesh Lane2
7. Async Flat-Mesh Lane1
8. Sync Thin 1×1
9. Sync Fat 2×2（强烈建议）

这里的 `a×b` 表示对应层级的输入 / 输出 lane organization，具体命名以 RTL 最终模块定义为准。

---

## 3.3 Correctness Benchmarks

### Case A1 — Single packet

- 5-flit packet；
- Head + Body × 3 + Tail；
- congestion-free；
- 覆盖所有 input → output 组合。

检查：

- flit 顺序；
- packet 完整性；
- Req/Ack phase；
- lane ownership；
- Tail 后 lane release。

### Case A2 — Lane competition

多个输入同时请求同一输出 / 不同 lane。

检查：

- arbitration correctness；
- 无 duplicated grant；
- 无 lost request；
- 无 lane reassignment in packet；
- 无 deadlock。

### Case A3 — Multicast branch

一个 packet 同时产生多个 branch。

检查：

- branch 数与 destination 一致；
- 每个 branch 只复制一次；
- 不产生多余 packet；
- 各 branch 可按不同 downstream speed 独立推进。

---

## 3.4 ASIC Implementation Metrics

统一输出：

| Metric               | 定义                                               |
| -------------------- | ------------------------------------------------ |
| Area                 | synthesized / post-layout cell area              |
| Head latency         | Head accepted at input → Head accepted at output |
| Body latency         | steady-state Body flit transfer latency          |
| Tail latency         | Tail accepted at input → Tail accepted at output |
| Cycle / service time | consecutive flit sustained transfer interval     |
| Sustained throughput | steady traffic 下单位时间成功输出 flits                   |
| Idle power           | 无 traffic                                        |
| Active power         | 固定代表 workload                                    |
| Energy/flit          | active energy / delivered flits                  |

所有 Async / Sync 结果必须：

- 使用同一工艺库；
- 使用同一 PVT；
- 使用同一 flit width；
- 使用一致的 activity window；
- 明确 pre-layout 或 post-layout；
- 不混用不同 corner 的数据。

---

# 4. Experiment B — Lane Provisioning / Fatness Ablation

## 4.1 研究问题

$$
\boxed{
1-2-2-2
\text{ 是否比 Thin 有足够 throughput 收益，}
\text{同时避免 }1-2-4-8\text{ 的过高 cost？}
}
$$

---

## 4.2 配置

网络：单个 Q64。

实验组：

- THIN64 = `1-1-1-1`
- PROP64 = `1-2-2-2`
- PFAT64 = `1-2-4-8`

除 lane 数外，其余全部固定：

- topology；
- routing；
- packet length；
- asynchronous protocol；
- flit width；
- traffic pattern。

---

## 4.3 Benchmark — BF-STRESS64

设计专门的 aggregation stress traffic：

- source 位于一个 lower subtree；
- destination 强制位于不同 lower subtree；
- traffic 必须穿越 upper tree level；
- 避免大量 local-only traffic 掩盖汇聚瓶颈。

至少测试：

1. Uniform cross-subtree unicast；
2. cross-subtree multicast；
3. 可选 hotspot-to-upper-tree stress。

---

## 4.4 Injection Sweep

从低负载开始连续增加 injection rate，直到出现：

- latency 急剧上升；
- throughput 不再线性增长；
- 或达到稳定 saturation。

主文只需要保留完整 load-latency / throughput 曲线中的关键结果。

---

## 4.5 Metrics

必须测：

- saturation throughput；
- zero-load latency；
- loaded latency；
- total synthesized router area；
- critical arbitration fan-in / control complexity；
- energy/flit。

---

## 4.6 最终 Figure

**Fig. A — Lane Provisioning Trade-off**

建议表现形式：

- x：hardware cost / area；
- y：saturation throughput；

或者：

- 左：load-throughput；
- 右：area / energy summary。

目标是证明 PROP 位于合理 Pareto 点，而不是宣称绝对最优。

---

## 4.7 Go / No-Go

### 可以支持 `1-2-2-2`

如果：

- 相比 THIN，throughput 有明确提升；
- 相比 PFAT，hardware cost 明显更低；
- PFAT 的额外 throughput 收益开始递减。

### 不应强行支持

如果：

- PFAT throughput 大幅优于 PROP；
- PFAT area / energy 增幅很小；
- PROP 没有形成合理 Pareto trade-off。

若出现这种情况，应重新调整 Proposed lane configuration，而不是通过措辞掩盖结果。

---

# 5. Experiment C — Scalability: Proposed vs Flat Mesh

## 5.1 研究问题

$$
\boxed{
\text{Fixed local hierarchy + upper Mesh}
\text{ 是否比 Flat Mesh 更适合规模扩展？}
}
$$

---

## 5.2 Network Configurations

### Flat Mesh

- FM64
- FM256
- FM1024

### Proposed

- PROP64
- PROP256
- PROP1024

Proposed 全部固定：

$$
Q64 + 1-2-2-2 + Mesh2
$$

---

## 5.3 Benchmark

这一实验必须尽量隔离 topology 变量。

正式主 benchmark：

### Uniform Random Unicast

原因：

- 不引入 multicast routing 差异；
- 不偏向 Proposed 的 native multicast；
- 纯粹观察 topology scaling。

可选 supporting case：

- locality-biased unicast；
- 但不建议占主文 Figure。

---

## 5.4 Metrics

### Hardware / structural

- Router instance count；
- synthesized router logic area accumulation；
- link / lane count；
- channel-bit cost；
- average minimal router traversals；
- maximum router traversals。

### Performance

- zero-load packet latency；
- average latency vs injection rate；
- per-node throughput；
- saturation throughput。

---

## 5.5 Area Accounting

256 / 1024 不要求整网 P&R。

采用：

$$
A_{\text{network}}
=
\sum_i N_i A_i
$$

其中：

- \( $N_i$ )：第 \(i\) 类 Router primitive 实例数；
- \($A_i$ )：其 ASIC implementation area。

必须明确这是：

> **estimated total router logic area from physically implemented primitives**

不要表述成 full-network post-layout area。

---

## 5.6 Figure

**Fig. B — Network Scalability**

建议至少包含：

1. average router traversals vs network size；
2. zero-load latency vs network size；
3. saturation throughput vs network size；
4. total router logic cost vs network size。

如果版面不足，优先级：

\[
\text{Traversal}

> 

\text{Latency}

> 

\text{Throughput}

> 

\text{Area}
\]

其中 Area 可压入 Table。

---

## 5.7 Go / No-Go

理想结果：

随着：

\[
64\rightarrow256\rightarrow1024
\]

Proposed 相比 Flat Mesh：

- average router traversals 增长更慢；
- total routing logic 增长更合理；
- zero-load latency 优势扩大；
- saturation throughput 至少不显著恶化。

若 1024 下 hierarchy 的 upper Mesh / tree root 出现严重 saturation，则需要重新检查：

- Mesh lane 数；
- traffic concentration；
- routing policy；
- Q64 cluster size。

---

# 6. Experiment D — Cross-Tier Multicast

## 6.1 研究问题

全文最核心问题：

\[
\boxed{
\text{为什么 multicast 必须原生跨 Tree 和 Mesh，}
\text{而不是在 hierarchy boundary 进行 replication？}
}
\]

---

## 6.2 网络

固定：

\[
1024\ PE = 16\times Q64
\]

比较：

- PROP1024
- HREP1024

二者硬件完全一致，只改变 cross-tier routing policy。

---

## 6.3 Isolated Multicast Benchmark

固定 multicast fanout：

\[
F=16
\]

扫描 destination cluster spread：

\[
S=1,\quad4,\quad16
\]

定义：

- \(F\)：destination PE 总数；
- \(S\)：这些 destination 分布到多少个 Q64 cluster。

例如：

### S = 1

16 个 target 全在同一 Q64。

### S = 4

16 个 target 分布在 4 个 Q64，每个约 4 个。

### S = 16

16 个 target 分布在 16 个 Q64，每个约 1 个。

这样保证 fanout 不变，只增加 global spatial spread。

---

## 6.4 核心 Metrics

### 1. Upper-Mesh Injected Packets

\[
N_{\text{inj}}
\]

直接测有多少 packet 被注入 upper Mesh。

### 2. Link Traversals

\[
H_{\text{total}}
=
\sum_{\text{all packet copies}} \text{links traversed}
\]

用于衡量网络内部 traffic duplication。

### 3. Multicast Completion Latency

\[
T_{\max}
=
t_{\text{last destination tail}}
-
t_{\text{source head}}
\]

注意必须以**最后一个 destination 收到 Tail**作为整个 multicast transaction 完成。

### 4. Optional Energy

若 network energy model 足够可信：

\[
E_{\text{MC}}
\]

否则主文不要强行报告。

---

## 6.5 Loaded Multicast Benchmark

在 isolated case 之外，再做一个 loaded case 防止 reviewer 认为优势只存在于无背景流量环境。

推荐：

- 90% Uniform Random unicast；
- 10% global multicast；
- multicast fanout 固定；
- destination 跨多个 cluster。

比较：

- average unicast latency；
- multicast completion latency；
- total throughput；
- saturation point。

---

## 6.6 Figure

**Fig. C — Cross-Tier Multicast**

主图：

x：

\[
S=1,4,16
\]

y 可放：

- normalized upper-mesh injected packets；
- normalized link traversals；
- multicast completion latency。

最好直接 normalize 到 H-REP = 1 或 Proposed/H-REP ratio，突出随着 cluster spread 增加，两者差距是否扩大。

---

## 6.7 Go / No-Go

这是全文最严格的判据。

### Claim 得到强支持

当 \(S\) 增加时：

- H-REP upper-mesh packet 数明显增加；
- H-REP link traversal 增长明显；
- Proposed completion latency 相对优势扩大；
- loaded case 下 Proposed saturation / latency 更优。

### Claim 支持较弱

如果：

- injected packet 数不同，但 latency 几乎没有区别；
- H-REP replication cost 被 upper Mesh 带宽完全吸收；
- loaded case 下没有 measurable benefit。

此时论文仍可能有 routing novelty，但“system-level benefit”会明显变弱。

---

# 7. Benchmark 与 Packet 设置统一规则

## 7.1 Packet Length

正式 network 实验统一使用：

$$
\boxed{5\text{-flit packet}}
$$

除非某一实验明确是在研究 packet length。

原因：

- 能真实覆盖 Head / Body / Tail；
- 能验证 packet-level lane reservation；
- 避免 single-flit specialization。

---

## 7.2 Traffic Generator

每一项实验必须保存：

- random seed；
- source selection rule；
- destination selection rule；
- multicast fanout；
- cluster spread；
- injection rate；
- warm-up interval；
- measurement interval；
- total events。

同一 Figure 中所有 baseline 必须使用相同 seeds。

---

## 7.3 Saturation 定义

不要人工选一个“看起来拐了”的点。

统一定义 saturation throughput / saturation injection rate，例如：

- throughput 相对 injection 不再近似线性增长；
- 或 latency 达到 low-load latency 的固定倍数；
- 或使用统一自动判定规则。

最终论文中必须给出明确定义，并对所有 baseline 一致使用。

---

# 8. Network Configuration Checklist

主实验需要准备的 network configuration：

| ID       | Configuration       | 用途                      |
| -------- | ------------------- | ----------------------- |
| FM64     | Flat Mesh, 64 PE    | scalability             |
| FM256    | Flat Mesh, 256 PE   | scalability             |
| FM1024   | Flat Mesh, 1024 PE  | scalability             |
| THIN64   | Q64, 1-1-1-1        | lane ablation           |
| PROP64   | Q64, 1-2-2-2        | proposed                |
| PFAT64   | Q64, 1-2-4-8        | lane ablation           |
| PROP256  | 4×Q64 + Mesh2       | scalability             |
| PROP1024 | 16×Q64 + Mesh2      | scalability / multicast |
| HREP1024 | same HW as PROP1024 | cross-tier baseline     |

HREP1024 应尽量与 PROP1024 复用同一 RTL / simulator hardware model，仅通过 routing policy 切换。

---

# 9. 数据与结果文件规范

每次实验至少输出：

```text
experiment_id/
├── config.json
├── raw.csv
├── summary.csv
├── run.log
├── seed.txt
└── figure_source.csv
```

`config.json` 必须记录：

- topology；
- network size；
- lane configuration；
- routing policy；
- packet length；
- traffic type；
- fanout；
- cluster spread；
- injection rate；
- simulation cycles / events；
- random seed；
- git commit hash。

禁止只保留最终画图数据而丢失 raw result。
