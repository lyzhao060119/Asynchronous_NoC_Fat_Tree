# DATE 实验 DUT 冻结：CMRRouter 结构 / 同步时钟 / 异步 DEL

> **冻结日期：2026-08-31**  
> **适用范围：** DATE V3 全部主实验（THIN / PROP / PFAT / SYNC / FM / H-REP）。  
> **原则：** Thin 与 Fat 共用同一套 Router 微架构；只改 **lane 几何** 和 **路由模式**（四叉树 vs Mesh）。不同时改 Buffer 深度、flit 宽度、握手协议、异步 DEL 配方或同步时钟。  
> **论文 PPA 口径：** DC ZeroWireload + MAXIMUM-SDF GLS + PT-PX。DATE V3 **不做 P&R**；不得把面积/时序写成 post-layout。

实现源：

| 角色 | 模块 | 路径 |
| --- | --- | --- |
| Async Router | `CMRRouter` | `src/main/scala/Router_Architecture/CMR/CMRRouter.scala` |
| Sync Router | `SyncCmrRouter` | `src/main/scala/Router_Architecture/sync_cmr/SyncCmrRouter.scala` |
| 几何 / DEL 默认 | `CMRParameters` | `src/main/scala/Router_Architecture/CMR/CMRTypes.scala` |
| 64 核时钟冻结 | — | `docs/CMR_Sync64_Clock_Freeze.md` |
| 异步 hop DEL 配方 | — | `docs/CMR_DC_Timing_Intent.md` § Paper hop delay recipe |
| 禁止覆盖的 run ID | — | `scripts/asic_dc/cmr/cmr_frozen_run_ids.py` |

`CMRArchitecture.md` 中仍出现的 **4×`DEL150`** 是 Fig. 6 历史叙述，**不是** 本论文 hop / Table I 配方。实验以本文为准。

---

## 1. 冻结声明（一句话）

$$
\boxed{
\text{同一 CMR Router = 5 槽 Buffer + 方向级 RCU + 精确宽度 OPM}
}
$$

- **Async：** 两相 bundled-data；显式 DEL 只有两处，且 **Thin/Fat、L1/L2/L3 完全相同**：RCU `MatchedDelay` = **1×`DEL050`**，OPM `AckinDelay` = **1×`DEL050`**，RCU matched buffer = **0**。
- **Sync：** 功能等价 valid/ready 对照；**无 `DelayElement`、无 Mutex、无 `LanePhaseAdapter`**；全局时钟 **1.0 ns**（TSMC 28 nm SS ZeroWireload），Thin 与 Fat 1-2-2-2 共用该周期。

任何新的 DC / SDF / PPA 若改了上述三项中的任意一项，都不得写入 DATE 主文，也不得覆盖已冻结 run ID。

---

## 2. 共用微架构（Async = Sync 功能同构）

两端都实现 Continuous-Time Replication 的 Fig. 5–8 角色划分，数据格式与路由换成本工程四叉树 / Mesh。

### 2.1 Flit 与 Buffer（不可改）

28-bit `DataStruct.Packet`：

```text
flit[27]    Head
flit[26]    Tail
flit[25:20] y1
flit[19:14] x1
flit[13:8]  y0
flit[7:2]   x0
flit[1:0]   id   （不参与路由）
```

- 路由地址 = `flit[25:2]`，24 bit。
- CMR Buffer：**5 槽** one-hot（奇数槽，交替初相位）；**1 写 + 4 个独立读口**（方向级，不是物理 lane 级）。
- 无 Mesh AMU。RCU 永远只看到 4 个合法**方向**；物理 lane 在读口之后展开。
- **no-U-turn：** 同一方向的 ingress 不能连回该方向的任何 egress lane。`allowSameDirChild = false`，`allowSameDirParent = false`。

### 2.2 端口与方向

五方向：4 个 child + 1 个 parent。物理端口数：

$$
N_{\mathrm{port}} = 4\cdot N_{\mathrm{child}} + N_{\mathrm{parent}}
$$

合法几何集合（代码硬约束，不可临时发明宽度）：

$$
\{(1,1),\ (1,2),\ (2,2),\ (2,4),\ (4,8)\}
$$

每个物理输入的 4 个合法输出方向对应 4 个 multicast branch。一个 Head 可同时打开多个 `PathEnabled`；各输出按自身速度读完，用 `TailPassed` 释放。

### 2.3 模块数据通路（两端同构）

```text
物理输入  →  IPM = RCU ∥ CMR Buffer
                 │ PathEnabled[4]
                 │ Data/Req（方向级）
                 ▼
          [lane>1 时：Lane Selector +（Async 才有）Phase Adapter]
                 │
物理输出  ←  OPM = MutexN / 时钟轮转仲裁 → Grant/MG → 输出寄存器
                 │ TailPassed
                 └──→ RCU 释放 PathEnabled
```

| 角色 | Async | Sync |
| --- | --- | --- |
| 链路握手 | 两相 `Req`/`Ack` | `valid`/`ready` |
| RCU 地址锁存 | HeadPredictor + PhaseSelector + LatchReg | `destReg` 在 Head fire 时锁存 |
| 路由计算 | `RoutingLogic` / `RoutingLogic_mesh` 组合 `Mat` | **同一套** `RoutingLogic`；`Mat` 组合驱动 `PathEnabled` |
| `Mat` 相对控制 | 显式 `DelayElement` 使 `Mat` 先于 `RouteSel` | **一个时钟就是 Mat 预算**；无 DEL、无额外 match-delay 寄存器 |
| Buffer | Fig. 7/8 锁存器 + Tail barrier | 5 个时钟寄存器槽 + Tail drain barrier |
| OPM 仲裁 | `CMRMutexN(SourceCount)`，Grant 保持到 Tail | 空闲时旋转优先级；Grant 保持到 Tail fire |
| 多 lane | `ContinuousLaneSelector`（Mutex）+ `LanePhaseAdapter` | `SyncLaneSelector`（寄存器 + PriorityEncoder） |
| 层间存储 | 论文 DUT：**bypass**（只有 Router 内 5 槽） | 直连导线（同样只有 Router 内 5 槽） |

Sync 是 **same-function counterpart**，不是把异步电路包一层时钟。DC 断言：`Mutex*=0`，`DelayElement*=0`，`LanePhaseAdapter*=0`。

---

## 3. Lane 几何冻结（Thin / PROP / PFAT）

Q64 固定深度：16×L1 + 4×L2 + 1×L3 = **21 个 Router**。L1 的 child lane 永远是 1，因此一个 tile 永远是 64 PE。

| V3 ID | 剖面 | L1 | L2 | L3 | Top parent lanes |
| --- | --- | --- | --- | ---: | ---: |
| **THIN** | 1-1-1-1 | `(1,1)` | `(1,1)` | `(1,1)` | 1 |
| **PROP** | **1-2-2-2** | `(1,2)` | `(2,2)` | `(2,2)` | 2 |
| **PFAT** | 1-2-4-8 | `(1,2)` | `(2,4)` | `(4,8)` | 8 |
| **FM** | flat Mesh | 全部 `(1,1)`，`useMeshRouting=true` | — | — | 无 top |

PROP 的默认环境变量：`CMR_FAT_LANE_PROFILE=1222`（Scala 默认已是 `1222`）。  
Sync Fat 64 核 **钉死** `NoCScaleConfig.syncFatTree64_1222`，不能被该环境变量悄悄切到 1-2-4-8。

### 3.1 单 Router 计数（实验 Table / Fig. A 用）

OPM `SourceCount`：child 出口 = \(3N_{\mathrm{child}}+N_{\mathrm{parent}}\)；parent 出口 = \(4N_{\mathrm{child}}\)。

| 几何 | 物理端口 | LanePhaseAdapter / SyncLaneSelector | child OPM 扇入 | parent OPM 扇入 | Mutex / 仲裁宽度 |
| --- | ---: | ---: | ---: | ---: | --- |
| Thin `(1,1)` | 5 | **0** | 4 | 4 | 4 |
| Fat L1 `(1,2)` | 6 | 4 | 5 | 4 | 2, 4, 5 |
| PROP L2/L3 `(2,2)` | 10 | 40 | 8 | 8 | 2, 8 |
| PFAT L2 `(2,4)` | 12 | 48 | 10 | 8 | 2, 4, 8, 10 |
| PFAT L3 `(4,8)` | 24 | 96 | 20 | 16 | 4, 8, 16, 20 |

`CMRMutexN` 只接受 `{1,2,4,5,8,10,16,20}`：

- 2 = `Mutex2`；4 = 已验证 `Mutex4`
- 5 / 8 / 10 = `CMRFlatArbiter5/8/10`
- 16 / 20 = 精确宽度 TAC 树（8+8 / 10+10）

**这就是 bounded-fat 的实现成本轴：** PROP 最大 OPM 扇入 = 8；PFAT L3 = 20。不要用“lane 数”代替仲裁 radix。

### 3.2 64 核 tile 计数

| DUT | 模块名 | 端口合计 | Adapter / Selector | 层间 FIFO |
| --- | --- | ---: | ---: | --- |
| Async PROP `NoC_64nodes` | `CMRFatTreeNoC64`，`CMR_FAT_LANE_PROFILE=1222` | 146 | 264 `LanePhaseAdapter`（全为 2-lane） | **0（bypass）** |
| Async PFAT `NoC_64nodes` | 同上，`1248` | 168 | 352（2/4/8-lane） | **0（bypass）** |
| Sync Thin `SyncNoC_64nodes` | `SyncCmrFatTreeNoC64` | 105 | 0 | 0 |
| Sync PROP `SyncNoC_64nodes` | `SyncCmrFatTreeNoC64Fat1222` | 146 | 264 `SyncLaneSelector` | 0 |
| Async FM `CMRMeshNoC` | 8×8，64 个 Thin Router | 320（64×5） | 0 | 0；无 top |

Thin 与 Fat 的 64 核 Sync 网表 **模块名相同**（`SyncNoC_64nodes`），目录和 `TOP_LANES` 必须分开，不可互换。

Async Thin Q64（21 个 `(1,1)` Router）与 Sync Thin 同几何；当前 `CMRFatTree` 生成器要求 L1=`(1,2)`，因此 **Async Thin 64 核 tile 尚未作为独立 emit 入口**。THIN 的 Router PPA 使用隔离 `CMRRouter(1,1)` hop 网表（已冻结）。网络级 THIN 需要单独发出 Thin 树，不得把 PROP 网表当 Thin。

---

## 4. 异步 DEL 冻结（Thin = Fat = 全层级）

工艺：TSMC 28HPC+ `tcbn28hpcplus` / `BWP12T30P140`。  
单元：`DelayElement_ASIC.v` 中 `DelayUnitPs=50` → **`DEL050D1BWP12T30P140`**。  
DC：`dont_touch` 该链，并核对个数；禁止用 WritePointer SDC 或 `insert_buffer` 冒充 RCU matched delay。

### 4.1 论文 hop / Table I 唯一配方

| 位置 | 作用 | 冻结值 | 禁止 |
| --- | --- | --- | --- |
| RCU `MatchedDelay`（`Req_rc`） | Fig. 6：`Mat` 稳定后再打开 `RouteSel` | **1 × `DEL050`** | 4×`DEL150`；`STEPS=0`；其后插 `BUFFD0` |
| RCU matched buffer | 历史 Thin CFifo / standalone 实验 | **0** | `CMR_RCU_MATCHED_BUF_STAGES≠0` |
| OPM `AckinDelay` | V2 close-event：避免组合 Ack 使 L5 永不关闭 | **1 × `DEL050`**（Fat 与 Thin 相同） | Fat `DEL250`；`CMR_OPM_ACKIN_USE_BUF=1` |
| `LanePhaseAdapter` 数据缓冲 | AckLatch D vs `Assigned` 关闭 | **0** | RTL 内固定 buffer |
| Write / Read 接口 | Fig. 7/8 | **无 `DelayElement`** | 在 `WriteCounter` 里加 DEL |
| 层间 FIFO DEL | 论文 DUT 已 bypass | **N/A** | 把 CFifo `16×BUFFD0` 算进 hop |

默认 Scala / 发射环境（不要覆盖）：

```text
CMR_RCU_MATCHED_DELAY_STEPS=1
CMR_RCU_MATCHED_DELAY_UNIT_PS=50
CMR_RCU_MATCHED_BUF_STAGES=0
CMR_OPM_ACKIN_DELAY_STEPS=1
CMR_OPM_ACKIN_DELAY_UNIT_PS=50
CMR_LANE01_BUF_STAGES=0
# 不要设置 CMR_OPM_ACKIN_USE_BUF
CMR_BYPASS_INTERLEVEL_FIFO=1          # 64 核论文 DUT
```

保护脚本：`cmr_frozen_run_ids.require_locked_delay_structure`。  
覆盖冻结目录必须显式 `CMR_FORCE_OVERWRITE_FROZEN=1`，且仍不得把新配方写进主文。

### 4.2 已冻结 Async hop 网表（Table I / Fig. A Router 点）

同一配方，六个隔离 Router：

| 几何 | run ID |
| --- | --- |
| Thin L1 `(1,1)` | `20260830_cmr_thin_l1_hop_del050_ackin050` |
| Thin L2 `(1,1)` | `20260830_cmr_thin_l2_hop_del050_ackin050` |
| Thin L3 `(1,1)` | `20260830_cmr_thin_l3_hop_del050_ackin050` |
| Fat L1 `(1,2)` | `20260830_cmr_fat_l1_hop_del050_ackin050` |
| PROP L2 `(2,2)` | `20260830_cmr_fat_l2_hop_del050_ackin050` |
| PROP L3 `(2,2)` | `20260830_cmr_fat_l3_hop_del050_ackin050` |

PPA 汇总目录：`20260830_cmr_router_level_baseline_del050`。

该配方上已测得的 hop Head（**引用用，不是新的调时目标**）：Thin ≈ **0.681 ns**；Fat L2/L3 ≈ **0.956 ns**。Body/Tail、面积、energy 以该 PPA 文件夹为准，不在实验中途改 DEL 去“刷”这两个数。

### 4.3 明确不是论文 hop 对照的网表

| run ID / 配方 | 为什么不算 |
| --- | --- |
| Thin NoC16 `20260828_cmr_cfifo_tp_nogrant_p50` | CFifo 网络 GLS；RCU 侧有 16×`BUFFD0` |
| `20260830_cmr_thin_l1_hop` | RCU DEL050 + 16×`BUFFD0` |
| `20260830_cmr_fat_l1_hop` | Ackin **DEL250** |
| Fat NoC16 `20260829_cmr_ft_noc16_lane01_0` | Ackin 250 |
| Fat NoC64 `20260830_095259_cmr_noc64_p50_1222` | 网络 SDF PASS，Ackin **DEL250**（网络稳健性前驱，不是 hop 配方） |
| 历史 Fig. 6 默认 4×`DEL150` | 实现笔记残留，代码默认已是 1×`DEL050` |

PFAT L2 `(2,4)` / L3 `(4,8)` 的 **RTL 几何已冻结**，隔离 hop 网表 **尚未** 进入 `FROZEN_HOP_NETLIST_RUN_IDS`。Fig. A 的 PFAT 硬件点必须用 **同一 DEL 配方** 新跑，不得拿 Ackin-250 或 1248 实验室网表充数。

---

## 5. 同步时钟冻结（Thin = Fat 1-2-2-2）

| 项 | 冻结值 |
| --- | --- |
| 周期 | **1.0 ns** |
| 工艺 / 角 | TSMC 28 nm SS `ssg0p81v125c` |
| 线载 | ZeroWireload |
| SDC | `scripts/asic_dc/cmr/sync_cmr_noc64.sdc`：setup uncertainty = 5%×周期，hold = 0.02 ns，I/O = 10%，ideal clock |
| 关键路径 | L2 `destReg` → bypass 导线 → L1 buffer 写（Mat/flit，**一个时钟**） |
| Fat 限制器 | arrival **0.85 ns**，required 0.93 ns，WNS **0.083 ns** |
| Thin | arrival 0.80 ns，WNS 0.134 ns |
| 同网表零裕量下限 | Fat ≈ **0.92 ns**；**禁止** 对这些 run ID 设 `CMR_SYNC64_CLOCK_PERIOD_NS=0.9` |

1.0 ns 是 Fat 在 ZeroWireload 下还剩约 80 ps 给真实线网的签核周期，不是松的 1.5–2 ns pad，也 **不是** 芯片 Fmax，更 **不是** 异步 hop Head。

已冻结 Sync 64 核网表：

| 几何 | run ID | 面积（约） | SDF |
| --- | --- | --- | --- |
| Thin | `20260831_014622_cmr_sync_noc64_thin_p50` | 0.143 mm² | TAB 3000/3000；VCTM-MC5-NM 3000 in / 4500 out |
| Fat 1-2-2-2 | `20260831_084457_cmr_sync_noc64_fat1222_p50` | 0.211 mm² | 同上 |

复用：`CMR_SYNC64_NETLIST_RUN_ID`。不要对同一 id 再跑 DC。

---

## 6. 工艺与综合边界（两端共用）

- 综合：`compile_ultra -no_autoungroup`，禁止 GTECH / SEQGEN 残留。
- Async 功能状态必须映射为库原语：可复位 latch（`LHCNDQD` 等）、V2 close-event、Mutex 交叉耦合、`DEL050` 链。
- Async Router SDC `async_cmr_router.sdc` 只是 10 ns clock stub；bundled-data 相对时序按 `CMR_DC_Timing_Intent.md` 的 RTC 目录，**不用这段 stub 当 Fmax**。
- 论文 64 核树：**层间 FIFO bypass**。存储只在 Router 五槽 Buffer。不要把带 CircularFIFO / AsyncFifo 的 NoC16 回滚网表当作 PROP64。
- **物理签核停在综合：** Table I / hop PPA 使用 DC cell area 与 MAXIMUM SDF；DATE V3 不对 Router 做 place-and-route。

---

## 7. 实验 ID → DUT 对照

| V3 ID | Router | 几何 | 时钟 / DEL | 备注 |
| --- | --- | --- | --- | --- |
| PROP | Async `CMRRouter` | Q64 1-2-2-2 | 1×`DEL050` + 1×`DEL050` | 主设计 |
| SYNC | `SyncCmrRouter` | 与 PROP 同几何 | 1.0 ns，无 DEL | 实现对照，不是 topology baseline |
| THIN | Async `CMRRouter` | 全 `(1,1)` | **同一 DEL** | ablation；不要减 DEL 去“帮”Thin |
| PFAT | Async `CMRRouter` | 1-2-4-8 | **同一 DEL** | DSE 上界；L3 hop 网表待按本配方新跑 |
| FM | Async `CMRRouter` `useMeshRouting` | 8×8 `(1,1)` | 同一 DEL | 只比 topology；Sync Mesh 尚未实现 |
| H-REP | 与 PROP **同一硬件** | 1-2-2-2 | 同一 DEL | 只改跨 cluster 拆包策略 |

---

## 8. 禁止清单（实验过程中）

1. 为了让 Thin hop 更好看而加厚 / 减薄 DEL，或只给 Fat 用 `DEL250`。
2. 把 1.0 ns Sync 时钟改成 0.90 ns 去追异步 Head。
3. 在 Fig. 7/8、AddressRegister、LanePhaseAdapter 里插入新的 `DelayElement`。
4. 用 `DontTouchBuf` 替换锁定的 Ackin `DEL050`。
5. 论文 64 核 DUT 打开层间 FIFO（`CMR_BYPASS_INTERLEVEL_FIFO=0`）却仍引用 bypass 面积/延迟。
6. 覆盖 `cmr_frozen_run_ids.py` 中的 hop / Sync64 / Thin NoC16 CURRENT 目录。
7. 把 UltraRouter / `RouterTop` / 旧 `quadtree_and_mesh` 的延迟或面积写进 DATE Table I。当前 256/1024 Top Mesh 生成器仍走遗留 `RouterTop`，**尚未** 切到 `CMRRouter`；系统级实验在切换完成前不得混用两套微架构的 PPA。
8. 把 DC / MAXIMUM-SDF 数字写成 post-layout、post-route 或 placed core area。DATE V3 不做 P&R。

---

## 9. 尚未冻结、但不改变本文结构的后续项

这些项 **不打开** 微架构或 DEL/时钟，只补 DUT 入口：

1. Async Thin 64 核 tile 生成器（21×`(1,1)`，bypass），与 Sync Thin 对齐。
2. PFAT L2 `(2,4)` / L3 `(4,8)` 在本 DEL 配方下的 hop DC/SDF。
3. Q64 之上的 Top Mesh2 改为 `CMRRouter`（PROP 256/1024）。
4. Sync `CMRMeshNoC` 对照（若 FM 需要 Sync 点）。

完成以上入口时，仍必须满足第 1 节冻结声明。
