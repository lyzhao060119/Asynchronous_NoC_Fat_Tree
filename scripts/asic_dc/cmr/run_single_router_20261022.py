"""Additive three-router experiment using current DC outputs and matched traffic."""
from pathlib import Path
import csv
import json
import os
import re
import statistics
import time

os.environ.setdefault('CMR_MATCHED_BATCH', 'single_router_20261022_r2')
import run_router_matched_ppa as m

original_remote_run = m.remote_run
def remote_run(client, command):
    command = command.replace('bsub -n 8 ', 'bsub -n 1 ').replace('bsub -n 4 ', 'bsub -n 1 ')
    return original_remote_run(client, command)
m.remote_run = remote_run
original_put = m.put
def put(client, sftp, local, remote):
    if local.name == 'run_ptpx_cmr_router_hop_ppa.tcl':
        local = m.out_dir()/'inputs'/local.name
    return original_put(client, sftp, local, remote)
m.put = put

HERE = Path(__file__).resolve().parent
RUNS = {name: '20261022_router_ppa_r1_' + name for name in
        ('async_c1p1', 'async_c1p4', 'sync_c1p4')}
for config in m.CONFIGS:
    config['netlist'] = RUNS[config['name']]


def prepare():
    target = m.out_dir() / 'inputs'
    target.mkdir(parents=True, exist_ok=True)
    sync_source = m.TB_FILES[True].read_text()
    common_flit = re.search(r'  function automatic \[FLIT_W-1:0\] flit_for.*?endfunction',
                            sync_source, re.S).group()
    for sync, source in list(m.TB_FILES.items()):
        text = source.read_text()
        # Use identical route-bearing data on both architectures. The clocked
        # implementation requires the route fields on body flits as well.
        if not sync:
            text = re.sub(r'  function automatic \[FLIT_W-1:0\] flit_for.*?endfunction',
                          lambda _: common_flit, text, flags=re.S)
            text = text.replace('src=x[1:0];', 'src=(x[1:0]+3)%4;')
        text = text.replace('  string mode',
            '  real inject_ns[0:3][0:11999];\n  string mode', 1)
        if sync:
            text = text.replace("if(tb_in_ready[port]) begin tb_in_valid[port]=1'b0; break; end",
                "if(tb_in_ready[port]) begin inject_ns[src][pk*5+fl]=$realtime; #0.001; tb_in_valid[port]=1'b0; break; end")
            text = text.replace("repeat(8) @(posedge clock);reset=1'b0;repeat(4) @(posedge clock);running=1'b1;",
                "repeat(8) @(negedge clock);reset=1'b0;repeat(4) @(negedge clock);running=1'b1;")
            text = text.replace('    if (mode=="isolated") begin\n      @(posedge clock);',
                                '    if (mode=="isolated") begin\n      @(negedge clock);')
            text = text.replace('    end else begin\n      @(posedge clock);',
                                '    end else begin\n      @(negedge clock);')
            text = text.replace('measurement_received);',
                'measurement_received,inject_ns[src][pk*5+ph],$realtime-inject_ns[src][pk*5+ph]);')
        else:
            text = text.replace('#(setup_ns); tb_in_req[port]=~tb_in_req[port];',
                '#(setup_ns); inject_ns[src][pk*5+fl]=$realtime; tb_in_req[port]=~tb_in_req[port];')
            text = text.replace('measurement_received);',
                'measurement_received,inject_ns[src][pk*5+ph],$realtime-inject_ns[src][pk*5+ph]);')
        # Only CSV records receive the extra columns (display markers remain intact).
        text = text.replace('$fdisplay(csv_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",',
                            '$fdisplay(csv_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%.6f,%.6f",')
        text = text.replace('data,measurement,received,measurement_received"',
                            'data,measurement,received,measurement_received,input_ns,latency_ns"')
        if sync:
            assert 'while(1) begin\n          @(posedge clock);' in text
        destination = target / source.name
        destination.write_text(text, encoding='utf-8')
        m.TB_FILES[sync] = destination
    spec = {'runs': RUNS, 'corner': 'tt0p8v25c', 'clock_ns': 1.0,
            'flit_bits': 28, 'packet_flits': 5,
            'payload': 'identical route-bearing flits on sync and async; source tags; no packet ID',
            'latency': 'mean of individual input-to-output flit latencies; sync input handshake edge; async input request; output capture/handshake',
            'energy': 'total and dynamic PT-PX window energy / delivered flits / 28',
            'area': 'DC total cell area, post synthesis, no P&R'}
    (m.out_dir() / 'scope.json').write_text(json.dumps(spec, indent=2)+'\n')
    power_source = (m.REPO/'scripts/asic_dc/power/run_ptpx_cmr_router_hop_ppa.tcl').read_text()
    power_source = power_source.replace('set LIB_DIR "/process/course_lib/t28hpc+"',
        'set LIB_DIR "/process/tsmc/CLN28HPC+/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp12t30p140_180a"')
    power_source = power_source.replace('tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db',
                                         'tcbn28hpcplusbwp12t30p140tt0p8v25c_ccs.db')
    (target/'run_ptpx_cmr_router_hop_ppa.tcl').write_text(power_source)


original_window = m.event_window
def event_window(events, sync, mode):
    if mode == 'isolated':
        if len(events) != 5:
            raise ValueError('isolated requires exactly five flits')
        start = min(float(e['input_ns']) for e in events)
        end = max(float(e['input_ns'])+float(e['latency_ns']) for e in events)
        return start, end
    selected = [e for e in events if e.get('measurement')=='1']
    if len(selected)!=40000:raise ValueError('aggregate requires 40000 flits')
    # Both clocks use absolute VCD time, including the reset interval.
    times=[float(e['input_ns'])+float(e['latency_ns']) for e in selected]
    return min(times),max(times)
m.event_window = event_window


def summarize():
    manifest = json.loads((m.archive_dir()/'manifest.json').read_text())
    power_audit=[]
    for power in manifest['ptpx']:
        folder=m.out_dir()/'ptpx'/power['tag']
        log=(folder/'logs'/'lsf.log').read_text(errors='replace')
        check=(folder/'check_power.rpt').read_text(errors='replace')
        nets=re.search(r'Number of annotated nets = (\d+) \(([0-9.]+)%\)',log)
        cells=re.search(r'Number of fully annotated leaf cells = (\d+) \(([0-9.]+)%\)',log)
        passed=bool(re.search(r'^PPA_POWER_PASS reports=',log,re.M))
        if not (passed and nets and cells and float(nets[2])==100 and float(cells[2])==100):
            raise RuntimeError('power annotation audit failed: '+power['tag'])
        power_audit.append({'config':power['config'],'mode':power['mode'],
            'actual_pass_marker':passed,'annotated_nets_percent':float(nets[2]),
            'fully_annotated_leaf_cells_percent':float(cells[2]),
            'out_of_range_ramps':int((re.search(r'(\d+) out_of_range ramps',check) or ['','0'])[1]),
            'out_of_range_loads':int((re.search(r'(\d+) out_of_range loads',check) or ['','0'])[1])})
    (m.out_dir()/'power_audit.json').write_text(json.dumps(power_audit,indent=2)+'\n')
    rows = []
    isolated_flits = []
    for config in m.CONFIGS:
        name = config['name']
        qor = HERE/'results'/RUNS[name]/'reports_dc'/'qor.rpt'
        area = re.search(r'(?:Total\s+)?Cell Area:\s*([0-9.eE+-]+)', qor.read_text(), re.I)
        for mode in ('isolated', 'aggregate'):
            gls = next(g for g in manifest['gls'] if g['config']==name and g['mode']==mode)
            power = next((p for p in manifest['ptpx'] if p['config']==name and p['mode']==mode), {})
            events = m.read_events(m.out_dir()/gls['run_id']/mode/'hop_events.csv', config['sync'], mode)
            selected = [e for e in events if e['measurement']=='1']
            if not selected or any(float(e['input_ns'])<=0 or float(e['latency_ns'])<0 for e in selected):
                raise RuntimeError('invalid input/latency timestamp: '+name+' '+mode)
            capture_offset = 0.0 if config['sync'] else 0.09
            latency = [float(e['latency_ns'])-capture_offset for e in selected]
            if mode=='isolated':
                isolated_flits.extend({'config':name,'flit':int(e['flit']),
                    'latency_ns':float(e['latency_ns'])-capture_offset} for e in selected)
            rows.append({'config': name, 'mode': mode, 'area_um2':float(area.group(1)),
                         'gls_pass':gls['functional_pass'], 'power_pass':power.get('power_pass',False),
                         'mean_flit_latency_ns':statistics.mean(latency) if latency else None,
                         'total_pj_per_bit':power.get('total_pj_per_bit'),
                         'dynamic_pj_per_bit':power.get('dynamic_pj_per_bit'),
                         'active_parent_lanes':gls['active_parent_lanes'],
                         'capture_offset_removed_ns':capture_offset,
                         'head_ns':statistics.mean(float(e['latency_ns'])-capture_offset for e in selected if e['flit']=='0') if selected else None,
                         'tail_ns':statistics.mean(float(e['latency_ns'])-capture_offset for e in selected if e['flit']=='4') if selected else None})
    (m.out_dir()/'summary.json').write_text(json.dumps(rows,indent=2)+'\n')
    with (m.out_dir()/'summary.csv').open('w', newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    with (m.out_dir()/'isolated_flits.csv').open('w', newline='') as f:
        writer=csv.DictWriter(f,fieldnames=['config','flit','latency_ns']);writer.writeheader();writer.writerows(isolated_flits)
    details = [
        '# Single Router results, 2026-10-22', '',
        'TT 0.8 V 25 C; 28 transported bits/flit; 5 flits/packet; sync clock 1 ns.',
        'Area is synthesized standard cell area, with no place and route.',
        'Energy = PT-PX window power x duration / (delivered flits x 28). Total includes leakage.',
        'Isolated energy covers first input through final output capture. Aggregate uses the 40000-flit output window.',
        'Latency is the arithmetic mean of each flit latency, not packet time divided by five.',
        'Async latency is input Req to output Req; the fixed 0.09 ns receiver capture delay is removed from raw timestamps.',
        'Sync latency is input valid/ready acceptance edge to output valid/ready acceptance edge.',
        'Traffic uses identical route-bearing data, with low payload switching. These are workload-specific energy values.',
        'A partial active-lane count describes the observed implementation and does not imply four active lanes.', '',
        'All six PT-PX windows have 100% net and leaf-cell activity annotation and an actual PPA_POWER_PASS marker.',
        'check_power reports out-of-table slew/load values. Energy is a post-synthesis estimate with library extrapolation, not power signoff.', '',
        '| Config | Mode | Area um2 | Total pJ/bit | Dynamic pJ/bit | Mean flit ns | Active parent lanes | GLS/PT-PX |',
        '|---|---|---:|---:|---:|---:|---:|---|']
    for r in rows:
        def fmt(value):return 'unavailable' if value is None else f'{value:.6f}'
        details.append(f"| {r['config']} | {r['mode']} | {r['area_um2']:.3f} | {fmt(r['total_pj_per_bit'])} | {fmt(r['dynamic_pj_per_bit'])} | {fmt(r['mean_flit_latency_ns'])} | {r['active_parent_lanes']} | {r['gls_pass']}/{r['power_pass']} |")
    (m.out_dir()/'RESULTS.md').write_text('\n'.join(details)+'\n')
    hashes={str(p.relative_to(m.REPO)):m.digest(p) for p in
            [Path(__file__), *list((m.out_dir()/'inputs').glob('*'))] if p.is_file()}
    (m.out_dir()/'analysis_hashes.json').write_text(json.dumps(hashes,indent=2)+'\n')
    reduction={'async_output_capture_offset_removed_ns':0.09,
               'timestamp_gate':'all measured inputs > 0 and raw latencies >= 0',
               'isolated_flit_count':5,'aggregate_measurement_flits':40000}
    (m.out_dir()/'reduction_scope.json').write_text(json.dumps(reduction,indent=2)+'\n')
    scope=json.loads((m.out_dir()/'scope.json').read_text())
    scope['reported_latency']='Async input Req to output Req (90 ps capture removed); sync input acceptance to output acceptance; arithmetic mean across five flits'
    (m.out_dir()/'scope.json').write_text(json.dumps(scope,indent=2)+'\n')
    import shutil
    analysis=m.archive_dir()/'analysis'
    analysis.mkdir(parents=True,exist_ok=True)
    for filename in ('summary.json','summary.csv','isolated_flits.csv','RESULTS.md',
                     'analysis_hashes.json','reduction_scope.json','scope.json','power_audit.json'):
        shutil.copy2(m.out_dir()/filename,analysis/filename)
    shutil.copy2(Path(__file__),analysis/Path(__file__).name)
    print(json.dumps(rows,indent=2),flush=True)


if __name__ == '__main__':
    import sys
    prepare()
    command = sys.argv[1]
    if command == 'prepare':
        print('PREPARED', m.out_dir())
    elif command in ('run', 'await-dc-run'):
        if command == 'await-dc-run':
            for attempt in range(360):
                ready = all((HERE/'results'/run/'summary.json').is_file() for run in RUNS.values())
                if ready:break
                print('WAIT_DC_ARTIFACTS', attempt, flush=True)
                time.sleep(20)
            else:raise RuntimeError('DC artifact timeout')
        # A three-lane sync result remains measurable, with its active lane
        # count reported explicitly; it is not a four-active-lane claim.
        os.environ['CMR_ALLOW_PARTIAL_LANES_POWER']='1'
        m.submit()
        m.collect(wait=True)
        m.submit_ptpx()
        jobs=json.loads((m.out_dir()/'ptpx_jobs.json').read_text())
        for job in jobs:
            client=m.connect()
            try:m.wait_job(client,job['job_id'],job['tag'],polls=240)
            finally:client.close()
        m.finalize()
        summarize()
    elif command == 'summarize':
        summarize()
    elif command == 'status':
        client=m.connect()
        try:
            print(m.remote_run(client, 'busers; bjobs -w | head -n 1; bjobs -w | grep -E "matched_|ppx_|20261022_router_ppa"; '
                f'for f in {m.stage_root()}/logs/*/lsf.log {m.stage_root()}/logs/*/ptpx/lsf.log; do '
                'test -f "$f" || continue; echo "$f"; tail -n 12 "$f"; done'),flush=True)
        finally:client.close()
    elif command == 'slots':
        # These are standalone, single-process DC runs. Reduce scheduler
        # reservations without changing any unrelated experiment jobs.
        client=m.connect()
        try:
            jobs=m.remote_run(client, 'bjobs -noheader -o "jobid stat job_name"')
            for line in jobs.splitlines():
                if '20261022_router_ppa_r1_' in line and 'PEND' in line:
                    jid=line.split()[0]
                    if jid.isdigit():print(m.remote_run(client,'bmod -n 1 '+jid),flush=True)
        finally:client.close()
