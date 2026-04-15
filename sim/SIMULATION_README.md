# Simulation README

这份文档定义了本项目后续仿真的标准做法。目标不是只让 RTL “能跑通”，而是把仿真工作整理成一套能支撑论文或毕业设计答辩的实验体系。后续新增测试、性能脚本、数据统计和图表，都建议按这里的分层推进。

## 目标

这套仿真流程需要回答 4 个问题：

- 设计是否正确，是否会丢包、重包、误投递或打乱 flit 顺序
- 在竞争、背压和长期运行下是否稳定
- 原生矩形多播相比 baseline 是否更有效率
- 网络规模、矩形大小、流量模式变化时，性能趋势是什么

## 当前仓库已经具备的基础

现有仓库已经覆盖了比较强的定向功能回归：

- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`
- `sim/testbenches/toplayer_mesh/toplayer_mesh_tb.sv`
- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`

现有脚本入口：

- `sim/xsim/three_level_quadtree/launch.ps1`
- `sim/xsim/quadtree_and_mesh/launch.ps1`
- `sim/xsim/toplayer_mesh/launch.ps1`
- `sim/xsim/three_level_quadtree/throughput_3flit.tcl`

这些内容已经足够构成“功能正确性验证”的基础，但距离论文级实验还缺：

- 约束随机验证
- 系统级性能扫点
- baseline 对比
- 可扩展性和稳健性统计
- 统一 CSV 结果输出和图表规范

## 分层仿真方案

后续仿真按 5 层推进。

### 第 1 层：定向功能回归

目的：

- 保证已有关键路径一直正确
- 给后续性能和随机实验提供最基础的回归门槛

必须覆盖的内容：

- 同 tree 单播
- 跨 tree 单播
- 矩形多播
- 跨 tile 矩形多播
- 边界翻转归一化
- 多包竞争
- 热点背压
- top-layer 单独路由正确性

当前对应文件：

- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`
- `sim/testbenches/toplayer_mesh/toplayer_mesh_tb.sv`

后续要求：

- 每次改动路由、复制、仲裁、异步握手逻辑后，先跑这层
- 这层必须是 CI/日常回归的第一关

通过标准：

- 所有 directed case 通过
- 不允许有 timeout、unexpected traffic、duplicate delivery、packet interleaving

### 第 2 层：约束随机正确性验证

目的：

- 证明设计不是只在手写场景下正确
- 用大量随机场景发现遗漏的角落问题

建议随机维度：

- 源节点
- 单播或矩形多播
- 矩形宽度和高度
- 包长
- 注入间隔
- 并发流数量
- sink `ack delay`
- 热点位置和热点强度

必须检查的内容：

- 目标集合是否完全正确
- 是否有丢包
- 是否有重复投递
- 是否有误投递
- 包内 flit 顺序是否保持
- body/tail 是否沿用 head 分配的 lane
- 是否发生死锁或长时间不前进

推荐实现方式：

- 新增独立的随机/统计 testbench，不要把大规模随机逻辑继续堆进现有 directed testbench
- 引入 scoreboard，先算“理论应该送达的节点集合”，再和“实际收到集合”比对
- 每个实验至少支持 `seed` 参数

建议新增文件：

- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_rand_tb.sv`
- `sim/xsim/quadtree_and_mesh/run_rand.ps1`

通过标准：

- 多个 seed 下无功能错误
- 统计结果中 `drop_count = 0`
- `duplicate_count = 0`
- `misroute_count = 0`
- `timeout_count = 0`

### 第 3 层：性能评估

目的：

- 形成论文中的核心性能图
- 回答“这个结构快不快、何时饱和、在哪些场景下有优势”

建议扫的自变量：

- offered load
- 流量模式
- 包长
- 矩形大小
- 并发流数量
- 背压延迟
- 是否跨 tile

建议流量模式：

- uniform random
- hotspot
- local traffic
- cross-tile traffic
- pure unicast
- pure multicast
- mixed unicast + multicast
- overlapping multicast

至少统计这些指标：

- average latency
- p95 latency
- p99 latency
- accepted throughput
- delivered packets
- delivered flits
- completion latency
- top-layer traffic volume
- per-tile receive throughput

建议图表：

- `offered load vs average latency`
- `offered load vs throughput`
- `rectangle size vs completion latency`
- `rectangle size vs total delivered flits`
- `ack delay vs latency/throughput`

当前仓库可复用的基础：

- `sim/xsim/three_level_quadtree/throughput_3flit.tcl`

后续要求：

- 把统计思路扩展到 `quadtree_and_mesh` 顶层，而不是停留在单 tile
- 所有性能实验自动导出 CSV，不依赖手抄控制台输出

建议新增文件：

- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_tb.sv`
- `sim/xsim/quadtree_and_mesh/run_perf.ps1`
- `sim/results/simulation/`

### 第 4 层：baseline 对比

目的：

- 证明“原生矩形多播”比朴素方案更有价值
- 给论文贡献点提供量化证据

最低要求 baseline：

- `baseline A`: 把一个矩形多播拆成多个单播包

如果时间足够，再做：

- `baseline B`: 简化的纯 mesh 策略
- `baseline C`: 简化的纯 tree 策略

至少对比这些指标：

- 总网络 flit 数
- completion latency
- average latency
- throughput saturation point
- 热点场景下的退化程度

论文里最适合的图：

- `multicast size vs total network traffic`
- `multicast size vs completion latency`
- `offered load vs throughput` for native multicast vs replicated unicast

### 第 5 层：可扩展性与稳健性

目的：

- 让结果不只是一组点，而是形成趋势
- 证明网络在更大规模、更长运行时间下仍稳定

建议覆盖：

- 单 tile、`2x2` tile、后续更大 mesh
- 不同包长
- 不同矩形尺寸
- 不同 seed
- soak test

soak test 建议：

- 长时间随机流量持续运行
- 每次实验记录是否出现 deadlock、livelock 或统计计数异常

论文里可以形成：

- `network size vs latency`
- `network size vs throughput`
- `packet length vs latency`
- `runtime duration vs error count`

## 统一实验规范

后续所有论文仿真都尽量遵守下面这些规则。

### 1. 每组实验必须写清楚变量

每条结果都要明确：

- DUT
- testbench
- traffic pattern
- packet type
- packet length
- rectangle width and height
- offered load
- ack delay
- seed

### 2. 每组实验必须分 warm-up 和 measurement window

建议：

- 先 warm-up，再开始计数
- measurement window 固定长度
- 同一张图里的所有点用一致的 window 规则

### 3. 每个点不要只跑一次

建议：

- 每个点至少跑多个 seed
- 画均值
- 条件允许时加误差条

### 4. 输出格式统一成 CSV

建议字段：

- `dut`
- `tb`
- `seed`
- `traffic_pattern`
- `packet_type`
- `packet_len`
- `rect_w`
- `rect_h`
- `offered_load`
- `ack_delay_ns`
- `avg_latency_ns`
- `p95_latency_ns`
- `p99_latency_ns`
- `throughput_flit_per_ns`
- `delivered_packets`
- `delivered_flits`
- `drop_count`
- `duplicate_count`
- `misroute_count`
- `timeout_count`

### 5. 异步时间结果只用于同一模型下的相对比较

本项目依赖异步握手和 `DelayElement` 模型，因此 RTL 仿真里的绝对 `ns` 更适合作为：

- 同一建模前提下的相对性能比较
- 设计版本之间的趋势对比

不要直接把 RTL 仿真里的绝对 `ns` 当作最终芯片级结论。论文里应把这一点写清楚。

## 论文最低仿真包

如果目标是一篇完整论文，建议至少准备下面这些结果。

### 必须有的结果

- 定向功能回归通过
- 随机正确性验证通过
- `offered load vs latency`
- `offered load vs throughput`
- `multicast size vs completion latency`
- `multicast size vs total traffic`
- native multicast vs replicated unicast 对比
- 至少一组背压/热点退化实验

### 最好有的结果

- 多 seed 误差条
- 长时间 soak test
- 不同网络规模趋势图
- 不同包长趋势图

## 推荐实施顺序

建议按下面顺序推进，避免一开始就把精力花在图表脚本上。

1. 先固化第 1 层，把 directed regression 当成日常门槛
2. 再完成第 2 层，先把随机正确性做扎实
3. 然后单独搭第 3 层性能 testbench 和 CSV 输出
4. 在第 3 层稳定之后，再做第 4 层 baseline 对比
5. 最后补第 5 层的长时间和可扩展性实验

## 后续文件组织建议

建议把论文向仿真资产逐步整理成下面这种结构：

- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_rand_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_tb.sv`
- `sim/xsim/quadtree_and_mesh/run_rand.ps1`
- `sim/xsim/quadtree_and_mesh/run_perf.ps1`
- `sim/results/simulation/raw/`
- `sim/results/simulation/csv/`
- `sim/results/simulation/figures/`

## 使用约定

以后如果只是改 RTL 并做快速检查，优先跑第 1 层。  
如果是准备论文数据或正式阶段性结果，必须按这份文档至少完成第 1 到第 4 层，再考虑进入 FPGA 原型验证。
