# CMR Router 调试日志

最后更新：2026-08-25

本文记录 CMR Router/Fat-tree 的 RTL、DC、严格 SDF GLS 与门级定位证据。
它沿用 [`UltraRouter_Debug_Log.md`](UltraRouter_Debug_Log.md) 的工作流：每轮固定基线、
先记录首个因果断点，再区分已证实结论、已排除模块和待验证修复；诊断探针不得驱动 DUT。

架构定义仍以
[`CMRArchitecture.md`](../src/main/scala/Router_Architecture/CMR/CMRArchitecture.md)
为准。本文件不是架构规范，也不把数字 SDF 结果解释为模拟亚稳态签核。

## 当前状态（2026-08-25）

Thin 16-core 层间链路是 depth-3 `AsyncFifo`（bypass 关、CircularFIFO 关）。
`AsyncStage` 出队 `Out.Req` 1×DEL150 已关闭 255 ns Req-before-Data X（§21–§22）。
冻结网表 `20260825_cmr_thin_acg_fifo3_outreqdel150_dc_01`。

VCTM-MC5-NM-3f-r0p50 严格 SDF（direct boundary，`GUARD=0.20`，`RX_CAPTURE=5`）
现停在 **53.21 µs Tail 流控，586/3366**，0 annotation error、0 timing
violation、无 X。L1 parent 与 L2 child 已不是同一对 pending 握手。
下一轮查 CMR Tail/`TailPassed`/mutex，不要再加 FIFO 出队 delay，也不要改
Fig. 7 XOR 或 Fig. 8 `PacketSeen`。

下文 §2 起是按时间排列的历史记录，**不是**当前首故障。

## 1. 每轮记录格式

每次调试必须记录以下内容：

1. 日期、目标和远程 run ID。
2. 冻结网表/SDF run ID、case 路径与 SHA-256。
3. 是否重新综合，以及所有诊断文件是否只读。
4. SDF annotation、X/Z、setup/hold/recovery/removal 状态。
5. 最后一个正确转换和第一个缺失转换。
6. 已排除模块、已证实责任边界和仍待验证假设。
7. 下一轮唯一实验；前一层失败时不继续运行更大的 traffic case。

禁止用大 VCD 代替定点事件记录。stall 快照至少包含当前相位、最后转换时间和
完整实例层次。

## 2. 当前故障：Fat-tree跨L1/L2 Tail停滞

### 2.1 冻结基线

- Fat-tree网表/SDF：`20260821_cmr_ft_pathclear_tab_p50_sdf_01`。
- 单packet case：远程Ultra只读目录中的 `noc16_00_to_33_3flit_sdf.case`。
- case SHA-256：
  `276e0e22ec63f0ccf28550e2c30428890255fd2c7b2d3ceabe83f414d46ade00`。
- 最终定位run：`20260821_cmr_tail_mutex2_probe_01`，LSF job `11363701`。
- 模式：未经功能patch的post-DC网表、MAXIMUM SDF、异步fail-fast边界TB。
- 本轮没有重新综合，也没有修改功能RTL。

### 2.2 RX Ack延迟扫描

run `20260821_cmr_tail_rx_capture_sweep_01`对同一3-flit单播扫描
`RX_CAPTURE_NS={0.05,1,2,5,10}`：

| 结构 | 0.05 ns | 1 ns | 2 ns | 5 ns | 10 ns | 结论 |
|---|---|---|---|---|---|---|
| Thin NoC16 | FAIL，1/3 | PASS | PASS | PASS | PASS | 最低已验证安全边界Ack为1 ns |
| Fat-tree NoC16 | FAIL，0/3 | FAIL | FAIL | FAIL | FAIL | 不是外部Ack过快 |

同一L1内的 `core0 -> core1` 3-flit case在1 ns和5 ns均通过。故障只在需要进入
L2的路径出现。

### 2.3 分层首断点

跨子树路径的稳定快照为：

```text
L1 parent Req       = 01
upward FIFO enq Ack = 01
upward FIFO deq Req = 01
L2 child3 Ack       = 00
L2 downward Req     = 00
destination Req     = 0
```

上行FIFO已经把请求送到L2，目标侧下行链尚未启动。因此第一个故障区域是
`routerL2.InputPortModules_6`，而不是层间FIFO或目标L1。

### 2.4 L2 IPM内部证据

stall时IPM6状态如下：

```text
PathEnabled                 = 0001
branch0 Read ReqX/Reqout    = 1/1
other branches AckX         = 111
branch0 CellEmpty           = 01010  // 尚未追平
branches1..3 CellEmpty      = 01101  // 已完成内部取消
WritePointer/CellFull       = 00100/01101
LaneSelect/Commit/lane Req  = 00/00/00
```

RCU已正确建立child0方向，CMR Buffer已写入Head/Body/Tail，错误路径也已内部完成。
正确branch0的方向级请求已经产生，但没有变成物理lane请求。Tail因此在
Write Interface barrier处等待branch0，而不是在RCU、ReadPhaseSelector或
WriteControlUnit中丢失。

### 2.5 精确故障实例

```text
routerL2
└── selector_24                       // IPM6 branch0 -> child0 lanes
    └── mutex                         // CMRMutexN_WIDTH2_21
        └── w2.root                   // Mutex2_273
```

该实例的门级快照：

```text
PathEnabled                  = 1
OtherGrant                   = 00
mutex_req                    = 11
LaneSelect                   = 00
child0 lane0/lane1 OPM Grant = all zero
child0 lane0/lane1 PPE       = all zero

last mutex_req change        =   414.055 ns
last raw q0/q1 change        = 23409.981 ns
last LaneSelect change       = 23409.963 ns
```

`mutex_req=11`稳定约23 us以后，交叉NAND内部节点与Grant仍在持续变化。
因此当前首个缺失转换是：

```text
ContinuousLaneSelector.mutex_req=11
  -X-> CMRMutexN_WIDTH2 one-hot LaneSelect
```

这是严格数字SDF中的对称反馈振荡。它同时解释功能停滞和仿真速度异常慢：
反馈环持续制造门级事件，但没有形成稳定赢家。

### 2.6 已排除范围

- `HeadPredictor`、Address Register、Route Computation与OPMSelector PathLatch。
- CMR Buffer Write Control、三个错误路径Read Control及正确路径Req生成。
- 上行AsyncFifo的数据/请求传递。
- LanePhaseAdapter之后的第二层OPM仲裁；Adapter尚未获得Commit，OPM尚未收到PPE。
- 外部receiver Ack间隔。
- runtime X/Z及标准单元setup/hold违例。

## CMR-WP-03 — VCTM `c107` Head/Body/Tail first-cause trace (2026-08-25)

### Frozen baseline and run conditions

- Frozen netlist: `20260825_cmr_thin_acg_fifo3_outreqdel150_dc_01`.
- Case: `VCTM-MC5-NM-3f-r0p50`, direct boundary, strict SDF,
  `ACK_TO_NEXT_REQ_GUARD_NS=0.20`, `RX_CAPTURE_NS=5`.
- Read-only GLS probe only: `tb_cmr_vctm_tail_release_trace.sv`; no RTL, CMR,
  OPM, FIFO, delay, or SDF change.
- Reproduced with both a 200 ns watchdog and the default 50 us watchdog.
  Default run `20260825_cmr_thin_acg_fifo3_wp03_default_01`: annotation errors
  = 0, timing violations = 0, then the same `TB_STALL_FAIL` at 53.210 us,
  `rx=586/3366`.

### Decisive observed sequence

The affected packet is `{Head,Body,Tail} = {810c107,010c107,410c107}`.
`OPM1 source0` is `routerL2.InputPortModules_0` branch 0.

```text
1856.546 ns  source0.Datain = 810c107 (Head)
             Reqin=1 Ackout=1, PPE=0, Grant=0, OPM Reqout=Ackin=1

1856.889 ns  source0.Reqin: 1 -> 0 while Head remains visible
             Ackout remains 1; PPE=0 and Grant=0

1857.851 ns  source0.Reqin: 0 -> 1 without an Ackout transition
1857.804 ns  PPE[source0] = 1
1857.914 ns  Grant[source0] = 1

1858.075 ns  source0.Datain changes Head -> 010c107 (Body)
1858.205 ns  Body source request becomes pending
1858.366 ns  OPM1 Reqout toggles and DownFIFO1 enqueues 010c107

1872.539 ns  OPM1 Reqout toggles and DownFIFO1 enqueues 410c107 (Tail)
1877.228 ns  L110 sees stranded Tail with PathEnabled=0000
```

For every `c107` OPM handoff, `OPM1.Dataout == DownFIFO1.enqueue data`; no
FIFO enqueue/dequeue replay or mismatch was observed.

### Classification

The Head is **not** accepted by OPM1 and then dropped by OPM1 or DownFIFO1.
The Head data becomes visible at the L2 IPM0 -> OPM1 source boundary before its
path is enabled; its request toggles and returns while `PPE=Grant=0`. Once the
path and grant appear, the source data has already advanced to Body, which is
the first valid OPM/FIFO transaction. Thus the currently proven failing
boundary is:

```text
L2 IPM0 branch0: Reqout/Dataout relative to PathEnabled[0] / OPM1 PPE[0]
```

This excludes for packet `c107`:

- L110 `PathEnabled` last-clear / speculative-read cancellation (CMR-WP-02);
- OPM1 dropping an accepted Head;
- DownFIFO1 losing or replaying the Head;
- SDF annotation, timing violation, or X-propagation as the observed cause.

Next diagnostic only: trace L2 IPM0 branch0's CMR read-interface
`ReqX/Reqout/Ackin/Dataout`, `PathEnabled_0`, and the Head cell's `CellEmpty`
through the `1856.5–1858.4 ns` window. The question is why branch0 launches
and retracts the Head request before the RCU path grant reaches OPM1; do not
modify OPM or FIFO before that causal edge is located.

## 3. Ultra历史上的 `00 <-> 11`

Ultra在2026-08-11的NoC16严格SDF中曾观察到：

```text
TAC-B local req = 11
root grant      = 1
raw arbo        = 00 <-> 11
final grant     = 00
```

当时采用的ASIC实验性修复是：

1. 保留交叉耦合的两个 `ND2D1BWP12T30P140`。
2. 将普通输出INV替换为四输入同接的 `NR4D1BWP12T30P140`：
   `NOR4(q,q,q,q)`。
3. 对Mutex层次、NAND和命名为`gnt*_filter`的NR4设置`dont_touch`。
4. DC后强制检查NAND与NR4数量相等，防止NR4被布尔折叠为INV。
5. 依次运行独立TAC2 simultaneous-contention、动态Mutex5和NoC16 TAB。

对应提交为 `aa9b992`。该实现让Ultra的TAC2/Mutex5独立SDF通过，并让TAB p10、
p20完整通过。相关原始记录见
[`UltraRouter_Debug_Log.md`](UltraRouter_Debug_Log.md)的
“Final mutex-boundary evidence”和“Mutex2 NOR4 output-filter experiment”。

## 4. 为什么Ultra修复不能直接视为CMR修复

当前CMR冻结网表已经使用同一个
[`Mutex2_ASIC.v`](../src/main/resources/ASYNC/Mutex2_ASIC.v)：

```text
cross-coupled ND2D1 + preserved tied-input NR4D1 filters
```

门级实例 `Mutex2_273`中也明确存在两个 `ND2D1` 和两个 `NR4D1`。因此CMR不是
遗漏了Ultra的NR4映射。NR4只限制亚稳态向Grant传播，不能在纯数字SDF中为一个
永久、完全对称的反馈环创造物理失配。

两种应用的关键区别是请求来源：

- Ultra的两个竞争请求来自不同输入/控制路径，存在真实组合路径和到达时间差；NR4实验消除了
  当时traffic下可见的输出不稳定。
- CMR Lane Selector用同一个`PathEnabled`同时生成所有空闲lane的候选。
  两个`OtherGrant=0`时，`mutex_req`天然从`00`同步变成`11`，在数字模型中保持完全对称。

所以“再次换成NR4”不是下一步，因为已经完成。也不能把输出端再插一个固定Delay当作严格SDF
修复；它只会延后观察，不会打破交叉NAND内部对称性。

## 5. 下一轮验证边界

修改功能前的独立 `CMRMutexN_WIDTH2 + ContinuousLaneSelector` 严格SDF复现已完成：

1. `PathEnabled`单沿同时产生`req=11`，保持不撤销。
2. 记录raw `q0/q1`、NR4输出和事件计数，并与Ultra TAC2 TB对照。
3. 注入可控的25/50/100/200 ps requester路径偏斜，仅用于确认数字对称性诊断，
   不作为最终RTL修复。
4. 结果显示同步和全部偏斜模式均稳定one-hot，详见下一节。

因此下一轮应恢复L2 Router的真实前序事件，而不是直接运行TAB/VCTM；更小的确定性
单packet仍然失败，尚不具备扩大traffic的条件。

## 6. 独立Lane Selector/Mutex2反证（2026-08-21）

为避免把冻结Fat-tree网表中的后来状态误判为Mutex根因，新增了完整的两lane
`ContinuousLaneSelector`候选方程复现：

```text
mutex_req[i] = PathEnabled & ~OtherGrant[i]
```

它使用当前共享的 `Mutex2_ASIC.v`、`CMRMutexN(WIDTH=2)`、现有
`async_primitives.tcl`（包括Mutex/NR4 `dont_touch`和一条loop timing-break）重新DC。
run `20260821_cmr_lane_mutex_sync_diag_04`满足：

```text
GTECH=0, SEQGEN=0
ND2 mutex cells=2, tied-input NR4 filters=2
SDF annotation errors/warnings=0
```

严格SDF结果如下：

| 场景 | 结果 | 同步/最后稳定时间 |
|---|---|---|
| 同一PathEnabled产生`00 -> 11` | `STABLE_ONEHOT` | `q=10, grant=01`，0.504/0.519 ns |
| 25 ps偏斜 | `STABLE_ONEHOT` | 10.839/10.854 ns |
| 50/100/200 ps偏斜 | `STABLE_ONEHOT` | 均无后续转换 |
| 第二请求晚1 ns | `STABLE_ONEHOT` | 52.814/52.829 ns |

同步场景只出现三次raw-q、四次Grant收敛转换，随后5 ns观察窗内没有新事件、没有X。
RTL功能模型与严格SDF均输出`TB_RESULT PASS`。

**结论修正：** 完全同步`req=11`不是当前T28/NR4实现下足以复现`00 <-> 11`的唯一条件，
也不能据此直接改造Lane Selector或重复NR4替换。Fat-tree中的振荡仍真实存在，但它依赖
该Mutex所处的动态上下文，例如`OtherGrant`反馈、第二层OPM Grant/Commit、Tail释放或其他
selector的请求/撤销历史。下一轮必须从`selector_24`在L2 Router的真实前序事件开始最小化，
而不是只从reset后的静态`00 -> 11`开始。

证据：
`scripts/asic_dc/cmr/results/20260821_cmr_lane_mutex_sync_diag_04/summary.json` 与
`logs_gls/lane_mutex/run.log`。

## 7. 本轮诊断工具

- `scripts/asic_dc/cmr/tb_cmr_fat_tree_phase_probe.sv`：stall触发的只读层次探针。
- `scripts/asic_dc/cmr/run_remote_cmr_rx_capture_sweep.py`：冻结网表Ack扫描与可选phase probe。
- `scripts/asic_dc/cmr/run_gls_cmr_noc16.sh`：可配置`RX_CAPTURE_NS`及probe编译。
- `scripts/asic_dc/cmr/results/20260821_cmr_tail_mutex2_probe_01/fat_rx5.run.log`：
  当前最终证据。
- `sim/CMR/testbench/CMRLaneSelectorMutex2Harness.v`：两lane候选方程复现。
- `sim/CMR/testbench/tb_cmr_lane_mutex_contention.sv`：同步、25/50/100/200 ps偏斜及
  第二请求延后诊断。

## 8. selector_24 dynamic-history result (2026-08-21)

Frozen NoC16 SDF `20260821_cmr_ft_pathclear_tab_p50_sdf_01` was rerun without
RTL or netlist changes, using `RX_CAPTURE_NS=5 ns` and a read-only 64-event
ring probe. The first definitive mutual-exclusion violation occurred at the
start of the packet, not during Tail release:

```text
414.032 ns  PathEnabled[0] = 1
414.055 ns  selector_24.mutex_req = 11
414.086 ns  raw q = 00
414.108 ns  LaneSelect = 11
414.117 ns  raw q = 11   <-- first illegal two-winner state
```

At those events `OtherGrant=00`; both child0 OPM requester-4 PPE, Grant, MG
and TailPassed remain zero. Thus the first bad boundary is the selector's
two-input physical mutex itself, before `LanePhaseAdapter.Commit` or either
second-level OPM can feed anything back. The terminal ring contains the same
`q: 11 -> 00` / `LaneSelect: 11 -> 10 -> 00` cycle and records 1,768,918
events by the fail-fast stall at 23.410 us. There are no X/Z or timing
violations.

The direct physical slice was also rerun with the actual prehistory
(`OtherGrant=00` while `PathEnabled=0`, then only `PathEnabled` rises). Its
separately synthesized strict-SDF run
`20260821_cmr_selector24_dynamic_slice_01` still settles one-hot. It does
not reproduce the frozen-fat-tree oscillation, so it must not be used as a
replacement proof for the failing instance. The next slice must retain the
frozen selector cell instance and its real post-DC fanout/loading context;
the current evidence rules out OPM, adapter and Grant-feedback as the first
cause.

## 9. Fat-tree TAB `8004004` misroute root cause (2026-08-22)

Frozen post-DC/SDF `20260821_cmr_ft_mutex_nd2d2_01` reproduces the same
unexpected flit with both the complete TAB case and a prefix containing only
the original input events through tick 14.  The prefix hash is
`dcdeb574da2097bf3d9ce352a2be9a04dacdb690effd545cdc512f82ec03bf13`.

The target head enters `L1_0_0.InputPortModules_5` from parent lane 1.  Its
correct final address field is `001001`, which selects branch1/child1/core1.
The read-only probe records the following causally relevant sequence:

```text
275.942 ns  Datain = 8004004; AddressRegister.dest still = 041041
275.975 ns  Req_rc becomes active; RCU first selects branch0
275.997 ns  dest = 001041
276.004 ns  dest = 001001 (correct final field)
276.238 ns  RCU selects branch1; PathEnabled is now 0011
284.389 ns  child0/core5 captures 8004004; checker expects core1
```

Therefore the first fault is neither a lane selector nor a physical
crossbar connection.  `AddressRegisterUnit` exposes `Req_rc` to Route
Computation before its buffered 24-bit address has settled.  The old/partial
address opens branch0, then the final address opens branch1 for the same
packet.  Because `OPMSelector` intentionally holds each selected path until
TailPassed, the stale child0 path remains active and replicates the packet.

Evidence: `scripts/asic_dc/cmr/results/20260822_cmr_ft_8004004_probe_05/`.
The next functional repair must restore the Fig. 6 bundled-data relation
between the address-latch data path and `Req_rc`; changing route direction
maps, OPM wiring, or FIFO lane connections would address a downstream
symptom only.

## 10. Thin NoC16 无 SDF 功能 TAB p50（2026-08-22）

本轮目标是冻结 post-DC Thin 网表上的无 SDF 功能 GLS，case 为完整
`TAB-NET-UR-3f-r0p50`。入口为
[`run_remote_cmr_noc16_async_func.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_async_func.py)
与 [`run_gls_cmr_noc16_func.sh`](../scripts/asic_dc/cmr/run_gls_cmr_noc16_func.sh)，
`RX_CAPTURE_NS=5`，不加载 SDF。探针只读，不得驱动 DUT。

### 10.1 冻结基线

- case：远程 Ultra `TAB-NET-UR-3f-r0p50.case`。
- case SHA-256：
  `dd114d8944c7995378cebeaa962591b4627a6f25807c907718a9dd5274d97b53`。
- 原始失败网表：`20260822_cmr_thin_func_dc_02`，
  SHA `3c5c9755881020c79a18e24e8d4f2c2c57e2c9304572d3aa1726d922154162ff`。
- 后续功能回归网表：`20260822_cmr_thin_rcu_matched4_dc_01`，
  SHA `dd29bd79907256bed00f3f480148a124a37302fa7b8fdea42e559053f942158f`。
- 模式：post-DC 门级、无 SDF、异步 fail-fast 边界 TB。
- 基线 run：`20260822_cmr_thin_func_p50_baseline_03`。

### 10.2 未 patch 时的首个 X 断点

未对 Mutex/Delay 做功能模型替换时，完整 p50 在 210 ns 报
`TB_X_FAIL`：`out_req[16]` 为 X，对应
`routerL2.io.outputs.parent(0)`。fail-fast 在写出 CSV 前终止。

L2 只读 probe run `20260822_cmr_thin_func_p50_l2x_03` 把同一时刻缩小到
`routerL2.InputPortModules_3`：

```text
t=210 ns  dest=0c20c2  reqrc=1  ackrc=0
          mat=xxxx -> 0001
          routesel=xxxx -> 000x
          ackrc -> x
L2 parent OPM  reqin=1000  ppe=x000  grant=0000
IPM3           path=xxxx  reqout=1111
```

reset-only case `noc16_reset_only` 通过，因此不是复位泄漏。
截断到首包的 `tab_ur_3f_r0p50_prefix_pkt10` 在 290 ns 复现同一
`RouteSel/Ack_rc` X 链。责任边界是 RCU 在 zero-delay 门级模型中把未稳定的
`Mat` 送到自应答 `InternalAck.Toggle`，而不是地址字段本身错误。

### 10.3 功能模型实验（不是最终 DUT 修复）

为了让无 SDF 仿真具备可见 Delay 和可解析 Mutex，功能 harness 对独立副本
`NoC_16nodes_post_func.v` 运行
[`patch_gls_netlist.py`](../scripts/asic_dc/sim_gls/patch_gls_netlist.py)
`--mode cmr_func`：Delay `#(1.0)`，Mutex 为 10/11 ps 微偏斜交叉耦合模型。
生产 `*_post.v` 未改写。

| Run | 网表 | 结果 |
|---|---|---|
| `20260822_cmr_thin_func_prefix_pkt10_funcpatch_01` | matched4 + 固定优先 Mutex | prefix PASS，3/3 |
| `20260822_cmr_thin_func_prefix_pkt10_skewmutex_02` | matched4 + 微偏斜 Mutex | prefix PASS，3/3 |
| `20260822_cmr_thin_func_tab_p50_funcpatch_01` | matched4 + 固定优先 Mutex | `TB_STALL_FAIL` 21.21 µs，rx=60/3000 |
| `20260822_cmr_thin_func_tab_p50_skewmutex_01` | matched4 + 微偏斜 Mutex | 同一时刻、同一计数的 `TB_STALL_FAIL` |

prefix 通过且完整 p50 不再报 X，说明 210 ns 的 `out_req[16]` X 来自无 SDF
标准单元模型缺少可见控制时序。两种 Mutex 功能模型的停滞签名相同，排除
固定优先级饥饿作为 21.21 µs 停滞的根因。该 patch 只服务功能 GLS，不替代
SDF 签核。

### 10.4 21.21 µs 停滞定位

core8 专用 probe `20260822_cmr_thin_func_tab_p50_stallprobe_01` 排除旧 SDF
路径：`L1(0,1).IPM3 path=0000`，对应 OPM `ppe=0000`。

全局只读 probe `20260822_cmr_thin_func_tab_p50_globalprobe_01`：

```text
t=21.21 us  rx=60 expected=3000
all out_req == out_ack
several inputs req != ack with active_input=-1
port 16..19 idle (no top traffic in this case)
```

输出握手全部完成，因此不是 sink 回压。多个输入端口在 TB 已撤销
`active_input` 后仍 `req!=ack`，后续 Head 无法发出。

Ack 退相追踪 `20260822_cmr_thin_func_tab_p50_acktrace_01` 给出第一个因果事件：

```text
t=255 ns  port=3  active=-1
last accepted tail = 4204205  H/T=0/1  rect=(1,2)-(1,2)
next unissued head = 830c30f  H/T=1/0  rect=(3,3)-(3,3)
in_req/in_ack = 1/0
tb_in_req/tb_in_ack = 1/0
rx=0 expected=213
```

按 [`NoC_16nodes.scala`](../src/main/scala/NoC/CMR/NoC_16nodes.scala) 的
`core = 2*x + localX + 4*(2*y + localY)` 与 `selector = (~dir) & 3`，
`port 3` 映射到 `routerL1(1,0).inputs.child(1)`，即
`routerL1_1_0.InputPortModules_1`。

证据目录：

- `scripts/asic_dc/cmr/results/20260822_cmr_thin_func_p50_baseline_03/`
- `scripts/asic_dc/cmr/results/20260822_cmr_thin_func_p50_l2x_03/`
- `scripts/asic_dc/cmr/results/20260822_cmr_thin_func_tab_p50_stallprobe_01/`
- `scripts/asic_dc/cmr/results/20260822_cmr_thin_func_tab_p50_globalprobe_01/`
- `scripts/asic_dc/cmr/results/20260822_cmr_thin_func_tab_p50_acktrace_01/`

### 10.5 已排除 / 已证实 / 待验证

- 已排除：复位泄漏；sink/output 回压；core8 / `L1(0,1).IPM3` 作为本轮停滞首因；
  功能 Mutex 固定优先级饥饿。
- 已证实：未 patch 时首个 X 在 L2 IPM3 的 `Mat/RouteSel/Ack_rc`；
  patch 后首个停滞事件是 port 3 在 255 ns 的 input Ack 退相。
- 待验证：`routerL1_1_0.InputPortModules_1` 内部哪一级把 `Ackout` 从完成相拉回。

### 10.6 下一轮唯一实验

为 `routerL1_1_0.InputPortModules_1` 增加只读定向 probe，记录
`Ackout`、Buffer write/read、`PathEnabled` 与 `TailPassed`。
在 255 ns 找到把 input Ack 从完成相拉回的第一级信号。
未定位该边界前不改 RTL，不扩大到完整 SDF 回归。

该定向 probe 已完成。无 SDF 的 255 ns 退相与后续 **严格 SDF 的 2317 ns**
不是同一条故障；SDF 写指针实验见第 11 节。

## 11. Thin NoC16 严格 SDF 写指针 / Reqin DEL250（2026-08-22）

本轮目标：在冻结 Thin 功能协议正确的前提下，用 TAB p50 **严格 SDF**
关掉 Fig. 7 WriteCounter 完成沿的相对时序洞。入口
[`run_remote_cmr_noc16_sdf.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_sdf.py)
与 [`run_remote_cmr_noc16_async_sdf.py`](../scripts/asic_dc/cmr/run_remote_cmr_noc16_async_sdf.py)，
fail-fast 异步 TB，`RX_CAPTURE_NS=5`，SDF MAXIMUM，
`FUNCTIONAL_STALL_PROBE=1`，`IPM3_ACK_PROBE=1`。
禁止改 Fig. 7 XOR、禁止在 `WriteCounter.v` 插入 `DelayElement`、
禁止全局 min-delay `Reqin → CellFull.D`。

时序意图对照
[`CMR_DC_Timing_Intent.md`](CMR_DC_Timing_Intent.md)
的 CMR-RCU-01 / CMR-HS-02 / CMR-WP-01。

### 11.1 问题

RTL 两相写口协议本身正确：非 Tail 用 `CellFull` 应答，Tail 等
`AllCellEmpty`，五路 `AckoutCell` 再 XOR 成通道 Ack。
SDF 下的洞是：WriteCounter 用 `posedge ~(Reqin^Ackout)` 打指针，
而下一拍 `Reqin`/`Datain` 仍可能看见**上一拍仍透明**的 latch。

冻结 matched4 网表上的稳定签名：

```text
FUNC_ACK_RETREAT / IPM3_ACK_RETREAT  t=2317 ns  port=2
  routerL1_1_0.InputPortModules_3
  in=0/1  last_flit=8108108 H=1 T=0
  wr_ptr 仍停在 Tail 槽；要等到随后 0/0 才旋转
  未选中槽的残留 Ack 被 XOR 进通道 → 完成相上 Ack 退相
TB_STALL_FAIL @ 60.21 µs  rx=753/3000
```

这与第 10 节无 SDF、`cmr_func` patch 后的 **255 ns / port 3 / IPM1**
不是同一时刻、同一端口。255 ns 是 zero-delay 功能模型里
`AllCellEmpty` 二次上升沿；2317 ns 是带 SDF 的写指针相对时序。

不等式（同一完成沿参考）：

```text
Tmax(complete↑ → WritePointer[next] @ CellFull.E) + Tsetup
  < Tmin(Ackout@pin → next Reqin @ CellFull.D)
```

### 11.2 工作流

固定 case：远程 Ultra `TAB-NET-UR-3f-r0p50.case`，
SHA `dd114d8944c7995378cebeaa962591b4627a6f25807c907718a9dd5274d97b53`。
工作冻结：`20260822_cmr_thin_rcu_matched4_dc_01`。
STA：`20260822_cmr_thin_wp_sta_01`（DDC 即该 matched4）。

实验顺序（先约束/ECO，再同一 harness 看**第一处**退相；恶化则记录，
不叠更多单元）：

```text
RCU MatchedDelay（显式，已在 RTL）
  → 撤 complete 展宽、撤 WritePointer SDC
  → DC insert 仅打 WriteCounter XNOR 的 Reqin 脚
  → TAB p50 SDF；若仍退相则报价，不再往这条网加 cell
```

1. **RCU 显式延迟留下。**
   `RouteComputationLogic` 已用 `DelayElement(4 × DEL150)` 推迟
   `Req_rc`，再 `RouteSel = Mat & (delayed Req_rc ^ Ack_rc)`。
   不搬进 SDC。DC 结构门只统计 `MatchedDelay` 层次：
   `DelayElement* && *MatchedDelay*` = 25，其下 `DEL150` = 100。
   FIFO 里另外约 24 个 `DelayElement` 不计入 RCU 门。

2. **撤 WritePointer 路径约束与 complete 展宽。**
   删除 `async_cmr_wp_control.sdc`；NoC16 DC 不再
   `create_clock` / `set_min_delay` / `set_max_delay` 写指针。
   删除 `ck = complete | DEL(complete)` 的 stretcher 分支。
   `WriteCounter.v` 不改。

3. **非 RTL 的 HS-02 ECO。**
   `compile_ultra` 之后 `insert_buffer` 一颗
   `DEL250D1BWP12T30P140` 到每个 WriteCounter 层次 `Reqin`
   （25 个，`dont_touch`）。目标是只推迟 XNOR 看到的 Reqin，
   不推迟 `CellFull.D`。

先前同 harness 的对比（均未过）：

| 网表 | 第一处退相 | 结果 |
|---|---|---|
| `wp_rtc_dc_01`（clocks，无 buffer） | 2317 ns port 2 `in=0/1` | stall 60.21 µs，rx=753 |
| `wp_mindelay_dc_02`（Reqin `DEL150`） | 370 ns `in=1/0` Head | stall 51.21 µs，rx=22 |
| `wp_mindelay_dc_03`（Reqin `DEL100`） | 250 ns `in=1/0` Tail | stall 51.21 µs，rx=7 |
| `wp_stretch_dc_04`（complete 展宽） | 250 ns `in=1/0` Tail | stall 51.21 µs，rx=7 |

`DEL100`/`DEL150` 的 `1/0` 解释是：Ack 追上**过期的延迟 Req**，
假 complete 上升沿多打一格，XOR 在通道已相等后多翻一次。
展宽 complete 脉冲得到同一 250 ns `1/0`，不是 2317 ns 的修法。

### 11.3 DC ECO 踩坑

`insert_buffer` 落在组合环（Reqin/Ackout/XNOR）上时，脚选错会静默插到
Ackout 一侧。结构计数若不过滤名字，会把 FIFO DelayElement 算进 RCU。

| DC run | 失败原因 | 日志要点 |
|---|---|---|
| `20260822_cmr_thin_wp_del250_dc_01` | 错脚 + 过严计数 | delay `I` 接到 `.../Ackout`；`*MatchedDelay*` 层次=125（wrapper+内部），总 `DEL150`=124 |
| `20260822_cmr_thin_wp_del250_dc_02` | RCU 计数含 FIFO | 已插在 `WriteInterfaceControl`，`I=io_Reqin`；`DelayElement*`=49（25 RCU + 24 FIFO），门仍要 25 |
| `20260822_cmr_thin_wp_del250_dc_03` | 通过 | `RCU_DE=25 RCU_DEL150=100 WP_DEL250=25`；`I` 网须含 `Reqin` 且不含 `Ackout`；`Z` 扇出不得碰到 `CellFull` |

通过后的连接（网表与 SDF 各 25 颗 `DEL250`）：

```text
WriteInterface.io_Reqin
  → wp_hs02_req_dly.I
  → eco_net → Counter.Reqin → XNOR
io_Reqin 仍直连 CellFull.D（未延迟）
```

### 11.4 DEL250 GLS

- GLS：`20260822_cmr_thin_wp_del250_tab_sdf_01`
- 网表：`20260822_cmr_thin_wp_del250_dc_03`
- SDF MAXIMUM，`annotation_errors=0`

```text
FUNC_ACK_RETREAT t=2317 ns port=2 in=0/1 last_flit=8108108 H=1
IPM3_ACK_RETREAT routerL1_1_0.InputPortModules_3
  wr_ptr=01000  reqin=0  ackout=0→1  complete=1→0
TB_STALL_FAIL @ 60.21 µs  rx=753/3000
```

与 matched4 / clocks-only **同一签名**，不是 `DEL100`/`DEL150` 的 `1/0`。
细胞确实进了仿真网表和 SDF，因此不是漏插或未标注。

### 11.5 已排除 / 已证实 / 下一轮

- 已排除：再靠 RCU 显式链或 WritePointer SDC/`create_clock` 关掉 2317 ns；
  complete 展宽；在 `WriteCounter.v` 里写 `DelayElement`；
  把 Reqin→XNOR 的延迟从 100/150 加到 250。
- 已证实：2317 ns 第一级是写指针相对时序（CMR-WP-01），不是 Fig. 7 XOR 方程错误。
  正确插在 Reqin 上的 `DEL250` **改变不了**这条退相；
  较早的 `1/0` 来自把 XNOR 一侧（或 Ackout）拖慢后的假 complete。
- 下一轮唯一方向：按 timing-intent 做 **指针快 / 下一拍 Req 慢** 的成对约束
  （complete↑ → `CellFull.E` 的 max-delay，Ackout→下一拍 Reqin 的 min-delay），
  而不是再往 Reqin→XNOR 这条网上加 cell。

证据：

- `scripts/asic_dc/cmr/results/20260822_cmr_thin_wp_del250_tab_sdf_01/`
- DC log：`20260822_cmr_thin_wp_del250_dc_03`（远程 `logs/dc/`）
## 12. Thin clean-baseline PhaseSelector localization (2026-08-23)

The clean NoC16 DC run `20260823_cmr_thin_clean_psprobe_tab_sdf_01` contains
no historical write-side or HS01 delay ECO:

```text
WP_REQ_DEL250_COUNT=0
HS01_HEAD_BUFFER_COUNT=0
HS01_TAIL_BUFFER_COUNT=0
RCU_DELAY_ELEMENT_COUNT=25 / RCU_DEL150_COUNT=100
```

Strict MAXIMUM-SDF TAB p50, with the read-only 64-event phase probe, fails at
the same first structure as the prior experimental netlists:

```text
routerL1_1_0.InputPortModules_3.RouteComputationUnit
  .AddressRegister.PhaseSelectorBlock.phase_reg

posedge D  = 2316.423 ns
posedge CP = 2316.441 ns
setup      = 19 ps
observed   = 18 ps
```

The input changes from Tail `4204206` to Head `8108108` while the previous
Tail acknowledgement is still propagating to `complete/CP`.  The notifier
makes `phase_reg.Q`, then `Req_pc`, unknown.  The probe sees
`WritePointer=00100` (Cell2 selected) at the notifier and no write-side X;
therefore the current Thin SDF first failure is not a missed Cell2-to-Cell3
WriteCounter rotation.

The remote-derived TAB prefix through input tick 105 reproduces the identical
2316.441 ns PhaseSelector violation.  The prefix through tick 104 does not
produce that violation; it later reaches the existing tail stall instead.
The next repair must preserve the whole `Reqin/Datain/Head/Tail` bundle until
the Tail-completion close event, using implementation-level relative timing;
do not add a Reqin-only or Head/Tail-only RTL delay.

### 13. External-Ack buffer trial (2026-08-23, deferred)

`run_dc_cmr_noc16.tcl` now has an explicitly opt-in
`CMR_ACK_FEEDBACK_BUFFER_STAGES=0/1/2` experiment.  It inserts one
`BUFFD0BWP12T30P140` after each of the 25 Thin NoC16 IPM `io_Ackout` output
pins, i.e. on the Router's external input-Ack branch only.  It does not edit
CMR RTL or any `Reqin/Datain/Head/Tail` bundle path.  The DC structure audit
for run `20260823_cmr_thin_ackfb1_prefix_t105_sdf_02` reported:

```text
ACK_FEEDBACK_BUFFER_STAGES=1
ACK_FEEDBACK_BUFFER_COUNT=25
WP_REQ_DEL250_COUNT=0
HS01_HEAD_BUFFER_COUNT=0
HS01_TAIL_BUFFER_COUNT=0
```

Strict SDF annotation was clean (`annotation_errors=0`, no `IFNSDFA`, no
setup/hold violation and no boundary X).  However, the run made only 9
deliveries and stalled before the target IPM accepted the tick-105 Head:

```text
TB_STALL_FAIL t=51210 ns, rx=9/651
```

Therefore it has **not** demonstrated that the 2316.441 ns transaction was
reached safely, and it is not a production timing repair.  The default is
kept at `CMR_ACK_FEEDBACK_BUFFER_STAGES=0`; this early global Tail-stall is a
separate next-round investigation.  Do not run the two-stage variant or alter
RTL until the Ack-feedback trial's packet-level stall is localized.

### 14. Fig. 6 explicit `phEn` Toggle trial (2026-08-23)

The standalone `HandshakeComplete.v` wrapper was removed.  The two Fig. 6
consumers now deliberately use opposite handshake phases:

```text
HeadPredictor.complete = ~(Reqin ^ Ackout)   // acknowledged-completion event
PhaseSelector.phEn     = !Head & (Reqin ^ Ackout)
phase                  = Toggle(reset, phEn)
Req_pc                 = Reqin ^ phase
```

This corrects the first version of the trial, which incorrectly supplied the
inverted phase to `PhaseSelector`.  `Toggle` has a direct ASIC mapping
(`D = !Q`, `CP = En`) so DC does not leave GTECH/SEQGEN inferred state.

Fresh local elaboration plus the complete CMR smoke suite pass, including the
five-port no-U-turn Router smoke.  The remote Thin NoC16 DC run
`20260823_cmr_thin_phentoggle_prefix_t105_sdf_03` also passes with
`GTECH=0`, `SEQGEN=0`, 25 RCU matched-delay modules and no historical
WriteCounter/HS01 delay experiment cells.

Its strict MAXIMUM-SDF t105-prefix run does **not** yet reach the former
2316.441 ns PhaseSelector breakpoint: fail-fast observes a new earlier
boundary failure at 255.116 ns:

```text
TB_PROTOCOL_X port=10 t=255.000 ns req=x ack=0 data=xxxxxxx
TB_X_FAIL boundary_control ... out_req=000001000x0100000000
```

SDF annotation completes with no `IFNSDFA` and the log contains no printed
`Timing violation`/`$setup`/`$hold` record.  Consequently this run is not
evidence that the old PhaseSelector violation is fixed; the new port-10 X
must be localized before resuming the t105 breakpoint or full TAB sequence.

### 15. Thin port-10 X localization (2026-08-23, frozen SDF)

The frozen post-DC netlist/SDF from
`20260823_cmr_thin_phentoggle_prefix_t105_sdf_03` was reused without RTL or
DC changes.  A read-only 64-event probe proves that core10 is not the source:

```text
core10 egress
  <- routerL1_1_1.OutputPortModules_3
  <- routerL1_1_1.InputPortModules_4 (parent ingress)
  <- downwardLinkFifos_0
  <- routerL2.OutputPortModules_0 requester slot 2
  <- routerL2.InputPortModules_3 branch 0
```

The first observed internal X is at **233 ns**:

```text
routerL2.InputPortModules_3.RouteComputationUnit.io_RouteSel_0 = X
```

At that instant, the corresponding upstream FIFO dequeue is stable
`Req/Ack=0/0`, with data `0308308`; the L2 IPM's branch request is `0/0` and
its packet-lifetime `PathEnabled_0` is still `1`.  Thus the FIFO, L2 OPM,
downward FIFO and L1 Router are propagation stages, not the first X source.
At 252 ns that transient/later-held RCU result appears as
`routerL2.OutputPortModules_0.PktPathEnable_2 = X`; at 255 ns it reaches
core10 as `Req=X`.

The remaining unresolved boundary is inside L2/IPM3's Fig. 6 RCU:
`AddressRegisterUnit`, `RouteComputationLogic` (`Mat`/matched-delay), or its
`InternalAckModule` feedback.  No repair was applied.  The next diagnostic
must probe `Req_rc`, `Ack_rc`, `dest`, `Mat[0]`, matched-delay output and
`RouteSel[0]` for this exact IPM on the same frozen netlist.

### 16. L2/IPM3 RCU first-X result (2026-08-23, frozen SDF)

The same netlist/SDF was run again with a read-only, 64-event Fig. 6 probe.
The probe is enabled at 200 ns and snapshots at 240 ns, before the boundary
fail-fast monitor observes the port-10 X at 255 ns.  No CMR RTL, DC command,
delay, FIFO, OPM or mutex was changed.

The first state-bearing signal that becomes X is **not** `Mat`,
`MatchedDelay`, `Ack_rc`, or `RouteSel`:

```text
routerL2.InputPortModules_3.RouteComputationUnit
  .AddressRegister.HeadPredictorBlock.en_state_reg.Q = X   (213 ns)
```

This register is the ASIC `DFSNQD` used by `HeadPredictor`:

```text
D  = Tail
CP = complete = ~(Reqin ^ Ackout)
Q  = En
```

The recorded transition order is:

```text
213 ns: Reqin/Ackout=1/1, Tail(D)=0, complete(CP)=1, Q=1, En=1
213 ns: Q -> X, therefore En -> X                 <-- first abnormal state
214 ns: AddressRegister control opens while En=X; Req_rc follows X
232 ns: MatchedDelay.Z and BundlingSignal -> X
233 ns: RouteSel[0] -> X, then Ack_rc -> X
252 ns: L2 OPM0 PktPathEnable requester-2 -> X
255 ns: core10 Req -> X
```

`dest=0c20c2` remains known through this sequence, and the PhaseSelector
control (`phEn`, `phase`, `Req_pc`) also remains known until after the
HeadPredictor output is contaminated.  Thus the route function and the
matched-delay/ack feedback are propagation victims, rather than the cause.

The run contains no printed VCS `Timing violation`, `$setup`, `$hold` or
notifier message.  The 1-ns event log cannot distinguish the sub-ns ordering
of `Tail(D)` and `complete(CP)` inside `DFSNQD`; the next diagnostic, if a
repair is authorized, must therefore use a narrow pin-level timing trace or
the cell/SDF timing check for this single `en_state_reg`.  It must not change
the RouteComputation or add an RTL delay before that ordering is established.

### 17. X root cause: final upward FIFO stage violates output bundled-data (2026-08-23)

The pin-level continuation proves that `HeadPredictor` is only the first CMR
state element to retain the fault.  The root is the last stage of the incoming
FIFO:

```text
routerL2.InputPortModules_3
  <- upwardLinkFifos_3.stages_2 (AsyncStage)
```

`AsyncStage` clocks both its control output (`Out_Req`) and 28-bit data output
registers with the same `acg.fire_o`.  The frozen SDF timing is:

```text
212.318 ns  stages_2 D[26] = 0, already stable
212.594 ns  stages_2 acg_fire_o = 1
212.635 ns  FIFO deq Req = 1, deq Data[26] is still X
212.671 ns  FIFO deq Data[26] = 0
212.721 ns  CMR StorageCell0 Tail[0] = 0
```

Thus the FIFO **does not have an input-data setup problem**: its final-stage
data D is a known zero before `fire_o`.  Instead, the request flip-flop reaches
its Q output 36 ps before the data flip-flop reaches Q.  Because CMR cell0 is
already transparent (`WritePointer=00001`), that X is captured/observed as
`Tail[0]`; `AckoutCell[0]` becomes X, then the XOR Ackout feeds the RCU as
described in section 16.

This is a missing **FIFO dequeue output bundled-data constraint**:
`deq Req` must be released only after every `deq Data` bit is stable.  The
diagnostic does not prescribe a fix and makes no RTL/DC change.  Any repair
must protect the FIFO output control path (for example, a DC-level matched
control delay after the final data register), rather than adding a delay in
RCU/HeadPredictor or changing CMR routing behavior.

### 18. Try Transition CircularFIFO as the Thin inter-level link (2026-08-23)

Hypothesis: replacing the depth-3 `AsyncFifo`/`AsyncStage` chain with the
paper four-slot `CircularFIFO` removes the dequeue `Req`-before-`Data` race,
because slot data is already closed in `DLatchBank` before `Reqout` is
formed by the XOR of per-slot `Req` latches.

Constraints kept from earlier rounds: no Fig. 7 XOR change, no
`DelayElement` in `WriteCounter.v`, no HeadPredictor/RCU delay as a FIFO
repair.

How it is selected: `CMR_USE_CIRCULAR_FIFO=1` on `NoC.CMR.NoC_16nodes`
(eight existing depth-3 links). Physical ring capacity remains four slots.

DC/GLS:

- First compile `20260823_cmr_thin_circfifo_dc_01` matched the expected
  latch/FIFO counts (`CIRCULAR=8`, extra `LHCNDQD=944`, `LHSNDQD=48`)
  but left 896 GTECH mux bits and 64 SEQGEN pointer flops because
  `set_dont_touch` had been applied to the whole CircularFIFO hierarchy.
  That dont_touch was removed.
- Passing compile: `20260823_cmr_thin_circfifo_dc_02`.
- Prefix `TAB-NET-UR-3f-r0p50_prefix_t105`, fail-fast async TB,
  `RX_CAPTURE_NS=5`, SDF MAXIMUM, run
  `20260823_cmr_thin_circfifo_prefix_t105_sdf_01`.

Prefix result:

```text
SDF annotate Done, annotation errors=0, timing_violation_count=0
No TB_PROTOCOL_X / no 255 ns port-10 X
No PhaseSelector $setuphold at 2316 ns
TB_STALL_FAIL t=51210 ns idle_ns=50699.771 rx=24 expected=651
```

Interpretation: the AsyncStage dequeue `Req`-before-`Data` X is gone on
this netlist, and the run lives past the old 2316 ns PhaseSelector hold.
The first remaining failure is a later network stall with many core
ports parked on Tail (`req=1 ack=0`) and all outputs equal.  That stall
is not evidence that CircularFIFO restored the bundled-data race; it is
the next protocol/backpressure question.  Section 19 removes the
inter-level FIFOs entirely and shows the same stall.

### 19. Bypass inter-level FIFOs (2026-08-23)

Goal: decide whether the 51.21 µs prefix stall in section 18 is caused by
the CircularFIFO (protocol, capacity, or backpressure) or by the CMR
routers.  Diagnostic topology only: `CMR_BYPASS_INTERLEVEL_FIFO=1` on
`NoC.CMR.NoC_16nodes` wires each L1 parent port directly to the matching
L2 child port.  No CMR Router RTL change, no HeadPredictor/RCU delay,
no FIFO cells.

#### 19.1 Frozen baseline

- Thin netlist/SDF: `20260823_cmr_thin_nofifo_dc_01` (DC job `11388001`).
- Structure: `FIFO=0 EXPECTED_FIFO=0`, latch counts back to
  `CLEAR=5725` path-100 / `non_path=5625`, `SET=450`.
- Case: remote CMR `TAB-NET-UR-3f-r0p50_prefix_t105.case`.
- Case SHA-256:
  `5d1b382e3506d20c4a7df8a2d7dbd9d1a8d9729467e1c42d68d00fe1e29c9af4`.
- GLS: `20260823_cmr_thin_nofifo_prefix_t105_sdf_01`, LSF `11388101`.
- Mode: post-DC netlist, MAXIMUM SDF, fail-fast async TB,
  `RX_CAPTURE_NS=5`.  Re-synthesized (bypass wrapper only).

TAB p50 was **not** run: prefix already fail-fast stalled, so a larger
traffic case would not move the first breakpoint.

#### 19.2 Prefix result vs CircularFIFO

| | CircularFIFO §18 | No FIFO (this section) |
|---|---|---|
| Netlist | `20260823_cmr_thin_circfifo_dc_02` | `20260823_cmr_thin_nofifo_dc_01` |
| SDF annotate / errors | Done / 0 | Done / 0 |
| Timing violations | 0 | 0 |
| 255 ns port-10 X | no | no |
| 2316 ns PhaseSelector hold | no | no |
| First fail | `TB_STALL_FAIL` 51210 ns | `TB_STALL_FAIL` 51210 ns |
| idle_ns | 50699.771 | 50699.771 |
| rx / expected | 24 / 651 | 18 / 651 |
| `input_done` | `11110000000000000000` | `11110000000000000000` |
| `tb_in_req` / `tb_in_ack` | `00000111101111111011` / `00001000010000000100` | same |
| `out_req` / `out_ack` | `00001100100101100000` / equal | same |
| `active0` | 2 | 2 |

Stall-port snapshot is the same injection state: every core is parked on
the same Tail flit with the same `req`/`ack` polarity (port 0
`420820a` `1/0`, port 2 `4104105` `0/1`, port 10 `400800b` `0/1`, …).
Only `rx` differs (24 vs 18).

#### 19.3 Responsibility

**Excluded as the sufficient cause of this stall:** the inter-level
FIFO, whether `AsyncFifo`/`AsyncStage` or Transition `CircularFIFO`.
Removing all eight links leaves the same 51.21 µs Tail-wait deadlock
and the same boundary bit vectors.

**Still in scope:** CMR L1/L2 (input-port Ack not returning on those
Tails, output-port not launching, or a routing/mutex hold that starves
the equal output side).  Outputs are handshake-equal, so the visible
symptom is injectors waiting for input Ack.

#### 19.4 Next unique experiment

Do not re-tune CircularFIFO or add RCU delay for this stall.  The next
step is a **read-only** Thin stall probe on frozen
`20260823_cmr_thin_nofifo_dc_01` (or the CircularFIFO netlist; the
boundary state is the same) that dumps L1 parent and L2 child Req/Ack
and the stalled IPM WritePointer/CellFull for the cores with
`req=1 ack=0`, without driving the DUT.

§19.4 之后的 NoFIFO stall probe、TAB p50 以及 WP-01 源端 0.20 ns 周转已在
2026-08-24 完成。下面从 VCTM p50 与 ACG FIFO 恢复记起。

## 20. NoFIFO VCTM p50：不是 WP-01，是 L1–L2 Tail 环（2026-08-24）

### 20.1 冻结基线

- Thin NoFIFO 网表沿用后续 ECO（OPM Ackin 1×DEL250、Mutex2 `q1=ND2D2`、
  RCU 4×DEL150）。D/E/F 关闭。
- Case：远程 Ultra `VCTM-MC5-NM-3f-r0p50`，SHA-256
  `e7772a11f981f5f33096f89c853f185c36821eee8b41de5b66278b72cea2e669`，
  expected **3366** flits。
- Harness：direct boundary（`STRUCTURAL_ENDPOINTS=0`），
  `+ACK_TO_NEXT_REQ_GUARD_NS=0.20`，`RX_CAPTURE_NS=5`，
  `NOFIFO_STALL_PROBE=1` 与 `FUNCTIONAL_STALL_PROBE=1`。
- 确认 run：`20260824_cmr_thin_nofifo_vctm_guard200_stallprobe_01`。

### 20.2 结果

```text
SDF annotate Done, annotation_errors=0, timing_violation_count=0
无 X、无 FUNC_ACK_RETREAT
TB_STALL_FAIL t=53210 ns idle_ns≈50860 rx=571 expected=3366
16 个 core 输入都停在 Tail（H=0 T=1）
关键 IPM TailPassed=0000
```

`NOFIFO_STALL_HS` 上 L1 parent 与 L2 child 是**同一对** pending 握手
（bypass 把 L1 OPM 与 L2 IPM 焊在同一根线上）。这不是 p30 的 CMR-WP-01
CellFull/双 Head XOR 复发。

### 20.3 下一轮

把八条 L1–L2 链路恢复为 depth-3 `AsyncFifo`（`CMR_BYPASS_INTERLEVEL_FIFO=0`，
`CMR_USE_CIRCULAR_FIFO=0`），再跑同一套 VCTM harness。不改 Fig. 7 XOR，
不把 `DelayElement` 放进 `WriteCounter.v`，不把 HeadPredictor/RCU delay
当作 FIFO 修复，不恢复 Fig. 8 `PacketSeen`。

## 21. 恢复 ACG FIFO：255 ns 出队 bundled-data X（2026-08-24）

### 21.1 拓扑与 DC

- Emit：`async_fifo=8 circular_fifo=0`。
- DC：`20260824_cmr_thin_acg_fifo3_dc_01`，LSF `11399801`。
- 结构：`FIFO=8 EXPECTED_FIFO=8 ASYNC_FIFO=8 CIRCULAR_FIFO=0`，
  非 path latch 5625 / SET=450（CLEAR 总计 5725，含 100 个 path latch）。
- 同一套 proven ECO；WP_DEL250=0，ACK_FEEDBACK=0。

### 21.2 同一套 VCTM harness

run `20260824_cmr_thin_acg_fifo3_vctm_guard200_stallprobe_02`
（fail-fast 在 X 时拉 `diagnostic_trigger`，以便打出 HS dump）：

```text
TB_X_FAIL boundary_control t=255000
TB_PROTOCOL_X port=13 req=x data=XX0XX0X
annotation_errors=0, timing_violation_count=0
rx=3 / 3366
```

`port 13` = `routerL1_0_1` child dir 0（core 13）。这不是 53.21 µs Tail 停滞：
仿真在更早的协议 X 处被 fail-fast 杀掉。

`NOFIFO_STALL_HS` 已显示 L1 parent 与 L2 child **不是同一对 pending**
（例如 `L1_00_parent_up` 1/1 空闲 vs `L2_child3_in` 1/0 pending）。
bypass 耦合已拆掉；剩下的是 FIFO 出队 X。

### 21.3 引脚级时间线（冻结 ACG 网表）

只读探针 [`tb_cmr_thin_acg_deq_x_probe.sv`](../scripts/asic_dc/cmr/tb_cmr_thin_acg_deq_x_probe.sv)，
run `20260825_cmr_thin_acg_fifo3_deq_x_diag_03`，LSF `11400301`。
`$realtime` 分辨率；窗口 200–220 ns。受害链是
`upwardLinkFifos_0` → L2 IPM0 与 `upwardLinkFifos_3` → L2 IPM3。

`up0`（喂 L2 IPM0）：

```text
212.573 ns  fire=1  d26=0  req=0  data_q=x   D 已稳定，fire 上升
212.614 ns  fire=1  d26=0  req=1  data_q=x   Req Q 先到，Data 仍为 X
212.650 ns  fire=1  d26=0  req=1  data_q=0   Data Q 晚 36 ps
```

`up3` 同一模式，Req 在 212.630 ns、Data 在 212.666 ns。

HeadPredictor 是传播受害者，不是根因：

```text
212.633 ns  HP D/Tail=X, Q=1          FIFO data_q 仍为 X
212.650 ns  Tail=0
212.852 ns  HP Q → X（tail 已为 0，cp=1）
254.964 ns  core13 data X，随后 req X
```

**已排除：** FIFO 输入 setup（`fire` 时 `D[26]` 已知）；L101 OPM 独立故障
（port13 X 晚约 42 ns）；Fig. 8 `PacketSeen` / WP-01 XOR。

**已证实：** 与 §17 相同的末级 `AsyncStage` 出队约束缺失：同一 `acg.fire_o`
打 `Out.Req` 与 28-bit Data，Req FF 的 clk-to-q 快于 Data FF。
空闲相 `req=0 data_q=x fire=0` 不是握手竞态（Data 在空闲时未定义）。

## 22. AsyncStage Out.Req 1×DEL150，然后重测 VCTM（2026-08-25）

### 22.1 修复

[`AsyncStage.scala`](../src/main/scala/Router_Architecture/common/async/AsyncStage.scala)
在 `acg.Out.Req` 与 `io.out.HS.Req` 之间插入 `DelayElement`，角色
`AsyncDelay.FifoOutReq`（P150_BASELINE / ASIC 为 1×DEL150）。
ACG `fire_o`、Fig. 7 XOR、HeadPredictor、RCU matched delay 未改。
八条 depth-3 FIFO 的每一级 `AsyncStage` 都带该 delay，避免中间级把 X
传给下一级。

DC：`20260825_cmr_thin_acg_fifo3_outreqdel150_dc_01`，LSF `11400401`，
`CMR_NOC16_DC_PASS`。结构仍为 FIFO=8、latch 5625/450。

### 22.2 同一探针，修复后

run `20260825_cmr_thin_acg_fifo3_outreqdel150_deq_x_01`，LSF `11400501`：

```text
213.076 ns  fire=1  req=0  data_q=0   Data Q 先稳
213.254 ns  fire=1  req=1  data_q=0   Req 晚约 178 ps
213.497 ns  HP Q 1→0，不是 X
无 hp_q_x，无 port13_x，无 TB_X_FAIL
```

255 ns 边界 X 关闭。仿真继续跑到 stall watchdog。

### 22.3 VCTM p50（depth-3 ACG 仍在）

同一 harness，run
`20260825_cmr_thin_acg_fifo3_outreqdel150_vctm_guard200_stallprobe_01`，
LSF `11400601`：

| | NoFIFO §20 | ACG 未修出队 | ACG + Out.Req DEL150 |
|---|---|---|---|
| 网表 | NoFIFO | `...acg_fifo3_dc_01` | `...outreqdel150_dc_01` |
| 首失败 | stall 53.21 µs | **X 255 ns** | stall 53.21 µs |
| rx / 3366 | 571 | 3 | **586** |
| SDF errors / timing viol. | 0 / 0 | 0 / 0 | 0 / 0 |
| L1 parent vs L2 child | 同一对 pending | 已解耦（X 时刻） | **已解耦** |

```text
TB_STALL_FAIL t=53210 ns idle_ns≈50760 rx=586 expected=3366
16 个 core 停在 Tail（H=0 T=1）
TailPassed=0000
```

HS 对照（FIFO：L100↔L2 child3，L101↔child2，L110↔child1，L111↔child0）
例如 `L1_00_parent_up` 1/0 vs `L2_child3_in` 0/1，不是同一对握手。
depth-3 ACG 弹性拆掉了 bypass 焊线，但没有消掉这条 Tail 环。

### 22.4 责任边界

- **已修复：** `AsyncStage` 出队 Req-before-Data（§17 / §21）。
- **已排除作为 53.21 µs 停滞的充分原因：** 缺少层间 FIFO、255 ns X、WP-01 XOR、
  Fig. 8 `PacketSeen`。
- **仍在范围内：** CMR L1/L2 在 Tail 上的流控 / `TailPassed` / mutex 占用。
  下一轮不要再加 FIFO 出队 delay，也不要把 HeadPredictor/RCU delay 当 FIFO 修复。

## CMR-WP-04 — L2 IPM0 Head request precedes RouteSel[0] (2026-08-25)

Frozen netlist: `20260825_cmr_thin_acg_fifo3_outreqdel150_dc_01`; case:
`VCTM-MC5-NM-3f-r0p50`, direct boundary, `GUARD=0.20 ns`,
`RX_CAPTURE=5 ns`.  This was a read-only GLS probe; no RTL, CMR, OPM,
FIFO, delay, or RCU logic changed.

Both the 200 ns watchdog run `20260825_cmr_thin_acg_fifo3_wp04_short_02`
and the default 50 us run `20260825_cmr_thin_acg_fifo3_wp04_default_01`
produce the same `810c107 -> 010c107 -> 410c107` ordering.  The default
run has `annotation_errors=0`, `timing_violation_count=0`, and stalls at
`53210 ns`, `586/3366`.

```text
1856.635 ns  IPM0 input starts Head 810c107 handshake
1856.717 ns  AddressRegister Req_rc rises
1856.853 ns  branch0 ReqX rises
1856.889 ns  ReadInterface_0 Reqout toggles (Head request pending)
1857.673 ns  RouteComputationLogic RouteSel[0] rises
1857.752 ns  OPMSelector PathEnabled[0] rises
1857.804 ns  OPM1 PktPathEnable[0] rises
1857.851 ns  ReadInterface_0 Reqout returns; Head request is no longer pending
1857.914 ns  OPM1 Grant[0] rises
1858.221 ns  OPM1 outputs Body 010c107 (not the Head)
```

The first causal inversion is therefore the L2/IPM0
`RouteComputationLogic -> RouteSel[0]` path: `Reqout` launches **784 ps**
before `RouteSel[0]`.  AddressRegister is not the first late unit because
`Req_rc` rises 136 ps before `ReqX`; OPMSelector and the lane/PPE path are
also not first late units because they follow `RouteSel` in 79 ps and 52 ps,
respectively.  When `Grant[0]` becomes true, the Head request has already
returned and CMR storage is presenting Body.  This is a relative-timing
failure between the speculative `ReadInterface_0` request and route
computation, not an OPM/FIFO drop.

