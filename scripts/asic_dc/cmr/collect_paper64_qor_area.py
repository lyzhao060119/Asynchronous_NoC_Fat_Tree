#!/usr/bin/env python3
"""Hash-verified read-only collection of four frozen NoC DC QoR area reports."""
import csv,hashlib,json,os,re
from datetime import datetime,timezone
from pathlib import Path
from run_remote_cmr_fat_tree_noc16_sdf import connect

REPO=Path(__file__).resolve().parents[3]
ROOT='/home/ghy19/Asynchronous_Router_CMR'
PAPER=REPO/'DATE paper/experiments/raw/paper64'
SPEC=REPO/'DATE paper/experiments/configs/power_round2_static4_minimal.json'
DESIGNS=('PROP_temp64','PROP_temp64_static4','PFAT64','FM64')

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()

def main():
 s=json.loads(SPEC.read_text(encoding='utf-8'))
 out=PAPER/f'paper64_area_{datetime.now():%Y%m%d_%H%M%S}'
 staging=out.with_name(out.name+'.staging')
 staging.mkdir(parents=True,exist_ok=False)
 os.environ.setdefault('C1_HOST','192.168.2.8')
 client=connect(attempts=2);sftp=client.open_sftp()
 try:
  rows=[];record=[]
  for design in DESIGNS:
   run=s['designs'][design]['netlist_run_id']
   remote=f'{ROOT}/reports/dc/{run}/qor.rpt'
   size=sftp.stat(remote).st_size
   if size<=0:raise RuntimeError('empty QoR report '+remote)
   _,stdout,stderr=client.exec_command('sha256sum '+remote)
   result=stdout.read().decode(errors='replace')
   digest=re.search(r'^([0-9a-f]{64})',result)
   if not digest:raise RuntimeError('remote QoR SHA missing '+stderr.read().decode(errors='replace'))
   local=staging/(design+'.qor.rpt')
   sftp.get(remote,str(local))
   if local.stat().st_size!=size or sha(local)!=digest.group(1):raise RuntimeError('QoR download mismatch '+design)
   text=local.read_text(errors='replace')
   area=re.search(r'(?m)^\s*Design Area:\s*([0-9.]+)',text)
   if not area:raise RuntimeError('Design Area absent '+design)
   rows.append({'design':design,'netlist_run_id':run,'area_um2':float(area.group(1)),
                'qor_sha256':digest.group(1),'qor_bytes':size,'report_remote':remote})
   print('QOR_AREA_PASS',design,area.group(1),flush=True)
  with (staging/'summary.csv').open('w',newline='',encoding='utf-8') as f:
   w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
  (staging/'manifest.json').write_text(json.dumps({'created_utc':datetime.now(timezone.utc).isoformat(),
   'source':str(SPEC),'remote_preserved':True,'designs':rows},indent=2)+'\n',encoding='utf-8')
  staging.rename(out)
  print('QOR_AREA_COLLECT_PASS',out,flush=True)
 finally:sftp.close();client.close()
if __name__=='__main__':main()
