"""Prepare PFAT power work; start only after the repaired-netlist scan audit passes."""
import json
import hashlib
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

HERE = Path(__file__).resolve().parent
HOME = '/home/ghy19/Asynchronous_Router_CMR'
SCAN = HOME + '/experiments/20261020_pfat64_fig2_mc_r1'
ROOT = HOME + '/formal64_power_pfat/20261020_fig2_8bench_3seed_r1'

STARTER = r'''import os,json,subprocess,re,hashlib,sys
from pathlib import Path
R=Path(__file__).resolve().parent
E=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261020_pfat64_fig2_mc_r1')
N=Path('/home/ghy19/Asynchronous_Router_CMR/outputs/20261019_archive_pfat64_fig2_tailrel100buf0_tt_r1')
PY='/soft/GNU/python3.12/bin/python3'
if (R/'manifest.json').exists():
 raise RuntimeError('power already submitted; refusing duplicate jobs')
selection=Path('/prjtemp/ghy19/date2027_formal64/power_selection_r2/mesh64_power_points.json')
entries=json.loads(selection.read_text())['benchmarks']
assert len(entries)==8 and all(x['status']=='READY' for x in entries)
items=[]
for entry in entries:
 b=entry['benchmark'];load=int(entry['selected_load'])
 for seed in [202701,202702,202703]:
  stem='%s_n64_s%d_m%d_PFAT64_top8.case'%(b,seed,load)
  candidates=[E/'cases'/stem]
  for src in entry['source_csv']:
   campaign=Path(src['path']).parent.parent.parent
   candidates.extend([campaign/'cases'/stem,campaign/'cases'/stem.replace('_top8','')])
  found=next((p for p in candidates if p.is_file() and p.stat().st_size),None)
  if found is None: raise RuntimeError('missing existing PFAT case: '+stem)
  tag='%s_s%d_m%d'%(b,seed,load)
  items.append(dict(benchmark=b,seed=seed,load=load,case=str(found),tag=tag,
                    case_sha256=hashlib.sha256(found.read_bytes()).hexdigest()))
assert len(items)==24
if '--preflight' in sys.argv:
 (R/'power_points.json').write_text(json.dumps(items,indent=2))
 print('PFAT_POWER_PREFLIGHT_PASS cases=24')
 sys.exit(0)
audit=json.loads((E/'manifests/final_acceptance_r3.json').read_text())
if audit['pending'] or audit['accepted_required']!=audit['required']:
 raise RuntimeError('scan acceptance incomplete; no power submission')
def submit(name,slots,cmd,log,dep=None):
 args=['bsub','-q','normal','-n',str(slots),'-J',name,'-o',str(log),'-e',str(log)+'.err']
 if dep:args+=['-w','done(%s)'%dep]
 out=subprocess.check_output(args+cmd,text=True);print(out.strip(),flush=True)
 return re.search(r'<(\d+)>',out).group(1)
previous=[None]*3
for i,item in enumerate(items):
 lane=i%3;tag=item['tag'];a=R/'activity'/tag;r=R/'reports'/tag;l=R/'logs'/tag
 for d in [a,r,l]:d.mkdir(parents=True,exist_ok=True)
 env=dict(FORMAL64_POWER_DESIGN='PFAT64',FORMAL64_POWER_CASE_FILE=item['case'],
  FORMAL64_POWER_CASE_NAME=tag,FORMAL64_POWER_TAG=tag,FORMAL64_POWER_ROOT=str(R),
  FORMAL64_ASYNC_ROOT=str(E),FORMAL64_SYNC_SIMV='unused',
  FORMAL64_POWER_VCD_STORAGE_DIR=str(R/'vcd'),E2_SDF_SLOT=str(lane))
 act=submit('pfat_act_'+tag,1,['env']+[k+'='+v for k,v in env.items()]+['bash',str(R/'activity.sh')],a/'lsf.log',previous[lane])
 px=submit('pfat_px_'+tag,4,[PY,str(R/'ptpx.py'),'--activity',str(a),'--report',str(r),
  '--tcl',str(R/'ptpx.tcl'),'--netlist-root',str(N),'--ddc-name','NoC_64nodes.ddc',
  '--netlist-name','NoC_64nodes_post.v','--sdf-name','NoC_64nodes.sdf','--top','NoC_64nodes',
  '--strip-path','tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc.noc/dut'],l/'ptpx.log',act)
 archive=submit('pfat_gz_'+tag,1,[PY,str(R/'archive.py'),'--activity',str(a),'--ptpx-log',str(l/'ptpx.log')],l/'archive.log',px)
 previous[lane]=archive;item.update(activity_job=act,ptpx_job=px,archive_job=archive)
 (R/'submission_progress.json').write_text(json.dumps(items[:i+1],indent=2))
(R/'manifest.json').write_text(json.dumps(dict(selection=str(selection),netlist=str(N),scan_audit=str(E/'manifests/final_acceptance_r3.json'),jobs=items),indent=2))
print('PFAT_POWER_QUEUED cases=24 chains=3',flush=True)
'''

def main():
    client = connect()
    try:
        print(remote_run(client, 'mkdir -p ' + ROOT), flush=True)
        sftp = client.open_sftp()
        activity = (HERE/'run_formal64_power_activity_remote.sh').read_text()
        activity = activity.replace('  PROP_M16|FM64)\n',
            '  PFAT64)\n    SIMV="$ASYNC_ROOT/work/PFAT64_fig2_r2/simv"\n'
            '    SDF_LOG="$ASYNC_ROOT/work/PFAT64_fig2_r2/sdf_slot${E2_SDF_SLOT:?}.log"\n    ;;\n  PROP_M16|FM64)\n')
        activity = activity.replace('"$SIMV" +CASE_FILE=', '"$SIMV" +SDF_SLOT="${E2_SDF_SLOT:?}" +CASE_FILE=')
        files = {'start.py': STARTER, 'activity.sh': activity,
                 'ptpx.py': (HERE/'run_formal64_mesh_ptpx_case.py').read_text(),
                 'ptpx.tcl': (HERE.parent/'power/run_ptpx_cmr_mesh_power.tcl').read_text(),
                 'archive.py': (HERE/'archive_formal64_power_vcd.py').read_text()}
        for name, content in files.items():
            with sftp.file(ROOT+'/'+name, 'w') as stream:
                stream.write(content.replace('\r\n','\n'))
        hashes={name:hashlib.sha256(content.replace('\r\n','\n').encode()).hexdigest() for name,content in files.items()}
        with sftp.file(ROOT+'/scripts_sha256.json','w') as stream:stream.write(json.dumps(hashes,indent=2))
        sftp.close()
        # Fail closed; invocation is deferred until final scan audit has passed.
        print('PFAT_POWER_PREPARED root='+ROOT, flush=True)
    finally:
        client.close()

if __name__ == '__main__':
    main()
