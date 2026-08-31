# bug确定方法论

之前的低注入定位分为两层。

1. 先确认现象属于功能还是物理时序

- 冻结同一份 post-DC 网表、SDF 与 case，记录 hash；诊断不重新综合、不改 DUT。
- TB 不会在首个 mismatch 处结束，而是持续到原始 timeout。
- 每个接收 flit 写入 `checker_full.log`：端口、时刻、实际值、匹配的 expected 项；最终还写出所有 missing、unexpected、每端口 TX cursor、Req/Ack 和 RX 统计。
- 同时筛选 `run.log` 中的 `$setup`、`$hold`、`Timing Violation`、`IFNSDFA`。

当时由此得出的关键结论是：V2 latch 的 D 在关闭前就已经错误，且没有 runtime setup/hold；因此不是“数据晚到”，而是上游出现了两个 MG/PPE 同时有效。

2. 再沿控制链逐层追溯

当时 TB 在 `ASYNC_NOC16_ULTRA_TRACE` 条件编译下增加了只读层次 probe 和窄 VCD。它不参与注入、Ack 或 Router 控制，只记录：

```text
输入/IPM：ReqX、rawRS
Atomic：P、packetActive、packetMask、owner、
        arbReq、anchorGrant、roundClose、seen、
        txValid、txWinner、txMask、fire
ReqGen：admittedRS、Req、Ack、Done、PPE、Grant、MG
OPM：四路 MG/DataX、V2 data latch D/E/Q、L5 D/E/Q、close、ReqOut/AckOut
```

低注入时正是这条链证明：

```text
P/mask 已清零
但 packetActive 残留为 1
→ 新 Head 借用了旧 active
→ admittedRS 错误拉高
→ 两个 ReqGen PPE 同时建立
→ 同一 OPM 的 MG=1100
→ one-hot Mux 实际做 OR，产生错误数据
```

所以最后修复的是 Atomic V2 的 transaction fire/lifecycle 一致性，以及 Tail 的 `tailReleaseReady` barrier；不是改 OPM 或延长 TB Ack。修复后同一 NoC16 SDF 下 r0p02 TAB 与 VCTM 都 PASS。

当前 r0p10 可直接复用的流程是：

```text
冻结当前 r0p10 post-DC netlist/SDF
→ 保持 checker 跑到 timeout
→ 先用 wrapper tx_cursor 找到最早未被 Ack 的 packet/flit
→ 只为该 packet 的源、目标路径开启窄 trace/VCD
→ 依次检查：
   OPM Ack
   → ReqGen Done↓
   → TailJoin allTailPassed
   → Atomic release transaction/fire
   → packetPresent/Active/mask/owner 清零
   → tailReleaseReady↑
   → AckGenerator complete/CP
   → AckX↑
   → V1 latch_en 打开
```

当前已有的 TB/runner 基础也可复用：

- [tb_noc16_async_axi_bram.sv](D:\NoC\asynchronous_fat_tree_multicast\sim\AsyncNoC\testbench\tb_noc16_async_axi_bram.sv) 已具备完整 checker、timeout 后统计，以及 `ASYNC_NOC16_ULTRA_TRACE` 的层次 probe 框架。
- [run_remote_ultra_noc16_sdf.py](D:\NoC\asynchronous_fat_tree_multicast\scripts\asic_dc\ultra\run_remote_ultra_noc16_sdf.py) 已支持复用冻结的 DC/SDF，并以 `ULTRA_NOC16_ENABLE_TAB_TRACE=1` 开启 TAB trace。
- 同一份 canonical AXI/BRAM wrapper、case parser、scoreboard 和严格 SDF 命令保持不变。

但不能直接使用旧 packet19 的 probe 名称：它硬编码的是 `routerL1_1_0 / outputModules_2` 的 core2→core6 数据混合路径；r0p10 当前首个可疑停滞是 core6 的 packet89，需要按其真实路由路径重新绑定 source、OPM local-source 与 Atomic input。方法完全相同，观察对象要换。