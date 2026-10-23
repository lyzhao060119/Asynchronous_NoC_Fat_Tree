"""Fetch only small completed Sync power evidence; plot six matched benchmarks."""
import argparse, base64, csv, hashlib, json, logging, re, statistics
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import MultipleLocator
from plot_formal64_power_six_benchmarks import BENCHMARKS, BASE, SOURCE
from launch64_power_supplement import ROOT

OUT=BASE/'results/formal64_sync_async_power_20261022_r1'
SERIES=[('PROP_M16','M16 (Async)','#2463A0',''),
        ('FM64','Mesh (Async, legacy)','#D77732',''),
        ('SYNC_M16','M16 (Sync)','#2463A0','///')]

def write_csv(path,rows):
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def fetch():
    logging.getLogger('paramiko').setLevel(logging.CRITICAL)
    from run_remote_cmr_noc16_sdf import connect
    code=r'''
import pathlib,json,re,csv,hashlib
R=pathlib.Path(__ROOT__);allowed=__BENCHMARKS__
orig={j['tag']:j for j in json.loads((R/'manifest.json').read_text())['jobs']}
jobs=json.loads((R/'repair_submission_r2.json').read_text())['jobs']
auditfile=pathlib.Path('/home/ghy19/Asynchronous_Router_CMR/power_audit/20261022_sync_acceptance_r1/acceptance.json')
audits={j['tag']:j for j in json.loads(auditfile.read_text())} if auditfile.exists() else {}
result=[]
for j in jobs:
    o=orig[j['tag']]
    if o['design']!='SYNC_M16' or o['benchmark'] not in allowed:continue
    a=pathlib.Path(o['activity_dir']);r=pathlib.Path(j['report_dir']);log=pathlib.Path(j['ptpx_log']).read_text(errors='replace')
    assert 'FORMAL64_PTPX_CASE_PASS' in log,j['tag']
    errors=[line for line in log.splitlines() if line.startswith('Error:')]
    assert not [line for line in errors if '(PT-063)' not in line],(j['tag'],errors)
    row=list(csv.DictReader((a/'result.csv').open()))
    assert len(row)==1 and row[0]['pass_fail']=='PASS'
    assert all(int(row[0][k])==0 for k in ['missing_expected_flits','unexpected_flits','timeout_hit'])
    assert re.search(r'Nets\s+\d+\(100\.00%\)',(r/'activity.rpt').read_text())
    assert (a/'measurement.vcd.archive.json').is_file()
    files={name:r/name for name in ['power.rpt','activity.rpt','input_hashes.sha256']}
    files.update({'result.csv':a/'result.csv','measurement.vcd.archive.json':a/'measurement.vcd.archive.json'})
    record=dict(tag=j['tag'],benchmark=o['benchmark'],seed=o['seed'],load=o['load'],case_sha256=o['case_sha256'],pt_errors=errors,
                remote_ptpx_log=j['ptpx_log'],files={name:dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size) for name,p in files.items()},
                waveform_status=audits.get(j['tag'],{}).get('waveform',{}).get('status','NOT_YET_AUDITED'))
    result.append(record)
assert len(result)==18,len(result)
print(json.dumps(result))
'''.replace('__ROOT__',repr(ROOT)).replace('__BENCHMARKS__',repr([b for b,_,_ in BENCHMARKS]))
    c=connect();c.get_transport().channel_timeout=600
    try:
        payload=base64.b64encode(code.encode()).decode()
        command='/soft/GNU/python3.12/bin/python3 -c "import base64;exec(base64.b64decode(\''+payload+'\'))"'
        _,stdout,stderr=c.exec_command(command,timeout=600)
        text=stdout.read().decode();err=stderr.read().decode()
        assert stdout.channel.recv_exit_status()==0,err
        records=json.loads(text)
        s=c.open_sftp();s.get_channel().settimeout(600)
        total_bytes=0
        try:
            for row in records:
                folder=OUT/'sync_raw'/row['tag'];folder.mkdir(parents=True,exist_ok=True)
                for name,info in row['files'].items():
                    assert info['bytes']<1024*1024,(name,'not a small summary')
                    target=folder/name;s.get(info['path'],str(target))
                    assert hashlib.sha256(target.read_bytes()).hexdigest()==info['sha256']
                    total_bytes+=target.stat().st_size
                print('FETCHED',row['tag'],flush=True)
        finally:s.close()
        (OUT/'sync_source_manifest.json').write_text(json.dumps(dict(root=ROOT,records=records,downloaded_bytes=total_bytes),indent=2),encoding='utf-8')
        print('SYNC_FETCH_PASS cases=18 bytes='+str(total_bytes),flush=True)
    finally:c.close()

def power(text,label):
    m=re.search(re.escape(label)+r'\s*=\s*([\d.eE+-]+)',text)
    assert m,label
    return float(m[1])

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--fetch',action='store_true')
    ap.add_argument('--plot-only',action='store_true',help='Preserve existing CSV files during visual-only edits')
    args=ap.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    if args.fetch:fetch()
    meta=json.loads((OUT/'sync_source_manifest.json').read_text())
    seeds=[]
    for j in meta['records']:
        folder=OUT/'sync_raw'/j['tag'];text=(folder/'power.rpt').read_text()
        with (folder/'result.csv').open(newline='') as f:r=list(csv.DictReader(f))[0]
        duration=(int(r['measurement_end_ps'])-int(r['measurement_start_ps']))*1e-12
        p=power(text,'Total Power')
        seeds.append(dict(design='SYNC_M16',benchmark=j['benchmark'],seed=j['seed'],load=j['load'],variant='sync_current',
                          total_w=p,power_mw=p*1000,window_s=duration,energy_nj=p*duration*1e9,
                          internal_w=power(text,'Cell Internal Power'),switching_w=power(text,'Net Switching Power'),leakage_w=power(text,'Cell Leakage Power'),
                          ptpx_pass=True,provisional=True,waveform_boundary_status=j['waveform_status'],
                          source=str((folder/'result.csv').relative_to(BASE))))
    sync_rows=list(seeds)
    with SOURCE.open(newline='',encoding='utf-8-sig') as f:old=list(csv.DictReader(f))
    allowed={b:load for b,_,load in BENCHMARKS}
    for r in old:
        if r['design'] not in ('PROP_M16','FM64') or r['benchmark'] not in allowed:continue
        if r['variant']=='native_repeated_compact' or r['accepted'].lower()!='true':continue
        assert int(r['load'])==allowed[r['benchmark']]
        seeds.append(dict(design=r['design'],benchmark=r['benchmark'],seed=int(r['seed']),load=int(r['load']),variant=r['variant'],
                          total_w=float(r['total_w']),power_mw=float(r['total_w'])*1000,window_s=float(r['window_s']),energy_nj=float(r['energy_nj']),
                          internal_w=float(r['internal_w']),switching_w=float(r['switching_w']),leakage_w=float(r['leakage_w']),
                          ptpx_pass=True,provisional=True,waveform_boundary_status='BOUNDARY_COVERAGE_OK',source=str(SOURCE.relative_to(BASE))))
    assert len(seeds)==54
    means=[]
    for design,label,color,hatch in SERIES:
        for b,_,load in BENCHMARKS:
            rr=[r for r in seeds if r['design']==design and r['benchmark']==b]
            assert len(rr)==3 and {r['seed'] for r in rr}=={202701,202702,202703},(design,b)
            assert {r['load'] for r in rr}=={load}
            values=[r['power_mw'] for r in rr]
            means.append(dict(design=design,benchmark=b,load=load,n_seeds=3,power_mw_mean=statistics.mean(values),power_mw_sample_sd=statistics.stdev(values),provisional=True))
    if not args.plot_only:
        write_csv(OUT/'sync_power_all_seeds.csv',sync_rows)
        write_csv(OUT/'combined_power_all_seeds.csv',seeds)
        write_csv(OUT/'power_three_seed_means.csv',means)
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,'ps.fonttype':42,
                         'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.8,'hatch.linewidth':.85})
    fig,ax=plt.subplots(figsize=(9.8,5.1));fig.subplots_adjust(left=.09,right=.985,bottom=.27,top=.82)
    x=np.arange(6);width=.235
    ax.axvspan(2.5,5.55,color='#F2F5F8',zorder=0)
    ax.axvline(2.5,color='#BFC8D1',lw=.8,ls=(0,(3,3)),zorder=1)
    for i,(d,label,color,hatch) in enumerate(SERIES):
        rr=[r for r in means if r['design']==d];y=[r['power_mw_mean'] for r in rr];sd=[r['power_mw_sample_sd'] for r in rr]
        bars=ax.bar(x+(i-1)*width,y,width=width*.94,color=color,edgecolor='white',linewidth=.65,hatch=hatch,label=label,zorder=3)
        ax.errorbar(x+(i-1)*width,y,yerr=sd,fmt='none',ecolor='#27333F',elinewidth=.8,capsize=2.5,capthick=.8,zorder=4)
        for bar,v,e in zip(bars,y,sd):ax.text(bar.get_x()+bar.get_width()/2,v+e+3,f'{v:.1f}',ha='center',va='bottom',fontsize=8,color='#354250')
    ax.set(xlim=(-.55,5.55),ylim=(0,320),ylabel='Total network power (mW)')
    ax.set_xticks(x);ax.set_xticklabels([f'{label}\n({load} Mflit/s/port)' for _,label,load in BENCHMARKS],fontsize=9)
    ax.yaxis.set_major_locator(MultipleLocator(50));ax.grid(axis='y',color='#DCE2E8',linewidth=.65);ax.set_axisbelow(True)
    ax.tick_params(axis='x',length=0,pad=8)
    for side in ('left','bottom'):ax.spines[side].set_color('#66717C')
    fig.text(.09,.955,'64-node network power',fontsize=14,fontweight='semibold',color='#17212B',va='top')
    fig.legend(*ax.get_legend_handles_labels(),loc='upper left',bbox_to_anchor=(.084,.91),ncol=3,frameon=False,fontsize=10,columnspacing=1.8,handlelength=1.5)
    fig.text(.09,.10,'Three-seed mean with sample SD; TT 0.8 V, 25 C; Sync clock: 1 GHz.',fontsize=8.5,color='#5D6772')
    fig.text(.09,.062,'Hatched bars: synchronous M16. Mesh uses historical routing; no axis break or normalization.',fontsize=8,color='#5D6772')
    fig.text(.09,.025,'Provisional synthesis estimates: PT/library warnings remain; extended Sync waveform audit is pending.',fontsize=8,color='#5D6772')
    for ext in ('png','pdf'):fig.savefig(OUT/f'formal64_sync_async_power.{ext}',dpi=320)
    plt.close(fig)
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.suffix in ('.csv','.png','.pdf')}
    (OUT/'plot_manifest.json').write_text(json.dumps(dict(source_async=str(SOURCE.relative_to(BASE)),source_async_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),outputs=hashes,means=means,excluded=['PFAT64','ALL-MULTICAST-AABB','ALL-BROADCAST'],sync_clock_ghz=1,ylimits_mw=[0,320],provisional=True),indent=2),encoding='utf-8')
    print('SYNC_ASYNC_POWER_PLOT_PASS groups=18 seed_records=54',flush=True)

if __name__=='__main__':main()
