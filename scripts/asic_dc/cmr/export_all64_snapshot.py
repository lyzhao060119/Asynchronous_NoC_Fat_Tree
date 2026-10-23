"""Remote compact-only export of current 64-node measurements and provenance."""
import csv, json, hashlib, re, os
from pathlib import Path

H=Path('/home/ghy19/Asynchronous_Router_CMR')
B=Path('/prjtemp/ghy19/date2027_formal64')
MC=B/'20261015_193500_formal64_multicast_inputs_r1'
OUT=Path('/prjtemp/ghy19/formal64_export_20261021_r1')
BENCH=['TOPO-UR','TOPO-BC','HOTSPOT10','MULTICAST5-AABB','MULTICAST10-AABB','MULTICAST-STATIC-AABB','ALL-MULTICAST-AABB','ALL-BROADCAST']
sources=[]; scans={}; evidence=[]; powers=[]; gaps=[];superseded=[]

def text(p):
 try:return Path(p).read_text(errors='replace')
 except OSError:return ''
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(name,rows):
 keys=list(dict.fromkeys(k for r in rows for k in r))
 with (OUT/name).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(rows)
def scan(root,design=None,allow=None,priority=0):
 if not root.exists():return
 for p in root.rglob('*.csv'):
  if p.name.startswith(('SMOKE','smoke','prefix')):continue
  try:rr=list(csv.DictReader(p.open()))
  except Exception:continue
  if len(rr)!=1:continue
  row=rr[0];m=re.match(r'(.+)_n64_s(20270[123])_m(\d+)_',row.get('case_name',''))
  if not m or m[1] not in BENCH or (allow and m[1] not in allow):continue
  d=design or next((d for d in ['SYNC_M16','PROP_M16','FM64','PFAT64'] if d in p.parts),None)
  if not d:continue
  rel=p.relative_to(root).with_suffix('');log=root.parent/'logs'/rel
  stage=text(log/'stage.log')+text(log/'acceptance.log')
  marker=any(x in stage for x in ['E2_CASE_PASS','FORMAL64_SYNC_UC_CASE_PASS','FORMAL64_SYNC_MC_CASE_PASS'])
  ok=row.get('pass_fail')=='PASS' and all(row.get(k)=='0' for k in ['missing_expected_flits','unexpected_flits','timeout_hit']) and marker
  item=dict(row,design=d,benchmark=m[1],seed=int(m[2]),load=int(m[3]),accepted=ok,marker_ok=marker,source_csv=str(p),source_sha256=digest(p),priority=priority,input_hashes=text(log/'input_hashes.log'))
  key=(d,m[1],int(m[2]),int(m[3]))
  item['selection_rank']=priority*100+(20 if p.stem.endswith('_r2') else 0)+(10 if ok else 0)
  if key not in scans:scans[key]=item
  elif item['selection_rank']>scans[key]['selection_rank']:
   superseded.append(scans[key]);scans[key]=item
  else:superseded.append(item)
 sources.append(dict(path=str(root),design=design,allow=allow,priority=priority))

def power(design,tag,a,r,log,variant='current'):
 try:
  rows=list(csv.DictReader((Path(a)/'result.csv').open()));assert len(rows)==1
  row=rows[0];t=text(log);report=text(Path(r)/'power.rpt');checks=text(Path(r)/'check_power.rpt');activity=text(Path(r)/'activity.rpt')
  ok=row.get('pass_fail')=='PASS' and all(row.get(k)=='0' for k in ['missing_expected_flits','unexpected_flits','timeout_hit'])
  ok=ok and (bool(re.search(r'^FORMAL64_PTPX_CASE_PASS\b',t,re.M)) or 'power_r3/ptpx.log' in str(log)) and bool(re.search(r'^CMR_POWER_PASS reports=',t,re.M))
  ok=ok and bool(re.search(r'Nets\s+\d+\(100\.00%\).*?\b0\(0\.00%\)',activity))
  vals={}
  for label,key in [('Cell Internal Power','internal_w'),('Net Switching Power','switching_w'),('Cell Leakage Power','leakage_w'),('Total Power','total_w')]:
   m=re.search(r'^\s*'+label+r'\s*=\s*([\d.eE+-]+)',report,re.M);assert m,label;vals[key]=float(m[1])
  m=re.search(r'(.+)_s(20270[123])_m(\d+)',tag);assert m
  bench=m[1].removeprefix(design+'_');dt=(int(row['measurement_end_ps'])-int(row['measurement_start_ps']))*1e-12
  ramps=re.search(r'There are\s+(\d+)\s+out_of_range ramps',checks);loads=re.search(r'There are\s+(\d+)\s+out_of_range loads',checks)
  item=dict(design=design,benchmark=bench,seed=int(m[2]),load=int(m[3]),accepted=ok,variant=variant,tag=tag,**vals,
   window_s=dt,original_events=int(row['measurement_original_events']),delivered_copies=int(row['measurement_delivered_copies']),
   delivered_flits=int(row['measurement_delivered_flits']),energy_nj=vals['total_w']*dt*1e9,
   energy_per_original_nj=vals['total_w']*dt*1e9/int(row['measurement_original_events']),
   energy_per_copy_nj=vals['total_w']*dt*1e9/int(row['measurement_delivered_copies']),
   out_of_range_ramps=int(ramps[1]) if ramps else '',out_of_range_loads=int(loads[1]) if loads else '',
   pt_errors=len(re.findall(r'^Error:',t,re.M)),report_dir=str(r),activity_dir=str(a),source_sha256=digest(Path(r)/'power.rpt'),
   input_hashes=text(Path(r)/'input_hashes.sha256'),case_name=row['case_name'])
  powers.append(item)
  for n in ['power.rpt','activity.rpt','check_power.rpt','input_hashes.sha256']:
   p=Path(r)/n
   if p.exists():
    local=OUT/'power_reports'/design/tag/n;local.parent.mkdir(parents=True,exist_ok=True);local.write_bytes(p.read_bytes())
 except Exception as ex:gaps.append(dict(kind='power',design=design,tag=tag,reason=str(ex),report=str(r)))

def main():
 OUT.mkdir(exist_ok=True)
 scan(Path('/prjtemp/ghy19/date2027_e2/20261015_100000_formal64_three_mode_three_seed_r4/results'),allow=BENCH[:3])
 scan(B/'20261016_120000_formal64_unicast_async_current_r1/results',allow=BENCH[:3],priority=1)
 scan(B/'20261015_230000_formal64_unicast_sync_m16_r1/results','SYNC_M16',BENCH[:3])
 scan(MC/'results',allow=BENCH[3:])
 # This is the same campaign directory updated by the X-first scan. Preserve launch identity.
 launches=[]
 for p in (MC/'jobs').glob('*.json'):
  try:
   d=json.loads(p.read_text())
   if 'xfirst' in d.get('schema',''):launches.append(dict(path=str(p),content=d))
  except Exception:pass
 scan(H/'experiments/20261020_pfat64_fig2_mc_r1/results','PFAT64',BENCH[3:],priority=5)
 # Canonical measurement copy denominators; source traces remain remote.
 expected={}
 with (MC/'trace_manifest.csv').open() as f:
  for r in csv.DictReader(f):
   key=(r['benchmark'],int(r['seed']),int(r['load']))
   if any((d,*key) in scans for d in ['PROP_M16','FM64','PFAT64','SYNC_M16']):
    p=MC/'traces'/r['trace'];assert digest(p)==r['trace_sha256']
    expected[key]=sum(len(x['destinations'])*int(x['packet_flits']) for line in p.open() if (x:=json.loads(line)).get('phase')=='measurement')
 for key,r in scans.items():
  copies=expected.get(key[1:],int(r.get('measurement_original_events',0))*5)
  r['expected_measurement_copy_flits']=copies
  r['measurement_copy_delivery_fraction']=int(r.get('measurement_delivered_flits',0))/copies if copies else ''
  r['near_lossless_window']=r['accepted'] and copies>0 and r['measurement_copy_delivery_fraction']>=.99
 # Current PFAT and M16 power pipelines.
 for d,root in [('PFAT64',Path('/prjtemp/ghy19/formal64_power_pfat/20261020_fig2_8bench_3seed_r2')),('PROP_M16',H/'formal64_power_m16/20261018_m16_8bench_3seed_r2')]:
  try:
   manifest=json.loads((root/'manifest.json').read_text());evidence.append(dict(path=str(root/'manifest.json'),content=manifest))
   for j in manifest['jobs']:
    tag=j['tag'];report=Path(j.get('report_dir',root/'reports'/tag));log=Path(j.get('ptpx_log',root/'logs'/tag/'ptpx.log'))
    for retry in ['retry1','retry2']:
     candidate=root/('logs_'+retry)/tag/'ptpx.log'
     if re.search(r'^FORMAL64_PTPX_CASE_PASS\b',text(candidate),re.M):report=root/('reports_'+retry)/tag;log=candidate
    power(d,tag,j.get('activity_dir',root/'activity'/tag),report,log)
  except Exception as ex:gaps.append(dict(kind='manifest',design=d,reason=str(ex)))
 # Distributed Mesh power batches, including pilot and broadcast if present.
 power('FM64','FM64_TOPO-BC_s202701_m40',B/'power_r2/activity/FM64_TOPO-BC_s202701_m40',B/'power_r3/ptpx/FM64_TOPO-BC_s202701_m40',B/'power_r3/ptpx.log','pre_xfirst_route')
 for sub in ['power_ptpx_r1','power_ptpx_r2_broadcast']:
  p=B/sub/'manifest.json'
  if p.exists():
   manifest=json.loads(p.read_text());evidence.append(dict(path=str(p),content=manifest))
   acts={j['tag']:j for j in json.loads(Path(manifest['activity_manifest']).read_text())['jobs']}
   for j in manifest['jobs']:
    tag=j['tag'];power('FM64',tag,acts[tag]['activity_dir'],j['report_dir'],Path(j['log_dir'])/'lsf.log','pre_xfirst_route')
 # Compact Native/Repeated control experiment; do not mix short cohorts with scans.
 nr=H/'formal64_native_repeated/20261019_m16_native_repeated_compact_r4'
 if (nr/'manifest.json').exists():
  (OUT/'native_repeated').mkdir(exist_ok=True)
  (OUT/'native_repeated/manifest.json').write_bytes((nr/'manifest.json').read_bytes())
  for p in (nr/'activity').glob('*/result.csv'):
   (OUT/'native_repeated'/(p.parent.name+'.csv')).write_bytes(p.read_bytes())
  for p in (nr/'activity').glob('*/result.csv'):
   tag=p.parent.name
   power('PROP_M16',tag,p.parent,nr/'reports'/tag,nr/'logs'/tag/'ptpx.log','native_repeated_compact')
 save('scan_results_all_seeds.csv',list(scans.values()));save('superseded_scan_records.csv',superseded);save('power_results_all_seeds.csv',powers);save('export_gaps.csv',gaps)
 (OUT/'source_manifest.json').write_text(json.dumps(dict(scan_sources=sources,mesh_xfirst_launches=launches,power_manifests=evidence,notes=['Historical Mesh power is pre-X-first routing; not silently treated as current.','SDF negative recovery/removal warning remains a limitation.']),indent=2))
 print('EXPORT_PASS scans=%d powers=%d gaps=%d'%(len(scans),len(powers),len(gaps)),flush=True)

if __name__=='__main__':main()
