# 最终实验指导（中文定稿）

这份文档用于最终敲定本项目后续论文实验的执行口径。它不是发散式的想法清单，而是后续仿真、整理 CSV、作图和撰写论文时应优先遵守的统一规范。

如无特殊说明，后续实验以本文件为准；`SIMULATION_README.md` 保留为扩展说明和设计背景。

关于 `batch_size`、功耗/能耗、同步 counterpart 公平性，以及“当前层次化矩形多播 vs 最初四叉树多播算法”的细化口径，统一参见 `POWER_AND_BASELINE_GUIDE_CN.md`。
关于参考论文对应的初始设定、workload 选择、sweep 维度和逐步执行流程，统一参见 `PAPER_DERIVED_SIMULATION_PROTOCOL_CN.md`。

## 1. 目标与范围

本文项目后续实验需要回答四个核心问题：

- 设计在层次化 quadtree + top mesh 互连中是否功能正确
- 在固定 3-flit 分组下，网络的延迟、吞吐和拥塞拐点如何变化
- 原生矩形多播相比朴素方案是否确实更高效
- 与同步电路 baseline 相比，本异步 NoC 在延迟、吞吐、功耗和实现成本上是否具备优势

## 2. 最终规模划分

后续实验固定分成两档规模，不再混用口径：

- `256-node`：用于第 1/2 层正确性验证，以及第 3 层脚本打通和单点 smoke
- `1024-node`：用于论文中的主性能结果、baseline 对比和最终图表

固定生成命令：

```powershell
sbt "runMain NoC.quadtree_and_mesh --verify-256"
sbt "runMain NoC.quadtree_and_mesh --paper-1024 --target-dir generated_1024"
```

固定原则：

- 只要目标是“证明有没有 bug”，优先使用 `256-node`
- 只要目标是“写进论文的性能曲线或 baseline 图”，统一使用 `1024-node`
- 如果当前 `generated/` 目录不是论文规模，不要直接拿来出最终结果，必须显式使用 `generated_1024/`

## 3. 固定实验环境与公共参数

### 3.1 仿真器约定

- `256-node`：可使用 `ModelSim` 或 `xsim`
- `1024-node`：统一使用 `Vivado xsim`
- 论文主结果应尽量来自同一条仿真链，避免不同仿真器混出一张图

### 3.2 公共参数

除非某项实验明确写了特殊设置，否则统一采用下面这组参数：

- `packet_len = 3 flits`
- `seeds = 12345, 22345, 32345`
- `warmup_ns = 20000`
- `measure_ns = 50000`
- `ack_delay_ns = 1`
- `packet_gap_ns sweep = 0, 10, 20, 40`
- `rect_size sweep = 1, 2, 4, 8, 16`

说明：

- `packet_len = 3 flits` 是当前性能 testbench 的固定打包长度，也是后续所有横向比较的统一口径
- `warmup_ns` 与 `measure_ns` 必须在同一组图中保持一致，不能一条曲线一个测量窗口
- 如果后续为了更平滑的最终论文图，把测量窗口增加到 `100000 ns`，应对整组图统一加长，而不是只改单个点

### 3.3 统一通过标准

任何一组仿真结果，只有同时满足下面条件，才允许进入论文 CSV 或最终图表：

- `status = PASS`
- `unexpected_core_flits = 0`
- `unexpected_top_flits = 0`
- `pending_packets = 0`
- 没有 testbench `timeout`
- 没有人工中断或 GUI 卡死造成的非正常结束

## 4. 第一层与第二层：正确性回归

这一部分的目标不是出图，而是确保后面的性能结果可信。

### 4.1 第一层：定向功能回归

必须覆盖以下场景：

- 同一 quadtree tile 内单播
- 跨 quadtree tile 单播
- tile 内矩形多播
- 跨 tile 矩形多播
- 多包竞争
- 背压与热点
- top-layer 独立路由

通过标准：

- 所有 directed cases 通过
- 无误投递、重复投递、丢包、顺序错误

### 4.2 第二层：约束随机正确性

固定推荐参数：

- 网络规模：`256-node`
- `seeds = 12345, 22345, 32345, 42345, 52345`
- `cases = 24`
- `max_pkts = 3`

推荐命令：

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_rand_suite.ps1 -Cases 24 -MaxPkts 3
```

通过标准：

- 所有 seed 均为 `PASS`
- 不接受“多数通过、少数失败”的口径
- 如果存在失败 seed，该层视为未完成，后续性能结果只可作为调试数据，不能进入论文正文

## 5. 第三层：论文主性能实验

第三层是论文的核心结果层，最终固定为三类实验：

- `3.1` 合成交通模式性能曲线
- `3.2` 多播专项与混合流量
- `3.3` baseline 对比，包括同步电路 baseline

不再把 `link distance / long-wire delay` 作为当前定稿方案中的必做项。

### 5.1 交通模式定义

后续统一使用以下交通模式名称与含义：

| 模式 | 含义 | 主要目标 |
| --- | --- | --- |
| `uniform_unicast` | 源和目的均匀分布的单播 | 给出基础 latency-throughput 曲线 |
| `local_unicast` | 尽量局限在局部 tile 或近邻范围内的单播 | 观察局部通信优势 |
| `cross_tile_unicast` | 明确跨 tile、需要经过更高层路径的单播 | 观察长路径代价 |
| `hotspot_unicast` | 多个源集中打向热点目的地的单播 | 观察拥塞和热点退化 |
| `uniform_multicast` | 矩形目的区域均匀分布的多播 | 观察原生多播基本收益 |
| `mixed_unicast_multicast` | 单播和多播并存 | 观察混合业务下的干扰 |
| `overlapping_multicast` | 多个多播矩形发生重叠 | 观察重叠目标带来的竞争和放大效应 |

### 5.2 3.1 合成交通模式性能曲线

这部分用于形成论文中的主图。

固定实验规模：

- `1024-node`
- `generated_1024/`
- `xsim batch` 优先，GUI 只用于调试单点

各模式的推荐配置如下：

| 模式 | `num_flows` | 额外设置 | 扫描变量 |
| --- | --- | --- | --- |
| `uniform_unicast` | 4 | 无 | `packet_gap_ns` |
| `local_unicast` | 4 | 无 | `packet_gap_ns` |
| `cross_tile_unicast` | 4 | 无 | `packet_gap_ns` |
| `hotspot_unicast` | 4 | 无 | `packet_gap_ns` |
| `uniform_multicast` | 1 | `rect_w = rect_h` | `packet_gap_ns`、`rect_size` |
| `mixed_unicast_multicast` | 4 | `rect_w = rect_h = 4` | `packet_gap_ns` |
| `overlapping_multicast` | 4 | `rect_w = rect_h = 4` | `packet_gap_ns`、必要时 `rect_size` |

固定测量指标：

- `avg_latency_ns`
- `p95_latency_ns`
- `p99_latency_ns`
- `avg_completion_latency_ns`
- `p95_completion_latency_ns`
- `p99_completion_latency_ns`
- `injected_flit_per_ns`
- `injected_pkt_per_ns`
- `throughput_flit_per_ns`
- `throughput_pkt_per_ns`
- `delivered_packets`
- `delivered_flits`
- `boundary_head_count`
- `boundary_tail_count`
- `pending_packets`

主图最少应包含：

- `uniform_unicast: offered load vs avg_latency_ns`
- `uniform_unicast: offered load vs p95_latency_ns`
- `uniform_unicast: offered load vs throughput_flit_per_ns`
- `cross_tile_unicast: offered load vs throughput_flit_per_ns`
- `hotspot_unicast: offered load vs avg_latency_ns`

推荐命令示例：

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf_suite.ps1 `
  -Pattern uniform_unicast `
  -SeedsCsv "12345,22345,32345" `
  -PacketGapsCsv "0,10,20,40" `
  -EdgeN 4 `
  -GeneratedDirName generated_1024 `
  -WarmupNs 20000 `
  -MeasureNs 50000
```

### 5.3 3.2 多播专项与混合流量

这部分必须体现“原生矩形多播”是本项目的真实贡献，而不是顺便支持一下多播。

固定做法：

- `uniform_multicast` 做 `rect_size sweep`
- `uniform_multicast` 做 `ack_delay sweep`
- `overlapping_multicast` 观察重叠带来的拥塞惩罚
- `mixed_unicast_multicast` 观察单播/多播并发时的性能退化

固定参数：

- `rect_size sweep = 1, 2, 4, 8, 16`
- `ack_delay_ns sweep = 1, 5, 10, 20`
- `warmup_ns = 20000`
- `measure_ns = 50000`

推荐图表：

- `uniform_multicast: rectangle size vs avg_completion_latency_ns`
- `uniform_multicast: rectangle size vs delivered_flits`
- `uniform_multicast: ack_delay_ns vs avg_completion_latency_ns`
- `overlapping_multicast: offered load vs throughput_flit_per_ns`
- `mixed_unicast_multicast: offered load vs p95_latency_ns`

推荐命令示例：

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf_rect_sweep.ps1 `
  -Pattern uniform_multicast `
  -RectSizesCsv "1,2,4,8,16" `
  -SeedsCsv "12345,22345,32345" `
  -EdgeN 4 `
  -GeneratedDirName generated_1024 `
  -WarmupNs 20000 `
  -MeasureNs 50000

powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf_ack_sweep.ps1 `
  -Pattern uniform_multicast `
  -AckDelaysCsv "1,5,10,20" `
  -SeedsCsv "12345,22345,32345" `
  -RectW 4 -RectH 4 `
  -EdgeN 4 `
  -GeneratedDirName generated_1024 `
  -WarmupNs 20000 `
  -MeasureNs 50000
```

### 5.4 3.3 baseline 对比

baseline 对比固定分成两条线，二者都要写进最终实验计划。

#### baseline A：原生多播 vs replicated unicast

定义：

- `native multicast`：使用当前 RTL 的原生矩形多播
- `replicated unicast`：把同一个矩形多播拆成多个独立单播，逐个发送到目的集合

固定比较指标：

- `avg_completion_latency_ns`
- `p95_completion_latency_ns`
- `throughput_flit_per_ns`
- `total injected_flits / delivered_flits`
- `energy_proxy_per_destination` 或 `energy_per_destination_nj`
- 热点或重叠场景下的退化程度

必须保证：

- 相同源节点
- 相同目的集合
- 相同 3-flit 包格式
- 相同 `seed`
- 相同 offered load

#### baseline B：异步 NoC vs 同步电路 baseline

这一项作为论文正式 baseline 纳入，不再只是备选想法。

同步 baseline 的公平性约束必须满足：

- 相同网络规模：优先对齐 `1024-node`
- 相同逻辑拓扑：优先保持 quadtree + top mesh；如果做不到，至少保持相同节点数和尽可能接近的层次结构
- 相同路由语义：单播/多播目的定义一致
- 相同分组格式：统一 `3-flit`
- 相同交通模式、相同 seed、相同 `packet_gap_ns`、相同 `ack_delay_ns`
- 相同统计口径：统一使用平均值、`p95`、`p99`、吞吐和完成延迟

同步 baseline 至少需要比较以下内容：

- `zero-load latency`
- `avg / p95 / p99 latency vs offered load`
- `throughput_flit_per_ns`
- `avg_completion_latency_ns`
- `saturation point`
- FPGA `LUT / FF / BRAM`
- `Fmax`
- `power`
- `energy per delivered packet`
- `EDP`
- 如果当前阶段还没有实现后功耗工具，至少补一版 `energy proxy`

工程实施建议：

- 如果当前仓库中尚无同步版 RTL，应单独建立一个 `baseline_sync/` 或同等目录，不要把同步逻辑混进异步主线代码
- 同步 baseline 的测试脚本应复用当前交通模式命名与 CSV 字段，确保后处理脚本可以直接拼图
- 如果同步 baseline 暂时只支持单播，论文中必须明确说明；但至少要完成 `uniform_unicast`、`cross_tile_unicast`、`hotspot_unicast` 三组对比

## 6. 论文最小结果集

如果目标是一篇完整论文，最终至少应形成以下结果集：

- 第一层 directed regression 全通过
- 第二层随机正确性多 seed 全通过
- `uniform_unicast` 的 latency-throughput 曲线
- `cross_tile_unicast` 与 `hotspot_unicast` 的性能曲线
- `uniform_multicast` 的 `rect_size sweep`
- `uniform_multicast` 的 `ack_delay sweep`
- `batch_size vs power / energy`
- `native multicast vs replicated unicast`
- `native multicast vs original quadtree baseline`
- `asynchronous NoC vs synchronous baseline`
- 至少一组 `256-node` 与 `1024-node` 的规模对照
- 至少一张 FPGA 实现代价对比表

## 7. 统一执行顺序

后续测试建议严格按下面顺序推进：

1. 完成 `256-node` 第一层 directed regression
2. 完成 `256-node` 第二层随机正确性多 seed 回归
3. 用 `1024-node` 跑通 `uniform_unicast` 主曲线
4. 完成 `cross_tile_unicast` 与 `hotspot_unicast`
5. 完成 `uniform_multicast` 的 `rect_size` 和 `ack_delay` 扫描
6. 完成 `mixed_unicast_multicast` 与 `overlapping_multicast`
7. 完成 baseline A：`native multicast vs replicated unicast`
8. 完成 `batch_size vs power / energy`
9. 完成 `native multicast vs original quadtree baseline`
10. 完成 baseline B：`asynchronous NoC vs synchronous baseline`
11. 最后再整理规模对照与 FPGA 表格

## 8. 数据整理要求

所有最终实验结果统一存放在：

- `sim/results/simulation/raw/`
- `sim/results/simulation/csv/`

建议新增的图表输出目录：

- `sim/results/simulation/figures/`

统一要求：

- 原始日志不要删，只能归档
- 最终图表必须能回溯到对应 CSV
- 图中的横轴、纵轴和图例命名应与本文档中的交通模式名称一致

## 9. 当前执行提醒

当前仓库允许同一份 DUT 编译后复用多个 seed 和多个负载点，因此：

- 只要 DUT 和 testbench 没改，不需要每个点都重新编译
- 同一组 `generated_1024/` 可以复用整轮第三层实验
- GUI 只用于定位单点问题，正式扫点优先使用 batch

如果后续你要把这份文档继续收紧成“论文实验 checklist”，建议直接在本文件基础上追加，不要再新开一份平行说明。
