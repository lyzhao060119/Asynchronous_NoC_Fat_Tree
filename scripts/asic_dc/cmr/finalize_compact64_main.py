#!/usr/bin/env python3
"""Publish the final paper-facing 64-node evidence view from accepted sources."""
import csv,hashlib,json,shutil,subprocess
from datetime import datetime,timezone
from pathlib import Path

REPO=Path(__file__).resolve().parents[3]
RAW=REPO/'DATE paper/experiments/raw/paper64'
FIG=REPO/'DATE paper/experiments/figures/paper64'

def newest(prefix):return sorted(p for p in RAW.glob(prefix+'_*') if p.is_dir() and not p.name.endswith('.staging'))[-1]
def read(path):return list(csv.DictReader(path.open(newline='',encoding='utf-8')))
def write(path,rows,fields=None):
 if not rows:raise RuntimeError('empty table '+path.name)
 with path.open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=fields or list(rows[0]));w.writeheader();w.writerows(rows)
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()

def main():
 cohort=newest('cohort64');static=newest('static64_cohort');area=newest('paper64_area')
 power=newest('network_power');sync_ur=newest('sync64_ur');sync_power=newest('sync64_power')
 pm=json.loads((power/'manifest.json').read_text(encoding='utf-8'))
 spm=json.loads((sync_power/'manifest.json').read_text(encoding='utf-8'))
 if pm['stages'].get('finalize')!='PASS':raise RuntimeError('network power not finalized')
 if spm['stages'].get('finalize')!='PASS':raise RuntimeError('Sync network power not finalized')
 pwr=read(power/'power_acceptance.csv')
 if len(pwr)!=8 or any(r['pass']!='True' for r in pwr):raise RuntimeError('power acceptance !=8')
 sync_pwr=read(sync_power/'power_acceptance.csv')
 if len(sync_pwr)!=2 or any(r['pass']!='True' for r in sync_pwr):raise RuntimeError('Sync power acceptance !=2')
 stamp=datetime.now().strftime('%Y%m%d_%H%M%S')
 out=RAW/('compact64_'+stamp);out.mkdir(parents=True,exist_ok=False)
 ur=read(cohort/'ur_acceptance.csv');st=read(static/'acceptance.csv');areas={r['design']:r for r in read(area/'summary.csv')}
 powers={r['id']:r for r in pwr}
 designs=[('PROP_temp64','Full PROP','prop_m100'),('PROP_temp64_static4','Static4','static_m100'),
          ('PFAT64','PFAT64','pfat_m100'),('FM64','FlatMesh64','flatmesh_m100')]
 table=[]
 for design,label,pid in designs:
  if design=='PROP_temp64_static4':
   perf=[r for r in st if r['claim_role']=='paper_point' and r['censored']=='False']
   high=max(perf,key=lambda r:int(r['load']))
   throughput=high['delivered_mflit_per_port_s']
   p95=high['cohort_p95_ns']
  else:
   perf=[r for r in ur if r['design']==design and r['paper_latency_eligible']=='True']
   high=max(perf,key=lambda r:int(r['load_setpoint_mflit_per_port_s']))
   throughput=high['delivered_mflit_per_port_s'];p95=high['cohort_p95_ns']
  table.append({'design':label,
   'performance_netlist_run_id':high.get('netlist_run_id',''),
   'area_power_netlist_run_id':areas[design]['netlist_run_id'],
   'area_um2':areas[design]['area_um2'],'near_lossless_high_load':high.get('load',high.get('load_setpoint_mflit_per_port_s')),
   'near_lossless_throughput_mflit_s_port':throughput,'full_drain_cohort_p95_ns':p95,
   'm100_energy_pj_per_delivered_flit':powers[pid]['total_pj_per_delivered_flit'],
   'power_netlist_run_id':powers[pid]['netlist_run_id'],
   'evidence_scope':'post-synthesis MAXIMUM-SDF + time-based PT-PX estimate',
   'caveat':'performance/power netlist differs; do not claim same physical implementation' if design=='PFAT64' else ''})
 write(out/'table64-i-network.csv',table)
 sync_perf=[r for r in read(sync_ur/'acceptance.csv') if r['paper_latency_eligible']=='True']
 if len(read(sync_ur/'summary.csv'))!=30 or not sync_perf:raise RuntimeError('Sync UR30 acceptance gate failed')
 sync_high=max(sync_perf,key=lambda r:int(r['load']))
 sync_m100={r['id']:r for r in sync_pwr}['sync_m100']
 qor=(sync_power/'dc_evidence/qor.rpt').read_text(errors='replace')
 area_match=__import__('re').search(r'Design Area:\s*([0-9.]+)',qor)
 if not area_match:raise RuntimeError('Sync area missing from frozen QoR')
 table.append({'design':'Sync B8','performance_netlist_run_id':'20260915_231600_sync_prop_temp64_b8_dc',
  'area_power_netlist_run_id':'20260915_231600_sync_prop_temp64_b8_dc','area_um2':area_match.group(1),
  'near_lossless_high_load':sync_high['load'],'near_lossless_throughput_mflit_s_port':sync_high['delivered_mflit_per_port_s'],
  'full_drain_cohort_p95_ns':sync_high['cohort_p95_ns'],'m100_energy_pj_per_delivered_flit':sync_m100['total_pj_per_delivered_flit'],
  'power_netlist_run_id':'20260915_231600_sync_prop_temp64_b8_dc',
  'evidence_scope':'post-synthesis MAXIMUM-SDF + time-based PT-PX estimate; pre-CTS clock activity','caveat':''})
 write(out/'table64-i-network.csv',table)
 lane=json.loads((RAW.parent/'hop_ppa/20260914_cmr_multi_lane_agg_r1/summary.json').read_text(encoding='utf-8'))
 router_ppa={r['design']:r for r in read(RAW/'compact64_20260915_112900/router_ppa_table.csv')}
 baseline=float(lane['c1p1_gflit_s'])
 router_table=[]
 for item in lane['rows']:
  if item['status']!='PASS' or not item['async']:continue
  lanes=int(item['parent_lanes']);throughput=float(item['throughput_gflit_s']);speedup=throughput/baseline
  ppa=router_ppa.get('async_fat_1x4',{}) if lanes==4 else {}
  router_table.append({'design':item['name'],'physical_parent_lanes':lanes,
   'aggregate_throughput_gflit_s':throughput,'speedup_vs_c1p1':speedup,
   'ideal_lane_scaling_efficiency_pct':100.0*speedup/lanes,
   'per_lane_throughput_gflit_s':throughput/lanes,
   'area_um2':ppa.get('area_um2',''),'stream_total_power_w':ppa.get('stream_total_power_w',''),
   'stream_pj_per_flit':ppa.get('stream_pj_per_flit',''),'idle_total_power_w':ppa.get('idle_total_power_w',''),
   'evidence_scope':'MAXIMUM-SDF aggregate; c1p4 PPA is post-synthesis PT-PX'})
 sync=router_ppa['sync_fat_1x4']
 router_table.append({'design':'sync_c1p4_implementation_reference','physical_parent_lanes':4,
  'aggregate_throughput_gflit_s':'','speedup_vs_c1p1':'','ideal_lane_scaling_efficiency_pct':'',
  'per_lane_throughput_gflit_s':'','area_um2':sync['area_um2'],
  'stream_total_power_w':sync['stream_total_power_w'],'stream_pj_per_flit':sync['stream_pj_per_flit'],
  'idle_total_power_w':sync['idle_total_power_w'],
  'evidence_scope':'post-synthesis PT-PX only; failed Sync aggregate excluded'})
 write(out/'table64-ii-router.csv',router_table)
 for src,name in ((cohort/'ur_acceptance.csv','ur_acceptance.csv'),(cohort/'bc_hotspot_acceptance.csv','bc_hotspot_acceptance.csv'),
  (static/'acceptance.csv','static_acceptance.csv'),(power/'power_acceptance.csv','network_power_acceptance.csv'),
  (sync_ur/'acceptance.csv','sync64_ur_acceptance.csv'),(sync_ur/'latency_trend.csv','sync64_latency_trend.csv'),
  (sync_power/'power_acceptance.csv','sync64_power_acceptance.csv'),(sync_power/'async_sync_power.csv','async_sync_power.csv'),
  (RAW/'compact64_20260915_112900/multicast_acceptance.csv','multicast_acceptance.csv'),
  (area/'summary.csv','area_acceptance.csv')):shutil.copy2(src,out/name)
 latest_fig=sorted(p for p in FIG.glob('final64_*_lane_scaling_*') if p.is_dir() and not p.name.endswith('_b'))[-1]
 latest_fig_b=Path(str(latest_fig)+'_b')
 figures=[]
 for src in (latest_fig/'fig64-a-architecture.pdf',latest_fig/'fig64-a-architecture.png',
             latest_fig_b/'fig64-b-mechanisms.pdf',latest_fig_b/'fig64-b-mechanisms.png'):
  dst=out/src.name;shutil.copy2(src,dst);figures.append({'file':dst.name,'sha256':sha(dst)})
 manifest={'created_utc':datetime.now(timezone.utc).isoformat(),
  'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
  'git_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=REPO)),
  'sources':{'cohort':str(cohort),'static':str(static),'area':str(area),'power':str(power),
   'sync_ur':str(sync_ur),'sync_power':str(sync_power),
   'router':'compact64_20260915_112900','figures':str(latest_fig)},
  'counts':{'ur':len(ur),'bc_hotspot':len(read(cohort/'bc_hotspot_acceptance.csv')),
   'static':len(st),'network_power':len(pwr)+len(sync_pwr),'sync_ur':30,'router_ptpx':8},
  'figures':figures,'excluded':['failed core64_power directories','dependency-invalid E2 PEND jobs',
   'Sync B8 bad CASE_TICK_NS job 12388301','six wrapper_precompile activity attempts']}
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 (out/'RESULTS.md').write_text(
  '# Final compact64 evidence view\n\n'
  '- UR: 90 throughput points; 44 pre-saturation full-drain 50,000-flit cohort latency points.\n'
  '- BC/Hotspot10: 120 full-drain cohorts recomputed offline.\n'
  '- Static4: frozen DC plus M5/M100/M420 paper points; real M420 lane counters support Static, not Dynamic, at this operating point.\n'
  '- Multicast and Router tables reuse previously accepted evidence.\n'
  '- Network power: eight established non-Sync plus two Sync post-synthesis time-based PT-PX estimates.\n'
  '- Sync B8: 30/30 MAXIMUM-SDF full-drain UR points; common Async/Sync near-lossless high is M420.\n',encoding='utf-8')
 print('COMPACT64_MAIN_PASS',out,flush=True)
if __name__=='__main__':main()
