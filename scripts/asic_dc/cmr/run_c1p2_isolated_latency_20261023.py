"""Measure c1p2 with the frozen r3 Thin isolated-flit testbench."""
import csv
import hashlib
import json
import re
import shlex
import statistics
import shutil
import sys
from pathlib import Path
import run_router_matched_ppa as m

m.BATCH='single_router_c1p2_isolated_latency_20261023_r1'
NETLIST='20261023_router_latency_r1b_async_c1p2'
SOURCE=m.HERE/'results/single_router_latency_power_20261022_r3/inputs'
OUT=m.out_dir()

def prepare():
    dest=OUT/'inputs';dest.mkdir(parents=True,exist_ok=True)
    t=(SOURCE/'tb_router_matched_ppa_async.sv').read_text()
    t=t.replace('`ifdef GEOM_C1_P4\n  localparam', '`ifdef GEOM_C1_P2\n  localparam integer CHILD_LANES=1, PARENT_LANES=2;\n`elsif GEOM_C1_P4\n  localparam',1)
    t=t.replace('`ifdef GEOM_C1_P4\n  CMRRouter dut', '`ifdef GEOM_C1_P2\n  CMRRouter dut (`include "async_ports_c1_p2.vi");\n`elsif GEOM_C1_P4\n  CMRRouter dut',1)
    (dest/'tb_router_matched_ppa_async.sv').write_text(t)
    w=(SOURCE/'run_gls_router_matched_ppa.sh').read_text()
    w=w.replace('case "$KIND" in','case "$KIND" in\n  async_fat_1x2) DEF=\'+define+GEOM_C1_P2\'; PREFIX=async_ports_c1_p2.vi ;;',1)
    w=w.replace('run_mode packet\nrun_mode aggregate\n','')
    # Refuse reuse of an existing simulation work directory.
    w=w.replace('rm -rf -- "$WORK";', 'test ! -e "$WORK";')
    (dest/'run_gls_router_matched_ppa.sh').write_text(w)
    m.TB_FILES={False:dest/'tb_router_matched_ppa_async.sv'}
    m.WRAPPER=dest/'run_gls_router_matched_ppa.sh'
    m.CONFIGS=[{'name':'async_c1p2','kind':'async_fat_1x2','netlist':NETLIST,'sync':False,'lanes':2}]

def submit():
    m.preflight()
    client=m.connect();sftp=client.open_sftp()
    try:
        base=m.upload_inputs(client,sftp,m.CONFIGS)
        log=m.stage_root()+'/logs/'+m.BATCH+'_async_c1p2'
        m.remote_run(client,'mkdir -p '+shlex.quote(log))
        env={'CMR_REMOTE_ROOT':m.REMOTE_ROOT,'CMR_RUN_ID':m.BATCH+'_async_c1p2',
             'CMR_NETLIST_RUN_ID':NETLIST,'CMR_HOP_KIND':'async_fat_1x2','CMR_MATCHED_SYNC':'0',
             'CMR_MATCHED_TB_ROOT':base,'CMR_MATCHED_LOG_ROOT':log}
        command='bsub -n 1 '+m.HOSTS+' -oo '+shlex.quote(log+'/lsf.log')+' -J c1p2_isolated env '
        command+=' '.join(k+'='+shlex.quote(v) for k,v in env.items())+' bash '+base+'/'+m.WRAPPER.name
        reply=m.remote_run(client,command)
        data={'job_id':m.job_id(reply),'log':log,'netlist':NETLIST}
        (OUT/'job.json').write_text(json.dumps(data,indent=2))
        print(json.dumps(data),flush=True)
    finally:sftp.close();client.close()

def collect():
    job=json.loads((OUT/'job.json').read_text())
    client=m.connect();sftp=client.open_sftp()
    try:
        print(m.remote_run(client,'bjobs -a '+job['job_id']),flush=True)
        m.fetch_tree(sftp,job['log'],OUT/'gls')
    finally:sftp.close();client.close()
    run=(OUT/'gls/isolated/run.log').read_text()
    sdf=(OUT/'gls/isolated/sdf_annotate.log').read_text()
    wrapper=(OUT/'gls/lsf.log').read_text()
    events=list(csv.DictReader((OUT/'gls/isolated/hop_events.csv').open()))
    assert all(marker in run for marker in ['MATCHED_RESULT PASS','PPA_RESULT PASS'])
    assert 'MATCHED_GLS_PASS' in wrapper
    assert re.search(r'Total errors:\s*0\b',sdf)
    assert not re.search(r'Timing violation|MATCHED_FAIL|PPA_RESULT FAIL|Fatal:|Error-',run)
    assert len(events)==5 and {int(e['flit']) for e in events}==set(range(5))
    rows=[]
    for e in events:
        inp=float(e['input_ns']);capture=float(e['time_ps'])/1000
        assert abs(capture-inp-float(e['latency_ns']))<1e-6
        rows.append({'flit':int(e['flit']),'input_req_ns':inp,'output_req_ns':capture-.09,
                     'latency_ns':capture-.09-inp,'lane':int(e['lane'])})
    result={'config':'async_c1p2','netlist_run':NETLIST,'gls_pass':True,'sdf_errors_zero':True,
            'metric':'mean(output_req-input_req), five output-paced low-switching flits; 90ps capture offset removed',
            'mean_flit_latency_ns':statistics.mean(r['latency_ns'] for r in rows),'events':rows,
            'corner':'TT 0.8V 25C; MAXIMUM SDF; post-synthesis',
            'source_tb_sha256':hashlib.sha256((SOURCE/'tb_router_matched_ppa_async.sv').read_bytes()).hexdigest()}
    dc=json.loads((m.HERE/'results'/NETLIST/'summary.json').read_text())
    assert dc['dc']['pass']
    result['dc_pass']=True
    result['dc_job_id']=dc['dc']['job_id']
    result['gls_job_id']=job['job_id']
    result['cell_recipe_note']='Same sizing targets as Thin; geometry-specific XNR4 count checked as exactly 8 instead of c1p4-derived 12.'
    target=m.REPO/'results'/m.BATCH;target.mkdir(exist_ok=True)
    (target/'summary.json').write_text(json.dumps(result,indent=2))
    with (target/'flit_events.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    (target/'RESULTS.md').write_text('# c1p2 isolated-flit latency\n\n'
        +f"Mean input-Req to output-Req latency: **{result['mean_flit_latency_ns']:.4f} ns**.\n\n"
        +'Same frozen r3 low-switching, output-paced five-flit test as Thin 0.6556 ns; only geometry bindings changed. '
        +'This is not packet completion divided by five. MAXIMUM SDF, TT 0.8 V 25 C, post-synthesis. '
        +'Five flits delivered; GLS PASS, zero SDF errors, no timing violations.\n\n'
        +'Cell sizing targets match the Thin recipe. The geometry-specific mapped XNR4 count is checked as exactly 8; all are sized to D2. The initial run with the c1p4-derived count check is retained separately.\n')
    (target/'status.json').write_text(json.dumps({'status':'COMPLETE','dc_pass':True,'gls_pass':True,
        'dc_run_id':NETLIST,'dc_job_id':dc['dc']['job_id'],'gls_job_id':job['job_id'],
        'mean_flit_latency_ns':result['mean_flit_latency_ns']},indent=2))
    (target/'STATUS.md').write_text('Completed. See RESULTS.md, summary.json and flit_events.csv.\n')
    archive=m.archive_dir();archive.mkdir(parents=True,exist_ok=True)
    for name in ('summary.json','flit_events.csv','RESULTS.md','status.json'):
        shutil.copy2(target/name,archive/name)
    shutil.copy2(Path(__file__),archive/Path(__file__).name)
    shutil.copytree(OUT/'inputs',archive/'inputs',dirs_exist_ok=True)
    shutil.copytree(OUT/'gls',archive/'gls',dirs_exist_ok=True)
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    prepare()
    {'submit':submit,'collect':collect,'prepare':lambda:print(OUT)}[sys.argv[1]]()
