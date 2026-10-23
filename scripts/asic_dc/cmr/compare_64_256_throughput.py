"""Common raw-counter throughput reduction; no synthetic simulation corrections."""
import csv,json,statistics,math,hashlib
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

OUT=Path('results/throughput64_256_common_metric_20261022_r1')
BENCHES=('TOPO-UR','MULTICAST10-AABB','ALL-MULTICAST-AABB')
LOADS=[5,10,20]+list(range(40,501,20))+[600,700,800]
def read(p):
 with p.open() as f:return list(csv.DictReader(f))
def write(p,rows):
 with p.open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def main():
 OUT.mkdir(exist_ok=True)
 sources=[(64,Path('results/formal64_all_20261021_r1/scan_results_all_seeds.csv')),
          (256,Path('results/metric_scope_audit_20261022/window_counts_256.csv'))]
 raw=[]
 for nodes,path in sources:
  for r in read(path):
   name={'PROP_M16':'M16','FM64':'Mesh','M16_256':'M16','Mesh256':'Mesh'}.get(r['design'])
   if not name or r['benchmark'] not in BENCHES:continue
   if nodes==64 and r['accepted'].lower()!='true':continue
   assert r['pass_fail']=='PASS' and all(int(r[k])==0 for k in ('missing_expected_flits','unexpected_flits','timeout_hit'))
   duration=(int(r['measurement_end_ps'])-int(r['measurement_start_ps']))*1e-12
   delivered=int(r['measurement_delivered_flits']);offered=int(r['measurement_offered_flits'])
   value=delivered/duration/nodes/1e6
   assert math.isclose(value,float(r['delivered_mflit_port_s']),abs_tol=1e-6)
   raw.append(dict(nodes=nodes,design=name,benchmark=r['benchmark'],seed=int(r['seed']),load=int(r['load']),
      window_ns=duration*1e9,window_output_copy_flits=delivered,window_offered_physical_flits=offered,
      output_mflit_s_per_node=value,output_total_gflit_s=delivered/duration/1e9,
      actual_offered_mflit_s_per_node=offered/duration/nodes/1e6))
 assert len(raw)==1080 and len({tuple(r[k] for k in ('nodes','design','benchmark','seed','load')) for r in raw})==1080
 groups=[]
 for n in (64,256):
  for d in ('M16','Mesh'):
   for b in BENCHES:
    for load in LOADS:
     rr=[r for r in raw if (r['nodes'],r['design'],r['benchmark'],r['load'])==(n,d,b,load)]
     assert len(rr)==3 and {r['seed'] for r in rr}=={202701,202702,202703}
     q=dict(nodes=n,design=d,benchmark=b,load=load,seeds=3)
     for k in ('output_mflit_s_per_node','output_total_gflit_s','actual_offered_mflit_s_per_node','window_ns'):
      q[k+'_mean']=statistics.mean(r[k] for r in rr);q[k+'_std']=statistics.stdev(r[k] for r in rr)
     groups.append(q)
 peaks=[];ratios=[]
 for n in (64,256):
  for d in ('M16','Mesh'):
   for b in BENCHES:
    peaks.append(max((r for r in groups if (r['nodes'],r['design'],r['benchmark'])==(n,d,b)),key=lambda r:r['output_mflit_s_per_node_mean']))
 for d in ('M16','Mesh'):
  for b in BENCHES:
   lo=next(r for r in peaks if (r['nodes'],r['design'],r['benchmark'])==(64,d,b))
   hi=next(r for r in peaks if (r['nodes'],r['design'],r['benchmark'])==(256,d,b))
   ratios.append(dict(design=d,benchmark=b,peak64_mflit_s_node=lo['output_mflit_s_per_node_mean'],peak256_mflit_s_node=hi['output_mflit_s_per_node_mean'],
     per_node_ratio_256_64=hi['output_mflit_s_per_node_mean']/lo['output_mflit_s_per_node_mean'],total_ratio_256_64=hi['output_total_gflit_s_mean']/lo['output_total_gflit_s_mean']))
 write(OUT/'raw_common_metric.csv',raw);write(OUT/'three_seed_common_metric.csv',groups);write(OUT/'peak_common_metric.csv',peaks);write(OUT/'scale_comparison.csv',ratios)
 plt.rcParams.update({'font.size':10,'pdf.fonttype':42})
 fig,axes=plt.subplots(1,2,figsize=(11,4.3),layout='constrained')
 for j,(metric,label) in enumerate([('output_mflit_s_per_node','Per-node output throughput (Mflit/s/node)'),('output_total_gflit_s','Total network output throughput (Gflit/s)')]):
  ax=axes[j]
  for idx,(d,n,color,hatch) in enumerate([('M16',64,'#2878B5',None),('M16',256,'#2878B5','//'),('Mesh',64,'#D95319',None),('Mesh',256,'#D95319','//')]):
   rr=[next(r for r in peaks if (r['nodes'],r['design'],r['benchmark'])==(n,d,b)) for b in BENCHES]
   vals=[r[metric+'_mean'] for r in rr]
   bars=ax.bar(np.arange(3)+(idx-1.5)*.20,vals,.185,color=color if n==64 else 'white',edgecolor=color,hatch=hatch,
    yerr=[r[metric+'_std'] for r in rr],capsize=2,label=f'{d}-{n}')
   ax.bar_label(bars,labels=[f'{v:.1f}' for v in vals],padding=4,fontsize=8,rotation=90)
  ax.set_xticks(range(3),['UR','Multicast10','All-Multicast']);ax.set_ylabel(label);ax.set_xlabel('Benchmark')
  ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True);ax.margins(y=.25)
 handles,labels=axes[0].get_legend_handles_labels();fig.legend(handles,labels,ncol=4,loc='outside upper center',frameon=False)
 for ext in ('pdf','png'):fig.savefig(OUT/f'peak_throughput64_256_common_metric.{ext}',dpi=300)
 manifest=dict(raw_rows=len(raw),groups=len(groups),peaks=len(peaks),scope='common output counter/window arithmetic; source schedule and finite-batch protocols NOT equalized',
  sources={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for _,p in sources})
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
 print(json.dumps(ratios,indent=2))
if __name__=='__main__':main()
