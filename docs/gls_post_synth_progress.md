# 综合后门级仿真（GLS）进展记录

Latest clean checkpoint: see
[`docs/current_progress_summary.md`](current_progress_summary.md). As of
2026-07-24, RouterL1 `P100_FIFO_ONLY` is the stable post-synth/SDF baseline
(`E2E_EDGE=2.147ns`), NoC16 SDF + edge probe + PT PX power are working, and the
current RouterL1 hotspot is the `InputControlModule` route/dest-mask control
cone feeding reqGen launch.

> **维护约定**：之后每次 GLS / SDF / 异步原语相关迭代，**必须更新本文档**（至少改「当前状态」「未解决问题」「迭代日志」三节）。  
> 脚本级操作细节见 [`scripts/asic_dc/sim_gls/README.md`](../scripts/asic_dc/sim_gls/README.md)。  
> 异步原语与综合约束见 [`docs/async_timing.md`](async_timing.md)。

**最后更新**：2026-07-23

---

## 1. 当前状态（快照）

| 项目 | 状态 |
|------|------|
| DC 后网表 RouterL1 | 全门级：`DEL150`×**1**/DelayElement；GTECH=0；**`DEL=61`**（Dreq=0 后，原 73） |
| DC 后网表 NoC16 | 已用当前 RTL/ASIC primitive 重综合；2026-07-22 16:45 输出刷新，GTECH=0，`DEL_delay=1748`，`ND2D1_mutex=476`（**仍为旧 flat4/DEL250；未随本轮重综合**） |
| **func** GLS smoke（无 SDF） | **PASS**：`smoke_directed` 9/9，`T_router≈59ns` |
| **sdf** GLS 全门级（identity 补丁） | **PASS**：RouterL1 `smoke_directed_sdf` 9/9（1×**DEL150**，Dreq=0）；`T_router≈59ns` |
| RouterL1 DUT 边界 Head E2E | **PASS**：`E2E_EDGE_*=2.356ns`（0→4，1×DEL150 基线）；本轮 SDF 包装 `T_router=59ns` |
| NoC16 DUT 边界 Head E2E | **PASS**：`E2E_EDGE_REQ/VALID_NS≈30.635ns`（封装 `T_noc≈110ns`；旧网表） |
| Vivado VCTM | **PASS**：`VCTM-MC5-NM-5f-r0p02`，`avg_lat_ns=82.802`（Dreq=0，无 C/A+B） |
| RouterL1 combo budget (DC) | 握手域 Dreq=0：FIFO **Dreq=NA**；reqGen **0.96 ns**；covered **5/6** |
| 1×DEL250 脉宽 | **够用**：high≈0.48–0.56ns；E2E≈3.35ns |
| 1×DEL150 脉宽 | **够用（现行）**：high≈**0.33–0.39ns**；偶见 demux 毛刺 0.008ns；**保留** |
| 1×DEL100 试探 | **FAIL**：timeout，delivered=2/9；PW≈0.25–0.31ns；SDF p50≈0.17ns；**已恢复 DEL150** |
| 1×DEL075 试探 | **FAIL**：delivered=0；已回退（见 §2.8） |
| `setuphold` | smoke 下约 0（`+notimingcheck`） |
| `T_*` 是否可当真实延时 | 包装口径否；DUT 边界 `E2E_EDGE_*` 可作门级路径延时 |

### 两模式补丁策略（现行）

| 模式 | Mutex | DelayElement | SDF |
|------|-------|--------------|-----|
| `func` | 行为化 `#(0.1)` | 行为化 `#(1.0)` | 无 |
| `sdf` | **identity**（保留 ND2/INV） | **identity**（保留 `DEL*`） | `sdf_boot` + `*_dc.sdf` |

工具：`patch_gls_netlist.py` -> `*_post_func.v` / `*_post_sdf.v`（不覆盖 DC `*_post.v`）。

ASIC Delay：`DelayElement_ASIC.v` 现行 **DEL150**；flat **1**。扫档：DEL250 PASS → DEL150 PASS → **DEL100 FAIL** → DEL075 FAIL。E2E@DEL150≈2.36ns。

---

## 2. 已解决问题

### 2.5 全门级 SDF 基础设施（2026-07-22）

| 问题 | 根因 | 做法 |
|------|------|------|
| `DelayValue=1` -> 1×DEL025≈0.017ns（SDF）脉宽不够 | Liberty 名义 0.25ns 不等于标注 SDF | 改 **DEL250**（SDF≈0.37ns）+ flat 链长 4 |
| `max(n,8/16)` 把 Dreq/Dfire 压成一样仍不够 | 行为补丁实际是所有 Delay=`#(1.0)` | asic 用 **flat steps**，匹配行为语义 |
| sdf 仍行为化 Delay | 目标禁止 `#(1.0)` | `patch --mode sdf` = **identity**；`run_gls_smoke.sh` 校验无 `#`、有 `DEL*`+`ND2` |
| 紧凑 case 只出 head | `fifoDepth=1` + 门级握手慢 | 默认 sdf case：`smoke_directed_sdf.case`（flit 间隔 40） |

### 2.6 RouterL1 全门级 SDF tail 缺失（2026-07-22）

| 观察 | 结论 |
|------|------|
| probe v6：单包 head/body 匹配，tail 注入后无 IPM launch、无 IPM->OPM edgeReq | tail 没卡在 OPM，而是没从输入 VC/selector 进入 request generator |
| probe v7/v9：tail 外部 Req/Ack 完成，但无 demux launch；body 阶段 demux launch clock 有二次上跳 | `AsyncForkRequestBlock` 的 `launchCond -> DelayElement -> launchClock` 在门级 SDF 下可二次触发，污染 fork 相位 |
| tail 到达时 VC FIFO、selector、requestGen 输入均已空闲，但 AckJoin 直接回 Ack | stale `forkBusy` 相位让输入 flit 被 Ack 掉但没有真正 launch |

修复：

- 在 `AsyncForkRequestBlock` 中用 `launchedReq` 记录“已经 launch 的 input Req 值”，替代原先每次 launch pulse 盲翻的 `launchPhase`。
- 分支 `outReqReg` 只在 `destMask(j) && launchedReq =/= io.inReq` 时翻转，防止同一个输入请求被门级二次 launch pulse 重复翻分支 Req。
- `forkBusy := launchedReq ^ io.inAck`，使 busy 语义绑定到当前 toggle 事务，而不是绑定到毛刺敏感的 launch 脉冲次数。

结果：

- `smoke_sdf_1pkt.case`：3/3 PASS，tail `4020020` 已 MATCH。
- `smoke_directed_sdf.case`：9/9 PASS，3 个 packet 全部完整送达。
- `smoke_directed` func GLS：9/9 PASS。

### 2.7 RouterL1 1×DEL250 脉宽实验（2026-07-23）

| 项 | 结果 |
|----|------|
| 改动 | `AsyncDelay.AsicFlatSteps` 4→**1**；重综合 RouterL1；`DEL250` 292→**73** |
| `smoke_directed_sdf` | **9/9 PASS**；`E2E_EDGE_*=3.349ns`（flat4 时 10.024ns） |
| 典型脉宽 `GLS_PW` | demux/sel/opm fireClk **high≈0.48–0.56ns**（≥ DEL250≈0.37ns 量级） |
| 毛刺 | body 阶段见 demux `high_ns=0.010` 二次跳变；`launchedReq` 下仍功能 PASS |
| 结论 | **1×DEL250 对当前 RouterL1 smoke 脉宽够用**；保留 flat=1。距 2ns E2E 仍需减握手级数 |

### 2.8 RouterL1 1×DEL075 试探（2026-07-23）— FAIL

| 项 | 结果 |
|----|------|
| 改动 | `DelayElement_ASIC` → `DEL075D1`；flat 仍为 1；重综合 `DEL075=73` |
| `smoke_directed_sdf` | **FAIL**：timeout，injected=9 delivered=**0**；`E2E_EDGE=NA` |
| SDF IOPATH | DEL075 p50≈**0.138 ns**（min≈0.096，max≈0.153） |
| `GLS_PW` | demux/sel high≈**0.20–0.28 ns**（短于 DEL250 的 ~0.5 ns）；见 demux high=0.007 ns 毛刺 |
| 处置 | **已恢复 DEL250** 并重综合 RouterL1；不保留 DEL075 映射 |

结论：当前 6 级 Click 结构下，**DEL075 不够**；实用下限在 **DEL075 与 DEL250 之间**。后续 1×DEL150 已验证 PASS（见 §2.9）。

### 2.9 RouterL1 1×DEL150 试探（2026-07-23）— PASS

| 项 | 结果 |
|----|------|
| 改动 | `DelayElement_ASIC` → `DEL150D1`；flat=1；`DEL150=73` |
| `smoke_directed_sdf` | **9/9 PASS**；`E2E_EDGE_*=2.356ns`（DEL250 时 3.349ns） |
| `GLS_PW` | demux/sel/opm high≈**0.33–0.39ns**；偶见 demux 0.008ns 毛刺仍 PASS |
| SDF IOPATH | DEL150 p50≈**0.247 ns**（min≈0.204，max≈0.263） |
| `smoke_sdf_1pkt` | **3/3 PASS** |
| 处置 | **保留 DEL150** 为现行 ASIC 映射 |

相对 2ns：E2E≈2.36ns，已接近；**DEL100 已证实不够**，再压 E2E 应减握手级数（见 §2.10）。

### 2.10 RouterL1 1×DEL100 试探（2026-07-23）— FAIL

| 项 | 结果 |
|----|------|
| 改动 | `DelayElement_ASIC` → `DEL100D1`；flat=1；`DEL100=73` |
| `smoke_directed_sdf` | **FAIL**：timeout，injected=9 delivered=**2**，unexpected=1，missing=7 |
| SDF IOPATH | DEL100 p50≈**0.167 ns** |
| `GLS_PW` | demux/sel high≈**0.25–0.31 ns**；demux 毛刺 0.007 ns |
| 处置 | **已恢复 DEL150** 并重综合 |

结论：实用下限在 **DEL100（不够）与 DEL150（够）之间**；现行保留 **1×DEL150**。

---

## 3. 当前仍未解决 / 已知限制

### 3.1 回归范围仍偏窄

目前已确认 RouterL1 smoke 和单包 tail 修复。仍需补充：

- 多输入同输出争用；
- multicast 多目的输出；
- 两 VC interleaving；
- NoC16 端到端小 case；
- 更长随机/压力 case。

### 3.2 Bypass 组合锥 + reqGen A+B（2026-07-23）

A+B 改动：导出 `canLaunch`（`dontTouch` 防 OR(destMask) 重构）；eligibility 合法边裁剪 + `otherOccupies` 浅化（holder≠none∧≠self）。

| Rank | Stage / Role | combo_exclude (ns) | vs 基线 | needs_opt |
|-----:|--------------|-------------------:|--------:|:---------:|
| 1 | reqGen launchPulse | **0.97**（基线 0.96） | ≈持平 | YES |
| 2 | VC arb Dfire | 0.35 | — | YES |
| 3 | demux launchPulse | 0.30 | — | YES |
| 4 | OPM arb Dfire | 0.17 | — | NO |
| 5 | FIFO Dfire | 0.15 | — | NO |
| 6 | FIFO Dreq | 0.03 | — | NO |

结论：关键路径仍在 flit→route/lane→eligibility AND 树；A 只去掉叶端 OR，B 同构浅化收益被综合抹平。**未达 DEL100 预算**。功能：`smoke_directed_sdf` PASS（`E2E_EDGE≈2.40 ns`）；Vivado `VCTM-MC5-NM-5f-r0p02` PASS。下一步：**方案 C**（已有脉冲寄存）或结构 **F**。

### 3.3 功耗流程注意事项

NoC16 PrimeTime PX time-based 功耗已跑通，VCD 注释率 100%。当前 smoke 窗口功耗报告为：

- VCD：`logs/noc16_sdf_smoke.vcd`
- 窗口：`150ns–350ns`（覆盖 SDF smoke 的 `src_req=205ns` 到 `dst_req=315ns`）
- `Net Switching Power = 6.178e-06 W`
- `Cell Internal Power = 4.915e-05 W`
- `Cell Leakage Power = 3.439e-03 W`
- `Total Power = 3.494e-03 W`
- `Peak Power = 0.0982 W @ 195ns`

PT log 仍有 `PT-063 Library Compiler executable path is not set` 诊断，但标准单元库、DDC、SDC、VCD 均成功读取，`read_vcd` 显示 nets/leaf cells 100% annotated，报告已生成。后续可继续清理 PT 环境变量，但当前功耗数值不是 vectorless。

---

## 4. 建议的下一步

1. 在 Dreq=0 基线上再评估 **方案 C**（VC fire 采样）或 **F**（reqGen 切域）——此前 C 与 A+B 已回退。
2. 继续 VC / demux 热点；重综合 NoC16（仍为旧 flat4）并回归。
3. 扩展多争用 / multicast / 压力 case。

---

## 5. 关键路径速查

| 用途 | 路径 |
|------|------|
| 网表补丁 | `scripts/asic_dc/sim_gls/patch_gls_netlist.py` |
| 跑测脚本 | `scripts/asic_dc/sim_gls/run_gls_smoke.sh` |
| 上传+bsub | `scripts/asic_dc/upload_and_run_gls_smoke.py` |
| RouterL1 DC | `scripts/asic_dc/run_dc_r1_only.py` |
| ASIC Delay | `src/main/resources/ASYNC/DelayElement_ASIC.v`（DEL150） |
| Delay 步长 | `AsyncDelay` in `src/main/scala/tool/AsyncLib_ACG.scala` |
| Fork 修复 | `src/main/scala/Router_Architecture/common/async/AsyncForkRequestBlock.scala` |
| RouterL1 sdf case | `sim/AsyncRouterL1/testbench/cases/smoke_directed_sdf.case` |
| RouterL1 DUT E2E probe | `GLS_E2E_PROBE=1` / stage `sdf_routerl1_probe`；默认 src=0 dst=4 |
| RouterL1 combo budget | `scripts/asic_dc/timing/run_dc_routerl1_combo_budget.tcl` + `run_dc_r1_combo_budget.py` → `combo_budget_bypass.csv` |
| NoC16 sdf case | `sim/AsyncNoC/testbench/small_cases/noc16_00_to_33_3flit_sdf.case` |
| NoC16 power | `scripts/asic_dc/power/run_ptpx_noc16_power.tcl` |
| 集群工程根 | `~/Asynchronous_Router` |

---

## 6. 迭代日志

| 日期 | 摘要 | 结果 |
|------|------|------|
| 2026-07-23 | 握手域：回退 C+A+B；仅 Dreq=0；VCTM+DC+bypass+SDF | VCTM PASS avg=82.8ns；DEL **73→61**；Dreq **NA**；reqGen **0.96ns**；SDF 9/9 PASS `T_router=59` |
| 2026-07-23 | reqGen A+B：`canLaunch` + eligibility 浅化；DC+bypass+SDF+VCTM | 功能 PASS；reqGen **0.97ns≈基线0.96**；**已回退** |
| 2026-07-23 | Path B 步骤一：bypass STA（leaf `DEL*/I` + disable DEL arcs） | **6/6**；热点 reqGen **0.96ns**；VC 0.35；demux 0.30；3/6 needs_opt vs DEL100；**未改 RTL** |
| 2026-07-23 | 试探 1×**DEL100**；RouterL1 重综合 + SDF GLS | **FAIL** delivered=2/9；PW≈0.25–0.31ns；SDF≈0.17ns；**已恢复 DEL150** |
| 2026-07-23 | 试探 1×**DEL150**；RouterL1 重综合 + SDF GLS | **PASS** 9/9；`E2E_EDGE=2.356ns`；PW≈0.33–0.39ns；**保留 DEL150** |
| 2026-07-23 | Per-domain Delay + `canLaunch`；`P150_BASELINE` | **PASS** 9/9；`DEL150=61`；`E2E_EDGE=2.226ns`；wrapper `T_router=59ns` |
| 2026-07-23 | `P100_SHORT_ONLY`（FIFO/OPM/context/priority→DEL100） | **FAIL** delivered=8/9；首 flit `E2E_EDGE=2.066ns`；状态/输出短脉冲过激 |
| 2026-07-23 | `P100_FORWARD_SHORT`（FIFO/OPM→DEL100） | **FAIL** delivered=8/9；OPM fire high≈0.264ns；输出域 DEL100 不够稳 |
| 2026-07-23 | `P100_FIFO_ONLY`（仅 FIFO Dfire→DEL100） | **PASS** 9/9；`DEL100=12 DEL150=49`；`E2E_EDGE=2.147ns`；当前推荐 profile |
| 2026-07-23 | RouterL1 reqGen segment STA（当前 `P100_FIFO_ONLY` DDC） | 已生成 `reqgen_segment_timing.csv`/`reqgen_segment_*.rpt`；总 cone **0.980ns**，到 `io_destMask_0_*` **0.940ns**，内部 `routeSelector/requestMask/eligibility` 边界已被 DC 优化掉；下一步优先优化 `InputControlModule` 内 destMask/route/lane mask 生成 |
| 2026-07-23 | 试探 1×**DEL075**；RouterL1 重综合 + SDF GLS | **FAIL** delivered=0；PW≈0.22ns；SDF≈0.14ns；已恢复后改试 DEL150 |
| 2026-07-23 | ASIC Delay flat 4→**1**（DEL250）；重综合 RouterL1；SDF GLS + `GLS_PW` | `DEL=73`；9/9+1pkt PASS；`E2E_EDGE=3.349ns`；典型 high≈0.5ns |
| 2026-07-23 | DC combo budget：分段 `report_timing` 到前向 Delay `I`；写 CSV + D_min；对照 2ns | covered **6/6**；`T_E2E,lb≈34.3ns`；**仅缩 Delay 达不到 2ns** |
| 2026-07-23 | RouterL1 TB 增加 DUT 边界 Head E2E probe（对齐 NoC16 `E2E_EDGE_*`）；默认 0→4 | `sdf_routerl1_probe` PASS：`E2E_EDGE_*=10.024ns`；静态 6×Delay≈9ns 同量级；`T_router=69ns` 多为 wrapper |
| 2026-07-22 | 加 RouterL1 门级 probe，定位 tail 缺失 | tail 外部 Ack 完成但无 demux launch；body 有二次 launch clock，上游 fork 相位被污染 |
| 2026-07-22 | 修复 `AsyncForkRequestBlock`：用 `launchedReq` 记录已启动 input Req，并阻止同 Req 重复翻 outReq | RouterL1 func 9/9 PASS；RouterL1 SDF `smoke_sdf_1pkt` 3/3 PASS；`smoke_directed_sdf` 9/9 PASS |
| 2026-07-22 | 修复 `run_gls_smoke.sh` 空数组在 `set -u` 下展开失败 | 默认不开 probe 的 SDF smoke 可正常运行 |
| 2026-07-22 | 重新生成/重综合 NoC16，并跑 NoC16 GLS smoke | NoC16 DC GTECH=0；func 宽间隔 case PASS，`T_noc=90ns`；SDF `noc16_00_to_33_3flit_sdf` PASS，`T_noc=110ns` |
| 2026-07-22 | 新增 NoC16 SDF VCD dump 和 PT PX time-based 功耗脚本 | VCD 100% annotated；150–350ns 窗口 `Total Power=3.494e-03 W` |
| 2026-07-22 | 全门级：DEL250 + AsyncDelay flat4；sdf identity；加宽 sdf case | 修复前 R1 sdf 6/9（无 tail）；func PASS；无行为 `#` |
| 2026-07-22 | 试验 floor/scale/flat8、PacketContext/OPM clear 变体 | 均未能送达 tail；确认非单纯脉宽 |
| 2026-07-21 | sdf Mutex 门级 + Delay `#(1.0)` | R1/N16 PASS，`T_*` 含人工 Delay |
| 2026-07-21 | 建立本文档 | 见上 |

---

## 7. 更新检查清单（每次迭代）

- [x] 更新「1. 当前状态」
- [x] 已关闭项写入「2」；新阻塞写入「3」
- [x] 「6. 迭代日志」追加
- [x] `最后更新` 日期
- [x] 同步 `scripts/asic_dc/sim_gls/README.md`
