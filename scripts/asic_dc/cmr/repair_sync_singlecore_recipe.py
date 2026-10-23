"""Repair optional execution-report command; reuse existing VCDs."""
from pathlib import Path
import json,re,subprocess,shlex,sys
R=Path('/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1')
T=R/'singlecore_recipe_r4'
def state(job):
 p=subprocess.run(['bjobs','-noheader','-o','stat',str(job)],capture_output=True,text=True)
 return p.stdout.strip()
def cmd(args):
 s=subprocess.check_output(args,text=True);print(s.strip(),flush=True);return s
def prepare():
 assert not (T/'check2_job.json').exists()
 (T/'check2.tcl').write_text('source '+str(T/'core_limits.tcl')+'\nputs "PT_CORE_RECIPE_CHECK_PASS"\nexit 0\n')
 # Guard on an exact output marker, not merely scheduler DONE.
 wrapper='set ch [open '+str(T/'check2.log')+' r]\nset validation [read $ch]\nclose $ch\nif {![regexp -line {^PT_CORE_RECIPE_CHECK_PASS$} $validation]} {puts "CMR_POWER_FAIL core_recipe_not_validated"; exit 2}\n'
 wrapper+='source '+str(T/'core_limits.tcl')+'\nputs "CMR_POWER_EXECUTION max_cores=1 overthreading=false"\nsource '+str(T/'base_ptpx.tcl')+'\n'
 (T/'ptpx.tcl').write_text(wrapper)
 out=cmd(['bsub','-q','normal','-n','1','-J','syncCoreCheck2','-o',str(T/'check2.log'),'-e',str(T/'check2.err'),'/soft/synopsys/prime/V-2023.12/bin/pt_shell','-f',str(T/'check2.tcl')])
 (T/'check2_job.json').write_text(json.dumps({'job':re.search(r'Job <(\d+)>',out).group(1)}))
def resume():
 log=(T/'check2.log').read_text(errors='replace')
 assert re.search(r'^PT_CORE_RECIPE_CHECK_PASS\s*$',log,re.M),'exact validation marker missing'
 assert 'to 1. (CMCR-103)' in log,'tool core-limit confirmation missing'
 assert not re.search(r'Error:.*\((?:CMD|CMCR)-',log),'configuration command error'
 check=json.loads((T/'check2_job.json').read_text())['job']
 changes=json.loads((T/'adjustments.json').read_text());m=json.loads((R/'repair_submission_r2.json').read_text());updates=[]
 for item in changes['updated']:
  j=next(j for j in m['jobs'] if j['tag']==item['tag']);st=state(j['ptpx_job'])
  if st in ['PEND','PSUSP','USUSP']:
   cmd(['bmod','-w','done(%s) && done(%s)'%(j['activity_job'],check),str(j['ptpx_job'])])
   if st in ['PSUSP','USUSP']:cmd(['bresume',str(j['ptpx_job'])])
   updates.append({'tag':j['tag'],'action':'resumed','job':j['ptpx_job']})
  elif st=='EXIT':
   # The failed startup did not run update_power; retain its log and use r4 outputs.
   old=j['ptpx_job'];newreport=R/'reports_r4'/j['tag'];newlog=R/'logs'/j['tag']/'ptpx_r4.log'
   args=list(item['command']);args[args.index('--report')+1]=str(newreport)
   out=cmd(['bsub','-q','normal','-n','1','-J','syncPxRetry_'+j['tag'],'-w','done(%s)'%check,'-o',str(newlog),'-e',str(newlog)+'.err']+args)
   new=re.search(r'Job <(\d+)>',out).group(1)
   archive=['/soft/GNU/python3.12/bin/python3',str(R/'archive.py'),'--activity',str(R/'activity'/j['tag']),'--ptpx-log',str(newlog)]
   cmd(['bmod','-w','done(%s)'%new,'-Z',shlex.join(archive),str(j['archive_job'])])
   j.update(ptpx_job=new,ptpx_job_original_r4=old,ptpx_log=str(newlog),report_dir=str(newreport))
   updates.append({'tag':j['tag'],'action':'retry_existing_waveform','old_job':old,'job':new})
  else:updates.append({'tag':j['tag'],'action':'untouched','state':st})
 (R/'repair_submission_r2.json').write_text(json.dumps(m,indent=2))
 (T/'recovery2.json').write_text(json.dumps({'check_job':check,'updates':updates},indent=2))
 print('SYNC_SINGLECORE_RECOVERY_DONE',len(updates),flush=True)
if __name__=='__main__':{'prepare':prepare,'resume':resume}[sys.argv[1]]()
