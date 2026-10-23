"""Plot the existing 256 M16 control using the actual 64 TB latency rule."""
import json,csv,statistics
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

out=Path('results/formal256_native_repeated_latency_64definition_20261022_r1')
rows=json.loads((out/'seed_records.json').read_text())
assert len(rows)==24
summary=[]
for d in ('M16_256','Mesh256'):
 for b in ('MULTICAST10-AABB','ALL-MULTICAST-AABB'):
  for mode in ('native','repeated'):
   rr=[r for r in rows if (r['design'],r['benchmark'],r['mode'])==(d,b,mode)]
   assert len(rr)==3
   q=dict(design=d,benchmark=b,mode=mode,load=rr[0]['load'],seeds=3)
   for field in ('mean_window_copy_latency_ns','mean_offer_to_head_req_ns','mean_head_req_to_tail_ns','old_last_destination_latency_ns'):
    q[field]=statistics.mean(r[field] for r in rr)
    q[field+'_sample_std']=statistics.stdev(r[field] for r in rr)
   summary.append(q)
for name,data in [('seed_records.csv',rows),('latency_summary.csv',summary)]:
 with (out/name).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
plt.rcParams.update({'font.size':11,'pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(7.2,4.8),layout='constrained')
for i,mode in enumerate(('native','repeated')):
 rr=[next(r for r in summary if r['design']=='M16_256' and r['benchmark']==b and r['mode']==mode) for b in ('MULTICAST10-AABB','ALL-MULTICAST-AABB')]
 vals=[r['mean_window_copy_latency_ns'] for r in rr]
 bars=ax.bar(np.arange(2)+(i-.5)*.3,vals,.28,color='#2878B5' if i==0 else 'white',edgecolor='#2878B5',hatch=None if i==0 else '//',
 yerr=[r['mean_window_copy_latency_ns_sample_std'] for r in rr],capsize=3,label='M16 - '+mode.title(),linewidth=1.2)
 ax.bar_label(bars,labels=[f'{v:.1f}' for v in vals],padding=6,fontsize=10)
ax.set_xticks([0,1],['Multicast10\n40 Mflit/s/port','All-Multicast\n20 Mflit/s/port'])
ax.set_ylabel('Window-completed copy latency (ns)');ax.set_ylim(bottom=0)
ax.set_ylim(0,800);ax.grid(axis='y',alpha=.22);ax.set_axisbelow(True);ax.legend(frameon=False,ncol=2,loc='upper left')
for ext in ('png','pdf'):fig.savefig(out/f'formal256_m16_native_repeated_latency_64definition.{ext}',dpi=300)
print(json.dumps(summary,indent=2))
