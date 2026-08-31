# Router Handshake Domains and Control/Data Paths

Last updated: 2026-07-24

本文档描述当前 RouterL1/Router 通用结构中各个异步握手域如何连接，以及控制链路、数据传输链路和组合逻辑如何共同决定一次 flit 的传输。当前时序数字以稳定基线 `P100_FIFO_ONLY` 为准。

相关源码：

- `src/main/scala/Router_Architecture/ipm/RouterIPM.scala`
- `src/main/scala/Router_Architecture/ipm/InputPortModule.scala`
- `src/main/scala/Router_Architecture/ipm/InputControlModule.scala`
- `src/main/scala/Router_Architecture/ipm/datapath/InputDatapathModule.scala`
- `src/main/scala/Router_Architecture/ipm/datapath/InputVcBuffer.scala`
- `src/main/scala/Router_Architecture/ipm/datapath/InputRequestGeneratorModule.scala`
- `src/main/scala/Router_Architecture/opm/RouterOPM.scala`
- `src/main/scala/Router_Architecture/common/async/*.scala`

## 1. 总体视图

Router 内部不是一条同步流水线，而是一组通过 toggle `req/ack` 相连的异步握手域。每条 `HS_Packet` 通道包含：

```text
forward direction: data + req
backward direction: ack
empty condition:    req == ack
full condition:     req != ack
```

一个 flit 从输入到输出大致经过：

```text
external input
  -> VC demux fork
  -> per-VC FIFO stage
  -> VC masked arbiter
  -> reqGen multicast fork
  -> OPM output arbiter
  -> external output
```

并行存在一条控制链路：

```text
selected VC flit / valid / context
  -> PacketRouteSelector
  -> LaneReservation
  -> MulticastRequestMask
  -> InputEligibility
  -> reqGen.destMask / reqGen.canLaunch
```

数据链路负责搬运 flit；控制链路不直接搬运 flit，而是决定下一个握手域是否可以发起，以及向哪些输出边发起。

## 2. 当前主要握手域与延时配置

当前稳定 profile 是 `P100_FIFO_ONLY`。ASIC 下每个非零 delay role 使用 1 级 DEL cell，当前配置如下：

| 握手域 | RTL 实体 | Delay role | 当前 cell | 典型 SDF delay | 当前组合锥 |
|--------|----------|------------|-----------|---------------:|-----------:|
| VC demux launch | `InputVcBuffer.demux` / `AsyncForkRequestBlock` | `demux_launch` | `1x DEL150` | `~0.25ns` | `0.220ns` |
| FIFO fire | `InputBuffer` / `AsyncStage` / `ACG.fire_o` | `fifo_dfire` | `1x DEL100` | `~0.17ns` | `0.120ns` |
| VC select fire | `AsyncMaskedArbiter` | `vc_arbiter_dfire` | `1x DEL150` | `~0.25ns` | `0.340ns` |
| reqGen launch | `InputRequestGeneratorModule.fork` / `AsyncForkRequestBlock` | `reqgen_launch` | `1x DEL150` | `~0.25ns` | `0.980ns` |
| fork complete | `AsyncForkAckJoinBlock` | `fork_complete` | `1x DEL150` | `~0.25ns` | 非当前 forward 热点 |
| OPM arbiter fire | `RouterOutputRequestSelectorModule` / `AsyncArbiter` | `opm_arbiter_dfire` | `1x DEL150` | `~0.25ns` | `0.170ns` |
| context update | `PacketContextModule` | `context_state` | `1x DEL150` | `~0.25ns` | 非当前 forward 热点 |
| priority update | `InputControlModule.priPulse` | `priority_pulse` | `1x DEL150` | `~0.25ns` | 非当前 forward 热点 |

说明：

- FIFO `Dfire` 是目前唯一降到 `DEL100` 后通过 RouterL1 SDF 的主路径握手域。
- OPM/context/priority 等更激进地降到 `DEL100` 的 profile 已经失败，表现为 RouterL1 SDF delivered `8/9`。
- `reqGen launch` 的组合锥远大于 DEL cell 本身，是当前首要优化对象。

## 3. 数据传输链路

### 3.1 输入到 VC demux

外部输入端口 `inPort(i)` 进入 `InputPortModule(i)`，然后进入 `InputDatapathModule` 中的 `InputVcBuffer`。

```text
external in HS_Packet
  data/req -> InputVcBuffer.demux
  ack      <- InputVcBuffer.demux
```

`InputVcBuffer` 使用一个 `AsyncFork(vcCount)` 作为 VC demux，但它每次只选择一个 VC：

```text
incoming head:
  choose first free VC

incoming body/tail:
  choose VC whose rxId matches packet id
```

关键控制：

- `routeValid` 表示当前输入 flit 能找到目标 VC。
- `demux.destMask(v) := routeValid && routeVc == v`
- `demux.canLaunch := routeValid`
- demux launch 成功后，`rxActive/rxId` 在 `demux.launch_clock` 上更新。

这一级的输出是每个 VC 的 `InputBuffer`。

### 3.2 VC FIFO stage

每个 VC 后面接 `InputBuffer`，当前本质是 `AsyncFifo(depth)` 中的一层或多层 `AsyncStage`。

```text
demux.out(v)
  -> InputBuffer(v)
  -> selector.in(v)
```

`AsyncStage` 的控制由 `ACG(In=1, Out=1)` 产生：

```text
full  = in.req ^ in.ack
empty = out.req == out.ack
fire  = Delay(full && empty)
```

fire 后：

- `in.ack` 跟随 `in.req`，表示输入 token 被接收。
- `out.req` 翻转，表示输出 token 可见。
- `data` 在 `fire_o` 上寄存到下一级。

当前该域使用 `fifo_dfire = DEL100`。

### 3.3 VC masked arbiter

一个 input port 内部可能有多个 VC ready，`AsyncMaskedArbiter` 选择一个 VC 送往 reqGen。

```text
VC buffer out(0..vcCount-1)
  -> AsyncMaskedArbiter
  -> requestGen.in
```

`InputPortModule` 生成 `vcAllow(v)`：

- body/tail 优先。
- 如果有 active context 或 body ready，新 head 不能抢占。
- head 只能在没有 body ready 且没有 active context 时选择空闲 VC。

`AsyncMaskedArbiter` 内部：

```text
fullVec(v)      = vc.req ^ ackReg(v)
allowedFull(v) = fullVec(v) && vcAllow(v)
chosen         = PriorityEncoder(allowedFull)
fire           = Delay(hasAllowed && outEmpty)
```

fire 后只 acknowledge 被选中的 VC，并把选中 flit 写入 `AsyncOutputBuffer`。这一级输出的 flit 是后续 `InputControlModule` 看到的 `inBits/inValid/isHead`。

### 3.4 reqGen multicast fork

`InputRequestGeneratorModule` 是 input 侧真正向 OPM 发起内部 sparse edge 请求的地方：

```text
requestGen.in
  -> AsyncFork(forkWidth)
  -> forkOutputs(local edge)
  -> RouterIPM.toOpm(global edge)
```

控制输入来自 `InputControlModule`：

- `destMask(localEdge)`：本 flit 要发往哪些合法内部边。
- `canLaunch`：这些目标当前是否全部满足发射资格。

`AsyncForkRequestBlock` 当前逻辑：

```text
inputFull  = inReq ^ inAck
forkBusy   = launchedReq ^ inAck
launchCond = inputFull && canLaunch && !forkBusy
launch     = Delay(launchCond)
```

在 `launch_clock` 上：

- `launchedReq := inReq`
- 若 `destMask(j)` 为真且当前 input req 尚未被 launch，则翻转 `outReq(j)`。

`AsyncForkAckJoinBlock` 等待所有 selected branch 的 `outReq/outAck` 完成后，再更新 `inAck`，表示这个 flit 对所有 multicast branch 都已完成。

这一级是当前 RouterL1 的最大组合热点，因为 `canLaunch/destMask` 来自很长的输入控制组合锥。

### 3.5 OPM output arbiter

`RouterOPM` 对每个物理 output lane 实例化一个 `RouterOutputPortModule`：

```text
fromIpm(edge ids targeting output o)
  -> RouterOutputRequestSelectorModule(o)
  -> external output o
```

每个 output 只连接 `edgesByOutput(o)` 中合法的 sparse input edge，不构造完整 dense crossbar。

`RouterOutputRequestSelectorModule` 内部使用 `AsyncArbiter`：

```text
internal edge[k].req/data
  -> Mutex tree / request selector
  -> output.req/data

internal edge[k].ack <- selected edge complete
```

fire 后：

- 选中的 input edge 被 acknowledge。
- 选中 flit 被写入 output buffer。
- `chosen/chosenData/fireClock` 输出给 `RouterOutputPathStateModule`。

### 3.6 OPM holder 状态

`RouterOutputPathStateModule` 在 output fire 时更新 `holder`：

```text
if tail:
  holder := none
else if head:
  holder := chosen input
```

`holder(o)` 回传到 IPM，表示 output `o` 当前被哪个 input 的 multi-flit packet 占用。这个反馈不是 `HS_Packet`，但它直接参与下一次 flit 的资格判断。

`opmOutEmpty(o)` 由 output channel 的 `Req == Ack` 产生，表示外部 output lane 当前是否空闲。

## 4. 控制链路

`InputControlModule` 是控制链的中心，它对所有 input port 统一计算：

```text
inBits / inValid / isHead / stored context
  -> routeSelector.currentDestVec
  -> laneReservation.headSelLane/headAllocOk
  -> requestMask.destMask
  -> eligibility.destMask/canLaunch
```

### 4.1 PacketRouteSelector

输入：

- `inBits(i)`：当前 VC selector 输出 flit。
- `inValid(i)`：当前 input port 是否有可见 flit。
- `isHead(i)`：是否 head flit。
- `storedDir(i)`：body/tail 的历史方向 context。

输出：

- `currentDestVec(i)(dir)`

规则：

- head flit 调用 `computeHeadRouting(packet, inValid, ingressDir)`。
- body/tail 不重新 route，直接复用 `storedDir`。

这保证多 flit packet 的 body/tail 路径跟 head 一致。

### 4.2 LaneReservation

输入：

- `currentDestVec`
- `inValid/isHead`
- `opmHolder`
- `priorityBase`

输出：

- `headSelLane(i)(dir)`
- `headAllocOk(i)`

功能：

- 对每个方向统计空闲 lane：`holder(outIdx) == none`。
- 按 `priorityBase` 形成 round-robin 扫描顺序。
- 同一方向多个 head 同时竞争时，第 `r` 个 winner 拿第 `r` 条空闲 lane。
- multicast head 必须所有目标方向都分配成功，`headAllocOk` 才为真。

这一级解决“head 应该走哪个 output lane”的组合选择。它只处理 head；body/tail 继续使用 context 中保存的 lane/mask。

### 4.3 MulticastRequestMask

输入：

- `currentDestVec`
- `headSelLane`
- `headAllocOk`
- `storedMask`
- `inValid/isHead`

输出：

- `requestMask(i)(outIdx)`

规则：

- head：把方向和 lane 选择转换成物理 output mask。
- body/tail：复用 `storedMask`。
- 无有效请求或 head 分配失败：输出全 0 mask。

这一级产生的是 dense physical output mask。`RouterIPM` 后续会把它压缩成本 input 对应的 local sparse edge mask：

```text
inputPorts(i).destMask(localIdx) :=
  control.destMask(i)(config.edgeOutput(edgeId))
```

### 4.4 InputEligibility

输入：

- `requestMask`
- `headWantedMask`
- `storedMask`
- `opmHolder`
- `opmOutEmpty`
- `inValid/isHead`

输出：

- `destMask`
- `canLaunch`

head flit 的条件：

```text
inValid
&& isHead
&& requestMask has at least one bit
&& every requested output is:
     holderFree
  && outEmpty
  && not blocked by higher-priority head or another holder
```

body/tail flit 的条件：

```text
inValid
&& !isHead
&& requestMask has at least one bit
&& every requested output is:
     held by this input
  && outEmpty
```

当 `canLaunch(i)` 为真时，`destMask(i)` 等于 gated `requestMask(i)`；否则输出全 0。`canLaunch` 直接连接到 reqGen fork 的 `AsyncForkRequestBlock.launchCond`。

## 5. 控制信号如何跨握手域连接

下面列出最关键的跨域控制信号。它们不是独立 `req/ack` 通道，但会改变某个握手域是否能 fire。

| 信号 | 产生方 | 使用方 | 作用 |
|------|--------|--------|------|
| `vcAllow(v)` | `InputPortModule` context/VC ready 逻辑 | `AsyncMaskedArbiter` | 决定哪个 VC token 可以被 selector ack |
| `inBits/inValid/isHead` | reqGen input channel，即 VC selector 输出 | `InputControlModule` | 作为 route/lane/mask/eligibility 的组合输入 |
| `storedDir/storedLane/storedMask` | `PacketContextModule` | `InputControlModule` | body/tail 复用 head 的路由结果 |
| `nextDir/nextLane/nextMask` | `InputControlModule` | `PacketContextModule` | head launch 时写入 context |
| `destMask` | `InputEligibility` | reqGen `AsyncFork` | 决定哪些 internal edge 翻转 req |
| `canLaunch` | `InputEligibility` | reqGen `AsyncForkRequestBlock` | gating launchCond |
| `headLaunch` | reqGen fork launch pulse | `InputControlModule.priorityBase` | 更新 input 侧 head RR 优先级 |
| `packetLaunch/packetComplete` | reqGen fork | `PacketContextModule` | head 写 context，tail/complete 清 context |
| `opmHolder` | OPM path state | `LaneReservation/InputEligibility` | 判断 output 是否被 packet 占用 |
| `opmOutEmpty` | external output `Req == Ack` | `InputEligibility` | 判断 output channel 是否可接收下一 flit |
| `chosen/chosenData/fireClock` | OPM arbiter | OPM path state | 更新 holder |

需要注意：`destMask/canLaunch` 是当前 reqGen launch 组合锥的末端输入。STA 结果显示，最终 DDC 中从 selector flit register 到 `io_destMask/io_canLaunch` 的路径已经接近整个 `reqgen_launch` cone，因此优化重点应放在 `InputControlModule` 内部的 mask 生成，而不是只改 reqGen fork 末端。

## 6. 单个 flit 的事件顺序

以 input 0 到 output 4 的 head flit 为例：

```text
1. external input toggles in.req with head flit data.
2. VC demux sees routeValid and toggles exactly one VC branch req.
3. selected VC FIFO stage fires and stores flit.
4. VC masked arbiter sees allowedFull, chooses one VC, fires to reqGen input.
5. InputControlModule sees reqGen input flit:
   route -> lane reservation -> request mask -> eligibility.
6. reqGen fork sees:
   inputFull && canLaunch && !forkBusy
   then launch DelayElement fires and toggles selected internal edge reqs.
7. OPM output arbiter sees one or more internal edge reqs, arbitrates, and
   toggles external output req with selected flit data.
8. external output ack returns.
9. OPM acknowledges selected internal edge.
10. reqGen ack join observes all selected branches complete and acknowledges
    the reqGen input.
11. context and holder update on their corresponding async clocks.
```

For multicast, step 6 toggles multiple internal edge reqs atomically, and step
10 waits until all selected branches have completed before acknowledging the
input flit.

## 7. 当前优化含义

当前 STA 与 SDF 结果说明：

- FIFO 域已经可以安全使用 `DEL100`。
- OPM 域组合锥较短，但直接降低到 `DEL100` 的 profile 曾失败，说明需要谨慎处理 pulse width 和反馈状态，而不是只看单条 STA。
- VC arbiter 组合锥约 `0.340ns`，是次级热点。
- reqGen launch 组合锥约 `0.980ns`，其中 `selector flit -> io_destMask` 已经约 `0.940ns`。

因此下一轮 RTL 优化优先级：

1. `InputControlModule` 内 route/dest-mask/lane-mask 生成。
2. `LaneReservation` 的 fan-in 和 prefix/rank 结构。
3. `InputEligibility` 中 head/body-tail gating 与 `otherOccupiesOutput` 展开。
4. 只有在组合锥下降后，才重新评估 `reqgen_launch` 是否能使用更小 Delay cell。

