# 功耗、Batch Size 与基线对比补充指导

这份文档补充 `FINAL_EXPERIMENT_GUIDE_CN.md` 与 `SIMULATION_README.md` 中尚未完全展开的部分，重点回答 4 类问题：

- `batch_size` 与功耗、能耗、完成时间之间的关系如何定义和测量
- 本异步 NoC 与同步 counterpart 应如何做公平的功耗对比
- 当前层次化矩形多播算法应如何与“最初的四叉树多播算法”做对照
- 对“向一个矩形区域多播”这类场景，应该输出哪些时间类和能耗类指标

如果后续只是补脚本或画图，请优先遵守本文件中的变量定义、CSV 字段命名和 baseline 名称。

## 1. 基本原则

- 功耗结论分成 `activity proxy`、实现后功耗、板级功耗 3 个层次，不要把它们混成一个数字
- 如果当前阶段还没有同步版 RTL 或原始四叉树 baseline 的完整实现，可以先固定比较口径和 CSV 字段，再逐步补实现
- 功耗比较必须与“完成了多少有效工作”绑定，不能只比较一个固定时间窗口内的平均功耗
- 对多播场景，必须同时报告 `时间` 和 `能耗`，否则很容易出现“更快但更耗能”或“更省能但拖慢批处理”的误判

## 2. 功耗测量分层

### 2.1 RTL activity proxy

这是当前仓库最容易先落地的一层，适合先做趋势分析和算法对比。

推荐从 RTL 仿真中提取这些活动量：

- `injected_flits`
- `delivered_flits`
- `delivered_packets`
- `boundary_head_count`
- `boundary_tail_count`
- `unexpected_top_flits`
- `top_layer_flit_hops`
- `tree_upward_copies`
- `duplicate_head_copies`
- `packet_residency_time_ns`

推荐定义：

- `energy_proxy = w_core_rx * core_rx_flits + w_top * top_layer_flit_hops + w_up * tree_upward_copies + w_hold * packet_residency_time_ns`
- `energy_proxy_per_delivered_packet = energy_proxy / delivered_packets`
- `energy_proxy_per_destination = energy_proxy / delivered_destinations`

说明：

- `w_*` 不需要一开始就有物理单位，可以先统一设为 `1` 做无量纲比较
- 如果后续拿到 SAIF/VCD 和实现后功耗结果，可以再反推或拟合这些权重
- 只要同一组图里权重保持一致，`energy proxy` 就可以支持趋势对比

### 2.2 综合或布局布线后的功耗

如果要写论文里的“绝对功耗”或“能量/包”结论，建议使用这一层。

最低要求：

- 异步设计与同步 baseline 使用同一工艺、同一器件或同一 FPGA 族
- 两边都使用同类激励文件，例如同一份 VCD、SAIF 或等价活动统计
- 两边都在相同 `packet_len`、相同 traffic pattern、相同 `batch_size` 下评估

推荐输出：

- `avg_power_mw`
- `dynamic_power_mw`
- `static_power_mw`
- `batch_energy_nj`
- `energy_per_delivered_packet_nj`
- `energy_per_destination_nj`
- `EDP`
- `ED2P`

建议公式：

- `batch_energy_nj = avg_power_mw * batch_completion_time_ns / 1e6`
- `energy_per_delivered_packet_nj = batch_energy_nj / delivered_packets`
- `energy_per_destination_nj = batch_energy_nj / delivered_destinations`
- `EDP = batch_energy_nj * batch_completion_time_ns`

### 2.3 板级或系统级功耗

这一层适合补最终 demo 或 FPGA 实验，不建议替代前两层。

可选输出：

- `board_power_idle_mw`
- `board_power_active_mw`
- `incremental_active_power_mw`
- `energy_per_inference_uJ`
- `energy_per_batch_uJ`

## 3. Batch Size 与功耗

### 3.1 这里的 batch size 应如何定义

建议把 `batch_size` 固定定义为：

- 一次应用级释放中，连续注入到网络中的 `message` 或 `packet` 数量

为了避免歧义，建议区分 2 种模式：

- `source_local_batch`：每个源节点一次性释放 `B` 个包，包内间隔很小，批次之间有较大间隔
- `global_step_batch`：多个源在同一个“应用步”里同时各释放 `B` 个包，更接近 SNN/DVS/CNN 中的一次事件窗口或一次 mini-batch

### 3.2 batch size 扫描建议

推荐首先固定：

- `packet_len = 3 flits`
- `batch_size = 1, 2, 4, 8, 16, 32`
- `inter_packet_gap_ns = 0` 或 `1`
- `inter_batch_gap_ns = 200` 或更大，用来清空前一批残余拥塞
- `warmup_ns = 0`，`measure` 改为按“批处理完成”统计

如果仍想与当前性能脚本保持一致，也可以保留 `warmup_ns / measure_ns`，但建议额外输出：

- `batch_completion_time_ns`
- `batch_tail_completion_jitter_ns`
- `batch_energy_nj`

### 3.3 batch size 相关的图表

最少建议补 4 张图：

- `batch_size vs avg_power_mw`
- `batch_size vs energy_per_delivered_packet_nj`
- `batch_size vs batch_completion_time_ns`
- `batch_size vs EDP`

如果做多播 workload，再加：

- `batch_size vs energy_per_destination_nj`
- `batch_size vs multicast_completion_time_ns`

### 3.4 结果解读建议

- `avg_power` 可能随着 `batch_size` 增大而上升，但 `energy_per_packet` 可能下降，因为固定启动开销被摊薄
- 如果 `batch_size` 增大后 `completion_time` 急剧上升，而功耗也没有明显下降，说明系统已经进入拥塞主导区
- 异步 NoC 可能在低负载或 bursty workload 下有更低空闲开销，但在高并发大 batch 下需要用 `energy per useful work` 来判断是否真的占优

## 4. 异步 NoC vs 同步 counterpart

### 4.1 公平性约束

同步 counterpart 必须尽量满足以下约束：

- 相同网络规模，例如都用 `1024-node`
- 相同拓扑优先级：先保持 `quadtree + top mesh`，做不到时再退化为相同节点数和相近层次结构
- 相同包格式：统一 `3-flit`
- 相同 traffic pattern、相同 `seed`
- 相同 `batch_size`
- 相同目的集合与多播语义
- 相同统计口径

### 4.2 推荐的两种公平比较方式

建议不要只做一种比较，最好同时给出：

- `same offered load`：横轴对齐输入负载，看谁更省能、更快饱和
- `same useful work`：固定同样数量的 delivered packets 或同样一个 batch，看谁完成得更快、更省能

对于同步设计和异步设计 `Fmax` 不同的情况，建议同时报告：

- 归一化到 `ns` 的结果
- 归一化到“每次完成同样工作量”的 `energy per useful work`

### 4.3 最少比较指标

- `zero-load latency`
- `avg / p95 / p99 latency`
- `avg_completion_latency_ns`
- `throughput_flit_per_ns`
- `saturation point`
- `avg_power_mw`
- `batch_energy_nj`
- `energy_per_delivered_packet_nj`
- `EDP`
- `LUT / FF / BRAM`
- `Fmax`

### 4.4 最少 workload

同步 counterpart 至少建议覆盖：

- `uniform_unicast`
- `cross_tile_unicast`
- `hotspot_unicast`

如果同步版也支持矩形多播，再补：

- `uniform_multicast`
- `mixed_unicast_multicast`

如果同步版暂时不支持原生矩形多播：

- 单播性能和功耗仍然要做
- 多播部分单独与 `replicated_unicast` 和 `original_quadtree` 算法 baseline 对照

## 5. 算法 baseline：当前设计 vs 原始四叉树多播算法

### 5.1 当前设计的算法特征

当前实现不是“见到矩形就无脑复制”的做法，而是两段式层次化策略：

- 在 quadtree 中，先对当前 tree 裁剪矩形，再按本层投影决定向哪些 child 复制
- 只有当当前 subtree 只覆盖了目标矩形的一部分时，才保留一份向上继续传播的副本
- 到 top mesh 后，先向离矩形最近的 tile 角点单路径靠近，再在目标 tile 矩形内部展开

相关代码位置：

- `src/main/scala/Router_Architecture/algorithm/RoutingLogic_quadtree.scala`
- `src/main/scala/Router_Architecture/algorithm/RoutingLogic_top_layer.scala`

### 5.2 建议定义的“原始四叉树多播算法” baseline

如果你想和“最初的四叉树多播算法”比较，建议先把 baseline 语义固定为：

- 在每一层四叉树结点，只要目标矩形与多个 child 象限相交，就立即复制到所有相交 child
- 不做当前实现中的“局部裁剪后再决定是否保留向上副本”的优化
- 对跨 tile 矩形，按每个目标 tile 或每个相交高层子树分别递归展开，不使用 top-layer 最近角点单路径导入和矩形内展开

这样定义的 baseline 很适合作为“算法层”的对照，因为它能突出当前设计里这两点优化：

- `局部裁剪 + 必要时才向上带副本`
- `进入目标 tile 后再展开，而不是更早大范围复制`

### 5.3 与算法 baseline 的比较指标

- `total_network_flits`
- `top_layer_flit_hops`
- `tree_upward_copies`
- `duplicate_head_copies`
- `avg_completion_latency_ns`
- `batch_completion_time_ns`
- `energy_proxy`
- `energy_per_destination`
- `EDP`

### 5.4 推荐图表

- `rect_size vs total_network_flits`
- `rect_size vs energy_proxy_per_destination`
- `rect_size vs avg_completion_latency_ns`
- `source_position_class vs completion_latency`
- `rect_aspect_ratio vs energy_proxy`

## 6. 矩形多播的时间与功耗分析

### 6.1 必做维度

对“向一个矩形多播”的分析，建议至少扫以下维度：

- `rect_size = 1, 2, 4, 8, 16`
- `rect_aspect_ratio = 1x16, 2x8, 4x4, 8x2, 16x1`
- `source_position_class = inside / edge / corner / outside`
- `same_tile / cross_tile / multi_tile`
- `batch_size = 1, 2, 4, 8, 16`

### 6.2 必做指标

- `avg_completion_latency_ns`
- `p95_completion_latency_ns`
- `batch_completion_time_ns`
- `delivered_flits`
- `delivered_destinations`
- `energy_proxy`
- `energy_per_destination`
- `energy_per_rectangle`
- `EDP`

### 6.3 重点对照组合

建议至少做这 3 组对照：

- `native multicast` vs `replicated unicast`
- `native multicast` vs `original_quadtree_recursive`
- `asynchronous native multicast` vs `synchronous counterpart multicast`

### 6.4 建议的结论写法

如果暂时没有实现后绝对功耗，不建议写“功耗降低了 X%”这种绝对结论，建议写：

- `energy proxy` 降低
- `per-destination traffic` 降低
- `same batch size 下 completion time 更短`
- `same useful work 下 EDP 更优`

## 7. CSV 字段补充

建议在现有性能 CSV 基础上新增这些字段：

- `batch_size`
- `batch_mode`
- `inter_batch_gap_ns`
- `power_method`
- `avg_power_mw`
- `dynamic_power_mw`
- `static_power_mw`
- `batch_energy_nj`
- `energy_proxy`
- `energy_proxy_per_delivered_packet`
- `energy_per_delivered_packet_nj`
- `energy_per_destination_nj`
- `EDP`
- `ED2P`
- `algorithm_baseline`
- `source_position_class`
- `rect_aspect_ratio`
- `top_layer_flit_hops`
- `tree_upward_copies`
- `duplicate_head_copies`
- `delivered_destinations`
- `batch_completion_time_ns`

推荐命名：

- `algorithm_baseline = native_multicast | replicated_unicast | original_quadtree_recursive | sync_counterpart`
- `power_method = rtl_proxy | post_synth | post_route | board`

## 8. 文件与脚本组织建议

如果后续开始补脚本，建议新增这些入口：

- `sim/xsim/quadtree_and_mesh/run_perf_batch_sweep.ps1`
- `sim/xsim/quadtree_and_mesh/run_power_proxy_suite.ps1`
- `sim/xsim/quadtree_and_mesh/run_algo_baseline_rect_sweep.ps1`
- `sim/xsim/quadtree_and_mesh/run_sync_baseline_suite.ps1`

建议新增这些目录：

- `baseline_sync/`
- `baseline_algo/`
- `sim/results/simulation/csv/power/`
- `sim/results/simulation/raw/power/`
- `sim/results/implementation/power/`

如果当前阶段还不写脚本，建议先完成这 3 件事：

- 固定 `batch_size` 的定义
- 固定 `algorithm_baseline` 的枚举值
- 固定功耗 CSV 字段名称

## 9. 当前最值得先补的最小集

如果你现在只想快速把论文实验补完整，而不是一次性做大而全，推荐先做下面这组最小集：

- `uniform_unicast`：`batch_size vs avg_power_mw / energy_per_delivered_packet_nj`
- `uniform_multicast`：`rect_size vs avg_completion_latency_ns / energy_proxy_per_destination`
- `native multicast` vs `replicated unicast`
- `native multicast` vs `original_quadtree_recursive`
- `asynchronous` vs `synchronous counterpart` 的 `uniform_unicast` 和 `cross_tile_unicast`

这样做的好处是：

- 能先把功耗和 batch size 的故事讲完整
- 能把原生矩形多播的算法贡献讲清楚
- 即使同步版多播尚未完全打通，仍然能先形成一版可信的对比框架
