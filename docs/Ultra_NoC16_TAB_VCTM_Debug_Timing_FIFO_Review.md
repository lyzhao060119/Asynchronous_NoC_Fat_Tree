# Ultra NoC16 TAB/VCTM 调试、时序约束与 FIFO 静态评估

## 1. 范围与结论

本文记录 Ultra Router 接入 16 节点 wrapper 后，运行 TAB 单播和
VCTM-MC5 原生多播时暴露的问题、已经完成的硬件结构修正，以及对
Transition 论文 Part III-E/F 和 Fig.6/Fig.7 的静态评估。

本次评估不修改 FIFO、IPM、OPM、Atomic 或 TailJoin RTL。当前结论是：

1. TAB/VCTM 前期失败并非单一问题。后续逐级复核证明，曾归因于
   AckGenerator 初始 `Done=0` 和旧 PPE 泄漏的两项判断不成立。
2. AckGenerator 已恢复为 Ultra Fig.5(a) 的纯 reduction-NOR 事件时钟
   加 Ack-following DFF；Atomic admission 不再进入 IPM/Ack 路径。
3. 高负载 VCTM 最后暴露的是 L1/L2 之间的真实资源依赖环。现有
   NoC16 在每条 L1↔L2 链路的两个方向各放置一个深度 3 的串联
   `AsyncFifo`，使本次固定 3-flit packet 能够整包解耦。
4. 当前 `AsyncFifo` 是多个 `AsyncStage` 串联，不是 Transition
   Fig.6 的 circular FIFO。后续若实现 Fig.6/Fig.7，最直接的替换位置
   就是当前 8 个 L1↔L2 链路 FIFO 所在位置。
5. Transition Part III-F 的核心是相对时序约束。RTL 中存在
   `DelayElement` 并不等于物理实现已经满足这些约束，综合和布局布线
   阶段仍需保护异步结构并执行专门的 STA/约束检查。

论文依据：

- [A transition-signaling bundled-data NoC switch architecture for cost-effective GALS multicore systems](A_transition-signaling_bundled_data_NoC_switch_architecture_for_cost-effective_GALS_multicore_systems.pdf)，Part III-E、Part III-F、Fig.6、Fig.7。
- [An Ultra-Low Cost and Multicast-Enabled Asynchronous NoC for Neuromorphic Edge Computing](An_Ultra-Low_Cost_and_Multicast-Enabled_Asynchronous_NoC_for_Neuromorphic_Edge_Computing.pdf)，ReqGenerator、Grant Masking 和多播 OPM 架构。

## 2. 当前完整数据与控制关系

单 Router 内部的主路径是：

```text
输入握手
  → Modified Mousetrap V1
  → Packet Route Selector
  → AtomicMulticastAdmission
  → RequestGeneratorBank
  → OPM
  → 输出握手
```

反馈关系是：

```text
OPM local TailPassed
  → MulticastTailJoin
  → allTailPassed
  → Atomic 原子释放 packetMask/owner

OPM Ack/Grant/MG
  → RequestGeneratorBank
  → Done
  → IPM/AckGenerator
  → 输入 Ack
```

`MulticastTailJoin` 是与 Atomic、ReqGeneratorBank 并列的 Router 中央反馈
模块，不属于某个单独 OPM 的“后级”。它将五个 OPM 的 local source
重新映射为 input/output 事件，并用 sticky bitmap 汇总错峰到达的 Tail。

## 3. TAB 调试中发现的问题

### 3.1 新旧 Head 的中央 Atomic 代际重叠

初期低负载 TAB 可以运行，但负载提高后出现“已经注入约 1000 个 packet，
只交付约 980 个 packet 后超时”的现象。scoreboard 没有发现错误 flit，
说明故障主要表现为握手停滞而不是数据随机损坏。先前把它解释成新 Head
借用尚未回落的旧 PPE；经过 OPM/AckGenerator 事件链复核，该解释不成立。

正确的局部顺序是：

```text
所有Done清零
→ 每条分支满足 !Done && !MG
→ PPE/Grant/TP完成清除
→ AckGenerator complete产生上升沿
→ AckX跟随ReqX
→ 输入Mousetrap才可能捕获下一Head
```

因此下一 Head 不会穿过旧 PPE。仍需区分的是中央 Atomic 状态：
OPM/PPE 已局部释放后，`packetActive/outputOwner` 可能尚在等待 TailJoin
和 Atomic release fire。若此时下一 Head 已进入 V1，不能仅凭旧
`packetActive` 把它判断为已经准入。

已完成的结构修正：

- `AtomicMulticastAdmission` 为每个输入增加 `headEpoch`，每次本地 Head
  到达时翻转；成功准入时把当前 epoch 采样到 `admittedEpoch`。
- `admittedRS` 只有在 packet active 且 epoch 匹配时才有效。

epoch 的正确用途是区分中央 Atomic reservation 所属的 Head，不是保护
OPM 的 PPE 清除。后续 ReqGenerator 隔离实验已经确认
`admissionBlocked` 不能解除 TAB 的跨层资源等待，而且论文 ReqGenerator
中也不存在这条旁路，因此已从 ReqGenerator、RequestGeneratorBank 和
UltraRouter 接线中删除。

### 3.2 AckGenerator 的 admission workaround 已撤销

先前分析错误地把 `complete = (Done == 0)` 当成电平敏感 enable。实际
AckGenerator 是 `complete` 上升沿触发 DFF。初始或等待准入时虽然
`Done=0、complete=1`，但没有新的上升沿，因此不会采样 `ReqX`。

正确事件序列是：

```text
初始 Done=0、complete=1：无边沿，不采样
分支开始 Done!=0：complete 1→0，不采样
最后分支 Done→0：complete 0→1，Ack DFF采样ReqX
```

因此已删除 `admissionPending`、`admissionHold` 和 `awaitingWorkLatch`，
IPM 也不再包含 admission 端口。

## 4. VCTM 多播调试中发现的问题

### 4.1 多播 Head 在所有分支建立前被输入侧确认

最初的低负载 VCTM-MC5 曾在约 73 个注入 flit、57 个交付 flit后停止。
某个三目标 Head 已由 Atomic 产生完整 `admittedRS=4'b1110`，但四个
ReqGenerator 的相位和 matched-delay 初值并不保证在完全相同的时刻建立
PPE。实际波形中一条分支先产生短 Done/PPE，另外两条还未建立，输入侧却
已认为 Head 完成。

后果是：

1. Body/Tail 只沿已经建立的那一条分支前进；
2. 其他目标从未收到该 packet；
3. TailJoin 正确地等待所有 mask 分支，因缺失分支而永久不产生
   `allTailPassed`。

这里 TailJoin 没有丢事件；根因发生在 Head 分支启动阶段。

先前加入的 `headStartPending` 通过 admission 路径门控 AckGenerator，
不属于论文 Ack 结构，现已随 admission workaround 一并删除。多播分支
启动问题现在由 ReqGeneratorBank smoke 直接验证：raw PRS `RS` 先建立
Head 相位，Atomic 完整准入后四个分支同时进入 active；Body/Tail 由 PPE
保持。测试不再由 AckGenerator 附加 latch 掩盖。

### 4.2 ReqGenerator 固定 Delay 与 Admission Block 已删除

论文原图复核表明，Ultra Fig.5(a) 的 ReqGenerator 由 RS 边沿 DFF、
Done XOR 和非对称 C-element 构成；Transition Fig.3 的 ReqGenerator
也是 phase selector 加 programmable inverter，并没有独立
`DelayElement`。Transition 的显式 matched delay 位于 PRS。

2026-07-31 的结构复核推翻了此前 raw `RS`/`Admit` 双接口的说法；现已按下述
结构实现：

```text
IPM raw RS -> Atomic
Atomic admittedRS = 失败 4'b0；成功保持原 RS mask
admittedRS 上升沿：phaseReg := ReqX XOR !Ack
branchActive = admittedRS || PPE
Req = branchActive ? (ReqX XOR phaseReg) : Ack
Done = Req XOR Ack
```

这里不存在独立 `Admit`：

1. raw PRS `RS` 只进入 Atomic，供其捕获 pending Head 的完整目标 mask；
2. Atomic 输出的 `admittedRS` 是 ReqGenerator 唯一的 RS 输入；未准入方向
   为零，获准方向保留原 mask；
3. `PPE` 在 Head 后保持 Body/Tail 路径；
4. inactive 时仍将 `Req` 钳位到 `Ack`，令 `Done=0`。

此前为规避零延时仿真旧 phase 而引入 `Admit`，属于错误的接口拆分；它
不能替代 Atomic 作为 RS 的唯一生产者。应通过正确的 Atomic 事件输出和
ReqGenerator 论文连接修正，而不是保留额外控制端口或恢复固定请求延时。

`admissionBlocked` 的隔离实验保持 ReqGenerator 无 Delay，仅临时恢复
Block；`TAB-NET-UR-3f-r0p02` 仍超时，且停滞仍是跨 L1/L2 wait-for 链。
因此 Block 与该问题无关，最终 RTL 不保留它。

### 4.3 高负载 VCTM 的 L1/L2 资源依赖环

完成上述相位和启动修正后，低中负载均通过，但高负载
`VCTM-MC5-NM-3f-r0p30` 仍曾在约 1985 个注入 flit、2112 个交付 flit后
超时，且没有 unexpected flit。

最终静态状态显示：

- 一个 L1 输入持有本地输出，Tail 已完成本地分支，但还等待 parent 向上；
- L2 的一个向下多播同时持有多个 child 输出，其中一支已完成，另一支
  等待同一个 L1 的 parent 输入；
- 其他 L1 packet 也在等待向上资源；
- Atomic reservation 和 TailJoin 都在忠实保持尚未全部完成的 packet，
  因而形成闭合的 wait-for 环。

这是网络级资源依赖，不是再增加一个局部控制延时就能修好的问题。若错误地
让 Atomic 提前释放或让 TailJoin 忽略未完成分支，虽然可能消除波形停滞，
却会破坏原子多播和 packet 完整性。

当前 NoC16 的解决办法是在所有 L1↔L2 链路上加入双向、深度 3 的
`AsyncFifo`。对当前固定 3-flit 测试，一个 FIFO 能容纳完整 packet，
从而使占用输入 Router 资源的 packet 可以整体离开并打断本次资源环。

## 5. 本轮回归涉及的模块级硬件调整

| 模块 | 已完成的结构调整 | 解决的问题 |
|---|---|---|
| `AtomicMulticastAdmission` | 保留 `headEpoch/admittedEpoch` 和 epoch 门控 `admittedRS` | 区分中央 reservation 的 Head 代际 |
| `AckGenerator` | 已删除 admission latch/hold，恢复 reduction-NOR 上升沿 DFF | 撤销对事件时钟的错误电平解释 |
| `ReqGeneratorBank` | 只接 Atomic `admittedRS` 作为 RS；已删除 `admissionBlocked` | 未获准 Head 不进入 ReqGenerator |
| `ReqGenerator` | 删除固定 request `DelayElement`、blocked 门控及临时 `Admit`；保留 phase DFF、XOR、C3 与 inactive Ack clamp | 忠实保留论文基本结构并支持 PPE 保持的 Body/Tail |
| `UltraRouter` | 已删除 `headStartPending → IPM/AckGenerator` 路径 | 恢复论文 Ack 事件关系 |
| `NoC_16nodes` | 4 条 upward 和 4 条 downward、深度 3 的 inter-level FIFO | 3-flit VCTM 高负载 L1/L2 资源环 |

OPM、MulticastTailJoin 的论文结构没有因为 wrapper debug 而永久增加新的
旁路。调试中曾尝试额外 OPM 输出延时和 V1 输入请求延时，但它们不能解决
上述根因，已经撤回。

## 6. Transition Part III-F：Timing Constraints 静态对照

### 6.1 Packet Route Selector 的无毛刺约束

论文指出 PRS 内需要 matching delay，以保证路由选择数据稳定后请求才到达
后续控制。其本质约束可写为：

```text
t(PRS request control path)
  > t(route decode + RS settle) + margin
```

这里的 `margin` 必须覆盖 PVT、布线和门延时差异。仿真中的固定
`DelayElement` 只表达意图；综合后必须检查它没有被吸收、重构或缩短。

### 6.2 OPM 控制路径相对于 data mux 的约束

Modified Mousetrap V2 要求选中数据先稳定，随后 L5/data latch 才关闭。
对 Head，路径包含路由/请求建立；对 Body，虽然不重新路由，数据仍需经过
已选定的 mux。

应检查的相对关系是：

```text
t(L1-L4 request latch + request merge + L5-close control)
  >= t(DataX selection + data mux + data-latch setup) + margin
```

不是 Req 越快越好。若控制先关闭 latch 而数据仍在切换，就会捕获上一
flit 或毛刺数据。当前 RTL 的结构与论文拓扑一致，但尚不能仅凭 RTL
elaboration 声明物理时序已满足。

### 6.3 Tail release 与下一请求之间的约束

Transition 特别讨论了 Tail 后的危险竞争：

```text
OPM Ack
  → IPM Ack merge
  → 输入寄存器重新透明
  → 下一请求
  → Request Control
  → OPM
```

可能短于：

```text
TailPassed
  → PPE/Grant 释放
  → mutex/路径状态真正空闲
```

论文在 L1-L4 前增加与 TailPassed 相关的 AND 门，使 Tail 到达后优先关闭
旧 request latch，避免下一请求穿过尚未释放的路径。

Ultra 多 flit/多播扩展的对应保护不再只依赖一个 OPM local mutex：

- OPM 使用 local TP 和 `MG = Grant & ~TP` 关闭 Tail 分支；
- TailJoin sticky 收齐所有目标；
- Atomic 原子释放完整 packet set；
- `outputTailBusy` 阻止旧 TP 未清零时新 owner 继承输出；
- Head epoch 区分中央 Atomic reservation 的 packet 代际。

仍需要检查 local TP/MG 关断是否在最坏 PVT 下快于下一 Req 穿透路径。

### 6.4 还需要落实到物理流程的事项

Transition 的实现方法包含两部分：

1. 保护异步 latch、C-element、延时链和反馈结构，避免综合优化改变其功能；
2. 先按最大延时分析并提取关键路径，再用 `set_min_delay` 等约束表达
   bundled-data 的下界关系，迭代布局布线并复核。

因此后续门级/物理验证至少应建立以下 constraint checklist：

- PRS control 相对于 route/RS settle；
- ReqGenerator selected-request 逻辑相对于 matched delay；
- OPM request-control/L5-close 相对于 DataX mux；
- TP→MG/request-latch close 相对于下一 Head/Body request；
- TailJoin/Atomic release 后，owner/PPE/TP 回落与下一准入；
- FIFO WCB/RCB 的 matched-delay、pointer、Full/Empty 相位关系。

DEL=0.2 ns 的行为仿真通过只能证明当前仿真模型下无失败，不能替代上述
最坏路径 STA。

## 7. 当前 FIFO 放置在哪里

当前 Ultra Router 内部的 IPM 和 OPM 没有新增 packet FIFO。FIFO 位于
`NoC.ultra.NoC_16nodes` 的 L1↔L2 互连边界：

```text
core
  ↕
L1 child port

L1 parent output
  → upwardLinkFifo[dir]
  → L2 child input

L2 child output
  → downwardLinkFifo[dir]
  → L1 parent input

L2 parent port
  ↕
top0
```

四个 L1 方向各有一个 upward FIFO 和一个 downward FIFO，共 8 个 FIFO。
默认深度是 3，因此当前共实例化 24 个 `AsyncStage` 存储槽。

选择链路边界而非某个 OPM 内部有两个原因：

1. 出问题的依赖跨越两个 Router 层级，链路缓存能让 packet 释放上游
   Router 的 Atomic/OPM 资源；
2. FIFO 位于 handshake link 上，不改变 IPM、ReqGenerator、TailJoin 和
   OPM 的论文内部边界。

## 8. 当前串联 FIFO 与 Transition circular FIFO 的区别

| 属性 | 当前 `AsyncFifo` | Transition Fig.6 circular FIFO |
|---|---|---|
| 数据组织 | `depth` 个 `AsyncStage` 串联 | 多个数据槽并列成环 |
| 控制推进 | 每一级独立握手，packet/flit 逐级穿越 | one-hot WritePointer/ReadPointer 选择槽 |
| 槽状态 | 隐含在各级 Req/Ack | `Full_i` 与 `Empty_i` 的相位关系 |
| 写控制 | 每一级普通 stage 控制 | Fig.7(a) Write Control Box |
| 读控制 | 每一级普通 stage 控制 | Fig.7(b) Read Control Box |
| 延迟特点 | 深度越大，串联级延迟越明显 | 避免所有数据逐级搬移，适合更大队列 |
| 当前状态 | 已用于 NoC16 回归 | 尚未实现，仅做静态评估 |

Transition 论文明确指出，简单串联多个 MOUSETRAP register 可以形成 FIFO，
但会带来严重的串行延迟；Fig.6 的设计正是为避免这一点。

## 9. Fig.6/Fig.7 控制结构静态评估

### 9.1 Write Control Box

每个槽的写入条件是：

1. `WritePointer_i` 为 one-hot 高，当前槽被选中；
2. 槽为空，即 `Full_i` 与 `Empty_i` 处于相同逻辑相位。

Fig.7(a) 的 WCB 用 AND 合并这两个条件，并用 XOR 把全局 `ReqIN` 的
transition 转换成该槽 request latch 所需的相位。数据稳定后，请求经过
WCB 内的 matched delay：

- 置位/翻转 `Full_i`；
- 关闭该槽 data register；
- 产生该槽输入 Ack。

所有槽 Ack 再由 N 输入 XOR 合并为 `AckOUT`。当 `ReqIN == AckOUT` 时，
write counter 才推进 one-hot WritePointer。

### 9.2 Read Control Box

槽内有有效数据时，`Full_i` 与 `Empty_i` 的相位不同。若该槽同时被
`ReadPointer_i` 选中，Fig.7(b) 的 RCB 发出请求：

- 每槽请求合并为全局 `ReqOUT`；
- 数据 mux 选择相同槽；
- 当 `ReqOUT` 与 `AckIN` 不同时，立即撤销当前 ReadPointer，冻结 request
  latch；
- ack latch 打开，把下游 `AckIN` 路由回该槽；
- 下游确认后翻转 `Empty_i`，read counter 再推进下一 pointer。

这种结构需要重点验证 one-hot pointer、XOR 相位合并以及 RCB/WCB 内
relative timing，不能直接把同步 RAM FIFO 的读写指针代码套用过来。

### 9.3 与当前 Ultra NoC16 的接口适配

若后续实现 `TransitionCircularFifo`，可以保持与当前 `AsyncFifo` 相同的
外部 two-phase bundled-data `enq/deq` 接口，并在当前 8 个 inter-level
位置原位替换。内部再实现：

- N 个并列 data latch/register；
- N 个 WCB 和 N 个 RCB；
- one-hot write/read pointer；
- 每槽 Full/Empty phase；
- Ack/Req XOR merge；
- 论文规定的 matched delay 和物理相对时序约束。

这样做不需要把 circular FIFO 放进 OPM，也不需要改变 TailJoin 的位置。

## 10. 深度 3 的适用边界

当前所有目标 case 都是 3-flit packet，因此深度 3 FIFO 可以在最坏情况下
吸收一个完整 packet，打断本次观察到的 L1/L2 依赖环。

但这不是一般性结论：

- 若改测 20-flit packet，深度 3 不能保证整包脱离上游 reservation；
- 更大的 circular FIFO 可以降低串联延迟，但只要深度仍小于可能阻塞的
  packet，仍不能自动证明无死锁；
- 任意包长和任意负载下的系统保证还需要足够 packet buffer、VC/escape
  channel、路由资源依赖证明或其他协议级策略。

因此 Fig.6 circular FIFO 的价值主要是“更高效地实现所需深度”，而不是
仅凭 circular 形式就消除所有死锁。

## 11. AckGenerator 恢复后的 NoC16 回归证据

删除 AckGenerator/IPM admission workaround 并恢复纯 reduction-NOR
上升沿 DFF 后，已重新生成 NoC16 RTL，并完整重跑以下 TAB/VCTM 八个
case。结果目录为 `sim/results/ultra_noc16/ackgen_restored`。

TAB 3-flit 单播：

| Case | 注入/交付 flit | 平均 packet latency | 结果 |
|---|---:|---:|---|
| r0p02 | 3000 / 3000 | 42.693 ns | PASS |
| r0p10 | 3000 / 3000 | 49.619 ns | PASS |
| r0p20 | 3000 / 3000 | 61.948 ns | PASS |
| r0p30 | 3000 / 3000 | 78.802 ns | PASS |

VCTM-MC5-NM 3-flit 原生多播：

| Case | 注入/交付 flit | 交付 packet | 平均 packet latency | 结果 |
|---|---:|---:|---:|---|
| r0p02 | 3000 / 3405 | 1135 | 42.835 ns | PASS |
| r0p10 | 3000 / 3303 | 1101 | 49.893 ns | PASS |
| r0p20 | 3000 / 3378 | 1126 | 63.181 ns | PASS |
| r0p30 | 3000 / 3285 | 1095 | 103.911 ns | PASS |

全部 case 均满足：

- `missing_expected_flits = 0`
- `unexpected_flits = 0`
- `timeout_hit = 0`
- `rx_overflow = 0`

原始结果：

- [TAB_16.csv](../sim/results/ultra_noc16/ackgen_restored/TAB_16/TAB_16.csv)
- [VCTM_16.csv](../sim/results/ultra_noc16/ackgen_restored/VCTM_16/VCTM_16.csv)

## 12. ReqGenerator 去 Delay/Block 后的回归证据

最终 ReqGenerator RTL 中不存在 `DelayElement` 或
`admissionBlocked`。`sbt compile`、RequestGeneratorBank smoke 和
UltraRouter smoke 均通过；两个 smoke 分别覆盖 Head/Body/Tail 的 PPE
保持与完整 Router 多播。

**最后修正：2026-07-31。** 随后完成了 RS 接口收敛：IPM 的 raw `RS` 只接
Atomic，`RequestGeneratorBank.RS` 只接 `Atomic.admittedRS`；临时的 raw
`RS`/`Admit` 双接口已经删除。以该最终接口重新生成 RTL、运行两个 smoke 和
NoC16 r0p02，结果如下；这也说明 VCTM 的通过不依赖 `Admit` 或 ReqGenerator
内的固定 delay。

最终 RS-only 接口的 NoC16 r0p02 结果目录为
`sim/results/ultra_noc16/reqgen_rs_only`：

| Case | 注入/交付 flit | missing | timeout | 结果 |
|---|---:|---:|---:|---|
| TAB-NET-UR-3f-r0p02 | 1002 / 969 | 2031 | 1 | FAIL |
| VCTM-MC5-NM-3f-r0p02 | 3000 / 3405 | 0 | 0 | PASS |

TAB 的 failure 没有 unexpected flit。终态探针显示多个 Router 的
`packetActive` 与 PPE 正在等待尚未进入下一跳的非 Tail flit，
`allTailPassed=0`；这是跨 L1/L2/FIFO 的资源等待，不是 ReqGenerator
局部 Tail 丢失。仅恢复 `admissionBlocked` 的隔离实验同样失败，因此不应
把 Block 或固定 Req 延时作为网络级依赖环的修复。

原始结果：

- [TAB_16.csv](../sim/results/ultra_noc16/reqgen_rs_only/TAB_16/TAB_16.csv)
- [VCTM_16.csv](../sim/results/ultra_noc16/reqgen_rs_only/VCTM_16/VCTM_16.csv)

## 13. 后续建议

### 13.1 2026-07-31 控制链快照复核

在最终 RS-only 接口的 `TAB-NET-UR-3f-r0p02` 超时点，五个 Router 的
Atomic/ReqGen/TailJoin 快照给出以下结论：

- 每个仍活跃的 packet 都有对应的 `PPE=1` 和 `Done=1`；没有出现
  `packetActive=1` 而 `PPE=0` 的 Atomic 准入丢失状态。
- 所有活跃 packet 的 `tailSeen`、`TailPassed`、`allTailPassed` 都为零；这表示
  Tail 尚未进入 OPM，而不是 TailJoin 漏记或 Atomic release 未响应。
- L2 与多个 L1 的选中分支均保持 `Req != Ack`，同时其余 Head 因目标 owner
  被占用而 `pending=1, eligible=0`。当前可观测停滞点在下游 branch/output
  handshake，而不在 Atomic→ReqGenerator 或 TailJoin 控制链。

这不能单独证明 FIFO 深度不足：低注入率下同样可能由一个确定的路由/资源组合
形成 wait-for 环。下一步必须观测跨 L1/L2 FIFO 各级 Req/Ack/占用，才能区分
“FIFO 已满导致的资源环”与“跨层链路握手未推进”。在该证据出现前，不删除
`headEpoch/admittedEpoch`，也不向 ReqGenerator 恢复 delay、block 或 Admit。

下一阶段可以在不改变 Router 内部架构的前提下分两步进行：

1. 先为现有 PRS、ReqGenerator、OPM、Tail release 和 link FIFO 建立明确的
   relative-timing constraint 清单及门级检查，避免继续依赖行为级 DEL。
2. 再在当前 8 个 inter-level FIFO 位置实现并替换 Transition Fig.6/Fig.7
   circular FIFO，对 3-flit 和 20-flit case 比较吞吐、延迟、面积和停滞状态。

在 circular FIFO RTL、WCB/RCB 和物理时序约束完成前，不应把当前串联
`AsyncFifo` 称为论文 Fig.6 的实现。
