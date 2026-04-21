# Simulation README

这份文档定义本项目后续仿真的标准做法。目标不是只证明 RTL “能跑”，而是把仿真工作整理成一套可复现、可统计、可写进论文的实验体系。

后续新增测试、性能脚本、统计口径和图表，建议都以这里为准。

## 目标

整套仿真流程需要回答 4 个问题：

- 设计是否正确，是否会丢包、重包、误投递或打乱 flit 顺序
- 在竞争、背压和长期运行下是否稳定
- 原生矩形多播相对 baseline 是否真的更有效
- 网络规模、矩形大小、流量模式变化时，性能趋势如何

## 当前规模约定

- `256-node`：`2x2` 个 quadtree tile，总计 `256` 个 core，用于第 1/2 层验证和快速性能冒烟
- `1024-node`：`4x4` 个 quadtree tile，总计 `1024` 个 core，用于论文主结果

推荐原则：

- 正确性回归优先使用 `256-node`
- 论文曲线优先使用 `1024-node`
- 与规模弱相关或只是机制级 smoke 的实验，默认先用 `256-node`
- 与路径长度分布、top-layer 竞争或大扇出 multicast 明显相关的实验，默认用 `1024-node`

规模相关性判定标准：

- 指标是否依赖平均路径长度或尾部路径长度分布
- 指标是否依赖 top-layer 竞争与跨 tile 拥塞
- 指标是否依赖 multicast 扇出规模或目标矩形跨 tile 比例

如果以上任一项答案是“是”，默认归类为“与规模强相关”，优先走 `1024-node`。如果三项都不是核心关注点，而目标只是功能、局部仲裁、CSV 连通性或单点 smoke，则默认归类为“与规模弱相关”，优先走 `256-node`。

当前机器上的默认仿真器映射：

- `256-node + ModelSim`：第 1 层定向功能回归、第 2 层约束随机正确性、第 3 层 `3.1` 单点 smoke，以及第 3 层 `3.2/3.4` 的早期调试或脚本打通
- `1024-node + xsim`：第 3 层 `3.1` 最终 latency-throughput 曲线、第 3 层 `3.2` 最终 multicast fanout/overlap/cross-tile 结果、第 3 层 `3.3` 应用驱动流量，以及第 3 层 `3.4` 中明显依赖规模效应的结果
- 第 4 层 baseline 对比默认按论文结果口径走 `1024-node + xsim`；如果只是先验证 baseline 机制是否打通，可以先在 `256-node + ModelSim` 上做 smoke
- 第 5 层可扩展性与稳健性默认同时覆盖 `256-node` 和 `1024-node`，其中 `1024-node + xsim` 是最终规模敏感结论的默认路径

当前限制：

- 现有 `ModelSim Intel FPGA Edition 2020.1` 可以编译 `quadtree_and_mesh_perf_1024_light_tb`，但会在 `vsim` 加载设计阶段出现内存分配失败，因此当前不把 `1024-node + ModelSim` 作为默认执行路径

相关生成命令：

```powershell
sbt "runMain NoC.quadtree_and_mesh --verify-256"
sbt "runMain NoC.quadtree_and_mesh --paper-1024 --target-dir generated_1024"
```

## 当前仓库基础

现有仓库已经具备较完整的功能性基础：

- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`
- `sim/testbenches/toplayer_mesh/toplayer_mesh_tb.sv`
- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`

现有脚本入口：

- `sim/xsim/three_level_quadtree/launch.ps1`
- `sim/xsim/quadtree_and_mesh/launch.ps1`
- `sim/xsim/quadtree_and_mesh/run_rand.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf.ps1`
- `sim/xsim/toplayer_mesh/launch.ps1`

这些内容足以支撑“功能正确性验证”，但论文级实验还需要：

- 约束随机正确性
- 系统级性能扫描
- baseline 对比
- 规模和稳健性实验
- 统一的 CSV 输出和图表规范

## 分层方案

后续仿真按 5 层推进。

### 第 1 层：定向功能回归

目的：

- 保证关键路径一直正确
- 给后续随机和性能实验提供最低门槛

必须覆盖：

- 同 tree 单播
- 跨 tree 单播
- 矩形多播
- 跨 tile 矩形多播
- 边界翻转归一化
- 多包竞争
- 背压热点
- top-layer 独立路由

对应文件：

- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`
- `sim/testbenches/toplayer_mesh/toplayer_mesh_tb.sv`

通过标准：

- 所有 directed case 通过
- 不允许出现 `timeout`
- 不允许出现 `unexpected traffic`
- 不允许出现 `duplicate delivery`
- 不允许出现 `packet interleaving`

### 第 2 层：约束随机正确性

目的：

- 证明设计不是只在手写 case 下正确
- 用大量随机场景发现角落 bug

建议随机维度：

- 源节点
- 单播或矩形多播
- 矩形宽高
- 包长
- 注入间隔
- 并发流数量
- sink `ack delay`
- 热点位置和热点强度

必须检查：

- 理论目标集合与实际接收集合是否一致
- 是否丢包
- 是否重复投递
- 是否误投递
- 包内 flit 顺序是否保持
- body/tail 是否复用 head 的路径和 lane
- 是否出现死锁或长时间停滞

建议实现：

- 独立随机 testbench
- scoreboard
- `seed` 参数化

对应文件：

- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_rand_tb.sv`
- `sim/xsim/quadtree_and_mesh/run_rand.ps1`

通过标准：

- 多个 seed 下无功能错误
- `drop_count = 0`
- `duplicate_count = 0`
- `misroute_count = 0`
- `timeout_count = 0`

### 第 3 层：性能评估

目的：

- 形成论文中的核心性能图
- 回答“快不快、何时饱和、什么场景下有优势”

这一层是论文实验的主体，建议拆成 4 个子层面。

#### 3.1 合成流量微基准

这部分用来建立最基础的 latency-throughput 曲线。

当前执行分层：


- `最终论文结果`：默认使用 `1024-node + xsim` 生成完整 latency-throughput 曲线和规模敏感结论


建议命令：

```powershell
powershell -ExecutionPolicy Bypass -File sim/modelsim/quadtree_and_mesh/run_perf_smoke.ps1
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern uniform_unicast -EdgeN 4 -GeneratedDirName generated_1024 -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
```

建议至少覆盖：

- `uniform_unicast`
- `local_unicast`
- `cross_tile_unicast`
- `hotspot_unicast`
- `uniform_multicast`
- `mixed_unicast_multicast`
- `overlapping_multicast`

自变量：

- offered load
- 包长
- 并发流数量
- `ack delay`
- 矩形宽高
- 网络规模

指标：

- `avg_head_latency_ns`
- `p95_head_latency_ns`
- `p99_head_latency_ns`
- `avg_completion_latency_ns`
- `p95_completion_latency_ns`
- `p99_completion_latency_ns`
- `accepted_throughput_flit_per_ns`
- `delivered_packets`
- `delivered_flits`
- `boundary_head_count`
- `boundary_tail_count`
- `pending_packets`

建议图表：

- `offered load vs average latency`
- `offered load vs p95 latency`
- `offered load vs throughput`
- `packet length vs completion latency`
- `ack delay vs latency/throughput`

#### 3.2 多播特性专项

这部分专门体现项目的核心贡献，而不是把多播混在普通单播里。

必须覆盖：

- `rectangle size sweep`
- `fanout sweep`
- `overlap degree sweep`
- `cross-tile multicast`
- `source inside / edge / corner / outside target rectangle`

新增建议指标：

- `total_network_flits`
- `multicast_delivery_efficiency = delivered_flits / total_network_flits`
- `completion_time_of_last_copy`
- `per_destination_tail_skew`
- `top_layer_load`

建议图表：

- `rectangle size vs completion latency`
- `rectangle size vs total network flits`
- `fanout vs throughput`
- `overlap degree vs congestion penalty`
- `cross-tile ratio vs completion latency`

#### 3.3 应用驱动流量

这部分参考用户提供的论文，补足“不是只有 synthetic traffic”的一块。

参考方向：

- 功能性 SNN traffic
- DVS/CNN 类事件流
- 控制消息 / 配置消息 / 状态消息等短消息流

建议新增 3 类 workload：

1. `SNN spike trace`
说明：
使用稀疏、事件驱动、强多播倾向的流量，模拟神经元 spike 传播。
动机：
`JETCAS 2024` 明确使用 functional spiking neural-network traffic 进行验证。

2. `DVS symbol / CNN trace`
说明：
使用局部密集、全局稀疏、存在 burst 的流量，模拟 DVS 输入驱动的分类工作负载。
动机：
`DYNAPs` 使用了 real-time classification of visual symbols flashed to a DVS。

3. `control-message traffic`
说明：
大量短包、低 payload、对端到端延迟更敏感，模拟配置和状态消息。
动机：
`IEEE Access 2024` 的异步 message bus 论文专门面向 control / configuration / status information。

建议 workload 级指标：

- `messages_per_second`
- `energy_proxy_per_message`
- `tail_completion_jitter`
- `zero-load_short_message_latency`
- `multicast_hit_ratio`
- `local_vs_global_traffic_ratio`

建议图表：

- `spike rate vs latency/throughput`
- `multicast fanout vs energy proxy`
- `control-message rate vs short-message latency`
- `local/global ratio vs top-layer utilization`

#### 3.4 物理和实现敏感性

这部分参考异步 NoC 和异步消息总线论文里的做法，补上“链路和实现条件变化时会怎样”。

必须覆盖：

1. `link distance / long-wire sensitivity`
说明：
观察链路长度增加时，head latency 和 throughput 的退化趋势。
动机：
`DATE 2013` 明确分析了 inter-switch distance 对 latency/cycle time 的影响。

2. `link pipelining sensitivity`
说明：
如果后续引入更细的异步 pipeline stage，评估 latency 和 throughput 的变化。
动机：
`DATE 2013` 讨论了 link pipelining 对 asynchronous latency 的影响。

3. `short-packet vs long-packet`
说明：
至少比较 `1 / 3 / 8 flit`。
动机：
`DATE 2013` 在 power analysis 中区分了 `3 flits` 和 `8 flits`。

4. `idle / hotspot / no-contention`
说明：
对齐异步交换和互连论文常见的三组条件。
动机：
`DATE 2013` 明确分析了 idle、hotspot、parallel benchmark。

建议图表：

- `link length vs head latency`
- `link length vs throughput`
- `pipeline stage count vs completion latency`
- `packet length vs power proxy`
- `idle / hotspot / parallel benchmark comparison`

#### 第 3 层推荐图表清单

如果目标是论文主结果，建议至少形成下列图：

- `uniform_unicast: offered load vs avg/p95 latency`
- `uniform_unicast: offered load vs throughput`
- `cross_tile_unicast: offered load vs throughput`
- `hotspot_unicast: offered load vs avg/p95 latency`
- `uniform_multicast: rectangle size vs completion latency`
- `uniform_multicast: rectangle size vs total network flits`
- `overlapping_multicast: overlap degree vs throughput`
- `ack delay sweep: ack delay vs completion latency`
- `SNN spike trace: spike rate vs throughput`
- `control-message trace: injection rate vs short-message latency`

#### 第 3 层落地要求

所有性能实验必须：

- 自动输出 CSV
- 支持 `seed`
- 支持 `warmup + measurement window`
- 支持 `256-node` 和 `1024-node`
- 明确记录 DUT 规模、traffic pattern、包长、矩形大小、并发数和 `ack delay`

当前基础脚本：

- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_tb.sv`
- `sim/modelsim/quadtree_and_mesh/run_perf_smoke.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf_suite.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf_rect_sweep.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf_ack_sweep.ps1`

### 第 4 层：baseline 对比

目的：

- 证明“原生矩形多播”比朴素方案更有效

最低要求 baseline：

- `baseline A`：一个矩形多播拆成多个单播

建议比较：

- 总网络 flit 数
- completion latency
- average latency
- saturation throughput
- 热点退化程度

建议图表：

- `native multicast vs replicated unicast: completion latency`
- `native multicast vs replicated unicast: total network traffic`
- `native multicast vs replicated unicast: throughput under load`

### 第 5 层：可扩展性与稳健性

目的：

- 证明结果不是单点偶然现象
- 展示规模变化和长时间运行下的趋势

建议覆盖：

- `256-node` 与 `1024-node`
- 多 seed
- 不同包长
- 不同矩形尺寸
- soak test

建议图表：

- `network size vs throughput`
- `network size vs latency`
- `packet length vs latency`
- `runtime duration vs error count`

## 统一实验规范

### 1. 每个实验都要写清楚变量

至少记录：

- DUT
- testbench
- 网络规模
- traffic pattern
- packet type
- packet length
- rectangle width / height
- offered load
- `ack delay`
- seed

### 2. 必须区分 warm-up 和 measurement

建议：

- 先 warm-up，再开始统计
- 同一张图中的所有点使用相同 measurement window

### 3. 每个点不要只跑一次

建议：

- 每个点至少多个 seed
- 论文图以均值为主
- 条件允许时附误差条

### 4. CSV 字段统一

建议最少包含：

- `dut`
- `tb`
- `network_nodes`
- `grid_x`
- `grid_y`
- `seed`
- `traffic_pattern`
- `packet_type`
- `packet_len`
- `rect_w`
- `rect_h`
- `offered_load`
- `ack_delay_ns`
- `avg_head_latency_ns`
- `p95_head_latency_ns`
- `p99_head_latency_ns`
- `avg_completion_latency_ns`
- `p95_completion_latency_ns`
- `p99_completion_latency_ns`
- `throughput_flit_per_ns`
- `delivered_packets`
- `delivered_flits`
- `total_network_flits`
- `drop_count`
- `duplicate_count`
- `misroute_count`
- `timeout_count`

### 5. 异步仿真的绝对时间只用于相对比较

本项目依赖异步握手和 `DelayElement` 模型，因此 RTL 仿真中的绝对 `ns` 更适合作为：

- 同一模型下的相对比较
- 设计版本之间的趋势对比

不要直接把 RTL 仿真里的绝对 `ns` 当作最终芯片结论。绝对面积、功耗和能耗结论应结合综合、P&R 或 FPGA 数据给出。

## 参考论文对第 3 层的补充映射

下面这些补充项直接来自用户提供论文的实验取向。

### 1. 面向异步 NoC 交换器和互连的基础性能项

来自：

- Ghiribaldi 等，`DATE 2013`，A transition-signaling bundled-data NoC switch architecture for cost-effective GALS multicore systems
- Bertozzi 等，`IEEE Micro 2021`，Cost-Effective and Flexible Asynchronous Interconnect Technology for GALS Systems

建议补充：

- `link length sweep`
- `link pipelining sweep`
- `idle / hotspot / parallel benchmark`
- `3-flit / 8-flit packet length comparison`
- `area efficiency` 或其 proxy

### 2. 面向神经形态多播的 workload 项

来自：

- Su 等，`JETCAS 2024`，An Ultra-Low Cost and Multicast-Enabled Asynchronous NoC for Neuromorphic Edge Computing
- Moradi 等，`TBCAS 2018`，DYNAPs

建议补充：

- `functional SNN traffic`
- `DVS / CNN style trace`
- `multicast fanout distribution`
- `local-vs-global neuromorphic traffic ratio`
- `application-level completion latency`

### 3. 面向短消息与控制流的延迟项

来自：

- Zeng 等，`IEEE Access 2024`，A Lightweight and High-Throughput Asynchronous Message Bus for Communication in Multi-Core Heterogeneous Systems

建议补充：

- `short-message zero-load latency`
- `control-message burst benchmark`
- `packet-level flow-control stress`
- `long-wire sensitivity`

## 论文最小仿真包

如果目标是一篇完整论文，建议至少准备这些结果：

- 第 1 层 directed regression 全通过
- 第 2 层随机正确性多 seed 全通过
- `uniform_unicast: offered load vs latency`
- `uniform_unicast: offered load vs throughput`
- `hotspot_unicast` 与 `cross_tile_unicast`
- `uniform_multicast: rectangle size vs completion latency`
- `uniform_multicast: rectangle size vs total network traffic`
- `native multicast vs replicated unicast`
- 至少一组 `SNN / DVS / control-message` 应用流量
- `256-node` 与 `1024-node` 至少一组规模对比

## 推荐实施顺序

1. 固化第 1 层，保持 directed regression 常绿
2. 完成第 2 层，多 seed 随机正确性常态化
3. 把第 3 层 synthetic traffic 跑完整
4. 补第 3 层的 workload-driven traffic
5. 进入第 4 层 baseline 对比
6. 最后补第 5 层规模和稳健性

## 文件组织建议

- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_rand_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_tb.sv`
- `sim/xsim/quadtree_and_mesh/run_rand.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf.ps1`
- `sim/results/simulation/raw/`
- `sim/results/simulation/csv/`
- `sim/results/simulation/figures/`

## 使用约定

- 如果只是改 RTL 并做快速检查，优先跑第 1 层
- 如果准备论文数据，至少完成第 1 到第 4 层
- `256-node` 主要用于验证
- `1024-node` 主要用于性能主结果

## 参考来源

- Ghiribaldi, Bertozzi, Nowick, “A Transition-Signaling Bundled Data NoC Switch Architecture for Cost-Effective GALS Multicore Systems,” DATE 2013  
  https://past.date-conference.com/proceedings-archive/2013/PDFFILES/04.2_1.PDF
- Bertozzi 等, “Cost-Effective and Flexible Asynchronous Interconnect Technology for GALS Systems,” IEEE Micro 2021  
  https://www.cs.columbia.edu/~nowick/
- Su 等, “An Ultra-Low Cost and Multicast-Enabled Asynchronous NoC for Neuromorphic Edge Computing,” IEEE JETCAS 2024  
  https://research.manchester.ac.uk/en/publications/an-ultra-low-cost-and-multicast-enabled-asynchronous-noc-for-neur/
- Moradi 等, “A Scalable Multicore Architecture With Heterogeneous Memory Structures for Dynamic Neuromorphic Asynchronous Processors (DYNAPs),” IEEE TBCAS 2018  
  https://ieee-cas.org/media/scalable-multicore-architecture-heterogeneous-memory-structures-dynamic-neuromorphic
- Zeng 等, “A Lightweight and High-Throughput Asynchronous Message Bus for Communication in Multi-Core Heterogeneous Systems,” IEEE Access 2024  
  https://www.mendeley.com/catalogue/7f7b851f-8e68-3299-aebd-5c5ce72b27b3/
