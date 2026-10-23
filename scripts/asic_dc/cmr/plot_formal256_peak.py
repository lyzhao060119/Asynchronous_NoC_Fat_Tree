"""Plot peak three-seed mean delivered-copy throughput by benchmark."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

root=Path('results/formal256_20261019_r3_checks')
with (root/'summary/three_seed_means.csv').open() as f:rows=list(csv.DictReader(f))
benches=[('TOPO-UR','UR'),('MULTICAST10-AABB','Multicast10'),('ALL-MULTICAST-AABB','All-Multicast')]
plt.rcParams.update({'font.size':10,'pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(6.2,4.6),layout='constrained')
data=[]
for offset,design,label,color in [(-.18,'M16_256','M16','#2878B5'),(.18,'Mesh256','Mesh','#D95319')]:
    vals=[];errors=[]
    for b,_ in benches:
        candidates=[r for r in rows if r['design']==design and r['benchmark']==b and r['mode']=='native']
        assert len(candidates)==30 and all(int(r['valid_seeds'])==3 for r in candidates)
        best=max(candidates,key=lambda r:float(r['delivered_mflit_port_s_mean']))
        value=float(best['delivered_mflit_port_s_mean']);std=float(best['delivered_mflit_port_s_std'])
        vals.append(value);errors.append(std)
        data.append(dict(design=design,benchmark=b,peak_delivered_copy_mflit_port_s=value,std_mflit_port_s=std,peak_offered_load=best['load'],seeds=3))
    bars=ax.bar(np.arange(3)+offset,vals,width=.34,color=color,label=label,yerr=errors,capsize=3)
    ax.bar_label(bars,labels=[f'{v:.1f}' for v in vals],padding=7,fontsize=10)
ax.set_xticks(range(3),[label for _,label in benches])
ax.set_ylabel('Peak delivered-copy throughput (Mflit/s/port)')
ax.set_xlabel('Benchmark');ax.set_ylim(0,410)
ax.legend(frameon=False,ncol=2);ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
for ext in ('png','pdf'):fig.savefig(root/f'figures/formal256_peak_throughput.{ext}',dpi=300)
with (root/'summary/peak_throughput.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
print(data)
