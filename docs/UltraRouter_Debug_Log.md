# UltraRouter 调试日志

最后更新：2026-08-05

本文件记录 UltraRouter 单体的 RTL、DC、严格 SDF GLS 与 STA 调试证据。
它不替代架构规范
[`ultra_mousetrap_paper_architecture.md`](../src/main/scala/Router_Architecture/ultra/ultra_mousetrap_paper_architecture.md)，
也不替代 NoC16/TAB/VCTM 的历史复盘
[`Ultra_NoC16_TAB_VCTM_Debug_Timing_FIFO_Review.md`](Ultra_NoC16_TAB_VCTM_Debug_Timing_FIFO_Review.md)。

## 1. 信号域约定

| 域 | 信号 | 定义 |
|---|---|---| 

| 外部输入 | `ReqIn/AckIn` | 两相输入端口握手；`AckIn := ReqX`。 |
| IPM 内部 | `ReqX/AckX` | V1 输出请求与 AckGenerator 返回的本地完成确认。`AckIn` 不等于 `AckX`。 |
| 请求分支 | `Req/Ack/Done` | 每个 ReqGenerator/OPM 分支的两相请求、确认与 `Done=Req xor Ack`。 |
| 多 flit 保持 | `PPE/Grant/MG` | Head 建立的路径保持、OPM Grant 观察和 Tail 前路径掩码。 |
| 输出边界 | `ReqOut/AckOut` | OPM V2 与下游端口的两相握手。 |

V1 只有在 `AckX == ReqX` 且 `PRSReady == 0` 时重新透明；`AckIn == ReqIn`
只说明 V1 已把当前输入相位复制为 `ReqX`，不单独证明 V1 已重新打开。

## 2. 运行记录格式

每轮必须记录：日期、目标、改动文件、RTL hash/远程 run ID、仿真模式、通过项、首个失败边沿、
波形或日志路径、已证实结论、仍待证假设、下一步。没有波形或事件日志支持的判断必须标记为“待证”。

## 3. 当前故障：Body 未进入 V1

### 3.1 已证实证据

- 远程 run：`20260805_c2c3_comb_reset`。
- DC：PASS，`GTECH=0`；STA：完成，`DEL250_COUNT=7`；严格 SDF 注释成功，无 `IFNSDFA`。
- Head 的 parent 输出请求被观察到，且 TB 在进入 Body 前已验证
  `DataOut[4] = 28'h8820820`；因此当前没有 Head 数据路径错误证据。
- 严格 SDF 在 Body 输入确认等待中超时：

  ```text
  TB_RESULT FAIL input_ack t=2034 ns
  in_req=00000, in_ack=00001, out_req=10000, out_ack=10000
  ```

  对 child0 而言，末态为 `ReqIn=0`、`AckIn=ReqX=1`。这表明 Body 的外部
  请求相位没有被 V1 request latch 接收；它不是 `AckX`、OPM branch Ack 或
  `AckOut` 的直接观测值。

### 3.2 当前待证假设

1. Head 后 branch3 的 `Done` 没有从 1 回落，导致 AckGenerator 的 `complete`
   没有产生上升沿。
2. `Done` 已回落但 AckGenerator 的 event-DFF 没有使 `AckX` 跟随 `ReqX`。
3. `AckX` 已翻转，但 PRS/V1 的 `PRSReady/latch_en` 反馈未恢复。
4. `latch_en` 已恢复而 Body request/data latch 未采样。

尚不能以当前边界日志判定上述任一假设。

### 3.3 本轮诊断操作

本轮只添加 simulation-only trace/VCD：不增加 Router 公共 IO，不改变 Router
功能方程，也不把内部 `AckX` 作为 TB 的流控条件。

- 记录 `ReqIn, AckIn/ReqX, AckX, latch_en, PRSReady`；
- 记录 branch3 `admittedRS, Req, Ack, Done, PPE, Grant, MG`；
- 记录 parent `ReqOut, AckOut, DataOut`；
- 基线保持原 Body 注入行为；另扫描 parent `AckOut` 后 `0/1/5/20 ns` 的固定等待，
  仅判断 `AckX` 是迟到还是未发生。

### 3.4 本地 RTL 基线结果

`tb_ultra_router_control_trace` 使用结构化 `Mutex2.v`、`BODY_GAP_NS=0` 通过。
关键时间顺序如下（xsim，时间分辨率 1 ps）：

```text
22.0 ns  Head ReqIn↑，ReqX/AckIn↑，V1 latch_en↓，PRSReady↑
23.0 ns  branch3 Done↑，parent ReqOut↑，DataOut=8820820
23.0 ns  OPM branch Ack↑，Done↓，complete↑，AckX↑，PRSReady↓，latch_en↑
24.0 ns  Body ReqIn↓，ReqX/AckIn↓，branch3 Done↑，parent ReqOut↓，DataOut=0020820
24.0 ns  branch Ack↑，Done↓，complete↑，AckX↓，latch_en 重新打开
```

结论：RTL 的多 flit 控制顺序符合预期；Body 不受 `AckIn` 提前返回的影响。
严格 SDF 必须比较同一组边沿，特别是 `Done↓ → complete↑ → AckX↑` 是否中断。

### 3.5 门级 trace 运行状态

- `20260805_body_ackx_trace`：DC/STA 完成；严格 SDF 在编译 trace TB 时停止。
  原因是综合网表扁平化后删除了 `requestBanks_0_io_Req_3`、
  `requestBanks_0_io_Done_3`、`requestBanks_0_io_PPE_3` 与
  `outputModules_4_io_MG_0` 临时名。该失败发生在仿真启动前，不能作为功能证据。
- `20260805_body_ackx_trace2`：TB 已改为使用综合网表保留的节点：OPM L1.Q、
  branch Ack、Grant 与 L1 enable，并已提交 DC/SDF/STA。结果待远程产物回收后填写。

当前远程执行环境暂时拒绝回收操作；在拿到 trace2 的 `ULTRA_TRACE` 前，
`Done/complete/AckX` 的 SDF 首个断点仍为待证。

静态语义补充：V1 是 level-sensitive latch。Body `ReqIn` 翻转后保持不变，
因此只要 `AckX` 最终追平 `ReqX` 且 `PRSReady` 下降，`latch_en` 就会重新为高并
自动采样该 Body 相位；TB 的 2 us `input_ack` 超时说明这种“重新打开”在该观察窗口内
没有发生。它排除“仅比 1 ns body gap 稍晚”的解释，但仍不能区分 `Done`、`complete`、
`AckX` 或 `PRSReady/latch_en` 中的首个失效点。

## 4. 修复与回归记录

| 日期 | 改动 | 证据/结果 | 结论 |
|---|---|---|---|
| 2026-08-05 | C2/C3 改为 reset 零钳位的纯组合自反馈方程；本地 smoke 使用 `Mutex2.v` | C2、C3、Mutex5、Atomic、ReqGenBank、UltraRouter H/B/T 本地 smoke PASS；远程 DC PASS | 当前 SDF Body 停滞需独立定位，不能归因于 C2/C3。 |
| 2026-08-05 | 新增 simulation-only control trace 与 VCD 支持 | 本地 RTL H/B/T trace PASS，确认 AckGenerator 在每个 flit 的 `Done↓` 后推进 AckX | 待严格 SDF 对照同一事件链。 |
| 2026-08-05 | 门级 trace 使用综合网表保留层次节点 | 首次 trace 因优化删除的临时网名编译失败；修正后 run `20260805_body_ackx_trace2` 已提交 | 等待回收 SDF trace，不修改 DUT。 |
| 2026-08-05 | run `20260805_sdf_body_reopen_diag`：严格 SDF 编译一次并运行 Body gap 0/1/5/20 | DC `GTECH=0`、SDF 注释成功、STA 完成。Head 在 parent 正确交付 `8820820`；`AckOut` 追平后 OPM local-source0 branch Ack 仍为 0，`Done` 因而保持 1，AckGenerator complete/AckX 与 V1 reopen 均未发生。 | 首断点是 OPM Ack DFF 的 capture 链；下一步只检查其 clock/data/reset 映射与 SDF timing arc，不修改 ReqGen、PRS、`AckIn := ReqX` 或 TB 流控。 |
| 2026-08-05 | run `20260805_opm_ack_dff_diag` 增加 OPM `regEnable`、Ack-DFF CP 与 D=L1.Q 的只读 trace | 零延迟 `AckOut` 下，`requestOutLatch_en` 始终为 1，Ack-DFF CP 始终为 0；这证明 Ack DFF 未触发的直接原因是 V2 的 Req/Ack 不同相窗口被 TB 的同-delta Ack 吞没，而非 DFF 映射/复位错误。 | 根因定位为 receiver TB 的零响应延迟。 |
| 2026-08-05 | receiver TB 在确认边界 `ReqOut/DataOut` 后保持 `0.2 ns` 再返回 `AckOut`；run `20260805_opm_ack_dwell200ps` | 严格 SDF、原始 DC 网表/SDF：`ULTRA_DC_PASS`、SDF annotation 完成、`TB_RESULT PASS UltraRouter unicast3`。每个 flit 都观察到 `regEnable↓ → Ack-DFF CP↑ → Ack↑ → Done↓ → AckX↑ → V1 reopen`；Head/Body/Tail 数据均正确。 | 单 Router 严格 SDF H/B/T 通过；该 0.2 ns 是外部 receiver 的物理响应时间，不是 DUT 内部补偿 Delay。 |
| 2026-08-05 | run `20260805_hbt_sdf_timing` 记录三 flit 的外部握手时间 | Head：ReqIn 30.200 ns、AckIn 30.400 ns、ReqOut 32.300 ns、AckOut 32.500 ns；Body：33.700/33.800/34.000/34.200 ns；Tail：35.400/35.600/35.800/36.000 ns。 | 严格 SDF H/B/T 测量 PASS；前向延迟分别为 2.100/0.300/0.400 ns，含 receiver Ack 的完整输出握手为 2.300/0.500/0.600 ns。 |
| 2026-08-05 | run `20260805_hbt_sdf_exact_edges` 使用 `@(AckIn)` / `@(ReqOut)` 记录真实门级边沿 | Head `ReqIn/AckIn/ReqOut/AckOut=30.200/30.330/32.256/32.500 ns`；Body `33.700/33.799/33.979/34.200 ns`；Tail `35.400/35.530/35.732/36.000 ns`。 | 严格 SDF PASS。真实前向 `ReqIn→ReqOut` 延迟：Head 2.056 ns、Body 0.279 ns、Tail 0.332 ns；输入 Ack 延迟：0.130/0.099/0.130 ns。完整 `ReqIn→AckOut` 为 2.300/0.500/0.600 ns，包含 receiver 0.2 ns 响应及 TB 0.1 ns 轮询量化。 |

> 本 run 的远程日志/VCD 已生成于 `logs/gls/20260805_sdf_body_reopen_diag/sdf/gap{0,1,5,20}`。完整 archive 回收受执行环境外部额度策略限制而被拒绝；不得绕过，待允许后仅执行正常 `--collect`。

## 5. 共同边界 Smoke：多播与竞争（2026-08-05）

新增 `sim/AsyncRouterL1/testbench/tb_ultra_router_boundary_smoke.sv`，作为本地
结构化 `Mutex2.v` xsim 与远程严格 SDF GLS 的同一份功能 TB。它只依据
`ReqIn/AckIn/DataIn` 和 `ReqOut/AckOut/DataOut` 工作：发送端固定
`DataIn → 0.2 ns → ReqIn toggle`，接收端确认输出和数据后再延迟响应 Ack。
没有内部状态参与发送、接收或判定。

本地结果：

| case | 结果 | 证据/结论 |
|---|---|---|
| `unicast3` | PASS | Child0→Parent 的 H/B/T 正确。 |
| `mc_single3` | PASS | Parent→Child0/Child1；两条输出均完整收到 H/B/T。 |
| `mc_disjoint_parallel3` | PASS（修正后） | A=Parent→Child0/Child1 与 B=Child0→Child2/Child3 并行，四个输出各收到所属 H/B/T。 |
| `uc_overlap_release3` | PASS | Child1→Parent 在 Child0→Parent Tail 完成后才开始输出。 |
| `mc_overlap_tailjoin3` | 已更正验收语义，待回归 | B 在 Child0 先出现是完整集合 reservation 后的合法 branch skew；应验证 Child1 保持 A Tail 至其自身 Ack，随后再输出 B。 |

原始 disjoint 用例写成 `Child2 → {Child2, Child3}`；该集合包含 no-U-turn 的
`Child2→Child2` 非法边，所以只看到 Child3，不是仲裁漏发。已改为合法的
`Child0 → {Child2, Child3}`。

`mc_overlap_tailjoin3` 的原始失败不是 TB 同-delta Ack 问题，而是验收断言过强：
Child1 的 Ack 特意延迟 1.0 ns，而 Child0 先完成 A Tail 后可以合法开始输出 B。
TailJoin 的完成事件定义为“Tail 已被 OPM V2 安全捕获”；Atomic 为 B 一次性
reservation 完整 `{Child0,Child1}`，但两个独立 V2 可在不同时间排出 B。B 的
Body/Tail 仍受所有 ReqGen branch Done 汇总约束，直到 Child1 也捕获 B Head 前
不能从输入端进入，因此不会覆盖或错位。

2026-08-07：项目确认维持 capture-completion 语义。TP 的 Tail 判据改为 V2
data latch 已提交的 `DataOut.isTail`，仍在 `regEnable↓` 采样；不改变 MG/PPE
或 TailJoin release 时刻。共同 smoke 允许 Child0 先输出 B，同时继续以 Child1
的 A Tail 数据检查保证该输出未被提前覆盖。

本地结构化 `Mutex2.v` 回归：C2、C3、Mutex5Anchor、Atomic、ReqGenBank smoke
全部 PASS；共同边界 smoke 的 `unicast3`、`mc_single3`、
`mc_disjoint_parallel3`、`uc_overlap_release3`、`mc_overlap_tailjoin3` 全部 PASS。
最后一例中 A Tail 的 O0/O1 Ack 为 26.7/27.5 ns，B Head 的 O0/O1 输出均为
27.6 ns；该运行未实际形成 branch skew，但 TB 允许合法 skew 且继续检查每条
输出的 A→B 顺序。下一步为同一 TB 的远程严格 SDF 回归。

远程 run `20260807_v2tail_boundary_reset10`：DC PASS（`GTECH=0`），STA 完成，
严格 SDF annotation 完成且无 `IFNSDFA`。`mc_single3` PASS；其余四例未通过：
`unicast3` 与 `uc_overlap_release3` 的第一条 Child0→Parent Head 都观察到
`expected=8820820, actual=8020800`，而 `mc_disjoint_parallel3` 与
`mc_overlap_tailjoin3` 在随后 Child-origin Head 的输出等待中超时。共同 TB 的
reset-release 至首注入间隔已从 2 ns 扩为与历史单播 GLS 相同的 10 ns，结果未变，
故 reset settle 不足被排除。该断点发生在首 Head、早于任何 Tail/TP 状态事件；本轮
记录为 Child-origin Head 的严格 SDF 数据/控制路径问题。它不可能是 Tail completion
语义错误，但 `DataOut.isTail` 新增的 Q fanout 可能间接改变门级负载/时序，仍须以
OPM/PRS data-control trace 定位；不得通过放宽数据比较或跳过失败 case 掩盖。

## 6. 严格 SDF 首 Head 数据断点：OPM V2 bundled-data（2026-08-07）

- 诊断 run：`20260807_sdf_data_trace`；复用失败 run
  `20260807_v2tail_boundary_reset10` 的**原始** `UltraRouter_post.v` 与同一 SDF，
  未重新综合、未使用 `+nospecify`、`+notimingcheck`、force 或 X 掩码。SDF 注释成功。
- TB 只以边界握手驱动：reset 在 20 ns 释放并再 settle 10 ns；`DataIn` 先稳定
  0.2 ns、随后翻转 `ReqIn`；仅在 Parent `ReqOut != AckOut` 后才返回 Ack。层次信号
  仅供记录，未参与任何发送或接收决策。VCD：
  `/home/ghy19/Asynchronous_Router_ultra/logs/gls/20260807_sdf_data_trace/sdf/data_trace.vcd`。
- 关键事件（ns）：

  ```text
  30.050  V1 data-latch Q 已稳定为 8820820
  30.200  Child0 ReqIn 翻转
  30.400  ReqX/AckIn 已翻转，V1 关闭；V1 Q 仍为 8820820
  32.200  Parent OPM V2 data-latch D 首先变为 8000000
  32.238  V2 D = 8020800（bit 5、23 尚未到达）
  32.261  Parent ReqOut 翻转——早于完整数据
  32.270  V2 Q/DataOut = 8020800（原 smoke 的错误值）
  32.275  V2 D 才稳定为 8820820
  32.306  V2 Q/DataOut 才稳定为 8820820
  32.415  V2 regEnable 关闭
  ```

- 结论（已证实）：首个错误不在输入 Mousetrap/V1；V1 Q 保持正确。也不是 Tail/TP
  判据。错误首先表现为 Parent OPM 的 V2 数据 cone 按位到达，而 V2 请求控制使
  `ReqOut` 提前 **14 ps** 于 V2 D 完整稳定、提前 **45 ps** 于 V2 Q/DataOut 完整稳定。
  因而接收端在合法的 `ReqOut` 事件上采到 `8020800`，而非 TB 映射错误。
- 唯一最小修复方向（尚未实施）：仅给 OPM 的 `mergedReq -> L5 -> ReqOut` 控制闭合
  支路加入依据 STA 最坏数据/控制差值确定的 matched delay，使 `ReqOut` 可见前 V2
  `dataOutLatch.D/Q` 已稳定并满足锁存器裕量；不改变 V1、TP、TailJoin、ReqGen、
  Atomic 或外部握手语义。必须以同一 SDF 回归验证，禁止通过延后 TB 采样掩盖问题。
## 2026-08-07 — Part VII RTM flow / RTL margin status

- The first valid OPM50 DC run preserved five explicit
  `v2RequestMargin/DEL050` cells and reached `GTECH=0`.
- Its first SDF H/B/T attempt stopped before OPM: the continuous source TB
  changed Body Data at 30.415ns while the Head V1 latch closed at 30.419ns.
  Historical passing smoke used per-flit Parent output completion plus a 1ns
  boundary recovery interval.  `unicast3` now uses that same boundary-only
  pacing before the RTL DEL sweep resumes.

- The timing baseline is now `Ultra_Design_Entry_and_Timing_Optimization_Flow.md`: structural entry is retained; only sizing, buffering, and explicit control-path DEL ECOs are allowed.
- Local structural C2/C3, Mutex5, Atomic, ReqGenBank and Router boundary-smoke regressions passed.
- Remote baseline `20260807_rtm0_struct_baseline` completed `ULTRA_DC_PASS`, `GTECH=0`, and `ULTRA_STA_DONE`.
- `20260807_rtm5_eco050_r4` is **not** valid DEL050 evidence: DC reported a recoverable `insert_buffer -lib_cell` syntax error, continued, and produced zero `DEL050` cells. Its func/SDF PASS is baseline-only.
- The post-map OPM ECO has been retired.  The correction is now one explicit
  XOR4-to-L5 `v2RequestMargin` DelayElement per OPM, with reset bypassing the
  DEL.  This removes dependence on unstable mapped net names and prevents any
  delay from reaching the L1-to-Ack DFF fanout.
- The next valid sweep uses generated RTL profiles OPM0/50/75/100/150/250;
  every DC run must prove its expected five mapped DEL cells before SDF is
  considered evidence.

## 2026-08-07 — Independent-output boundary-smoke rerun

- Replaced `receive_pair(...); join` with five independent output agents.  Each agent consumes only its own expected-flit FIFO and applies its own Ack delay; no output branch can gate a different branch's Ack or packet injection.
- Source injection remains strictly boundary-only: wait `AckIn == ReqIn`, drive `DataIn`, wait 0.2 ns, then toggle `ReqIn`.  Source tasks never inspect `ReqOut`, `AckOut`, or internal Router state.
- Local structural xsim PASS: `unicast3`, `mc_single3`, `mc_disjoint_parallel3`, `uc_overlap_release3`, and `mc_overlap_tailjoin3`; each case writes a dedicated VCD.
- Remote strict-SDF rerun is not yet a hardware result: the remote SFTP daemon reset during upload.  The runner now writes to a private temporary path, verifies SHA-256, then atomically renames; interrupted uploads can no longer truncate a published RTL/TB file.  Resume the remote DC/func/SDF/STA run only after a stable upload completes.

## 2026-08-07 — RTL OPM50 RTM result and per-flit source pacing

- Run `20260807_rtl_rtm_opm050_r4` used the frozen RTL profile
  `ULTRA_P250_PRS_ACG_OPM50`.  DC passed with `GTECH=0` and found exactly five
  `v2RequestMargin/DEL050` instances—one under each OPM.  This is the first
  valid physical DEL050 implementation, not the earlier failed post-map ECO.
- The source TB now sends one flit at a time: it waits for the matching Parent
  output request/data event, returns `AckOut`, and holds the external boundary
  for 1 ns before changing the next `DataIn`.  This is a testbench boundary
  recovery requirement only; it adds no Router delay and reads no internal
  state.  It removes the earlier V1 false failure in which Body data changed
  while Head closure was still propagating.
- Strict SDF annotated successfully and measured Head at
  `Tdata=2.072 ns`, `Tcontrol=2.150 ns`.  The resulting RTM is **3.76%**;
  the 5% requirement therefore has a `0.026 ns` shortfall.  The TB stopped at
  this deliberate RTM assertion before Body/Tail.  There was no V1 setup/hold
  violation in this run.  Therefore DEL050 is functionally clean but does not
  meet the 5% signoff target; the next candidate is RTL `OPM75`.

## 2026-08-07 — RTL OPM75 signoff result

- Run `20260807_rtl_rtm_opm075` used `ULTRA_P250_PRS_ACG_OPM75` and the same
  frozen boundary TB. DC passed with `GTECH=0`; its mapped-cell manifest lists
  exactly one `DEL075D1BWP12T30P140` below `v2RequestMargin` in each of the
  five OPMs.
- Strict SDF annotation completed without `IFNSDFA`. `unicast3` passed with
  the required data sequence `8820820 / 0020820 / 4420820`. The sampled RTM
  values are: Head `Tdata=2.072 ns`, `Tcontrol=2.200 ns`, **6.18%**;
  Body `Tdata=-0.058 ns`, `Tcontrol=0.450 ns`; Tail `Tdata=-0.038 ns`,
  `Tcontrol=0.450 ns`. Negative Body/Tail Tdata means the transparent data
  path had already settled before that flit's ReqIn phase edge; it therefore
  exceeds the data-before-control requirement rather than masking a late
  transition. All three have zero shortfall.
- Conclusion: `OPM75` is the smallest tested RTL control margin meeting the
  5% Child0→Parent H/B/T strict-SDF criterion. `OPM50` remains documented as
  the rejected 3.76% candidate. Func GLS remains diagnostic-only because its
  patched zero-SDF feedback model is not the physical signoff criterion.

## 2026-08-08 — Five-case strict-SDF smoke on the frozen OPM75 netlist

- Smoke log run `20260808_opm075_smoke5_sdf` deliberately reused the original
  DC post-netlist/SDF from `20260807_rtl_rtm_opm075`; no RTL or DC result was
  regenerated.  It used the same `tb_ultra_router_boundary_smoke.sv` and ran
  `unicast3`, `mc_single3`, `mc_disjoint_parallel3`, `uc_overlap_release3`,
  and `mc_overlap_tailjoin3`.  SDF annotation completed for every case without
  `IFNSDFA`.
- `unicast3` PASSed again, including the 6.18% Head RTM result.  The other
  four cases all stopped before a router output event at `input_ack_timeout`.
  Each first failure is preceded by strict V1 data-latch setup/hold warnings:
  their packet tasks write the next Body data at 30.415 ns while the prior
  flit's V1 closing event is 30.418/30.419 ns.  The receiver is not the cause;
  the violation is already at the source-side V1 latch, and it corrupts the
  source's ability to complete its next input handshake.
- This run is therefore valid evidence that OPM75 fixes the measured OPM V2
  control/data relation for the serial `unicast3` path, but it is **not** a
  multicast/competition hardware signoff.  The current multicast helpers must
  be converted to the same per-flit boundary recovery discipline before their
  SDF results can distinguish Atomic/ReqGen/TailJoin behavior from V1 source
  timing violations.  No Router RTL change follows from this run.

## 2026-08-08 — Per-flit multicast boundary recovery and aggregate acceptance

- The common smoke TB now pre-registers each logical packet's expected
  per-output A->B sequence, while each output agent still compares and
  acknowledges its own flit immediately.  A packet-level bitmap records H/B/T
  delivery per target and declares completion only after all target branches
  have independently acknowledged all three flits.  It therefore tests
  reservation atomicity without imposing simultaneous branch visibility.
- Every source uses `send_flit_and_drain_targets`: Data setup 0.2 ns before
  Req, then wait for that logical flit's complete target mask and hold 1 ns
  before changing DataIn.  A first implementation used `disable` on a shared
  task name; VCS allowed one concurrent source to terminate another source's
  wait.  The final helper uses an invocation-local completion flag instead.
- Local structural OPM75 suite PASSed all five cases.  In `mc_overlap_tailjoin3`
  packet A completed at 36.050 ns and packet B at 40.850 ns; the scoreboard
  accepted branch skew while retaining each output's A->B order.
- Remote strict-SDF run `20260808_opm075_boundary_smoke5_sdf_r3` reused the
  frozen `20260807_rtl_rtm_opm075` post-netlist/SDF.  Annotation succeeded and
  there were no V1 input-latch setup/hold failures. `unicast3` and `mc_single3`
  PASSed, including packet aggregation. `mc_disjoint_parallel3`,
  `uc_overlap_release3`, and `mc_overlap_tailjoin3` each completed packet A
  but timed out waiting for packet B Head's target output.  Thus the remaining
  defect is not source pacing or receiver atomicity; it is a second-packet
  admission/release-path issue. The disjoint case additionally reports an
  SDF timing violation at Atomic `capturedMask_0/packetActive_0`; the two
  overlapping cases have the same observable B-Head release failure and need
  a focused Atomic/ReqGen/TailJoin control trace next.

## 2026-08-08 — Disjoint B-Head Atomic timing diagnosis

- Scope: diagnose only; no Router functional RTL, arbitration equation,
  ReqGenerator, TailJoin, OPM, or boundary handshake behavior was changed.
  The strict-SDF run `20260808_disjoint_bhead_trace_r3` reused the *original*
  OPM75 post-netlist/SDF from `20260807_rtl_rtm_opm075` (post-netlist SHA-256
  `233d7d955d8a2e66047ae516a5ac54f5b335a97c4e09bc2360493ddfdba57eef`).
- Added simulation-only, hierarchical `TB_BTRACE` observation for input0 B:
  raw `RS`, `capturedMask`, epochs, Atomic eligibility/anchor/fire,
  `packetActive/mask/owner/admittedRS`, B ReqGen `Req/PPE/Done`, and the
  Child2/Child3 boundary requests.  No internal signal controls TB sending or
  receiving.  The common boundary TB additionally has two Head-only cases:
  `b_alone_head` and `a_then_b_head_parallel`.
- Local structural RTL: all prior five smoke cases plus both Head-only cases
  PASS.  In the A+B Head-only trace, B progresses through
  `RS=11 -> capturedMask=01100 -> eligible -> anchor -> fire ->
  packetActive/mask=01100 -> admittedRS=11 -> PPE=11 -> O2/O3 ReqOut` while
  A still owns O0/O1.  Thus the intended complete-set greedy algorithm does
  admit disjoint B in RTL; B does not need A Tail/release.
- Strict SDF, `b_alone_head`: PASS.  B reaches O2/O3 at 32.450 ns and both
  outputs acknowledge at 32.650 ns.  This excludes the independent
  Child0-to-Child2/3 PRS, ReqGen, and OPM Head path as the cause.
- Strict SDF, `a_then_b_head_parallel`: A Head reaches O0/O1, but B Head
  stops before `admittedRS`.  B does reach raw `RS=11` and
  `capturedMask=0110z`; the unobserved no-U-turn bit is optimized away in the
  gate netlist and is not the packet mask failure.  The selected mask bits are
  the expected O2/O3 set.  The decisive violation is
  `admission.packetActive_0_reg`: D changes at 31.705 ns and `fire_o` clocks
  it at 31.710 ns, only 5 ps apart versus a 21 ps setup requirement.  The
  resulting state is inconsistent: `packetActive_0=1`, but
  `packetMask_0=00000`, O2/O3 owners remain `none`, and `admittedRS=00`.
  Consequently B ReqGen `PPE/Req` remains zero and no Child2/Child3 ReqOut
  can occur.
- The same failure repeats in full `mc_disjoint_parallel3`: packet A completes
  all H/B/T, while B Head never receives a coherent Atomic commit.  A preceding
  `capturedMask_0_reg[2]` setup warning is 19 ps versus a 20 ps requirement in
  both B-alone and parallel runs; it is a real marginal Atomic capture path,
  but it is not sufficient to cause failure because B-alone still passes.
- Conclusion: the B Head stop is an **Atomic second-admission commit timing
  defect**, not a TailJoin release issue, an OPM issue, a ReqGenerator issue,
  a source-pacing issue, or a receiver atomicity rule.  The minimal future
  fix direction is to apply Fig.6-style relative timing inside Atomic: ensure
  the `capturedMask -> eligible/anchor/winner -> packetActive D` cone settles
  before the ACG `fire_o` commit edge, with at least the 21 ps DFF setup plus
  margin; separately close the 20 ps capturedMask D-to-localHead-clock setup.
  Do not compensate this by delaying OPM, PRS, receiver Ack, or B packet
  injection.

## 2026-08-08 — AtomicMulticastArbiterV2 Router integration, DC and strict SDF

- `UltraRouter` now instantiates `AtomicMulticastArbiterV2`; the legacy
  `AtomicMulticastAdmission` remains unmodified.  The remote manifest was
  extended to include `UltraHeadCaptureCell`, `AsyncRoundDecisionCell`, and
  `AsyncArbiterTransactionController`.
- Run `20260808_v2_router_opm075_smoke5` used the frozen
  `ULTRA_P250_PRS_ACG_OPM75` entry RTL.  DC passed with `GTECH=0`, no
  unresolved/unmapped cell, and exactly five OPM `DEL075` margin cells.
- Strict SDF annotation completed for all five common boundary cases with no
  `IFNSDFA`: `unicast3`, `mc_single3`, `mc_disjoint_parallel3`,
  `uc_overlap_release3`, and `mc_overlap_tailjoin3`.  Each case failed at its
  first Head output timeout: external input Req/Ack had completed, while all
  five output request phases remained zero.  Thus this is an earlier V2
  admission/startup failure than the historical second-packet V1 Atomic
  timing defect above.
- The run preserves the DC netlist, SDF, per-case logs, and five SDF VCDs in
  `scripts/asic_dc/ultra/results/20260808_v2_router_opm075_smoke5/`.  Next
  work must instrument the V2 gate-level chain from HeadCapture P/M through
  Mutex5, transaction `txValid`, ACG `fire_o`, and the active/owner bank;
  do not change OPM, ReqGenerator, TailJoin, or boundary TB pacing before
  that first missing transition is identified.

## 2026-08-08 — V2 strict-SDF first-Head trace: reset-release latch race

- Trace run `20260808_v2_router_head_trace_r2` reused the exact original
  post-netlist/SDF of the failing V2 run and added only a simulation-only
  hierarchy trace: HeadCapture P/M, Mutex5 request/grant, four decision-token
  ports, transaction valid/ACG Start/fire, and active/owner. No traced signal
  participates in the boundary TB handshake.
- At reset release (`t=20.000 ns`), before the first Head at `30.200 ns`,
  input0 already has `P=1, M=00000`; all Mutex5 request/grant bits remain
  zero. The four decision tokens then become `1111`, transaction valid and
  ACG Start assert, and repeated `fire_o` events occur with zero winner/owner
  state. When raw RS later becomes `1000`, P remains high with an empty mask,
  so no legal anchor request can form and no output request occurs.
- Root cause is the V2 reset protocol, not Mutex resolution. Several
  transparent latches open under `En=reset|event` but drive `D=1` whenever
  reset falls, even when their event is absent. Gate delay leaves En open long
  enough to capture that default one. The pattern affects
  `HeadCapture.present_latch` (`p_d` defaults to one), decision `valid_latch`,
  and the controller busy/commit/transaction-valid latches. Zero-delay RTL
  masks this release ordering, explaining the local/strict-SDF discrepancy.
- Minimal repair: every reset-open event latch must drive normal D from its
  positive protocol event (HeadCapture `head_set`, stage valid `close_ready`,
  busy `anchor_start`, commit-seen `fire`, transaction-valid `payload_ready`),
  while reset/release explicitly write zero. Reset deassertion then has
  `D=0, En=0` when no real event exists. Unit-smoke this repair before
  repeating Router SDF; OPM, ReqGenerator, TailJoin, and TB pacing stay fixed.

## 2026-08-08 — V2 reset-latch repair regression

- Replaced every identified reset-open/default-one latch with event plus Q
  self-hold: HeadCapture P, decision seen/ack/closed/valid, and transaction
  busy/commit-seen/valid. Reset or protocol clear still writes zero. The
  repair preserves transparent-latch state semantics and adds no DFF or event
  clock.
- New structural smokes for HeadCapture reset/capture/release and transaction
  controller reset/single-fire passed, alongside decision-cell, V2 Atomic,
  C2/C3, Mutex5, ReqGenBank, and all five local Router boundary cases.
- DC/SDF run `20260808_v2_reset_latchfix_opm075_smoke5` passed DC with
  `GTECH=0`, no unresolved/unmapped cell, and five mapped OPM DEL075 cells.
  Post-netlist SHA-256 is
  `bc5abe2c62d336e48f7d15450b79a3eec8e8615916ad0145830a395a9deb6568`.
- Strict SDF annotation succeeded without `IFNSDFA`. The reset/startup defect
  is fixed: `mc_single3`, `mc_disjoint_parallel3`, `uc_overlap_release3`, and
  `mc_overlap_tailjoin3` all PASS; `unicast3` reaches Parent output but stops
  only on the signoff TB's 5% RTM assertion. Its Head measurement is
  `Tdata=5.316 ns`, `Tcontrol=5.450 ns`, `RTM=2.52%`, shortfall `0.132 ns`.
  There is no X failure or V1/V2 setup/hold warning in that case log.
- Therefore this repair closes the gate-level functional startup issue. The
  remaining work is a separate V2 Head control/data relative-timing closure;
  do not reinterpret the RTM assertion as a reset, admission, or packet
  correctness failure.

## 2026-08-09 -- V2 Head strict-SDF end-to-end timing decomposition

- Diagnostic run `20260809_v2_head_timing_trace_r2` reused the frozen raw
  post-DC netlist/SDF from `20260808_v2_reset_latchfix_opm075_smoke5` (SHA-256
  `bc5abe2c62d336e48f7d15450b79a3eec8e8615916ad0145830a395a9deb6568`).  It
  changed only the common boundary TB by adding compile-guarded,
  observation-only hierarchy timestamps; it did not regenerate DC or alter
  any DUT port, state, handshake, or SDF annotation.
- Child0 -> Parent Head (`0x8820820`) was injected at `30.200 ns`.  The
  cumulative strict-SDF control timestamps are:

  | boundary / state event | time (ns) | delta from ReqIn (ns) | local increment (ns) |
  | --- | ---: | ---: | ---: |
  | V1 `ReqX` | 30.314 | 0.114 | 0.114 |
  | PRS `RS[Parent]` | 30.764 | 0.564 | 0.450 |
  | V2 HeadCapture `P` | 31.224 | 1.024 | 0.460 |
  | V2 Mutex5 anchor grant | 31.528 | 1.328 | 0.304 |
  | V2 decision stage 1 close token | 32.844 | 2.644 | 1.316 |
  | V2 decision stage 4 close token | 34.426 | 4.226 | 1.582 |
  | V2 transaction valid | 34.514 | 4.314 | 0.088 |
  | V2 ACG `fire_o` | 34.988 | 4.788 | 0.474 |
  | V2 active state / `admittedRS` | 35.056 / 35.119 | 4.856 / 4.919 | 0.131 from fire to admittedRS |
  | ReqGen `Req` / OPM L1 request | 35.201 | 5.001 | 0.082 |
  | ReqGen `PPE` / OPM Grant | 35.274 | 5.074 | 0.073 |
  | OPM `MG` | 35.316 | 5.116 | 0.042 |
  | OPM V2 `DataOut` stable | 35.516 | 5.316 | 0.200 |
  | first observed external `ReqOut` transition | 35.603 | 5.403 | 0.087 |

- The receiving boundary agent accepts the request at `35.650 ns`, yielding
  the signoff measurement `Tcontrol=5.450 ns`; the small 47 ps difference to
  the first observed `ReqOut` edge is boundary/event scheduling, so the RTM
  check retains the conservative receiver-observed value.  `Tdata=5.316 ns`,
  RTM is `2.52%`, and the 5% target shortfall remains `0.132 ns`.
- The V2 Arbiter interval from valid PRS RS to `admittedRS` is `4.355 ns`
  (`30.764 -> 35.119`), about 80% of the `5.450 ns` Head control latency.
  Within it, the four-stage round builder consumes `2.898 ns`
  (`Mutex5 anchor -> stage4`); HeadCapture plus Mutex5 consumes `0.764 ns`,
  and transaction-valid/ACG/commit-to-admittedRS consumes `0.693 ns`.
  These are handshake completion times under this SDF corner, not merely
  individual standard-cell arc delays.
- This evidence identifies the decision/token chain as the largest Head-only
  latency contributor.  It does not show a functional fault: the Head data is
  correct and all state events occur in order.  Future 5% RTM work should
  target the V2 builder/commit relative-timing profile before changing the
  already-correct V1, ReqGen, or OPM data path.

- Addendum, per-cell builder timestamps from the complete trace: decision
  stage 1 is `1.316 ns` after Mutex5 anchor; decision stages 2, 3, and 4 add
  `0.528 ns`, `0.527 ns`, and `0.527 ns` respectively.  Thus the full
  anchor-to-stage4 builder interval is `2.898 ns`.

## 2026-08-09 -- Parallel membership Builder: strict-SDF regression

- Replaced V2's serial `stage1 -> stage2 -> stage3 -> stage4` handshake
  chain with four parallel `AsyncRoundMembershipCell` instances.  Each still
  uses `Mutex2(candidate, common-roundClose)` and unchanged `DEL250`; a
  balanced three-C2 tree waits until every membership decision is closed.  A
  single frozen, combinational rotated-greedy fold then feeds the transaction
  latch through one final unchanged `DEL250` margin.
- No delay profile was shortened: this run remains
  `ULTRA_P250_PRS_ACG_OPM75`.  The speedup is purely from eliminating serial
  control dependency, not from reducing HeadCapture, Decision, Commit, PRS,
  or OPM DEL values.
- Local structural regression passed: C2/C3, Mutex5, HeadCapture,
  MembershipCell, transaction controller, Atomic V2 interface, and all Router
  boundary smokes.  The Atomic smoke retains legal-edge, disjoint parallel,
  late-candidate, rotated-greedy, overlap, release, and tail-busy coverage.
- Remote run `20260809_v2_parallel_membership_opm075_smoke5` passed DC with
  `GTECH=0`, no unresolved/unmapped cells, and five mapped OPM DEL075 cells.
  Strict SDF annotation completed without `IFNSDFA`; all five boundary cases
  passed: `unicast3`, `mc_single3`, `mc_disjoint_parallel3`,
  `uc_overlap_release3`, and `mc_overlap_tailjoin3`.
- Head timing comparison, Child0 -> Parent:

  | metric | serial builder baseline | parallel membership | improvement |
  | --- | ---: | ---: | ---: |
  | `ReqIn -> admittedRS` | 4.919 ns | 3.812 ns | 1.107 ns |
  | `anchorGrant -> txValid` | 2.986 ns | 1.867 ns | 1.119 ns |
  | `ReqIn -> receiver-observed ReqOut` | 5.450 ns | 4.300 ns | 1.150 ns (21.1%) |

- New Head time marks are: `roundClose=2.152 ns`; four parallel memberships
  complete by `2.614 ns`; C-tree all-closed at `2.741 ns`; final-builder ready
  at `3.115 ns`; `txValid=3.226 ns`; `fire=3.684 ns`; `admittedRS=3.812 ns`.
  This confirms that no candidate stage is waiting for a prior candidate
  stage.  The remaining DEL250 values are intentionally deferred to the next
  delay-shrink/STA phase.

## 2026-08-09 -- Ultra NoC16 local low-load regression

- Generated `generated_ultra/NoC_16nodes.v` from the current parallel
  membership Builder and ran the canonical AXI/BRAM NoC16 wrapper locally
  with structural `Mutex2.v`.  The runner now conditionally compiles Ultra's
  adjacent BlackBox resource files, including `AsyncRoundMembershipCell`, so
  the wrapper and case/scoreboard remain architecture-neutral.
- `TAB-NET-UR-3f-r0p02`: PASS; 3000 injected flits, 3000 delivered flits,
  1000 delivered packets, average latency 42.693 ns, p95 41.800 ns, p99
  80.000 ns; missing/unexpected/timeout/rx_overflow are all zero.
- `VCTM-MC5-NM-3f-r0p02`: PASS; 3000 injected flits, 3405 delivered flits,
  1135 delivered packets, average latency 42.968 ns, p95 60.000 ns, p99
  80.000 ns; missing/unexpected/timeout/rx_overflow are all zero.  The 3405
  deliveries confirm native multicast replication rather than a repeated
  unicast baseline.
- Logs, WDBs, compile output, and CSV summaries are isolated under
  `sim/results/ultra_noc16/parallel_membership_r0p02/`.

## 2026-08-09 -- Ultra NoC16 remote strict-SDF low-load regression

- Run `20260809_v2_parallel_membership_noc16_r0p02` used the current
  parallel-membership V2 RTL with `ULTRA_P250_PRS_ACG_OPM75`.  The remote
  manifest contained the same `async_noc16_axi_bram_wrapper.sv` and
  `tb_noc16_async_axi_bram.sv` used by the local xsim run, plus the identical
  TAB/VCTM `.case` files.  No direct asynchronous-port TB was used.
- DC completed with `ULTRA_NOC16_DC_PASS`, `GTECH=0`, and `SEQGEN=0`; the
  resulting `NoC_16nodes_post.v` and `NoC_16nodes.sdf` were the only DUT/SDF
  pair used by both cases.
- Strict `$sdf_annotate` completed for both cases.  The SDF invocation did
  not use `+nospecify` or `+notimingcheck` (only `+no_notifier`, so warnings
  remain observable).  Neither case is signed off:

  | case | injected / expected-delivered flits | observed delivered | result |
  | --- | ---: | ---: | --- |
  | `TAB-NET-UR-3f-r0p02` | 3000 / 3000 | 810 | FAIL: timeout, 2190 missing |
  | `VCTM-MC5-NM-3f-r0p02` | 3000 / 3405 | 1200 | FAIL: timeout, 2205 missing |

- The first visible physical failures are inside OPM V2 control/data state,
  not a wrapper or case-platform mismatch.  TAB reports hold violations at
  `routerL2.outputModules_1.requestOutLatch` (55 ps) and
  `routerL1_0_1.outputModules_1.requestOutLatch` (80 ps).  VCTM reports a
  17 ps setup violation at `routerL2.outputModules_3.ackState_1_reg`, then an
  80 ps hold violation at its `requestOutLatch`.  These violations precede
  the subsequent missing-flit timeout and are the next physical-timing
  targets; this run makes no claim that the RTL control functionality failed.

### Pin-level SDF evidence and port mapping

- The TAB case reports two independent V2 L5 (`requestOutLatch`) hold checks:

  | hierarchy | physical egress | SDF event | requirement | observed separation | shortfall |
  | --- | --- | --- | ---: | ---: | ---: |
  | `routerL2.outputModules_1` | L2 child-1, downward FIFO to L1 `(1,0)` | `E↓=729.297857 ns`, `D↓=729.297882 ns` | 55 ps | 25 ps | 30 ps |
  | `routerL1_0_1.outputModules_1` | L1 `(0,1)` child-1, core 9 | `E↓=842.867079 ns`, `D↑=842.867130 ns` | 80 ps | 51 ps | 29 ps |

- VCTM's first failure is in `routerL2.outputModules_3`, L2 child-3
  (downward FIFO to L1 `(0,0)`).  Its local source-1 Ack DFF sees
  `selectedReq` D at `745.417654 ns`, but the `regEnable↓`-derived CP arrives
  at `745.417663 ns`: 9 ps versus the required 17 ps setup, an 8 ps shortfall.
  The same OPM's L5 then sees `E↓=745.417802 ns` and `D↑=745.417856 ns`:
  54 ps versus an 80 ps hold requirement, a 26 ps shortfall.
- These are transparent-latch/DFF **cell-pin** timing checks, not an assertion
  that the external receiver Ack was early.  In OPM, L5 uses
  `D=DEL075(XOR4(requestLatches.Q))`, while its enable is
  `E=regEnable=~(L5.Q xor AckOut)`.  The Ack DFF data is `selectedReq` and its
  clock is `!regEnable`.  Thus L1/Q/XOR/DEL/L5/enable feedback is one local
  bundled-control loop.  The observed checks prove that a D transition reaches
  the mapped latch/DFF only 25/51/54 ps after its closing event (and the Ack
  DFF data only 9 ps before its clock).  They do **not** by themselves prove
  that the transition belongs to a new external flit: the run did not enable
  a narrow OPM VCD/edge trace, so the exact originating `selectedReq`/MG edge
  remains unobserved.  The next diagnostic must trace those nets around these
  timestamps before choosing between additional L5 control margin, an Ack-DFF
  data-to-close margin, or a correction to a late control re-evaluation.

### Confirmed cause of the apparently impossible L5 hold interval

- Direct SDF/netlist inspection resolves the contradiction.  The mapped
  `DEL075D1` has `I->Z` max arcs of about 101 ps rising and 103 ps falling, so
  the violating L5 D edge is not traversing the full post-`E↓` feedback loop
  in 25/51 ps.
- The physical close and sampling signals fork before the reset/open gate:

  ```text
  L5.Q/AckOut -> U8/U9 mismatch (`!regEnable`)
                         |-> Ack/TP DFF CP immediately
                         `-> U10 reset/enable gate -> L5/data-latch E
  ```

  `U9/ZN` drives every Ack/TP DFF CP directly.  L5/data-latch E is instead
  `U10/ZN`; U10 contributes approximately 111--139 ps on this transition.
  Consequently Ack/TP sampling and the ReqGen feedback it starts can precede
  the actual L5 E-pin falling edge by roughly that amount.
- The first TAB violation is quantitatively consistent with this skew.  The
  feedback D transition reaches L5 only 25 ps after E, despite passing through
  a 103 ps DEL fall arc, because the feedback was launched upstream of E about
  one U10 delay earlier.  The VCTM Ack-DFF setup shortfall is the same defect
  seen at the earlier boundary: `selectedReq` has only 9 ps before the early
  U9-derived CP.
- Therefore increasing the XOR-to-L5 DEL alone is not the architectural fix.
  The paper ordering requires Ack/TP sampling to represent the **actual V2
  latch-close event**.  The next RTL/physical correction should create one
  preserved `v2LatchEnable = reset || regEnable` signal for both V2 latches and
  derive the Ack/TP sampling clock from the complement of that actual enable
  after the close/reset gate (or provide an equivalent matched close-event
  element).  The implementation must then be checked after synthesis to ensure
  DC has not recreated the pre-gate CP fork.

## 2026-08-09 -- Global resettable latch and V2 physical-close correction

### Implemented correction

- `DLatchBank` now has high-active global `reset`.  In the ASIC-T28 DC entry
  it directly instantiates `LHCNDQD1BWP12T30P140` per bit with
  `CDN=~reset`; it no longer relies on an external reset-to-D mux or an
  enable-OR gate.  Protocol-local clear conditions (`round_reset`, release,
  `fire`, and packet-inactive) remain ordinary `D/En` operations.
- Each OPM now drives L5 and the V2 data latch from the same actual
  `v2LatchEnable=regEnable`.  `V2CloseEvent` is a preserved inverter after
  that latch-enable and is the sole CP source for the Ack and TP DFFs.  This
  removes the former pre-enable CP fork.

### Local verification

- `sbt compile` and UltraRouter generation passed.
- Resettable-DLatch, C2/C3, Mutex5, Atomic-V2, ReqGenBank, and all five
  boundary Router smoke cases passed with structural `Mutex2.v`.

### Remote UltraRouter strict-SDF sign-off smoke

- Run: `20260809_resettable_latch_closeevent_smoke5`.
- DC passed with `GTECH=0`; it contains 417 direct `LHCNDQD*` latches, zero
  plain `LHQ*` cells under `requestOutLatch`, and five preserved OPM
  close-event instances (ten hierarchy objects including each inverter).
- Strict SDF annotation completed with no `IFNSDFA`; all five cases passed:
  `unicast3`, `mc_single3`, `mc_disjoint_parallel3`,
  `uc_overlap_release3`, and `mc_overlap_tailjoin3`.  The run reported no
  X state or boundary-test failure.  STA completed against the same DDC.
- This is the first evidence that the prior OPM L5 hold and Ack-DFF setup
  defect is corrected at single-Router scope.

### NoC16 follow-up status

- NoC16 run `20260809_resettable_latch_closeevent_noc16_r0p02` completed DC
  successfully with `GTECH=0`, 2,085 direct `LHCNDQD*` latches, zero V2
  `LHQ*` latches, and 50 close-event hierarchy objects.
- Its TAB/VCTM LSF submissions (`11107201` and `11107301`) disappeared before
  producing a GLS `run.log`, `compile.log`, or SDF annotation log.  Therefore
  this run provides **no NoC16 functional/timing verdict** and must not be
  interpreted as a Router failure.  The remote runner's LSF terminal-state
  handling was corrected to recognize `DONE/EXIT`; the remaining missing-job
  launch issue must be resolved before rerunning the two canonical cases.

### Canonical NoC16 rerun result

- The job-launch ambiguity was removed by returning to the previously used
  direct flow: `bsub -K` invokes the frozen `run_gls_ultra_noc16.sh`, which
  compiles `tb_noc16_async_axi_bram + sdf_boot` against the current raw
  `NoC_16nodes_post.v/NoC_16nodes.sdf`.  No new TB, wrapper, scoreboard, or
  packet schedule was introduced.
- TAB job `11109601` completed real strict-SDF simulation.  SDF annotation
  reached `Done`; the result was FAIL after 581 injected flits, 547 delivered
  flits, two unexpected flits, 2,455 missing flits, and timeout.  The first
  observable corruption was at output/core port 6:

  ```text
  expected packet sequence 19 Tail: 410810b
  observed unexpected:            c10810b
  next unexpected:                0000000
  ```

- No runtime `$setup/$hold` violation was printed before this corruption.
  Compile/annotation still reports the same class of partial SDF interconnect
  annotation diagnostics seen by the previous NoC16 run (current total 6,157
  annotation errors versus 4,824 in the earlier run).  Therefore the present
  evidence does not yet distinguish a traffic-dependent Router state/release
  defect from a NoC16 hierarchical SDF annotation defect.
- Because TAB failed, VCTM was not run.  The single-Router five-case PASS is
  still valid but is insufficient coverage: those tests contain only a few
  packets and one Router, while TAB reaches the first bad event after hundreds
  of flits and multiple L1/L2 hops.

### 2026-08-09 retry note

- The NoC16 runner was corrected to create the per-run LSF stdout/stderr
  directory before submission and to flush large SFTP uploads.  The frozen
  NoC16 RTL, primitives, wrapper/TB, and both cases were successfully
  uploaded and hash-checked.
- A fresh SSH-only submission mode then reached the `bsub` invocation, but
  the remote scheduler call did not return a job ID.  The local runner was
  terminated without changing RTL.  This is a remote submission-service
  blocker; no new TAB/VCTM SDF result exists for this retry.

## 2026-08-09 -- TAB packet19 complete-error trace (NoC16 strict SDF)

### Scope and method

- Reused the frozen raw NoC16 post-DC netlist/SDF from
  `20260809_resettable_latch_closeevent_noc16_r0p02`; no Router, OPM,
  Arbiter, ReqGen, case, or DC input changed.
- The canonical AXI/BRAM boundary wrapper still owns injection and Ack.  The
  TB now writes a complete diagnostic file for every received flit and every
  missing expected flit.  A mismatch is recorded but does **not** finish the
  simulation; the original case timeout remains the only normal termination
  condition.
- Diagnostic job `11110701` enabled a narrow packet19/core6 trace.  Evidence
  is archived remotely under
  `logs/gls/20260809_resettable_latch_closeevent_noc16_r0p02/sdf/TAB-NET-UR-3f-r0p02/`:
  `tab_port6_packet19.trace`, `tab_port6_packet19.vcd`, and
  `checker_full.log`.

### What `1100` means

The trace is at L1 router `(1,0)`, physical output Child2 (core6),
`outputModules_2`.  Its local source index 2 is the Child3/core2 ingress;
local source index 3 is the Parent ingress.  At the packet19 Tail capture:

```text
time                 728.410 ns
source2 DataX        410810b   (packet19 Tail from core2)
source3 DataX        8108108   (a different parent-arriving packet)
MG[3:0]              1100      (sources 3 and 2 are both selected)
V2 dataLatch.D       c10810b
```

`c10810b = 410810b | 8108108`.  Thus the unexpected bit27 (`isHead`) is not
a tail-decode error and is not a single-bit latch corruption: the OPM's
one-hot data Mux is being driven by **two** live selections and is correctly
producing their bitwise OR under that illegal condition.  The later all-zero
flit follows the two-source MG/TP release sequence and is a consequence, not
the first fault.

### Timing evidence and conclusion

- The traced V2 latch D is already `c10810b` before its E-close/Q capture;
there is no observation of a correct `410810b` D becoming wrong after close.
- `run.log` and `stdout.log` contain no runtime `$setup`, `$hold`, or timing
violation before this event.  Therefore this packet19 error is not explained
by the prior OPM V2 D/E hold issue.
- The required invariant is `MG[3:0]` one-hot-or-zero per OPM.  Here it is
violated by source2 and source3, both requesting the same physical Child2
output.  That ownership exclusion belongs upstream to
`AtomicMulticastArbiterV2` / admission-to-ReqGen reservation integrity;
OPM should not arbitrate a second time.

### Full-run status and next repair target

- The checker continued after the first mismatch and recorded further RX
events until the original case timeout: 581 injected, 547 delivered, two
unexpected, 2,455 missing.  Final wrapper `in_pending` values are cleared by
the timeout procedure, so they cannot be used to classify a live deadlock.
- The next functional investigation is to trace the two admission chains
  that produced source2 and source3 PPE/MG at this exact OPM, and prove where
  the V2 owner/mask exclusion admitted both packets.  Do not modify the OPM
  data latch or treat a longer receiver delay as a fix for this failure.

## 2026-08-10 -- TAB packet19 double-PPE root cause (Atomic V2 state coherence)

### Scope and frozen evidence

- This diagnostic reused the same raw NoC16 post-DC netlist and SDF as the
  preceding entry; no DUT RTL, case, wrapper protocol, or DC artifact was
  changed.  Netlist SHA-256:
  `17aafafe8ed038f1d380d4889e8521339c0706965582cad550256bfb4669b1b8`.
  SDF SHA-256:
  `c2c6a836339cd84235d0e43fd562e0fb70d3027f44c3273c6a6c0f6fb2285f93`.
- The trace was extended only through simulation hierarchy at
  `routerL1_1_0.outputModules_2`: global input 3 / local source 2 and global
  input 4 (Parent) / local source 3.  It records HeadCapture `P`, V2
  transaction Q/fire, active/mask/owner state, admittedRS, and both ReqGen
  branches.  The checker still runs to the original case timeout.
- Strict SDF annotation completed.  There is no runtime setup/hold message
  preceding this failure.

### Proven causal sequence

The failure is an Atomic V2 **P/A coherence error**, not an OPM or ReqGen
self-start error.  Here `P` is HeadCapture `packet_present` and `A` is the
committed `packetActive` state.

1. At **724.285 ns**, input 4 was legitimately admitted by a transaction
   with `txWinner=10000`, `txMask[4]=00001`; it became active for output 0.
2. At **724.316 ns**, a legitimate release transaction for input 4 occurred:
   `relC4=1`, `txRel=1`, `txWinner=10000`, and `fire=1`.  During this
   transaction `P[4]` is cleared and `A[4]` is also observed to clear.  This
   proves that the release mechanism itself can operate.
3. By **727.082 ns**, however, the state has become incoherent again:

   ```text
   P       = 00000
   A       = 10000
   mask[4] = 00000
   owner[2]= NONE
   ```

   A zombie `packetActive[4]` is high although its HeadCapture state and mask
   are clear.  The trace establishes this forbidden state but does not yet
   distinguish whether it was reasserted by an extra fire or retained by a
   later release/return race; both mechanisms are in the Atomic V2 commit
   lifecycle.
4. A later Parent Head presents raw `RS[4]=0100`.  Because V2 currently
   forms `admittedRS = rawRS & packetActive`, this Head receives
   `admittedRS[4][2]=1` directly from the stale `A[4]`: no new transaction,
   no `fire`, and no owner write occur.  HeadCapture then overwrites its
   local mask with output 2 and ReqGen branch 2 correctly raises PPE.
5. At **728.374 ns**, input 3 is independently and legitimately admitted to
   output 2 by a new transaction (`txWinner=01000`, `txMask[3]=00100`,
   `fire=1`), because output 2 still has owner NONE.
6. At **728.402 ns**, both input 3 and the stale-active input 4 have a valid
   `admittedRS` and their corresponding ReqGen PPEs are high.  They reach
   local sources 2/3 of OPM2, so `MG=1100` and the one-hot data Mux produces
   `410810b | 8108108 = c10810b`.

### Eliminated hypotheses

- **Not a same-fire Builder overlap:** the input-3 fire contains only
  `txWinner=01000`; input 4 was not a winner of that transaction.
- **Not ReqGen PPE self-activation:** each PPE rise has a prior matching
  admittedRS high.  ReqGen is following its permitted phase/PPE path.
- **Not a branch-to-local-source mapping defect:** input 3→source2 and
  Parent→source3 are the intended static mappings.
- **Not an OPM V2 data-latch or SDF D/E error:** V2 receives an already
  illegal two-hot MG selection; its OR result merely exposes the upstream
  admission violation.

### Required repair direction (not implemented in this diagnostic run)

The next functional change must make HeadCapture `P`, `packetActive A`,
packet mask, and owner release a transaction-consistent lifecycle.  In
particular, a release must not permit `P=0, A=1`, and a new Head must never
reuse an old active reservation.  As a protective condition, the current
`admittedRS = RS & A` needs a packet-presence/identity gate while the release
atomicity is corrected; that gate alone is insufficient because it would
leave the zombie `A` reservation unresolved.  The repair belongs in Atomic
V2 release/commit state, not OPM or ReqGen.

## 2026-08-10 -- Tail release barrier repair and NoC16 strict-SDF closure

### Implemented correction

- `AsyncArbiterTransactionController` now holds the frozen transaction kind,
  winner, and five masks closed for the entire `fire=1` interval.  Previously
  `tx_valid` was cleared by fire and reopened these latches in the same
  commit window; the Active/owner bank could consequently sample an empty or
  changing payload.  The new latch enable is `~tx_valid & ~fire`.
- Atomic V2 now exports per-input `tailReleaseReady = !P && !A`.  It is a
  stable idle level, not a release-fire pulse.  `admittedRS` is additionally
  gated by `P`, `A`, and the captured packet mask, so a raw RS cannot borrow
  a reservation without a live descriptor.
- The IPM/AckGenerator receives `tailReleaseReady` and V1's stable current
  `isTail` bit.  The original Ack-following DFF remains unchanged; only its
  event condition becomes:

  ```text
  Done == 0 && (!currentFlitIsTail || tailReleaseReady)
  ```

  Head and Body therefore retain the paper path.  Tail holds AckX/V1 closed
  until Atomic has completed complete-set release, preventing a next Head
  from entering the old reservation window.

### Verification evidence

- Local: Scala compile/generation, C2/C3, Mutex5, Atomic V2, ReqGenBank, IPM
  Tail-barrier smoke, and all seven existing Router boundary smokes PASS.
- Local canonical NoC16 wrapper, `TAB-NET-UR-3f-r0p02`: **PASS**;
  3,000 injected / 3,000 delivered, zero missing, unexpected, timeout, and
  RX overflow.
- Remote single-Router fresh DC and strict SDF: DC completed; all five
  boundary cases PASS (`unicast3`, `mc_single3`, `mc_disjoint_parallel3`,
  `uc_overlap_release3`, `mc_overlap_tailjoin3`).
- Remote NoC16 run `20260810_tail_release_barrier_noc16_tab`: new DC reports
  `GTECH=0` and `ULTRA_NOC16_DC_PASS`; strict SDF annotation completed and
  canonical TAB r0p02 reports **PASS** with 3,000/3,000 flits, zero missing,
  unexpected, timeout, or overflow.  No runtime `$setup/$hold` / timing
  violation is present in its SDF run log.

### Flow note

- The remote NoC16 SDF shell runner was corrected for `set -u`: an empty
  optional trace argument array is now expanded only when set.  This was a
  harness startup failure before VCS execution, not a hardware failure.
- The cluster occasionally returned a stale hash immediately after a large
  SFTP upload.  The frozen NoC RTL and the changed transaction-controller
  primitive were independently SHA-256 checked before the successful DC/SDF
  run.

### VCTM native-multicast SDF regression

- The same fresh NoC16 post-DC netlist/SDF was then reused without RTL or
  synthesis changes for `VCTM-MC5-NM-3f-r0p02` (LSF job `11120801`).
- Strict SDF annotation completed and the canonical AXI/BRAM scoreboard
  reported **PASS**: 3,000 injected flits, 3,405 delivered flits, 1,135
  delivered packets, and zero missing, unexpected, timeout, or RX overflow.
  The 3,405 deliveries confirm native multicast replication rather than a
  repeated-unicast expectation.

## 2026-08-10 -- TAB r0p10 packet89 strict-SDF stall diagnosis

### Frozen implementation and method

- The diagnostic reuses, without regenerating DC, the raw post-DC
  `NoC_16nodes_post.v` and matching SDF from
  `20260810_tail_release_barrier_noc16_tab`.
- The canonical AXI/BRAM checker remains non-fatal: it runs to the original
  timeout and writes all receive/missing records.  The historical r0p10 run
  has 305 injected / 270 delivered flits, 2,730 missing, zero unexpected,
  timeout=1, and no RX overflow.  No runtime `$setup`, `$hold`, or SDF
  annotation failure was reported.
- A narrow, read-only trace follows core6 packet89 through L1(1,0) Child2,
  its parent OPM/upward FIFO, then L2 input1.  No Router interface, wrapper
  handshake, case stimulus, DC netlist, or SDF was changed.

### First causal break

Packet89 itself is blocked upstream of the first Router where the relevant
release failed.  At L2 input1, an earlier unicast packet with mask `00100`
has already completed its Tail:

```text
726.892 ns  L2 input1: active=1, mask=00100, allTailPassed=1,
             Done[3:0]=0000, currentFlitIsTail=1
             => release predicate (active & allTailPassed)=1
```

Nevertheless the Atomic V2 transaction controller remains at
`txValid=0, txRelease=0, fire=0`, and `tailReleaseReady=0`; this state is
still unchanged at 726.916 ns while the next upward-FIFO entry waits.
Therefore AckGenerator correctly keeps `AckX` at its old phase for this
Tail, V1 remains closed, and the FIFO cannot dequeue.  The later core6
packet89 Head/Body/Tail consequently cannot enter L2; the source L1 sees its
parent OPM/FIFO backpressured.  This is a control-lifecycle stall, not an OPM
data error and not a runtime setup/hold failure.

### Scope narrowed

- Eliminated: core6 V1/PRS, source L1 ReqGen, source OPM, FIFO data capture,
  L2 ReqGen branch2, L2 output3/downward FIFO, and TailJoin detection.  The
  trace proves the L2 Tail is present and `allTailPassed` rises.
- Fault boundary: `AsyncArbiterTransactionController` release entry, between
  `release_req = packet_present & packet_active & all_tail_passed` and the
  frozen release transaction (`txValid/txRelease/fire`).

### Final mutex-boundary evidence (2026-08-11)

The additional frozen-netlist trace disproves the tentative `roundBusy`
hypothesis above.  At the stalled L2 input1 Tail, including at 726.892 ns and
again much later while the condition persists, the relevant state is:

```text
P=1, A=1, mask=00100, allTailPassed=1
roundBusy=0, commitSeen=0, txValid=0, fire=0
anchorReq=01110 (later 01111), anchorGrant=00000
Mutex3 root grant (P,B,A) = 010     // B group has root_grant=1
TAC-B: req_up=1, root=1, grant={0,0}, arbo={00 <-> 11}
```

Thus the HeadCapture lifecycle is coherent (`P=1,A=1`), RETURN is idle, and
the valid release request already reaches `Mutex5Anchor.req`.  The root
`Mutex3Grant` selects the B child group, but TAC-B's local structural
`Mutex2` is presented with both child requests and does not resolve to a
stable one-hot `arbo`.  In strict digital SDF it alternates between `00` and
`11`; consequently neither TAC-B `grant` output reaches 1, `anchorGrant`
stays zero, and the controller cannot freeze a release transaction.

This is neither a TailJoin failure nor a Controller RETURN/transaction-latch
failure.  The full trace was stopped after this was established because the
unresolved feedback loop emitted an unbounded diagnostic stream; no DUT,
case, SDF, or handshake change was made.

### Unique next repair direction (not implemented here)

Repair the **TAC-B local Mutex2 physical arbitration primitive/model** so two
simultaneous requests resolve to exactly one stable `arbo` winner under the
same post-DC/SDF flow.  Preserve the 2+2+1 Mutex5 topology and do not replace
the release protocol with a Controller reset.  The repair must be a real
asymmetric/characterized mutual-exclusion implementation (or the foundry
mutex macro, if available), with structural protection through DC; a fixed
behavioral delay is acceptable only for functional diagnosis, never as the
strict-SDF signoff implementation.  After the local Mutex2 resolves, TAC2's
existing C-element grant join will receive its already-proven root grant and
the pending release can enter the unchanged transaction/ACG path.

### Correction: isolated TAC2 strict-SDF contention result (2026-08-11)

The statement above must not be interpreted as proof that `Mutex2_ASIC` is
intrinsically unable to arbitrate.  A new independently synthesized TAC2 run,
`20260811_tac2_contention_inv`, used the same T28 SS library, the current
`Mutex2_ASIC.v` (ordinary INV output stage), a newly generated TAC2 post-DC
netlist, and strict SDF annotation.  It passed both equal-arrival tests:

```text
local requests first, root grant later:       arbo=01, grant=01 at 46 ns
root grant first, local requests simultaneous: arbo=01, grant=01 at 74 ns
```

There were zero SDF annotation errors/warnings.  The older `TAC2/Mutex3`
smoke indeed did not cover this exact simultaneous local-contention case, but
the new dedicated test does and it passes.  Therefore a four-input-NOR output
filter is a valid *physical robustness experiment* from the extended
isochronic-fork paper, not yet a proven fix for the TAB r0p10 stall.

The remaining evidence points to the **dynamic full-Mutex5 context**: while
TAC-B has `root_grant=1`, other `arb_req` bits change (`01110` to `01111`) and
the complete root/TAC masking-return network is live.  The next diagnostic
must reproduce that exact request-vector and return sequence in a standalone
post-SDF `Mutex5Anchor`, while recording TAC-B's raw NAND outputs, `arbo`,
root grant, and the two final C-element grants.  Only if that test shows a
stable raw mutex choice but an invalid/absent final grant does the repair move
to TAC masking/C-element return; only if the raw mutex itself fails under this
exact dynamic sequence should the physical mutex/filter be changed.

### Correction: standalone Mutex5 dynamic strict-SDF result (2026-08-11)

That next experiment was run as `20260811_mutex5_dynamic_01110_01111`, with
a newly synthesized `Mutex5Anchor` post-netlist/SDF and the unchanged current
ASIC primitives.  It reproduces the observed request-vector prefix exactly:

```text
01110 --105 ps--> 01111
```

It passes under strict SDF with no annotation warning.  The settled state is
`root(P,B,A)=010`, TAC-B `rawq=10`, `arbo=01`, final TAC-B grant `01`, and
top-level `grant=00100`; it remains stable for a further 20 ns and returns
cleanly to zero.  Therefore the field failure is **not reproduced by the
Mutex5 combinational arbitration network plus this request-vector sequence**.

The earlier NoC trace's rapidly alternating `arbo` samples cannot yet be
treated as a root cause.  They may be a consequence of a wider controller
state/re-entry condition, a different request pulse history, or an
observation point being repeatedly triggered by another changing signal.
The physical NOR4 metastability filter remains a literature-backed candidate
for robustness characterization, but there is currently no basis to make it
the functional fix.  The next trace must capture `arb_req[2:3]`, raw Mutex2
nodes, and their **edge history before and after** `allTailPassed`, together
with the controller's `round_reset/reset` and the exact transaction-return
signals, rather than sampling only a later stalled steady state.

### Causal-order correction: Mutex5 instability predates the failed release

Reading the beginning of the frozen NoC trace establishes the missing order.
At **726.892 ns**, before the affected packet's Tail completion:

```text
allTailPassed=0, releaseExpected=0
arb_req=01100, roundBusy=0
root(P,B,A)=010, TAC-B root_grant=1
TAC-B arbo repeatedly samples as 11 then 00; final grant remains 00
```

Thus the B-group local mutex is already failing to produce an anchor while it
is arbitrating ordinary pending **admissions**.  Only later does
`allTailPassed` rise for L2 input1.  Its `release_req` is then valid, but it
joins a Mutex5 whose B local decision is already unresolved, so
`anchorGrant=0`, `txValid=0`, and no release transaction can be armed.

This refines the exact failure statement: release generation is not the
first defect.  The immediate missing signal is `anchorGrant`, and its first
failure predates release.  The standalone TAC2/Mutex5 tests prove that clean
reset-to-static request vectors settle; they do **not** prove that the raw
cross-coupled NAND mutex is safe for every dynamic request/return history.
Strict digital SDF cannot model analogue metastability directly.  The next
reproduction must begin from the pre-726.892 ns request/grant/return history,
not from reset, to determine whether that history exposes an unmodelled
mutex-resolution assumption or a controller-generated illegal re-entry.

## 2026-08-11 -- Mutex2 NOR4 output-filter experiment

The ASIC `Mutex2` output stage was changed from two `INVD1` cells to two
preserved `NR4D1BWP12T30P140` cells with tied inputs (`q,q,q,q`).  This is a
physical output-filter experiment based on *Stretching Quasi Delay
Insensitivity by Means of Extended Isochronic Forks*; it retains the crossed
ND2 mutex latch and does not alter Atomic, Controller, TAC, ReqGen or OPM
protocol equations.  DC now treats `gnt*_filter` as structural asynchronous
cells and fails NoC16 compilation if the mapped ND2/NOR4 counts do not match.

### Results

- `20260811_tac2_contention_nr4`: fresh DC and strict SDF PASS.  Both
  simultaneous-local-request scenarios resolve to a one-hot TAC2 grant; SDF
  annotation reports zero errors/warnings.
- `20260811_mutex5_dynamic_nr4`: fresh DC and strict SDF PASS for
  `01110 -> 105 ps -> 01111`; Mutex5 settles to `grant=00100`, holds that
  grant for 20 ns, and returns to zero cleanly.
- `20260811_mutex_nr4_noc16_tabp10`: fresh NoC16 DC PASS with `GTECH=0`.
  The post-DC structural check reports exactly `90 ND2D1` mutex latch cells
  and `90 NR4D1` named output-filter cells, proving that the filter was not
  folded into an INV.  Canonical strict SDF TAB p10 PASS: 3,000 injected /
  3,000 delivered flits, 1,000 packets, zero missing, unexpected, timeout,
  or RX overflow.  SDF annotation completed without `IFNSDFA`.

This establishes the NR4D1 filter as the current ASIC Mutex2 output stage.
It does not independently prove analogue metastability resolution, but it
removes the previously observed p10 control stall under the required physical
NoC16 SDF regression.

### TAB r0p20 extension

The same frozen NOR4 NoC16 post-DC netlist/SDF was reused for canonical
strict-SDF `TAB-NET-UR-3f-r0p20`.  It passed with 3,000 injected / 3,000
delivered flits and zero missing, unexpected, timeout, or RX overflow
(`avg=63.496 ns`, `p95=140.100 ns`, `p99=180.100 ns`).

### TAB r0p30 extension

Canonical strict-SDF `TAB-NET-UR-3f-r0p30` reused that exact frozen NOR4
post-DC netlist and SDF.  It did **not** pass: the wrapper timeout occurred
after 980 injected and 946 delivered flits (315 delivered packets), with
2,054 missing flits, zero unexpected flits and zero RX overflow.  The
completed deliveries had `avg=74800.194 ns`, `p95=734730.400 ns`, and
`p99=737711.700 ns`, which identifies a high-load control stall rather than
a simple data mismatch.

SDF annotation completed.  The collected log contains `SDFCOM_IWSBA`
interconnect-annotation warnings, but no `IFNSDFA` or runtime `$setup`/`$hold`
message associated with this run's first observed timeout.  No RTL or TB
functional behavior was changed for this extension; the root cause remains
unclassified and requires a dedicated high-load transaction/controller trace.

### TAB r0p30 packet-246 narrow-path result (diagnosis only)

Run `20260811_mutex_nr4_noc16_tabp30_trace246_r4` reused the **same frozen**
post-DC netlist and SDF from `20260811_mutex_nr4_noc16_tabp10`; it only
recompiled the canonical wrapper TB with read-only hierarchical trace probes.
It reproduced the original result exactly: SDF annotation completed, the
checker continued to the original timeout, and there was no `IFNSDFA` or
runtime `$setup`/`$hold` diagnostic.

The first missing expected packet is packet 246, Core9 -> Core0:

```text
L1(0,1) input1 / parent OPM4 source1
  -> upward FIFO2 -> L2 input2 / OPM3 source2
  -> downward FIFO3 -> L1(0,0) parent input4 / OPM3 source3 -> Core0
```

The Head `8000002` reaches Core0 and its external output handshake completes
(`ReqOut=1`, `AckOut=1`).  During the following Body/Tail window around
`727.351 ns`, the destination branch is nevertheless:

```text
destination OPM source3: local Ack=0, Grant=1, MG=1, TP=0
destination ReqGen branch3: Req=1, Done=1, PPE=1
destination IPM: ReqX=1, AckX=0, V1 latch_en=0
destination output: ReqOut=1, AckOut=1, DataOut=8000002
```

Thus the first causal break is **inside the destination OPM V2 close-event /
Ack-DFF feedback path**: after its Head is accepted externally, the OPM does
not return the corresponding local `Ack` to the destination ReqGenerator.
`Done` consequently never falls, `AckGenerator` cannot toggle `AckX`, the V1
input latch remains closed, and the Body/Tail cannot dequeue from the incoming
downward FIFO.  This is not an Atomic V2 release or TailJoin failure for
packet 246; the source L1 and L2 forward the Tail and their own release paths
continue while the destination input is blocked.

The trace proves the failing interface state, but does not yet distinguish
whether the physical cause is the V2 close-event clock failing to reach the
Ack DFF, or the Ack DFF sampling an incorrect `selectedReq` at that event.
Neither condition has an emitted library timing-check violation in this run.
The next repair-oriented experiment must therefore probe the post-netlist
Ack-DFF CP/D/Q and V2 latch E/Q at this exact destination OPM; no functional
RTL change was made in this diagnosis run.

### TAB r0p30 packet-246 pin-level conclusion

The follow-up frozen-netlist run
`20260811_mutex_nr4_noc16_tabp30_trace246_r5_pins` read the retained cell
ports of `routerL1_0_0.outputModules_3`: `requestLatches_3`,
`requestOutLatch`, `closeEvent`, and `ackState_3_reg`.  It establishes the
minimal fault point without modifying functional RTL.

At **727.330 ns**, while packet 246's Head is committed at Core0:

```text
L1 request latch: D=1, E=1, Q=1
L5 request latch: D=1, E=1, Q changes 0 -> 1
Ack DFF:           D=1, CP=0, Q=0
```

The wrapper observes the new `ReqOut=1` and returns `AckOut=1` in the same
simulation timestamp.  Therefore `RegEnable = XNOR(ReqOut,AckOut)` has no
physical low interval that propagates through the `V2CloseEvent` inverter:
the retained `close_clock`/Ack-DFF `CP` stays at zero.  The Ack DFF's data is
already correct (`D=1`), but there is no rising clock edge to capture it.

This is the exact minimal defect: **the V2 close-event is derived from an
unacknowledged-output mismatch pulse that may be shorter than the physical
E-to-close-inverter propagation delay.**  A clock-edge-based Ack/TP action
can consequently be suppressed when the boundary receiver returns Ack in the
same wrapper clock tick.  It is not a ReqGen D/PPE fault, not an Ack-DFF D
setup failure, and not an Atomic/TailJoin release failure.  The absence of a
library setup/hold warning is expected: no CP edge reaches the DFF.

The minimal repair scope, for a later implementation task, is OPM's
`RegEnable -> close-event -> Ack/TP DFF` event-generation path (or an
explicitly specified minimum boundary Ack response interval).  It must make
one V2-close event observable per L5 request-phase transition, even when
`AckOut` follows at the nearest wrapper clock edge.  No repair was made in
this diagnostic task.

### 2026-08-11: canonical clockless NoC16 boundary platform

Added `tb_noc16_async_boundary.sv` and `AsyncEndpointBank20` as the new
canonical asynchronous traffic platform.  The existing AXI/BRAM wrapper is
retained for interface regression but is no longer the primary performance or
strict-SDF testbench: its clocked receiver can collapse `ReqOut` and `AckOut`
into one simulation timestamp, exactly the condition that hid the V2 close
event in the packet-246 diagnosis above.

The new TB has independent event-driven sender/receiver processes on all 20
ports.  `input_cycle` remains a 20-ns offered-load timestamp for TAB/VCTM
comparability, but it does not create a handshake clock.  Data is written,
held for 0.2 ns, then the two-phase request toggles; output Ack follows a
captured flit after 0.2 ns.  The structural tier places Mousetrap source and
sink stages at every boundary, so a strict SDF run can annotate a physical
capture-before-Ack path independently of the NoC netlist.

Local xsim verification using the current Ultra RTL passed in both behavioral
and structural-endpoint modes:

```text
TAB-NET-UR-3f-r0p02:      3000 injected / 3000 delivered, PASS
VCTM-MC5-NM-3f-r0p02:     3000 injected / 3405 delivered, PASS
```

The first small 3-flit unicast measured 41.8 ns from Head ingress Ack to Tail
egress Req.  Event and latency CSV artifacts are emitted per run.  The next
step is separate DC/SDF annotation of `AsyncEndpointBank20` together with the
NoC16 post-netlist; no conclusion about strict SDF timing follows from this
RTL-only endpoint run.

### 2026-08-11: structural EndpointBank strict-SDF integration is invalid

The first two-SDF run, `20260811_async_boundary_tab`, is **not a valid NoC
strict-SDF result**. It compiled independently synthesized
`NoC_16nodes_post.v` and `AsyncEndpointBank20_post.v` in one VCS invocation.
Both netlists define globally named parameter-specialized modules, including
`MousetrapStage_WIDTH28_0` and `DLatchBank_WIDTH28_*`. VCS reported repeated
`Warning-[OPD] Override previous declaration` diagnostics, then used the
EndpointBank definition because it appears later in the file list.

The conflict is functional, not cosmetic. The NoC version of
`MousetrapStage_WIDTH28_0` implements

```text
latch_en = ~(ReqX xor AckX) & ~PRSReady
```

and contains the dynamic `PRSReady` input. Endpoint synthesis has
`PRSReady=0` for every boundary stage and constant-propagates that term; its
identically named module contains only the ReqX/AckX mux form. Therefore the
later Endpoint netlist overwrites the NoC IPM V1 cell definition and silently
removes the NoC's PRSReady close gate. This explains the otherwise implausible
strict-SDF symptom: even the isolated Core0 -> Core15 packet delivers its
Head but not its Body/Tail (`3 injected / 1 delivered`).

The boundary handshake itself progressed: source-side events recorded each
flit's `noc_in_req` and subsequent `noc_in_ack`; the first break is not an
endpoint source request that never reaches NoC. The NoC model being simulated
is structurally corrupted at compile time.

Required platform repair before any new SDF conclusion:

1. Use a single DC top containing both NoC16 and `AsyncEndpointBank20`,
   producing one namespaced netlist and one SDF; or
2. Namespace/uniquify every EndpointBank generated module before compilation
   (for example an `EP_` prefix for all `MousetrapStage_WIDTH*` and
   `DLatchBank_WIDTH*` definitions), then annotate two partitions.

The first option is preferred: it eliminates duplicate Verilog definitions
and includes boundary interconnect in the physical timing model. Until then,
TAB p02/p10/p20/p30 results from this platform are diagnostic failures only,
not Router throughput or correctness results.

### 2026-08-12: unified boundary netlist removes the platform collision

`20260812_boundary_single_top_smoke_r2` synthesizes
`AsyncNoC16BoundaryDUT` as one DC top containing the 20 source endpoint
stages, `NoC_16nodes`, and the 20 sink endpoint stages. The resulting single
post-netlist/SDF passed DC with `GTECH=0`, `SEQGEN=0`, 495 retained
`PRSReady` references, two `AsyncEndpointBank20` references, and 3245
resettable-latch references. Strict GLS compiled only this netlist and the
boundary TB; the compile log contains no `Override previous declaration`.

Thus the duplicate-module collision is fixed. However, the isolated
Core0 -> Core15 H/B/T strict-SDF case still delivered only the Head:

```text
injected=3, delivered=1, missing=2, timeout=1
```

The new single-top result proves the remaining Head-to-Body transition is not
caused by separately synthesized EndpointBank module names overwriting NoC
modules. Per the regression gate, TAB p02/p10/p20/p30 were not run from this
netlist. The next diagnosis must trace the physical single-top path after the
Head's output acknowledgement: source/IPM AckX and V1 latch-enable, the
relevant OPM Ack/Done closure, and the endpoint sink's NoC-side acknowledgement.

### 2026-08-12: old AXI/BRAM boundary isolates the remaining failure to the new endpoint timing

The same isolated `noc16_00_to_33_3flit_sdf` case was rerun against the
standalone NoC post-netlist/SDF using the historical
`async_noc16_axi_bram_wrapper` and `tb_noc16_async_axi_bram` platform:

```text
TB_RESULT PASS
injected_flits=3, delivered_flits=3, missing=0, unexpected=0, timeout=0
```

This is a direct A/B result: the old boundary transfers H/B/T under strict
SDF, whereas the new unified structural endpoint top transfers only Head.
The remaining cause is therefore in the new endpoint boundary timing rather
than the NoC Head/Body routing or the former duplicate-netlist collision.

The leading mechanism is the structural sink's immediate acknowledgement:
`noc_out_ack = sink.ReqX`.  Unlike the old wrapper, which returns output Ack
on a later wrapper cycle, the sink can return Ack immediately after its local
capture.  That can make the OPM `ReqOut != AckOut` mismatch interval too
narrow for the V2 close-event inverter and Ack DFF, reproducing the known
close-event suppression condition.  This is a hypothesis pending a pin-level
trace of `ReqOut/AckOut`, V2 latch E and `V2CloseEvent`; no Router change was
made here.

### 2026-08-12: endpoint 50 ps setup and physical Ack margin experiment

The unified endpoint platform now applies a 50 ps source bundled-data setup
before each request phase transition. Each structural sink returns NoC Ack
through a synthesized, protected `DEL050` instance rather than directly from
`sink.ReqX`. The common DC run `20260812_boundary_ack50_smoke` passed with 20
retained `sink_ack_delay` instances, so this is a physical SDF experiment,
not a TB-only `#delay` workaround.

Local structural RTL H/B/T passed. Strict SDF still produced:

```text
injected=3, delivered=1, missing=2, timeout=1
```

The 50 ps margin is present but does not by itself restore the Head-to-Body
transition. TAB loads were not run. The next diagnostic must measure the
actual SDF times at the destination OPM: `ReqOut`, sink capture/`sink.ReqX`,
delayed `AckOut`, V2 latch E, `V2CloseEvent`, Ack-DFF CP/Q, source `Done`,
and source IPM `AckX/latch_en`.

### 2026-08-12: Core0→Core15 unified-boundary SDF trace — first failure is the destination OPM close event

Frozen run: `20260812_boundary_ack50_smoke`; no DC, DUT, endpoint, delay, or
handshake behavior was changed. A read-only narrow trace followed:

```text
source0 → L1(0,0).in3/outParent → upward FIFO3 → L2.in3/outChild0
        → downward FIFO0 → L1(1,1).inParent/outChild0 → sink15
```

The Head reaches every router/FIFO stage and sink15 correctly. At the final
OPM (`routerL1_1_1.outputModules_0`, local source3), the relevant strict-SDF
events are:

| Time | Event |
|---:|---|
| 425.837 ns | V2 L5 `E` falls and `ReqOut` becomes 1 with `AckOut=0`; V2 data is already `0x830c30c`. |
| 425.891 ns | sink15 sees NoC `ReqOut=1`. |
| 425.946 ns | sink Mousetrap emits `ReqX=1` to the TB receiver. |
| 425.996 ns | TB receiver returns its 50 ps capture Ack. |
| 425.998 ns | sink `DEL050` output reaches NoC `AckOut=1`. |

Thus the OPM mismatch/closed interval is only about **161 ps**. Crucially,
the trace and narrow VCD show no `V2CloseEvent.close_clock` rising edge during
that interval. Accordingly `ackState_3_reg.CP` remains 0 and its Q remains
0; branch3 `Ack` remains 0, `Done=Req xor Ack` remains 1, destination IPM
`AckX` remains 0 while `ReqX=1`, and its V1 latch stays closed. The Body
offered at 1410.050 ns is consequently captured by the source endpoint but
cannot enter the frozen destination-side pipeline.

This rules out source setup, source endpoint→NoC transfer, the three Router
forward paths, both FIFOs, sink capture, and ordinary D/E setup/hold warnings
as the *first* failure. The strict-SDF run produced no relevant runtime
setup/hold/recovery/removal warning; the fault is a missing close-event pulse,
not a reported latch violation.

The old AXI/BRAM wrapper passes the same case because its `out_ack` is a
clocked register updated only on a later 20 ns wrapper edge. It therefore
keeps `ReqOut != AckOut` high for orders of magnitude longer than 161 ps, so
the physical V2 close inverter can propagate a CP pulse to the Ack DFF.

**Final diagnosis for this platform:** the structural sink's capture path plus
TB 50 ps receiver delay plus the mapped `DEL050` do not provide a sufficient
minimum OPM `ReqOut != AckOut` pulse width for `V2CloseEvent` under this SDF.
The next repair (out of this diagnostic round) belongs to the structural
endpoint/receiver Ack contract: derive a signoff minimum Ack delay from the
V2 close-event inverter plus Ack-DFF CP pulse-width requirement, then retain
that delay as a protected physical endpoint element. It is not a Router,
Arbiter, ReqGen, FIFO, or source-bundled-data functional fix.

Artifacts:

```text
/home/ghy19/Asynchronous_Router_ultra/logs/gls/20260812_boundary_ack50_smoke/
  async_sdf/noc16_00_to_33_3flit_sdf/core0_to_core15.trace
  async_sdf/noc16_00_to_33_3flit_sdf/core0_to_core15.vcd
```

### 2026-08-12: structural endpoint Ack window repaired — DEL075 selected

The endpoint Ack delay is now a protected, direct ASIC delay-cell choice.
`DEL050`, `DEL075`, `DEL100`, `DEL150`, and `DEL250` are selectable at the
single NoC16-plus-endpoint DC entry; the selected cell remains at all 20
`sink_ack_delay` instances. This is a receiver-boundary timing constraint,
not a Router, OPM, ReqGen, or Arbiter modification.

The first DEL075 DC attempt exposed a flow defect: two separate DC `-define`
switches left `ASIC_T28` inactive, turning all 25 `V2CloseEvent` instances
into `GTECH_NOT`. The entry now supplies `ASIC_T28` and the delay-selection
macro as one define list. Corrected run `20260812_ack075_r5_core015` has
`GTECH=0`, retains 20 sink delay instances, and maps the selected endpoint
delay to `DEL075`.

Strict SDF Core0→Core15 H/B/T passed twice from this single physical top:
`3 injected / 3 delivered / 0 missing / 0 unexpected / 0 timeout`. The
destination Ack DFF receives a close event for every flit and Body reopens
the input path.

The same post-DC netlist/SDF then passed all TAB 3-flit loads:

| Case | Result |
|---|---|
| TAB-NET-UR-3f-r0p02 | PASS, 3000/3000, no missing/unexpected/timeout |
| TAB-NET-UR-3f-r0p10 | PASS, 3000/3000, no missing/unexpected/timeout |
| TAB-NET-UR-3f-r0p20 | PASS, 3000/3000, no missing/unexpected/timeout |
| TAB-NET-UR-3f-r0p30 | PASS, 3000/3000, no missing/unexpected/timeout |

The initial TAB p02 launch stopped before simulation because an empty Bash
trace array expanded under `set -u`; the runner was corrected and the retry
used the unchanged post-DC netlist/SDF. This was not a DUT failure.

### 2026-08-13: OPM V2 DEL075 replaced by native mapped control path

The previous OPM timing hypothesis was corrected before any 310 ps hold-fix
was accepted.  The relevant bundled-data relation is local to the V2 data
latch, not the full Router latency:

```text
DataX -> MG mux -> dataOutLatch.D (last stable transition)
                                      before
request selection -> XOR4 -> L5 feedback -> dataOutLatch.E falling
```

On the zero-DEL r2 post-synthesis netlist/SDF
`20260813_opm_synth_localde_r2`, all 20 legal edges and all H/B/T phases
passed (`60` samples).  Worst Head data arrival was `3.873 ns`; the earliest
same-flit D-to-E-close margin was `264 ps`, above the `193.65 ps` 5% target.
Body/Tail margins were at least `527 ps`/`556 ps`.  No OPM buffer insertion is
therefore justified by this local RTC.

The profile `ULTRA_P250_PRS_ACG_OPM_SYNTH_MEM0_HC0` keeps five named
`v2RequestMargin` boundaries but maps no DEL075.  Router strict-SDF five-case
smoke passed, followed by one-top structural endpoint NoC16 strict SDF run
`20260813_opm_synth_localde_noc16_p50`:

- TAB r0p50: `3000/3000`, zero missing/unexpected/timeout.
- VCTM-MC5 r0p50: `3000/3366`, zero missing/unexpected/timeout.

This replaces the former DEL075 baseline for pre-layout work.  The endpoint
sink DEL075 remains an environment Ack-service requirement and is not part of
the Router forward-latency or OPM RTC calculation.  P&R/post-route signoff
must re-run the same local D/E check.

Artifacts: `/home/ghy19/Asynchronous_Router_ultra/outputs/20260812_ack075_r5_core015/boundary/`
and `/home/ghy19/Asynchronous_Router_ultra/logs/gls/20260812_ack075_r5_core015/`.
# 2026-08-16 — Atomic V2 R3f Return handshake closure

Run `20260816_r3f_router` closes the previously recurring strict-SDF failure
where the first packet completed but a pending second packet never produced
ReqOut.  R3d/R3e proved that `busy_d=~clearBusyReq` caused the occupancy
latch's D to rise only 4–6 ps before E fell, below the 14–15 ps library setup
requirement, allowing `round_busy` to recapture one.

R3f changes the occupancy equation to
`busy_d=set_round & ~clearBusyReq` and keeps `clearBusyReq` asserted while the
captured anchor and transaction state are cleared.  The final clear-request
return therefore closes E while D remains continuously zero.  A sticky
`return_ack` keeps Mutex5 gated until commit visibility, cleanup, and the
post-cleanup request-cone DEL250 have all completed.

Evidence:

- local Atomic V2, seven Router boundary cases, and 20-edge H/B/T PASS;
- remote DC `GTECH=0`;
- strict SDF annotation completed, X-free, no busy-latch setup/hold warning;
- all five Router cases PASS, including both overlap/release second rounds.

Artifacts are under
`scripts/asic_dc/ultra/results/20260816_r3f_router/`.  This establishes a
single-Router SYNTH-CLOSED result only; NoC16 and post-route validation remain
separate work.

The follow-up unified asynchronous NoC16 run
`20260816_r3f_asyncnoc16_p50` regenerated and re-synthesized the complete
`AsyncNoC16BoundaryDUT` with the same R3f controller SHA.  Strict SDF passed:

- TAB p50: 3000 injected / 3000 delivered, zero missing, unexpected, timeout;
- VCTM-MC5 p50: 3000 injected / 3366 delivered, zero missing, unexpected,
  timeout;
- both SDF annotations completed with no `IFNSDFA`.

This removes the earlier second-round Return failure at both Router-directed
and NoC16 p50 scope.  Post-route validation remains open.
