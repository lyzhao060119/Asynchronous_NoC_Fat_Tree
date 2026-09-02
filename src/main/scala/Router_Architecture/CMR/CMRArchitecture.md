# CMR Router Implementation Notes

本文档以 Bhardwaj 和 Nowick 的 Continuous-Time Replication 论文 Fig. 2、
Fig. 5–8 为电路结构来源，但数据格式和路由决策已经替换为本工程的
四叉树实现。当前实现包含完整 OPM、RCU、Fig. 7/8 CMR Buffer、Fig. 5 IPM
以及五输入五输出 no-U-turn Router。

## 1. 当前数据和端口约定

CMR 不再定义独立 flit 类型，所有数据通路统一使用 `DataStruct.Packet`：

```text
flit[27]    Head
flit[26]    Tail
flit[25:20] y1
flit[19:14] x1
flit[13:8]  y0
flit[7:2]   x0
flit[1:0]   id
```

RCU 的 `Address_field` 和 `dest` 均为 `flit[25:2]`，宽度 24 bit。`id` 不参与
路由；Head/Tail 单独进入控制电路。每个物理输入通过 partial crossbar 连接到
另外四个输出，自身输入方向不能返回自身输出，分支顺序由
`UltraTopology.legalOutputPorts` 唯一确定。

## 2. OPM - Continuous Fig. 2

`Router_Architecture.CMR.OPM` 保留 Ultra OPM 已验证的数据通路，但使用论文
信号名，并恢复每个 OPM 内部的四路仲裁：

```text
PktPathEnable[4] -> Mutex4 -> Grant[4]
Grant & !TailPassed -> MG[4]
Reqin[4] -> L1-L4 -> XOR4 -> L5 -> Reqout
Datain[4] -> Data Mux(MG) -> Data Reg -> Dataout
RegEnable = !(Reqout ^ Ackin)
RegEnable falling event -> Ackout FFs + Tail Detector FFs
```

- `PktPathEnable` 是 packet-lifetime 请求，直接进入 `Mutex4`。
- `Grant` 选择唯一 IPM，`MG` 在 Tail 通过前保持数据和请求通路打开。
- L1-L4 是 normally-closed request latch；L5 和 Data Reg 是
  capture-pass output register。
- `Ackout` 在 flit 粒度返回被选输入；`TailPassed` 在 packet 粒度通知 RCU
  释放 `PathEnabled`。
- 不同输入锁存的两相请求可以处于不同逻辑电平，因此 `Reqout` 表示 XOR4
  的全局相位，不能直接与某一路 `Reqin` 的电平作相等判断。

### Mutex4 数字模型边界

`Mutex4` 由三个 `Mutex2` 构成：两个叶层 mutex 选择组内请求，一个中间 mutex
选择左右请求组。最终 grant 使用 resolved group grant 与 resolved leaf grant
直接相与。旧实现使用 Muller-C join，会在同组等待者存在时保持已经释放的
grant 并形成双授权，已删除该错误状态保持。

`Mutex2_sim.v` 的两条反馈路径使用 0.10 ns/0.11 ns 的微小失配，使完全同时的
数字请求也能确定性解析。它只是物理 mismatch 的仿真替代，不代表 ASIC
仲裁优先级或公平性；ASIC 仍使用独立的 `Mutex2_ASIC.v`。

## 3. RCU - Continuous Fig. 6

RCU 保持论文的三个主模块名：

```text
Input Channel -> AddressRegisterUnit -> RouteComputationLogic -> RouteSel[4]
                                                         |            |
                                                   Ack_rc feedback    v
TailPassed[4] ------------------------------------------> OPMSelector
                                                                      |
                                                               PathEnabled[4]
```

异步状态原语位于 `src/main/resources/ASYNC/CMR`。通用 `DLatchBank` 继续从
`ASYNC` 根目录复用。Fig. 6 `RouteComputationLogic` 在 `Req_rc` 上保留显式
`DelayElement`（默认 4 级 `DEL150`），使四路 `Mat` 先于 `RouteSel` 稳定。
WriteCounter / 写接口 RTL 不含 `DelayElement`。

### 3.1 AddressRegisterUnit

Address Register Unit 包含论文原名的 `HeadPredictor`、`PhaseSelector` 和
`LatchReg`。

Head Predictor：

```text
transaction_complete = ~(Reqin ^ Ackout)
posedge(transaction_complete): En <- Tail
reset: En <- 1
```

因此地址锁存器复位时透明，Head 的 Ackout 完成后关闭，Body 期间保持关闭，
Tail 的 Ackout 完成后重新打开等待下一 Head。

Phase Selector 以论文 Fig. 6 门级为准，与 Head Predictor 使用相反的握手极性：

```text
pending = Reqin ^ Ackout
phEn    = !Head & pending
phase   = Toggle(phEn)
Req_pc  = Reqin ^ phase
```

非 Head 的 `Reqin` 上升进入未完成窗口时 `phEn` 拉高，Toggle 翻转一次，把
`Req_pc` 扳回已锁存的 header 相位。Tail 的 `Ackout` 使 Head Predictor 重新打开
LatchReg 时，`Req_rc` 不会像新请求。Fig. 6 不用
`transaction_complete & !Head` 做 Toggle 时钟：空闲完成相上 bundled data 由
Head 变为 Body/Tail 时，那条接法会造出伪完成沿。LatchReg 一次锁存
`{Req_pc, Address_field}`，输出 `Req_rc` 和 `dest`。

### 3.2 RouteComputationLogic

原论文的四个 64-bit partition address match 被当前四叉树算法替换：

```text
RoutingInfo.flit = {2'b00, dest[23:0], 2'b00}
RouteDecision = RoutingLogic(x, y).computeRouting(
    RoutingInfo, true, routerLevel, ingressDirection)
Mat[branch] = RouteDecision.output_valid(legalOutputDirection[branch])
```

支持 `routerLevel=1..3`。`LegalOutputs` 来自 Ultra partial crossbar 规则，所以
当前 ingress 对应的输出永远不会进入四路 `Mat`。

Fig. 6 的本地两相握手保持不变，控制发射带显式匹配延迟：

```text
BundlingSignal = DelayElement(Req_rc, 4 x DEL150) ^ Ack_rc
RouteSel[i] = Mat[i] & BundlingSignal
Ack_rc = Toggle(OR(RouteSel[3:0]))
```

一个 Head 可以同时产生多个 `RouteSel`，但 OR 后只生成一次 `Ack_rc` 翻转。
Ack_rc 关闭 bundling window 后，`RouteSel` 返回低电平，而 OPM Selector 已经
保存 packet-lifetime 状态。如果合法输出集合为空，`RouteSel/Ack_rc` 均不产生，
输入保持阻塞，以便暴露非法或不可达路由而不是静默丢包。

### 3.3 OPMSelector

每个分支对应一个 reset-dominant `SRLatch`：

```text
S = RouteSel[i]
R = TailPassed[i]
Q = PathEnabled[i]
```

四个 latch 相互独立，允许多播 packet 同时占用多个 OPM，并允许各输出按自身
速度读完和释放。`TailPassed` 必须在下一 packet 的 `RouteSel` 之前撤销，禁止
同一 latch 同时 Set/Reset。

## 4. Fig. 7 Write Interface Control

写接口由一个五槽 one-hot `WriteCounter`、五个 `WriteControlUnit` 和一个
`WriteAckGenerator` 构成。输入 `Reqin` 广播到五个控制单元，但只有
`WritePointer[i]` 指向的单元打开论文中的 D latch：

```text
CellFull[i] = Latch(Reqin, En=WritePointer[i])
AllCellEmpty[i] = AND_b XNOR(CellFull[i], CellEmpty[b][i])
TailAck[i] = Toggle(AllCellEmpty[i])
AckoutCell[i] = Tail[i] ? TailAck[i] : CellFull[i]
Ackout = XOR_i AckoutCell[i]
```

非 Tail flit 的 `AckoutCell` 直接跟随 `CellFull`，因此存储完成后立即确认。
Tail 写入仍立即翻转 `CellFull`并向四个读接口广播，但其内部 Ack 保持旧相位；
只有四个 `CellEmpty` 都追平新的 `CellFull`相位后，`TailAck`才翻转。这是论文
packet-based buffering 的 Tail barrier。

五槽为奇数，两相环必须采用交替初相位，避免 WritePointer 切换到下一透明
latch 时产生伪 `CellFull`转换：

```text
CellFull/TailAck reset phase = [0,1,0,1,0]
WritePointer reset           = [1,0,0,0,0]
Ackout/Reqin reset phase     = 0
```

Fig. 8 的 `CellEmpty[b][i]` 后续必须复位到对应槽相同的初相位。论文 Fig. 7
明确把 `Reqin`与 `Ackout`都接入 Write Counter。请求到达后两相握手进入不等
状态；只有 `Ackout`追平 `Reqin`、使
`WriteHandshakeComplete = XNOR(Reqin, Ackout)`产生完成上升沿时，Counter 才按
`0 -> 1 -> 2 -> 3 -> 4 -> 0`推进。Storage Cell 的透明使能直接使用论文
`WritePointer`，要求 bundled-data 环境在 `Reqin`转换前保证 `Datain/Tail`稳定。

## 5. Fig. 8 Read Interface Control

每个 CMR Buffer 含四个彼此独立的 Read Interface Control。每个接口包含一个五槽 one-hot `ReadCounter`、五个 `ReadControlUnit`、一个 `ReadRequestGenerator`、一个 `ReadPhaseSelector`和一个 `ReadAckGenerator`：

```text
Req[i]        = Latch(CellFull[i], En=ReadPointer[i])
CellEmpty[i]  = Latch(AckX, En=Req[i] XOR CellEmpty[i])
ReqX          = XOR(Req[0..4])
WrongPath     = !PathEnabledLocal && OR(PathEnabledOthers)
CancelEnable  = WrongPath && (Reqout XOR Ackin)
CorrectionPhase = Toggle(CancelEnable)
Reqout        = ReqX XOR CorrectionPhase
Completion    = XNOR(Reqout, Ackin)
AckX          = Toggle(Completion)
```

正确路径保持 `Reqout`并等待对应 OPM 的 `Ackin`；错误路径在首个推测请求后翻转 `CorrectionPhase`，使 `Reqout`产生第二次转换并自行取消。若四路 `PathEnabled`全为零，则不判定错误路径，请求保持阻塞并等待 RCU 给出合法路由。外部确认或内部取消都会使 `AckX`转换；Fig. 8 中 `ReqX`和 `AckX`共同接入 Read Counter，只有 `ReadHandshakeComplete = XNOR(ReqX, AckX)`的完成上升沿才推进 `ReadPointer`。同一个 `AckX`还使当前槽的 `CellEmpty`追平 `CellFull`。

四个读接口拥有独立的 `AckX`、`ReadPointer`和 `CellEmpty`状态。因此一个正确分支被下游反压时，其余分支仍可继续读取；只有四个读接口的对应 `CellEmpty`都追平，Fig. 7 的 Tail barrier 才确认 Tail。

五个 `Req`和 `CellEmpty`锁存器的复位相位均为 `[0,1,0,1,0]`。IV.C.4.b 写明复位时读指针选 tail cell（cell 4）；IV.C.2 要求刚写入的 header 立刻被所有读口推测广播，而 Fig. 8 只有 `ReadPointer` 指向的槽才透明。论文没有给出 4→0 的复位推进序列，因此四个 `ReadPointer` 与 `WritePointer` 一样从 cell0（`00001`）开始。这是有意的冷启动路径，不是漏画 Fig. 8。

`Dataout`由 `ReadPointer`直接选择五个 Storage Cell 中的一个。该 MUX 属于 bundled-data 路径，要求数据在请求和确认期间保持稳定。错误路径取消依赖 OPM normally-opaque 输入锁存器阻断短暂的推测请求；当前验证覆盖功能时序，不替代门级相对时序签核。

## 6. Fig. 5 IPM 与方向级、多 Lane Router

每个输入侧 `IPM`由一个 RCU和一个 CMR Buffer组成，不包含Mesh专用AMU：

```text
External Reqin/Datain -> RCU + CMRBuffer
CMRBuffer.Ackout      -> External Ackout + RCU.Ackout
RCU.PathEnabled       -> CMRBuffer.PathEnabled + OPM.PktPathEnable
CMRBuffer.Reqout/Dataout -> OPM.Reqin/Datain
OPM.Ackout            -> CMRBuffer.Ackin
OPM.TailPassed        -> RCU.TailPassed
```

其中 `Reqout/Ackout`是flit级两相握手，`PathEnabled/TailPassed`是packet生命周期
控制，不能互换。RCU与CMR Buffer始终只看到四个合法**方向**，物理lane位于
Read Interface之后。因此增加lane不会复制五槽Buffer，也不会把RCU改成物理
端口选择器。Router支持且只支持下列精确几何：

| 配置 | child lane/方向 | parent lane | 物理IPM/OPM | child OPM输入 | parent OPM输入 |
|---|---:|---:|---:|---:|---:|
| Thin | 1 | 1 | 5 | 4 | 4 |
| L1 | 1 | 2 | 6 | 5 | 4 |
| L2 | 2 | 4 | 12 | 10 | 8 |
| L3 | 4 | 8 | 24 | 20 | 16 |

稀疏连接删除的是整个ingress方向，而不是同编号lane：child ingress不能连接该
child方向的任何egress lane，parent ingress也不能连接任何parent egress lane。
所有Vec、OPM输入和仲裁树按真实lane数生成，不按最大方向补齐。

## 7. Verilog 资源归属

CMR 专属 Fig. 6–8 控制位于：

```text
ASYNC/CMR/Toggle.v
ASYNC/CMR/HeadPredictor.v
ASYNC/CMR/PhaseSelector.v
ASYNC/CMR/AddressRegisterUnit.v
ASYNC/CMR/InternalAckModule.v
ASYNC/CMR/OPMSelector.v
ASYNC/CMR/WriteControlUnit.v
ASYNC/CMR/WriteCounter.v
ASYNC/CMR/WriteAckGenerator.v
ASYNC/CMR/ReadControlUnit.v
ASYNC/CMR/ReadCounter.v
ASYNC/CMR/ReadRequestGenerator.v
ASYNC/CMR/ReadPhaseSelector.v
ASYNC/CMR/ReadAckGenerator.v
ASYNC/CMR/CMRMutexN.v
ASYNC/CMR/LanePhaseAdapter.v
ASYNC/CMR/PhaseResetDLatch.v
```

`Mutex4`、`Mutex2`、`DLatchBank` 和 `V2CloseEvent` 是共享原语，
不在 CMR 子目录创建同名副本，避免生成或综合时出现重复 module definition。

## 8. 本地冒烟测试

生成电路：

```powershell
sbt "runMain Router_Architecture.CMR.OPMMain"
sbt "runMain Router_Architecture.CMR.RCUMain 1"
sbt "runMain Router_Architecture.CMR.RCUMain 2"
sbt "runMain Router_Architecture.CMR.RCUMain 3"
sbt "runMain Router_Architecture.CMR.WriteControlUnitMain"
sbt "runMain Router_Architecture.CMR.WriteCounterMain"
sbt "runMain Router_Architecture.CMR.WriteInterfaceControlMain"
sbt "runMain Router_Architecture.CMR.ReadControlUnitMain"
sbt "runMain Router_Architecture.CMR.ReadCounterMain"
sbt "runMain Router_Architecture.CMR.ReadPhaseSelectorMain"
sbt "runMain Router_Architecture.CMR.ReadInterfaceControlMain 0"
sbt "runMain Router_Architecture.CMR.CMRBufferMain"
sbt "runMain Router_Architecture.CMR.IPMMain 1 4"
sbt "runMain Router_Architecture.CMR.CMRRouterMain 1"
sbt "runMain Router_Architecture.CMR.CMRRouterMain 2"
sbt "runMain Router_Architecture.CMR.CMRRouterMain 3"
sbt "runMain Router_Architecture.CMR.CMRRouterMain 1 1 2"
sbt "runMain Router_Architecture.CMR.CMRRouterMain 2 2 4"
sbt "runMain Router_Architecture.CMR.CMRRouterMain 3 4 8"
sbt "runMain NoC.CMR.CMRFatTreeMain"
```

运行本地 XSim：

```powershell
Set-Location sim/CMR
vivado -mode batch -source run_smoke.tcl
vivado -mode batch -source run_fat_tree_smoke.tcl
```

OPM smoke 覆盖四路独占、Head/Body/Tail、backpressure、Tail Detector、精确同时
竞争和等待者接管。RCU smoke 覆盖 Head 地址锁存、Body 保持、Tail 重开、单播、
多播、多路独立释放以及 `RouteSel` 内部 Ack 返回。TCL runner 会逐项解析
`TB_RESULT`。Write Interface smoke 覆盖五槽循环、上升/下降请求相位、无伪
转换和四读口 Tail barrier。Read Interface smoke 覆盖正确路径反压、错误路径
内部取消、`PathEnabled=0000`阻塞、CellFull/ReadPointer 两种到达次序和五槽
环回。完整 Buffer smoke 覆盖四个独立读口、多播分支独立推进以及 Tail 等待
全部读口完成。Router smoke 覆盖parent多播及慢分支反压、五个ingress的
no-U-turn、无复位连续packet路由状态清理，以及两个child IPM竞争parent OPM；
任何子测试没有明确 PASS 都会使整套测试失败。

## 9. RCU 相对时序约束

Fig. 6 的 `BundlingSignal` 必须晚于四路 `Mat` 全部稳定。这项关系由
`RouteComputationLogic` 里的显式 `DelayElement`（`RcuMatchedDelaySteps`，
默认 4 级 `DEL150`）放在 `Req_rc` 上表达，而不是 SDC。DC 必须 `dont_touch`
该链并核对 `DEL150` 个数。WritePointer / HS-02 不走这条路径。

## 10. Continuous Lane Selector与两相Phase Adapter

每个物理IPM的每个合法方向拥有一个精确宽度的`ContinuousLaneSelector`。对
requester `i`和候选lane `l`：

```text
OtherGrant[i][l]   = OR(OPMGrant[l][j]), j != i
LaneSelectable[i][l] = PathEnabled[i] && !OtherGrant[i][l]
LaneSelect[i]      = MutexN(LaneSelectable[i])
PPE[i][l]          = PathEnabled[i] && LaneSelect[i][l]
Commit[i][l]       = LaneSelect[i][l] && OPMGrant[l][i]
```

第二层OPM尚未决定时，第一层Mutex持续保存选择；若该lane最终授予其他输入，
`OtherGrant`使输家撤出并对剩余lane继续仲裁。赢家的Grant保持到TailPassed，所以
同一packet的Head/Body/Tail不会迁移。该方案没有全局采样沿、RR或LastOwner，
公平性来自连续Mutex的物理解析，不承诺有界等待。

不同物理lane可能保留不同的两相历史，因此不能直接对Ack做组合MUX。
`LanePhaseAdapter`在`Commit`前记录所选lane相对方向级channel的`PhaseOffset`，
只有`Commit` lane能够输出翻译后的Req并推进方向级Ack；其余lane令
`Reqout=Ackin`保持空闲。连续packet切换lane、上下相位和backpressure均由独立
smoke覆盖。

## 11. 精确宽度TAC Mutex

`CMRMutexN`只接受`1/2/4/5/8/10/16/20`。1路旁路，2路使用`Mutex2`，4路使用
已验证`Mutex4`；其余宽度使用CMR私有、最小接口的基线`CMRTAC2 + Mutex2`构造
接近均分且无虚拟叶子的树：
5=`2+3`，10=`5+5`，16=`8+8`，20=`10+10`。因此L1/L2/L3的child OPM分别
使用Mutex5/10/20，parent OPM分别使用Mutex4/8/16；lane侧分别使用
Mutex1/2、Mutex2/4、Mutex4/8。

这里的`CMRTAC2`对应论文的基础2×1 TAC，不是该论文Fig. 5提出的专用3×1或4×1
TAC。后两者包含扁平化的3/4路内部仲裁核、Enable Generator和对应的root/result
masking时序；当前递归2×1树不具备该路径均衡与impartiality改进。`arbo`和
`result_masked`仍保留为CMRTAC2内部实现节点，却不再暴露给CMR上层接口。共享
`ASYNC/TAC2.v`保持原接口，以免影响Ultra既有的诊断与SDF测试。

本轮新增论文Fig. 5(a)的`CMRTAC3`、`CMRTAC4`及扁平化`CMRFlatArbiter5/7/8`。
其中TAC3由Fig. 2三对两两竞争Mutex、ReqA deadlock detector、三路Enable
Generator和三路Muller-C grant join组成；TAC4由并行4路基础仲裁、四路Enable
Generator、一次ReqUp前传和四路grant join组成。`CMRMutexN`的宽度5、8、10已
切换为Flat5、Flat8、Flat10；Flat10采用`3+3+4`叶子和Fig. 2三路根仲裁。16、20
仍使用原精确宽度基线树，等待相应根仲裁结构的专门相对时序签核后再扁平化。

## 12. 三级 CMR Fat Tree

`NoC.CMR.CMRFatTree`实现一个完整64-core三级四叉树：16个L1 `1→2` Router，
以及两套 L2/L3 Fat 几何（`CMR_FAT_LANE_PROFILE`）：

- `1248`（默认）：4个L2 `2→4`、1个L3 `4→8`，8条top parent lane。
- `1222`：L2 与 L3 均为 `2→2`，2条top parent lane。`(2,2)` 的 OPM
  `SourceCount=8` 与 lane Mutex 宽 2 已在合法集中，不改 Mutex 网表。

`NoC.CMR.CMRFatTreeNoC64` 把该树暴露为固定模块名 `NoC_64nodes`，默认
bypass 层间 FIFO（与论文 DUT 一致）。L1-L2 与 L2-L3 仍逐物理 lane 一一
连接。原全1-lane CMR NoC16 继续作为兼容基线。

## 13. 当前验证与完成边界

本地RTL验证包括：所有精确Mutex宽度、两层竞争/迁移、Phase Adapter历史相位、
Thin Router完整回归、L1/L2/L3两个并发packet占用不同parent lane，以及两个
packet穿越L1/FIFO/L2/FIFO/L3到top的Head/Body/Tail动态测试。所有测试均要求
`TB_RESULT PASS`且稳定控制无X/Z。

AMU按四叉树路由结论有意省略，不存在占位接口。Thin 16 核全部矩形×源穷举下，
CMR no-U-turn `Mat` 对每个非源目的地恰好一条路径。本轮没有执行新增TAC树、lane
adapter或完整Fat Tree的DC/SDF；相对时序、门级hazard、Mutex物理公平性和PVT
签核仍属于下一阶段物理实现工作。

## 14. LanePhaseAdapter AckLatch 的标准单元时序保护

L2 的早期 strict-SDF `multilane_complex` 曾在
`InputPortModules_0.adapter_3.AckLatch` 报出 `D/E` 的 19 ps setup 违例。
该 latch 本身已经映射为带 `CDN` 的 `PhaseResetDLatch`，因此问题不是 reset
语义丢失，而是 Tail release 时 `SelectedAck ^ PhaseOffset` 的数据边沿距离
`Assigned`（latch enable）关闭边沿过近。

`LanePhaseAdapter.AckLatch` 不再包含专用数据 buffer。`SelectedAck ^
PhaseOffset` 与 `Assigned` 的 latch-close 关系由 DC/P&R 的 paired
relative-timing 约束闭合，不能靠 RTL 内的固定 buffer 掩盖。

远程 L2 (`2->4`) run `20260821_cmr_l2_ackdata_buf_sdf_01`：DC PASS，
`GTECH=0`、`SEQGEN=0`；严格 SDF `multilane_complex` PASS，注入完成、无
`IFNSDFA`/X-Z 失败，并且 `$setup/$hold` 违例计数均为零。该结论是当前
post-synthesis SDF（SYNTH-CLOSED）证据，尚不替代 post-layout/PVT 签核。

## 15. 同步 64 核对照（valid/ready，1.0 ns 冻结）

时钟版 `SyncCmrFatTree` 与异步树同几何、层间 bypass。Thin 全 `(1,1)` 一
条 top；Fat **1-2-2-2** 为 L1 `(1,2)`、L2/L3 `(2,2)`、两条 top。模块名都
是 `SyncNoC_64nodes`，网表目录分开。签核时钟首选 **1.0 ns**（SS ZeroWireload）。
Phase 2.5 把 isolated Head 压成 **1 拍**（组合 Grant / LaneSelect）。Fat 关键路径
为 L2 `destReg` → Mat → LaneSelect → OPM PE → L1 buffer。**1.0 ns 已合上**
（Thin NoC64 WNS 0.000667 ns，Fat 0.000033 ns），**不要改到 0.90 ns**。
论文网表 `20260901_cmr_sync_noc64_{thin,fat1222}_p50`。细节与 TAB/VCTM SDF：
[`docs/CMR_Sync64_Clock_Freeze.md`](../../../../../docs/CMR_Sync64_Clock_Freeze.md)。
