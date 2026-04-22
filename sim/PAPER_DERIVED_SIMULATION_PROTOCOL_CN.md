# 论文参考下的仿真初始设定与执行流程

这份文档把当前项目后续论文仿真里“初始设定应该怎么定、每类实验应该怎么跑、哪些设定是直接来自参考论文、哪些是为了适配当前仓库做的工程归一化”统一写清楚。

它不是替代 `FINAL_EXPERIMENT_GUIDE_CN.md` 和 `SIMULATION_README.md`，而是把它们背后的论文依据和更具体的执行过程补全。

建议使用顺序：

- 日常脚本入口与目录说明：`sim/README.md`
- 项目总方法学与实验分层：`sim/SIMULATION_README.md`
- 最终论文口径与最小结果集：`sim/FINAL_EXPERIMENT_GUIDE_CN.md`
- 功耗、batch size、同步 baseline、公平性约束：`sim/POWER_AND_BASELINE_GUIDE_CN.md`
- 论文依据下的初始设定和逐步流程：本文档

## 1. 文档范围与口径说明

本文档覆盖 4 类内容：

- `switch-level` 与 `network-level` 仿真的初始设定
- synthetic、multicast、workload-driven、功耗与 baseline 对比的具体流程
- 当前仓库命令如何对应到文献里的实验结构
- 哪些参数是直接来自论文，哪些是针对本仓库的统一化设定

为了避免“看起来像在复现论文，实际上口径不一致”的问题，本文档统一使用两个标签：

- `[论文直接参考]`：论文中明确给出或能直接读出的设定
- `[工程归一化]`：为了对齐当前仓库脚本、统一 CSV 字段或补齐缺失流程而做的固定约定

## 2. 参考论文与各自提供的实验启发

### 2.1 异步 NoC 与 GALS 基础性能

- A. Ghiribaldi, D. Bertozzi, S. M. Nowick, “A Transition-Signaling Bundled Data NoC Switch Architecture for Cost-Effective GALS Multicore Systems,” DATE 2013.
  - 可公开访问版本：<https://past.date-conference.com/proceedings-archive/2013/PDFFILES/04.2_1.PDF>
  - 提供了 `5x5 switch`、`32-bit flit`、`wormhole`、`dimension-order routing`、`head latency`、`cycle time`、`link length`、`link pipelining`、`3/8 flit packet`、`idle/hotspot/parallel`、`post-layout power` 的标准评测结构。
- D. Bertozzi et al., “Cost-Effective and Flexible Asynchronous Interconnect Technology for GALS Systems,” IEEE Micro 41(1), 2021.
  - DOI：<https://doi.org/10.1109/MM.2020.3002790>
  - 公开摘要与项目说明：<https://www.cs.columbia.edu/~nowick/>
  - 给出了“完整异步 NoC 设计方法学 + 同步 counterpart 公平对比 + full-HD video playback application projection + 14nm 工业 router apples-to-apples 对比”的总体框架。

### 2.2 神经形态通信与多播

- Z. Su et al., “An Ultra-Low Cost and Multicast-Enabled Asynchronous NoC for Neuromorphic Edge Computing,” IEEE JETCAS, 2024.
  - DOI：<https://doi.org/10.1109/JETCAS.2024.3433427>
  - 公开全文入口：<https://www.researchgate.net/publication/382576972_An_Ultra-Low_Cost_and_Multicast-Enabled_Asynchronous_NoC_for_Neuromorphic_Edge_Computing>
  - 直接提供了 `single-flit spike packet`、`3x3 mesh`、`NAV/KWS RSNN`、`40/512 input neurons`、`512 ALIF recurrent layer`、`top-left injection`、`bottom-right readout`、`sparsity sweep = 10/20/40/80/100%`、`six update frequencies`、`native multicast vs replicated unicast` 这类关键设定。
- S. Moradi et al., “A Scalable Multicore Architecture With Heterogeneous Memory Structures for Dynamic Neuromorphic Asynchronous Processors (DYNAPs),” IEEE TBioCAS, 2018.
  - DOI：<https://doi.org/10.1109/TBCAS.2017.2759700>
  - 可公开获取的摘要页：<https://pubmed.ncbi.nlm.nih.gov/29377800/>
  - 说明了 `hierarchical + mesh routing` 的神经形态通信背景，并给出 `DVS visual symbol classification` 这类真实 workload 的使用方式。
- Z. Su et al., “An Efficient Multicast Addressing Encoding Scheme for Multi-Core Neuromorphic Processors,” ISCAS 2025.
  - DOI：<https://doi.org/10.1109/ISCAS56072.2025.11043591>
  - 开放元数据与 arXiv 入口：<https://www.research-collection.ethz.ch/handle/20.500.11850/716601>
  - 说明应补 `address encoding / multicast algorithm` 层面的 baseline，而不仅仅是电路实现级 baseline。

### 2.3 短消息与控制流

- Q. Zeng et al., “A Lightweight and High-Throughput Asynchronous Message Bus for Communication in Multi-Core Heterogeneous Systems,” IEEE Access, 2024.
  - DOI：<https://doi.org/10.1109/ACCESS.2024.3380477>
  - 开放摘要页：<https://www.mendeley.com/catalogue/7f7b851f-8e68-3299-aebd-5c5ce72b27b3/>
  - 直接支持把 `control / configuration / status` 消息单独作为 workload 类别，并强调 `quasi-synchronous fixed-interval flit injection`、`packet-level flow control`、`long-wire latency`。

### 2.4 大规模 GALS 神经形态系统

- Y. Zhong et al., “PAICORE: A 1.9-Million-Neuron 5.181-TSOPS/W Digital Neuromorphic Processor With Unified SNN-ANN and On-Chip Learning Paradigm,” IEEE JSSC, 2025.
  - DOI：<https://doi.org/10.1109/JSSC.2024.3426319>
  - 公开摘要页：<https://m.booksci.cn/literature/141857683.htm>
  - 明确了 `1024-core`、`GALS`、`five-level fat up-down quadtree NoC`、`equivalent simulation and programming` 的大型系统背景，可直接支撑本仓库固定 `1024-node` 为论文主结果规模。

## 3. 统一初始设定

### 3.1 网络规模

- `[论文直接参考]` DYNAPs 强调小中规模多核神经形态处理器；JETCAS 2024 使用 `3x3 mesh` 映射 workload；PAICORE 2025 采用 `1024-core` GALS + fat-tree/quadtree 风格 NoC。
- `[工程归一化]` 当前项目固定两档规模：
  - `256-node`：正确性回归、脚本打通、单点 smoke
  - `1024-node`：论文主结果、baseline、公平对比、batch/power/workload 结果

结论：

- 所有“写进论文的曲线或表格”默认走 `1024-node`
- `256-node` 不再作为最终结论，只作为前置验证规模

### 3.2 仿真器与执行模式

- `[论文直接参考]` DATE 2013 与 JETCAS 2024 都强调 post-layout / realistic timing / actual handshake，而不是理想化抽象模型。
- `[工程归一化]`
  - `256-node`：可用 `ModelSim` 或 `xsim`
  - `1024-node`：默认 `xsim batch`
  - GUI 仅用于调试，不用于正式扫点

### 3.3 包格式

- `[论文直接参考]`
  - JETCAS 2024 主打 `single-flit spike packet`
  - DATE 2013 明确比较 `3 flits` 与 `8 flits`
  - Zeng 2024 面向 short message/control message，强调小包和 packet-level flow control
- `[工程归一化]`
  - 主线口径保持当前仓库 `packet_len = 3 flits`
  - 补充两个敏感性分支：
    - `1 flit`：对应 spike/control short message
    - `8 flits`：对应 DATE 2013 的 packet-length sensitivity

固定要求：

- 主论文横向比较默认先用 `3 flits`
- 所有涉及短消息优势、控制流优势、单 flit multicast 优势的图，必须补 `1 flit`
- 所有涉及 packet-length 影响、功耗代理或链路流水的图，建议补 `8 flit`

### 3.4 时间窗口与 seeds

- `[论文直接参考]` DATE 2013 使用明确的 latency / cycle-time / power benchmark；JETCAS 2024 在 workload 里按 inference trace、sparsity 和 update frequency 扫描。
- `[工程归一化]`
  - `seeds = 12345, 22345, 32345`
  - synthetic/multicast 默认：
    - `warmup_ns = 20000`
    - `measure_ns = 50000`
  - workload-driven trace 默认：
    - 不再只看固定 measurement window
    - 必须补 `per-inference` 或 `per-batch` 完成时间

### 3.5 默认 sweep 维度

- `[工程归一化]`
  - `packet_gap_ns = 0, 10, 20, 40`
  - `ack_delay_ns = 1, 5, 10, 20`
  - `rect_size = 1, 2, 4, 8, 16`
  - `batch_size = 1, 2, 4, 8, 16, 32`
  - `sparsity = 10%, 20%, 40%, 80%, 100%`
  - `update_frequency`：固定 6 个点

## 4. 仿真分层与具体流程

### 4.1 第 0 步：DUT 与目录准备

固定命令：

```powershell
sbt "runMain NoC.quadtree_and_mesh --verify-256"
sbt "runMain NoC.quadtree_and_mesh --paper-1024 --target-dir generated_1024"
```

固定目录：

- 原始日志：`sim/results/simulation/raw/`
- 汇总 CSV：`sim/results/simulation/csv/`
- 图表输出：`sim/results/simulation/figures/`
- 实现后功耗：`sim/results/implementation/power/`

固定要求：

- 同一轮论文实验不要混用 `generated/` 与 `generated_1024/`
- 同一轮论文曲线里，DUT 版本必须一致

### 4.2 第 1 步：正确性闸门

先做 directed regression，再做 constrained-random correctness。只有通过后，后续性能和功耗结果才算有效。

推荐命令：

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_rand_suite.ps1 -Cases 24 -MaxPkts 3
```

通过标准：

- 无 `timeout`
- 无 `unexpected traffic`
- 无误投递 / 重复投递 / 丢包
- 所有 seed 均 `PASS`

### 4.3 第 2 步：switch-level 基础微基准

这一层主要来自 DATE 2013，用来给异步/同步 baseline 与链路敏感性建立统一定义。

#### 初始设定

- `[论文直接参考]`
  - `5x5 switch`
  - `32-bit flit width`
  - `wormhole switching`
  - `algorithmic dimension-order routing`
  - latency 定义为：输入端 request 置位到输出端 request 置位
  - cycle time 定义为：输出端连续两次 acknowledgment 的间隔
  - injector/absorber 用同类 switch 实例闭环相连，提供真实握手与最大注入速率
  - `40nm low-power standard-Vt, 1.2V, 300K`
  - power benchmark：`leakage / idle / hotspot / parallel`
  - packet length：`3 / 8 flits`

#### 当前仓库中的工程映射

- `[工程归一化]` 当前仓库默认以 system-level testbench 为主，还没有独立的 5x5 router-only 论文脚本。
- 若需要严格补齐，应新增：
  - `sim/testbenches/router_switch/`
  - `sim/xsim/router_switch/run_link_sweep.ps1`
  - `sim/xsim/router_switch/run_power_bench.ps1`

#### 必跑项目

- ideal link 下：
  - `head latency`
  - `cycle time`
  - `throughput`
  - `area efficiency`
- unpipelined link distance sweep
- pipelined link distance sweep
- power benchmark：
  - `leakage`
  - `idle`
  - `hotspot`
  - `parallel`

### 4.4 第 3 步：system-level synthetic traffic

这一层对应当前仓库已有 `run_perf.ps1`、`run_perf_suite.ps1`、`run_perf_rect_sweep.ps1`、`run_perf_ack_sweep.ps1`。

#### 固定初始设定

- `[工程归一化]`
  - `1024-node`
  - `xsim batch`
  - `packet_len = 3 flits`
  - `seeds = 12345,22345,32345`
  - `warmup_ns = 20000`
  - `measure_ns = 50000`

#### 必跑 traffic pattern

- `uniform_unicast`
- `local_unicast`
- `cross_tile_unicast`
- `hotspot_unicast`
- `uniform_multicast`
- `mixed_unicast_multicast`
- `overlapping_multicast`

#### 命令模板

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

#### 固定输出

- `avg_latency_ns`
- `p95_latency_ns`
- `p99_latency_ns`
- `avg_completion_latency_ns`
- `p95_completion_latency_ns`
- `p99_completion_latency_ns`
- `injected_flit_per_ns`
- `throughput_flit_per_ns`
- `injected_packets`
- `delivered_packets`
- `boundary_head_count`
- `boundary_tail_count`
- `pending_packets`

### 4.5 第 4 步：矩形多播专项

这一层同时参考当前项目目标、JETCAS 2024 的 native multicast 论证思路、以及编码论文中“多播地址/路由方案要和真实任务结合”这一点。

#### 固定初始设定

- `pattern = uniform_multicast`
- `num_flows = 1`
- `rect_w = rect_h`
- `rect_size = 1, 2, 4, 8, 16`
- `ack_delay_ns = 1, 5, 10, 20`

#### 必补分析维度

- `rect_size sweep`
- `ack_delay sweep`
- `source_position_class = inside / edge / corner / outside`
- `cross_tile_ratio`
- `rect_aspect_ratio`

#### 必补 baseline

- `native multicast`
- `replicated unicast`
- `original_quadtree_recursive`

#### 最低图表

- `rect_size vs avg_completion_latency_ns`
- `rect_size vs throughput_flit_per_ns`
- `rect_size vs delivered_flits`
- `rect_size vs energy_proxy_per_destination`

### 4.6 第 5 步：batch size 与功耗/能耗

这一步主要吸收 PAICORE 的大规模部署视角、JETCAS 的 neuromorphic real-task 视角，以及 `POWER_AND_BASELINE_GUIDE_CN.md` 中的能耗代理口径。

#### 固定初始设定

- `[工程归一化]`
  - `batch_size = 1,2,4,8,16,32`
  - `inter_packet_gap_ns = 0 或 1`
  - `inter_batch_gap_ns = 200`
  - synthetic 仍保留固定 `warmup/measure`
  - workload 则改为 `per-batch completion`

#### 必补指标

- `batch_completion_time_ns`
- `avg_power_mw`
- `batch_energy_nj`
- `energy_per_delivered_packet_nj`
- `energy_proxy`
- `EDP`

#### 执行顺序

1. 在固定 `traffic pattern` 下扫 `batch_size`
2. 在固定 `batch_size` 下扫 `packet_gap_ns`
3. 对 `native multicast` 与 `replicated unicast` 重复以上扫描
4. 如果有同步 counterpart，再做相同 sweep

### 4.7 第 6 步：workload-driven trace

这一层是把 DYNAPs、JETCAS 2024、Zeng 2024、PAICORE 2025 的“真实任务驱动”视角统一落地。

#### A. NAV / KWS 风格 RSNN trace

- `[论文直接参考]` JETCAS 2024：
  - `three-layer RSNN`
  - `40` input neurons for NAV
  - `512` input neurons for KWS
  - `512 ALIF` recurrent neurons
  - `3x3 mesh`
  - input spikes injected from top-left
  - outputs mapped to bottom-right core
  - `sparsity = 10/20/40/80/100%`
  - six update frequencies

- `[工程归一化]`
  - 当前仓库不必机械复制 `3x3 mesh`
  - 统一映射到 `1024-node` quadtree+mesh
  - 但必须保留：
    - `input injection hotspot`
    - `distributed hidden layer`
    - `single output aggregation hotspot`
    - `sparsity sweep`
    - `update frequency sweep`

#### B. DVS visual-symbol / event-camera trace

- `[论文直接参考]` DYNAPs 用 convolutional neural network 对 DVS visual symbols 做 real-time classification。
- `[工程归一化]`
  - 需要准备一组 `DVS/event trace`
  - 转为：
    - `src_core`
    - `timestamp`
    - `dest_set / rect`
    - `packet_type`
  - 重点统计：
    - `short-message latency`
    - `local/global traffic ratio`
    - `multicast fanout distribution`
    - `per-inference completion`

#### C. control / configuration / status trace

- `[论文直接参考]` Zeng 2024 明确面向 `control messages, configuration instructions, status information`
- `[工程归一化]`
  - 需要单独建立 `control-message` 类 workload
  - 固定特点：
    - `1 flit` 或 `3 flit`
    - bursty
    - 小 payload
    - 对 tail completion 延迟敏感
    - 需考察 packet-level flow control/backpressure

#### D. 大规模 GALS 部署

- `[论文直接参考]` PAICORE 2025 采用 `1024-core`、`GALS`、`five-level fat up-down quadtree`
- `[工程归一化]`
  - 本仓库的 `1024-node` quadtree+mesh 主结果必须保留
  - 所有 workload-driven 结果都至少要有一组 `1024-node`

### 4.8 第 7 步：baseline 对比

#### baseline A：native multicast vs replicated unicast

- 相同源节点
- 相同目的集合
- 相同 packet length
- 相同 batch size
- 相同 seed
- 相同 offered load

#### baseline B：native multicast vs original quadtree baseline

- 当前算法：局部裁剪 + 必要时才向上保留副本 + 进入目标 tile 后再展开
- baseline：在每层四叉树只要和多个 child 相交就立即复制，不做当前的优化

#### baseline C：asynchronous vs synchronous counterpart

- 相同规模
- 相同 packet semantics
- 相同 traffic pattern
- 相同 batch size
- 相同功耗统计层级

## 5. 每类仿真的最小输出文件

每个实验点至少输出：

- 原始 log
- 一行 summary CSV
- 图表所需聚合 CSV
- 参数 manifest

建议 manifest 字段：

- `paper_mode`
- `experiment_class`
- `dut`
- `tb`
- `network_nodes`
- `traffic_pattern`
- `packet_len`
- `rect_w`
- `rect_h`
- `seed`
- `batch_size`
- `sparsity`
- `update_frequency`
- `power_method`
- `algorithm_baseline`
- `sync_baseline_enabled`

## 6. 当前仓库中的推荐执行顺序

1. 生成 `256-node` 与 `1024-node` DUT
2. 做 directed + random correctness 闸门
3. 先跑 `uniform_unicast` 主曲线
4. 再跑 `cross_tile_unicast` 与 `hotspot_unicast`
5. 跑 `uniform_multicast` 的 `rect_size` 与 `ack_delay`
6. 跑 `mixed_unicast_multicast` 与 `overlapping_multicast`
7. 跑 `batch_size vs power / energy`
8. 跑 `native multicast vs replicated unicast`
9. 跑 `native multicast vs original_quadtree_recursive`
10. 跑 `NAV/KWS-like RSNN`、`DVS`、`control-message` trace
11. 最后跑 `asynchronous vs synchronous counterpart`

## 7. 当前最值得先补的脚本

如果下一步要继续把这份文档变成能直接执行的流程，优先补下面几个脚本：

- `sim/xsim/quadtree_and_mesh/run_perf_batch_sweep.ps1`
- `sim/xsim/quadtree_and_mesh/run_workload_trace.ps1`
- `sim/xsim/quadtree_and_mesh/run_algo_baseline_rect_sweep.ps1`
- `sim/xsim/quadtree_and_mesh/run_sync_baseline_suite.ps1`

## 8. 你当前项目里应当遵守的最终固定口径

如果只保留一套最核心、最不容易跑偏的规则，建议固定为：

- 论文主结果统一 `1024-node + xsim batch`
- 主线统一 `3 flit`，补 `1 flit` 和 `8 flit` 敏感性
- synthetic 统一 `warmup_ns = 20000`、`measure_ns = 50000`
- 所有多播结果必须同时给出 `completion latency` 与 `energy/traffic` 代理
- 所有 workload 结果必须给出 `per-inference` 或 `per-batch` 完成时间
- 所有 baseline 比较都必须保证相同 `seed`、相同目的集合、相同 batch size
- 所有最终图表都必须能回溯到 raw log 与 summary CSV

## 9. 这一版协议与论文的关系

最后强调一次，这份协议不是逐字逐表复现单篇论文，而是：

- 用 DATE 2013 和 IEEE Micro 2021 固定异步 NoC 的基础 microbenchmark 和公平比较方式
- 用 JETCAS 2024 固定 neuromorphic multicast、RSNN workload、sparsity/update-frequency sweep 的做法
- 用 DYNAPs 固定 DVS / event-driven trace 的任务形态
- 用 Zeng 2024 固定 control-message 类 workload 的必要性
- 用 PAICORE 2025 固定 `1024-core/GALS/fat-tree or quadtree-class NoC` 的规模目标
- 用 2025 编码论文固定“算法/编码层 baseline 也要比较”的要求

这样整理后，当前仓库里的仿真不再只是“能跑”，而是有明确论文依据、有统一初始设定、也有清晰执行顺序的实验体系。
