"""Frozen-netlist latency definitions and low/random activity power audit."""
import os
os.environ['CMR_MATCHED_BATCH']='single_router_latency_power_20261022_r3'
import csv
import json
import re
import statistics
import shutil
import shlex
from pathlib import Path
import run_single_router_20261022 as previous
m=previous.m
HERE=Path(__file__).resolve().parent

FLIT_FUNCTION='''  function automatic [FLIT_W-1:0] flit_for(input integer src,pkt,flit);
    reg [FLIT_W-1:0] x;
    reg [31:0] mix;
    begin
      x=28'b0; x[27]=(flit==0); x[26]=(flit==4);
      if(flit==0 || data_random==0) begin
        x[25:20]=6'd8; x[19:14]=6'd8; x[13:8]=6'd8; x[7:2]=6'd8;
      end else begin
        mix=32'h6d2b79f5 ^ ((pkt+1)*32'h9e3779b9) ^ ((src+1)*32'h85ebca6b) ^ (flit*32'hc2b2ae35);
        mix=mix^(mix<<13); mix=mix^(mix>>17); mix=mix^(mix<<5);
        x[25:2]=mix[23:0];
      end
      x[1:0]=src[1:0]+2'd1; flit_for=x;
    end
  endfunction'''

def prepare():
    previous.prepare()
    for sync,p in m.TB_FILES.items():
        t=p.read_text()
        t=t.replace('  real inject_ns', '  integer output_paced=0, data_random=0;\n  real inject_ns',1)
        t=re.sub(r'  function automatic \[FLIT_W-1:0\] flit_for.*?endfunction',lambda _:FLIT_FUNCTION,t,flags=re.S)
        marker='    if(!$value$plusargs("MODE=%s",mode)) mode="aggregate";'
        assert marker in t
        t=t.replace(marker,marker+'\n    if(!$value$plusargs("OUTPUT_PACED=%d",output_paced)) output_paced=0;\n    if(!$value$plusargs("DATA_RANDOM=%d",data_random)) data_random=0;')
        pace='\n        if(output_paced) begin wait(expected_pkt[src]*5+expected_phase[src]>pk*5+fl); #0.20; end'
        if sync:
            t=t.replace('        sent_flits[src]=sent_flits[src]+1;', '        sent_flits[src]=sent_flits[src]+1;'+pace)
            assert 'while(1) begin\n          @(posedge clock);' in t
        else:
            ending='        wait(tb_in_req[port]===tb_in_ack[port]);\n      end'
            assert ending in t
            t=t.replace(ending,'        wait(tb_in_req[port]===tb_in_ack[port]);'+pace+'\n      end')
        p.write_text(t)
    wrapper=HERE/'run_gls_router_matched_ppa.sh'
    t=wrapper.read_text()
    t=t.replace('local mode="$1";', 'local mode="$1"; local sim_mode="$mode"; local pace=0; local random=0;\n  if [ "$mode" = isolated ]; then pace=1; fi\n  if [ "$mode" = packet ]; then sim_mode=isolated; fi\n  if [ "$mode" = aggregate ]; then random=1; fi;')
    t=t.replace('./simv +MODE="$mode"', './simv +MODE="$sim_mode" +OUTPUT_PACED="$pace" +DATA_RANDOM="$random"')
    t=t.replace('run_mode aggregate\n', 'run_mode packet\nrun_mode aggregate\n')
    t=t.replace('"$LOG/isolated" "$LOG/aggregate"', '"$LOG/isolated" "$LOG/packet" "$LOG/aggregate"')
    dest=m.out_dir()/'inputs'/wrapper.name
    dest.write_text(t)
    m.WRAPPER=dest
    # Upload only the geometries used by this experiment.
    binds=m.out_dir()/'inputs'/'hop_binds'
    binds.mkdir(exist_ok=True)
    for name in ('async_ports_c1_p1.vi','async_ports_c1_p4.vi','sync_ports_c1_p4.vi'):
        shutil.copy2(HERE/'hop_binds'/name,binds/name)
    m.BIND_DIR=binds
    spec={'dc_runs':previous.RUNS,'corner':'TT 0.8V 25C','sync_clock_ns':1,
          'isolated':'five flits; each waits for previous output; low switching',
          'packet':'one five-flit packet, input-Ack/ready paced; low switching',
          'aggregate':'four sources, 48000 flits, 40000 measured; pseudorandom 24-bit body/tail plus 2-bit source tag',
          'latency_definitions':{'mean_flit':'mean(output_i-input_i)',
                                 'packet_completion':'output_tail-input_head',
                                 'packet_amortized':'packet_completion/5'},
          'power_scope':'all DUT cells; internal + switching + leakage; post-synthesis no P&R/SPEF; input/output external drivers excluded'}
    (m.out_dir()/'audit_spec.json').write_text(json.dumps(spec,indent=2)+'\n')

def collect():
    rows=m.collect(wait=True)
    for c in m.CONFIGS:
        rid=f"{m.BATCH}_{c['name']}"
        folder=m.out_dir()/rid/'packet'
        run=(folder/'run.log').read_text()
        sdf=(folder/'sdf_annotate.log').read_text()
        with (folder/'hop_events.csv').open() as f:events=list(csv.DictReader(f))
        ok=(len(events)==5 and 'MATCHED_RESULT PASS' in run and 'PPA_RESULT PASS' in run
            and bool(re.search(r'Total errors:\s*0\b',sdf))
            and not re.search(r'Timing violation|MATCHED_FAIL|PPA_RESULT FAIL',run))
        if not ok:raise RuntimeError('packet GLS failed '+c['name'])
        start,end=previous.event_window(events,c['sync'],'isolated')
        lanes={str(i):sum(e['lane']==str(i) for e in events) for i in range(c['lanes'])}
        rows.append({'config':c['name'],'run_id':rid,'mode':'packet','status':'PASS',
            'functional_pass':True,'power_eligible':True,'all_lanes_active':True,
            'active_parent_lanes':sum(v>0 for v in lanes.values()),'lane_counts':lanes,
            'start_ns':start,'end_ns':end,'duration_ns':end-start,'measurement_count':5,
            'event_count':5,'count_ok':True,'sdf_errors_zero':True})
    (m.out_dir()/'gls_summary.json').write_text(json.dumps(rows,indent=2)+'\n')

def reduce():
    archive=m.archive_dir()
    manifest=json.loads((archive/'manifest.json').read_text())
    result=[]; flits=[]
    for g in manifest['gls']:
        c=m.cfg(g['config']); off=0 if c['sync'] else .09
        with (m.out_dir()/g['run_id']/g['mode']/'hop_events.csv').open() as f:
            events=list(csv.DictReader(f))
        selected=[e for e in events if e['measurement']=='1']
        if any(float(e['input_ns'])<=0 or float(e['latency_ns'])<off for e in events):
            raise RuntimeError('invalid timestamp '+g['run_id'])
        power=next(p for p in manifest['ptpx'] if p['config']==g['config'] and p['mode']==g['mode'])
        base=m.out_dir()/'ptpx'/power['tag']
        log=(base/'logs'/'lsf.log').read_text(errors='replace')
        check=(base/'check_power.rpt').read_text(errors='replace')
        nets=re.search(r'Number of annotated nets = (\d+) \(([0-9.]+)%\)',log)
        cells=re.search(r'Number of fully annotated leaf cells = (\d+) \(([0-9.]+)%\)',log)
        if not (power['power_pass'] and re.search(r'^PPA_POWER_PASS reports=',log,re.M)
                and nets and cells and float(nets[2])==100 and float(cells[2])==100):
            raise RuntimeError('PTPX audit failed '+power['tag'])
        row={'config':c['name'],'mode':g['mode'],'gls_pass':g['functional_pass'],
             'mean_flit_latency_ns':statistics.mean(float(e['latency_ns'])-off for e in selected),
             'packet_completion_ns':None,'packet_time_div5_ns':None,
             'power_pass':power['power_pass'],'total_power_mw':power['total_power_w']*1e3,
             'internal_power_mw':power['internal_power_w']*1e3,
             'switching_power_mw':power['switching_power_w']*1e3,
             'leakage_power_mw':power['leakage_power_w']*1e3,
             'total_pj_per_bit':power['total_pj_per_bit'],'dynamic_pj_per_bit':power['dynamic_pj_per_bit'],
             'leakage_pj_per_bit':power['leakage_power_w']*g['duration_ns']*1e3/(g['measurement_count']*28),
             'activity_coverage_percent':float(nets[2]),
             'out_of_range_ramps':int((re.search(r'(\d+) out_of_range ramps',check) or ['','0'])[1]),
             'out_of_range_loads':int((re.search(r'(\d+) out_of_range loads',check) or ['','0'])[1])}
        if g['mode']!='aggregate':
            start=min(float(e['input_ns']) for e in events)
            end=max(float(e['input_ns'])+float(e['latency_ns'])-off for e in events)
            row['packet_completion_ns']=end-start
            row['packet_time_div5_ns']=(end-start)/5
            for e in events:
                flits.append({'config':c['name'],'mode':g['mode'],'flit':int(e['flit']),
                    'input_ns':float(e['input_ns']),
                    'output_ns':float(e['input_ns'])+float(e['latency_ns'])-off,
                    'latency_ns':float(e['latency_ns'])-off})
        result.append(row)
    d=m.out_dir()
    for name,data in [('summary',result),('flit_events',flits)]:
        (d/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
        with (d/(name+'.csv')).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
    lines=['# Router latency and power audit','',
        'Frozen 20261022 DC netlists; TT 0.8V 25C; 28 transported bits/flit; 5 flits/packet; Sync 1 ns.',
        'isolated = output-paced flits, packet = input-paced single packet, aggregate = pseudorandom Body/Tail traffic.',
        'Mean flit latency = mean(output_i - input_i). Packet completion = output_tail - input_head. Completion/5 is a separate amortized metric.',
        'Power includes internal, net switching and leakage of the entire DUT. No idle-baseline subtraction.',
        'No P&R/SPEF or external source/sink/link drivers. Slew/load table extrapolation warnings remain. No numerical silicon-error bound is established.','',
        '|Config|Mode|Mean flit ns|Packet ns|Packet/5 ns|Total pJ/bit|Leakage mW|',
        '|---|---|---:|---:|---:|---:|---:|']
    for r in result:
        fmt=lambda x:'-' if x is None else f'{x:.6f}'
        lines.append('|'+ '|'.join([r['config'],r['mode'],*[fmt(r[k]) for k in
            ('mean_flit_latency_ns','packet_completion_ns','packet_time_div5_ns','total_pj_per_bit','leakage_power_mw')]])+'|')
    (d/'RESULTS.md').write_text('\n'.join(lines)+'\n')
    analysis=archive/'analysis';analysis.mkdir(exist_ok=True)
    for name in ('summary.csv','summary.json','flit_events.csv','flit_events.json','RESULTS.md','audit_spec.json'):
        shutil.copy2(d/name,analysis/name)
    shutil.copy2(Path(__file__),analysis/Path(__file__).name)
    print(json.dumps(result,indent=2),flush=True)

def sensitivity():
    """Explicit pin assumptions; keep the extracted-wire limitation visible."""
    d=m.out_dir()
    rows=json.loads((d/'gls_summary.json').read_text())
    if not all(r['functional_pass'] for r in rows):raise RuntimeError('GLS prerequisite failed')
    local=d/'inputs'/'power_pin_sensitivity.tcl'
    t=(d/'inputs'/'run_ptpx_cmr_router_hop_ppa.tcl').read_text()
    marker='read_sdc "$OUT/$DUT_NAME.sdc"'
    t=t.replace(marker,marker+'''
set_input_transition $::env(AUDIT_SLEW_NS) [all_inputs]
set_load $::env(AUDIT_LOAD_PF) [all_outputs]
if {[sizeof_collection [all_clocks]] > 0} {
  set_clock_transition $::env(AUDIT_SLEW_NS) [all_clocks]
}
puts "AUDIT_PIN_ASSUMPTIONS slew_ns=$::env(AUDIT_SLEW_NS) load_pf=$::env(AUDIT_LOAD_PF)"
report_port -verbose [all_inputs] > "$REPORT_DIR/input_assumptions.rpt"
report_port -verbose [all_outputs] > "$REPORT_DIR/output_assumptions.rpt"
''')
    local.write_text(t)
    remote=m.stage_root()+'/power_pin_sensitivity.tcl'
    client=m.connect();sftp=client.open_sftp()
    jobs=[]
    try:
        m.put(client,sftp,local,remote)
        for label,slew,load in [('s20_l1',.020,.001),('s50_l5',.050,.005),('s100_l10',.100,.010)]:
            for c in m.CONFIGS:
                g=next(r for r in rows if r['config']==c['name'] and r['mode']=='aggregate')
                tag=f"{m.BATCH}_{c['name']}_{label}"
                log=f'{m.stage_root()}/sensitivity/{tag}/logs'
                report=f'{m.stage_root()}/sensitivity/{tag}/reports'
                work=f'{m.stage_root()}/sensitivity/{tag}/work'
                dut='SyncCmrRouter' if c['sync'] else 'CMRRouter'
                strip=('tb_router_matched_ppa_sync' if c['sync'] else 'tb_router_matched_ppa_async')+'/dut'
                vcd=f"{m.stage_root()}/logs/{g['run_id']}/aggregate/hop_ppa.vcd"
                env={'SYNOPSYS_LC_ROOT':'/soft/synopsys/lc/V-2023.12',
                     'CMR_REMOTE_ROOT':m.REMOTE_ROOT,'CMR_RUN_ID':tag,'CMR_NETLIST_RUN_ID':c['netlist'],
                     'CMR_DUT_NAME':dut,'CMR_TB_STRIP':strip,'CMR_POWER_VCD_FILE':vcd,
                     'CMR_POWER_REPORT_DIR':report,'CMR_POWER_START_NS':f"{g['start_ns']:.3f}",
                     'CMR_POWER_END_NS':f"{g['end_ns']:.3f}",'AUDIT_SLEW_NS':str(slew),
                     'AUDIT_LOAD_PF':str(load),'TMPDIR':m.stage_root()+'/tmp',
                     'PT_TMPDIR':m.stage_root()+'/tmp'}
                inner='cd '+shlex.quote(work)+' && env '+' '.join(k+'='+shlex.quote(v) for k,v in env.items())+' /soft/synopsys/prime/V-2023.12/bin/pt_shell -f '+shlex.quote(remote)
                command=f'mkdir -p {log} {report} {work}; bsub -n 1 {m.HOSTS} -oo {log}/lsf.log -J sens_{c["name"]}_{label} bash -lc '+shlex.quote(inner)
                response=m.remote_run(client,command);jid=m.job_id(response)
                jobs.append({'config':c['name'],'scenario':label,'slew_ns':slew,'output_load_pf':load,
                    'job_id':jid,'report':report,'log':log,'duration_ns':g['duration_ns']})
                print('SENSITIVITY_SUBMIT',c['name'],label,jid,flush=True)
        (d/'sensitivity_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
    finally:sftp.close();client.close()
    client=m.connect()
    try:
        for j in jobs:client=m.wait_job(client,j['job_id'],j['config']+'_'+j['scenario'],polls=240)
    finally:client.close()
    client=m.connect();sftp=client.open_sftp();results=[]
    try:
        for j in jobs:
            folder=d/'sensitivity'/j['config']/j['scenario']
            m.fetch_tree(sftp,j['report'],folder);m.fetch_tree(sftp,j['log'],folder/'logs')
            log=(folder/'logs'/'lsf.log').read_text(errors='replace')
            check=(folder/'check_power.rpt').read_text(errors='replace')
            p=m.parse_power(folder/'power.rpt')
            good=(bool(re.search(r'^PPA_POWER_PASS reports=',log,re.M)) and p['power_sum_ok']
                  and bool(re.search(r'^AUDIT_PIN_ASSUMPTIONS slew_ns=',log,re.M)))
            if not good:raise RuntimeError('sensitivity power failed '+j['config']+' '+j['scenario'])
            results.append({**j,**p,'power_pass':good,
                'total_pj_per_bit':p['total_power_w']*j['duration_ns']*1e3/(40000*28),
                'out_of_range_ramps':int((re.search(r'(\d+) out_of_range ramps',check) or ['','0'])[1]),
                'out_of_range_loads':int((re.search(r'(\d+) out_of_range loads',check) or ['','0'])[1])})
    finally:sftp.close();client.close()
    (d/'power_sensitivity.json').write_text(json.dumps(results,indent=2)+'\n')
    with (d/'power_sensitivity.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(results[0]));w.writeheader();w.writerows(results)
    for name in ('power_sensitivity.json','power_sensitivity.csv','sensitivity_jobs.json'):
        shutil.copy2(d/name,m.archive_dir()/'analysis'/name)
    print(json.dumps(results,indent=2),flush=True)

def report():
    d=m.out_dir()
    rows=json.loads((d/'summary.json').read_text())
    sensitivities=json.loads((d/'power_sensitivity.json').read_text())
    old=json.loads((HERE/'results/single_router_20261022_r2/summary.json').read_text())
    toggles=[]
    for c in m.CONFIGS:
        path=d/(m.BATCH+'_'+c['name'])/'aggregate/hop_events.csv'
        with path.open() as f:events=list(csv.DictReader(f))
        hamming=[]
        for src in range(4):
            seq=[e for e in events if int(e['src'])==src and e['measurement']=='1']
            for a,b in zip(seq,seq[1:]):
                if int(a['flit'])>=1 and int(b['flit'])==int(a['flit'])+1:
                    hamming.append(((int(a['data'])>>2)^(int(b['data'])>>2)).bit_count()/24)
        toggles.append({'config':c['name'],'adjacent_body_payload_toggle_fraction':statistics.mean(hamming),
                        'compared_body_transitions':len(hamming)})
    for j in json.loads((d/'sensitivity_jobs.json').read_text()):
        log=(d/'sensitivity'/j['config']/j['scenario']/'logs/lsf.log').read_text(errors='replace')
        for pattern in (r'Number of annotated nets = \d+ \(100\.00%\)',
                        r'Number of fully annotated leaf cells = \d+ \(100\.00%\)'):
            if not re.search(pattern,log):raise RuntimeError('sensitivity coverage failed '+j['config']+' '+j['scenario'])
    names={'async_c1p1':'Thin 异步 c1p1','async_c1p4':'异步 c1p4','sync_c1p4':'同步 c1p4'}
    lines=['# 单 Router 延时重测与功耗审计','',
        '批次：`single_router_latency_power_20261022_r3`。冻结原 20261022 DC 网表，TT 0.8 V/25°C，28 bit/flit，5 flit/包，同步时钟 1 ns。',
        '9/9 MAX-SDF 窗口 PASS；9/9 原始 PT-PX 窗口 PASS；9/9 pin 敏感性 PT-PX 窗口 PASS；功耗网及叶单元活动覆盖率均为 100%。','',
        '## 延时定义与实测','',
        '- 逐 flit 隔离：每个 flit 等前一个到达输出，再加 200 ps guard 后发送。平均值为 `mean(t_out_i - t_in_i)`。',
        '- 连续单包：一个源按输入 Ack/ready 连续发送五个 flit，不等待每个输出。',
        '- 包完成时间为 `t_out_tail - t_in_head`；除以 5 得到每 flit 摊销包完成时间，与逐 flit 延时均值不同。',
        '- 异步端点为 Req 到 Req，已扣除测试台 90 ps 采样等待；同步端点为输入、输出 valid/ready 接受边沿。','',
        '|Router|隔离 flit 平均 ns|连续包完成 ns|包完成/5 ns|连续包逐 flit 平均 ns|',
        '|---|---:|---:|---:|---:|']
    energy=[]
    for c in m.CONFIGS:
        name=c['name']; iso=next(r for r in rows if r['config']==name and r['mode']=='isolated')
        pkt=next(r for r in rows if r['config']==name and r['mode']=='packet')
        lines.append(f"|{names[name]}|{iso['mean_flit_latency_ns']:.4f}|{pkt['packet_completion_ns']:.4f}|{pkt['packet_time_div5_ns']:.4f}|{pkt['mean_flit_latency_ns']:.4f}|")
        low=next(r for r in old if r['config']==name and r['mode']=='aggregate')
        rand=next(r for r in rows if r['config']==name and r['mode']=='aggregate')
        nominal=next(r for r in sensitivities if r['config']==name and r['scenario']=='s50_l5')
        cases=[r['total_pj_per_bit'] for r in sensitivities if r['config']==name]
        energy.append({'config':name,'low_toggle_default_pin_pj_bit':low['total_pj_per_bit'],
            'random_default_pin_pj_bit':rand['total_pj_per_bit'],
            'random_nominal_pin_pj_bit':nominal['total_pj_per_bit'],
            'random_nominal_pin_pj_useful_payload_bit':nominal['total_pj_per_bit']*140/96,
            'pin_scenario_min_pj_bit':min(cases),'pin_scenario_max_pj_bit':max(cases),
            'nominal_leakage_uw':nominal['leakage_power_w']*1e6,
            'nominal_total_mw':nominal['total_power_w']*1e3,
            'nominal_internal_mw':nominal['internal_power_w']*1e3,
            'nominal_switching_mw':nominal['switching_power_w']*1e3})
    lines.extend(['','## 功耗与能量','',
        '主能量指标采用四个 child 输入源向固定 (8,8) 目的地的 parent 方向单播连续负载、40000 个测量 flit，非组播。相邻 Body/Tail 的 24-bit 字段实测平均翻转率 48.6111%；旧低翻转模式为 0%。随机模式是固定种子的可复现实验，不构成统计误差估计。',
        '`P_total = P_internal + P_net_switching + P_leakage`；`E/bit = P_total × T / (40000 × 28)`，不扣除空闲/泄漏。',
        '名义 pin 条件为输入/时钟 slew 50 ps、全部输出负载 5 fF。这是显式假设，不是提取的物理条件。','',
        '|Router|旧低翻转默认 pin pJ/bit|随机默认 pin pJ/bit|随机 50ps/5fF pJ/bit|名义漏电 μW|',
        '|---|---:|---:|---:|---:|'])
    for r in energy:
        lines.append(f"|{names[r['config']]}|{r['low_toggle_default_pin_pj_bit']:.6f}|{r['random_default_pin_pj_bit']:.6f}|{r['random_nominal_pin_pj_bit']:.6f}|{r['nominal_leakage_uw']:.3f}|")
    lines.extend(['','## 精度与比较范围','',
        '- 包含整个 Router DUT 的标准单元内部、网络翻转及泄漏功耗。同步包括寄存器 clock pin 内部功耗。',
        '- ZeroWire/综合后模型不含提取的互连寄生、物理 CTS、外部源/接收器及真实链路功耗；库中的单元 pin 电容仍有计入。',
        '- 基线 SDC 没有显式输入 slew/输出负载；增加三组 20ps/1fF、50ps/5fF、100ps/10fF 敏感性分析。它们改变 PT-PX 电气假设，保持同一 VCD，不是重新闭合相应物理条件下的时序。',
        '- 库表外 slew/load 警告仍保留；100% 活动覆盖率不能推出硅后误差小于某个百分比。三组 pin 场景的范围也不是置信区间或硅后误差界。',
        '- 门级库模型不能直接验证模拟亚稳态过程的电流。当前结果属于明确条件下的综合后估计。',
        '- 短单包活动窗口在末 flit 捕获结束，不包含无限空闲及全部后续控制释放过程；正式能量比较优先使用长测量窗口。',
        '- 28 bit 分母包含 Head、标志和源标签；本测试每包随机有效数据为 4×24=96 bit。按有效 payload bit 报能量需要乘以 140/96。',
        '- 截图中的工艺、编码、FIFO 和 pJ/spike/pJ/bit 分母不同，缺少各文献测量定义时，不应直接据此宣称能效领先。',
        '- 工具支持动态及泄漏功耗分析：[Synopsys PrimePower](https://www.synopsys.com/implementation-and-signoff/signoff/primepower.html)。','',
        '原始事件、网表哈希、SDF 日志、PT-PX 报告、check_power 和 pin 假设报告均保留在本批次目录。'])
    target=m.REPO/'results'/'single_router_latency_power_audit_20261022_r3'
    target.mkdir(parents=True,exist_ok=True)
    for name,data in [('energy_comparison',energy),('switching_audit',toggles)]:
        (target/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
        with (target/(name+'.csv')).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
    (target/'RESULTS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    for name in ('summary.csv','summary.json','flit_events.csv','power_sensitivity.csv','audit_spec.json'):
        shutil.copy2(d/name,target/name)
    for p in target.iterdir():
        if p.is_file():shutil.copy2(p,m.archive_dir()/'analysis'/p.name)
    print('FINAL_AUDIT_PASS',target,flush=True)
    print(json.dumps(energy,indent=2),flush=True)

if __name__=='__main__':
    import sys
    command=sys.argv[1]
    if command not in ('reduce','sensitivity','report'):prepare()
    if command=='run':
        m.submit();collect();m.submit_ptpx()
        jobs=json.loads((m.out_dir()/'ptpx_jobs.json').read_text())
        client=m.connect()
        try:
            for job in jobs:client=m.wait_job(client,job['job_id'],job['tag'],polls=240)
        finally:client.close()
        m.finalize();reduce()
    elif command=='reduce':reduce()
    elif command=='sensitivity':sensitivity()
    elif command=='report':report()
    elif command=='prepare':print('PREPARED',m.out_dir())
