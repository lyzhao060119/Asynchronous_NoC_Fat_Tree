"""Latency-only native/repeated comparison for the two 256 benchmarks."""
import csv
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

root=Path('results/formal256_20261019_r3_checks')
with (root/'summary/native_repeated_comparison.csv').open() as f:rows=list(csv.DictReader(f))
out=Path('results/formal256_native_repeated_latency_20261022_r1');out.mkdir(exist_ok=True)
plt.rcParams.update({'font.size':11,'pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(7.2,4.8),layout='constrained')
benches=['MULTICAST10-AABB','ALL-MULTICAST-AABB']
for idx,(design,label,mode,color) in enumerate([
 ('M16_256','M16 - Native','native','#2878B5'),
 ('M16_256','M16 - Repeated','repeated','#2878B5')]):
 selected=[next(r for r in rows if r['design']==design and r['benchmark']==b) for b in benches]
 assert all(int(r['seeds'])==3 for r in selected)
 vals=[float(r[mode+'_latency_ns']) for r in selected]
 err=[float(r[mode+'_latency_std_ns']) for r in selected]
 bars=ax.bar(np.arange(2)+(idx-.5)*.30,vals,.28,color=color if mode=='native' else 'white',
             edgecolor=color,hatch=None if mode=='native' else '//',linewidth=1.2,
             yerr=err,capsize=3,label=label)
 ax.bar_label(bars,labels=[f'{v:.1f}' for v in vals],padding=5,fontsize=9)
ax.set_xticks([0,1],['Multicast10\n40 Mflit/s/port','All-Multicast\n20 Mflit/s/port'])
ax.set_ylabel('Last-destination latency (ns)')
ax.set_ylim(0,800);ax.set_xlim(-.5,1.5)
ax.grid(axis='y',alpha=.22);ax.set_axisbelow(True)
ax.legend(frameon=False,ncol=2,loc='upper left')
for ext in ('png','pdf'):
 p=out/f'formal256_native_repeated_latency.{ext}';fig.savefig(p,dpi=300);print(p)
plt.close(fig)
