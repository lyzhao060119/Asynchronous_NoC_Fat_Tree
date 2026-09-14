# DATE 今日紧急实验清单

目标：只完成用于冻结 **Title + Abstract** 的关键实验。当前不做 256-node，不扩展完整 Evaluation。

## 1. M1：Topology —— 64-node 单播对比

### 实验

比较：

- 新 Parallel-Path64
- 旧 PFAT64 `1-2-4-8`
- FlatMesh64

Traffic：Uniform Random Unicast，统一 packet 长度、traffic generator、measurement window、SDF/PVT 口径。

### 需要交付的数据

每个 load 输出：

- offered throughput（Mflit/s/port）
- delivered throughput（Mflit/s/port）
- mean latency（ns）
- p95 / p99 latency（ns）
- backlog

若时间允许，新拓扑继续向上扫直到出现明显 saturation knee。

---

## 2. M2：Multicast —— Native Multicast 消融

### 主实验

比较：

- Parallel-Path64 + Native Multicast
- **同一拓扑** + multicast replication / repeated-unicast baseline

固定：

- 100% multicast
- fanout = 16
- 相同 source multicast transaction arrival process

做完整 load sweep，直到至少一方进入明显 saturation。

### 需要交付的数据

每个 load 输出：

- offered multicast transaction rate
- completed multicast transaction rate
- useful destination delivery rate
- mean multicast completion latency（ns）
- p95 / p99 completion latency（ns）
- injected flits
- total link traversals
- backlog

### Fanout Sweep

固定一个中高、未饱和 load，比较：

`fanout = 2, 4, 8, 16, 32`

输出：

- completion latency
- link traversals
- injected flits
- useful throughput

重点最终计算：

- traffic reduction (%)
- multicast throughput improvement (%) 或 completion-latency reduction (%)

---

## 3. M3：Router —— Async vs Sync

### 实验

比较：

- Async `c1p4`
- Sync `c1p4`

保持相同 technology、PVT、port geometry、buffer、packet width 和 routing functionality。

### 需要交付的数据

- head-hop latency（ns）
- body service interval（ns）
- maximum flit rate（Gflit/s 或 Mflit/s）
- cell area（µm²）
- energy/flit（pJ）
- dynamic power / leakage（若时间允许）

### 可选附加实验

比较：

- Async `c1p4`
- Async `c4p8`

输出同样的 latency / service interval / area / energy，用于说明“多个窄 Router”相比“少量宽 Router”的代价与收益。

---

# 最终需要交付给我的文件/表格

## A. Unicast

三组：Parallel-Path64 / PFAT64 / FlatMesh64

字段：

```csv
offered,delivered,mean_latency,p95,p99,backlog
```

## B. Multicast 主扫描

两组：Native Multicast / Replication baseline，fanout = 16

字段：

```csv
load,offered_transactions,completed_transactions,useful_delivery_rate,mean_completion_latency,p95_completion_latency,p99_completion_latency,injected_flits,link_traversals,backlog
```

## C. Multicast Fanout Sweep

```csv
scheme,fanout,mean_completion_latency,link_traversals,injected_flits,useful_delivery_rate
```

## D. Router Summary

| Metric                     | Async c1p4 | Sync c1p4 | Async c4p8（可选） |
| -------------------------- | ----------:| ---------:| --------------:|
| Head-hop latency (ns)      |            |           |                |
| Body service interval (ns) |            |           |                |
| Max flit rate              |            |           |                |
| Cell area (µm²)            |            |           |                |
| Energy/flit (pJ)           |            |           |                |
| Dynamic power              |            |           |                |
| Leakage                    |            |           |                |

---

# 今日优先级

1. **Native Multicast vs Replication，F=16 完整 load sweep**
2. **Async c1p4 vs Sync c1p4 Router 测试**
3. **Fanout = 2/4/8/16/32 sweep**
4. **新拓扑单播继续向上扫 saturation**
5. 可选：`c1p4` vs `c4p8`

完成前 3 项后即可冻结 Abstract 的三类定量结果：**M1 throughput、M2 multicast benefit、M3 router latency/energy**。
