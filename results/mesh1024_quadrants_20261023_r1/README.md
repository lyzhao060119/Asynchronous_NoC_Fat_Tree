# Mesh1024 四象限映射组装

输入：冻结 `split1024_20261020/mesh` 的 1024 Router RTL/已有坐标专用 DDC。
不修改原始 RTL、原始 DDC、坐标、握手或保护器件；不复用 grid16 的独立 Mesh256。

四块各包含 256 Router，保持 grid32 全局坐标及跨块边界。结构比较见
`partition_audit.json`：1024 实例、20096 赋值完全对应，384 跨块信号唯一驱动。
这是结构比较，不是功能、STA 或 SDF 签核。

## 2026-10-24 00:04 检查点

- 四个 namesafe 作业：15083201 / 15083301 / 15083401 / 15083501，均已确认 RUN。
- 最终连接：15083601，依赖上述四块完成并检查 PASS/error 日志，PEND。
- 第一轮启动因 profile 与 nounset 冲突退出；已移除 profile 前的 nounset。
- 第二轮读取发现 UIO-92：多个 DDC 保留同名 RouteComputationLogic 等模块。
  已用独立 DC 作业 15083101 验证 rename_design，然后在每个 DDC 读入后、
  下一个 DDC 读入前为未限定名的设计添加坐标 Router 前缀。
  第二轮分块作业已停止，不作为有效候选；原始两个长时间 Stitch 未动。
- 各分块及最终顶层均不调用 compile_ultra；复用映射单元，组装、link、检查后导出。
- 最终运行在出现 UIO-92 或 Error 时拒绝采用分块，不以 scheduler DONE 代替验收。

完整远程产物保留于：
`/home/ghy19/Asynchronous_Router_CMR/campaigns/mesh1024_quadrants_20261023_r1`。

待完成：确认四块无错、命名隔离、256/块结构及非空 DDC/post.v/SDF；最终
1024 Router、四象限绑定、未解析引用/映射检查及产物哈希。仍未完成综合验收。

## r4 验收脚本修正

单 Router 检查 15084201 已验证 `is_unresolved` 查询和 GTECH/SEQGEN 检查有效、
均为 0；同时证明按 `CMRRouter_split_*` 前缀会匹配 710 个内部层次单元，
不能据此统计 Router。r4 改为精确正则匹配完整坐标 Router 名称。
此前 r3 作业已停止并保留日志；不存在已验收分块被替换。

- r4 四块：15084401 / 15084501 / 15084601 / 15084701。
- r4 最终：15084801，四块 PASS、无 Error/UIO-92 后才执行。
- 每块及最终均捕获 Tcl 错误并拒绝 PASS；检查 Router、IPM、OPM 数量、
  未解析引用及 GTECH/SEQGEN，再导出 DDC/netlist/SDF 和 SHA256。
- 完整输入哈希保存在远程 `inputs_r4.sha256`。

## 四块完成检查点

15084401 / 15084501 / 15084601 / 15084701 已全部 DONE 且有实际
`MESH_QUADRANT_PASS`，无 Error/UIO-92；每块 256 Router、1280 IPM/OPM，
未解析引用和 GTECH/SEQGEN 检查通过。每块已导出 DDC（约 794--795 MB）、
post.v（约 267 MB）、SDF（约 1.95--1.97 GB）及 SHA256 清单。

最终作业 15084801 已由依赖自动释放并实际 RUN，读取上述分块 DDC。
最终全量产物审计 15090801 依赖最终连接完成，核对所有五个对象的日志、
哈希和 SDF 文件尾。最终 1024 仍未完成，不能据此宣称 STA 或门级仿真通过。

## 顶层结构与映射检查通过，SDF 仍在导出

最终日志已确认 `MESH_QUADRANT_EXPORT_BEGIN top=CMRMeshNoC routers=1024`，
这之前的 IPM/OPM 数量（各 5120）、未解析引用及 GTECH/SEQGEN 检查均通过。
最终 DDC 已写出 3,365,273,600 bytes，网表 1,068,807,703 bytes。
SDF 已开始写出且持续增长，但尚未有最终 PASS 或完成审计。

SDF 预处理产生大量 OPT-314 自动断弧警告，不应将本次组装完成外推为
STA 闭合。当前慢点为完整 SDF 的全网 INTERCONNECT 记录串行写出；
独立帮助查询 15098001 已确认 write_sdf 支持 `-instance`，但未验证跨块
覆盖前不采用拆分导出来替换当前完整 SDF。

原始顶层本地/远程实际文件 SHA256 均为
`ff5d92d0b4cff1f94a8801c36c60e5d70b510d4aaa41b1235fba65d069b650e1`，
与冻结 manifest 一致。本轮未修改原始顶层或原始 Router DDC。
最新小型状态见 `status.json`；持续监控使用增量日志缓存，不下载大型产物。
