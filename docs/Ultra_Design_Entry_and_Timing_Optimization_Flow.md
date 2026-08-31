# Ultra Design Entry and Timing Optimization Flow

最后修正日期：2026-08-13

本文档是 Ultra Router / NoC 的 design entry、逻辑综合、物理实现、STA、ECO 和严格 SDF GLS 的时序方法规范。后续任何时序优化必须遵循本文档；如果实际工具或工艺要求迫使流程发生变化，应先更新本文档，再实施变更。

## 1. 论文依据与方法演进

本文档综合以下三篇论文的 synthesis 与 timing optimization 方法：

1. [A transition-signaling bundled-data NoC switch architecture for cost-effective GALS multicore systems](D:/NoC/asynchronous_fat_tree_multicast/docs/A_transition-signaling_bundled_data_NoC_switch_architecture_for_cost-effective_GALS_multicore_systems.pdf)，重点是 Part III-F 与 Part IV：列出 switch 内关键 RTC，并给出逻辑综合、P&R、硬宏和链路综合方法。
2. [Cost-Effective and Flexible Asynchronous Interconnect Technology for GALS Systems](D:/NoC/asynchronous_fat_tree_multicast/docs/Cost-Effective_and_Flexible_Asynchronous_Interconnect_Technology_for_GALS_Systems.pdf)，重点是 Implementation Tool Flow 与 Fig. 2：把方法扩展成 switch macro（步骤 1-10）和 top-level NoC（步骤 11-16）的 bottom-up hierarchical flow。
3. [An Ultra-Low Cost and Multicast-Enabled Asynchronous NoC for Neuromorphic Edge Computing](D:/NoC/asynchronous_fat_tree_multicast/docs/An_Ultra-Low_Cost_and_Multicast-Enabled_Asynchronous_NoC_for_Neuromorphic_Edge_Computing.pdf)，重点是 Part VII、Fig. 6 和 Fig. 7：明确 hybrid HDL-GTECH RTL-equivalent entry、结构保持、增量综合内环、RTM 渐进外环和可选 ECO。

三篇论文的方法不是彼此替代，而是逐步完善：

```text
Transition：定义关键 RTC，并用 max-delay 初次实现、路径提取、min-delay 约束和迭代收敛
    ↓
Flexible Interconnect：加入 datapath-first、switch/topology 两级分层实现和 RTM nested loop
    ↓
Ultra：固定 RTL-equivalent structured entry，并明确性能上下界、增量综合与 ECO 决策
```

## 2. 不可违反的基本原则

### 2.1 功能正确性依赖动态结构

异步电路的正确性不只由稳态布尔函数决定，还依赖毛刺、反馈、事件顺序和相对延时。因此综合工具不得把以下结构当作普通组合逻辑任意重写：

- Muller C-elements、Mutex、TAC 和组合反馈状态单元；
- Mousetrap request/data latch 及其控制反馈；
- ACG、事件触发 DFF、V2 close-event；
- OPM 的 request-selection latch、XOR、L5、data latch、Ack/TP DFF；
- Atomic V2 的 HeadCapture、membership、transaction 和 RETURN 状态结构；
- 明确承担 matched delay 的 DelayElement；
- FIFO 内的异步控制反馈。

允许的自动优化原则上仅限：

- 标准单元 technology mapping；
- 等价 drive-strength sizing；
- 不改变动态结构的 buffer/inverter insertion；
- 经过记录、只作用于违例控制路径的最小 DEL ECO。

禁止跨 hierarchy 的布尔重构、状态复制、逻辑吸收、反馈环消除、异步 primitive 展平以及 retiming。每个 run 都必须通过结构检查证明这些要求仍成立。

### 2.2 数据先优化，控制再匹配

论文共同采用 datapath-first：先让数据路径达到局部可实现的最优结果并稳定下来，再把相关控制路径匹配到已经确定的数据延时。

不得一开始同时无约束地优化数据和控制，否则两者会在迭代中相互移动，RTC 难以收敛。尤其在链路物理实现中，第一次布线和 buffer insertion 后应冻结数据线的 placement、routing 和 drive strength，再对 request 施加相对 min-delay 约束。

### 2.3 RTC 是单边顺序约束，同时需要性能上界

对一条 bundled-data 关系：

对每一条 RTC，必须以最危险的 PVT/path 组合判定：最晚数据与最早控制，而不是两条 max-delay 相减。

```text
required_control_min = Tdata_max × (1 + RTM_target)
margin_ps            = Tctrl_min - Tdata_max
shortfall            = max(0, required_control_min - Tctrl_min)
RTM_actual           = margin_ps / Tdata_max × 100%
```

功能正确性要求 `Tctrl_min >= Tdata_max`；签核还要求达到目标 RTM。另一方面，控制不能无限变慢，因此还必须为控制路径设置有限的最大延时：

```text
Tcontrol_min = Tdata_max × (1 + RTM_target)
Tcontrol_max = Tcontrol_min + extra_slack
```

`extra_slack` 是帮助工具收敛的自由度，不是永久增加延时的目标。RTC 过度设计会直接损害 latency 和 cycle time，必须尝试收紧。

### 2.4 约束与验证必须覆盖双相位

Transition-signaling 的上升沿和下降沿都代表有效 flit 事件。STA、SDF GLS 与事件测量必须覆盖两种相位、Head/Body/Tail，以及 acquire/release 两条方向；不能只签核正沿或第一个 Head。

## 3. Design entry 规范

### 3.1 Hybrid HDL-structural entry

遵循 Ultra Part VII，design entry 使用 fully synthesizable 的 RTL-equivalent hybrid specification：

- 路由计算、mask 计算等普通逻辑可用行为 HDL；
- C-element、Mutex、latch、事件 DFF、ACG、DelayElement 等用明确的 structural primitive；
- entry netlist 可以经过 technology-independent generic mapping，但进入优化后必须禁止逻辑操纵，只开放 sizing 与 buffer insertion。

当前项目的 Verilog primitive 是 GTECH-equivalent design entry。远程 T28 DC 的最终 target netlist 必须满足 `GTECH=0`；不能把未映射的 generic cell 当作签核实现。

### 3.2 Primitive 结构签名

每次 DC 后必须检查并记录：

- C2/C3、DLatchBank、V2CloseEvent、ACG、DelayElement 的实例数量；
- Mutex2 每实例的交叉锁存与 filter 结构；
- TAC2、Mutex3、Mutex5 的 hierarchy 和局部连接；
- 五个 OPM 的 request/data latch 与 RTL matched-delay 数量；
- Atomic V2 HeadCapture、membership C-tree、transaction controller 的数量；
- `GTECH`、unresolved、unmapped 数量均为零。

ASIC `Mutex2` 当前固定为每实例 `2×ND2D1 + 2×NR4D1`：四输入 NOR 的四个输入连接同一内部节点，作为结构化 output filter。`q*_nand` 和 `gnt*_filter` 必须 `dont_touch`，不得折叠成 INV 或跨层合并。

### 3.3 运行可复现性

每个综合/物理 run 使用唯一 `run_id`，并保存：

- source RTL、primitive、约束脚本和 TB 的 SHA-256；
- entry/post-layout netlist、DDC、SDC、SDF；
- compile directives、case analysis、disabled timing arcs；
- primitive/DEL 计数和结构指纹；
- 工艺库、PVT、tool version 与 delay profile。

## 4. Ultra 当前必须维护的时序关系

### 4.1 V1 输入 bundled-data

```text
data leg:    DataIn → V1 data latch D/Q → DataX
control leg: ReqIn → V1 request latch/ReqX → latch E 关闭
requirement: Data 在实际 V1 latch 关闭前满足 setup/hold，并在 outstanding 期间保持
```

外部 source 的 `Data → Req` setup 属于接口协议约束；它不能代替 Router 内部 STA。

### 4.2 PRS hazard-free matched delay

Transition 明确指出 PRS 内 matched delay 用于保证 routing logic 无毛刺。应比较 routing data/mask 的最坏传播路径与触发 `RS`/ready 的控制路径，而不是把 PRS DEL 当作固定不可优化常数。

### 4.3 Atomic V2 bundled-control 关系

当前多播扩展引入论文原始 switch 没有的事务化仲裁路径，必须独立维护以下 RTC：

| 关系 | 数据/状态路径 | 关闭/提交路径 |
|---|---|---|
| Head capture | `localMask → mask latch Q` | `localHead → packetPresent/关闭 capture` |
| Membership | `candidate/seen → frozen membership` | `roundClose → closeReady/allClosed` |
| Builder | `anchor/seen/mask → greedy winner/tx payload` | `allClosed → finalBuilderReady` |
| Commit | `transaction latch Q` | `txValid/Start → ACG fire` |
| Return | `active/owner/P/mask 清理完成` | `returnDone → reopen next round` |

这些约束保护 fire 域只读取已经冻结的 transaction，不允许实时 candidate 或实时 mask 落入提交边沿。当前 `UltraArbiterHeadCapture`、`UltraArbiterDecision`、`UltraArbiterCommit` 使用 DEL250 作为已验证基线，但后续应按本文档逐条测量后缩减，不能整体盲目降档。

### 4.4 OPM V2 bundled-data

Transition 将 OPM 确认为关键 RTC：data 必须在 output register latch 关闭前稳定，Head path setup 和 Body propagation 都要满足。

```text
data leg:    source DataX → MG-controlled Mux → V2 data latch D/Q → DataOut
control leg: source Req latch Q → XOR4 → v2RequestMargin → L5 Q feedback → V2 latch E falling
requirement: DataOut 在 ReqOut 被接收端观察到之前稳定
```

当前每个 OPM 在 XOR4 后、L5 前保留命名 RTL `v2RequestMargin`，reset 写零路径绕过该层次。V2 bundled-data 的签核点是 `dataOutLatch.D` 的最后稳定时刻与同一 data latch 的实际 `E↓`，而不是端到端 `DataOut/ReqOut` 差值。只有局部 `D→E` 余量低于目标时，才可由综合在 XOR4 到 L5 的普通组合段做最小 sizing/buffer 修复；不得把 Router 端到端延迟折算为该局部段的固定 min-delay。

### 4.5 V2 close-event、Ack 与 TP

```text
V2 latch E 实际关闭 → protected inverter/V2CloseEvent → Ack/TP DFF CP
data latch Q[isTail]  → TP D
request-selection Q   → Ack D
```

CP 必须从实际 latch `E` 的后级产生，不能从 reset 门之前的逻辑旁路。需要分别检查：

- latch D 对 E 的 setup/hold；
- E 低脉宽足以形成唯一 close-event；
- Ack/TP D 在 CP 前稳定；
- CP 到 Q 后能使 ReqGen `Done` 正确回落。

### 4.6 Tail/Grant release

Transition 指出 Tail 后存在细微 release race：OPM Ack 经 Ack merge 和 input-register control 重新打开输入时，新 request 可能沿路径再次到达 OPM。论文用 TailPassed/MG 关闭 L1-4，避免依赖更慢的 PPE deassertion 与 mutex release。

当前多播实现还要求：

- TailJoin 收齐目标分支后，Atomic 原子清 `P/A/mask/owner`；
- `tailReleaseReady` 后 AckGenerator 才完成 Tail 输入 Ack；
- 新 Head 不得在旧 reservation 完整释放前进入同一输入生命周期。

这既是功能状态约束，也要报告 release feedback 的最坏延时和恢复 cycle time。

### 4.7 FIFO 与 NoC 链路

Transition 指出 Mutex、Request Control 和 circular FIFO 内还有 RTC；它们在典型 switch 实现中通常自然满足，但仍必须检查，不能直接 false-path。

对于跨 Router 链路：

1. 先用 max-delay、max-capacitance、max-transition 完成数据与 request 初始 route/buffer。
2. 提取最坏数据延时并冻结数据线 placement、routing 和 drive strength。
3. 为 request 设置相对 min-delay，使其晚于数据稳定并达到目标 RTM。
4. 只对 control 做 incremental physical optimization；必要时插入最小 delay ECO。

对于包含 Mousetrap repeater/FIFO 的长链路：

- repeater 作为 soft macro，并给出 placement boundary 以形成规则 floorplan；
- 允许工具 sizing pipeline cells 和插 buffer；
- STA 可在分析视图中切断 latch control feedback arc，并把 reset 定义为 dummy clock 来约束最大 forward delay；
- 被切断的反向 Ack 路径必须另设 max-delay，不能变成无界路径；
- 分析切环仅用于 STA，不得删除功能网表反馈。

### 4.8 结构化异步边界端点

当前统一后仿顶层为：

```text
20× source Mousetrap → NoC_16nodes → 20× sink Mousetrap
```

source 使用 50 ps 的 Data-before-Req setup；sink Ack 使用受保护的物理 DEL075，为 NoC OPM 留出可靠 close-event 窗口。端点与 NoC 必须在同一个 DC 顶层中综合并生成唯一网表/SDF，禁止分别综合网表后因同名模块覆盖而组合仿真。

## 5. 分层综合与物理实现流程

### 5.1 Switch / UltraRouter macro：对应论文步骤 1-10

1. 从参数化 RTL 生成 technology-independent structural entry netlist。
2. 施加结构保持指令，只开放 sizing 与 buffer insertion。
3. 对每条数据路径独立设置局部 max-delay，并优化 datapath。
4. 做第一次 technology mapping，目标是最大性能和最小合理面积。
5. 从已映射网表提取每条 matched data path 的 `arrival`。
6. 根据数据延时和当前 RTM 生成 control 的 `set_min_delay` 与有限 `set_max_delay`。
7. 执行 incremental synthesis；重新提取并比较所有 RTC，直至内环收敛。
8. 生成并保存 gate-level netlist。
9. 在 P&R 中重新施加 absolute constraints、max cap/transition 和 RTC，完成 floorplan/place/route。
10. post-route 提取真实 RC，重新运行 RTC 内环；输出 switch macro、SDF、STA 和 GLS 模型。

当前 UltraRouter 尚未使用固定 hard macro 集成，但单 Router 的 DC/SDF/STA 必须按这一阶段独立签核，才能进入 NoC16 层级。

### 5.2 Top-level NoC：对应论文步骤 11-16

11. 生成参数化 topology-level structural netlist。
12. 导入已经签核的 switch/FIFO/endpoint macro 或受保护 hierarchy，并设置 floorplan、端口、区域和链路约束。
13. 完成 top-level floorplanning、placement 和初始 routing。
14. 以较宽松 RTM 开始 topology link closure。
15. 对所有 link RTC 执行 incremental physical optimization；需要时仅在违例 control path 上 ECO 小 DEL，然后重新抽取和检查。
16. 全部 RTC 和 absolute constraints 收敛后 extraction，生成唯一 post-layout netlist/SDF，并进行严格 GLS。

NoC 层不能假设 Router-level RTC 会自动覆盖 link delay；每条合法跨层链路都必须重新配对 data/control path。

## 6. RTM 内环：Ultra Fig. 6 的项目化执行

每一个 RTM 档位执行以下流程：

1. 对全设计施加积极但可实现的 `set_max_delay`，并把优化 cost priority 设为 delay，得到初始高性能映射。
2. 提取所有 RTC 的 `Tdata` 和 `Tcontrol`，计算 `RTM_actual` 与 `shortfall`。
3. 对 shortfall 路径设置：

   ```text
   set_min_delay  Tdata × (1 + RTM_target)  <control path>
   set_max_delay  Tdata × (1 + RTM_target) + extra_slack  <control path>
   ```

4. 执行 incremental compile，不允许重新构造异步结构。
5. 重新测量全部 RTC：
   - 有 shortfall：继续迭代；
   - 多条约束并行难以收敛：小步增加 `extra_slack` 或调整 min-delay cost priority；
   - control 明显过慢：收紧其 max-delay，重新优化性能；
   - 达到迭代上限仍违例：进入最小 ECO，而不是无限放宽。
6. 在 post-route RC 下重复同一检查，逻辑综合通过不能代替物理收敛。

约束必须绑定到明确的 port/pin/net path。禁止把 cell collection 直接当作 `-through` 对象，也禁止由于 timing loop 被工具自动 cut 就把路径报告为空视为通过。

## 7. RTM 外环：Ultra Fig. 7 与 Flexible Fig. 2

目标 RTM 采用渐进档位：

```text
0% → 5% → 7% → 10%
```

- 0%：证明功能 bundling 正确；
- 5%：当前工程基线；
- 7%：中间物理鲁棒性档；
- 10%：三篇论文使用或示例的最终保守目标。

每一档都从上一档已收敛设计增量开始，但必须生成独立 run 产物。不得一次把大量并行 RTC 推到 10%，以免工具过载或产生不必要的巨大控制延时。最终应保存两个明确标签的实现：`PERF build`（最小可靠 RTM）和 `PAPER build / RTM10_SIGNOFF`（所有 bundling RTC ≥10%，用于论文对齐比较）。

ECO 只在 synthesis/P&R 难以同时满足众多控制路径时启用：

- 仅作用于违反 RTC 的 control segment；
- 优先从最小可用 DEL 开始；
- data path、reset clear、Ack DFF、TP DFF 和协议状态不得随意延迟；
- 每次 ECO 后重新运行 STA、严格 SDF 和结构检查；
- 对同一类型反复出现的 ECO，下一轮才评估是否固化为 RTL matched delay。

## 8. STA 报告规范

### 8.1 每条 RTC 的 paired report

每条 RTC 必须在同一 corner、同一起点事件和同一分析模式下输出：

| 字段 | 内容 |
|---|---|
| ID | 模块、输入、输出、flit 类型和相位 |
| Data path | startpoint、through pins、endpoint、min/max arrival |
| Control path | startpoint、through pins、endpoint、min/max arrival |
| Tdata/Tcontrol | 统一参考事件下的延时 |
| RTM | 实际百分比、目标百分比、shortfall |
| Constraint | min-delay、max-delay、extra_slack |
| Status | PASS / shortfall / overdesigned / no-path |

Head 与 Body/Tail 必须分开报告。Head 包含 PRS、Atomic 和首次 PPE/MG 建立；Body/Tail 复用 PPE/MG，主要衡量 V1、OPM 与反馈 cycle。

### 8.2 全路径覆盖

Router 至少覆盖全部 20 条合法 input→output edge；NoC16 还要覆盖：

- L1→L2 upward links；
- L2→L1 downward links；
- FIFO/repeater forward 与 Ack return；
- endpoint→NoC 和 NoC→endpoint；
- multicast 最早分支与最晚分支；
- acquire、capture、release 和 reopen。

### 8.3 切环报告

所有 disabled arc、case analysis 和 loop breakpoint 都要单列报告，说明：

- 为什么必须切；
- 被切路径由哪个独立约束覆盖；
- 功能网表反馈是否仍存在；
- strict SDF 是否验证了该反馈的动态行为。

## 9. 严格 SDF 与性能验证

### 9.1 签核规则

严格 SDF 必须使用本次 run 的原始 post netlist 与 SDF：

- 禁止 `+nospecify`、`+notimingcheck`、force、X-to-0 或功能 patch；
- 允许 `+no_notifier` 保持数值仿真继续，但 timing violation 必须完整记录；
- SDF annotation 无 `IFNSDFA`，且 annotation coverage 可审计；
- 数据错误不立即结束 checker，除非出现仿真不可收敛；
- 边界 TB 不能读取内部信号控制 Req/Ack。

### 9.2 论文忠实的异步环境

Transition 使用真实 injector/switch/absorber 握手环境，避免零延时边界产生过度乐观结果。本项目对应采用结构化 Mousetrap endpoint，并独立测量：

- offer→ingress Req 排队延迟；
- ingress Req→Ack 输入握手；
- Head ingress→egress 网络延迟；
- egress Req→capture 接收延迟；
- 多播最后目标 Tail capture 完成时间。

性能延迟定义为输入 request 事件到输出 request 事件；Head latency、payload latency 和 cycle time 分开统计。

## 10. 当前已签核基线

### 10.1 OPM75

`ULTRA_P250_PRS_ACG_OPM75` 是当前结构基线：PRS/Atomic 为 DEL250，每个 OPM 有一个 RTL DEL075。单 Router run `20260807_rtl_rtm_opm075` 的 Head 测量为：

```text
Tdata    = 2.072 ns
Tcontrol = 2.200 ns
RTM      = 6.18%
```

其 Child0→Parent Head/Body/Tail 严格 SDF 已通过。该结果只证明当前路径超过 5%，不等于全部 20 条 edge 或全部 PVT 已达到 10%。

### 10.2 统一异步 NoC16 顶层

当前严格 SDF 签核网表为 run `20260812_ack075_r5_core015`，采用单一 `AsyncNoC16BoundaryDUT` DC 顶层、DEL075 sink Ack 和唯一 SDF。已通过：

- TAB 3-flit：r0p02、10、20、30、40、50、60、70、80、90；
- VCTM-MC5-NM 3-flit：r0p02、10、20、30、40、50、60、70、80、90；
- 所有 case 均为零 missing、零 unexpected、零 timeout。

这些结果构成后续减小 PRS/Atomic DEL 和提升 RTM 前的功能基线。任何时序优化后必须完整回归这两组 case。

## 11. 下一阶段优化顺序

后续优化按以下顺序进行：

1. 冻结当前功能基线与结构指纹。
2. 对 Router 全部 20 条 edge 生成 paired STA，补齐未测 RTC。
3. 单独优化 datapath；冻结其结构和物理结果。
4. 逐项测量并缩减 PRS、HeadCapture、Decision、Commit DEL；一次只改变一个 timing role。
5. 每档执行 Router smoke、NoC16 TAB/VCTM strict-SDF 回归。
6. Router 收敛后，再做 FIFO 和 L1/L2 link-level RTM。
7. 按 0→5→7→10% 外环推进；每档控制过度延迟也必须被识别并收紧。

任何“为了通过仿真而增加固定延时”的做法都必须先由 paired STA 证明其 shortfall；任何“为了降低 latency 而删除 DEL”的做法都必须在 post-route RTC 和严格 SDF 下重新签核。

## 12. 阶段 3：Router macro datapath-first 规则

阶段 3 属于 **pre-layout / SYNTH-CLOSED** 优化，不是最终 P&R 签核。其
目标是先收紧数据锥，再在后续阶段用已冻结的 `Tdata_max` 约束控制锥；不得
通过增加控制 DEL 掩盖数据路径过慢。

1. 从冻结 Router DDC 进入 incremental DC，只对 V1 capture、PRS
   descriptor、HeadCapture/Atomic descriptor 和 OPM V2 数据锥施加
   `set_max_delay = 0.95 × baseline Tdata_max`。
2. correctness 采用 **最晚数据 / 最早控制** 的 paired measurement；rise 与
   fall 分开记录。无法共享事务参考的 STA segment 标为
   `NOT_COMPARABLE`，不得用于计算 RTM。
3. 可优化的只有普通组合数据逻辑、drive sizing 和 buffer insertion。所有
   Mutex、C-element、DLatch/DFF、DelayElement、close-event、ACG、reset
   锥、层次和边界优化均保持冻结。
4. 每个候选执行两次从冻结/前一通过 DDC 进入的 incremental pass。只有 r1/r2
   的关键 `Tdata_max` 收敛至 `max(10 ps, 2% × baseline)`，且结构、DRC、
   strict-SDF 和功能回归全通过，才冻结数据路径。
5. 明确 DEL 是最后残余 control shortfall 的 ECO 手段；阶段 3 不缩减任一
   DEL，不施加 control min-delay，也不以 endpoint sink service delay 计入
   Router forward latency。

## 13. 每轮交付清单

每轮综合与时序优化结束时，必须在 Debug Log 和 run summary 中记录：

- 修改目的、文件、delay role 和候选档位；
- entry/post/SDF/TB hash 与结构计数；
- DC/P&R/STA 的 tool、library、corner 和约束；
- 全部 RTC 的 Tdata、Tcontrol、RTM、shortfall、extra_slack；
- disabled arc、loop breakpoint 和对应替代约束；
- Router smoke、TAB、VCTM 的 strict-SDF 结果；
- 首条 timing violation 或功能断点；
- 最终选择及未解决风险。

只有结构、RTC、严格 SDF 和功能回归四项同时通过，才可以把一个实现标记为 timing-closed。

## 14. MembershipClose 的已验证例外（2026-08-13）

`AsyncRoundMembershipCell.close_margin` 不参与 membership 的状态建立：同一个
`close_grant` 并行驱动 `stage_closed` 锁存路径和 `close_margin → close_delayed`
路径，随后 `C2(stage_closed, close_delayed)` 才产生 `close_ready`。因此该 DEL
不是 candidate 数据到状态的 bundled-data 保护路径。

在 profile `ULTRA_P250_PRS_ACG_OPM75_MEM0` 中保留该实例与层次、但取
`DelayValue=0`。该选择已通过本地完整 smoke、单 Router 严格 SDF 五项 smoke，
以及统一结构化异步端点 NoC16 的 TAB/VCTM r0p50 严格 SDF。后续 P&R 阶段仍须
重新验证此例外；若 post-route RTC 显示 C2 输入偏斜导致 shortfall，才允许按
数据导出的最小值恢复 delay。

## 15. HeadCapture 的已验证例外（2026-08-13）

`UltraHeadCaptureCell` 中 `head_margin` 的唯一职责是让
`localMask -> maskLatch.D` 先于 `localHead -> packetPresent` 关闭 mask
latch。它不替代 PRS matched delay：后者仍负责在 `RS/PRSReady` 打开前等待
路由 decode 稳定。

profile `ULTRA_P250_PRS_ACG_OPM75_MEM0_HC0` 保留五个 `head_margin` 的
层次并令 `DelayValue=0`，同时保留 `MEM0` 的 membership bypass。该组合已在
本地 Router 全套 smoke、单 Router 严格 SDF 五项 smoke，以及统一结构化异步
NoC16 的 TAB/VCTM r0p50 严格 SDF 中通过。它可作为 pre-layout baseline；不得
据此删除 PRS DEL。P&R 后必须以 `localMask` 最晚到达、`packetPresent` 最早关闭
的 paired RTC 重新签核，出现 shortfall 时仅恢复数据导出的最小 HeadCapture DEL。
