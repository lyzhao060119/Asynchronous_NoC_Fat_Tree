#!/usr/bin/env python3
"""Eight-point frozen-netlist network power pipeline. No DC, no case upload."""
from __future__ import annotations
import argparse,csv,hashlib,json,os,re,shlex,subprocess
from datetime import datetime,timezone
from pathlib import Path
from run_remote_cmr_fat_tree_noc16_sdf import connect,job_id

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
SPEC=REPO/'DATE paper/experiments/configs/power_round2_static4_minimal.json'
ROOT='/home/ghy19/Asynchronous_Router_CMR'
DATA='/prjtemp/ghy19/paper64_network_power'
LOCAL=REPO/'DATE paper/experiments/raw/paper64'

def read_spec():
 s=json.loads(SPEC.read_text(encoding='utf-8'))
 s['points']=[dict(p,load=s['selectors'][p['load']] if isinstance(p['load'],str) else p['load']) for p in s['points']]
 if len(s['points'])!=8 or any(p['design'].startswith('SYNC') for p in s['points']):raise RuntimeError('spec requires eight non-Sync points')
 if len({(p['design'],p['suite'],p.get('scheme'),p['load'],p['window']) for p in s['points']})!=8:raise RuntimeError('duplicate power point')
 return s

def case(p):
 if p['suite']=='multicast':
  scheme='PROP_temp64' if p['scheme']=='native' else 'source_repeated_unicast'
  name=f'MC-REGION-F16_n64_s202701_m5_{scheme}_top16'
  base=f'{ROOT}/sim/prop_temp64_20260914_prop_temp64_mc_f16_main/cases'
 elif p['design'] in ('PROP_temp64','PROP_temp64_static4'):
  name=f"TOPO-UR_n64_s202701_m{p['load']}_PROP_temp64_top16"
  base=f'{ROOT}/sim/prop_temp64_20260913_prop_temp64_asap_uc_m5_500/cases'
 else:
  suffix='PFAT64_top8' if p['design']=='PFAT64' else 'FM64_top0'
  name=f"TOPO-UR_n64_s202701_m{p['load']}_{suffix}"
  base=f'{ROOT}/sim/cases_noc64'
 return name,base+'/'+name+'.case'

def inputs():
 return {
 'run_gls_cmr_noc64_power_activity.sh':HERE/'run_gls_cmr_noc64_power_activity.sh',
 'run_ptpx_cmr_mesh_power.tcl':REPO/'scripts/asic_dc/power/run_ptpx_cmr_mesh_power.tcl',
 'tb_noc64_async_boundary.sv':REPO/'sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv',
 'tb_cmr_noc64_async_boundary_failfast.sv':HERE/'tb_cmr_noc64_async_boundary_failfast.sv',
 'tb_prop_temp64_lane_monitor.sv':HERE/'tb_prop_temp64_lane_monitor.sv',
 'async_prop_temp64_port_adapter.sv':REPO/'sim/AsyncNoC/async_prop_temp64_port_adapter.sv',
 'async_noc64_mesh_port_adapter.sv':REPO/'sim/AsyncNoC/async_noc64_mesh_port_adapter.sv',
 'async_noc64_port_adapter.sv':REPO/'sim/AsyncNoC/async_noc64_port_adapter.sv'}

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()

def cmd(client,command):
 _,out,err=client.exec_command(command)
 data=out.read().decode(errors='replace');error=err.read().decode(errors='replace')
 rc=out.channel.recv_exit_status()
 if rc:raise RuntimeError(f'remote RC={rc}: {command}\n{error[-800:]} {data[-800:]}')
 return data

def positive(sftp,path):
 try:size=sftp.stat(path).st_size
 except IOError:raise RuntimeError('missing frozen input '+path)
 if size<=0:raise RuntimeError('empty frozen input '+path)
 return size

def hashes(client,paths):
 result=cmd(client,'sha256sum '+' '.join(map(shlex.quote,paths)))
 found={path:h for h,path in re.findall(r'(?m)^([0-9a-f]{64})\s+(\S+)$',result)}
 if set(found)!=set(paths):raise RuntimeError('remote SHA incomplete')
 return found

def put(sftp,local,destination):
 data=local.read_bytes();tmp=destination+'.uploading'
 with sftp.file(tmp,'wb') as f:f.write(data)
 sftp.posix_rename(tmp,destination)
 return hashlib.sha256(data).hexdigest()

def save(archive,m):(archive/'manifest.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
def load(archive):return json.loads((archive/'manifest.json').read_text(encoding='utf-8'))

def preflight(archive,run_id):
 if archive.exists():raise RuntimeError('refusing overwrite '+str(archive))
 s=read_spec();os.environ.setdefault('C1_HOST','192.168.2.8')
 client=connect(attempts=2);sftp=client.open_sftp()
 try:
  designs={}
  for design,info in s['designs'].items():
   if design.startswith('SYNC'):continue
   base=f"{ROOT}/outputs/{info['netlist_run_id']}"
   files={key:base+'/'+info[key] for key in ('ddc','sdc','post','sdf')}
   sizes={key:positive(sftp,path) for key,path in files.items()}
   digs=hashes(client,list(files.values()))
   marker=None;dc_log=None
   for log in (f"{ROOT}/logs/dc/{info['netlist_run_id']}.retry.log",f"{ROOT}/logs/dc/{info['netlist_run_id']}.log"):
    try:
     with sftp.file(log,'rb') as f:text=f.read().decode(errors='replace')
     found=re.search(r'(?m)^([A-Z0-9_]*DC_PASS)\b',text)
     if found:marker=found.group(1);dc_log=log;break
    except IOError:pass
   if not marker:raise RuntimeError('DC PASS marker missing '+design)
   designs[design]={'netlist_run_id':info['netlist_run_id'],'files':files,'sizes':sizes,'sha256':digs,'dc_log':dc_log,'dc_pass_marker':marker,'caveat':info.get('caveat','')}
  points=[]
  for p in s['points']:
   name,path=case(p);size=positive(sftp,path)
   points.append({**p,'case_name':name,'case_path':path,'case_bytes':size})
  digs=hashes(client,[p['case_path'] for p in points])
  for p in points:p['case_sha256']=digs[p['case_path']]
  by_id={p['id']:p for p in points}
  for a,b in (('prop_m100','static_m100'),('dynamic_common_high','static_common_high')):
   if by_id[a]['case_sha256']!=by_id[b]['case_sha256']:raise RuntimeError('Dynamic/Static trace mismatch '+a)
  accepted=list(csv.DictReader((LOCAL/'compact64_20260915_112900/multicast_acceptance.csv').open(newline='',encoding='utf-8')))
  f16=[r for r in accepted if r['fanout']=='16' and r['load']=='5' and r['source_run_id']=='20260914_prop_temp64_mc_f16_main']
  if len(f16)!=2 or len({r['trace_sha256'] for r in f16})!=1 or any(r['acceptance']!='PASS' or r['completed_count']!='400' or r['backlog']!='0' for r in f16):raise RuntimeError('F16 original trace acceptance failed')
  for name,path in inputs().items():
   if not path.is_file() or path.stat().st_size<=0:raise RuntimeError('missing local power input '+name)
  archive.mkdir(parents=True,exist_ok=False)
  m={'run_id':run_id,'created_utc':datetime.now(timezone.utc).isoformat(),
   'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
   'git_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=REPO)),
   'spec_path':str(SPEC),'spec_sha256':sha(SPEC),'designs':designs,'points':points,
   'multicast_original_trace_sha256':f16[0]['trace_sha256'],'stages':{'preflight':'PASS'}}
  save(archive,m);print('CORE64_POWER_PREFLIGHT_PASS',run_id,'points=8',flush=True)
 finally:sftp.close();client.close()

def submit_activity(archive,ids,retry=False):
 m=load(archive)
 if m['stages'].get('preflight')!='PASS':raise RuntimeError('preflight gate failed')
 os.environ.setdefault('C1_HOST','192.168.2.8');client=connect(attempts=2);sftp=client.open_sftp()
 try:
  base=f"{DATA}/{m['run_id']}"
  input_dir=base+('/inputs_v3' if retry else ('/inputs_v2' if m.get('activity_jobs') else '/inputs'))
  cmd(client,'mkdir -p '+shlex.quote(input_dir))
  key='input_sha256_v3' if retry else ('input_sha256_v2' if m.get('activity_jobs') else 'input_sha256')
  m[key]={name:put(sftp,path,input_dir+'/'+name) for name,path in inputs().items()};save(archive,m)
  submitted={j['id'] for j in m.get('activity_jobs',[]) if not j.get('excluded')}
  for p in m['points']:
   if ids and p['id'] not in ids:continue
   if p['id'] in submitted:
    if not retry:raise RuntimeError('already submitted '+p['id'])
    prior=[j for j in m['activity_jobs'] if j['id']==p['id'] and not j.get('excluded')]
    if len(prior)!=1:raise RuntimeError('retry requires exactly one failed active attempt '+p['id'])
    with sftp.file(prior[0]['remote_log']+'/lsf.err','rb') as f:diagnostic=f.read().decode(errors='replace')
    if 'monitor_top[@]: unbound variable' not in diagnostic:raise RuntimeError('retry is restricted to confirmed wrapper precompile fault '+p['id'])
    prior[0]['excluded']='wrapper_precompile_unbound_array'
    save(archive,m);submitted.remove(p['id'])
   tag=p['id']+('_retry1' if retry else '')
   log=f'{base}/logs/paper64_power/{m["run_id"]}/{tag}'
   cmd(client,'mkdir -p '+shlex.quote(log))
   env={'CMR_REMOTE_ROOT':ROOT,'CMR_POWER_DATA_ROOT':base,'CMR_POWER_RUN_ID':m['run_id'],
    'CMR_POWER_NETLIST_RUN_ID':m['designs'][p['design']]['netlist_run_id'],'CMR_POWER_DESIGN':p['design'],
    'CMR_POWER_CASE_NAME':p['case_name'],'CMR_POWER_CASE_FILE':p['case_path'],
    'CMR_POWER_LOAD_MFLIT':str(p['load']),'CMR_POWER_TAG':tag,'CMR_POWER_INPUT_ROOT':input_dir,
    'CMR_POWER_VCD_MODE':'full_drain' if p['suite']=='multicast' else 'measurement',
    'CMR_POWER_LANE_MONITOR':'1' if p.get('lane_monitor') else '0'}
   wrapper=log+'/activity.sh'
   body='#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n'+'\n'.join('export '+k+'='+shlex.quote(v) for k,v in env.items())+'\nexec bash '+shlex.quote(input_dir+'/run_gls_cmr_noc64_power_activity.sh')+'\n'
   with sftp.file(wrapper,'wb') as f:f.write(body.encode())
   cmd(client,'chmod +x '+shlex.quote(wrapper))
   bsub=f'bsub -n 8 -m "node21 node26 node24 node18" -oo {shlex.quote(log+"/lsf.log")} -eo {shlex.quote(log+"/lsf.err")} -J {shlex.quote("p64act_"+tag)} {shlex.quote(wrapper)}'
   jid=job_id(cmd(client,bsub))
   m.setdefault('activity_jobs',[]).append({'id':p['id'],'tag':tag,'job_id':jid,'remote_log':log,'case_sha256':p['case_sha256'],'input_dir':input_dir,'input_hash_set':key})
   m['stages']['activity']='SUBMITTED';save(archive,m)
   print('CORE64_ACTIVITY_SUBMITTED',tag,jid,flush=True)
 finally:sftp.close();client.close()

def status(archive):
 m=load(archive);os.environ.setdefault('C1_HOST','192.168.2.8')
 client=connect(attempts=2);sftp=client.open_sftp()
 try:
  for job in m.get('activity_jobs',[]):
   if job.get('excluded'):continue
   jid=job['job_id']
   try:response=cmd(client,'bjobs -a -noheader -o "jobid stat queue exec_host" '+shlex.quote(str(jid)))
   except RuntimeError as exc:response=str(exc)[-200:]
   try:
    with sftp.file(job['remote_log']+'/lsf.log','rb') as f:
     f.seek(max(0,sftp.stat(job['remote_log']+'/lsf.log').st_size-1000));tail=f.read().decode(errors='replace')
   except IOError:tail=''
   marker='CMR_POWER_ACTIVITY_PASS' if 'CMR_POWER_ACTIVITY_PASS' in tail else ('CMR_POWER_ACTIVITY_FAIL' if 'CMR_POWER_ACTIVITY_FAIL' in tail else 'NO_STAGE_MARKER')
   sizes={name:(sftp.stat(job['remote_log']+'/'+name).st_size if name in sftp.listdir(job['remote_log']) else 0) for name in ('compile.log','run.log','sdf_annotate.log','measurement.vcd')}
   print('CORE64_ACTIVITY_STATUS',job['id'],jid,response.strip(),marker,sizes,flush=True)
   if 'EXIT' in response and marker=='NO_STAGE_MARKER':
    for name in ('lsf.log','lsf.err'):
     try:
      with sftp.file(job['remote_log']+'/'+name,'rb') as f:
       f.seek(max(0,sftp.stat(job['remote_log']+'/'+name).st_size-1200));tail=f.read().decode(errors='replace')
      print('CORE64_ACTIVITY_EXIT_DIAGNOSTIC',job['id'],name,tail[-900:],flush=True)
     except IOError:pass
   if sizes['compile.log'] and not sizes['run.log']:
    with sftp.file(job['remote_log']+'/compile.log','rb') as f:
     f.seek(max(0,sizes['compile.log']-1200));compile_tail=f.read().decode(errors='replace')
    if re.search(r'(?i)(error-|syntax error|unresolved|compilation failed)',compile_tail):
     print('CORE64_COMPILE_DIAGNOSTIC',job['id'],compile_tail[-800:],flush=True)
  for job in m.get('ptpx_jobs',[]):
   try:response=cmd(client,'bjobs -a -noheader -o "jobid stat queue exec_host" '+shlex.quote(str(job['job_id'])))
   except RuntimeError as exc:response=str(exc)[-200:]
   try:
    names=sftp.listdir(job['remote_report'])
    sizes={name:sftp.stat(job['remote_report']+'/'+name).st_size for name in names if name.endswith('.rpt')}
   except IOError:sizes={}
   print('CORE64_PTPX_STATUS',job['id'],job['job_id'],response.strip(),sizes,flush=True)
   if sizes.get('check_power.rpt',0):
    with sftp.file(job['remote_report']+'/check_power.rpt','rb') as f:
     check_preview=f.read().decode(errors='replace')[-650:]
    print('CORE64_CHECK_POWER_PREVIEW',job['id'],check_preview,flush=True)
   try:
    with sftp.file(job['remote_log']+'/lsf.log','rb') as f:
     size=sftp.stat(job['remote_log']+'/lsf.log').st_size
     f.seek(max(0,size-900));tail=f.read().decode(errors='replace')
    print('CORE64_PTPX_STAGE',job['id'],'PT063_PRESENT' if 'PT-063' in tail else 'PT063_ABSENT',
          'CMR_POWER_PASS' if 'CMR_POWER_PASS' in tail else 'PT_IN_PROGRESS',flush=True)
   except IOError:pass
 finally:sftp.close();client.close()

def collect_activity(archive,ids):
 m=load(archive);os.environ.setdefault('C1_HOST','192.168.2.8')
 client=connect(attempts=2);sftp=client.open_sftp()
 try:
  by_id={p['id']:p for p in m['points']}
  accepted={r['id'] for r in m.get('accepted_activity',[])}
  for job in m.get('activity_jobs',[]):
   if job.get('excluded'):continue
   tag=job['id']
   if ids and tag not in ids:continue
   if tag in accepted:continue
   log=job['remote_log'];lsf=log+'/lsf.log'
   try:
    with sftp.file(lsf,'rb') as f:lsf_text=f.read().decode(errors='replace')
   except IOError:
    print('CORE64_ACTIVITY_WAIT',tag,'no_lsf_log',flush=True);continue
   if 'CMR_POWER_ACTIVITY_PASS' not in lsf_text:
    if 'CMR_POWER_ACTIVITY_FAIL' in lsf_text or 'Exited with exit code' in lsf_text:
     raise RuntimeError('activity GLS failed '+tag+'\n'+lsf_text[-2000:])
    print('CORE64_ACTIVITY_WAIT',tag,'no_pass_marker',flush=True);continue
   p=by_id[tag]
   files=('compile.log','run.log','sdf_annotate.log','result.csv','events.csv','latency.csv',
          'flit_latency.csv','input_hashes.sha256')
   local=archive/'activity'/tag;local.mkdir(parents=True,exist_ok=False)
   sizes={}
   for name in files:
    remote_path=log+'/'+name
    sizes[name]=positive(sftp,remote_path)
    sftp.get(remote_path,str(local/name))
    if (local/name).stat().st_size!=sizes[name]:raise RuntimeError('activity download size mismatch '+tag+'/'+name)
   if p.get('lane_monitor'):
    name='lane_counts.csv';sizes[name]=positive(sftp,log+'/'+name)
    sftp.get(log+'/'+name,str(local/name))
   run=(local/'run.log').read_text(errors='replace')
   sdf=(local/'sdf_annotate.log').read_text(errors='replace')
   if 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' not in run and p['suite']=='ur':
    raise RuntimeError('full-drain 55k gate failed '+tag)
   if any(token in run for token in ('TB_RESULT FAIL','TB_HARD_TIMEOUT','TB_X_FAIL','Fatal:')):
    raise RuntimeError('activity TB fail '+tag)
   if not re.search(r'Total errors:\s*0',sdf):raise RuntimeError('activity SDF annotation failed '+tag)
   input_text=(local/'input_hashes.sha256').read_text(errors='replace')
   if p['case_sha256'] not in input_text:raise RuntimeError('activity canonical case SHA mismatch '+tag)
   report=list(csv.DictReader((local/'result.csv').open(newline='',encoding='utf-8')))
   if len(report)!=1 or report[0].get('pass_fail')!='PASS':raise RuntimeError('invalid activity result CSV '+tag)
   r=report[0]
   start=int(r['measurement_start_ps']);end=int(r['measurement_end_ps'])
   if end<=start:raise RuntimeError('invalid activity measurement window '+tag)
   if p['suite']=='ur' and (int(r['injected_flits'])!=55000 or int(r['delivered_flits'])!=55000 or
      int(r['measurement_delivered_flits'])<=0):raise RuntimeError('UR activity denominator gate '+tag)
   if p['suite']=='multicast':
    if 'TB_RESULT PASS' not in run:raise RuntimeError('F16 full-drain TB gate '+tag)
    pt_window(p,{'local_log':str(local)})
   vcd=log+'/measurement.vcd';vcd_size=positive(sftp,vcd)
   vcd_sha=hashes(client,[vcd])[vcd]
   if p.get('lane_monitor'):
    result=subprocess.run(['python',str(HERE/'summarize_prop_temp64_lane_counts.py'),str(local/'lane_counts.csv'),
                           str(local/'lane_summary.csv')],capture_output=True,text=True,check=True)
    if 'CMR_LANE_SUMMARY_PASS routers=32' not in result.stdout:raise RuntimeError('lane summary failed '+tag)
   entry={'id':tag,'remote_vcd':vcd,'vcd_bytes':vcd_size,'vcd_sha256':vcd_sha,'case_sha256':p['case_sha256'],
    'measurement_start_ps':start,'measurement_end_ps':end,'result':r,'local_log':str(local),
    'local_hashes':{name:sha(local/name) for name in sizes},'lane_monitor_pass':bool(p.get('lane_monitor'))}
   m.setdefault('accepted_activity',[]).append(entry);m['stages']['activity']='PARTIAL_PASS';save(archive,m)
   print('CORE64_ACTIVITY_ACCEPTED',tag,'vcd_bytes='+str(vcd_size),flush=True)
  if len(m.get('accepted_activity',[]))==8:
   m['stages']['activity']='PASS';save(archive,m);print('CORE64_ACTIVITY_ALL_PASS points=8',flush=True)
 finally:sftp.close();client.close()

def pt_window(p,activity):
 if p['suite']=='ur':
  start,end=activity['measurement_start_ps'],activity['measurement_end_ps']
  denom=int(activity['result']['measurement_delivered_flits'])
  if denom<=0:raise RuntimeError('zero UR denominator '+p['id'])
  return start,end,{'delivered_flits':denom}
 raw=Path(activity['local_log'])
 with (raw/'latency.csv').open(newline='',encoding='utf-8') as f:rows=list(csv.DictReader(f))
 cohort=[r for r in rows if 64<=int(r['original_event_id'])<464]
 originals={int(r['original_event_id']) for r in cohort}
 if originals!=set(range(64,464)):raise RuntimeError('F16 400/400 completion not proved '+p['id'])
 if len(cohort)!=6400:raise RuntimeError('F16 useful destination denominator !=6400 '+p['id'])
 start=min(int(r['head_offer_ps']) for r in cohort)
 end=max(int(r['tail_capture_ps']) for r in cohort)
 if end<=start:raise RuntimeError('invalid F16 first-arrival-to-last-tail window '+p['id'])
 return start,end,{'original_transactions':400,'useful_destination_deliveries':6400}

def submit_ptpx(archive,ids):
 m=load(archive);os.environ.setdefault('C1_HOST','192.168.2.8')
 accepted={r['id']:r for r in m.get('accepted_activity',[])}
 if not accepted:raise RuntimeError('no accepted activity')
 by_id={p['id']:p for p in m['points']}
 client=connect(attempts=2);sftp=client.open_sftp()
 try:
  base=f"{DATA}/{m['run_id']}"
  pt_dir=base+'/pt_inputs_'+datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
  cmd(client,'mkdir -p '+shlex.quote(pt_dir))
  pt_tcl=inputs()['run_ptpx_cmr_mesh_power.tcl']
  pt_sha=put(sftp,pt_tcl,pt_dir+'/run_ptpx_cmr_mesh_power.tcl')
  submitted={j['id'] for j in m.get('ptpx_jobs',[])}
  for tag,activity in accepted.items():
   if ids and tag not in ids:continue
   if tag in submitted:raise RuntimeError('PT already submitted '+tag)
   p=by_id[tag];design=m['designs'][p['design']]
   start,end,denominators=pt_window(p,activity)
   log=f'{base}/logs/ptpx/{m["run_id"]}/{tag}'
   report=f'{base}/reports/ptpx/{m["run_id"]}/{tag}'
   cmd(client,'mkdir -p '+shlex.quote(log)+' '+shlex.quote(report))
   info=json.loads(SPEC.read_text(encoding='utf-8'))['designs'][p['design']]
   env={'SYNOPSYS_LC_ROOT':'/soft/synopsys/lc/V-2023.12',
        'CMR_POWER_DDC':design['files']['ddc'],'CMR_POWER_SDC':design['files']['sdc'],
        'CMR_POWER_NETLIST':design['files']['post'],'CMR_POWER_SDF':design['files']['sdf'],
        'CMR_POWER_VCD':activity['remote_vcd'],'CMR_POWER_TOP':info['top'],
        'CMR_POWER_STRIP_PATH':info['strip_path'],'CMR_POWER_START_NS':f'{start/1000:.3f}',
        'CMR_POWER_END_NS':f'{end/1000:.3f}','CMR_POWER_REPORT_DIR':report}
   wrapper=log+'/ptpx.sh'
   body='#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n'+'\n'.join('export '+k+'='+shlex.quote(v) for k,v in env.items())+'\nexec /soft/synopsys/prime/V-2023.12/bin/pt_shell -f '+shlex.quote(pt_dir+'/run_ptpx_cmr_mesh_power.tcl')+'\n'
   with sftp.file(wrapper,'wb') as f:f.write(body.encode())
   cmd(client,'chmod +x '+shlex.quote(wrapper))
   bsub=f'bsub -n 4 -m "node21 node26 node24 node18" -oo {shlex.quote(log+"/lsf.log")} -eo {shlex.quote(log+"/lsf.err")} -J {shlex.quote("p64px_"+tag)} {shlex.quote(wrapper)}'
   jid=job_id(cmd(client,bsub))
   m.setdefault('ptpx_jobs',[]).append({'id':tag,'job_id':jid,'remote_log':log,'remote_report':report,
    'start_ps':start,'end_ps':end,'denominators':denominators,'pt_tcl_sha256':pt_sha,'pt_input_dir':pt_dir})
   m['stages']['ptpx']='SUBMITTED';save(archive,m)
   print('CORE64_PTPX_SUBMITTED',tag,jid,'window_ps='+str(start)+':'+str(end),flush=True)
 finally:sftp.close();client.close()

def parse_power_report(path):
 text=path.read_text(errors='replace')
 scales={'W':1.,'mW':1e-3,'uW':1e-6,'nW':1e-9,'pW':1e-12}
 def get(label):
  m=re.search(label+r'\s*=\s*([0-9.eE+-]+)\s*([munp]?W)',text,re.I)
  if m:return float(m.group(1))*scales[m.group(2)]
  # PrimeTime's table reports use the library's W unit but often omit the
  # suffix on the labelled summary lines.
  bare=re.search(label+r'\s*=\s*([0-9.eE+-]+)(?:\s|$)',text,re.I)
  return float(bare.group(1)) if bare else None
 total=get('Total\\s+Power');leak=get('Cell\\s+Leakage\\s+Power')
 dynamic=get('Total\\s+Dynamic\\s+Power')
 if total is None or leak is None or total<=0 or leak<0 or leak>total:raise RuntimeError('power total/leakage unit parse failed '+str(path))
 if dynamic is None:dynamic=total-leak
 if dynamic<0:raise RuntimeError('negative dynamic power')
 return dynamic,leak,total

def collect_ptpx(archive,ids):
 m=load(archive);os.environ.setdefault('C1_HOST','192.168.2.8')
 client=connect(attempts=2);sftp=client.open_sftp()
 try:
  accepted={r['id'] for r in m.get('accepted_ptpx',[])}
  activity={r['id']:r for r in m.get('accepted_activity',[])}
  for job in m.get('ptpx_jobs',[]):
   tag=job['id']
   if ids and tag not in ids:continue
   if tag in accepted:continue
   log=job['remote_log']+'/lsf.log'
   try:
    with sftp.file(log,'rb') as f:stage=f.read().decode(errors='replace')
   except IOError:
    print('CORE64_PTPX_WAIT',tag,'no_lsf_log',flush=True);continue
   if 'CMR_POWER_PASS' not in stage:
    if 'CMR_POWER_FAIL' in stage or 'Exited with exit code' in stage:
     raise RuntimeError('PT-PX failed '+tag+'\n'+stage[-2500:])
    print('CORE64_PTPX_WAIT',tag,'no_pass_marker',flush=True);continue
   if 'PT-063' in stage:raise RuntimeError('PT-063 in startup '+tag)
   if 'CMR_POWER_WINDOW' not in stage:raise RuntimeError('missing PT time window '+tag)
   report=job['remote_report'];names=('power.rpt','power_hierarchy.rpt','power_cells.rpt',
     'activity.rpt','check_power.rpt','input_hashes.sha256')
   local=archive/'ptpx'/tag;local.mkdir(parents=True,exist_ok=True)
   for name in names:
    size=positive(sftp,report+'/'+name)
    sftp.get(report+'/'+name,str(local/name))
    if (local/name).stat().st_size!=size:raise RuntimeError('PT report download mismatch '+tag+'/'+name)
   check=(local/'check_power.rpt').read_text(errors='replace')
   if re.search(r'(?i)\b(error|violation)\b',check) and not re.search(r'(?i)(?:0\s+errors?|errors?\s*:\s*0|0\s+violations?|violations?\s*:\s*0)',check):
    raise RuntimeError('check_power not clean '+tag)
   activity_text=(local/'activity.rpt').read_text(errors='replace')
   if re.search(r'(?i)(no\s+switching\s+activity|0\s+annotated)',activity_text):
    raise RuntimeError('zero switching activity '+tag)
   if len(re.findall(r'(?m)^\s*\S+\s+[0-9]',activity_text))==0 and len(activity_text)<100:
    raise RuntimeError('empty activity coverage '+tag)
   input_hash=(local/'input_hashes.sha256').read_text(errors='replace')
   if activity[tag]['vcd_sha256'] not in input_hash:raise RuntimeError('PT VCD SHA mismatch '+tag)
   design=next(p['design'] for p in m['points'] if p['id']==tag)
   frozen=m['designs'][design]
   if any(frozen['sha256'][path] not in input_hash for path in frozen['files'].values()):
    raise RuntimeError('PT frozen netlist hash mismatch '+tag)
   dynamic,leak,total=parse_power_report(local/'power.rpt')
   duration_ns=(job['end_ps']-job['start_ps'])/1000
   energy_j=total*duration_ns*1e-9
   dyn_j=dynamic*duration_ns*1e-9
   leak_j=leak*duration_ns*1e-9
   d=job['denominators']
   row={'id':tag,'design':design,'window_start_ps':job['start_ps'],'window_end_ps':job['end_ps'],
    'dynamic_power_w':dynamic,'leakage_power_w':leak,'total_power_w':total,
    'dynamic_energy_j':dyn_j,'leakage_energy_j':leak_j,'total_energy_j':energy_j,
    'delivered_flits':d.get('delivered_flits',''),'original_transactions':d.get('original_transactions',''),
    'useful_destination_deliveries':d.get('useful_destination_deliveries',''),
    'total_pj_per_delivered_flit':energy_j*1e12/d['delivered_flits'] if 'delivered_flits' in d else '',
    'total_pj_per_original_transaction':energy_j*1e12/d['original_transactions'] if 'original_transactions' in d else '',
    'total_pj_per_useful_destination_delivery':energy_j*1e12/d['useful_destination_deliveries'] if 'useful_destination_deliveries' in d else '',
    'netlist_run_id':frozen['netlist_run_id'],'vcd_sha256':activity[tag]['vcd_sha256'],
    'power_report_sha256':sha(local/'power.rpt'),'ptpx_job_id':job['job_id'],'pass':True,
    'physical_class':'post-synthesis time-based PT-PX estimate'}
   m.setdefault('accepted_ptpx',[]).append(row);m['stages']['ptpx']='PARTIAL_PASS';save(archive,m)
   print('CORE64_PTPX_ACCEPTED',tag,'total_w='+str(total),flush=True)
  if len(m.get('accepted_ptpx',[]))==8:
   m['stages']['ptpx']='PASS';save(archive,m);print('CORE64_PTPX_ALL_PASS points=8',flush=True)
 finally:sftp.close();client.close()

def finalize(archive):
 m=load(archive)
 accepted=m.get('accepted_ptpx',[])
 if len(accepted)!=8 or {r['id'] for r in accepted}!={p['id'] for p in m['points']}:
  raise RuntimeError('refusing final power table: accepted PT-PX points !=8')
 if m['stages'].get('activity')!='PASS' or m['stages'].get('ptpx')!='PASS':
  raise RuntimeError('power stage gate incomplete')
 order={p['id']:i for i,p in enumerate(m['points'])}
 rows=sorted(accepted,key=lambda r:order[r['id']])
 fields=list(rows[0])
 with (archive/'power_summary.csv').open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
 (archive/'power_acceptance.csv').write_bytes((archive/'power_summary.csv').read_bytes())
 (archive/'RESULTS.md').write_text(
  '# Paper64 network power\n\nEight non-Sync frozen-netlist activity and time-based PT-PX points passed. '
  'All values are post-synthesis estimates, not post-layout or measured silicon. '
  'PFAT M100 power uses the 20260915 frozen netlist; its historical performance baseline used a different archived netlist and is not treated as the same physical implementation.\n',
  encoding='utf-8')
 m['stages']['finalize']='PASS';m['finalized_utc']=datetime.now(timezone.utc).isoformat();save(archive,m)
 print('CORE64_POWER_FINALIZE_PASS',archive,flush=True)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('stage',choices=('preflight','submit-activity','retry-activity','status','collect-activity','submit-ptpx','collect-ptpx','finalize'))
 ap.add_argument('--run-id',required=True);ap.add_argument('--point',action='append')
 args=ap.parse_args();archive=LOCAL/('network_power_'+args.run_id)
 if args.stage=='preflight':preflight(archive,args.run_id)
 elif args.stage=='submit-activity':submit_activity(archive,set(args.point or []))
 elif args.stage=='retry-activity':submit_activity(archive,set(args.point or []),retry=True)
 elif args.stage=='status':status(archive)
 elif args.stage=='collect-activity':collect_activity(archive,set(args.point or []))
 elif args.stage=='submit-ptpx':submit_ptpx(archive,set(args.point or []))
 elif args.stage=='collect-ptpx':collect_ptpx(archive,set(args.point or []))
 elif args.stage=='finalize':finalize(archive)
 else:raise RuntimeError('stage awaits preceding activity gate: '+args.stage)
if __name__=='__main__':main()
