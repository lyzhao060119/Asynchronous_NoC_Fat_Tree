# Ultra Delay Role and Replacement Inventory

最后修正日期：2026-08-17（§42 PRS50 已接受）

本文盘点当前 `UltraRouter` 宏内的显式 `DelayElement`，并明确区分：

1. **RTC 必要性**：某个数据/状态必须先稳定、控制/关闭事件才可以到达；
2. **显式 DEL 必要性**：是否必须用 RTL 内的 `DelayElement` 实现该 RTC。

两者不能混淆。对于 bundled-data 异步电路，第一项不可删除；第二项通常可以由受约束的综合/P&R 的 cell sizing、buffer/inverter insertion、routing 和 `set_min_delay` 实现，但只有在所有 PVT/路径下确实闭合后，才可以删除显式 DEL。

## 1. 当前范围和计数

当前 profile 为 `ULTRA_P250_PRS_ACG_OPM75`。每个 `UltraRouter` 有 25 个
显式 DelayElement：

| 类别 | 实例数 | 当前档位 | 是否处于 Router forward Head path |
|---|---:|---:|---|
| PRS matched delay | 5 | DEL050 | 是 |
| Head capture | 5 | DEL250 | 是 |
| Anchor / round close / membership / final builder | 1 / 1 / 4 / 1 | DEL250 | 是 |
| Return | 1 | DEL250 | 否，影响下一轮 reopen |
| ACG commit fire / commit Ack | 1 / 1 | DEL250 | fire 是；Ack 否 |
| OPM V2 request margin | 5 | DEL075 | 是 |

不计入本表：NoC endpoint 的 `AsyncEndpointAckDelay`、测试平台 Ack dwell、
仿真 `#delay`、NoC link/FIFO 的延时，以及未接入当前 V2 Router 的 legacy
模块。这些不应计入 Router forward latency。

Delay role/profile 的定义在
[`AsyncLib_ACG.scala`](../src/main/scala/tool/AsyncLib_ACG.scala)；物理 DEL
映射在 [`DelayElement_ASIC.v`](../src/main/resources/ASYNC/DelayElement_ASIC.v)。

## 2. 先给出判定原则

对每一项 RTC，必须使用同一事务参考事件、最晚数据和最早控制：

```text
Tctrl_min >= Tdata_max × (1 + RTM_target)
```

因此：

- **“必须保留 RTC”**：上式代表的先后顺序必须存在，不能因降低 E2E 延迟删除；
- **“显式 DEL 可候选删除”**：在不插入该 RTL DEL 时，综合/P&R 仍能通过
  `set_min_delay` 达到上式，且同时以有限 `set_max_delay` 避免过度拖慢控制；
- **“当前不得删除”**：还没有该 role 的 multi-corner paired RTC 证据，或已经有
  严格 SDF 失败证据。

换言之，不能仅从原论文图中“未画 DEL”推导当前 DEL 一定错误。论文图通常描述
功能拓扑；其门延时、布线和物理优化隐含地提供了相对时序。项目中的显式 DEL 是把
该物理假设固定在 RTL 的一种实现方式。

## 3. Router 内 Delay 逐项清单

| Role / 数量 | 当前控制路径 | 受保护的数据或状态路径 | RTC 的作用 | 显式 DEL 的当前判定 | 可替代方式与下一步 |
|---|---|---|---|---|---|
| PRS matched ×5, DEL050 | `ReqX → DEL → XOR AckX → RS/PRSReady` | ungated RoutingLogic `_GEN_8` / `projectedDir`（不是 V1 DataOut，也不是 gated `decision_dir` / RS） | ungated route_valid 必须先稳定，RS 才可以打开。 | **RTC 必须；显式 DEL 已单角色降到库最小档 DEL050（R3f）。** §42：`Tdata` from ReqX = 0 ps，`Tctrl` = 196 ps，`Tprs` = 55 ps，残差 141 ps ≥ 80 ps 下限。五项 SDF 通过，Head **2.165 ns**。**已接受**为当前 SYNTH-CLOSED。不要 PRS0。 | 库里没有更小的 PRS cell。不要 DelayValue=0。不要混 R4b/Return/OPM/DFIRE0。 |
| HeadCapture ×5, DEL250 | `local_head → head_margin → packet_present` | `local_mask → mask_latch` | `packet_present` 锁住 mask 前，完整 routed mask 必须已经到达，否则会锁存部分目的集合。这里 `local_head = OR(RS)`、`local_mask = RS` 的重编码：若各 RS bit 会 skew，最先到达的 bit 可先把 `local_head` 拉高而其它 multicast bit 尚未稳定。 | **“完整 mask 先于 P”这个 RTC 必须；显式 DEL 是否需要尚未证明。** PRS 已保护 `RoutingInfo → RS`，HeadCapture 只可能是在保护 RS vector 内部的 bit skew。 | 先直接量 `RS[*]` 最后稳定时刻到 `packet_present`/mask latch close 的间隔。若 local-head OR 本身和 latch/布线已提供所需 min-delay，则 `head_margin` 可以是 DEL0 候选；否则以该 RTM 约束或最小 DEL 实现。 |
| Anchor ×1, DEL250 | `anchor_any → anchor_margin → anchor_start` | Mutex5 grant、`anchor_q`、`anchor_mask` | 一轮 membership 开始前，anchor one-hot 与 anchor mask 必须冻结。 | **RTC 必须；显式 DEL 暂保留。** | 可用 anchor snapshot→round-start 的 `set_min_delay` 替代；应先和 RoundClose 分别测量，不可同时削减。 |
| RoundClose ×1, DEL250 | `anchor_start → round_close_margin → round_close` | `anchor_q`、`anchor_mask` 和 candidate membership 输入 | 使 anchor snapshot 稳定后，才打开四个并行 membership race。 | **RTC 必须；显式 DEL 暂保留。** | 它是当前 Head 延迟的较大候选来源之一。先冻结 descriptor/data cone 后，再逐档缩减或以控制 min-delay 实现。 |
| MembershipClose ×4, DEL250 | `close_grant → close_margin → close_ready` | `stage_closed`、`member_seen` | `stage_closed` 由同一 `close_grant` 写入 latch，且 `MullerC2(stage_closed, close_delayed)` 已要求它为 1。故“等待 `stage_closed`”由 C-element 本身完成；`close_margin` 仅在两项都准备好后再强制额外等待。 | **`stage_closed` 先确认这个协议条件必须；当前额外 DEL250 不具有已证明的功能必要性，是最高优先级 DEL0 候选。** | 先将一个 role 的 `MembershipDelayValue=0`，保持 C-element 的两个输入为 `stage_closed` 和未延迟的 `close_grant`，验证 close-ready 脉冲、late contender、all-membership join 和 strict SDF。若失败，再以测得的 C-element/recovery 或 downstream builder RTC 建立最小约束，而不是默认 DEL250。 |
| FinalBuilder ×1, DEL250 | `all_membership_closed → final_builder_margin → final_builder_ready` | greedy fold 的 `win4` / transaction bundle | 所有 membership frozen 后，greedy winner/mask 和 transaction latch D 必须稳定，才允许 `tx_valid`。 | **RTC 必须；显式 DEL 暂保留。** | 候选由 `transaction latch D` 的 `Tdata_max` 导出。可以是约束替代的较好对象，但不能在 builder data cone 未冻结时删除。 |
| Commit/ACG fire ×1, DEL050 | frozen `tx_valid/Start → Dfire → fire` | transaction latch Q、active/owner 更新输入 | ACG fire 采样的必须是已冻结 transaction，而非实时 membership/mask。 | **RTC 必须；显式 DEL 已单角色降到库最小档 DEL050（R3f）。** 名义表 75 ps 低于 80 ps 下限，但映射实测 `Tctrl=97 ps`。五项 SDF 通过，Head **2.486 ns**，**已接受**为当前 SYNTH-CLOSED。DFIRE0 仍拒绝。首 Head OPM V2 RTM5 有 22 ps shortfall，body 为 0。 | 库里没有更小的 DEL cell。不要重试 DFIRE0。更大的 Head 切片仍在 PRS（0.583 ns）与 OPM ReqOut（0.655 ns）。 |
| Return ×1, DEL250 | `fire → return_margin → round_reset` | active、owner、transaction、reservation release 清理 | 前一 transaction 的状态清理完成前，不能开始下一轮。 | **RTC 必须；不在首个 Head forward path，低优先级。** | 用 fire→state-clear/reopen 的 paired release RTC 验证。可约束替代，但不要为了 Head latency 优先修改它。 |
| Commit Ack ×1, DEL250 | `commitController.Out.Req → commitAckDelay → Ack` | 无 bundled payload；ACG 输出握手状态 | 给 ACG 输出握手一个完整、可恢复的返回事件，避免回路过快。 | **协议回路必要；不在 fire 前关键路径。** | 需先定义 ACG 自身的 recovery/min-pulse 约束。当前不建议作为性能优先项。 |
| OPM V2 request margin ×5, DEL075 | `selectedReq → XOR4 → v2RequestMargin → L5 D → ReqOut` | `DataX → MG Mux → V2 data-latch D/Q` | 在共享 V2 latch 关闭、ReqOut 可见前，selected data 必须已经稳定；它不改变 L1→Ack、MG、TP 或数据锥。 | **RTC 必须；显式 DEL 是候选可删除项。** 当前 OPM75 是项目扩展，不是 Ultra Fig.5(b) 明画的器件。 | 优先建立 `dataOutLatch.D` 相对 latch `E`/close-event 的 pin-level paired RTC。若无 DEL 的 OPM0 在所有 PVT 满足目标 RTM，可删除；否则首先让综合/P&R 按 `set_min_delay` 插入局部 buffer，最后才保留最小 RTL/ECO DEL。 |

上述结构位置可直接在下列源文件中核对：

- PRS：`PacketRouteSelector` / `IPM`；
- OPM：[`OPM.scala`](../src/main/scala/Router_Architecture/ultra/OPM.scala)；
- HeadCapture：[`UltraHeadCaptureCell.v`](../src/main/resources/ASYNC/UltraHeadCaptureCell.v)；
- Anchor、RoundClose、FinalBuilder、Return：
  [`AsyncArbiterTransactionController.v`](../src/main/resources/ASYNC/AsyncArbiterTransactionController.v)；
- MembershipClose：
  [`AsyncRoundMembershipCell.v`](../src/main/resources/ASYNC/AsyncRoundMembershipCell.v)。

## 4. OPM：论文图与当前显式 DEL 的关系

当前 OPM 代码明确注明：四路 two-phase request 在 XOR4 合并后进入
`v2RequestMargin`，该 DEL 的作用是延后 L5 closure/ReqOut，而不改变数据路径或
上游 Ack/TP：

```text
selectedReq[0:3] → XOR4 → [v2RequestMargin] → L5 request latch → ReqOut
DataX[0:3]       → MG Mux ───────────────────→ V2 data latch → DataOut
```

这颗 DEL 是项目为 Part VII bundled-data margin 加入的显式实现。Ultra 的 OPM
功能图没有把 XOR4 后的 DEL 画成独立模块，并不表示可以不满足该 RTC；它表示该
论文实现把匹配留给门级/物理实现或其它未展开的时序假设。

因此 OPM 是**最值得优先尝试以综合/P&R 约束取代 RTL DEL 的角色**，但目前不能
直接删除：

- 当前 20-edge SDF 观测以 `DataOut/ReqOut` 为端点时接近零 margin，不能证明
  OPM0 已安全；
- 该观测仍混合了 V2 latch 和输出可见性，必须改成 `dataOutLatch.D` 对实际
  latch `E`/close-event 的测量，才能回答“Data 是否已经在 Mux 后等待”；
- `OPM0` profile 已存在，适合在完成上述测量及多 PVT STA 后作为单变量候选。

## 5. 综合/P&R 应怎样替代显式 DEL

替代并不是把 DEL 删掉后不约束地运行 `compile_ultra`。正确过程是：

1. 保护 C-element、Mutex、latch/DFF、ACG、close-event、反馈与 hierarchy；
2. 仅对普通数据锥设置局部 `set_max_delay`，完成 sizing/buffer 优化并冻结
   `Tdata_max`；
3. 对对应的控制段设置：

   ```tcl
   set_min_delay $required -from <ctrl_start> -to <ctrl_end>
   set_max_delay [expr {$required + $extra_slack}] \
       -from <ctrl_start> -to <ctrl_end>
   ```

   其中 `required = Tdata_max * (1 + RTM_target)`；
4. 用 incremental synthesis/P&R 让工具选择 drive、buffer 和局部 routing；
5. 若最小延迟仍无法稳定满足，才在**违反的控制 segment**插入最小 DEL ECO；
6. 对每个候选重新做 paired min/max RTC、latch/DFF setup/hold、严格 SDF 和
   Router/NoC 回归。

现有
[`async_ultra_router_datapath.sdc`](../scripts/asic_dc/ultra/async_ultra_router_datapath.sdc)
已经是第 2 步的数据锥 overlay；它故意不约束 request、Ack、DEL 或异步状态锥。
控制 RTC 的逐路径 min/max 内环尚未落地，而且当前 overlay 的 mapped-DDC pin
绑定为零，必须先修复绑定，不能把尚未生效的约束视为结果。

## 6. 推荐的实验顺序

1. 修复 datapath overlay 的 DDC pin/port 绑定，先得到冻结的 `Tdata_max`；
2. 先量 OPM 的 `D → E/close-event`，确定 OPM75 是否是实际需要还是仅为保守；
3. 对 PRS、HeadCapture、RoundClose、MembershipClose、FinalBuilder、Commit 各自
   建立 paired RTC，不混合多个 DEL；
4. 对每个 role 先尝试“约束替代显式 DEL”，无法闭合才测试最接近边界的 1–2 个
   DEL 档位；
5. Return 和 commit Ack 留到 Head latency closed 之后，按 release/recovery
   correctness 优先，而不是 E2E 首包延迟优先。

任何 role 在没有其 `Tdata_max` 与 `Tctrl_min` 证据前，都只能标为“当前暂保留”，
不能标为“绝对必需”或“可以安全删除”。
