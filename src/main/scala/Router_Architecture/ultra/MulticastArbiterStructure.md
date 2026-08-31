可以敲定为“混合式异步事务 Arbiter”：

- `DLatch/C-element`：捕获并保持 Head 请求、控制 round 状态。
- `Mutex5`：选择本轮 anchor。
- 异步 decision chain：按照 anchor 的旋转顺序逐项判断其余候选，构造多个不相交 winner。
- transaction latch：冻结本轮完整提交内容。
- `ACG fire`：只负责一次性原子提交已经冻结的 transaction。
- 旧 `AtomicMulticastAdmission` 保留，新模块建议命名为 `AtomicMulticastArbiterV2`。

这既保留“不相交集合同一轮平行准入”，也解决 B 在 fire setup/hold 窗口内临时加入的问题。

## 一、总体结构

```text
                         ┌─────────────────────────┐
RS ──► HeadCaptureCell ─►│ packetPresent + mask   │
                         └────────────┬────────────┘
                                      │ admissionRequest
TailJoin ──► releaseRequest ──────────┤
                                      ▼
                               ┌────────────┐
                               │   Mutex5   │
                               │ select     │
                               │ anchor     │
                               └─────┬──────┘
                                     │
                anchor=release ──────┤
                                     │ anchor=admission
                                     ▼
                         ┌──────────────────────┐
                         │ Rotated Round Builder│
                         │ anchor,I+1,...,I+4   │
                         │ conflict comparison  │
                         └──────────┬───────────┘
                                    │ buildDone
                                    ▼
                         ┌──────────────────────┐
                         │ Transaction DLatches │
                         │ kind/winner/masks    │
                         └──────────┬───────────┘
                                    │ txValid
                                    ▼
                               ┌─────────┐
                               │   ACG   │
                               │  fire   │
                               └────┬────┘
                                    ▼
                        packetActive / outputOwner
```

关键边界是：

```text
实时请求只能修改 HeadCapture/packetPresent
冻结后不能修改 transaction latch
fire 只能读取 transaction latch.Q
```

因此 fire 前到达的 B 有且只有两种合法结果：

- 被 decision cell 判定为本轮成员，完整进入本轮；
- 被判定为下一轮成员，保持 pending。

不会再出现：

```text
packetActive[B]=1
packetMask[B]=0
owner[B]=none
```

这种撕裂状态。

---

## 二、Head 请求状态

每个输入使用一个 `HeadCaptureCell`，状态为：

```text
P[i]       packetPresent，表示一个完整 packet 已进入控制链
M[i][o]    该 packet 的目标输出集合
A[i]       packetActive，表示 reservation 已完成
```

这里不再使用 `headEpoch/admittedEpoch`。

### Head 捕获

```text
captureOpen[i] = !P[i]

maskLatch.En = reset || captureOpen[i]
maskLatch.D  = reset ? 0 : localMask[i]
```

`localHead` 必须经过与 `localMask` 匹配的控制延时，然后设置：

```text
P[i] := 1
```

一旦 `P[i]=1`：

- mask latch 关闭；
- `M[i]` 保持整个 packet 生命周期；
- 后续 Body/Tail 不会改变它；
- admission 后 `P[i]`仍保持为 1；
- Tail release 完成后才清 `P[i]`。

因此：

```text
admissionRequest[i] =
    P[i] && !A[i] && maskNonzero[i] && allTargetsFree[i]

releaseRequest[i] =
    P[i] && A[i] && allTailPassed[i]
```

同一个输入不可能同时产生 admission 和 release request。

### 输入局部状态图

```text
          Head mask captured
 EMPTY ─────────────────────► PENDING
   ▲                            │
   │                            │ admission commit
   │                            ▼
   └──────────────────────── ACTIVE
          release commit
```

| 状态 | `P` | `A` | 含义 |
|---|---:|---:|---|
| `EMPTY` | 0 | 0 | 可以捕获新 Head |
| `PENDING` | 1 | 0 | Head 已捕获，等待 reservation |
| `ACTIVE` | 1 | 1 | Packet 正在传输 |
| release 后 | 0 | 0 | mask latch 重新打开 |

这个协议也使 `headEpoch` 不再必要：新 Head 只有在前一个 packet release、`P/A` 清零后才能成为新请求。

---

## 三、Mutex5 的职责

Mutex5 只选择本轮最高优先级 anchor，不负责决定全部 winner：

```text
arbRequest[i] = admissionRequest[i] || releaseRequest[i]
```

因为同一个输入的两种 request 互斥，所以 Grant 后的事务类型可以稳定判定：

```text
anchorIsRelease = releaseRequest[anchor]
anchorIsAdmit   = admissionRequest[anchor]
```

### Release anchor

Release 一次处理一个 packet：

```text
txKind   = RELEASE
txInput  = anchor
txMask   = M[anchor]
```

不经过 greedy builder，直接冻结 transaction。

### Admission anchor

Admission anchor 初始化本轮：

```text
winnerSet_0   = oneHot(anchor)
acceptedMask_0 = M[anchor]
```

随后按旋转顺序检查其余四个输入。

例如 anchor 为 I2：

```text
I2 → I3 → I4 → I0 → I1
```

---

## 四、异步 Round Builder

每个候选检查阶段都必须是一个真正的异步 decision cell，而不能是当前实时组合 `winnerByStart`。

对于第 `r` 个候选：

```text
candidate = (anchor + r) mod 5
```

计算：

```text
conflict =
    (M[candidate] & acceptedMask[r]).orR

canJoin =
    admissionRequest[candidate] && !conflict
```

如果候选在本阶段关闭前到达：

```text
take[r] = 1
```

则：

```text
winnerSet[r+1] =
    winnerSet[r] | oneHot(candidate)

acceptedMask[r+1] =
    acceptedMask[r] | M[candidate]
```

否则：

```text
winnerSet[r+1]   = winnerSet[r]
acceptedMask[r+1] = acceptedMask[r]
```

### 后到请求的边界处理

每个 decision cell 使用一个小型 `Mutex2`，仲裁：

```text
candidate request
        vs
stage close token
```

结果：

| Mutex2 结果 | 含义 |
|---|---|
| candidate 胜 | 候选属于本轮，再做集合冲突检查 |
| close token 胜 | 候选属于下一轮，保持 `P=1,A=0` |
| 几乎同时到达 | Mutex 内部解析，结果可以是任一侧，但不会污染 transaction |

这就是消除 setup/hold 问题的核心。

异步输入的“本轮还是下一轮”在物理上不可能永远确定，但不确定性被限制在 Mutex 中。无论 Mutex 输出哪一种结果，系统状态都合法。

### 多 winner 保证

例如：

```text
I2 anchor：{O0}
I3：       {O1,O2}
I4：       {O2,O3}
I0：       {O4}
```

判断过程：

```text
accepted = {O0}, winner={I2}

I3 无冲突：
accepted = {O0,O1,O2}, winner={I2,I3}

I4 与 I3 冲突：
保持不变，I4 留待下一轮

I0 无冲突：
accepted = {O0,O1,O2,O4}, winner={I2,I3,I0}
```

本轮 transaction 同时准入 I2、I3、I0。它们的 packet 随后完全并行传输。

---

## 五、全局状态机

全局控制状态固定为：

```text
IDLE
SELECT
BUILD
ARMED
RETURN
```

`ACTIVE` 不是全局状态，而是每个输入自己的 `A[i]` 状态，因此多个 packet 可以同时 active。

### 状态转移图

```text
                    有 admission/release request
          ┌────────────────────────────────────────┐
          │                                        ▼
      ┌──────┐                                 ┌────────┐
      │ IDLE │                                 │ SELECT │
      └──▲───┘                                 └───┬────┘
         │                                         │ Mutex Grant
         │                         ┌───────────────┴───────────────┐
         │                         │                               │
         │                  release anchor                  admit anchor
         │                         │                               │
         │                         ▼                               ▼
         │                    freeze tx                       ┌────────┐
         │                         │                          │ BUILD  │
         │                         │                          └───┬────┘
         │                         │                         buildDone
         │                         └───────────────┬───────────────┘
         │                                         ▼
         │                                    ┌────────┐
         │                                    │ ARMED  │
         │                                    └───┬────┘
         │                                       fire↑
         │                                         ▼
         │                                    ┌────────┐
         └────────────────────────────────────│ RETURN │
                      ACG empty, chain reset  └────────┘
```

### 状态转移表

| 当前状态 | 条件 | 动作 | 下一状态 |
|---|---|---|---|
| `IDLE` | `arbRequest.orR=0` | 保持 capture 开放 | `IDLE` |
| `IDLE` | `arbRequest.orR=1` | 允许 Mutex5 解析 | `SELECT` |
| `SELECT` | 无稳定 Grant | 保持 | `SELECT` |
| `SELECT` | Release Grant | 锁存 input/mask/kind | `ARMED` |
| `SELECT` | Admission Grant | anchor 加入 winnerSet | `BUILD` |
| `BUILD` | decision chain 未完成 | 逐个候选比较 | `BUILD` |
| `BUILD` | `buildDone=1` | 关闭 transaction latch | `ARMED` |
| `ARMED` | transaction 尚未满足 RTM | 保持全部 transaction Q | `ARMED` |
| `ARMED` | `fire_o↑` | 原子提交 reservation/release | `RETURN` |
| `RETURN` | ACG 尚未 empty | 保持 transaction 不变 | `RETURN` |
| `RETURN` | ACG empty、Grant 清零、builder reset | 重新开放下一轮 | `IDLE` |

---

## 六、状态转移方程

使用 one-hot phase 状态：

```text
Q_IDLE
Q_SELECT
Q_BUILD
Q_ARMED
Q_RETURN
```

定义：

```text
requestAny     = OR(arbRequest)
grantValid     = OR(anchorGrant)
grantRelease   = grantValid && releaseRequest[anchor]
grantAdmission = grantValid && admissionRequest[anchor]
buildDone      = decisionChainDone
fireEvent      = posedge(fire_o)

returnDone =
    acgEmpty
    && !txValid
    && !anchorGrant.orR
    && builderIdle
```

状态方程为：

```text
Q_IDLE+ =
    (Q_IDLE && !requestAny)
    || (Q_RETURN && returnDone)

Q_SELECT+ =
    (Q_SELECT && !grantRelease && !grantAdmission)
    || (Q_IDLE && requestAny)

Q_BUILD+ =
    (Q_BUILD && !buildDone)
    || (Q_SELECT && grantAdmission)

Q_ARMED+ =
    (Q_ARMED && !fireEvent)
    || (Q_SELECT && grantRelease)
    || (Q_BUILD && buildDone)

Q_RETURN+ =
    (Q_RETURN && !returnDone)
    || (Q_ARMED && fireEvent)
```

这些不是建议综合成普通组合 `always @(*)` 自反馈，而是状态规范。实际电路使用 C-element/反馈状态单元实现共识保持，并保证一次仅有一个 phase 有效。

初态：

```text
Q_IDLE=1
其他=0
```

---

## 七、Transaction 格式

冻结内容必须完整，不能只冻结 winner：

```text
txKind                   1 bit
txWinner[4:0]            5 bits
txMask[5][4:0]          25 bits
txOwnerWrite[5][2:0]    15 bits
txReleaseInput[4:0]      5 bits
```

也可以省略可由稳定字段组合得到的内容，但 `fire` 前所有 Atomic D 输入必须只依赖 transaction latch Q。

禁止：

```text
fire state D ← live RS
fire state D ← live capturedMask
fire state D ← live eligible
fire state D ← live winner
fire state D ← live allTailPassed
```

---

## 八、fire 时的原子状态更新

### Admission transaction

```text
packetActive[i]+ =
    packetActive[i] || txWinner[i]

outputOwner[o]+ =
    if txWinner 中某输入的 txMask 包含 o
    then corresponding input
    else outputOwner[o]
```

不相交约束保证每个 output 最多有一个 winner。

`M[i]` 已经在 HeadCaptureCell 中保持，不需要再复制一份实时 mask 寄存器。对外：

```text
packetMask[i] =
    packetActive[i] ? M[i] : 0
```

### Release transaction

```text
packetActive[releasedInput]+ = 0

for o in txMask[releasedInput]:
    outputOwner[o]+ = none
```

随后清除：

```text
P[releasedInput] = 0
M[releasedInput] = 0
```

`outputTailBusy` 继续充当旧 TP 清零前的再分配屏障。

---

## 九、ACG 的唯一职责

新设计中 ACG 不再承担“等待实时组合 winner 稳定”的模糊职责。

它只做：

```text
tx latch 已关闭
        │
        ▼
matched delay / RTM
        │
        ▼
fire_o
        │
        ▼
原子更新 state bank
```

时序要求明确为：

```text
T(transaction latch Q → state D)
+ setup
+ 5% RTM
≤
T(txValid → fire_o)
```

因为 `transaction latch Q` 在 `ARMED` 全程不变，后续 Head 到达不会再影响这个约束。

---

## 十、最终敲定

新 Arbiter 采用：

```text
混合式实现
= Head/Mask DLatch
+ pending/phase C-state
+ Mutex5 anchor
+ 4级异步 decision chain
+ packed transaction DLatch
+ 单一 ACG fire commit domain
```

保留的旧思路：

- 完整多播集合准入；
- Mutex5 决定最高优先级；
- 按 anchor 的旋转顺序比较；
- 不冲突候选同一 transaction 获准；
- 冲突候选保持 pending；
- TailJoin 后原子释放完整集合。

删除的旧思路：

- `localHead` 直接作为普通 DFF clock；
- `headEpoch/admittedEpoch` 补丁式跨域保护；
- 实时 `winner/capturedMask` 直接连接 fire 域 D；
- Start 已经建立后仍允许新请求改变本轮 transaction；
- 多组独立寄存器依靠同一个 fire“碰巧”保持一致。

这个架构满足你提出的三个目标：

1. 不相交多播集合可以在同一轮获准并平行传输。
2. 冲突集合仍以 Mutex5 anchor 为起点按旋转顺序决定。
3. 后到请求在 decision-cell Mutex 边界被归入本轮或下一轮，不再落入最终状态 DFF 的 setup/hold 窗口。

## 异步 Builder 补充说明

decision cell 建议做成一个“小型异步握手级”，不使用 DFF 时钟采样。它由以下元件组成：

```text
1 × Mutex2                 决定 candidate 与 close token 谁先到
1 × candidateSeen 状态单元  记录 candidate 是否属于本轮
1 × DLatchBank             保存更新后的 acceptedMask/winnerSet
组合 conflict logic         完整集合重叠判断
1 × matched DelayElement    覆盖 conflict + mask update + latch setup
C-element/握手反馈          推进 close token 并完成返回
```

> close token 在各候选位置依次“关门”；candidate request 与关门事件通过 Mutex2 决定谁先发生。

## 1. 什么是 candidate request？

`candidate request` 不是原始 `RS`，也不是 ReqGenerator 的 `Req`。

它表示：

> 某个已经完整捕获 Head mask、尚未 active、当前目标输出均可用的输入，请求加入正在构造的 admission round。

定义为：

```text
packetPresent[i] = P[i]
packetActive[i]  = A[i]
capturedMask[i]  = M[i]

allTargetsFree[i] =
    AND_o(!M[i][o] || outputFree[o])

admissionRequest[i] =
    P[i]
    && !A[i]
    && M[i].orR
    && allTargetsFree[i]
```

Builder 选择某个候选位置时：

```text
candidate = (anchor + rank) mod 5
```

该 stage 的 candidate request 就是：

```text
candidateRequest[rank] =
    admissionRequest[candidate]
    && stageOpen[rank]
```

它是保持型请求，不是窄脉冲：

- Head 到达后 `P[i]` 保持；
- mask latch 保持 `M[i]`；
- 在获准或 release 前不会消失；
- 因而 Mutex2 有充分时间解析竞争。

### candidate request 与 pending 的区别

```text
P[i] / pending
```

是跨 round 保持的 packet 请求状态。

```text
candidateRequest
```

是该 pending packet 在某一轮、某一个 decision stage 上发出的临时“加入本轮”请求。

如果 candidate 被拒绝或来晚了：

- `P[i]` 不清除；
- `A[i]` 仍为 0；
- 下一轮会重新产生 candidate request。

如果 candidate 被本轮选中：

- 仍暂时保持 `P[i]=1,A[i]=0`；
- 等最终 transaction 的 `fire`；
- fire 后才原子设置 `A[i]=1`。

---

## 2. 什么是 close token？

`close token` 是 Builder 内部传播的“本轮成员资格关闭事件”。

它不是时钟，也不是绝对时间延迟。它表达：

> 当前 acceptedMask 已经从上一级稳定传来，现在必须确定这个候选是否属于本轮，然后关闭这个 stage 并继续检查下一个候选。

anchor 确定以后，初始化：

```text
winnerSet_0    = oneHot(anchor)
acceptedMask_0 = M[anchor]
```

随后产生第一个 close token：

```text
anchor initialized
        │
        ▼
closeToken[1]
        │
        ▼
检查 anchor+1
        │
        ▼
closeToken[2]
        │
        ▼
检查 anchor+2
        │
       ...
        ▼
closeToken[4]
        │
        ▼
buildDone
```

close token 经过每个 stage 时，都要和该 stage 的 candidate request 做一次 Mutex2 判定。

---

# Decision cell 的结构

以一个 candidate 为例：

```text
candidateRequest ─────────────┐
                              │
                              ▼
                          ┌────────┐
closeTokenIn.Req ────────►│ Mutex2 │
                          └──┬───┬─┘
                  candGrant  │   │ closeGrant
                             │   │
              ┌──────────────┘   └──────────────┐
              ▼                                 ▼
      candidateSeen := 1                candidateSeen := 0
              │                                 │
              └──────────────┬──────────────────┘
                             ▼
                    conflict calculation
                             │
                             ▼
                  acceptedMask/winner D
                             │
                       matched delay
                             │
                             ▼
                    close output latch
                             │
                             ▼
                    closeTokenOut.Req
```

输入数据：

```text
acceptedMaskIn[4:0]
winnerSetIn[4:0]
candidateMask[4:0]
candidateID
```

输出数据：

```text
acceptedMaskOut[4:0]
winnerSetOut[4:0]
```

---

# 3. Candidate 先到时怎样处理？

假设 candidate request 已经为高，close token 随后到达。

```text
candidateRequest ↑
        │
        ▼
Mutex2 candidate 侧获胜
        │
        ▼
candidateSeen := 1
candidateAck  := 1
        │
        ▼
candidateRequest 退出 Mutex 请求
        │
        ▼
close token 随后取得 close grant
```

然后进行集合判断：

```text
conflict =
    (candidateMask & acceptedMaskIn).orR

take =
    candidateSeen && !conflict
```

如果无冲突：

```text
acceptedMaskOut =
    acceptedMaskIn | candidateMask

winnerSetOut =
    winnerSetIn | oneHot(candidate)
```

如果有冲突：

```text
acceptedMaskOut = acceptedMaskIn
winnerSetOut    = winnerSetIn
```

即使发生冲突，candidate 也只是“本轮没有选中”：

```text
P[candidate] = 1
A[candidate] = 0
```

它会留到下一轮继续竞争。

---

# 4. Close token 先到时怎样处理？

如果 close token 到达时 candidate 尚未提出请求：

```text
closeTokenIn.Req ↑
        │
        ▼
Mutex2 close 侧获胜
        │
        ▼
stageOpen := 0
candidateSeen := 0
```

该 stage 直接旁路：

```text
acceptedMaskOut = acceptedMaskIn
winnerSetOut    = winnerSetIn
```

此后，即使 candidate 在 Builder 尚未整体完成时到达：

```text
candidateRequest 不再进入这个已关闭的 stage
```

但它的 `P[i]` 会被 HeadCaptureCell 保存，因此它属于下一轮。

这正是旧设计缺失的行为：

```text
旧设计：
B 在任意时刻到达，都可能改变实时 winner

新设计：
某个 stage 关闭后，B 只能等待下一轮
```

---

# 5. 两者几乎同时到达怎么办？

这是 Mutex2 的核心作用。

```text
candidateRequest
                  → Mutex2 → candidateGrant 或 closeGrant
closeToken
```

如果二者非常接近：

- Mutex2 可能进入短暂亚稳态；
- 最终只会解析成一侧 Grant；
- 不允许两个 Grant 同时稳定有效；
- 亚稳态不会直接进入 owner/packetActive DFF。

最后结果可能是：

```text
candidate 属于本轮
```

也可能是：

```text
candidate 属于下一轮
```

两者在功能上都正确。

系统不要求在无限精确的时间边界上确定 B 必须属于哪一轮，只要求：

- 不能部分进入；
- 不能破坏已经冻结的 transaction；
- 不能造成 owner、mask、active 不一致。

---

# 6. Candidate Ack 的含义

`candidateAck` 只表示：

> 当前 decision cell 已经记录了这个 candidate 的本轮加入申请。

它不表示 packet 已经获得输出，也不清除 `packetPresent`。

建议 candidate 侧采用以下保持关系：

```text
candidateRequest =
    admissionRequest
    && stageOpen
    && !candidateAck
```

当 candidate 侧 Mutex 获胜：

```text
candidateSeen := 1
candidateAck  := 1
```

于是：

```text
candidateRequest → 0
```

Mutex candidate grant 可以释放，让正在等待的 close token 继续取得 grant。

`candidateAck` 保持到整个 round RETURN/reset，不立刻下降。否则 candidate 仍然 pending，会在同一 round 再次发出 request。

因此局部过程为：

```text
candidateReq↑
→ candGrant
→ candidateSeen=1
→ candidateAck↑
→ candidateReq↓
→ candGrant↓
→ closeGrant 可以建立
```

在下一轮开始前：

```text
candidateAck↓
candidateSeen清零
stageOpen重新置1
```

如果 candidate 本轮未 commit，它会在新一轮重新请求。

---

# 7. Close token 使用什么握手？

建议 Builder 内部使用局部四相 Req/Ack，因为它和 Mutex 的保持型 request/grant 更自然：

```text
1. closeReq ↑
2. decision cell 完成捕获和计算
3. closeAck ↑
4. closeReq ↓
5. closeAck ↓
```

相邻 stage 连接为：

```text
Stage r closeOutReq ──► Stage r+1 closeInReq
Stage r closeOutAck ◄── Stage r+1 closeInAck
```

虽然 Router 外部使用两相握手，但 Builder 内部可以使用四相控制。这个协议被封装在 Arbiter V2 内部，不影响 ReqIn/AckIn 或 ReqOut/AckOut。

选择四相的原因：

- Mutex request 必须保持到 grant；
- Grant 后通过 request 撤销完成释放；
- “stage 已经关闭”可以直接由 Req/Ack 状态表示；
- 不需要用事件 DFF记录 token phase；
- 复位状态明确为全部 Req/Ack=0。

---

# 8. 时序如何推进？

decision cell 不是 close token 一到就立即转发。

完整推进顺序为：

```text
close grant 建立
      │
      ▼
candidateSeen 已稳定
      │
      ▼
conflict = candidateMask & acceptedMaskIn
      │
      ▼
take / acceptedMaskOut / winnerSetOut 稳定
      │
      ▼
matched DelayElement
      │
      ▼
关闭本级数据 latch
      │
      ▼
closeTokenOut.Req ↑
```

匹配延时必须满足：

```text
TcloseControl
≥
T(candidate mux
  + mask AND
  + OR reduction
  + acceptedMask OR
  + winnerSet OR
  + output latch setup)
× 1.05
```

即：

```text
Tcontrol ≥ Tdata × (1 + RTM)
```

本轮仍采用 5% RTM。

### 为什么不能直接用 conflict 结果产生 closeOut？

因为这会重新引入 bundled-data 违例：

```text
closeOut 已经推进
但 acceptedMaskOut 尚未稳定
```

下一级可能读取到部分旧 mask、部分新 mask。

因此每一级都必须遵循：

```text
data first
matched control later
```

---

# 9. Decision cell 的局部状态

每一级可以抽象成五个状态：

```text
OPEN
CANDIDATE_SEEN
CLOSING
FORWARDED
RETURN
```

状态图：

```text
                   candidate wins
             ┌────────────────────────┐
             │                        ▼
          ┌──────┐              ┌──────────────┐
          │ OPEN │              │CANDIDATE_SEEN│
          └──┬───┘              └──────┬───────┘
             │ close wins              │ close subsequently wins
             │                         │
             └────────────┬────────────┘
                          ▼
                     ┌─────────┐
                     │ CLOSING │
                     └────┬────┘
                          │ data stable + delay
                          ▼
                    ┌───────────┐
                    │ FORWARDED │
                    └─────┬─────┘
                          │ downstream ack
                          ▼
                      ┌────────┐
                      │ RETURN │
                      └────┬───┘
                           │ round reset
                           ▼
                          OPEN
```

状态转移表：

| 当前状态 | 条件 | 动作 | 下一状态 |
|---|---|---|---|
| `OPEN` | candidate Grant | `candidateSeen=1`，Ack candidate | `CANDIDATE_SEEN` |
| `OPEN` | close Grant | `candidateSeen=0`，关闭加入窗口 | `CLOSING` |
| `CANDIDATE_SEEN` | 等待 close Grant | 保持 candidate 信息 | `CANDIDATE_SEEN` |
| `CANDIDATE_SEEN` | close Grant | 计算 conflict/take | `CLOSING` |
| `CLOSING` | 数据未满足 matched delay | 保持输出 latch 透明 | `CLOSING` |
| `CLOSING` | delay 完成 | 关闭输出 latch，发下一级 token | `FORWARDED` |
| `FORWARDED` | 下一级未 Ack | 保持输出数据 | `FORWARDED` |
| `FORWARDED` | 下一级 Ack | Ack 上一级 close token | `RETURN` |
| `RETURN` | round 尚未复位 | 保持关闭 | `RETURN` |
| `RETURN` | round reset | 清 seen/Ack，重新打开 | `OPEN` |

这些状态建议由 C-element/SR 反馈单元实现，不使用自由运行时钟 DFF。

---

# 10. 一个具体例子

假设 anchor=I2：

```text
I2 = {O0}
I3 = {O1,O2}
I4 = {O2,O3}
I0 = {O4}
I1 暂时未到
```

初始：

```text
winner = {I2}
acceptedMask = {O0}
```

### Stage 1：I3

I3 candidate request 先于 close token：

```text
candidateSeen=1
conflict({O1,O2},{O0})=0
```

结果：

```text
winner={I2,I3}
accepted={O0,O1,O2}
```

### Stage 2：I4

I4 已请求：

```text
candidateSeen=1
conflict({O2,O3},{O0,O1,O2})=1
```

结果保持：

```text
winner={I2,I3}
accepted={O0,O1,O2}
```

I4 保持 pending。

### Stage 3：I0

I0 已请求且无冲突：

```text
winner={I2,I3,I0}
accepted={O0,O1,O2,O4}
```

### Stage 4：I1

close token 先到，I1 随后才到：

```text
closeGrant wins
candidateSeen=0
```

I1 属于下一轮。

最终 transaction：

```text
txWinner = I2 | I3 | I0
```

这三个输入在同一个 ACG fire 中写入 owner，因此可以平行多播。

I4 和 I1 保持 pending，下一轮再以 Mutex5 选出的新 anchor 开始判断。

## v2.0 （V3 Arbiter） 优化规划

| 模块/事件 | 累计时间 | 本段时间 |
|---|---:|---:|
| 输入 V1 Mousetrap：`ReqIn → ReqX` | 0.114 ns | 0.114 ns |
| PRS：`ReqX → RS` | 0.564 ns | 0.450 ns |
| V2 HeadCapture：`RS → P` | 1.024 ns | 0.460 ns |
| Mutex5：`P → anchorGrant` | 1.328 ns | 0.304 ns |
| Decision cell 1 | 2.644 ns | 1.316 ns |
| Decision cell 2 | 3.172 ns | 0.528 ns |
| Decision cell 3 | 3.699 ns | 0.527 ns |
| Decision cell 4 | 4.226 ns | 0.527 ns |
| Transaction latch | 4.314 ns | 0.088 ns |
| ACG：`txValid → fire_o` | 4.788 ns | 0.474 ns |
| commit / `admittedRS` | 4.919 ns | 0.131 ns |
| ReqGen：`admittedRS → Req` | 5.001 ns | 0.082 ns |
| ReqGen C3：`Req → PPE/Grant` | 5.074 ns | 0.073 ns |
| OPM：`Grant → MG` | 5.116 ns | 0.042 ns |
| OPM 数据到输出稳定 | 5.316 ns | 0.200 ns |
| OPM 首次 `ReqOut` 边沿 | 5.403 ns | 0.087 ns |

当前 V2 的主要性能问题不是 Mutex5，而是把“候选是否属于本轮”的边界处理，做成了四级串行的完整异步握手链。

当前 Head 的 5.450 ns 中：

| 部分 | 时间 |
|---|---:|
| V1 + PRS | 0.564 ns |
| HeadCapture + Mutex5 | 0.764 ns |
| 四级 Decision builder | 2.898 ns |
| Transaction + ACG + commit | 0.693 ns |
| ReqGen + OPM 控制到输出 | 0.531 ns |

特别是 stage1 的 1.316 ns 并不全是逻辑计算慢，而是连续经过了多个保守的控制等待：

```text
anchor grant
→ anchor_margin DEL250
→ first_stage_margin DEL250
→ stage1 Mutex/C-state
→ stage1 decision_margin DEL250
→ close token
```

所以仅 stage1 就有约 0.75 ns 的显式 DEL，另加 Mutex、C2、透明锁存器及布线。stage2–4 每级也各自有一个 `decision_margin DEL250`，因此每级约 0.527 ns。

你的两个方向都成立。

1. Decision cell 不应继续逐级串行推进

按 [MulticastArbiterStructure.md](D:\NoC\asynchronous_fat_tree_multicast\src\main\scala\Router_Architecture\ultra\MulticastArbiterStructure.md) 的当前实现，四级链的目的有两个：

- 按 anchor 旋转优先级完成 greedy 集合选择；
- 把“候选在本轮还是下一轮”的异步边界封装进 Mutex2，避免晚到 Head 直接污染 fire 域。

第二点是必要的；但“每级都等前一级完成以后，才允许下一候选与 close token 仲裁”不是唯一实现方式。

更合适的 V3 Builder 可以保留现有全局状态：

```text
IDLE → SELECT → BUILD → ARMED → RETURN
```

但把 `BUILD` 改为“并行成员快照 + 一次组合 greedy 求解”：

```text
Mutex5 anchor
      │
      ├─ roundClose ── Mutex2(candidate1, close) ── seen1
      ├─ roundClose ── Mutex2(candidate2, close) ── seen2
      ├─ roundClose ── Mutex2(candidate3, close) ── seen3
      └─ roundClose ── Mutex2(candidate4, close) ── seen4
                         │
                     C-tree join
                         │
         frozen {anchor, seen1..seen4, masks}
                         │
         combinational rotated greedy selection
                         │
                  Transaction latch → ACG
```

这样仍满足：

- 每个候选与 `roundClose` 的竞态由自己的 Mutex2 吸收；
- 晚到候选自然留到下一轮；
- fire 只读取冻结的 transaction；
- 不相交集合仍可在同一 transaction 中并行获准；
- anchor 后的 priority 顺序完全保留。

但不再需要 `stage1 → stage2 → stage3 → stage4` 的四次完整握手串行传播。四个“是否进本轮”的 Mutex2 可以并行解析，之后只等待一个 C-tree 汇合。`acceptedMask/winnerSet` 也不必在每一级重复锁存；可只在最终 transaction latch 冻结。

这是最值得做的结构优化，预计能直接去掉当前约 **1.5 ns 以上** 的三级串行附加等待；单一 Head、没有其他 pending 候选时的收益尤其大。

2. Delay 可以减，但不能无证据地全删

当前前向关键 Delay 如下：

| Delay | 当前作用 | 对 Head 前向延迟 |
|---|---|---|
| `head_margin DEL250` | local mask 先稳定，再锁定 `P/M` | 有影响 |
| `anchor_margin DEL250` | anchor grant 后等待 anchor 数据稳定 | 有影响 |
| `first_stage_margin DEL250` | 启动 stage1 close token | 有影响 |
| 四个 `decision_margin DEL250` | 每级 mask/winner 数据先稳定、再推进 close | 有影响 |
| ACG `UltraArbiterCommit DEL250` | transaction Q 先稳定、再 fire | 有影响 |
| `return_margin DEL250` | fire 后 round 回收 | 不影响本次 Head 首次输出 |
| `commitAckDelay` | ACG Ack 回路 | 基本不在首次 `fire_o` 前向路径上 |

建议不是直接删除，而是分三类处理：

- `return_margin`、commit Ack 回路：不影响 Head 前向延迟，暂不作为优化目标。
- `head_margin`、每级 `decision_margin`、ACG commit DEL：按实际 bundled-data 约束做 `250 → 150 → 100 → 75 → 50 ps` 的独立 STA/SDF sweep。它们理论上可显著缩短，但必须满足相应 latch/transaction 的 5% RTM。
- `anchor_margin + first_stage_margin`：最可疑的冗余组合。两者串联只是为了保证 `anchor_q/anchor_mask` 冻结后再启动 builder；应重构为一个 `anchorReady` 共识点加一条匹配 DEL，而不是保留两条独立 DEL。这里有机会直接节省约 250 ps。

不建议把 `decision_margin` 直接设为 0：当前它保证 `candidateSeen/conflict/acceptedMask/winnerSet` 已稳定后才把 close token 交给下一级。删除后会重新出现“下一级读取部分更新 mask”的 bundled-data 错误，只是从 DFF setup/hold 问题换成 latch 级数据竞争。

结论：

- 小步、低风险优化：合并 `anchor_margin` 和 `first_stage_margin`；量化后缩短 HeadCapture、Decision、Commit 的 DEL。
- 大步、真正解决 2.9 ns Builder 延迟的优化：保持现有 `P/M/A`、Mutex5、transaction、ACG 和状态机语义，但把四级串行 Decision chain 改为“4 个并行 candidate-close Mutex + C-tree 汇合 + 冻结后的组合 greedy”。

前者可减少数百 ps；后者才可能把仲裁器从约 4.36 ns 降到更可接受的约 2 ns 级别。