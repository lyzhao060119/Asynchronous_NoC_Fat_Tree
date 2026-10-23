"""Consolidate frozen, accepted router results without changing raw experiments."""
import csv
import hashlib
import json
import re
import statistics
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
RAW=ROOT/'scripts/asic_dc/cmr/results'
OUT=ROOT/'results/single_router_final_20261022'
OUT.mkdir(parents=True,exist_ok=True)
lat=json.loads((ROOT/'results/single_router_latency_power_audit_20261022_r3/summary.json').read_text())
packet=json.loads((ROOT/'results/single_router_packet_power_20261022_r4/packet_power_summary.json').read_text())
gls=json.loads((RAW/'single_router_packet_power_20261022_r4/gls_packets.json').read_text())
release=json.loads((ROOT/'results/single_router_packet_power_20261022_r4/packet_release_audit.json').read_text())
steady=json.loads((ROOT/'results/single_router_latency_power_audit_20261022_r3/energy_comparison.json').read_text())
names={'async_c1p1':'Thin 异步 c1p1','async_c1p4':'异步 c1p4','sync_c1p4':'同步 c1p4'}
rows=[];sources=[]
for name in names:
    run='20261022_router_ppa_r1_'+name
    qor=RAW/run/'reports_dc/qor.rpt'
    area=float(re.search(r'Cell Area:\s*([0-9.eE+-]+)',qor.read_text(),re.I)[1])
    iso=next(r for r in lat if r['config']==name and r['mode']=='isolated')
    active=next(r for r in packet if r['config']==name and r['window']=='active')
    guard=next(r for r in packet if r['config']==name and r['window']=='guard5')
    cont=next(r for r in steady if r['config']==name)
    selected=[r for r in gls if r['config']==name]
    assert len(selected)==3 and all(r['gls_pass'] and len(r['events'])==5 for r in selected)
    off=0 if name.startswith('sync') else .09
    completion=[];mean_flit=[]
    for r in selected:
        events=r['events']
        duration=max(float(e['input_ns'])+float(e['latency_ns'])-off for e in events)-min(float(e['input_ns']) for e in events)
        completion.append(duration)
        mean_flit.append(statistics.mean(float(e['latency_ns'])-off for e in events))
    rows.append({'config':name,'router':names[name],'dc_run':run,'area_um2':area,
        'isolated_flit_latency_ns_low_pattern':iso['mean_flit_latency_ns'],
        'random_packet_completion_ns':statistics.mean(completion),
        'random_packet_completion_div5_ns':statistics.mean(completion)/5,
        'random_packet_mean_individual_flit_latency_ns':statistics.mean(mean_flit),
        'packet_active_duration_ns':active['duration_ns'],'packet_active_power_mw':active['total_power_mw'],
        'packet_active_energy_pj':active['energy_pj'],'packet_active_energy_pj_sample_std':active['energy_pj_sample_std'],
        'packet_active_pj_per_flit':active['pj_per_flit'],'packet_active_pj_per_transferred_bit':active['pj_per_transferred_bit'],
        'packet_guard5_energy_pj':guard['energy_pj'],'packet_guard5_pj_per_transferred_bit':guard['pj_per_transferred_bit'],
        'packet_guard5_power_mw':guard['total_power_mw'],
        'steady_random_power_mw':cont['nominal_total_mw'],'steady_random_pj_per_transferred_bit':cont['random_nominal_pin_pj_bit'],
        'last_observed_release_ns':max(r['last_nonclock_transition_after_tail_capture_ns'] or 0 for r in release if r['config']==name)})
    sources.append(qor)

for filename,data in [('final_results.json',rows)]:
    (OUT/filename).write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
with (OUT/'final_results.csv').open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
lines=['# 单 Router 最终结果（2026-10-22）','',
    '冻结本次综合网表：28nm TT、0.8V、25°C；同步时钟1ns；28bit/flit、5flit/包。功耗显式采用50ps输入/时钟slew、5fF输出负载。',
    '面积为DC标准单元总面积，无布局布线。功耗包括整个DUT的内部、网络翻转与泄漏，不做空闲基线扣除。','',
    '## 面积和延时','',
    '|Router|面积 μm²|隔离flit平均 ns|随机5-flit包完成 ns|包完成/5 ns|',
    '|---|---:|---:|---:|---:|']
for r in rows:
    lines.append(f"|{r['router']}|{r['area_um2']:.2f}|{r['isolated_flit_latency_ns_low_pattern']:.4f}|{r['random_packet_completion_ns']:.4f}|{r['random_packet_completion_div5_ns']:.4f}|")
lines.extend(['',
    '隔离flit延时来自r3逐个等待输出的低翻转控制包测试；随机包延时直接从r4同一单包功耗波形提取。包完成时间是首flit输入到尾flit输出Req/握手，不含异步测试台90ps采样等待。包完成/5是摊销值，不是逐flit时间差均值。','',
    '## 单个随机5-flit包功耗与能量（主结果）','',
    '每次复位后仅一个源发送一个包，3个Body数据种子取均值。窗口为首flit输入到尾flit捕获；异步窗口比输出Req延时口径多90ps。每包140个传输bit，96个随机payload bit。','',
    '|Router|平均功耗 mW|整包能量 pJ|每flit pJ|每传输bit pJ|',
    '|---|---:|---:|---:|---:|---:|'])
for r in rows:
    lines.append(f"|{r['router']}|{r['packet_active_power_mw']:.4f}|{r['packet_active_energy_pj']:.4f}|{r['packet_active_pj_per_flit']:.4f}|{r['packet_active_pj_per_transferred_bit']:.5f}|")
lines.extend(['','## 包含尾部释放的延长窗口','',
    '末flit捕获后再延长5ns。该窗口覆盖本次观察到的释放活动，也包含释放后的空闲功耗与同步持续时钟开销，不是唯一或最小的整包能量定义。','',
    '|Router|整包+5ns能量 pJ|每传输bit pJ|观测释放时间 ns|',
    '|---|---:|---:|---:|'])
for r in rows:
    lines.append(f"|{r['router']}|{r['packet_guard5_energy_pj']:.4f}|{r['packet_guard5_pj_per_transferred_bit']:.5f}|{r['last_observed_release_ns']:.3f}|")
lines.extend(['','## 四源连续负载（独立参考口径）','',
    '40000个测量flit，伪随机Body/Tail数据；同一50ps/5fF pin条件。不能与单包结果混用。','',
    '|Router|平均功耗 mW|每传输bit pJ|','|---|---:|---:|'])
for r in rows:
    lines.append(f"|{r['router']}|{r['steady_random_power_mw']:.4f}|{r['steady_random_pj_per_transferred_bit']:.5f}|")
lines.extend(['','## 验证与范围','',
    '- 当前DC产物通过；r3延时/随机负载9个GLS窗口及18个基础/敏感性PT-PX窗口通过。',
    '- r4单包9次GLS均5/5交付、SDF零错误、无时序违例，交付后25ns检查接口排空。36个功耗窗口通过，活动覆盖100%。',
    '- 旧固定Body数据的低翻转能量仅作为历史对照；主结果均采用变化的Body数据。',
    '- 电气库表外推警告仍保留。未提取物理互连/CTS，也未计外部源、接收器和实际链路功耗；这些数是综合后模型估计，不是硅后测量。',
    '- 3个种子样本标准差表示数据模式差异，不是模型/硅后误差。',
    '- 各文献的工艺、电压、编码、负载、能量分母及延时定义未统一前，不直接据此宣称跨论文领先。','',
    '## 数据来源','',
    '- `scripts/asic_dc/cmr/results/20261022_router_ppa_r1_{async_c1p1,async_c1p4,sync_c1p4}`：综合面积和冻结产物。',
    '- `results/single_router_latency_power_audit_20261022_r3`：隔离延时、随机连续负载和pin敏感性。',
    '- `results/single_router_packet_power_20261022_r4`：单个随机包、尾部释放及波形审计。'])
(OUT/'RESULTS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
sources.extend([ROOT/'results/single_router_latency_power_audit_20261022_r3/summary.json',
    ROOT/'results/single_router_latency_power_audit_20261022_r3/energy_comparison.json',
    ROOT/'results/single_router_packet_power_20261022_r4/packet_power_summary.json',
    ROOT/'results/single_router_packet_power_20261022_r4/packet_release_audit.json',
    RAW/'single_router_packet_power_20261022_r4/gls_packets.json'])
(OUT/'source_hashes.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},indent=2)+'\n')
print('SINGLE_ROUTER_FINAL_SUMMARY_PASS',OUT)
print(json.dumps(rows,indent=2,ensure_ascii=False))
