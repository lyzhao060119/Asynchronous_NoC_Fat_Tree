# 单 Router 聚合对照实验

本实验独立于 PROP M16，不改变原有网络默认配置。

| 对象 | 几何 | IPM/OPM 数 | OPM Mutex 宽度 |
|---|---|---:|---|
| Tree L1 | c1p4 | 8 | 7、4 |
| Tree L2 | c4p16 | 32 | 28、16 |
| Tree L3 | c16p16 | 80 | 64 |
| Mesh Router | dir16/local16 | 80 | 64 |

64 节点树由 16 L1、4 L2、1 L3 构成：21 Router、336 IPM、336 OPM、896 LanePhaseAdapter，64 核心端口和16顶部端口。顶部端口空闲时是64节点封闭树实验。

Mesh 本轮是单 Router；local16 为并行本地 lane，不代表已有16个可独立寻址的核心，不能直接据此生成64核心 Mesh。

## 发射与综合

- 独立发射入口：`NoC.CMR.CMRWideGeometryMain l1|l2|l3|mesh <target>`。
- 分层树：`Router_Architecture.CMR.CMRSplitNetworkEmitMain wide_tree64 <target>`。
- sbt 启动前设置 `JDK_JAVA_OPTIONS=-Xmx6g`；该机器的 launcher 不支持 `-J-Xmx6G` 形式。
- 分层产物必须先通过 `scripts/asic_dc/cmr/check_split_emit.py`。
- `run_wide_router_dc.py stage`：结构检查、源码/输入哈希、上传隔离 campaign。
- `run_wide_router_dc.py singles`：提交四个单 Router；已有 job record 时不重复提交。
- `run_wide_router_dc.py network`：分批 child DC，通过后才 stitch。
- `run_wide_router_dc.py status`：读取调度器、bpeek及产物状态。
- `run_wide_router_hop.py`：依赖单 Router DC 完成的严格 MAXIMUM-SDF 测量。

以上 Python 使用 `D:\anaconda\python.exe`。远程 campaign 为 `Asynchronous_Router_CMR/campaigns/20261029_wide_router_tt_r1`；本地只保留 manifest、摘要、报告和小 CSV，不下载 DDC/SDF/波形。

## 判定口径

工艺为 TT/0.8 V/25℃，Tree RCU DEL100，Mesh DEL150，沿用当前 IPM/OPM/LaneSelector 综合器件配方。新28/64路 Mutex 使用精确宽度的二叉 TAC，原有宽度实现不变。功能测试通过不能替代门级或模拟亚稳态验证。

面积来自综合后 `report_area -hierarchy`，同时保存 reference 和产物哈希。单跳时间沿用既有 TB 的输入 Req 翻转到输出 Req 翻转定义，5 flit，无竞争，分别报告 Head/Body/Tail；不把接收 capture 延迟算作传播延时。库 notifier 保持开启，出现 timing violation、X、数据错误或标注错误均不验收。

DC 的无时钟诊断 report_timing 不等价于异步时序签核；不得以其 WNS 推断完整安全性。64树延迟仍需网络事件仿真，不能用单 Router 延迟简单乘层数代替。

宽 Router 需要超过32端口的结构统计；child/stitch 检查已去除固定32的上限。必须核对完整端口与实际 TAC 实例，不能把旧 c1p4 结果外推至 c16p16。

## 当前证据

2026-10-29：Scala 编译通过；16/28/64路 Mutex 定向功能测试得到 `TB_RESULT PASS wide_mutex`；四个单 Router 发射完成；64树21/21 child 发射及端口对照审计通过。综合、门级延迟和面积验收以本轮远程实际产物为准，尚未据此宣称完成。

首轮 r1 在活动 DC 期间重复解包输入，随后 L1 出现 Tcl `missing close-brace`，本地同一脚本 `info complete` 为1。运行中替换流式读取脚本是疑似原因，r1 已作废并停止其剩余任务，保留原日志。正式重跑使用独立 `20261029_wide_router_tt_r2`：先完整上传单体和网络输入，再提交；`stage` 已增加提交后拒绝覆盖的保护。用环境变量 `CMR_WIDE_CAMPAIGN` 选择 r2，禁止对 r2 活动输入再次解包。

后续审计修正：r2 单体再次报错，而层次 child 成功。实际远程脚本与初始 manifest 的差异仅为 CRLF→LF，层次 runner 自带 `sed` 规范化而单体先启动。另有一处对空 AOI22 集合调用 `set_dont_touch` 的 CMD-036。不能把 r2 单体失败认定为 RTL 根因，也不再采用此前未证实的“解包竞态”解释。r3 在打包时统一文本 LF，并跳过空集合命令；远程脚本哈希与 manifest 一致。r3 L1 已取得无 Error 的综合 PASS、非空三项产物及面积16654.344008 µm²。r1/r2 保留诊断证据，后续统一使用 `CMR_WIDE_CAMPAIGN=20261029_wide_router_tt_r3`。

`collect_wide_router_results.py` 只拉取小型报告和 CSV，分别审计 DC、产物哈希、面积、单跳严格 SDF、网络严格 SDF。`run_wide_tree64_gls.py --prepare-only` 已验证482个顶层信号（含时钟/复位）、远程既有 M5 seed202701 的55000个输入 flit及核心目的掩码；该 case 原 PFAT top8 标签保留，DUT 的16顶部输入保持空闲。不得在 stitch 通过前提交正式网络仿真。

r3 L1 最终小型审计已通过：三项产物 SHA-256 复核、综合零 Error、严格 MAXIMUM-SDF 零标注错误/时序违规、5/5 flit 正确。无竞争单跳 Head/Body均值/Tail 为1.422/0.864/1.013 ns，cycle1.278 ns。仿真入口 v2 在启用 `set -u` 前完成 shell 环境初始化；v1 环境早退记录保留，不计 DUT 失败。其余几何及64网络仍须逐项取得自己的结果，不外推 L1 数据。

### 宽归约树配方 r4

r3 的16个 L1 child 均完成独立面积/产物/错误/哈希审计。L2 随后停在旧器件配方的固定 XNR4 数量检查：实际192，旧式 `2 × OPM数` 期望64。RTL 中 `ReqSelection.xorR`、`Ackout.xorR` 随来源数量扩展归约树，不能把窄 OPM 的固定门数当作所有几何的结构不变量。

r4 为每个 OPM 保存来源数和实际 XNR4 清单，只对既有等价门做 D0→D2 sizing，数量/极性/连接不变；原<=20来源几何仍走原固定数量检查。宽 Router 在配方前保存 `*_mapped_pre_recipe.ddc`，后续失败诊断可用该映射检查点。

当前候选改为 `CMR_WIDE_CAMPAIGN=20261029_wide_router_tt_r4`。`import_wide_l1.py` 只复用 r3 的单 L1 和16个 L1 child：核对全部 RTL/库输入哈希、原始 PASS/零 Error 和复制前后三项产物哈希，写入 `import_provenance.json`。源产物保留，L2/L3/Mesh 不准通过该入口复用。CSV 区分 `dc_method=imported/compiled` 与 `dc_source_run`，不能把复用标成新执行的综合。r4 的独立 L2/L3/Mesh、网络4个 L2和1个 L3 均需自己的综合及仿真结果。

### Tcl 后处理补跑与 L2 验收

r4 单体 L2 在宽器件配方通过后，仍于普通 `-f` 的后续 if 语句报 `missing close-brace`；实际远程 LF 文件与 manifest 哈希一致，不能继续将其唯一归因于 CRLF。相同冻结脚本用于层次 L2 时通过，具体读取差异尚未唯一定位。

`replay_wide_router_recipe.py l2 replay2` 从本轮 `CMRRouter_mapped_pre_recipe.ddc` 恢复，绝对路径启动 bootstrap，先完整读取 LF Tcl，再 `uplevel #0` 执行，并保存 errorInfo。只重做等价器件配方及导出，不再运行 compile。补跑脚本用字节方式落盘；前一次 Windows 换行导致的坏 shebang 启动记录保留。补跑必须确认上一候选已终止，核对映射输入与上传脚本哈希。

L2 `20261029_wide_router_tt_r4_l2_replay2` 已综合后处理通过：面积110283.767557 µm²；严格 MAXIMUM-SDF 无竞争5-flit单跳 Head/Body均值/Tail 为2.248/1.071/1.076 ns，cycle1.579 ns。补跑 run 与原映射来源 run 分别记录，不能把该时间混作整网延迟或带载吞吐率。网络已有20/21个 child 完成审计，最后的 L3 及网络 stitch/GLS 仍须各自验收。

## r4 宽 OPM 运行诊断（2026-10-29）

四个独立 Router 的 DC 产物已通过当前产物审计；L1/L2 严格 MAXIMUM-SDF 为5/5，L3/Mesh 仅首个 Head 正确，随后出现重复输出请求与数据不匹配。因此 L3/Mesh 延迟仍不具备验收资格，不能用首个 Head 延迟代替通过结果。

只读 DDC inventory 确认 L3 `OutputPortModules_79` 的 Ack 状态寄存器源0为 `FF0_FF3_0_reg`（DFCNQOPTMAD8），其 CP 驱动为 INVD1；Reqout CP 驱动为 OA221D0。这是实际连接证据，不代表已证明失败根因。独立诊断作业15715401保留严格标注与原检查，额外记录 Req/Ack/CP/D/Q/reset，在220 ns停止以避免重复错误淹没日志。分析期间不改变 DUT 或接收采样时间。

64节点树21/21 child 审计通过；stitch作业15686601仍在运行，最终网络面积与延迟等待最终产物和后仿真验收。

诊断15715401已完成：212.266 ns首次 Reqout CP 上升，212.417 ns下降；其后212.566 ns再次上升。但源0 Ack DFF CP 在整个209–220 ns观察窗内保持1，D已为1而Q保持0。证据支持先验证反相时钟支路的驱动/脉冲传递；尚不能据此宣布所有失败均已解释。小型事件日志保存为本地 `l3_click_probe_v1.log`，无波形下载。

新增 `size_wide_ack_clock.py`：从冻结的最终 DDC 读取每个OPM源0 Ack寄存器CP的实际驱动，要求其为同极性INVD后统一替换INVD6（80处），不compile、不改方程/连线，独立输出DDC/网表/SDF、面积及替换清单。L3试验作业15716101已确认RUN；原候选保留，需通过结构审计和原严格SDF后才允许采用。Mesh暂不盲目推广。

L3 INVD6候选严格后仿真15716501最终FAIL：5个输出事件但5次数据不匹配，不计作延迟验收。候选面积545246.852107 µm²（原545179.652106），只增加67.2 µm²。诊断15717101确认Ack CP开始翻转，212.507 ns上升、Ack Q于212.546 ns更新；Reqout CP却在212.590 ns再次上升，早于下一次输入Req（213.276 ns）。因此初始时钟脉冲传递问题有所改善，但反馈收敛/重新开启竞争仍未消除。不得把该候选采用到网络。进一步探针从report_cell实际输入网名绑定Fire门输入，以定位反馈竞争窗口；不凭网名猜测RTL含义。

汇总器的大报告有界下载修正：超过20 MB只取尾部会漏掉开头Total cell area；现在远程单独提取该字段与完整Error扫描，再附有界尾部，不下载大报告全量。

64节点树stitch 15686601完成验收：`CMR_NOC64_DC_PASS ... routers=21 ipm=336 adapters=896 fifos=0`，无工具Error；DDC 581279744 B、post-netlist 161126402 B、SDF 1122714923 B，三项哈希全部核验通过，21/21 child有效。最终综合面积1253027.658451 µm²。这仅为DC验收，不是时序闭环或网络延迟通过。

网络严格SDF作业15721401已确认RUN（4槽），原样使用远程M5/seed202701 case。此网络为原r4 stitch，不包含未通过的INVD6试验。与之并行的L3控制门输入探针15720301曾因CPU负载被调度器SSUSP，随后已恢复RUN，未重启。大综合日志的GLS提交门槛已改为远程全量Error/PASS扫描与产物哈希校验，避免下载完整日志。

网络M5严格MAX-SDF作业15721401已EXIT：79.238 ns在核心端口49触发首个unexpected/corrupted flit，captured=0x8604606，原fail-fast终止，`PROP_TEMP64_GLS_FAIL protocol, timing, or scoreboard error`。因此网络面积/DC有效，网络延迟仍不验收。该失败使用原r4网络（无INVD6改动）；不能未探查就把网络首错等同于单Router故障。L3实际Fire门输入探针15720301仍由LSF报告RUN，保留原句柄等待，不复制重启。

后续单变量试验：INVD32，从原始r4 L3最终DDC重新开始（不从INVD6失败候选叠加），仍仅替换80个实际Ack时钟反相器，不compile、不改网络或RTL。作业15722201已提交；`wait_wide_ack_clock.py l3 32`在确切作业DONE后核对80处映射、全量工具Error和三项哈希，再自动提交原严格hop测试。仅作为试验，不宣布修复或推广。

INVD32候选15722201明确工具FAIL（UID-109目标lib_cell不存在、CMD-036），未进入仿真；已终止其无效导出，保留失败输入/日志。先前对可用档位的判断有误，不能把它计作有效优化。新脚本在首次替换前要求get_lib_cells精确命中1个目标，并逐次核对ref_name，避免size_cell命令失败后仍输出PASS。INVD24为实际库清单中存在的档位，从原冻结DDC重新生成候选15722301；独立等待/审计/严格SDF派发器已运行。

探针健康检查15722401通过LSF在node3只读执行ps：15720301对应vcs1 PID116802仍存活，状态SN，CPU累计127 s，wchan=futex_wait_queue_me；没有据此认定终止或复制重启。INVD24候选15722301仍RUN，工具产生NLE-033 dont_use警告，单独记录，不能将该警告当作Error或忽略其采用限制。自动派发器86640（本地会话）继续等待确切候选终态与产物审计。

首错位置纠正：原始run.log最先出现的`TB_MATCH_FAIL_NOW`为port53/slot41/flit0x8614616。之前port49来自fail-fast在停止后遍历未匹配槽的快照，不能称为首错端口或根因。端口53由实际localCoreIndex=(x+8*y)对应(5,6)，连接L1(2,3)的child方向1；这是检测边界，不等于首个出错Router。早期同头候选为源50、packet129、计划8ns，必须结合逐跳Body/Req/Ack确认，不能只凭重复Head字值绑定包。

按用户要求先定位Router：已停止本地INVD24自动验收/派发器PID42632，不继续提交器件实验。网络只读定位作业15722801已确认RUN，原r4网络/原M5 case/原严格SDF与断言不变；额外监测全部21 Router、672输入输出接口，记录Req事件、100ps采样和pending期间Data变化，85ns诊断上限，不声称性能PASS。保留所有原始失败记录。

首错Router定位已取得真实边界证据（15722801 DONE）：原始与重放first TB_MATCH_FAIL_NOW均为port53/slot41/0x8614616；原case、网表、SDF、adapter、TB、fail-fast哈希全部一致，SDF annotation errors=0，warnings119825另列。source50/packet129的5个flit完整经过L1(1,3)、L2(0,1)并进入L3输入47。L3输出15于34.279 ns发Head、34.838 ns再次发同一Head，之后观察窗内共71次Head，无对应Body/Tail。下游L2(1,1)/L1(2,3)已收到重复Head。因此对首个scoreboard失败包，首个产生序列分歧的Router确定为L3(0,0)，不是末端L1。内部根因仍需针对IPM47 branch0 -> adapter188 lane15 -> OPM15 source31探查；实际综合网表内部可能有external包装层，须重新绑定，不外推单体OPM79/source0。详见结果目录network_first_router_localization.md。

## 网络OPM15 Mutex专项诊断结论（15732701）

只读重放原r4网络、原M5，42 ns结束诊断，不声称全case PASS。SDF标注errors=0，warnings119825独立保留。实际层次为routerL3/external/OutputPortModules_15，已从post-netlist重新绑定；跟踪64路req/grant/MG、根节点、source31子树以及该来源Req/Ack/CP。

83条动态快照（32.112–41.874 ns）显示：仅source31有请求；Grant于33.597 ns置位source31，MG于33.724 ns置位source31，此后均稳定；全局Grant始终onehot0，无X，各TAC路径在仲裁完成后无撤销/切换。因此当前首错没有Mutex竞争或Grant不互斥证据，不能继续以Mutex根因为前提修改。

实际故障：RegEnable/Reqout CP于34.082 ns上升、34.233 ns下降，151 ps高脉冲；source31 Ack FF的CP全窗恒1，Ackout恒0。真实连接中该CP由INVD1驱动，其输入正是Reqout FF CP公共RegEnable网。SDF TIMESCALE=1ns，该反相器IOPATH I->ZN rise=174ps、fall MAX=169ps，实际观察到151ps脉冲未传递。下游Ackin于34.543ns返回，RegEnable于34.655ns再次开启；原请求尚未内部确认，IPM/adapter仍保持Head，于34.838ns输出重复Head。

这确定了当前优先保护位置是Ackout反相时钟支路；不等于已签核Mutex其他多请求场景。网表还将Ack时钟分成多条实际驱动支路：本次source31使用U72/INVD1，而先前单体source0试验检查的是另一支路。后续必须枚举全部Ack FF CP实际驱动，不能仅改每OPM的source0驱动然后外推。未做新的硬件修改。

小型证据：network_mutex15_events.csv、network_mutex15_inventory.json、network_mutex15_ack_clock_sdf_excerpt.txt、network_mutex15_diagnostic_summary.json。原始大产物仍在远程。

用户授权加强保护后，新增分析独立recipe `apply_cmr_wide_ack_clock_protection.tcl`。从原冻结DDC进行等价器件重映射/重新导出，不改RTL、TAC或握手。逐一绑定全部80×64=5120 Ackout FF，按实际CP驱动去重后增强到库中存在的INVD24；要求所有分支直接反相同一Reqout FF CP Fire参考，目标存在且替换ref一致。source0单支路试验不再作为覆盖依据。

L3候选20261029_wide_router_tt_r4_l3_ackall24_r1，作业15735101，已确认RUN，并取得 `CMR_WIDE_ACK_CLOCK_PROTECT_PASS opm=80 states=5120 branches=240`。这仅证明补强覆盖；正在导出产物，完整Error/哈希/覆盖CSV审计后自动提交原严格5flit hop SDF。NLE-033 dont_use警告保留，尚未采用此候选。单体通过后才推广Mesh和网络。

### 公共Fire与反相时钟的配套保护

上述all-branch候选15735101已完成产物审计，面积546107.012062 µm²，但严格hop 15736001 FAIL（只交付1/5）。定向探针15736201确认Ack CP已能拉低，公共Fire却一直为高：INVD24增加公共Fire负载，而上一级仍为OA221D0；原始Reqout反馈关闭未能在下游Ack返回前形成有效关闭事件。因此不能仅凭Ack分支尺寸与覆盖通过采用候选。

新balanced候选从原始冻结DDC重新开始：全部240个Ack反相驱动使用INVD24；公共Fire末级使用实际库存在的OA221D4（若不存在则要求OA221D2）；现有输出OPMDelay由DEL050换为DEL250，保留BUFFD0。内部反馈继续使用原始Reqout，不在Ackin插入延迟，不改方程或TAC。记录每个OPM的旧/新Fire和输出器件，必须80/80命中。此轮为等价器件sizing/重导出，不冒称重新执行RTL逻辑compile。

`20261029_wide_router_tt_r4_l3_balanced24_req250_r1`（DC 15736801）已完成80 OPM/5120状态/240支路覆盖和DDC/post/SDF哈希审计；严格MAXIMUM-SDF hop 15737901已确认RUN。仍为待验收候选，输出延迟增加后的单跳时间必须重新测量。Mesh与网络暂未采用，先等待L3结果。

`run_wide_tree64_gls.py`现在支持single_jobs.json中显式选择的tree64候选；每候选使用独立提交记录、TB目录和LSF日志，原始失败run保留。仍须核对完整DC错误、产物哈希与21个原child审计，并原样使用相同远程M5 case。此入口准备完成不等于已提交或网络通过。

balanced严格hop 15737901最终交付5/5、PPA_RESULT PASS，但检测到TailPassed_0_FF_reg setuphold违规（D=218664ps，CP=218673ps，库setup=27ps、hold=4ps），所以LSF EXIT、严格验收FAIL。不能用scoreboard PASS替代库检查。Head/Body/Tail=2.583/1.236/1.172ns仅作为失败候选诊断值。

下一轮balancedtail继续从原始冻结DDC开始，保留上述Fire/Ack/输出保护，仅将现有每源TailCaptureDelay从DEL050改为DEL150（80×64=5120处），不新增状态或改变TailDetectorReset。增加独立CSV逐来源核对，其他类保持不变；需要重新验证Tail捕获、Grant/reset及原严格hop，不能凭延迟标称值宣布通过。

balancedtail候选DC 15739101已PASS；严格MAXIMUM-SDF hop 15742801最终DONE，取得`WIDE_HOP_STRICT_PASS kind=l3`。完整run.log远程扫描无Timing violation/PPA_FAIL/Error/Fatal，SDF annotation errors=0（warnings60502单列保留），事件CSV为5行数据。Head/Body/Tail=2.583/1.236/1.172 ns，cycle=1.765 ns。此前TailPassed setup违规在本次相同测试中未再出现。验收范围仅为单体L3 source0到OPM79的无竞争5-flit单跳；不据此宣称80个OPM全场景STA或64节点网络闭环。小型远程审计记录为`l3_tail150_strict_remote_audit.txt`。

用户授权64节点接线综合与测试后，提交`20261029_wide_router_tt_r4_tree64_balanced24_req250_tail150_r1`，DC作业15747501已确认RUN。读取原完整21-Router网络冻结DDC，在routerL3/external的实际负载下应用与单体相同的Ack/Fire/输出/Tail捕获保护；L1/L2接线及器件保留。此轮属于完整映射网表的等价器件处理与重新导出，不是重新执行所有child的RTL compile。原网络与失败证据不覆盖。

`wait_wide_ack_all.py tree64 balancedtail`等待确切DC终态，完成5120 Ack状态、240物理分支、80 Fire/输出、5120 Tail保护及三项产物哈希审计后，自动调用网络GLS入口。原M5/seed202701、1ns tick、100ps RX capture及fail-fast保持原要求，候选使用独立目录和提交记录。canonical case改为远程解析/哈希，仅返回计数与SHA摘要，避免下载原始case；必须与既有network_case_audit.json哈希一致。网络尚未取得本候选的仿真结果。

网络保护DC 15747501最终DONE，取得`CMR_NOC64_DC_PASS`与完整保护覆盖PASS；DDC/post/SDF SHA全部核验OK。原本地等待器的1小时观察上限先于网络处理完成而退出，导致自动GLS未派发；已从DONE后的审计继续执行，未重跑DC。等待上限改为12小时，观察超时仍只报告并保留原作业，不重复提交综合。实际SDF状态以独立network_gls候选记录及最终工具标记为准。

网络严格M5作业15750801最终EXIT/FAIL：109.635ns终止，首个`TB_MATCH_FAIL_NOW`仍为port53/slot41/0x8614616。停止后快照中的port2不是首错。完整run.log中Timing violation计数为0，SDF annotation errors=0、warnings119825；因此只能确认本次没有记录库违规，不能将scoreboard失败当作保护已有效。相同Head字值也不单独证明原包或原故障链完全相同，需新网表逐跳复查。原大日志留远程，小型摘要为network_balancedtail_failure_excerpt.txt。

`trace_wide_network_routers.py --selected`支持从当前选中的网络候选及其GLS记录绑定网表/SDF/case，使用独立目录和提交记录，125ns诊断上限；保留原fail-fast与100ps采样，监测全部21 Router/672边界。不得复用原网表85ns观察窗来判断当前109.635ns失败，也不得据诊断结束标志宣称case通过。

新候选逐跳诊断15766301完成，确认首错已移至L2(1,1)输出11。L3输入47、输出15和L2(1,1)输入31均完整交付source50/packet129的五flit序列；L2输出11却出现116个同Head捕获事件，无该包Body/Tail，随后L1(2,3)输出1/core53看到43个Head。时间和完整证据见`network_balancedtail_first_router.md`及`network_balancedtail_backtrace.json`。当前L3保护在该路径上有效，不能再将本次整网FAIL说成L3仍重复Head。单体L2先前仅测试parent输出31，不覆盖当前child输出11；后续须探查这个实际输出的IPM/adapter/OPM路径，不能把边界定位直接当作内部器件根因。

L2内部只读诊断15771501完成。实际绑定IPM31 branch2 -> adapter126 lane3 -> OPM11 source27（28来源）。Grant于35.747ns选source27、MG于35.873ns选中，之后稳定且onehot0。Ack D于35.961ns置1；RegEnable于36.245ns上升、36.392ns下降，高脉冲147ps。Ack CP全窗恒1，CDN全窗恒1（复位已释放），Ack Q/sourceAck全窗恒0。实际U6/INVD1直接负载56，SDF fall MAX201ps、rise MAX209ps，脉冲未传到Ack时钟。输出Req36.441ns、下游Ack36.705ns、再次Fire36.815ns、重复Req36.997ns。由此确认当前故障为OPM内部Ack时钟未捕获，adapter/IPM因未收到确认保持Head；本次没有Mutex多高/撤销证据。详见`network_l2_internal_root_cause.md`。保护应配套核对公共Fire驱动和Ack分支、输出重开及Tail捕获，不能只放大末级反相器后忽略上游负载。

## L2采用L3配套保护

用户授权采用相同方式后，`protect_wide_tree64_l2.py submit`从已冻结的L3保护网络DDC出发，提交候选`20261029_wide_router_tt_r4_tree64_l2l3_balanced24_req250_tail150_r1`，DC 15774201已确认RUN。只对4个L2施加同极性Ack INVD24、Fire OA221D4（库无D4时显式D2）、原输出DEL250和原TailCapture DEL150，保留BUFFD0、原始Reqout内部反馈、L3保护及L1器件。属于完整网表等价器件处理/重导出，不修改RTL或重新compile全部逻辑。

L2覆盖不是每OPM固定64来源：每Router的16个child输出各28来源、16个parent输出各16来源，共704状态；4个Router合计128 OPM、2816 Ack/Tail状态。通用Tcl新增auto来源目录，逐项检查端口连续性；审计器另按实际几何核对来源数，不将枚举结果自证为覆盖通过。每个Router独立CSV记录Ack分支、Fire/输出和Tail映射。延迟叶单元目录现在按Router一次收集后局部筛选，避免为每个源反复扫描完整网表；仍逐单元验证替换ref。

`protect_wide_tree64_l2.py watch`等待确切作业终态，检查4份OPM/状态/物理支路覆盖、全量工具Error、DDC/post/SDF哈希后选择候选，自动提交原M5严格网络SDF。未通过任何门槛则停止派发，原失败产物保留。当前状态只是已运行，尚无新候选SDF PASS。

15774201在L2(0,0)/OPM16触发`non-inverter Ack clock ... OAI221D2`并停止，未生成可验收候选、未派发SDF。child输出与parent输出映射不同，不能将L3反相器配方无条件套用全L2。r2从原L3保护DDC重新开始，仅处理4个L2的child OPM0–15（64 OPM、1792 Ack/Tail状态），包括已证实故障的OPM11；parent输出保留原映射且不计为本轮保护通过。新DC 15797701，独立记录`tree64_l2_child_protection_r2_job.json`；审计和原M5严格SDF流程保留，失败r1产物不覆盖。

DC 15797701最终DONE；r2覆盖审计通过64 OPM/1792 Ack及Tail状态/64物理Ack支路，DDC/post/SDF三项SHA核对OK。自动提交严格MAXIMUM-SDF原M5/seed202701作业15799101；当前尚未取得该候选完整case PASS。SDF导出1122709755字节，原大产物仍留远程。

严格M5 15799101最终EXIT：320.412ns首错`port=2 slot=10 flit=8000003`，停止快照判为期望core0的数据到达core2。完整run.log Timing violation=0，annotation errors=0/warnings119825。前一port53首错未先出现，但不能据此宣布该包已完整正确或整体保护完成。新只读边界诊断15799501从同一候选重放，观察上限350ns，保留fail-fast，重新定位新首错的路由路径。`0x8000003`在完整case中有82处匹配，必须结合早期时间及Body标识，不能只凭Head绑定源包。

15799501复现相同首错：source11/packet23（计划299ns，Body0017343/0017543）于319.150ns进入L1(1,0)输入0，320.412ns从本地输出3送core2，目的应为core0。网表结构审计发现stitch同名内部设计冲突：L1(1,0)外层external ref为正确坐标x1_y0，但其IPM/RCU/RouteComputationLogic未全部被uniquify重命名；最终网络的该RouteComputationLogic所有单元/连线与独立child x0_y0完全相同，与独立child x1_y0不同（network_coordinate_collision_audit.json）。这是拼接时错误共用坐标专用逻辑，不是延迟短缺；不能继续以加DEL修复。

新增namespace_wide_children.py：从每个原独立child冻结DDC出发，用工具支持的rename_design -prefix/-update_links/-dont_link_with_original_name为全部内部design加唯一命名空间，保留顶层ref及所有instance/接口；rename前后leaf数量必须一致、所有内部design必须带对应child前缀、link必须成功。独立DDC中应用已确认的L3及L2 child保护，再导出新的namespaced DDC。原DDC及失败网络不覆盖。先验证x1_y0 pilot，再扩展21child及重新stitch；新网络必须额外验证各坐标RCU与对应原child的一致性，不能只用IPM数量/未解析引用为零代替接线语义审计。

pilot 15800501已取得NAMESPACE_CHILD_PASS（1332内部design、9994叶单元），SHA核验OK。全部21 child已提交独立nsprotect候选，以done依赖限制最多4个处理任务。stitch_namespaced_wide64.py等待各child实际终态，逐项扫描工具Error/PASS、SHA和namespace.txt并验证全部设计集合互斥；重新stitch后增加336个RCU的坐标命名空间检查，完成后再派发原严格M5。调度和拼接均用独立记录，不覆盖旧候选。流程问题会影响此前网络面积/功能结论，旧数值只作为失败候选历史，不作为新网络验收依据。
