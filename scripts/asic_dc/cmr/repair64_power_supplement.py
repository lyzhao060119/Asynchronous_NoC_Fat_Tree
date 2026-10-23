"""Recover completed activity inputs and requeue PT with VCD-proven scopes.

Runs on the remote host. No DUT or waveform edits; old logs/reports retained.
"""
from pathlib import Path
import json, re, subprocess, hashlib, shutil, sys

R=Path('/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1')
PY='/soft/GNU/python3.12/bin/python3'
STRIP={'SYNC_M16':'tb_cmr_noc64_sync_boundary_failfast/core/noc/dut',
       'FM64':'tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_mesh.noc/dut',
       'PROP_M16':'tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_prop_temp_m16.noc/dut'}
TOP={'SYNC_M16':'SyncNoC_64nodes','FM64':'CMRMeshNoC','PROP_M16':'PROP_temp64_m16'}

def recover():
 m=json.loads((R/'manifest.json').read_text()); recovered=[]
 for i,j in enumerate(m['jobs']):
  a=Path(j['activity_dir']); v=R/'vcd'/j['tag']/'measurement.vcd'
  if not v.exists():continue
  run=(a/'run.log').read_text(errors='replace')
  assert re.search(r'TB_RESULT PASS injected=55000 delivered=[1-9][0-9]* missing=0 unexpected=0 timeout=0',run),j['tag']
  assert not re.search(r'TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation',run),j['tag']
  # Validate exact VCD path before requesting any analysis.
  stack=[]; found=False
  with v.open(errors='replace') as f:
   for line in f:
    w=line.split()
    if w[:1]==['$scope']:
     stack.append(w[2]);found |= '/'.join(stack)==STRIP[j['design']]
    elif w[:1]==['$upscope']:stack.pop()
    elif w[:1]==['$enddefinitions']:break
  assert found, j['tag']
  slot=i%2 if j['design']=='SYNC_M16' else 0
  sdf=R/'work'/j['design']/('sdf_slot%d.log'%slot)
  assert re.search(r'Total errors:\s*0\b',sdf.read_text(errors='replace'))
  if not (a/'sdf_annotate.log').exists():shutil.copy2(sdf,a/'sdf_annotate.log')
  if not (a/'measurement.vcd').exists():(a/'measurement.vcd').symlink_to(v)
  files=[Path(j['case']),R/'work'/j['design']/'simv',v]
  hashes=[]
  for p in files:
   h=hashlib.sha256()
   with p.open('rb') as f:
    for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
   hashes.append(h.hexdigest()+'  '+str(p))
  (a/'recovered_input_hashes.sha256').write_text('\n'.join(hashes)+'\n')
  (a/'recovery_activity.log').write_text('FORMAL64_POWER_ACTIVITY_PASS recovered=1 tag='+j['tag']+'\n')
  recovered.append(j['tag']);print('POWER_ACTIVITY_RECOVERED '+j['tag'],flush=True)
 (R/'activity_recovery_r2.json').write_text(json.dumps(recovered,indent=2))

def submit(name,slots,cmd,log,dep=None):
 args=['bsub','-q','normal','-n',str(slots),'-J',name,'-o',str(log),'-e',str(log)+'.err']
 if dep:args+=['-w',dep]
 out=subprocess.check_output(args+cmd,text=True);print(out.strip(),flush=True)
 return re.search(r'Job <(\d+)>',out).group(1)

def requeue():
 assert not (R/'repair_submission_r2.json').exists(),'already requeued'
 m=json.loads((R/'manifest.json').read_text());jobs=m['jobs']
 # Retain failed jobs and logs; cancel only this campaign's obsolete analysis jobs.
 for j in jobs:
  for key in ['ptpx_job','archive_job']:
   state=subprocess.run(['bjobs','-noheader','-o','stat',str(j[key])],capture_output=True,text=True).stdout.strip()
   if state in ['PEND','RUN']:
    subprocess.run(['bkill',str(j[key])],check=True)
 recovery=submit('p64recover_r2',1,[PY,str(R/'repair.py'),'recover'],R/'recovery_r2.log')
 prev=[None,None];updates=[]
 for i,j in enumerate(jobs):
  d=j['design'];tag=j['tag'];a=Path(j['activity_dir']);logs=R/'logs'/tag
  existing=(R/'vcd'/tag/'measurement.vcd').exists()
  if not existing:
   assert d=='SYNC_M16'
   dep='done(%s)'%(prev[i%2] or recovery)
   subprocess.run(['bmod','-w',dep,str(j['activity_job'])],check=True)
  dep='done(%s)'%(recovery if existing else j['activity_job'])
  top=TOP[d];net=Path('/home/ghy19/Asynchronous_Router_CMR/outputs')/j['netlist_run']
  report=R/'reports_r2'/tag;log=logs/'ptpx_r2.log'
  px=submit('p64px2_'+tag,4,[PY,str(R/'ptpx.py'),'--activity',str(a),'--report',str(report),'--tcl',str(R/'ptpx.tcl'),'--netlist-root',str(net),'--ddc-name',top+'.ddc','--netlist-name',top+'_post.v','--sdf-name',top+'.sdf','--top',top,'--strip-path',STRIP[d]],log,dep)
  gz=submit('p64gz2_'+tag,1,[PY,str(R/'archive.py'),'--activity',str(a),'--ptpx-log',str(log)],logs/'archive_r2.log','done(%s)'%px)
  if d=='SYNC_M16':prev[i%2]=gz
  updates.append(dict(tag=tag,activity_job=j['activity_job'],reused_activity=existing,ptpx_job=px,archive_job=gz,strip_path=STRIP[d],report_dir=str(report),ptpx_log=str(log)))
  (R/'repair_submission_r2.json').write_text(json.dumps(dict(recovery_job=recovery,jobs=updates),indent=2))
 print('POWER_REPAIR_QUEUED cases='+str(len(updates)),flush=True)

if __name__=='__main__':
 {'recover':recover,'requeue':requeue}[sys.argv[1]]()
