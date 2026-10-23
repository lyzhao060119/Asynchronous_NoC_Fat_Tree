"""Three frozen routers, one random five-flit packet per reset, three seeds."""
import csv
import json
import re
import shlex
import shutil
import statistics
import hashlib
from pathlib import Path
import run_single_router_20261022 as base
m=base.m
m.BATCH='single_router_packet_power_20261022_r4'
HERE=Path(__file__).resolve().parent
SOURCE=HERE/'results/single_router_latency_power_20261022_r3/inputs'
SEEDS=(1,2,3)

def prepare():
    inputs=m.out_dir()/'inputs';inputs.mkdir(parents=True,exist_ok=True)
    for sync,name in [(False,'tb_router_matched_ppa_async.sv'),(True,'tb_router_matched_ppa_sync.sv')]:
        t=(SOURCE/name).read_text()
        t=t.replace('integer output_paced=0, data_random=0;', 'integer output_paced=0, data_random=0, payload_seed=1;')
        t=t.replace("mix=32'h6d2b79f5 ^", "mix=32'h6d2b79f5 ^ (payload_seed*32'h27d4eb2d) ^")
        marker='    if(!$value$plusargs("DATA_RANDOM=%d",data_random)) data_random=0;'
        assert marker in t
        t=t.replace(marker,marker+'\n    if(!$value$plusargs("PAYLOAD_SEED=%d",payload_seed)) payload_seed=1;')
        settle=("if(tb_in_valid!=='0 || tb_out_valid!=='0) fail(\"nonempty boundary after settling\");" if sync else
                'if(tb_in_req!==tb_in_ack || tb_out_req!==tb_out_ack) fail("unbalanced boundary after settling");')
        t=t.replace('$fclose(csv_fd);', '#25; '+settle+'\n    if(failures==0) $display("PACKET_SETTLE_PASS seed=%0d end_ns=%0.6f",payload_seed,$realtime);\n    else $display("PPA_RESULT FAIL settling");\n    $fclose(csv_fd);')
        dest=inputs/name;dest.write_text(t);m.TB_FILES[sync]=dest
    t=(SOURCE/'run_gls_router_matched_ppa.sh').read_text()
    t=t.replace('local sim_mode="$mode"; local pace=0; local random=0;', 'local sim_mode=isolated; local pace=0; local random=1; local seed=${mode#seed};')
    t=t.replace('+DATA_RANDOM="$random"', '+DATA_RANDOM="$random" +PAYLOAD_SEED="$seed"')
    t=t.replace('"$LOG/isolated" "$LOG/packet" "$LOG/aggregate"', '"$LOG/seed1" "$LOG/seed2" "$LOG/seed3"')
    t=t.replace('run_mode isolated\nrun_mode packet\nrun_mode aggregate', 'run_mode seed1\nrun_mode seed2\nrun_mode seed3')
    dest=inputs/'run_gls_router_matched_ppa.sh';dest.write_text(t);m.WRAPPER=dest
    binds=inputs/'hop_binds';binds.mkdir(exist_ok=True)
    for name in ('async_ports_c1_p1.vi','async_ports_c1_p4.vi','sync_ports_c1_p4.vi'):
        shutil.copy2(SOURCE/'hop_binds'/name,binds/name)
    m.BIND_DIR=binds
    t=(SOURCE/'power_pin_sensitivity.tcl').read_text()
    extra='''
foreach suffix {guard2 guard5 idle} {
  if {$suffix eq "idle"} {
    set extra_start [expr {$END_NS+10.0}]
    set extra_end [expr {$END_NS+20.0}]
  } else {
    set extra_start $START_NS
    if {$suffix eq "guard2"} {set extra_end [expr {$END_NS+2.0}]} else {set extra_end [expr {$END_NS+5.0}]}
  }
  report_vcd_window $VCD_FILE $extra_start $extra_end "$REPORT_DIR/power_${suffix}.rpt" $suffix
  check_power > "$REPORT_DIR/check_power_${suffix}.rpt"
  report_switching_activity > "$REPORT_DIR/activity_${suffix}.rpt"
}
'''
    t=t.replace('puts "PPA_POWER_PASS reports=$REPORT_DIR"',extra+'\nputs "PPA_POWER_PASS reports=$REPORT_DIR"')
    (inputs/'packet_power.tcl').write_text(t)
    spec={'batch':m.BATCH,'dc_runs':base.RUNS,'seeds':SEEDS,'packet_flits':5,'flit_bits':28,
        'sources':1,'route':'child0 to parent; unicast destination (8,8)',
        'body_payload':'24-bit pseudorandom data; 2-bit source tag; Head route fields fixed',
        'injection':'continuous packet, input handshake paced, no wait for per-flit output',
        'corner':'TT 0.8V 25C','sync_clock_ns':1,'input_slew_ns':.05,'output_load_pf':.005,
        'power_windows':'head ingress to tail capture; also +2 ns, +5 ns, and tail capture+10..20 ns idle',
        'simulation_post_drain_ns':25,'scope':'entire DUT; internal + switching + leakage; no idle subtraction; no P&R/SPEF'}
    (m.out_dir()/'packet_spec.json').write_text(json.dumps(spec,indent=2)+'\n')

def collect_gls():
    jobs=json.loads((m.out_dir()/'jobs.json').read_text())['jobs']
    client=m.connect()
    try:
        for j in jobs:client=m.wait_job(client,j['job_id'],j['name'],polls=240)
    finally:client.close()
    client=m.connect();sftp=client.open_sftp();rows=[]
    try:
        for j in jobs:
            c=m.cfg(j['name']);remote=f"{m.stage_root()}/logs/{j['run_id']}";local=m.out_dir()/j['run_id']
            m.fetch_tree(sftp,remote,local)
            for seed in SEEDS:
                folder=local/f'seed{seed}'
                run=(folder/'run.log').read_text(errors='replace')
                sdf=(folder/'sdf_annotate.log').read_text(errors='replace')
                with (folder/'hop_events.csv').open() as f:events=list(csv.DictReader(f))
                good=(len(events)==5 and all(e['measurement']=='1' for e in events)
                    and bool(re.search(r'MATCHED_RESULT PASS .*sent=5 received=5 measurement=5',run))
                    and 'PACKET_SETTLE_PASS' in run and bool(re.search(r'Total errors:\s*0\b',sdf))
                    and not re.search(r'MATCHED_FAIL|PPA_RESULT FAIL|Timing violation|Fatal:',run))
                if not good:raise RuntimeError('single packet GLS failed '+j['name']+f' seed{seed}')
                start,end=base.event_window(events,c['sync'],'isolated')
                if any(float(e['input_ns'])<=0 or float(e['latency_ns'])<0 for e in events):raise RuntimeError('timestamp failure')
                vcd=f'{remote}/seed{seed}/hop_ppa.vcd'
                size=sftp.stat(vcd).st_size
                if not 0<size<50_000_000:raise RuntimeError('unexpected VCD size')
                sftp.get(vcd,str(folder/'hop_ppa.vcd'))
                rows.append({'config':c['name'],'seed':seed,'run_id':j['run_id'],
                    'gls_pass':good,'start_ns':start,'tail_capture_ns':end,'duration_ns':end-start,
                    'vcd':vcd,'vcd_bytes':size,'events':events})
                print('PACKET_GLS_PASS',c['name'],seed,'duration_ns',end-start,flush=True)
    finally:sftp.close();client.close()
    (m.out_dir()/'gls_packets.json').write_text(json.dumps(rows,indent=2)+'\n')

def submit_power():
    rows=json.loads((m.out_dir()/'gls_packets.json').read_text())
    client=m.connect();sftp=client.open_sftp();jobs=[]
    try:
        remote=m.stage_root()+'/packet_power.tcl'
        m.put(client,sftp,m.out_dir()/'inputs/packet_power.tcl',remote)
        for row in rows:
            c=m.cfg(row['config']);tag=f"{m.BATCH}_{c['name']}_s{row['seed']}"
            root=m.stage_root()+'/power/'+tag;log=root+'/logs';report=root+'/reports';work=root+'/work'
            dut='SyncCmrRouter' if c['sync'] else 'CMRRouter'
            strip=('tb_router_matched_ppa_sync' if c['sync'] else 'tb_router_matched_ppa_async')+'/dut'
            env={'SYNOPSYS_LC_ROOT':'/soft/synopsys/lc/V-2023.12','CMR_REMOTE_ROOT':m.REMOTE_ROOT,
                'CMR_RUN_ID':tag,'CMR_NETLIST_RUN_ID':c['netlist'],'CMR_DUT_NAME':dut,
                'CMR_TB_STRIP':strip,'CMR_POWER_VCD_FILE':row['vcd'],'CMR_POWER_REPORT_DIR':report,
                'CMR_POWER_START_NS':f"{row['start_ns']:.3f}",'CMR_POWER_END_NS':f"{row['tail_capture_ns']:.3f}",
                'AUDIT_SLEW_NS':'0.05','AUDIT_LOAD_PF':'0.005','TMPDIR':m.stage_root()+'/tmp',
                'PT_TMPDIR':m.stage_root()+'/tmp'}
            inner='cd '+shlex.quote(work)+' && env '+' '.join(k+'='+shlex.quote(v) for k,v in env.items())+' /soft/synopsys/prime/V-2023.12/bin/pt_shell -f '+shlex.quote(remote)
            command=f'mkdir -p {log} {report} {work} {m.stage_root()}/tmp; bsub -n 1 {m.HOSTS} -oo {log}/lsf.log -J pktpx_{c["name"]}_s{row["seed"]} bash -lc '+shlex.quote(inner)
            reply=m.remote_run(client,command);jid=m.job_id(reply)
            jobs.append({**row,'job_id':jid,'report':report,'log':log,'tag':tag})
            print('PACKET_POWER_SUBMIT',c['name'],row['seed'],jid,flush=True)
    finally:sftp.close();client.close()
    (m.out_dir()/'power_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')

def collect_power():
    jobs=json.loads((m.out_dir()/'power_jobs.json').read_text())
    client=m.connect()
    try:
        for j in jobs:client=m.wait_job(client,j['job_id'],j['tag'],polls=240)
    finally:client.close()
    client=m.connect();sftp=client.open_sftp()
    try:
        for j in jobs:
            folder=m.out_dir()/'power'/j['config']/f"seed{j['seed']}"
            m.fetch_tree(sftp,j['report'],folder);m.fetch_tree(sftp,j['log'],folder/'logs')
    finally:sftp.close();client.close()

def reduce():
    jobs=json.loads((m.out_dir()/'power_jobs.json').read_text());rows=[]
    for j in jobs:
        folder=m.out_dir()/'power'/j['config']/f"seed{j['seed']}"
        log=(folder/'logs/lsf.log').read_text(errors='replace')
        if not re.search(r'^PPA_POWER_PASS reports=',log,re.M) or 'PT-063' in log:raise RuntimeError('PTPX failed '+j['tag'])
        for window,extra in [('active',0),('guard2',2),('guard5',5),('idle',10)]:
            suffix='' if window=='active' else '_'+window
            power=m.parse_power(folder/('power'+suffix+'.rpt'))
            activity=(folder/('activity'+suffix+'.rpt')).read_text(errors='replace')
            nets=re.search(r'^\s*Nets\s+\d+\(100\.00%\)',activity,re.M)
            if not power['power_sum_ok'] or not nets:raise RuntimeError('power/coverage failure '+j['tag']+' '+window)
            duration=10 if window=='idle' else j['duration_ns']+extra
            energy=power['total_power_w']*duration*1e3
            rows.append({'config':j['config'],'seed':j['seed'],'window':window,'duration_ns':duration,
                'packet_energy_pj':energy if window!='idle' else None,'energy_pj':energy,
                'pj_per_flit':energy/5 if window!='idle' else None,
                'pj_per_transferred_bit':energy/140 if window!='idle' else None,
                'pj_per_payload_bit':energy/96 if window!='idle' else None,
                'total_power_mw':power['total_power_w']*1e3,'internal_power_mw':power['internal_power_w']*1e3,
                'switching_power_mw':power['switching_power_w']*1e3,'leakage_power_uw':power['leakage_power_w']*1e6,
                'activity_percent':100,'power_pass':True})
    summaries=[]
    for c in m.CONFIGS:
        for window in ('active','guard2','guard5','idle'):
            selected=[r for r in rows if r['config']==c['name'] and r['window']==window]
            summaries.append({'config':c['name'],'window':window,'seeds':3,
                **{k:statistics.mean(r[k] for r in selected) for k in
                   ('duration_ns','energy_pj','total_power_mw','internal_power_mw','switching_power_mw','leakage_power_uw')},
                'energy_pj_sample_std':statistics.stdev(r['energy_pj'] for r in selected),
                'pj_per_flit':None if window=='idle' else statistics.mean(r['pj_per_flit'] for r in selected),
                'pj_per_transferred_bit':None if window=='idle' else statistics.mean(r['pj_per_transferred_bit'] for r in selected)})
    target=m.REPO/'results'/m.BATCH;target.mkdir(parents=True,exist_ok=True)
    for name,data in [('packet_power_samples',rows),('packet_power_summary',summaries)]:
        (target/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
        with (target/(name+'.csv')).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
    lines=['# 单个 5-flit 包功耗与能量','',
        '冻结 20261022 DC 网表；TT 0.8V 25°C；输入/时钟 slew 50ps，输出负载5fF；同步时钟1ns持续运行。',
        '一个源、一个5-flit单播包，按输入握手连续注入；每次复位后仅发送这一包；3个随机Body数据种子独立运行。',
        '包含整个DUT内部、网络翻转和漏电，不扣空闲功耗。每包140个传输bit，96个随机payload bit。',
        'active窗口：Head输入到Tail捕获；guard2/guard5在该窗口后加2ns/5ns。末flit Req时间比捕获时间提前90ps（异步）。',
        '仿真在交付后继续25ns，检查接口完全排空；idle窗口为Tail捕获后10..20ns。',
        'VCD审计观测到Tail捕获后最后的非时钟翻转：Thin 0.425ns、异步c1p4 0.556ns、同步c1p4 2.068ns。因此guard2未完全覆盖同步释放，guard5覆盖本次全部观测到的释放活动。',
        'guard窗口的同步时钟仍运行，故延长窗口会计入更多时钟能量；这是窗口定义的差异。',
        'guard5含释放完成后的少量空闲时间，不能称作唯一的或最小的整包能量；表中保留全部窗口以明确这一选择。',
        '9个GLS运行均5/5完整交付且settle PASS；9个PT-PX运行各4个窗口，共36个功耗窗口全部通过，活动覆盖100%。',
        '综合后ZeroWire估计：没有提取布局互连/CTS；仍须保留库表外推警告。3个种子的标准差只表示数据模式差异，不是硅后误差。','',
        '|Router|窗口|平均功耗mW|整包能量pJ|每flit pJ|每传输bit pJ|',
        '|---|---|---:|---:|---:|---:|']
    for r in summaries:
        if r['window']=='idle':continue
        lines.append(f"|{r['config']}|{r['window']}|{r['total_power_mw']:.6f}|{r['energy_pj']:.6f}|{r['pj_per_flit']:.6f}|{r['pj_per_transferred_bit']:.6f}|")
    (target/'RESULTS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    shutil.copy2(m.out_dir()/'packet_spec.json',target/'packet_spec.json')
    archive=m.archive_dir()/'analysis';archive.mkdir(parents=True,exist_ok=True)
    for p in target.iterdir():shutil.copy2(p,archive/p.name)
    shutil.copy2(Path(__file__),archive/Path(__file__).name)
    print('SINGLE_PACKET_POWER_PASS',target,flush=True)
    print(json.dumps(summaries,indent=2),flush=True)

def release_audit():
    """Inspect the saved DUT waveforms; omit clock and library clock-pin aliases."""
    rows=json.loads((m.out_dir()/'gls_packets.json').read_text());result=[]
    for row in rows:
        path=m.out_dir()/row['run_id']/f"seed{row['seed']}"/'hop_ppa.vcd'
        names={};scopes=[];header=[]
        with path.open(errors='replace') as f:
            for line in f:
                header.append(line)
                parts=line.split()
                if parts[:1]==['$scope']:scopes.append(parts[2])
                elif parts[:1]==['$upscope']:scopes.pop()
                elif parts[:1]==['$var']:
                    names.setdefault(parts[3],[]).append('.'.join(scopes+[parts[4]]))
                elif '$enddefinitions' in line:break
            match=re.search(r'\$timescale\s+(\d+)\s*(fs|ps|ns|us)\s+\$end',''.join(header))
            if not match:raise RuntimeError('unknown VCD timescale')
            unit=int(match[1])*{'fs':1e-6,'ps':1e-3,'ns':1,'us':1000}[match[2]]
            clocks={key for key,refs in names.items() if any(re.search(r'\.(clock|(?:cp|ck|clk)(?:_\w+)?)$',ref,re.I) for ref in refs)}
            state={};now=0;last=None;last_changes=[]
            for line in f:
                line=line.strip()
                if not line:continue
                if line[0]=='#':now=int(line[1:])*unit;continue
                if line[0] in '01xXzZ':value,key=line[0],line[1:]
                elif line[0] in 'bBrR':
                    parts=line.split()
                    if len(parts)!=2:continue
                    value,key=parts
                else:continue
                old=state.get(key);state[key]=value
                if old is None or old==value or key in clocks or key not in names:continue
                if now<row['tail_capture_ns'] or now>row['tail_capture_ns']+20:continue
                last=now
                last_changes.append({'time_ns':now,'aliases':names[key][:3]})
                last_changes=last_changes[-12:]
        result.append({'config':row['config'],'seed':row['seed'],
            'vcd_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'clock_identifier_groups_excluded':len(clocks),
            'last_nonclock_transition_after_tail_capture_ns':None if last is None else last-row['tail_capture_ns'],
            'last_changes':last_changes})
    target=m.REPO/'results'/m.BATCH;target.mkdir(parents=True,exist_ok=True)
    (target/'packet_release_audit.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps([{k:v for k,v in r.items() if k!='last_changes'} for r in result],indent=2),flush=True)

if __name__=='__main__':
    import sys
    command=sys.argv[1]
    if command=='run':
        prepare();m.submit()
        spec=json.loads((m.out_dir()/'experiment_spec.json').read_text())
        spec['workload']=json.loads((m.out_dir()/'packet_spec.json').read_text())
        (m.out_dir()/'experiment_spec.json').write_text(json.dumps(spec,indent=2)+'\n')
        collect_gls();submit_power();collect_power();reduce()
    elif command=='reduce':reduce()
    elif command=='release-audit':release_audit()
    elif command=='prepare':prepare();print('PREPARED',m.out_dir())
