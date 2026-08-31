# Ultra Timing Optimization Log

## 2026-08-12 — Phase 0/1/2 execution record

### Phase 0 — frozen baseline

- Frozen run: `20260812_timing_baseline_r1`.
- DC: `ULTRA_DC_PASS`, `GTECH=0`; STA completed. Archive:
  `scripts/asic_dc/ultra/results/20260812_timing_baseline_r1/`.
- PVT is T28 SS, 0.81 V, 125 C. This DC-only synthesis flow has no P&R
  randomization, so its seed is explicitly `N/A — deterministic synthesis flow`.
- Structural reference: 417 resettable latches, five OPM DEL075 instances,
  and the existing Mutex/C-element/V2 close-event hierarchy. Equivalence is
  structural count + QoR/RTC tolerance + regression outcome; hashes track
  artifacts but are not the sole equivalence criterion.

### Phase 1 — paired OPM measurement

- Strict-SDF run `20260812_rtc_all_edges_baseline_r2` reused the frozen
  post-netlist/SDF and passed every legal Router edge with isolated H/B/T:
  60 samples total, 40 rise and 20 fall.
- CSV: `docs/timing_baselines/20260812_rtc_all_edges_baseline_r2_rtc.csv`.
  Raw SDF log:
  `scripts/asic_dc/ultra/results/20260812_rtc_all_edges_baseline_r2/rtc_all_edges_sdf.log`.
- The fixture records physical `DataIn→DataOut` separately from paired
  `ReqIn→DataOut` and `ReqIn→ReqOut`. At this corner the latest DataOut and
  earliest ReqOut are separated by only the 1 ps simulator quantization:
  Head is approximately 4.50–4.65 ns, Body/Tail approximately 0.45 ns.
  This is a near-zero OPM bundled-data margin, not a 5% RTM pass.
- The first all-edge fixture used a 75 ps output-Ack dwell and stalled after
  Head. It was corrected to the canonical 200 ps Ack dwell plus 1 ns recovery;
  this was a TB protocol correction only.

### Phase 2 — role split accepted as value-equivalent

- `UltraArbiterDecision` is decomposed into `UltraArbiterAnchor`,
  `UltraArbiterRoundClose`, `UltraArbiterMembershipClose`,
  `UltraArbiterFinalBuilder`, and `UltraArbiterReturn`; `UltraArbiterCommit`
  remains responsible for ACG Dfire and commit-Ack chains. All remain DEL250
  under `ULTRA_P250_PRS_ACG_OPM75`; no equation or intended DEL count changed.
- Local Scala compile and structural Router smoke, including all-edge H/B/T,
  pass. DC now emits a role-by-role delay-cell report.
- Router run `20260812_timing_role_split_r4`: DC PASS (`GTECH=0`), STA PASS
  (`DEL250_COUNT=20`), and all five strict-SDF boundary cases PASS.
- NoC16 run `20260812_timing_role_split_noc16_r2`: DC PASS (`GTECH=0`), then
  canonical strict-SDF TAB p02 PASS (3000/3000) and VCTM-MC5 p02 PASS
  (3000/3405), each with zero missing/unexpected flits, timeout, or overflow.
- The first local NoC16 invocation incorrectly selected `Mutex2_sim.v`; it
  failed and is invalid for this comparison. The required structural
  `Mutex2.v` invocation then passed both canonical p02 cases. Remote uses the
  ASIC Mutex netlist and is the acceptance result.
- The initial role report used `*member*_close_margin*`, which did not match
  DC's slash-separated hierarchy and caused r2 to exit despite valid RTL.
  The report now uses `*member*/close_margin*`; this naming-only correction
  changes neither the controller nor its DEL values.

### Atomic V2 baseline timing trace — optimization ordering evidence

- Strict-SDF trace `20260812_atomic_role_timing_r4`, using the frozen r4
  Router netlist, passed `unicast3`.  Head timing from ReqIn is:

| Boundary | Cumulative delay |
|---|---:|
| V1 ReqX | 0.066 ns |
| PRS RS | 0.583 ns |
| HeadCapture P | 1.064 ns |
| Mutex5 anchor | 1.497 ns |
| RoundClose | 2.284 ns |
| Membership all closed | 2.903 ns |
| FinalBuilder ready | 3.277 ns |
| Transaction valid | 3.390 ns |
| ACG fire | 3.848 ns |
| admittedRS | 3.996 ns |
| ReqGen Req | 4.080 ns |
| OPM DataOut | 4.415 ns |
| ReqOut | 4.600 ns |

- With all explicit Arbiter roles still DEL250, the largest direct removable
  guard before commit is the RoundClose interval (anchor → close, 0.787 ns),
  followed by Membership/C-tree (0.619 ns), FinalBuilder (0.374 ns), and
  Commit/ACG (0.458 ns). This is only an ordering observation; no role value
  is changed in this round. The next round must choose exactly one measured
  role, freeze its data path, derive a min/max control window, and test only
  one or two boundary-adjacent DEL candidates.

最后更新：2026-08-12

本文档记录 Ultra Router / NoC 时序优化的执行状态、每阶段边界、输入基线、实验变量、STA/SDF 证据和最终选择。方法规范见 [Ultra Design Entry and Timing Optimization Flow](Ultra_Design_Entry_and_Timing_Optimization_Flow.md)；故障诊断仍记录在 [UltraRouter Debug Log](UltraRouter_Debug_Log.md)。

## 1. 总目标

在不改变异步协议、功能结构和多播原子语义的前提下：

1. 降低 Head 的 `ReqIn → ReqOut` 前向延迟，重点缩短 PRS 和 Atomic V2 控制路径。
2. 降低 Body/Tail cycle time，保持 OPM V2、Ack/TP、Tail release 的正确事件顺序。
3. 对全部 Router RTC 和 NoC link RTC 建立可审计的 `Tdata/Tcontrol/RTM/shortfall` 报告。
4. 先保持当前 5% RTM 基线，再按论文外环推进到 7% 和 10%。
5. 最终严格 SDF 下保持所有 Router smoke、TAB 和 VCTM 回归通过。

优化优先级是：在满足目标 RTM 与功能正确性的前提下最小化控制延时。控制路径超过数据路径过多也属于时序失败，而不是“更安全”。

## 2. 当前冻结基线

| 项目 | 当前值/状态 |
|---|---|
| Delay profile | `ULTRA_P250_PRS_ACG_OPM75` |
| PRS matched delay | DEL250 |
| Atomic V2 HeadCapture | DEL250 |
| Atomic V2 controller Decision 参数 | DEL250，当前同时控制 anchor、return、round-close、membership-close、final-builder |
| Atomic V2 Commit / ACG | DEL250 |
| OPM V2 request margin | DEL075，暂时冻结 |
| Structured sink Ack | DEL075，仅属于验证环境，暂时冻结 |
| Router SDF baseline | 五项 boundary smoke 已通过 |
| NoC16 SDF baseline | run `20260812_ack075_r5_core015` |
| TAB 3-flit | r0p02 至 r0p90 全部 PASS |
| VCTM-MC5-NM 3-flit | r0p02 至 r0p90 全部 PASS |

当前基线是所有优化实验的回退点。任何候选失败时，不允许在失败候选上叠加下一项修改。

## 3. 已知测量缺口

开始缩减 DEL 之前必须解决以下问题：

- 当前 STA 只对一条 Child0→Parent 路径给出较完整报告，20 条合法 edge 的报告尚未自动计算 paired RTM。
- 当前 `UltraArbiterDecision` 同时驱动多个不同 RTC；直接 sweep 会同时改变六类边界，无法归因。
- Atomic V2 的 HeadCapture、anchor、round-close、membership-close、greedy/final-builder、commit、return 尚无统一的 pin-level 时间节点表。
- 当前 DC 主要是 post-synthesis SDF，尚未完成论文要求的 datapath-first 冻结和 control min/max 增量优化闭环。
- Router-level 结果不能覆盖 FIFO 和 L1/L2 link；NoC level 必须重新提取 RTC。

## 4. 分阶段优化计划

### 阶段 0：冻结基线与可复现性

目标：建立不可歧义的优化起点。

工作：

- 固定当前 RTL、primitive、TB、DC/STA Tcl 和 delay profile 的 SHA-256。
- 保存 Router 与统一 `AsyncNoC16BoundaryDUT` 的 entry/post/SDF、结构计数和 QoR。
- 汇总现有 Router smoke、TAB、VCTM 结果，建立 baseline manifest。
- 确认 `GTECH=0`、无 unresolved/unmapped，Mutex/C-element/latch/DEL 结构计数正确。

边界：本阶段只归档和检查，不修改 RTL、约束、DEL 或综合策略。

完成条件：固定 source/constraint hash、tool version、library、PVT 和 seed；重建结果须结构等价、关键 timing/QoR 落在预设容差内且所有回归一致。仅当工具已证明 deterministic 时，才额外要求 post-netlist/SDF SHA-256 完全一致。

### 阶段 1：建立全路径时序测量基础设施

目标：先测量，再优化。

工作：

- 修正 STA 对象选择，只使用可解析的 port/pin/net，不把 cell collection 当作 `-through`。
- 为全部 20 条合法 Router edge 输出 Head、Body、Tail 的 paired report；Req 上升与下降事务分别报告，最终取最坏组合。
- 为 Atomic V2 记录：

  ```text
  ReqIn → ReqX → RS
  → HeadCapture P/M
  → anchorGrant
  → roundClose
  → membership closeReady/allClosed
  → finalBuilderReady
  → txValid
  → ACG fire
  → admittedRS/PPE/MG
  → ReqOut
  ```

- 对每个节点同时记录 data/state leg 与 control/close leg，且明确共同参考事件。
- 自动 CSV 的每一行固定包含：

  ```text
  rtc_id, phase,
  data_start, data_end, Tdata_min, Tdata_max,
  ctrl_start, ctrl_end, Tctrl_min, Tctrl_max,
  margin_ps = Tctrl_min - Tdata_max,
  RTM = margin_ps / Tdata_max,
  target_RTM, shortfall_ps, overdesign_ps
  ```

  bundled-data 正确性一律以 `Tctrl_min >= Tdata_max × (1 + target_RTM)` 判定；禁止以 `Tctrl_max - Tdata_max` 或单一 max-delay 报告判定通过。
- 明确记录所有 loop breakpoint 和替代约束。

边界：仅修改 STA、报告脚本和 simulation-only timing trace；不修改功能 RTL、delay profile 或 TB 握手。

完成条件：20 条 edge 和 Atomic 关键 RTC 均有非空、双相位报告；所有 `NO_PATH` 都有明确原因；SDF trace 与 STA 的关键事件顺序一致。

### 阶段 2：解耦 Delay role，不改变物理延时

目标：让后续实验每轮只改变一个变量。

工作：

- 将当前 `UltraArbiterDecision` 拆分为独立 role：

  | 新 role | 当前结构位置 |
  |---|---|
  | `UltraArbiterAnchor` | `anchor_any → anchor_start` |
  | `UltraArbiterRoundClose` | `anchor_start → round_close` |
  | `UltraArbiterMembershipClose` | 四个 membership `close_grant → close_ready` |
  | `UltraArbiterFinalBuilder` | `allMembershipClosed → finalBuilderReady` |
  | `UltraArbiterReturn` | `fire → round_reset/RETURN` |
  | `UltraArbiterCommit` | transaction Q → ACG fire/commit Ack |

- 所有新 role 初始仍映射 DEL250。
- profile 改成可独立配置，但保留一个与旧 baseline 完全等价的别名。

边界：只重构参数和结构命名，不改变任何 DEL 数值、方程、状态生命周期或模块接口语义。

完成条件：生成网表的 DEL 数量和位置与旧基线一一对应；本地单元/Router smoke、远程 Router 五项 SDF 和 NoC16 TAB/VCTM p02 均 PASS；关键时间允许仅有工具噪声差异。

### 阶段 3：Datapath-first 优化与冻结

目标：按论文先确定要匹配的数据路径。

工作：

- 对 V1、PRS mask、Atomic transaction payload、OPM data Mux/latch 和 NoC link data 分别施加合理 max-delay、max-capacitance、max-transition。
- 只允许 sizing 与 buffer insertion，保持异步结构。
- 提取每类最坏 `Tdata`；选择每个 RTC 的参考数据路径。
- 在 post-route 阶段冻结已收敛 data placement、routing 和 drive strength；当前仅 DC 阶段则冻结映射结构并记录限制。

边界：不缩减任何 matched DEL，不改变 control min-delay，不做 ECO。

完成条件：所有数据路径达到稳定 QoR；连续两轮 incremental compile 的关键 `Tdata` 变化低于预设阈值；严格 SDF 功能回归无退化。

本阶段及阶段 4-8 在尚无完整 P&R/RC extraction 时，统一标记为 **SYNTH-CLOSED**，即 DC mapped netlist、STA RTC 和 post-synthesis SDF 通过；不得称为最终 ASIC timing signoff。完成 P&R、RC extraction、post-route STA 与 post-layout SDF 后，才可标记为 **PHYS-CLOSED**。

### 阶段 4：PRS 显式 DEL 去过设计 / coarse pruning

目标：降低 Head routing 延迟，同时保持 routing mask 在 RS 事件前稳定且无毛刺。

显式 DEL 不是 Ultra 的主 closure 手段，而是对明显过度设计的当前 RTL margin 做 coarse pruning，以及对后续残余 violation 做 ECO 的工具。先由阶段 3 的 `Tdata_max/Tctrl_min` 算出需求窗口，再选最少的 1-2 个候选；不再机械枚举所有档位。

每个候选：

- 从阶段 3 冻结基线重新生成独立 run。例如若 DEL150 明显偏保守、DEL100 接近需求，仅测 150 与 100。
- 测量 routing/mask `Tdata` 与 RS/control `Tcontrol`。
- 运行 PRS/Router H/B/T、本地五项 Router smoke、远程五项严格 SDF。
- 候选通过后才运行 NoC16 TAB/VCTM p02。

边界：本阶段只改变 `UltraPrsMatched`；Atomic、OPM、endpoint、FIFO 均保持基线。

停止条件：第一次 RTC shortfall、毛刺、setup/hold、数据错误或 timeout。选择最小可靠候选；剩余 closure 回到阶段 8 的 data-derived min/max window 与 incremental synthesis。

### 阶段 5：Atomic HeadCapture 显式 DEL 去过设计 / coarse pruning

目标：缩短 `RS/localMask → P/M captured`。

候选由阶段 3 数据窗口决定，优先测边界附近 1-2 档；0 ps 仅在 STA 明确证明自然逻辑延时满足 RTC 时测试。

重点 RTC：`localMask` 完整稳定早于 `packetPresent` 关闭 mask latch；release 不得误清下一 Head。

边界：只改变 `UltraArbiterHeadCapture`。

完成条件：HeadCapture/Atomic standalone、五项 Router smoke、NoC16 TAB/VCTM p02 全部 strict-SDF PASS，且无 `P=1/M=0`、descriptor/active/owner 不一致。

### 阶段 6：Atomic Builder 各边界显式 DEL 去过设计 / coarse pruning

目标：降低当前 Head 延迟最大来源，同时保留 transactional membership 语义。

执行顺序：

1. `UltraArbiterAnchor`
2. `UltraArbiterRoundClose`
3. `UltraArbiterMembershipClose`
4. `UltraArbiterFinalBuilder`
5. `UltraArbiterCommit`
6. `UltraArbiterReturn`

每一项只根据该 RTC 的测量窗口测试最有信息量的 1-2 个候选；通过后把该项的最优值固定为下一项基线。显式 DEL 仍不是最终 closure 的替代品。

重点检查：

- anchor/mask 在 roundClose 前冻结；
- late candidate 只能进入本轮或下一轮，不能污染 frozen membership；
- `allClosed` 后 greedy winner/tx payload 在 `txValid` 前稳定；
- ACG fire 只采样 frozen transaction；
- RETURN 完成前不启动新 round；
- 同一 output 的 active mask、owner、PPE/MG 始终 one-hot-consistent。

边界：每一子轮只改变一个 role。任何失败都回到该 role 的前一通过档，不把多个补偿 DEL 一起改变。

完成条件：每个 role 都有选定最小档和 paired RTC 证据；最终五项 Router strict-SDF、TAB/VCTM p02/p10 PASS；Head `ReqIn→ReqOut` 明显小于基线。

### 阶段 7：OPM、Ack/TP 与 Tail release 复核

目标：确认前级加速没有侵蚀已经签核的输出时序。

工作：

- 暂时保持 OPM DEL075，不主动继续减小。
- 复核 20 条 OPM edge 的 V2 RTM、latch D/E setup/hold、close-event pulse、Ack/TP DFF。
- 复核 TailJoin→Atomic release→tailReleaseReady→AckGenerator→V1 reopen。
- 若某条 edge shortfall，只允许按 paired STA 对该 control segment做最小修复；不得增加全局 DEL 掩盖局部问题。

边界：无证据不得修改 OPM75 或 endpoint DEL075。

完成条件：全部 OPM/TP/release RTC 达到当前 5%，五项 Router smoke 全部 strict-SDF PASS。

### 阶段 8：Router-level 5% RTM 签核

目标：完成 Ultra Fig. 6 的第一轮内环闭合。

工作：

- 对全部 Router RTC 同时施加 data-derived `set_min_delay` 和有限 `set_max_delay`。
- 使用 incremental synthesis；必要时小步增加 `extra_slack` 或调整 cost priority。
- 对 overdesigned control path 收紧 max-delay。
- 仅在迭代无法收敛时对违例 control path做最小 DEL ECO。

边界：本阶段不提升到 7%/10%，不处理 NoC link RTC。

完成条件：全部 20 条 edge、Atomic、PRS、OPM、Tail release RTC 在 post-route/当前最高物理精度下达到 5%，Router 五项严格 SDF PASS。

### 阶段 9：FIFO 与 NoC link 优化

目标：从 Router macro 扩展到完整 NoC16。

工作：

- 按 upward/downward link 分别提取 data/request/Ack 路径。
- 数据线初次 route/buffer 后冻结，再约束 request min-delay。
- 对 FIFO forward 与 Ack return 分开约束；STA 分析切环必须有替代约束。
- 保持统一 `AsyncNoC16BoundaryDUT` 单顶层、唯一网表/SDF。
- endpoint DEL075 作为环境签核条件保留，不纳入 Router 性能优化。

边界：Router 内部已签核参数保持冻结；只优化 FIFO/link/top-level buffer 和 control matching。

完成条件：NoC link RTC 达到 5%；TAB 与 VCTM r0p02/10/20/30/40/50/60/70/80/90 全部 strict-SDF PASS。

### 阶段 10：RTM 外环 7% 与 10%

目标：执行 Ultra Fig. 7 的渐进式最终裕量收敛。

工作：

- 以 5% timing-closed 结果为起点，独立运行 7%，再运行 10%。
- 优先 sizing/buffer/incremental P&R；只对 shortfall control path使用小 DEL ECO。
- 同时约束 control max-delay，避免为了 10% RTM 大幅牺牲 latency/cycle time。

边界：7% 未通过不得进入 10%；任何档位不得改变功能结构或 TB。

完成条件分为两个受控 build：

- **PERF build**：选择最小可靠 RTM（通常 5% 或 7%），用于性能探索；
- **PAPER build / RTM10_SIGNOFF**：全部 bundling RTC 至少 10%，用于与 Ultra 实现方法的正式 area/power/latency 对比。

若 10% 成本不可接受，PERF build 可以保留 5%/7%，但不得以其替代 PAPER build 的论文对齐结论。

## 5. 每阶段统一验证梯度

每个候选按以下顺序执行，前一级失败即停止：

1. `sbt compile`、elaboration 和结构计数。
2. 对应 primitive/模块 standalone smoke。
3. Atomic/ReqGen/OPM 局部集成 smoke。
4. Atomic directed contention smoke：双输入/五输入同输出、overlap multicast、late contender、anchor/round-close 邻近到达、Tail release 紧贴 next Head、连续 maximum-rate request。
5. 本地五项 Router boundary smoke。
6. 远程 Router DC、STA、严格 SDF 五项 smoke。
7. 统一 NoC16 DC/SDF：TAB/VCTM p02。
8. 关键阶段扩展 p10；阶段签核扩展至 p90。

禁止通过修改 case、放宽 scoreboard、读取内部状态控制 TB、关闭 timing check 或使用行为 patch 获得 PASS。

## 6. 统一结果记录格式

每个 run 增加一行：

| 日期 | 阶段 | run ID | closure level | 唯一变量 | 候选 | Tdata_max | Tctrl_min | RTM | overdesign | Head latency | Cycle time | Router SDF | TAB/VCTM | 结论 |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|

详细记录还必须包含：

- source/post/SDF/TB hash；
- primitive 和 DEL 数量；
- PVT、tool version、constraint manifest；
- 首个 shortfall、timing violation 或功能失败边沿；
- overdesign 路径；
- 回退基线和下一候选。

## 7. 当前状态

| 阶段 | 状态 | 说明 |
|---|---|---|
| 0 基线冻结 | 执行中 | 已生成 `docs/timing_baselines/20260812_ack075_r5_core015_baseline_manifest.json`；远程 DC/STA 重建 run `20260812_timing_baseline_r1` 已提交，用于补齐 tool/PVT/QoR 证据。 |
| 1 测量基础设施 | 执行中 | STA 已改为输出 20×2 phase 的静态 segment index，并明确 `NOT_COMPARABLE_STATIC`；共同事件的 SDF `TB_RTC_SAMPLE` 与 CSV 聚合工具已加入。等待新远程 STA/SDF 样本。 |
| 2 Delay role 解耦 | 待执行 | 当前 controller 多处共用 `UltraArbiterDecision` |
| 3 Datapath-first | 待执行 | 尚未建立冻结 datapath 的增量综合基线 |
| 4 PRS sweep | 未开始 | 当前 DEL250 |
| 5 HeadCapture sweep | 未开始 | 当前 DEL250 |
| 6 Builder/Commit/Return sweep | 未开始 | 当前各处等效 DEL250 |
| 7 OPM/release 复核 | 未开始 | OPM75 当前功能基线已通过 |
| 8 Router 5% 签核 | 未开始 | 仅 Child0→Parent 曾测得 6.18% |
| 9 NoC link/FIFO | 未开始 | 当前只有功能 SDF 基线 |
| 10 7%/10% 外环 | 未开始 | 等待 5% 全设计签核 |

## 8. 第一轮执行边界

本轮只执行阶段 0 和阶段 1：冻结基线、完善 STA/trace、得到优化前的完整时间表。不改任何 DEL、RTL 功能方程或综合优化策略。

该轮交付应回答：

- Head 延迟具体分布在哪些模块和 RTC；
- 每个 DEL250 实际保护的 data/control 差值是多少；
- 哪个 role 有最大可缩减空间；
- 当前全部 20 条 Router edge 的最坏 RTM 是多少；
- 是否存在自然满足而无需 DEL 的路径。

## 9. Phase 0/1 execution record

### 2026-08-12 — baseline instrumentation (in progress)

- Baseline profile remains `ULTRA_P250_PRS_ACG_OPM75`; no RTL timing role,
  delay value, constraint, or DC optimization policy was changed.
- The reproducibility manifest records source/constraint hashes, library/PVT,
  seed field, tool-version collection requirement, primitive-equivalence
  policy, and the fact that endpoint sink `DEL075` is environment service
  delay, not Router forward latency.
- `tb_ultra_router_boundary_smoke.sv` now emits observation-only
  `TB_RTC_SAMPLE` for Head/Body/Tail.  It reports `DataIn→DataOut`,
  `ReqIn→ReqOut`, and the data visibility relative to Req separately.  A
  Body/Tail value where data is already transparent before Req is classified
  as `DATA_PRECEDES_REQ`; it is never treated as a negative physical data
  delay or used to claim RTM.
- `run_sta_ultra_router.tcl` now emits both rise/fall rows for all 20 OPM
  source/output cases.  These static reports are deliberately marked
  `NOT_COMPARABLE_STATIC` until a same-reference SDF sample supplies the
  required `Tdata_max` / `Tctrl_min` pair.
- Local structural RTL `unicast3` PASSed after the instrumentation.  The
  remote DC/STA baseline run is `20260812_timing_baseline_r1`; no DEL pruning
  may begin until its reports and the first paired SDF CSV are archived.

## 10. Phase 3 — Router macro datapath-first (in progress)

### 2026-08-12 — frozen measurement and 95% target generation

- **Entry:** `20260812_timing_role_split_r4`, profile
  `ULTRA_P250_PRS_ACG_OPM75`.  No RTL function, control-path DEL, RTC
  min-delay, NoC/FIFO, or asynchronous-state primitive was changed.
- A simulation-only `ULTRA_TRACE_DATAPATH` observation was run against the
  frozen Router post-netlist/SDF.  The strict-SDF `unicast3` run passed and
  produced these same-reference Head data arrivals:

  | data class | baseline `Tdata_max` | 95% target |
  |---|---:|---:|
  | V1 capture | 54 ps | 51 ps |
  | PRS descriptor | 783 ps | 744 ps |
  | HeadCapture descriptor | 870 ps | 827 ps |
  | Atomic descriptor | 924 ps | 878 ps |
  | OPM V2 (worst of 20 legal edges) | 4851 ps | 4608 ps |

- The target source is
  `scripts/asic_dc/ultra/20260812_phase3_datapath_r1_targets.tcl`; its JSON
  sidecar records the frozen SDF measurements and rounding.  The 20-edge OPM
  maximum remains the signoff bound; the first four values are representative
  transaction measurements and are explicitly not used to claim a complete
  all-placement physical closure.
- Added a datapath-only SDC overlay and incremental-DC entry mode.  They may
  optimize only ordinary data-cone drive/buffer implementation.  Mutex,
  C-element, latch/DFF protocol state, DEL, close-event, ACG, reset cones,
  hierarchy and boundary structure remain protected.
- Local structural C2/C3, Mutex5, Atomic V2, ReqGenBank and Router smoke
  suite passed before remote optimization launch.
- **External status:** the first status probe accidentally used a stale host
  address.  The configured C1 host accepted the launcher; r1 DC and SDF jobs
  `11184701/11184801` are queued.  They are not accepted results until both
  jobs complete and the overlay/structure/SDF gates below are checked.

### Phase-3 acceptance gate

`datapath_r1` and then `datapath_r2` must each demonstrate: (1) all required
data-only constraints resolve against the seeded DDC, (2) `GTECH=0` and the
protected structural fingerprint is unchanged, (3) no max-delay/library DRC
violation, (4) the five Router strict-SDF smoke cases pass, and (5) r1/r2
measured data values converge within `max(10 ps, 2% of baseline)`.  Only then
does the unified NoC16 TAB/VCTM p02 regression run; the result is labelled
`SYNTH-CLOSED`, never post-layout signoff.

### 2026-08-12 — r1 constraint-binding stop

- First incremental attempt `20260812_phase3_datapath_r1` stopped before
  compilation because the initial overlay used RTL-style bus/pin patterns
  against a seeded mapped DDC.  It applied zero constraints, which is an
  intentional hard failure rather than an optimization result.
- Retry `20260812_phase3_datapath_r1b` used `full_name` filtering to avoid
  Tcl bracket glob parsing.  It also stopped before `compile_ultra` with:

  ```text
  ULTRA_DATAPATH_CONSTRAINT_COUNT=0
  ULTRA_DATAPATH_FAIL no_path_constraints_applied
  ```

- The preserved DDC demonstrably contains the expected structural cells
  (for example `inputModules_0/mousetrap/data_latch/.../latch_cell` in the
  structural fingerprint), but the overlay's assumed *pin* names do not bind
  to the mapped port/pin naming scheme.  Therefore no max-delay constraint
  has been applied and no r1 QoR, STA, SDF, r2, TAB or VCTM result may be
  interpreted as Phase-3 evidence.
- **Next required action, outside this stopped run:** use a read-only
  `read_ddc` name inventory (`query_ultra_datapath_names.tcl`) to bind each
  of the five data-cone endpoint classes to actual DDC ports/pins; require a
  nonzero, class-by-class endpoint count before allowing incremental DC.
  Then restart r1 from the unchanged frozen r4 DDC.  Do not relax the
  zero-constraint guard and do not proceed to r2.

## 11. MembershipClose DEL250 zero-delay bypass experiment

### 2026-08-13 — accepted SYNTH-CLOSED candidate

- **Single changed role:** `UltraArbiterMembershipClose`.  Profile
  `ULTRA_P250_PRS_ACG_OPM75_MEM0` keeps the four `close_margin` instances but
  elaborates each as `DelayValue=0` (`close_grant → close_delayed` direct
  connection).  PRS, HeadCapture, Anchor, RoundClose, FinalBuilder, Return,
  Commit and OPM75 remain unchanged.
- This is deliberately not a state-machine rewrite.  In each membership cell,
  `stage_closed` and `close_delayed` remain the two parallel inputs of the
  close consensus C-element; candidate/close Mutex2 arbitration and the
  candidateSeen/candidateAck/closed latches are unchanged.
- Local structural suite passed: C2/C3, Mutex5, Atomic/ReqGen smoke, directed
  competition cases, five Router boundary cases and all 20 isolated H/B/T
  edge samples.
- Router DC/SDF run `20260812_membership0_router`:
  - `GTECH=0`; resettable latches=417; V2 close events=10.
  - role report confirms `MembershipClose=0` mapped `DEL250` cells while its
    hierarchy count remains four; Anchor/RoundClose/FinalBuilder/Return and
    Commit retain their baseline DEL250 counts.
  - strict SDF five-case Router suite: all PASS.
- Unified structural asynchronous NoC16 run
  `20260812_membership0_asyncnoc16_p50` used one
  `AsyncNoC16BoundaryDUT` DC top and one SDF.  Its sink environment retains
  20 direct DEL075 Ack delays.  Both high-load tests PASS:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- SDF annotation completed for both cases; no timing-check suppression,
  behavioral patch, force, or wrapper-based Ack was used.  Boundary post-netlist
  SHA-256: `a817f8aa5ea8d79efb7a266004f8fb3e129771c35f95d4ecd5a24fef45d32095`;
  SDF SHA-256: `1fc7b1d6849093b02a517bd1fb8d78e4790aa5a7dcebcc246f68439511ef626d`.
- **Conclusion:** DEL250 is not required for the current MembershipClose
  protocol under the measured T28 post-synthesis/SDF environment.  The
  zero-delay bypass is now the accepted pre-layout baseline for the next
  single-role timing experiment.  It remains `SYNTH-CLOSED`, not P&R signoff.

## 12. HeadCapture DEL250 zero-delay bypass experiment

### 2026-08-13 — accepted SYNTH-CLOSED candidate

- **Single changed role:** `UltraArbiterHeadCapture`, on top of the accepted
  MembershipClose bypass.  Profile `ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0` keeps
  every `head_margin` and `close_margin` hierarchy, but elaborates both with
  `DelayValue=0`.  `UltraPrsMatched`, Anchor, RoundClose, FinalBuilder,
  Return, Commit, Admission ACG and OPM75 remain unchanged.
- This specifically tests the downstream `RS[3:0] -> localMask` capture
  window.  It does **not** remove or weaken the PRS matched delay that gives
  routing decode time before RS is asserted.
- Local structural regression passed: C2/C3, Mutex5, Atomic/ReqGen smoke,
  directed contention, all five Router boundary cases, and all 20 isolated
  H/B/T edge samples.
- Router run `20260813_mem0_hc0_router`: `GTECH=0`, resettable latches=417,
  V2 close events=10.  Its DC report records five HeadCapture and four
  Membership hierarchies, with zero mapped DEL250 cells in both roles; all
  other protected role counts remain at their MEM0 baseline.  The five strict
  SDF Router cases and STA completed successfully.
- Unified structural asynchronous NoC16 run
  `20260813_mem0_hc0_asyncnoc16_p50` used one `AsyncNoC16BoundaryDUT`
  netlist/SDF and retained twenty DEL075 sink-Ack environment cells:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- Both strict-SDF runs completed annotation with no `IFNSDFA` or runtime
  setup/hold violation.  The annotation log retains the pre-existing VCS
  warning that negative `$setup/$hold` limits require `$setuphold`; it is an
  annotation-model limitation, not a runtime timing violation.  Boundary
  post-netlist SHA-256:
  `360a0a780165693fd77d883fb1cc29d507a73acecdb3ae84fa9796047ed42a83`;
  SDF SHA-256:
  `67f397432811b9b3a759ef85dd367b28587149c8f976c36a43ac71488c12f436`.
- **Conclusion:** the explicit HeadCapture DEL250 is not required by the
  measured pre-layout implementation once PRS matched routing and the
  existing mask latch protocol are retained.  `MEM0_HC0` is the new
  pre-layout / `SYNTH-CLOSED` baseline.  Post-route paired RTC must still
  prove that the latest localMask settles before packetPresent closes capture.

## 13. OPM V2 DEL075 replacement — local D/E RTC correction

### 2026-08-13 — zero-DEL local measurement completed

- The previous attempted `0.310–0.360 ns` control window is **void**.  It
  incorrectly derived a local XOR4-to-L5 delay from the Router end-to-end
  `DataOut/ReqOut` measurement.  It was never used to produce an accepted DC
  candidate.
- The authoritative OPM V2 bundled-data check is now:

  ```text
  DataX → MG Mux → dataOutLatch.D (last transition)
                            before
  request selection Q → XOR4 → L5.Q feedback → dataOutLatch.E falling
  ```

  `ReqOut` remains a functional/latency observation only; it is not the
  capture boundary used to calculate OPM RTM.
- Strict SDF run `20260813_opm_local_rtc_entry5` used the mapped zero-DEL
  entry `20260813_opm_synth_entry_r1`, with all 20 legal edges and H/B/T:

  | local measurement | worst result |
  |---|---:|
  | Head `DataX → dataOutLatch.D` | 3.857 ns |
  | Head `D stable → E↓` | 254 ps |
  | 5% required local margin | 192.85 ps |
  | Body/Tail `D stable → E↓` | 528–555 ps |

- Thus the zero-DEL entry already meets the measured 5% local D/E margin;
  no ordinary buffer is required.  The ongoing r1/r2 DC sequence is retained
  only to prove mapping convergence, DEL075 removal, and functional SDF
  equivalence.  It must not introduce a synthetic min-delay window.

### 2026-08-13 — OPM_SYNTH accepted: no replacement buffer is required

- The two incremental mapped candidates completed from the zero-DEL OPM entry:
  `20260813_opm_synth_localde_r1b` and
  `20260813_opm_synth_localde_r2`.  Both have `GTECH=0`, preserve the five
  `v2RequestMargin` hierarchy boundaries, and map **zero** DEL075 cells.
  The remaining five control-cell count is the retained hierarchy wrapper,
  not inserted delay cells.
- Repeating the complete local V2 D/E experiment on the r2 netlist/SDF
  (`20260813_opm_synth_localde_r2_rtc`) produced 60 samples over 20 legal
  edges and Head/Body/Tail phases.  The worst local results are:

  | flit | max `DataX -> dataOutLatch.D` | min `D stable -> E falling` | 5% requirement | result |
  |---|---:|---:|---:|---|
  | Head | 3.873 ns | 264 ps | 193.65 ps | PASS (+70.35 ps) |
  | Body | 44 ps | 527 ps | 2.20 ps | PASS |
  | Tail | 43 ps | 556 ps | 2.15 ps | PASS |

  This is the only OPM RTC used for this choice: the latest V2 data-latch D
  transition is compared with the earliest actual E falling edge for the same
  flit.  `ReqOut` is retained as a functional/latency observation and is not
  an OPM delay target.
- Router strict-SDF run `20260813_opm_synth_localde_router_sdf` passed all
  five boundary cases.  The unified structural-endpoint NoC16 DC run
  `20260813_opm_synth_localde_noc16_p50` then mapped the same profile into one
  `AsyncNoC16BoundaryDUT` netlist/SDF (`GTECH=0`, 20 environment sink DEL075,
  no OPM DEL075) and passed:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- The VCTM SDF log records one non-fatal timing warning at
  `routerL2.admission.tx.txm3.resettable_latch[1]`
  (`$setuphold(negedge E, posedge D, limits -11/16 ps)`).  It is an Atomic
  transaction-latch event, not an OPM V1/V2 D/E violation; the full checker
  still completed with zero errors.  It remains an Atomic-RTC item for the
  later control-role optimization round and must not be hidden by a timing
  check suppression option.

- **Decision:** `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0` is the new
  pre-layout / `SYNTH-CLOSED` baseline.  No ordinary XOR4-to-L5 buffer or
  inverter was necessary, because the native mapped control path already
  meets the 5% local D/E requirement.  The former 310–360 ps end-to-end
  window is retired and must not be reintroduced.  Post-route extraction must
  repeat the same D/E paired check before making a final physical-signoff
  claim.

## 14. Anchor DEL250 zero-delay bypass experiment

### 2026-08-14 — local structural candidate PASSed; remote SDF FAILed

- **Single changed role:** `UltraArbiterAnchor`, on top of the accepted
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0` baseline.  Profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_ANC0` keeps the `anchor_margin`
  hierarchy but elaborates it as `DelayValue=0` (`anchor_any → anchor_start`
  direct connection).  OPM `v2RequestMargin`, MembershipClose, and
  HeadCapture remain `steps=0`.  RoundClose, FinalBuilder, Return, Commit
  and PRS remain DEL250.
- Dead code only: unused `pick_mask` was removed from
  `AsyncArbiterTransactionController.v`.  No round-state, membership, or
  Release-path equation changed.
- Generated `UltraRouter.v` records
  `AnchorDelayValue(0)`, `MembershipDelayValue(0)`, HeadCapture
  `DelayValue(0)`, and OPM `v2RequestMargin DelayValue(0)`.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM, ReqGenBank,
  seven Router boundary cases (`unicast3`, `mc_single3`,
  `mc_disjoint_parallel3`, `uc_overlap_release3`, `mc_overlap_tailjoin3`,
  `b_alone_head`, `a_then_b_head_parallel`) and all 20 isolated H/B/T edge
  samples.  Zero-delay RTL therefore still implements the intended protocol;
  the failure below is a post-synth SDF hold/race, not an RTL equation bug.

### Remote Router DC/SDF — `20260814_anc0_router`

- Jobs: DC `11231901`, SDF `11232001`.  Stages: `dc,sdf` only.  Archive:
  `scripts/asic_dc/ultra/results/20260814_anc0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 / hierarchy=1;
  MembershipClose DEL250=0 / hierarchy=4; RoundClose/FinalBuilder/Return
  DEL250=1; Commit DEL250=2.  The netlist is the intended ANC0 topology.
- **SDF FAIL on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.  Inputs arrive at ~30.2 ns, then the
  DUT produces no output until the 2.03 µs timeout:

  | Case | Failure |
  |---|---|
  | `unicast3` | `parent_output_timeout` in=00001 out=00000 |
  | `mc_single3` | `target_output_timeout` in=10000 out=00000 |
  | `mc_disjoint_parallel3` | `target_output_timeout` in=10001 out=00000 |
  | `uc_overlap_release3` | `target_output_timeout` in=00011 out=00000 |
  | `mc_overlap_tailjoin3` | `target_output_timeout` in=10100 out=00000 |

- NoC16 was not launched.  A Router that never emits a Head cannot be a
  candidate for network-level SDF.

### Why Anchor is not leftover padding

- Controller sequence: Mutex5 `grant` → `anchor_any = |grant` →
  `anchor_margin` → `anchor_start`.  `busy_latch` is enabled by
  `anchor_start` and drives `round_busy`.  `anchor_latch` /
  `kind_latch` are transparent only while `~round_busy`.  `arb_req` is
  also gated by `~round_busy`, so raising busy drops Mutex request.
- The DEL250 on `anchor_margin` is the hold window that lets grant data
  settle into the transparent owner latches **before** `round_busy`
  closes them and drops `arb_req`.  With `DelayValue=0` that path is a
  combinational loop (`grant → start → busy → ~arb_req → grant`).
  Zero-delay RTL still captures grant in the same delta cycle; mapped
  SDF delays close busy / collapse grant before `anchor_q` is frozen,
  so the round starts empty and never produces ReqOut.
- This is therefore a real RTM on the grant-capture edge, not overdesign.
  Do not stack a compensating DEL elsewhere.  Revert this role only:
  keep `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0` as the SYNTH-CLOSED
  baseline.  ANC0 remains a documented failed experiment.

- **Decision:** Anchor DEL250 is **not removable** at the current
  controller equations.  Next single-role candidate remains
  FinalBuilder or RoundClose, each in its own experiment.  Do not mix
  a structural rewrite of `busy_latch`/`anchor_latch` with a delay
  sweep.

## 15. FinalBuilder DEL250 zero-delay bypass experiment

### 2026-08-14 — local structural candidate PASSed; remote Router and NoC16 SDF PASSed

- **Single changed role:** `UltraArbiterFinalBuilder`, on top of the accepted
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0` baseline.  Anchor DEL250 is kept.
  Profile `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0` keeps the
  `final_builder_margin` hierarchy but elaborates it as `DelayValue=0`
  (`all_membership_closed → final_builder_ready` direct connection).
  OPM `v2RequestMargin`, MembershipClose, and HeadCapture remain
  `steps=0`.  Anchor, RoundClose, Return, Commit and PRS remain DEL250.
- No controller equation, greedy fold, or `payload_ready` change.  Release
  transactions still skip FinalBuilder (`round_close`).
- Generated `UltraRouter.v` records `FinalBuilderDelayValue(0)`,
  `AnchorDelayValue(1)`, `MembershipDelayValue(0)`, HeadCapture
  `DelayValue(0)`, and OPM `v2RequestMargin DelayValue(0)`.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM, ReqGenBank,
  seven Router boundary cases (`unicast3`, `mc_single3`,
  `mc_disjoint_parallel3`, `uc_overlap_release3`, `mc_overlap_tailjoin3`,
  `b_alone_head`, `a_then_b_head_parallel`) and all 20 isolated H/B/T edge
  samples.

### Remote Router DC/SDF — `20260814_fb0_router`

- Jobs: DC `11232101`, SDF `11232201`.  Stages: `dc,sdf` only.  Archive:
  `scripts/asic_dc/ultra/results/20260814_fb0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=1 / hierarchy=2;
  MembershipClose DEL250=0 / hierarchy=4; FinalBuilder DEL250=0 /
  hierarchy=1; RoundClose/Return DEL250=1; Commit DEL250=2.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Remote NoC16 async-boundary p50 — `20260814_fb0_asyncnoc16_p50`

- Jobs: DC `11232301`, TAB SDF `11232401`, VCTM SDF `11232501`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260814_fb0_asyncnoc16_p50/summary.json`.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.  Mapped counts:
  HeadCapture DEL250=0 / hierarchy=25; MembershipClose DEL250=0 /
  hierarchy=20; FinalBuilder DEL250=0 / hierarchy=5.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing / unexpected /
  timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- The existing VCTM `txm3` `$setuphold` annotation remains an SDF
  **Warning**, not an error.  The full checker completed with zero errors.
  Do not hide it with a timing-check suppression option.

- **Decision:** `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0` is the new
  pre-layout / `SYNTH-CLOSED` baseline.  FinalBuilder's explicit DEL250 is
  removable at this mapped corner because membership is already frozen by
  the C-tree before the greedy fold.  Anchor DEL250 stays.  This is not
  PHYS-CLOSED.  Next single-role candidate is RoundClose; do not mix it
  with a structural rewrite of `payload_ready` / `winner_latch`.

## 16. FB0 Head timing measurement (no RTL change)

### 2026-08-14 — frozen `20260814_fb0_router` netlist/SDF, `unicast3`

- Observation-only SDF rerun `20260814_fb0_head_timing` reused the signed
  FB0 netlist (`ULTRA_NETLIST_RUN_ID=20260814_fb0_router`).  No controller
  equation, delay profile, or DC remap.  The boundary TB gained two
  hierarchical probes (`anchor_margin.Z`, `busy_latch.q`) so grant,
  `anchor_start`, `round_busy`, and `round_close` are no longer collapsed
  into one interval.
- `TB_RESULT PASS unicast3`.  Annotation `Done`, no `IFNSDFA`.
- Head cumulative delay from ReqIn, versus the all-DEL250 r4 trace:

  | Boundary | r4 (all DEL250) | FB0 | interval on FB0 |
  |---|---:|---:|---:|
  | V1 ReqX | 0.066 | 0.066 | 0.066 |
  | PRS RS | 0.583 | 0.583 | 0.517 |
  | HeadCapture P | 1.064 | 0.693 | 0.110 |
  | Mutex5 grant | 1.497 | 1.126 | 0.433 |
  | anchorStart | — | 1.534 | 0.408 |
  | roundBusy | — | 1.626 | 0.092 |
  | RoundClose | 2.284 | 1.913 | 0.287 |
  | allMembershipClosed | 2.903 | 2.239 | 0.326 |
  | FinalBuilder ready | 3.277 | 2.239 | 0.000 |
  | Transaction valid | 3.390 | 2.354 | 0.115 |
  | ACG fire | 3.848 | 2.812 | 0.458 |
  | ReqOut | 4.600 | 3.463 | 0.651 |

- `ReqIn→ReqOut` fell from 4.600 ns to 3.463 ns (−1.137 ns).  The three
  accepted zero-DEL roles account for it: HeadCapture −0.371 ns,
  Membership/C-tree −0.293 ns, FinalBuilder −0.374 ns.
- RoundClose path is now split.  Grant→`anchor_start` is 0.408 ns (Anchor
  DEL, keep).  `anchor_start`→`round_busy` is 0.092 ns (busy latch).
  `round_busy`→`round_close` is 0.287 ns: busy is already 1, then the
  remaining RoundClose DEL250 still fires close.  That 0.287 ns is the
  only remaining Builder forward interval that a later `I=round_busy`
  rewrite plus optional DEL0 could attack.  Do not DEL0 RoundClose on
  the current `I=anchor_start` net.
- ACG fire after `tx_valid` is still 0.458 ns, unchanged from r4.
  PRS RS is still 0.583 ns from ReqIn, unchanged.

- **Decision:** measurement only.  Next round starts the RoundClose
  qualification rewrite with DelayValue still 1.  Do not mix that
  equation change with a delay sweep.

## 17. RoundClose qualification from `round_busy` (DEL250 kept)

### 2026-08-14 — equation change only, DelayValue still 1

- Parent baseline remains `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0`.
  Single RTL change in `AsyncArbiterTransactionController.v`:
  `round_close_margin.I` is `round_busy` instead of `anchor_start`.
  RoundClose / Anchor / Return / Commit / PRS stay DEL250.  MembershipClose,
  HeadCapture, FinalBuilder, and OPM stay `steps=0`.
- Local structural suite PASSed.
- DC `20260814_rc_busy_router`: `ULTRA_DC_PASS`, `GTECH=0`.  RoundClose
  DEL250=1 / hierarchy=2; Anchor=1; FinalBuilder=0.  The first SDF job
  attached to that run is **invalid**: leftover
  `ULTRA_NETLIST_RUN_ID=20260814_fb0_router` annotated the previous
  netlist.  It is not evidence for this equation.
- Valid SDF: `20260814_rc_busy_sdf` on
  `outputs/20260814_rc_busy_router/UltraRouter.sdf`.  All five cases PASS,
  no `IFNSDFA`.
- `unicast3` Head from ReqIn versus FB0 (DEL still 1 on both):

  | Boundary | FB0 | I=round_busy |
  |---|---:|---:|
  | Mutex5 grant | 1.126 | 1.126 |
  | anchorStart | 1.534 | 1.533 |
  | roundBusy | 1.626 | 1.623 |
  | RoundClose | 1.913 | 2.003 |
  | allMembershipClosed | 2.239 | 2.329 |
  | ReqOut | 3.463 | 3.553 |

  `round_busy→round_close` is now 0.380 ns (one DEL250 from the busy
  edge).  Head is 90 ps slower than FB0 because the busy-latch delay no
  longer overlaps the close DEL.  That is expected and is not a reason
  to revert.  RoundClose `DelayValue=0` is a later, separate experiment.

### Remote NoC16 async-boundary p50 — `20260814_rc_busy_asyncnoc16_p50`

- Jobs: DC `11233001`, TAB SDF `11233101`, VCTM SDF `11233201`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260814_rc_busy_asyncnoc16_p50/summary.json`.
  Controller hash `75592eba…` matches the `I=round_busy` RTL.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.  Mapped counts:
  HeadCapture DEL250=0 / hierarchy=25; MembershipClose DEL250=0 /
  hierarchy=20; FinalBuilder DEL250=0 / hierarchy=5.  RoundClose stays
  DEL250=1 (profile unchanged).
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing / unexpected /
  timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- The existing VCTM `txm3` `$setuphold` annotation remains an SDF
  **Warning**, not an error.

- **Decision:** `round_close_margin.I = round_busy` with DelayValue still 1
  is the new RTL baseline on profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0`.  Do not rename the delay
  profile: this round changed an equation, not a `steps` count.  This is
  not PHYS-CLOSED.  Head is +90 ps versus FB0 until a later RoundClose
  `steps=0` experiment.  Next single-role candidate is only RoundClose
  `DelayValue=0` on this wiring; do not mix it with Return, Commit, or
  a structural rewrite.

## 18. RoundClose DEL250 zero-delay bypass on `I=round_busy`

### 2026-08-14 — local structural candidate PASSed; remote Router and NoC16 SDF PASSed

- **Single changed role:** `UltraArbiterRoundClose`, on the accepted
  `I=round_busy` RTL plus `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0`
  delay parent.  Profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0` keeps the
  `round_close_margin` hierarchy but elaborates it as `DelayValue=0`
  (`round_busy → round_close` direct connection).  Anchor, Return,
  Commit and PRS remain DEL250.  MembershipClose, HeadCapture,
  FinalBuilder, and OPM stay `steps=0`.  No equation change in this
  round.
- Generated `UltraRouter.v` records `RoundCloseDelayValue(0)`,
  `AnchorDelayValue(1)`, `FinalBuilderDelayValue(0)`,
  `MembershipDelayValue(0)`, HeadCapture `DelayValue(0)`, and OPM
  `v2RequestMargin DelayValue(0)`.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM,
  ReqGenBank, seven Router boundary cases and all 20 isolated H/B/T
  edge samples.  Zero-delay RTL therefore still implements the intended
  protocol; remote post-synth SDF is required before any SYNTH-CLOSED
  claim.

### Remote Router DC/SDF — `20260814_rc0_router`

- Jobs: DC `11233301`, SDF `11233401`.  Stages: `dc,sdf` only.
  `ULTRA_NETLIST_RUN_ID=20260814_rc0_router` (same as the DC run).
  Archive: `scripts/asic_dc/ultra/results/20260814_rc0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=1 / hierarchy=2;
  MembershipClose DEL250=0 / hierarchy=4; FinalBuilder DEL250=0 /
  hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return DEL250=1;
  Commit DEL250=2.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.  Annotated path:
  `outputs/20260814_rc0_router/UltraRouter.sdf`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Remote NoC16 async-boundary p50 — `20260814_rc0_asyncnoc16_p50`

- Jobs: DC `11233501`, TAB SDF `11233601`, VCTM SDF `11233701`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260814_rc0_asyncnoc16_p50/summary.json`.
  Controller hash `8f062f7d…` matches the `I=round_busy` RTL used by
  the Router run.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.  Mapped counts:
  HeadCapture DEL250=0 / hierarchy=25; MembershipClose DEL250=0 /
  hierarchy=20; FinalBuilder DEL250=0 / hierarchy=5; RoundClose
  DEL250=0 / hierarchy=5.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing /
  unexpected / timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- The existing VCTM `txm3` `$setuphold` annotation remains an SDF
  **Warning**, not an error.

- **Decision:** `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0` is the
  new pre-layout / `SYNTH-CLOSED` baseline.  RoundClose's explicit
  DEL250 is removable at this mapped corner because close is qualified
  by `round_busy` rather than `anchor_start`.  Anchor DEL250 stays.
  This is not PHYS-CLOSED.  Next single-role candidates remain Return
  or Commit, each in its own experiment.  Do not mix either with a
  structural rewrite.

## 19. RC0 Head timing measurement (no RTL change)

### 2026-08-14 — frozen `20260814_rc0_router` netlist/SDF, `unicast3`

- Observation-only SDF rerun `20260814_rc0_head_timing` reused the signed
  RC0 netlist (`ULTRA_NETLIST_RUN_ID=20260814_rc0_router`).  Annotated
  path `outputs/20260814_rc0_router/UltraRouter.sdf`.  `TB_RESULT PASS
  unicast3`.  Annotation `Done`, no `IFNSDFA`.
- Head cumulative delay from ReqIn:

  | Boundary | r4 | FB0 | I=round_busy DEL1 | RC0 | interval on RC0 |
  |---|---:|---:|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 1.064 | 0.693 | 0.693 | 0.693 | 0.110 |
  | Mutex5 grant | 1.497 | 1.126 | 1.126 | 1.126 | 0.433 |
  | anchorStart | — | 1.534 | 1.533 | 1.533 | 0.407 |
  | roundBusy | — | 1.626 | 1.623 | 1.629 | 0.096 |
  | RoundClose | 2.284 | 1.913 | 2.003 | 1.629 | 0.000 |
  | allMembershipClosed | 2.903 | 2.239 | 2.329 | 1.957 | 0.328 |
  | FinalBuilder ready | 3.277 | 2.239 | — | 1.957 | 0.000 |
  | Transaction valid | 3.390 | 2.354 | — | 2.072 | 0.115 |
  | ACG fire | 3.848 | 2.812 | — | 2.530 | 0.458 |
  | ReqOut | 4.600 | 3.463 | 3.553 | 3.181 | 0.651 |

- `ReqIn→ReqOut` is 3.181 ns (−0.372 ns vs I=round_busy DEL1, −1.419 ns
  vs all-DEL250 r4).  `round_busy` and `round_close` now share the same
  1.629 ns mark: the remaining close DEL is gone.
- Remaining mapped DEL250 in UltraRouter: PRS ×5, Anchor ×1, Return ×1,
  Commit fire ×1, Commit Ack ×1 (9 cells).  Hierarchy still present at
  DelayValue=0: HeadCapture ×5, MembershipClose ×4, FinalBuilder ×1,
  RoundClose ×1, OPM `v2RequestMargin` ×5.

- **Decision:** measurement only.  RC0 remains the SYNTH-CLOSED baseline.
  Do not start Return or Commit from this observation.

## 20. Commit Ack DEL250 zero-delay bypass (dummy loop kept)

### 2026-08-14 — local structural candidate PASSed; remote Router and NoC16 SDF PASSed

- **Single changed role:** `UltraArbiterCommitAck`, on the accepted
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0` baseline and the
  `I=round_busy` RTL.  Profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0` keeps the
  `commitAckDelay` hierarchy but elaborates it as `DelayValue=0`
  (`Out.Req → Ack` direct connection).  The dummy output loop is kept.
  Dfire (`UltraArbiterCommit`), Anchor, Return and PRS stay DEL250.
  MembershipClose, HeadCapture, FinalBuilder, RoundClose and OPM stay
  `steps=0`.  No controller equation change.
- Generated `UltraRouter.v` records `commitAckDelay DelayValue(0)` and
  `fire_o_Dfire DelayValue(1)`.  `RoundCloseDelayValue(0)` and
  `AnchorDelayValue(1)` are unchanged.
- Local structural suite PASSed.

### Remote Router DC/SDF — `20260814_cack0_router`

- Jobs: DC `11236301`, SDF `11236401`.  Stages: `dc,sdf` only.
  `ULTRA_NETLIST_RUN_ID=20260814_cack0_router` (same as the DC run).
  Archive: `scripts/asic_dc/ultra/results/20260814_cack0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=1 / hierarchy=2;
  MembershipClose DEL250=0 / hierarchy=4; FinalBuilder DEL250=0 /
  hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return DEL250=1;
  Commit Dfire DEL250=1; Commit Ack DEL250=0.  The first DC log printed
  `ULTRA_ARBITER_ROLE_REVIEW=RoundClose` because the Router Tcl still
  expected RC=1 for `*_CACK0`; that is a count-script gap, not a
  netlist mismatch.  The Tcl was fixed to treat `FB0_RC0*` as RC=0.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Remote NoC16 async-boundary p50 — `20260814_cack0_asyncnoc16_p50`

- Jobs: DC `11236501`, TAB SDF `11236601`, VCTM SDF `11236701`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260814_cack0_asyncnoc16_p50/summary.json`.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.  Mapped counts:
  HeadCapture DEL250=0 / hierarchy=25; MembershipClose DEL250=0 /
  hierarchy=20; FinalBuilder DEL250=0 / hierarchy=5; RoundClose
  DEL250=0 / hierarchy=5; Commit Ack DEL250=0 / hierarchy=5.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing /
  unexpected / timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- The existing VCTM `txm3` `$setuphold` annotation remains an SDF
  **Warning**, not an error.

- **Decision:** `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0`
  is the new pre-layout / `SYNTH-CLOSED` baseline.  The dummy output
  Ack DEL is removable at this mapped corner; Dfire still protects the
  frozen-transaction-to-fire window.  This is not PHYS-CLOSED.  Next
  single-role candidate is only Return; do not mix it with a dummy-loop
  removal or a controller rewrite.

## 21. Empty-membership skip (equation only, DEL unchanged)

### 2026-08-14 — local structural candidate PASSed; remote Router SDF FAIL; equation reverted

- **Single changed equation** in
  `AsyncArbiterTransactionController.v`, on the accepted
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0` baseline.
  Delay profile was not renamed.  Membership cells, Anchor / Return /
  Dfire / dummy Ack loop, and all `DelayValue` settings were unchanged.
- The candidate added a sticky `empty_skip` latch per rank, enabled by
  `round_reset | (round_close & ~qreq)`, with
  `member_closed = close_ready | empty_skip` into the existing C-tree,
  plus `all_membership_closed |= (skip1 & skip2 & skip3 & skip4)` so an
  all-empty unicast would not wait on Mutex2 / close_consensus / C-tree.
  Intent: remove the measured 0.328 ns `roundClose → allMembershipClosed`
  residue on Head after RC0.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM,
  ReqGenBank, seven Router boundary cases and all 20 isolated H/B/T
  edge samples.

### Remote Router DC/SDF — `20260814_memskip_router`

- Jobs: DC `11236901`, SDF `11237001`.  Stages: `dc,sdf` only.
  `ULTRA_NETLIST_RUN_ID=20260814_memskip_router` (same as the DC run).
  Archive: `scripts/asic_dc/ultra/results/20260814_memskip_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts unchanged
  from CACK0: HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=1 /
  hierarchy=2; MembershipClose DEL250=0 / hierarchy=4; FinalBuilder
  DEL250=0 / hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return
  DEL250=1; Commit Dfire DEL250=1; Commit Ack DEL250=0.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  No
  `TB_X_FAIL`.  First packet of a run from global reset completes;
  later overlapping / parallel rounds time out.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- `qreq` is `cand_req & round_busy & ~anchor_release_q`, so `~qreq` is
  true whenever the round is idle.  After `round_reset` drops busy and
  then itself falls, a still-high `round_close` (DelayValue=0 buffer
  lag, or close not yet following busy) re-enables the skip latch with
  `d=1`.  Skip therefore retriggers between rounds.  The next round
  sees `all_empty_skip` already 1 and does not wait for live membership.
  Single-round cases (`unicast3`, `mc_single3`) never exercise that
  hole; overlapping cases do.

- Head timing and NoC16 were **not** run on this netlist.

- **Decision:** revert this equation only.  The controller is restored
  to the CACK0 membership join (`close_ready` into the three-C2 tree).
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0` remains the
  SYNTH-CLOSED baseline.  The 0.328 ns empty-membership residue is
  still present.  Do not retry this skip without a round-qualified
  enable that cannot fire while `~round_busy`.  Do not mix a second
  skip rewrite with Return DEL0.

## 22. Empty-membership skip, round-qualified enable (equation only)

### 2026-08-14 — local structural PASSed; remote Router and NoC16 SDF PASSed

- **Single changed equation** in
  `AsyncArbiterTransactionController.v`, on the accepted
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0` baseline.
  Delay profile not renamed; membership cells, Anchor / Return /
  Dfire / dummy Ack loop and all `DelayValue` settings unchanged.
- Retry of §21 with the failure mode fixed: the sticky `empty_skip`
  set condition is now round-qualified,
  `skip_set = round_close & round_busy & ~cand_req & ~anchor_release_q`.
  `round_close` is a DEL0 buffer of `round_busy`, so it stays high for
  a short lag after busy falls at round end; the §21 enable
  (`round_close & ~qreq`, with busy inside `qreq`) re-armed the latch
  in that gap and poisoned the next round.  The `round_busy` term
  closes the hole.  `member_closed = close_ready | empty_skip` feeds
  the existing three-C2 tree, and
  `all_membership_closed |= (skip1 & skip2 & skip3 & skip4)` lets an
  all-empty unicast close before the C-tree.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM,
  ReqGenBank, seven Router boundary cases and all 20 isolated H/B/T
  edge samples.

### Remote Router DC/SDF — `20260814_memskip2_router`

- Jobs: DC `11237901`, SDF `11238001`.  Stages: `dc,sdf` only.
  `ULTRA_NETLIST_RUN_ID=20260814_memskip2_router` (same as the DC run).
  Archive: `scripts/asic_dc/ultra/results/20260814_memskip2_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts
  unchanged from CACK0: HeadCapture DEL250=0 / hierarchy=5; Anchor
  DEL250=1 / hierarchy=2; MembershipClose DEL250=0 / hierarchy=4;
  FinalBuilder DEL250=0 / hierarchy=1; RoundClose DEL250=0 /
  hierarchy=1; Return DEL250=1; Commit Dfire DEL250=1; Commit Ack
  DEL250=0.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260814_memskip2_head_timing`

- Observation-only SDF rerun reused the signed memskip2 netlist
  (`ULTRA_NETLIST_RUN_ID=20260814_memskip2_router`).
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | RC0 | memskip2 | interval on memskip2 |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.693 | 0.693 | 0.110 |
  | Mutex5 grant | 1.126 | 1.132 | 0.439 |
  | anchorStart | 1.533 | 1.539 | 0.407 |
  | roundBusy | 1.629 | 1.634 | 0.095 |
  | RoundClose | 1.629 | 1.634 | 0.000 |
  | member_closed (skip latch out) | — | 1.834 | 0.200 |
  | FinalBuilder ready | 1.957 | 1.872 | 0.038 |
  | Transaction valid | 2.072 | 1.975 | 0.103 |
  | ACG fire | 2.530 | 2.388 | 0.413 |
  | ReqOut | 3.181 | 3.039 | 0.651 |

- `ReqIn→ReqOut` is **3.039 ns** (−0.142 ns vs RC0).  The gain is
  smaller than the 0.328 ns residue because the skip path itself
  (AND of four qualifiers → latch enable → `all_empty_skip` AND4 →
  OR) costs about 0.2 ns.  The `all_empty_skip` OR term works as
  intended: `final_builder_ready` rises at 1.872 ns, before the
  C-tree output (1.971 ns trace point).
- Live-candidate rounds do not use the bypass: their ranks still wait
  on `close_ready` through the cell Mutex2 race.

### Remote NoC16 async-boundary p50 — `20260814_memskip2_asyncnoc16_p50`

- Jobs: DC `11238601`, TAB SDF `11238701`, VCTM SDF `11238801`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260814_memskip2_asyncnoc16_p50/summary.json`.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing /
  unexpected / timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- **Decision:** the round-qualified empty-membership skip is accepted.
  The RTL baseline on top of
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0` now includes
  this equation; the delay profile name is unchanged.  Head is
  3.039 ns.  This is not PHYS-CLOSED.  Next single-role candidate
  remains Return; do not mix it with a dummy-loop removal or a
  controller rewrite.

## 23. Return DEL250 to commit-completion handshake (equation + role)

### 2026-08-14 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed role + equation:** `UltraArbiterReturn`, on the
  accepted CACK0 + memskip (§22) baseline.  Profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_RETH0` set
  Return to `steps=0`, and `return_margin.I` changed from `fire` to
  `return_req = commit_seen & commit_visible & round_busy`, where
  `commit_visible` completion-senses every winner input's
  fire-clocked state (admission: active=1 and every masked output
  owned; release: active/present cleared).  Intent: replace the
  matched fire-to-reset DEL250 with an actual commit-done handshake.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM,
  ReqGenBank, seven Router boundary cases and all 20 isolated H/B/T
  edge samples.

### Remote Router DC/SDF — `20260814_reth0_router`

- Jobs: DC `11240201`, SDF `11240301`.  Stages: `dc,sdf` only.
  `ULTRA_NETLIST_RUN_ID=20260814_reth0_router` (same as the DC run).
  Archive: `scripts/asic_dc/ultra/results/20260814_reth0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`, Return DEL250=0 with the
  `return_margin` hierarchy retained.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  No
  `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- Failure signature: the first packet(s) complete; a round that
  follows a release/overlap never produces its ReqOut.  Two candidate
  mechanisms, both rooted in the same gap:
  1. `round_reset` became a self-clearing pulse (busy-latch + AND,
     roughly 0.1 ns) instead of `DEL250(fire)`.  Everything it clears
     (membership cells, skip latches, C-tree, commit_seen) is
     level-sensitive, but the narrow pulse may not clear reliably at
     this corner.
  2. `commit_visible` senses the commit **register Qs**, but the
     `owner -> free -> all_free -> admission_req` cone is still
     settling when `round_busy` falls.  A runt on `arb_req` into
     Mutex5 can hang the mutex.  The matched DEL250 covered the whole
     request cone, not just the register updates; register-boundary
     completion sensing does not.
- Head timing and NoC16 were **not** run on this netlist.

- **Decision:** revert this round only (equation, RETH0 profile, Tcl
  expectations).  The controller is restored to the §22 baseline
  (SHA-256 `f0a0b2dc…`, matching the accepted memskip2 netlist);
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0` remains the
  SYNTH-CLOSED profile.  Return DEL250 stays.  A future Return
  handshake must sense at/after the request cone, or keep a smaller
  measured margin after `commit_visible`; do not retry
  register-boundary completion sensing alone.  This is not
  PHYS-CLOSED.

## 24. Sticky dual-rail Anchor capture (equation + Anchor DEL0)

### 2026-08-14 — local structural PASSed; remote Router and NoC16 SDF PASSed

- **Single changed equation + role:** sticky dual-rail Anchor capture in
  `AsyncArbiterTransactionController.v`, on the accepted CACK0 + memskip
  (§22) baseline.  Profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0` sets only
  `UltraArbiterAnchor` to `steps=0`.  Membership cells, empty_skip,
  Return DEL250, Dfire, `commit_seen`, owner encoding and PRS are
  unchanged.
- Capture equations:

  `AdmitSet = grant AND admission_req`

  `ReleaseSet = grant AND release_req`

  AdmitQ / ReleaseQ are sticky (set as above, reset = `round_reset`).

  `anchor_q = AdmitQ OR ReleaseQ`

  `anchor_release_q = |ReleaseQ`

  `anchor_captured = |anchor_q`

  `busy` is set from `anchor_captured`, not from `DEL(OR(grant))`.
  `anchor_margin` remains as a named `DelayValue=0` buffer of
  `anchor_captured`.  `arb_req = (admission|release) AND ~round_busy`
  is unchanged: grant exists only while idle, sticky Q sets while grant
  is still high, then busy rises and withdraws req.
- Generated `UltraRouter.v` records `AnchorDelayValue(0)`,
  `RoundCloseDelayValue(0)`, `FinalBuilderDelayValue(0)`,
  `MembershipDelayValue(0)`, HeadCapture `DelayValue(0)`, OPM
  `v2RequestMargin DelayValue(0)`, `commitAckDelay DelayValue(0)`,
  Return `DelayValue(1)`, Commit Dfire `DelayValue(1)`, PRS
  `matchedDelay DelayValue(1)`.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM,
  ReqGenBank, seven Router boundary cases and all 20 isolated H/B/T
  edge samples.

### Remote Router DC/SDF — `20260814_ancst0_router`

- Jobs: DC `11249601`, SDF `11249701`.  Stages: `dc,sdf` only.
  `ULTRA_NETLIST_RUN_ID=20260814_ancst0_router` (same as the DC run).
  Archive: `scripts/asic_dc/ultra/results/20260814_ancst0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 / hierarchy=1;
  MembershipClose DEL250=0 / hierarchy=4; FinalBuilder DEL250=0 /
  hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return DEL250=1;
  Commit Dfire DEL250=1; Commit Ack DEL250=0.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260814_ancst0_head_timing`

- Observation-only SDF rerun reused the signed ANCST0 netlist
  (`ULTRA_NETLIST_RUN_ID=20260814_ancst0_router`).
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | memskip2 | ANCST0 | interval on ANCST0 |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.693 | 0.693 | 0.110 |
  | Mutex5 grant | 1.132 | 1.128 | 0.435 |
  | anchorStart | 1.539 | 1.353 | 0.225 |
  | roundBusy | 1.634 | 1.448 | 0.095 |
  | RoundClose | 1.634 | 1.448 | 0.000 |
  | membershipN_closed | 1.834 | 1.648 | 0.200 |
  | FinalBuilder ready | 1.872 | 1.754 | 0.106 |
  | Transaction valid | 1.975 | 1.854 | 0.100 |
  | ACG fire | 2.388 | 2.269 | 0.415 |
  | ReqOut | 3.039 | 2.923 | 0.654 |

- `ReqIn→ReqOut` is **2.923 ns** (−0.116 ns vs memskip2).  The 0.40 ns
  explicit Anchor DEL is gone; grant→start is now the sticky capture
  cone (AND, latch, OR) at 0.225 ns, then the busy latch still costs
  0.095 ns.  That is why Head did not reach the 2.64 ns sketch
  (3.039−0.40).  Do not add a compensating DEL.
- Controller SHA-256 `cd28dbb31d…`.

### Remote NoC16 async-boundary p50 — `20260814_ancst0_asyncnoc16_p50`

- Jobs: DC `11249901`, TAB SDF `11250001`, VCTM SDF `11250101`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260814_ancst0_asyncnoc16_p50/summary.json`.
  Reused the existing remote p50 cases; none were regenerated.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.
  HC/MEM/FB/RC/CACK DEL250=0 with retained hierarchy.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing /
  unexpected / timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- **Decision:** sticky dual-rail Anchor capture plus Anchor `steps=0`
  is accepted as the new SYNTH-CLOSED profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Head is 2.923 ns.  This is not PHYS-CLOSED.  Next round is R2 phase
  tokens; do not mix it with Return handshake or membership cleanup.

## 25. R2 — C-element five-state phase tokens

### 2026-08-14 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed equation, same ANCST0 profile.**  Split `round_busy` /
  `commit_seen` in `AsyncArbiterTransactionController.v` into one-hot
  asymmetric C-element tokens `Q_IDLE / Q_SELECT / Q_BUILD / Q_ARMED /
  Q_RETURN` (MulticastArbiterStructure.md §六).  No new delay profile;
  Return DEL250 is kept as the temporary `returnDone`.  Membership cells,
  empty_skip, Dfire, owner encoding and PRS are unchanged except that
  membership now opens only in `Q_BUILD`.
- Phase equations (asymmetric C-element `Q+ = set || (Q && hold)`, not a
  combinational `always @(*)` FSM):

  | token | set | hold |
  |---|---|---|
  | `Q_IDLE` (reset 1) | `Q_RETURN && returnDone` | `~requestAny` |
  | `Q_SELECT` | `Q_IDLE && requestAny` | `~grantAdmission && ~grantRelease` |
  | `Q_BUILD` | `Q_SELECT && grantAdmission` | `~buildDone` |
  | `Q_ARMED` | `(Q_SELECT && grantRelease) \|\| (Q_BUILD && buildDone)` | `~fire` |
  | `Q_RETURN` | `Q_ARMED && fire` | `~returnDone` |

  `grantAdmission` / `grantRelease` remain the R1 sticky AdmitQ / ReleaseQ.
  `returnDone = DEL(fire)` (`return_margin`).  `buildDone =
  final_builder_ready && Q_BUILD`.  `arb_req` is still gated by
  `~(Q_BUILD \| Q_ARMED \| Q_RETURN)`, so Mutex still sees requests in
  IDLE/SELECT.
- `commit_seen` is deleted.  `payload_ready = Q_ARMED && ~fire`: leaving
  ARMED on fire itself forbids a second arming of the same frozen
  transaction.
- Release fast path: `SELECT + ReleaseQ` freezes tx and goes to ARMED.
  The four membership cells and empty_skip open only while `Q_BUILD`;
  `round_close_margin.I = Q_BUILD`.
- Generated `UltraRouter.v` still records `AnchorDelayValue(0)`,
  `RoundCloseDelayValue(0)`, `FinalBuilderDelayValue(0)`,
  `MembershipDelayValue(0)`, Return `DelayValue(1)`, Commit Dfire
  `DelayValue(1)`.  Controller SHA-256 `5a6e436461…`.
- Local structural suite PASSed: C2/C3, primitives, Mutex5, IPM,
  ReqGenBank, Atomic V2 interface smoke, seven Router boundary cases and
  all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260814_r2phase_router`

- Jobs: DC `11250301`, SDF `11250401`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260814_r2phase_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts unchanged
  from ANCST0: HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 /
  hierarchy=1; MembershipClose DEL250=0 / hierarchy=4; FinalBuilder
  DEL250=0 / hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return
  DEL250=1; Commit Dfire DEL250=1; Commit Ack DEL250=0.  VCS compiled
  `AsyncPhaseToken_RESET_VAL1` and `AsyncPhaseToken_RESET_VAL0_*`.
- **SDF FAIL on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  No `TB_X_FAIL`.  Every case times out on the first
  Head with zero ReqOut:

  | Case | Result |
  |---|---|
  | `unicast3` | FAIL `parent_output_timeout` in=00001 out=00000 |
  | `mc_single3` | FAIL `target_output_timeout` in=10000 out=00000 |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00000 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=00000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00000 |

- Failure signature: the first packet never produces an output.  Local
  xsim PASSed the same cases, so this is a post-map / SDF holding
  problem, not the protocol sequence used in structural sim.  The
  `AsyncPhaseToken` equation is combinational self-feedback
  `Q = reset ? RESET_VAL : (set | (Q & hold))`.  `Q_IDLE` is the only
  token with `RESET_VAL=1`.  After reset deasserts, a mapped loop that
  settles to 0 has `set = Q_RETURN && returnDone = 0`, so `Q_IDLE`
  stays 0, `Q_SELECT` never sets, BUILD/ARMED never fire, and `tx_valid`
  never rises.  MullerC2 survives because it resets to 0, matching the
  loop's natural state.  Head timing and NoC16 were **not** run.

- **Decision:** revert this round only (phase-token equation and the
  Scala comment).  Sticky dual-rail Anchor capture is restored; the
  controller SHA-256 is again `cd28dbb31d…`, matching the accepted
  ANCST0 netlist.  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  remains the SYNTH-CLOSED profile.  A future R2 retry must initialize
  `Q_IDLE=1` with a real state unit (resettable latch / C-element that
  powers up to 1), not combinational feedback with a reset mux.
  Do not stack a compensating DEL on this failed candidate.  This is
  not PHYS-CLOSED.

### Retry — latch phase tokens, active-low IDLE (`20260814_r2latch_router`)

- **Same ANCST0 profile, no extra DEL.**  Replaced `busy_latch` /
  `commit_seen_latch` with five `DLatchBank` (`LHCNDQD`, CDN clear)
  tokens.  IDLE is stored active-low so async clear yields logic-1
  without a preset latch or combinational self-feedback:

  ```text
  Q_IDLE_N reset → 0
  Q_IDLE    = ~Q_IDLE_N
  ```

  Enable is `set|clr`; data prefers clear (`d = clr ? 0 : 1`).  A token
  drops only after its successor is 1 (overlap, not a 1-delta pulse).

  | latch | set | clr |
  |---|---|---|
  | `Q_IDLE_N` | `Q_SELECT` | `Q_RETURN && returnDone` |
  | `Q_SELECT` | `Q_IDLE && requestAny` | `Q_BUILD \|\| Q_ARMED` |
  | `Q_BUILD` | `Q_SELECT && grantAdmission` | `Q_ARMED` |
  | `Q_ARMED` | `(Q_SELECT && grantRelease) \|\| (Q_BUILD && buildDone)` | `Q_RETURN` |
  | `Q_RETURN` | `Q_ARMED && fire` | `Q_IDLE` |

  `grantAdmission` / `grantRelease` remain `|admit_q` / `|release_q`
  OR'd with `anchor_captured|anchor_start`.  `returnDone = DEL(fire)`.
  `buildDone = final_builder_ready && Q_BUILD`.  `round_busy =
  Q_BUILD \| Q_ARMED \| Q_RETURN` (not `Q_IDLE_N`).  `payload_ready =
  Q_ARMED && ~fire`.  Membership / `round_close_margin.I` / `skip_set`
  gated by `Q_BUILD` only.  Release: SELECT + ReleaseQ → ARMED.
  R1 sticky AdmitQ/ReleaseQ is unchanged.  Controller SHA-256
  `5fba83539e…`.
- Local structural suite PASSed (Atomic V2 + seven boundary cases +
  20-edge H/B/T) before the remote submit.

- Jobs: DC `11250501`, SDF `11250601`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260814_r2latch_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts unchanged
  from ANCST0: HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 /
  hierarchy=1; MembershipClose DEL250=0 / hierarchy=4; FinalBuilder
  DEL250=0 / hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return
  DEL250=1; Commit Dfire DEL250=1; Commit Ack DEL250=0.  VCS compiled
  `DLatchBank_WIDTH1_*` (no `AsyncPhaseToken`).
- **SDF FAIL on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  X-free.  Every case times out on the first Head with
  zero ReqOut — the same signature as combinational R2:

  | Case | Result |
  |---|---|
  | `unicast3` | FAIL `parent_output_timeout` in=00001 out=00000 |
  | `mc_single3` | FAIL `target_output_timeout` in=10000 out=00000 |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00000 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=00000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00000 |

- Active-low `LHCNDQD` fixed the IDLE reset polarity that combinational
  `RESET_VAL=1` could not, but did not change the mapped first-Head
  timeout.  The five tokens still couple through transparent-latch
  `en=set\|clr` while successors overlap; after SDF that handoff does
  not produce `tx_valid`.  Head timing and NoC16 were **not** run.

- **Decision:** revert only these latch tokens (and the Scala comment).
  Sticky dual-rail Anchor capture is restored; controller SHA-256 is
  again `cd28dbb31d…`.  Local structural suite PASSed after the revert.
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0` remains
  the SYNTH-CLOSED profile.  Do not stack a compensating DEL on this
  failed candidate.  This is not PHYS-CLOSED.

## 26. R2 — single roundActive occupancy, decoded phases

### 2026-08-15 — local structural PASSed; remote Router SDF, Head, and NoC16 PASSed

- **Same ANCST0 profile, no extra DEL, no stored phase tokens.**  Five
  latch tokens stay reverted.  The R1 occupancy latch is rewritten so
  En/D are stable protocol levels (Q not in D).  SELECT / BUILD / ARMED
  / RETURN are combinational decodes of `round_busy`, sticky capture,
  `tx_valid`, and `commit_seen`.  Return DEL250 and sticky AdmitQ /
  ReleaseQ are unchanged.  Membership cells, Dfire, owner encoding and
  PRS are unchanged except that membership now opens only in BUILD.
- Occupancy:

  `setRound = anchor_captured`

  `clearRound = round_reset` (Return DEL250 of fire)

  `en = setRound | clearRound | anchor_start`

  `d = setRound & ~clearRound` (overlap: clear wins)

  `anchor_start` is on En only so the named DelayValue=0 Anchor cell is
  not DCE'd.  Mutex grant is never the set term.
  `arb_req = (admission|release) AND ~round_busy`.
- Decoded phases (wires, not latches).  `commit_seen` (sticky fire,
  cleared by `round_reset`) is this round's `returnReq`:

  `build_enable = round_busy & ~anchor_release_q & ~tx_valid & ~commit_seen & ~fire & ~round_reset`

  `release_ready = round_busy & anchor_release_q & anchor_captured & ~commit_seen & ~fire & ~round_reset`

  `~fire` / `~round_reset` keep the fire edge from reopening BUILD:
  fire drops `tx_valid` combinationally, and the sim Return DEL can
  coincide with that falling edge.  Local controller smoke caught a
  re-arm (`valid_rises=2`) without those two terms.

  | phase | decode |
  |---|---|
  | IDLE | `!round_busy && !request_any` |
  | SELECT | `!round_busy && request_any` |
  | BUILD | `build_enable` |
  | ARMED | `round_busy && tx_valid && !commit_seen` |
  | RETURN | `round_busy && commit_seen` |

- `round_close_margin.I = build_enable` (DelayValue still 0).
  membership `candidate_req = cand_req & build_enable`.
  `skip_set = round_close & build_enable & ~cand_req`.
  `payload_ready = (anchor_release_q ? release_ready : (final_builder_ready & build_enable)) & ~commit_seen`.
  ACG.Start remains `tx_valid`.
- Generated `UltraRouter.v` still records `AnchorDelayValue(0)`,
  `RoundCloseDelayValue(0)`, `FinalBuilderDelayValue(0)`,
  `MembershipDelayValue(0)`, Return `DelayValue(1)`, Commit Dfire
  `DelayValue(1)`.  Controller SHA-256 `32308c4cd7…`.
- Local structural suite PASSed: Atomic V2 (including the fire-rearm
  check) plus seven Router boundary cases and all 20 isolated H/B/T
  edge samples.

### Remote Router DC/SDF — `20260815_r2active_router`

- Jobs: DC `11250701`, SDF `11250801`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260815_r2active_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts unchanged
  from ANCST0: HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 /
  hierarchy=1; MembershipClose DEL250=0 / hierarchy=4; FinalBuilder
  DEL250=0 / hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return
  DEL250=1; Commit Dfire DEL250=1; Commit Ack DEL250=0.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260815_r2active_head_timing`

- Observation-only SDF rerun reused the signed occupancy netlist
  (`ULTRA_NETLIST_RUN_ID=20260815_r2active_router`).  Job `11250901`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | ANCST0 R1 | occupancy decode | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.693 | 0.693 | 0.110 |
  | Mutex5 grant | 1.128 | 1.134 | 0.441 |
  | anchorStart | 1.353 | 1.347 | 0.213 |
  | roundBusy | 1.448 | 1.434 | 0.087 |
  | RoundClose | 1.448 | 1.520 | 0.086 |
  | membershipN_closed | 1.648 | 1.740 | 0.220 |
  | FinalBuilder ready | 1.754 | 1.703 | — |
  | Transaction valid | 1.854 | 1.829 | 0.126 |
  | ACG fire | 2.269 | 2.245 | 0.416 |
  | ReqOut | 2.923 | 2.899 | 0.654 |

- `ReqIn→ReqOut` is **2.899 ns** (−0.024 ns vs R1 ANCST0).  RoundClose
  now tracks BUILD (`I=build_enable`) rather than coinciding with
  `round_busy`.  Do not add a compensating DEL.

### Remote NoC16 async-boundary p50 — `20260815_r2active_asyncnoc16_p50`

- Jobs: DC `11251001`, TAB SDF `11251101`, VCTM SDF `11251201`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260815_r2active_asyncnoc16_p50/summary.json`.
  Reused the existing remote p50 cases; none were regenerated.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.
  HC/MEM/FB/RC/CACK DEL250=0 with retained hierarchy.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing /
  unexpected / timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- **Decision:** single occupancy latch plus decoded phases is accepted
  as the new SYNTH-CLOSED equation on
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Head is 2.899 ns.  Sticky dual-rail Anchor capture is kept.  This is
  not PHYS-CLOSED.  Next round is the Return handshake (`commit_seen` /
  Return DEL250 → sticky `returnReq` + completion-tree `returnDone`);
  do not mix it with extra En DEL or stored phase tokens.

## 27. R3 — RETURN level handshake and completion tree

### 2026-08-15 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed equation + role:** replace `round_reset = DEL(fire)` with
  a level RETURN handshake in `AsyncArbiterTransactionController.v`, on the
  accepted occupancy-decode / ANCST0 baseline (§26).  Profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_RET0` sets
  only `UltraArbiterReturn` to `steps=0`.  The named `return_margin`
  hierarchy is retained as a buffer of `returnAck`, not `DEL(fire)`.
  Internal `outputOwner` is now one-hot-or-zero (external IO stays 3-bit).
  Membership cells, empty_skip, Dfire and PRS are unchanged.  No stored
  phase tokens.
- Handshake (RETH0's self-clearing pulse is the failure to avoid):

  `returnReq = commit_seen`

  `commit_visible = owner_valid AND (packet_active == owns_any)`

  `commit_done = acg_empty AND ~tx_valid AND ~grant AND commit_visible AND ~fire`

  `builder_reset = returnReq AND commit_done`  (LEVEL held by `commit_seen`)

  `returnAck = commit_done AND membership_idle AND ctree_idle AND ~round_busy AND ~fire`

  Occupancy `clearRound = builder_reset`.  `commit_seen` is set by fire
  (fire wins) and cleared only by `returnAck`, so the reset level stays
  high after busy falls and through membership/C-tree going idle.
  `arb_req` is gated by `~round_busy AND ~commit_seen` so Mutex stays
  closed for the RETURN tail.
- One-hot owner: each output stores a 5-bit one-hot input id (0 = free).
  `free[o] = ~(|owner_oh[o]) AND ~tail_busy[o]`.  `owns_any` is the OR
  of that bit across outputs, so completion sensing includes the
  free/admission request cone rather than a binary `owner==NONE`
  comparison.  `io.outputOwner` is still encoded to 3-bit (`5` = none)
  for TailJoin.
- Fire-wins on `commit_seen` is required at Return DEL0: a coincident
  `returnAck` while `fire` was still high toggled `commit_seen` in the
  same delta (local admission smoke, zero-delay oscillation).  `~fire`
  on `commit_done` / `returnAck` keeps RETURN off the fire pulse.
- Generated `UltraRouter.v` records `AnchorDelayValue(0)`,
  `RoundCloseDelayValue(0)`, `FinalBuilderDelayValue(0)`,
  `MembershipDelayValue(0)`, Return `DelayValue(0)`, Commit Dfire
  `DelayValue(1)`.  Controller SHA-256 `b86dbc830a…`.
- Local structural suite PASSed: Atomic V2 (controller now also checks
  that the handshake reopens a second admission) plus seven Router
  boundary cases and all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260815_r3ret0_router`

- Jobs: DC `11251301`, SDF `11251401`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260815_r3ret0_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 / hierarchy=1;
  MembershipClose DEL250=0 / hierarchy=4; FinalBuilder DEL250=0 /
  hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return DEL250=0 /
  hierarchy=1; Commit Dfire DEL250=1; Commit Ack DEL250=0.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  X-free.
  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- Failure signature is the same as RETH0 (§23): the first packet(s)
  complete; a later overlap/release round never produces its next
  ReqOut.  Isolated Heads pass.  Head timing and NoC16 were **not**
  run on this netlist.

- **Decision:** revert this round only (handshake equation, one-hot
  owner, RET0 profile, Tcl expectations, controller smoke).  Occupancy
  decode and sticky dual-rail Anchor capture are restored; controller
  SHA-256 is again `32308c4cd7…`.  Local structural suite PASSed after
  the revert.  Return DEL250 stays.
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  remains the SYNTH-CLOSED profile.  A later Return handshake must
  keep the next-round request cone covered after occupancy falls, not
  only wait for ACG empty / register-visible commit / builder idle.
  Do not stack a compensating DEL on this failed candidate.  This is
  not PHYS-CLOSED.

## 28. R4a — merge Membership `member_seen` / `candidate_ack`

### 2026-08-15 — local structural PASSed; remote Router SDF and Head PASSed

- **Single changed equation.**  R3 RETURN handshake stays reverted
  (§27).  `round_reset` is still `DEL(fire)`.  Profile remains
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.  Only
  [`AsyncRoundMembershipCell.v`](../src/main/resources/ASYNC/AsyncRoundMembershipCell.v)
  changes: the two latches that already shared
  `en = round_reset | cand_grant` and
  `d = round_reset ? 0 : (Q | cand_grant)` become one
  `memberAccepted` latch.  Ports stay:

  `candidate_ack = memberAccepted`

  `member_seen = memberAccepted`

  Mutex2 still withdraws on `~candidate_ack`.  Controller wiring of
  `seen*` / `member_ack*` is unchanged.  `stage_closed`, cell C2,
  `close_margin`, `empty_skip`, Return DEL250, Anchor, occupancy
  decode, Dfire and PRS are unchanged.  R4 items 2–3 (drop C2; Mutex2
  close-win instead of empty_skip) stay blocked until a persistent
  level RETURN exists.
- Generated `UltraRouter.v` still records `AnchorDelayValue(0)`,
  `RoundCloseDelayValue(0)`, `FinalBuilderDelayValue(0)`,
  `MembershipDelayValue(0)`, Return `DelayValue(1)`, Commit Dfire
  `DelayValue(1)`.  Controller SHA-256 remains `32308c4cd7…`.
  Membership cell SHA-256 `3c79fb2abb…`.
- Local structural suite PASSed: Atomic V2 (membership-cell smoke
  included) plus seven Router boundary cases and all 20 isolated
  H/B/T edge samples.

### Remote Router DC/SDF — `20260815_r4a_router`

- Jobs: DC `11251501`, SDF `11251601`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260815_r4a_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts
  unchanged from occupancy/ANCST0: HeadCapture DEL250=0 / hierarchy=5;
  Anchor DEL250=0 / hierarchy=1; MembershipClose DEL250=0 /
  hierarchy=4; FinalBuilder DEL250=0 / hierarchy=1; RoundClose
  DEL250=0 / hierarchy=1; Return DEL250=1; Commit Dfire DEL250=1;
  Commit Ack DEL250=0.
- **SDF PASS on every requested case.**  Annotation completed (`Done`,
  no `IFNSDFA`).  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260815_r4a_head_timing`

- Observation-only SDF rerun reused the signed R4a netlist
  (`ULTRA_NETLIST_RUN_ID=20260815_r4a_router`).  Job `11251901`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | occupancy §26 | R4a merge | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.693 | 0.693 | 0.110 |
  | Mutex5 grant | 1.134 | 1.134 | 0.441 |
  | anchorStart | 1.347 | 1.347 | 0.213 |
  | roundBusy | 1.434 | 1.434 | 0.087 |
  | RoundClose | 1.520 | 1.520 | 0.086 |
  | membershipN_closed | 1.740 | 1.739 | 0.219 |
  | FinalBuilder ready | 1.703 | 1.703 | — |
  | Transaction valid | 1.829 | 1.829 | 0.090 |
  | ACG fire | 2.245 | 2.245 | 0.416 |
  | ReqOut | 2.899 | 2.899 | 0.654 |

- `ReqIn→ReqOut` is **2.899 ns** (unchanged vs occupancy decode).  The
  merge is not on the Head forward path.

### Remote NoC16 async-boundary p50 — `20260815_r4a_asyncnoc16_p50`

- Jobs: DC `11252401`, TAB SDF `11252901`, VCTM SDF `11253001`.
  Endpoint Ack remains environment DEL075.  Summary:
  `scripts/asic_dc/ultra/results/20260815_r4a_asyncnoc16_p50/summary.json`.
  Reused the existing remote p50 cases; none were regenerated.
- **DC PASS:** `ULTRA_BOUNDARY_DC_PASS`, `GTECH=0`.
  HC/MEM/FB/RC/CACK DEL250=0 with retained hierarchy.
- **SDF PASS**, annotation `Done`, no `IFNSDFA`, zero missing /
  unexpected / timeout:

  | case | injected | delivered | missing / unexpected / timeout |
  |---|---:|---:|---|
  | TAB-NET-UR-3f-r0p50 | 3000 | 3000 | 0 / 0 / 0 |
  | VCTM-MC5-NM-3f-r0p50 | 3000 | 3366 | 0 / 0 / 0 |

- **Decision:** R4a is accepted as the new SYNTH-CLOSED membership
  equation on
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Head stays 2.899 ns.  Do not proceed to R4b/R4c on pulse
  `round_reset`.  Do not retry the §27 completion tree.  This is not
  PHYS-CLOSED.

## 29. R3b — RETURN level handshake with request-cone Delay

### 2026-08-15 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed equation + role:** replace `round_reset = DEL(fire)`
  with a level RETURN handshake on the accepted R4a / ANCST0 baseline
  (§28).  Profile stays
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Return `DelayValue` stays 1; `return_margin.I` moves from `fire` to
  `requestConeStart`.  No RET0 profile.  No owner recode.  CACK0 /
  Dfire / R4a `memberAccepted` / empty_skip / cell C2 unchanged.
  `acg_empty` is not a completion event.

- Handshake (avoid §27's `acg_empty` / global one-hot / RET0):

  `returnReq = sticky(fire)`

  `acg_start = tx_valid & ~returnReq`

  `tx_valid` cleared only by `clear_tx`, not by `fire`

  `commitVisible` compares frozen `tx_winner` / `tx_mask*` / `tx_release`
  against live `packet_active` / `outputOwner` / `packet_present`

  `commitCoreDone = returnReq & ~fire & commitVisible`

  `cleanupReq = commitCoreDone & ~cleanupDone`  (short phase; builder only)

  `requestConeStart = commitCoreDone & cleanupDone`

  `requestConeReady = DEL250(requestConeStart)`

  Three-step clear: `tx_valid`, then `returnReq`, then `round_busy`

- Local structural suite PASSed: Atomic V2 (controller checks
  `commitVisible` before RETURN and a second admission) plus seven
  Router boundary cases and all 20 isolated H/B/T edge samples.
  Controller SHA-256 `03e38a10e9…`.

### Remote Router DC/SDF — `20260815_r3b_router`

- Jobs: DC `11256101`, SDF `11256201`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260815_r3b_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Mapped role counts:
  HeadCapture DEL250=0 / hierarchy=5; Anchor DEL250=0 / hierarchy=1;
  MembershipClose DEL250=0 / hierarchy=4; FinalBuilder DEL250=0 /
  hierarchy=1; RoundClose DEL250=0 / hierarchy=1; Return DEL250=1 /
  hierarchy=2; Commit Dfire DEL250=1; Commit Ack DEL250=0.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  X-free.
  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- Failure signature is the same as RETH0 (§23) and §27: the first
  packet(s) complete; a later overlap/release round never produces its
  next ReqOut.  Isolated Heads pass.  Head timing and NoC16 were **not**
  run on this netlist.

- **Decision:** revert this round only (handshake equation, `acg_start`
  port, controller smoke).  R4a membership merge and occupancy decode
  are restored; controller SHA-256 is again `32308c4cd7…`.  Local
  structural suite PASSed after the revert.  Return remains
  `DEL(fire)` / DEL250.
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  remains the SYNTH-CLOSED profile.  Moving the existing Return DEL
  later and sensing frozen-tx `commitVisible` did not cover the
  overlap/release reopen.  Do not stack a compensating DEL on this
  failed candidate.  Do not retry §27 or this §29 equation.  This is
  not PHYS-CLOSED.

- **Post-mortem (gate-level):** the first-order R3b defect was not
  `requestConeReady=DEL250(requestConeStart)` being too short.  DC
  rewrote occupancy into a follower of the ANCST0 wire:

  `busy_latch.en = anchor_start`, `busy_latch.d = anchor_captured`

  With `anchor_start = anchor_captured`, RETURN cleanup drops D and E
  together (SDF 0 ps).  The latch SETUP(negedge D, negedge E) is about
  20 ps, so `round_busy` holds 1 and `arb_req` never reopens.  Evidence:
  `tmp/r3b_inspect/outputs/20260815_r3b_router/UltraRouter_post.v:5114`.
  The next Return attempt must give `round_busy` an independent held
  clear (`E=1, D=0`) that DC cannot fold back into `E=D=captured`.

## 30. R3c — independent `clearBusyReq` handshake

### 2026-08-15 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed equation:** keep the §29 level RETURN, but stop
  treating `round_busy` as a follower of `anchor_captured`.  Profile
  stays `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Return `DelayValue` stays 1.  No extra cone DEL.  No RET0.  No owner
  recode.  `acg_empty` is not a completion event.

- Intended occupancy / RETURN order:

  `busy_en = anchor_captured | clearBusyReq`

  `busy_d = clearBusyReq ? 0 : 1`  (D is not a function of captured)

  `clearBusyReq = sticky(requestConeReady)` until `busyCleared`

  `busyCleared = clearBusyReq & !round_busy`

  `fire → returnReq → Start=0 → commitVisible → cleanup →`
  `requestConeReady → clearBusyReq → round_busy=0 → clear tx_valid →`
  `clear returnReq last`

  `anchor_start` stays off `busy_latch.E` so ANCST0 cannot rewrite the
  latch into the R3b follower.

- Local structural suite PASSed: Atomic V2 (frozen tx, `commitVisible`,
  second admission) plus seven Router boundary cases and all 20
  isolated H/B/T edge samples.  Uploaded controller SHA-256
  `0fe34fbeba…`.

### Remote Router DC/SDF — `20260815_r3c_router`

- Jobs: DC `11264001`, SDF `11264101`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260815_r3c_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Return DEL250 remains 1.
  Occupancy was **not** folded this time.  The mapped controller has:

  `busy_en = OR(anchor_captured, clearBusyReq)`

  `busy_d = ~clearBusyReq`

  `clear_busy_req_latch` and `return_req_latch` are both present.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  X-free.
  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- Same signature as RETH0 / §27 / §29: first packet(s) complete; a
  later overlap/release round never produces its next ReqOut.  Isolated
  Heads pass.  Head timing and NoC16 were **not** run.

- **Decision:** revert this round only (handshake equation, `acg_start`
  port, controller smoke).  R4a membership merge and occupancy decode
  are restored; controller SHA-256 is again `32308c4cd7…`.  Local
  structural suite PASSed after the revert.  Return remains
  `DEL(fire)` / DEL250.
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  remains the SYNTH-CLOSED profile.  The R3b busy-latch fold was real
  and this netlist fixed it, but an independent `clearBusyReq` was not
  enough: RETURN still does not finish in strict SDF, so Mutex5 never
  sees the second `arb_req`.  The remaining defect is earlier in the
  handshake (`commitVisible` / `cleanupDone` / `requestConeReady` /
  `returnReq` drop), not another missing cone Delay.  Do not stack a
  compensating DEL.  Do not retry §27, §29, or this §30 equation.
  This is not PHYS-CLOSED.

## 31. Dfire measurement — `tx Q → fire` vs `Start → fire`

### 2026-08-15 — observation only; DelayValue unchanged

- **No DelayValue change.**  Profile remains
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Commit Dfire stays DEL250.  Return stays `DEL(fire)`.  R4a
  `memberAccepted` and occupancy decode are unchanged.  This round
  only added observation probes and measured the frozen R4a netlist.
- Boundary TB (`ULTRA_TRACE_HEAD_TIMING`) now records the Commit RTC
  with Start/`tx_valid` as the common reference: last
  `tx_winner` / `tx_mask0` / `tx_release` Q, `Dfire.I`, `Dfire.Z`,
  and `TB_DFIRE_WINDOW` / `TB_RTC_SAMPLE rtc=ACG_DFIRE_COMMIT`.
  The probes do not participate in handshake decisions.
- Local structural `unicast3` PASSed with the new probes.  Behavioral
  sim numbers are not the measurement.
- Observation-only SDF+STA `20260815_r4a_dfire_measure` reused
  `ULTRA_NETLIST_RUN_ID=20260815_r4a_router`.  Jobs: SDF `11267001`,
  STA `11267101`.  Annotation `Done`, no `IFNSDFA`.  `TB_RESULT PASS
  unicast3`.  Head `ReqIn→ReqOut` remains **2.899 ns**.
- CSV/JSON:
  `docs/timing_baselines/20260815_r4a_dfire_measure.csv`,
  `docs/timing_baselines/20260815_r4a_dfire_measure.json`.
  Extractor: `scripts/asic_dc/ultra/extract_ultra_dfire_rtc.py`.

Paired SDF sample (`unicast3` Child0→Parent):

| Event | t_ns | vs ReqIn | vs Start |
|---|---:|---:|---:|
| last `tx_mask0` Q | 30.921 | 0.721 | −1.108 |
| last `tx_winner` Q | 31.559 | 1.359 | **−0.470** |
| Start / `Dfire.I` | 32.029 | 1.829 | 0.000 |
| `Dfire.Z` / fire | 32.445 | 2.245 | **0.416** |
| Active_commit Q | 32.522 | 2.322 | 0.493 |

- `Tdata` from Start = **0 ps** (Q last-changes 470 ps before Start;
  `DATA_PRECEDES`).
- `Tctrl_min` Start→fire = **416 ps**.
- `Tdfire` I→Z = **416 ps**.  The entire control interval is the
  DEL250 cell; Start→`Dfire.I` is 0 ps at this corner.
- Residual Start→fire after removing Dfire = **0 ps**.
- STA Q→D pin reports are `NO_PATH` (mapped DFF names).  Static
  Start→fire reports are reset/loop paths and remain
  `NOT_COMPARABLE_STATIC`.  The SDF same-reference sample is the
  measurement.

- **Decision:** do **not** set Dfire `DelayValue=0`.  Residual
  control after deleting the cell is 0 ps, so a zero-delay fire has
  no intentional pulse or Q→D window.  The 250 ps cell is
  overdesigned relative to Tdata-from-Start (Q already frozen), but
  the next single-role Head experiment is a **DEL150 derate** or a
  Start→fire `set_min_delay` of at least the 80 ps conservative
  floor — not DEL0.  Do not mix this with RETURN.  Profile and Head
  2.899 ns stay unchanged.  This is not PHYS-CLOSED.

## 32. DFIRE0 — DC `set_min_delay` replacement of Commit Dfire

### 2026-08-15 — constraint bound; Tctrl below floor; keep ANCST0

- **Single-role experiment.**  New profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE0`
  bypasses only `UltraArbiterCommit` (`DelayValue=0`).  Return and
  PRS stay DEL250.  No P&R.  No DEL150 derate.
- DC overlay
  [`async_ultra_router_dfire_control.sdc`](../scripts/asic_dc/ultra/async_ultra_router_dfire_control.sdc)
  applies `set_min_delay 0.080` / `set_max_delay 0.160` on
  `commitController/Start` → `fire_o`.  `fire_o_Dfire` dont_touch is
  released; other DelayElement hierarchies stay protected.
- Local structural `unicast3` PASSed (behavioral `#0` Dfire; not
  signoff).
- Remote full DC → func → SDF → STA `20260815_r4a_dfire0`.  Jobs:
  DC `11267601`, func `11267701`, SDF `11267801`, STA `11267901`.
  `ULTRA_DC_PASS`, GTECH=0.  SDF annotation `Done`, no `IFNSDFA`.
  `TB_RESULT PASS unicast3`.  STA `DEL250_COUNT=6` (PRS×5 + Return×1).

DC audit:

| Check | Result |
|---|---|
| pin bind | `from=1 to=1` |
| min/max applied | 0.080 / 0.160 ns |
| Dfire dont_touch release | 1 hierarchy |
| Dfire DEL250 | 0 |
| ordinary cells under `fire_o_Dfire` | **0** |

Paired SDF sample (`unicast3` Child0→Parent):

| Event | t_ns | vs ReqIn | vs Start |
|---|---:|---:|---:|
| last `tx_mask0` Q | 30.921 | 0.721 | −1.161 |
| last `tx_winner` Q | 31.559 | 1.359 | **−0.523** |
| Start / `Dfire.I` / `Dfire.Z` / fire | 32.082 | 1.882 | **0.000** |
| Active_commit Q | 32.158 | 1.958 | 0.076 |
| ReqOut | 32.735 | **2.535** | 0.653 |

- `Tdata` from Start = **0 ps** (Q last-changes 523 ps before Start).
- `Tctrl_min` Start→fire = **0 ps**.
- `Tdfire` I→Z = **0 ps**.  The bypassed cell is a wire; DC did not
  insert buffers on this async / ZeroWireload path.
- Head `ReqIn→ReqOut` = **2.535 ns** (−364 ps vs R4a 2.899 ns).
- Extractor `--synth-replace`:
  `docs/timing_baselines/20260815_r4a_dfire0.{json,csv}` →
  **`REJECT_SYNTH_REPLACE`**.

- **Decision:** do **not** accept DFIRE0.  The constraint bound, but
  `compile_ultra` left `Tctrl=0`, below the 80 ps Q→D / pulse floor.
  `unicast3` PASSed at this typical SDF corner because the transaction
  Q was already frozen, yet that is not a closed RTC.  Keep accepted
  profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  and Head **2.899 ns**.  Do not fall back to a DEL150 derate and do
  not mix this with RETURN.  The next Dfire attempt stays on the
  synthesis side: incremental `insert_buffer` / a second compile that
  actually realizes the 80 ps min-delay on `Start→fire`.  After Dfire
  closes, the next constraint-replaceable Head role is **PRS ×5**.
  This is not PHYS-CLOSED.

### Remote Router five-case SDF — `20260815_r4a_dfire0_smoke5`

- Reused frozen DFIRE0 netlist
  (`ULTRA_NETLIST_RUN_ID=20260815_r4a_dfire0`).  Job `11268901`.
  Annotation `Done`, no `IFNSDFA`.  Archive:
  `scripts/asic_dc/ultra/results/20260815_r4a_dfire0_smoke5/`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- Single-packet Heads can complete with `Tctrl=0`.  Overlap / release /
  second-transaction cases time out, which is the functional counterpart
  of the missing fire pulse.  This confirms **REJECT_SYNTH_REPLACE**.
  NoC16 p50 is not a reason to accept DFIRE0; it is only extra evidence.

## 33. DFIRE150 — single-role DEL150 derate of Commit Dfire

### 2026-08-16 — timing closed at 264 ps; three-case overlap still fails

- **Single-role experiment.**  New profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE150`
  keeps `UltraArbiterCommit` as a real T28 DEL150
  (`DelayValue=1`, `DelayUnitPs=150`).  Return and PRS stay DEL250.
  No P&R.  No DFIRE0.
- DC/STA: [run_dc_ultra_router.tcl](../scripts/asic_dc/ultra/run_dc_ultra_router.tcl)
  counts `DEL150D1*`; dont_touch release remains DFIRE0-only.  The
  Start→fire overlay was applied as a guard
  (`min_ns=0.080 max_ns=0.160`); the physical delay comes from the
  DEL150 cell.
- Local five-case structural smoke PASSed.
- Remote `20260816_r4a_dfire150`: jobs DC `11282301`, func `11282401`,
  SDF `11282501`, STA `11282601`.  `ULTRA_DC_PASS`, `GTECH=0`,
  `ULTRA_ARBITER_ROLE=CommitDfire EXPECTED_DELAY=1 ACTUAL_DELAY=1
  REF=DEL150D1*`.  SDF annotation `Done`, no `IFNSDFA`.
- Extractor `--synth-derate` on `unicast3`: Tdata from Start = 0 ps
  (`tx_winner` Q 470 ps before Start), **Tctrl Start→fire = 264 ps**,
  `Tdfire` I→Z = 264 ps.  Head `ReqIn→ReqOut` = **2.746 ns**
  (−153 ps vs R4a 2.899 ns).  This meets the 80 ps floor, but the
  profile is **not accepted** because the overlap smoke fails.

| Case | Result |
|---|---|
| `unicast3` | PASS |
| `mc_single3` | PASS |
| `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
| `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
| `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- **Decision:** keep accepted profile
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`,
  Head **2.899 ns**.  The failure set is identical to DFIRE0, so the
  264 ps fire pulse is not the missing condition.  The next step is to
  debug why the second transaction never re-arms / completes after
  overlap (Return / reopen path), not to push Dfire further.  Do not
  mix this with PRS.  This is not PHYS-CLOSED.

## 34. R3d — RETURN teardown without cleanupDone gating

### 2026-08-16 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed equation:** keep the R3c independent `clearBusyReq`
  busy structure, but stop gating `clear_tx` on `cleanupDone`.
  `cleanupReq` is held until `clearBusyReq` rises;
  `requestConeStart = commitCoreDone` (no `cleanupDone` factor);
  `clear_tx = busyCleared & returnReq & ~fire`.  Profile stays
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Return `DelayValue` stays 1.  No RET0.  No owner recode.
- Local structural suite PASSed: Atomic V2 (frozen tx, `commitVisible`,
  second admission) plus seven Router boundary cases and all 20
  isolated H/B/T edge samples.  Uploaded controller SHA-256
  `866fdf24b7…`.

### Remote Router DC/SDF — `20260816_r3d_router`

- Jobs: DC `11283701`, SDF `11283801`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260816_r3d_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Return DEL250 remains 1.
  The mapped controller keeps the intended busy structure:
  `busy_en = OR(anchor_captured, clearBusyReq)`,
  `busy_d = ~clearBusyReq`, and both `return_req_latch` /
  `clear_busy_req_latch` are present.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  X-free.
  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- **First SDF evidence of the busy-latch setup violation.**  Every
  packet’s RETURN produces:

  `$setup( posedge D:33870, negedge E &&& CDN_SDFCHK:33876, limit: 14 )`

  on `dut.admission.tx.busy_latch.resettable_latch[0].latch_cell`.
  The accepted R4a netlist does not emit this check.  In R3d, after
  `busyCleared` drops `round_busy`, `clear_tx` clears `tx_valid`,
  `clear_returnReq` drops `returnReq`, and `clearBusyReq` then falls.
  `busy_d = ~clearBusyReq` returns to 1 through an inverter while
  `busy_en = anchor_captured | clearBusyReq` closes through an OR;
  the D rise arrives only ~6 ps before the E fall, violating the
  latch’s 14 ps setup-to-close requirement.  The Mutex reopens
  combinationally (`~round_busy & ~returnReq`) while the latch is
  still metastable, so the next `admit_set` can be missed and the
  second transaction never re-arms.

- **Decision:** revert this round only (handshake equation, `acg_start`
  port, controller smoke).  R4a membership merge and occupancy decode
  are restored; controller SHA-256 is again `32308c4cd7…`.  Local
  structural suite PASSed after the revert.  Return remains
  `DEL(fire)` / DEL250.
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  remains the SYNTH-CLOSED profile.  Do not stack a compensating DEL
  on this failed candidate.  Do not retry §27, §29, §30, or this §34
  equation.  The next RETURN attempt must keep `busy_d` at 0 until
  after the latch is safely opaque, or use a two-phase clear that
  separates `round_busy` fall from `clearBusyReq` fall.  This is not
  PHYS-CLOSED.

## 35. R3e — hold `clearBusyReq` until `fire` falls

### 2026-08-16 — local structural PASSed; remote Router SDF FAIL; reverted

- **Single changed equation:** keep the §34 RETURN order, but release
  `clearBusyReq` only after `fire` has fallen:

  `clear_busy_req_latch.en = requestConeReady | (~returnReq & clearBusyReq & ~fire) | anchor_start`

  The intent was to use the ACG Dfire low pulse (~250 ps) as the busy
  latch's setup-to-close margin.  Profile stays
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`.
  Return `DelayValue` stays 1.  No RET0.  No owner recode.
- Local structural suite PASSed: Atomic V2 (frozen tx, `commitVisible`,
  second admission) plus seven Router boundary cases and all 20
  isolated H/B/T edge samples.  Uploaded controller SHA-256
  `6b5da22d35…`.

### Remote Router DC/SDF — `20260816_r3e_router`

- Jobs: DC `11285801`, SDF `11285901`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260816_r3e_router/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.  Return DEL250 remains 1.
- **SDF FAIL.**  Annotation completed (`Done`, no `IFNSDFA`).  X-free.
  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | FAIL `target_output_timeout` in=10001 out=00011 |
  | `uc_overlap_release3` | FAIL `target_output_timeout` in=00011 out=10000 |
  | `mc_overlap_tailjoin3` | FAIL `target_output_timeout` in=10100 out=00011 |

- The busy-latch violation is **unchanged**:

  `$setup( posedge D:33762, negedge E &&& CDN_SDFCHK:33766, limit: 15 )`

  Gating the `clearBusyReq` release on `~fire` moved **when**
  `clearBusyReq` falls but cannot change the D/E skew at the busy
  latch: `busy_d = ~clearBusyReq` rises through the inverter and
  `busy_en = anchor_captured | clearBusyReq` falls through the OR off
  the *same* source edge, so posedge D still leads negedge E by only
  ~4 ps.  With `+no_notifier` the transparent window samples D=1
  before E closes, so `round_busy` recaptures 1 at the end of every
  RETURN and the Mutex never sees the second `arb_req`.

- **Decision:** revert this round only (handshake equation, `acg_start`
  port, controller smoke).  R4a membership merge and occupancy decode
  are restored; controller SHA-256 is again `32308c4cd7…`.  Local
  structural suite PASSed after the revert.  Return remains
  `DEL(fire)` / DEL250.
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0`
  remains the SYNTH-CLOSED profile.  Do not stack a compensating DEL.
  Do not retry §27, §29, §30, §34, or this §35 equation.  The defect
  is structural: `busy_d` must **stay 0** while `busy_en` closes
  (R4a's `busy_d = anchor_captured & ~round_reset` never rises around
  the closing edge).  The next RETURN attempt must drive
  `busy_d = set_round & ~clearBusyReq` and order anchor cleanup while
  `clearBusyReq` still holds `busy_en` high, so neither the closing
  nor the clearing edge ever coincides with a D transition.  This is
  not PHYS-CLOSED.

## 36. R3f — safe busy clear and four-phase RETURN acknowledgement

### 2026-08-16 — local structural PASS; remote Router strict-SDF PASS

- **Root-cause correction.**  The occupancy latch no longer uses
  `busy_d=~clearBusyReq`.  Its mapped protocol is now:

  ```text
  busy_en = set_round | clearBusyReq | anchor_start
  busy_d  = set_round & ~clearBusyReq
  ```

  `clearBusyReq` rises before anchor cleanup and remains asserted while the
  anchor, builder and transaction state are cleared.  Consequently
  `set_round=0` before `clearBusyReq` falls; the busy latch closes with D
  continuously at zero.  This removes the R3d/R3e `posedge D / negedge E`
  setup-to-close race structurally rather than delaying the same unsafe fork.

- **RETURN protocol.**  Transaction Q remains frozen by `commit_seen` after
  fire.  The new level sequence is:

  ```text
  fire -> commit_seen
       -> commit_visible(active/present/owner versus frozen tx Q)
       -> clearBusyReq -> busy_cleared
       -> round_reset clears anchor/membership/transaction-valid state
       -> cleanup_done
       -> Return DEL250(request_cone_start) -> request_cone_ready
       -> sticky return_ack
       -> clear commit_seen and clearBusyReq
       -> return_ack drops last -> Mutex request boundary reopens
  ```

  `arb_req` is gated by `~round_busy & ~commit_seen & ~clearBusyReq &
  ~return_ack`; therefore lowering `round_busy` during RETURN cannot expose a
  partially cleaned request cone to Mutex5.  Return DEL250 is retained, but it
  now protects only the post-cleanup request cone instead of directly driving
  every round reset.

- Transaction payload latches now remain closed through `commit_seen` and
  `return_ack`, so `commit_visible` always compares live state with the exact
  transaction consumed by fire.  The controller smoke was extended with a
  second disjoint Head already pending at the first fire; it must remain
  blocked during RETURN and become the unique second transaction afterward.

### Local verification

- `sbt compile` and Atomic/UltraRouter elaboration PASS.
- DecisionCell, MembershipCell, HeadCapture, TransactionController and Atomic
  V2 structural smoke PASS.
- Seven Router boundary cases and the 20-edge H/B/T suite PASS.
- Controller SHA-256:
  `cad6648bd6ba6321e0ea3720eb02c8069be8792edccc5c135637937a94fb1d22`.

### Remote Router DC/SDF — `20260816_r3f_router`

- Jobs: DC `11287301`, SDF `11287401`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`; Return DEL250 remains one physical
  instance.  The mapped controller retains separate `busy_latch`,
  `clear_busy_req_latch`, and `return_ack_latch`.
- **Strict SDF PASS:** annotation completed, no `IFNSDFA`, X-free, and no
  busy-latch `$setup/$hold` warning in any case.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

- The previous signature—first packet completes and the second round never
  emits ReqOut—is eliminated.  In `uc_overlap_release3`, packet 4 completes
  at 36.950 ns and packet 5 completes at 45.950 ns.  In
  `mc_overlap_tailjoin3`, packet 6 completes at 38.450 ns and packet 7 at
  47.750 ns.
- Archive:
  `scripts/asic_dc/ultra/results/20260816_r3f_router/`.
- **Decision:** R3f is accepted for the single-Router SYNTH-CLOSED Return
  boundary.  No NoC16 regression or post-route claim is made in this round.

### Unified asynchronous NoC16 p50 — `20260816_r3f_asyncnoc16_p50`

- Regenerated `NoC_16nodes` from the accepted R3f controller and synthesized
  `AsyncNoC16BoundaryDUT` as one top-level netlist/SDF.  The structural sink
  Ack environment remains DEL075.
- DC job `11287501`; TAB SDF `11287901`; VCTM SDF `11288001`.
- Both strict-SDF cases annotated successfully with no `IFNSDFA`:

  | Case | Injected | Delivered | Missing / unexpected / timeout |
  |---|---:|---:|---|
  | `TAB-NET-UR-3f-r0p50` | 3000 | 3000 | 0 / 0 / 0 |
  | `VCTM-MC5-NM-3f-r0p50` | 3000 | 3366 | 0 / 0 / 0 |

- Controller manifest SHA-256 is the same R3f value
  `cad6648bd6ba6321e0ea3720eb02c8069be8792edccc5c135637937a94fb1d22`.
  No trace/debug plusarg was enabled.  The R3f RETURN handshake therefore
  closes both the directed second-round Router cases and sustained p50
  unicast/native-multicast traffic in the unified asynchronous platform.
- Summary:
  `scripts/asic_dc/ultra/results/20260816_r3f_asyncnoc16_p50/summary.json`.
- **Updated decision:** R3f is accepted as the current pre-layout /
  SYNTH-CLOSED Return baseline for Router and NoC16 p50.  It is not a
  PHYS-CLOSED or RTM10 signoff.

### Head timing on the frozen R3f netlist — `20260816_r3f_head_timing`

- Observation-only SDF rerun reused the signed R3f netlist
  (`ULTRA_NETLIST_RUN_ID=20260816_r3f_router`).  Job `11288601`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.  DelayValue unchanged.
- Head cumulative delay from ReqIn:

  | Boundary | R4a §28 | R3f | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.693 | 0.695 | 0.112 |
  | Mutex5 grant | 1.134 | 1.079 | 0.384 |
  | anchorStart | 1.347 | 1.302 | 0.223 |
  | roundBusy | 1.434 | 1.392 | 0.090 |
  | RoundClose | 1.520 | 1.454 | 0.062 |
  | membershipN_closed | 1.740 | 1.669 | 0.215 |
  | FinalBuilder ready | 1.703 | 1.636 | — |
  | Transaction valid | 1.829 | 1.733 | 0.064 |
  | ACG fire | 2.245 | 2.145 | 0.412 |
  | ReqOut | 2.899 | 2.799 | 0.654 |

- `ReqIn→ReqOut` is **2.799 ns** (−0.100 ns vs R4a).  Dfire remains
  DEL250 (`Tctrl` Start→fire = 412 ps).  The first-Head gain is from
  a shorter Mutex5/BUILD cone, not from Return DEL.  This is the Head
  number to beat with DFIRE150 on the same R3f handshake.

## 37. DFIRE150 on the accepted R3f handshake

### 2026-08-16 — local structural PASSed; remote Router SDF and Head PASSed

- **Single changed role.**  Keep the accepted R3f controller
  (SHA-256 `cad6648b…`) and stack only
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE150`.
  `UltraArbiterCommit` is a real T28 DEL150 (`DelayValue=1`,
  `DelayUnitPs=150`).  Return stays DEL250 on the post-cleanup
  request cone.  PRS stays DEL250.  No DFIRE0.  No R4b/R4c/R5.
- The earlier DFIRE150 on R4a (§33) closed Start→fire at 264 ps but
  failed overlap because RETURN could not reopen.  R3f supplies that
  reopen, so this is a retry of the derate only.
- Generated `UltraRouter.v` records `fire_o_Dfire DelayUnitPs(150)
  DelayValue(1)` and `ReturnDelayValue(1)`.
- Local structural suite PASSed: Atomic V2 plus seven Router boundary
  cases and all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260816_r3f_dfire150`

- Jobs: DC `11288801`, SDF `11288901`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260816_r3f_dfire150/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.
  `ULTRA_ARBITER_ROLE=CommitDfire EXPECTED_DELAY=1 ACTUAL_DELAY=1
  REF=DEL150D1*`.  Return DEL250 remains.  Commit Ack DEL250=0.
- **SDF PASS on every requested case.**  Annotation `Done`, no
  `IFNSDFA`.  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260816_r3f_dfire150_head`

- Observation-only SDF reused
  `ULTRA_NETLIST_RUN_ID=20260816_r3f_dfire150`.  Job `11289001`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | R3f DEL250 | DFIRE150 | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.695 | 0.695 | 0.112 |
  | Mutex5 grant | 1.079 | 1.079 | 0.384 |
  | anchorStart | 1.302 | 1.302 | 0.223 |
  | roundBusy | 1.392 | 1.392 | 0.090 |
  | RoundClose | 1.454 | 1.454 | 0.062 |
  | membershipN_closed | 1.669 | 1.669 | 0.215 |
  | FinalBuilder ready | 1.636 | 1.636 | — |
  | Transaction valid | 1.733 | 1.733 | 0.064 |
  | ACG fire | 2.145 | 1.978 | 0.245 |
  | ReqOut | 2.799 | 2.632 | 0.654 |

- `ReqIn→ReqOut` is **2.632 ns** (−0.167 ns vs R3f Head 2.799,
  −0.267 ns vs R4a 2.899).  `Tctrl` Start→fire = **245 ps**,
  `Tdfire` I→Z = 245 ps, Tdata-from-Start = 0 ps (winner Q 415 ps
  before Start).  The 80 ps floor is met.  The entire fire-interval
  reduction is the DEL150 cell.

- **Decision:** accept
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE150`
  as the new SYNTH-CLOSED profile on the R3f handshake.  Head is
  2.632 ns.  Do not retry DFIRE0.  Do not mix R4b (drop cell C2) into
  this derate; R4b remains a later, separate equation.  R4c / R5 stay
  deferred.  This is not PHYS-CLOSED.

## 38. DFIRE100 on the accepted R3f handshake

### 2026-08-16 — local structural PASSed; remote Router SDF and Head PASSed

- **Single changed role.**  Keep the accepted R3f controller
  (SHA-256 `cad6648b…`) and stack only
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE100`.
  `UltraArbiterCommit` is a real T28 DEL100 (`DelayValue=1`,
  `DelayUnitPs=100`).  Return stays DEL250 on the post-cleanup
  request cone.  PRS stays DEL250.  No DFIRE0.  No R4b/R4c/R5.
- Generated `UltraRouter.v` records `fire_o_Dfire DelayUnitPs(100)
  DelayValue(1)` and `ReturnDelayValue(1)`.
- Local structural suite PASSed: Atomic V2 plus seven Router boundary
  cases and all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260816_r3f_dfire100`

- Jobs: DC `11289401`, SDF `11289501`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260816_r3f_dfire100/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.
  `ULTRA_ARBITER_ROLE=CommitDfire EXPECTED_DELAY=1 ACTUAL_DELAY=1
  REF=DEL100D1*`.  Return DEL250 remains.  Commit Ack DEL250=0.
- **SDF PASS on every requested case.**  Annotation `Done`, no
  `IFNSDFA`.  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260816_r3f_dfire100_head`

- Observation-only SDF reused
  `ULTRA_NETLIST_RUN_ID=20260816_r3f_dfire100`.  Job `11289701`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | DFIRE150 | DFIRE100 | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.695 | 0.695 | 0.112 |
  | Mutex5 grant | 1.079 | 1.079 | 0.384 |
  | anchorStart | 1.302 | 1.302 | 0.223 |
  | roundBusy | 1.392 | 1.392 | 0.090 |
  | RoundClose | 1.454 | 1.454 | 0.062 |
  | membershipN_closed | 1.669 | 1.669 | 0.215 |
  | FinalBuilder ready | 1.636 | 1.636 | — |
  | Transaction valid | 1.733 | 1.733 | 0.064 |
  | ACG fire | 1.978 | 1.898 | 0.165 |
  | ReqOut | 2.632 | 2.551 | 0.653 |

- `ReqIn→ReqOut` is **2.551 ns** (−0.081 ns vs DFIRE150 2.632,
  −0.248 ns vs R3f 2.799).  `Tctrl` Start→fire = **165 ps**,
  `Tdfire` I→Z = 165 ps, Tdata-from-Start = 0 ps (winner Q 415 ps
  before Start).  The 80 ps floor is met.  Extractor
  recommendation: `ACCEPT_DEL_DERATE`.  The entire fire-interval
  reduction is the DEL100 cell.

- **Decision:** accept
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE100`
  as the new SYNTH-CLOSED profile on the R3f handshake.  Head is
  2.551 ns.  Do not retry DFIRE0.  Do not mix R4b (drop cell C2)
  into this derate.  R4c / R5 stay deferred.  This is not
  PHYS-CLOSED.

## 39. DFIRE50 on the accepted R3f handshake

### 2026-08-16 — local structural PASSed; remote Router SDF and Head PASSed

- **Single changed role.**  Keep the accepted R3f controller
  (SHA-256 `cad6648b…`) and stack only
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50`.
  `UltraArbiterCommit` is a real T28 DEL050 (`DelayValue=1`,
  `DelayUnitPs=50`).  Return stays DEL250 on the post-cleanup
  request cone.  PRS stays DEL250.  No DFIRE0.  No R4b/R4c/R5.
- The sizing table projected DEL050 at 75 ps, below the 80 ps floor.
  This run measures the mapped cell instead of trusting the nominal
  table.  Generated `UltraRouter.v` records `fire_o_Dfire
  DelayUnitPs(50) DelayValue(1)` and `ReturnDelayValue(1)`.
- Local structural suite PASSed: Atomic V2 plus seven Router boundary
  cases and all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260816_r3f_dfire50`

- Jobs: DC `11294401`, SDF `11294501`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260816_r3f_dfire50/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.
  `ULTRA_ARBITER_ROLE=CommitDfire EXPECTED_DELAY=1 ACTUAL_DELAY=1
  REF=DEL050D1*`.  Return DEL250 remains.  Commit Ack DEL250=0.
- **SDF PASS on every requested case.**  Annotation `Done`, no
  `IFNSDFA`.  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260816_r3f_dfire50_head`

- Observation-only SDF reused
  `ULTRA_NETLIST_RUN_ID=20260816_r3f_dfire50`.  Job `11294701`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.
- Head cumulative delay from ReqIn:

  | Boundary | DFIRE100 | DFIRE50 | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.583 | 0.583 |
  | HeadCapture P | 0.695 | 0.695 | 0.112 |
  | Mutex5 grant | 1.079 | 1.079 | 0.384 |
  | anchorStart | 1.302 | 1.302 | 0.223 |
  | roundBusy | 1.392 | 1.392 | 0.090 |
  | RoundClose | 1.454 | 1.454 | 0.062 |
  | membershipN_closed | 1.669 | 1.669 | 0.215 |
  | FinalBuilder ready | 1.636 | 1.637 | — |
  | Transaction valid | 1.733 | 1.734 | 0.065 |
  | ACG fire | 1.898 | 1.831 | 0.097 |
  | ReqOut | 2.551 | 2.486 | 0.655 |

- `ReqIn→ReqOut` is **2.486 ns** (−0.065 ns vs DFIRE100 2.551).
  `Tctrl` Start→fire = **97 ps**, `Tdfire` I→Z = 97 ps,
  Tdata-from-Start = 0 ps (winner Q 416 ps before Start).  The
  mapped DEL050 is 97 ps, not 50 ps and not the 75 ps nominal
  table.  The 80 ps floor is met (margin 17 ps).  Extractor
  recommendation: `ACCEPT_DEL_DERATE`.
- First-Head OPM V2 RTM5 sample reports `shortfall_ns=0.022`
  (`TdataVisible=2.402`, `Tcontrol=2.500`).  Body flits remain
  `shortfall=0`.  This is an OPM window observation, not a Dfire
  floor miss.  Five-case SDF still PASSed.

- **Decision:** accept
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50`
  as the new SYNTH-CLOSED profile on the R3f handshake.  Head is
  2.486 ns.  Commit Dfire has no smaller library cell.  Do not
  retry DFIRE0.  Do not mix R4b.  R4c / R5 stay deferred.  This is
  not PHYS-CLOSED.

## 40. PRS matched-delay paired RTC on frozen DFIRE50

### 2026-08-16 — observation-only `unicast3` SDF, no DelayValue change

- Frozen net `ULTRA_NETLIST_RUN_ID=20260816_r3f_dfire50`.  Observation
  job `20260816_r3f_prs_measure` (SDF `11295301`).  Profile still
  `…_ANCST0_DFIRE50`.  Controller SHA-256 `cad6648b…`.  Membership
  SHA-256 `3c79fb2abb…`.  Annotation `Done`, no `IFNSDFA`.
  `TB_RESULT PASS unicast3`.  Head remains **2.486 ns**.
- `Tdata` is the last stability of ungated RoutingLogic route_valid
  (`_GEN_8` / `decision_projectedDir`), not V1 DataOut, not gated
  `decision_dir`, and not RS.  Common reference is ReqX /
  `matchedDelay.I`.

  | Quantity | Value |
  |---|---:|
  | last ungated `_GEN_8` vs ReqX | −80 ps |
  | last `projectedDir` vs ReqX | −91 ps |
  | `Tdata` from ReqX | **0 ps** |
  | `Tctrl` ReqX→RS | **517 ps** |
  | `Tprs` matchedDelay I→Z | **374 ps** |
  | residual `Tctrl − Tprs` | **143 ps** |
  | required floor | 80 ps |

- Extractor: `SET_MIN_DELAY_NOT_DEL0`.  JSON:
  `docs/timing_baselines/20260816_r3f_prs_measure.json`.
- Residual already covers the 80 ps floor, so `DelayValue=0` is not
  the next experiment (DFIRE0 inserted zero buffers).  All explicit
  derate cells 150/100/75/50 are projected to cover.  Next single-role
  cut is coarsest covering **PRS150**; Commit stays DEL050, Return
  stays DEL250.  Do not mix R4b / Return / OPM / DFIRE0.

## 41. PRS150 single-role derate on the R3f handshake

### 2026-08-16 — local structural PASSed; remote Router SDF and Head PASSed

- **Single changed role.**  Keep the accepted R3f controller
  (SHA-256 `cad6648b…`) and stack only
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS150`.
  `UltraPrsMatched` is a real T28 DEL150 (`DelayValue=1`,
  `DelayUnitPs=150`).  Commit stays DEL050.  Return stays DEL250.
  No PRS0.  No R4b/R4c/R5.  No OPM or Dfire mix.
- Generated `UltraRouter.v` records five
  `matchedDelay DelayUnitPs(150) DelayValue(1)`, `fire_o_Dfire
  DelayUnitPs(50) DelayValue(1)`, and `ReturnDelayValue(1)`.
- Local structural suite PASSed: Atomic V2 plus seven Router boundary
  cases and all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260816_r3f_prs150`

- Jobs: DC `11297401`, SDF `11297501`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260816_r3f_prs150/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.
  `ULTRA_ARBITER_ROLE=PrsMatched EXPECTED_DELAY=5 ACTUAL_DELAY=5
  REF=DEL150D1*`.  Commit Dfire remains DEL050.  Return DEL250
  remains.
- **SDF PASS on every requested case.**  Annotation `Done`, no
  `IFNSDFA`.  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260816_r3f_prs150_head`

- Observation-only SDF reused
  `ULTRA_NETLIST_RUN_ID=20260816_r3f_prs150`.  Job `11297601`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.  Annotated netlist is
  `outputs/20260816_r3f_prs150/UltraRouter.sdf`.
- Head cumulative delay from ReqIn:

  | Boundary | DFIRE50 | PRS150 | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.583 | 0.419 | 0.419 |
  | HeadCapture P | 0.695 | 0.531 | 0.112 |
  | Mutex5 grant | 1.079 | 0.915 | 0.384 |
  | anchorStart | 1.302 | 1.138 | 0.223 |
  | roundBusy | 1.392 | 1.228 | 0.090 |
  | RoundClose | 1.454 | 1.290 | 0.062 |
  | membershipN_closed | 1.669 | 1.505 | 0.215 |
  | FinalBuilder ready | 1.637 | 1.473 | — |
  | Transaction valid | 1.734 | 1.570 | 0.065 |
  | ACG fire | 1.831 | 1.667 | 0.097 |
  | ReqOut | 2.486 | 2.322 | 0.655 |

- `ReqIn→ReqOut` is **2.322 ns** (−0.164 ns vs DFIRE50 2.486).  The
  entire reduction is the PRS interval (0.583 → 0.419).
  `Tctrl` ReqX→RS = **353 ps**, `Tprs` I→Z = **211 ps**,
  Tdata-from-ReqX = 0 ps (ungated `_GEN_8` 80 ps before ReqX).
  Residual 142 ps.  Mapped DEL150 is 211 ps, not 150 ps and not the
  220 ps nominal table.  The 80 ps floor is met.  Extractor
  recommendation: `ACCEPT_DEL_DERATE`.
- First-Head OPM V2 RTM5 shortfall is now **0** (`TdataVisible=2.238`,
  `Tcontrol=2.350`).  This is a side effect of the earlier Head, not
  an OPM change.

- **Decision:** accept
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS150`
  as the new SYNTH-CLOSED profile on the R3f handshake.  Head is
  2.322 ns.  Do not start PRS0.  A later single-role PRS100 remains
  available (projected residual+DEL100 still covers 80 ps).  Do not
  mix R4b.  R4c / R5 stay deferred.  NoC16 p50 is not part of this
  cut.  This is not PHYS-CLOSED.

## 42. PRS50 single-role derate on the R3f handshake

### 2026-08-17 — local structural PASSed; remote Router SDF and Head PASSed

- **Single changed role.**  Keep the accepted R3f controller
  (SHA-256 `cad6648b…`) and stack only
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS50`.
  `UltraPrsMatched` is a real T28 DEL050 (`DelayValue=1`,
  `DelayUnitPs=50`).  Commit stays DEL050.  Return stays DEL250.
  Skipped PRS100/PRS75 at the user's request.  No PRS0.  No
  R4b/R4c/R5.
- Generated `UltraRouter.v` records five
  `matchedDelay DelayUnitPs(50) DelayValue(1)`, `fire_o_Dfire
  DelayUnitPs(50) DelayValue(1)`, and `ReturnDelayValue(1)`.
- Local structural suite PASSed: Atomic V2 plus seven Router boundary
  cases and all 20 isolated H/B/T edge samples.

### Remote Router DC/SDF — `20260817_r3f_prs50`

- Jobs: DC `11315101`, SDF `11315201`.  Stages: `dc,sdf` only.
  Archive: `scripts/asic_dc/ultra/results/20260817_r3f_prs50/`.
- **DC PASS:** `ULTRA_DC_PASS`, `GTECH=0`.
  `ULTRA_ARBITER_ROLE=PrsMatched EXPECTED_DELAY=5 ACTUAL_DELAY=5
  REF=DEL050D1*`.  Commit Dfire remains DEL050.  Return DEL250
  remains.
- **SDF PASS on every requested case.**  Annotation `Done`, no
  `IFNSDFA`.  X-free.  No `TB_X_FAIL`.

  | Case | Result |
  |---|---|
  | `unicast3` | PASS |
  | `mc_single3` | PASS |
  | `mc_disjoint_parallel3` | PASS |
  | `uc_overlap_release3` | PASS |
  | `mc_overlap_tailjoin3` | PASS |

### Head timing on the frozen netlist — `20260817_r3f_prs50_head`

- Observation-only SDF reused
  `ULTRA_NETLIST_RUN_ID=20260817_r3f_prs50`.  Job `11315301`.
  `ULTRA_TRACE_HEAD_TIMING=1`, `unicast3`.  Annotation `Done`, no
  `IFNSDFA`.  `TB_RESULT PASS unicast3`.  No
  `TB_PRS_DECODE_AFTER_RS`.
- Head cumulative delay from ReqIn:

  | Boundary | PRS150 | PRS50 | interval |
  |---|---:|---:|---:|
  | PRS RS | 0.419 | 0.262 | 0.262 |
  | HeadCapture P | 0.531 | 0.374 | 0.112 |
  | Mutex5 grant | 0.915 | 0.758 | 0.384 |
  | anchorStart | 1.138 | 0.981 | 0.223 |
  | roundBusy | 1.228 | 1.071 | 0.090 |
  | RoundClose | 1.290 | 1.133 | 0.062 |
  | membershipN_closed | 1.505 | 1.348 | 0.215 |
  | FinalBuilder ready | 1.473 | 1.316 | — |
  | Transaction valid | 1.570 | 1.413 | 0.065 |
  | ACG fire | 1.667 | 1.510 | 0.097 |
  | ReqOut | 2.322 | 2.165 | 0.655 |

- `ReqIn→ReqOut` is **2.165 ns** (−0.157 ns vs PRS150 2.322,
  −0.321 ns vs DFIRE50 2.486).  The reduction is the PRS interval
  (0.419 → 0.262).  `Tctrl` ReqX→RS = **196 ps**, `Tprs` I→Z =
  **55 ps**, Tdata-from-ReqX = 0 ps (ungated `_GEN_8` still 80 ps
  before ReqX).  Residual 141 ps.  Mapped PRS DEL050 is 55 ps on
  this load, not the Dfire DEL050 97 ps and not the 75 ps nominal
  table.  `Tctrl` still meets the 80 ps floor.  Extractor
  recommendation: `ACCEPT_DEL_DERATE`.
- First-Head OPM V2 RTM5 shortfall remains 0.

- **Decision:** accept
  `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0_FB0_RC0_CACK0_ANCST0_DFIRE50_PRS50`
  as the new SYNTH-CLOSED profile on the R3f handshake.  Head is
  2.165 ns.  This is the smallest library PRS cell.  Do not start
  PRS0.  Do not mix R4b.  R4c / R5 stay deferred.  NoC16 p50 is not
  part of this cut.  This is not PHYS-CLOSED.

