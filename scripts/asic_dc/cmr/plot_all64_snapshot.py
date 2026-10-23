"""Audit three-seed summaries and plot the compact 2026-10-21 snapshot."""
import argparse,csv,json,statistics,math,hashlib,re,zipfile
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from plot_formal64_async_curves import BENCHMARKS,DESIGNS,plot

def read(p):
 with p.open(newline='',encoding='utf-8') as f:return list(csv.DictReader(f))
def write(p,rows):
 keys=list(dict.fromkeys(k for r in rows for k in r))
 with p.open('w',newline='',encoding='utf-8') as f:
  w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(rows)
def yes(v):return str(v).lower()=='true'
def num(r,k):
 try:v=float(r[k]);return v if math.isfinite(v) else None
 except (ValueError,KeyError,TypeError):return None
def save(fig,out,name):
 fig.savefig(out/(name+'.png'),dpi=220,bbox_inches='tight')
 fig.savefig(out/(name+'.pdf'),bbox_inches='tight');plt.close(fig)
def bars(ax,rows,metric,err,ylabel):
 x=np.arange(8);w=.24
 for i,(d,(label,color,_)) in enumerate(DESIGNS.items()):
  values=[];errors=[]
  for b,_ in BENCHMARKS:
   r=next((r for r in rows if r['design']==d and r['benchmark']==b),{})
   values.append(float(r.get(metric,float('nan'))));errors.append(float(r.get(err,0)))
  ax.bar(x+(i-1)*w,values,w,color=color,label=label,yerr=errors,capsize=2,alpha=.9)
  for pos,v in zip(x+(i-1)*w,values):
   if not math.isfinite(v):ax.text(pos,.02,'n/a',transform=ax.get_xaxis_transform(),ha='center',va='bottom',rotation=90,fontsize=7,color=color)
 ax.set_xticks(x,['UR','BC','Hotspot10','MC5','MC10','MC-static','All-MC','Broadcast'],rotation=25,ha='right')
 ax.set_ylabel(ylabel);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,required=True);a=ap.parse_args();out=a.root
 records=read(out/'scan_results_all_seeds.csv');powers=read(out/'power_results_all_seeds.csv')
 provenance=[]
 for r in records:
  current=not(r['design']=='FM64' and r['benchmark'] not in ['TOPO-UR','TOPO-BC','HOTSPOT10'] and '20261017_190000_mesh64_xfirsty_dc_r3' not in r.get('input_hashes',''))
  r['pipeline_accepted']=r['accepted'];r['current_candidate']=str(current)
  if not current:r['accepted']='False';r['exclusion_reason']='HISTORICAL_MESH_NETLIST'
  provenance.append({k:r.get(k,'') for k in ['design','benchmark','seed','load','pipeline_accepted','current_candidate','accepted','exclusion_reason','source_csv']})
 write(out/'candidate_provenance_audit.csv',provenance)
 # Keep missing/rejected points explicit, including deliberately stopped broadcast points.
 indexed={(r['design'],r['benchmark'],int(r['seed']),int(r['load'])):r for r in records}
 missing=[]
 for d in ['PROP_M16','FM64','PFAT64','SYNC_M16']:
  for b,_ in BENCHMARKS:
   for seed in [202701,202702,202703]:
    for load in [5,10,20]+list(range(40,501,20))+[600,700,800]:
     r=indexed.get((d,b,seed,load))
     if r and yes(r['accepted']):continue
     status=r.get('exclusion_reason','REJECTED') if r else ('STOPPED_AFTER_SATURATION' if d=='PFAT64' and b=='ALL-BROADCAST' and load>40 else 'MISSING')
     missing.append(dict(design=d,benchmark=b,seed=seed,load=load,status=status,source_csv=r.get('source_csv','') if r else ''))
 write(out/'missing_or_rejected.csv',missing)
 groups={};coverage=[];means=[];maxima=[];issues=[]
 for r in records:
  key=(r['design'],r['benchmark'],int(r['load']))
  groups.setdefault(key,[]).append(r)
 metrics=['offer_to_tail_mean_ns','offered_mflit_port_s','delivered_mflit_port_s','flit_lat_mean_ns','measurement_backlog_flits','measurement_copy_delivery_fraction']
 for (d,b,l),rr in sorted(groups.items()):
  if len(rr)!=len({r['seed'] for r in rr}):raise ValueError('duplicate seeds '+str((d,b,l)))
  good=[r for r in rr if yes(r['accepted'])]
  if len(good)!=3 or {r['seed'] for r in good}!={'202701','202702','202703'}:continue
  row=dict(design=d,benchmark=b,load=l,n_seeds=3,latency_curve_eligible=str(all(yes(r['near_lossless_window']) for r in good)))
  for m in metrics:
   vv=[num(r,m) for r in good]
   if all(v is not None for v in vv):row[m+'_mean']=statistics.mean(vv);row[m+'_std']=statistics.stdev(vv)
  means.append(row)
 for d in ['PROP_M16','FM64','PFAT64','SYNC_M16']:
  for b,_ in BENCHMARKS:
   rr=[r for r in records if r['design']==d and r['benchmark']==b]
   coverage.append(dict(design=d,benchmark=b,found=len(rr),accepted=sum(yes(r['accepted']) for r in rr),planned_grid_points=90,
    stopped_after_saturation=(d=='PFAT64' and b=='ALL-BROADCAST'),missing_from_full_grid=90-len(rr)))
   mm=[r for r in means if r['design']==d and r['benchmark']==b and 'delivered_mflit_port_s_mean' in r]
   near=[r for r in mm if r['latency_curve_eligible']=='True']
   if mm:
    peak=max(mm,key=lambda r:r['delivered_mflit_port_s_mean']);safe=max(near,key=lambda r:r['load']) if near else None
    maxima.append(dict(design=d,benchmark=b,peak_copy_throughput=peak['delivered_mflit_port_s_mean'],peak_copy_std=peak['delivered_mflit_port_s_std'],peak_load=peak['load'],
     safe_copy_throughput=safe['delivered_mflit_port_s_mean'] if safe else float('nan'),safe_copy_std=safe['delivered_mflit_port_s_std'] if safe else 0,
     highest_near_lossless_load=safe['load'] if safe else '',n_three_seed_points=len(mm)))
 write(out/'formal64_seed_averages.csv',means);write(out/'coverage.csv',coverage);write(out/'throughput_summary.csv',maxima)
 # Frozen per-seed fields retained in original CSV; no averaging across different loads or variants.
 pmeans=[]
 for d in DESIGNS:
  for b,_ in BENCHMARKS:
   rr=[r for r in powers if r['design']==d and r['benchmark']==b and r['variant']!='native_repeated_compact' and yes(r['accepted'])]
   if len(rr)!=3 or len({r['seed'] for r in rr})!=3:
    issues.append(dict(kind='power_coverage',design=d,benchmark=b,accepted_seeds=len(rr)));continue
   if len({r['load'] for r in rr})!=1:raise ValueError('mixed power loads')
   r=dict(design=d,benchmark=b,load=int(rr[0]['load']),n_seeds=3,variant=rr[0]['variant'])
   for m in ['total_w','internal_w','switching_w','leakage_w','energy_nj','energy_per_original_nj','energy_per_copy_nj']:
    vals=[float(v[m]) for v in rr];r[m+'_mean']=statistics.mean(vals);r[m+'_std']=statistics.stdev(vals)
   r['power_mw']=r['total_w_mean']*1000;r['power_mw_std']=r['total_w_std']*1000
   pmeans.append(r)
 write(out/'power_seed_averages.csv',pmeans);write(out/'analysis_issues.csv',issues)
 plt.rcParams.update({'font.family':'DejaVu Sans','pdf.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
 plot(means,out,'latency');plot(means,out,'throughput')
 fig,axs=plt.subplots(2,1,figsize=(12,8),layout='constrained')
 bars(axs[0],maxima,'peak_copy_throughput','peak_copy_std','Peak copy throughput (Mflit/s/port)')
 bars(axs[1],maxima,'safe_copy_throughput','safe_copy_std','Copy throughput at highest near-lossless load')
 axs[0].legend(ncol=3,frameon=False);fig.suptitle('64-node asynchronous NoC: observed throughput summary')
 fig.supxlabel('Mean +/- sample SD, three seeds. Near-lossless: >=99% window delivery. Current Mesh broadcast: m5/m10 only; not a measured capacity.',fontsize=9)
 save(fig,out,'formal64_throughput_summary')
 fig,axs=plt.subplots(3,1,figsize=(12,11),layout='constrained')
 bars(axs[0],pmeans,'power_mw','power_mw_std','Total network power (mW)')
 bars(axs[1],pmeans,'energy_per_original_nj_mean','energy_per_original_nj_std','Window energy / offered original event (nJ)')
 bars(axs[2],pmeans,'energy_per_copy_nj_mean','energy_per_copy_nj_std','Window energy / delivered packet copy (nJ)')
 axs[0].legend(ncol=3,frameon=False);fig.suptitle('64-node reported power / energy estimates at matched loads')
 fig.supxlabel('Three-seed mean +/- sample SD. Mesh power: historical pre-X-first routing. Sync excluded. n/a: incomplete seeds.\nTT 0.8 V, 25 C; library-table extrapolation, PT-063 and SDF compatibility issues remain; not power signoff.',fontsize=9)
 save(fig,out,'formal64_power_energy')
 # Supplemental compact Native/Repeated test, never combined with 10k-event scans.
 nr=[]
 for p in (out/'native_repeated').glob('*.csv'):
  if p.name=='case_manifest.csv':continue
  rr=read(p)
  if len(rr)!=1 or 'offer_to_tail_mean_ns' not in rr[0]:continue
  r=rr[0];r['mode']='REPEATED' if 'REPEATED' in p.name else 'NATIVE'
  r['benchmark']='MULTICAST10-AABB' if 'MULTICAST10' in p.name else 'ALL-MULTICAST-AABB';nr.append(r)
 if nr:
  fig,axs=plt.subplots(2,3,figsize=(13,7),layout='constrained')
  nrsummary=[]
  for axes,(b,title) in zip(axs,[('MULTICAST10-AABB','Multicast10, m20'),('ALL-MULTICAST-AABB','All-multicast, m10')]):
   for col,(metric,label) in enumerate([('offer_to_tail_mean_ns','Offer-to-last-tail latency (ns)'),('delivered_mflit_port_s','Delivered copies (Mflit/s/port)'),('energy_per_original_nj','Energy / original event (nJ)')]):
    vals=[];sd=[]
    for mode in ['NATIVE','REPEATED']:
     if col<2:vv=[float(r[metric]) for r in nr if r['mode']==mode and r['benchmark']==b]
     else:vv=[float(r[metric]) for r in powers if r['variant']=='native_repeated_compact' and r['benchmark']==b and r['tag'].endswith('_'+mode) and yes(r['accepted'])]
     if len(vv)!=3:vals.append(float('nan'));sd.append(0);continue
     vals.append(statistics.mean(vv));sd.append(statistics.stdev(vv))
     nrsummary.append(dict(benchmark=b,mode=mode,metric=metric,mean=vals[-1],std=sd[-1],n_seeds=3))
    ax=axes[col];ax.bar(['Native','Repeated'],vals,yerr=sd,capsize=4,color=['#146C94','#9B667C']);ax.set_title(title);ax.set_ylabel(label);ax.grid(axis='y',alpha=.2)
  fig.suptitle('M16: matched Native versus Repeated control experiment')
  fig.supxlabel('Three seeds; 100 warm-up + 1,000 measured original transactions. Separate from full scans.\nEnergy: reported synthesis estimates, with PT/library model limitations retained.',fontsize=9)
  save(fig,out,'formal64_native_repeated')
  write(out/'native_repeated_seed_averages.csv',nrsummary)
 facts=dict(scan_rows=len(records),power_rows=len(powers),three_seed_scan_points=len(means),power_three_seed_groups=len(pmeans),sync_plotted=False,
  warnings=['Mesh power uses historical pre-X-first netlist.','PT-063 Library Compiler executable path error appears in inspected PT logs; not power signoff.','Out-of-range library-table ramps/loads retained in power CSV.','SDF negative recovery/removal compatibility warnings; not full timing signoff.','Missing/failed seeds are never averaged as zero.','Total window energy/event uses offered cohort, not necessarily completed cohort.'])
 (out/'plot_manifest.json').write_text(json.dumps(facts,indent=2),encoding='utf-8')
 files=[p for p in out.iterdir() if p.is_file() and (p.name.startswith('formal64_') or p.name in ['throughput_summary.csv','power_seed_averages.csv','native_repeated_seed_averages.csv','coverage.csv','missing_or_rejected.csv','plot_manifest.json'])]
 (out/'figure_hashes.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2),encoding='utf-8')
 with zipfile.ZipFile(out.parent/'formal64_all_20261021_r1.zip','w',zipfile.ZIP_DEFLATED) as z:
  for p in out.rglob('*'):
   if p.is_file() and not p.name.startswith('qa_'):z.write(p,p.relative_to(out))
 print(json.dumps(facts,indent=2))

if __name__=='__main__':main()
