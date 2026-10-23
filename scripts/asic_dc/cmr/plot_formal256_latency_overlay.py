"""Overlay the three native benchmarks with a fixed 0-200 view."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

root=Path('results/formal256_20261019_r3_checks')
with (root/'summary/three_seed_means.csv').open() as f:
    rows=list(csv.DictReader(f))
plt.rcParams.update({'font.size':10,'font.family':'DejaVu Sans','pdf.fonttype':42})
fig,ax=plt.subplots(figsize=(6.2,5.8))
ax.set_box_aspect(.8)
benches=[('TOPO-UR','UR','o','-'),('MULTICAST10-AABB','Multicast10','s','--'),('ALL-MULTICAST-AABB','All-Multicast','^',':')]
handles=[]
for design,name,color in [('Mesh256','Mesh','#D95319'),('M16_256','M16','#2878B5')]:
    for benchmark,label,marker,style in benches:
        points=sorted([r for r in rows if r['design']==design and r['benchmark']==benchmark and r['mode']=='native'],key=lambda r:float(r['load']))
        assert len(points)==30 and all(int(r['valid_seeds'])==3 for r in points)
        x=[float(r['load']) for r in points];y=[float(r['mean_last_destination_ns_mean']) for r in points]
        ax.plot(x,y,color=color,ls=style,lw=2)
        for r,xx,yy in zip(points,x,y):
            if xx<=300 and yy<=200:
                ax.plot(xx,yy,ls='none',marker=marker,ms=5.5,color=color,mfc=color if r['latency_curve_eligible']=='True' else 'white',mew=1.1)
        handles.append(Line2D([],[],color=color,ls=style,lw=2,marker=marker,ms=5.5,label=f'{name} - {label}'))
ax.set(xlim=(0,300),ylim=(0,200),xlabel='Offered original-flit load (Mflit/s/port)',ylabel='Last-destination latency (ns)')
ax.set_xticks([0,40,80,120,160,200,240,280,300]);ax.set_yticks(range(0,201,40))
ax.grid(alpha=.22)
topology_handles=[Line2D([],[],color='#2878B5',lw=2,label='M16'),
                  Line2D([],[],color='#D95319',lw=2,label='Mesh')]
benchmark_handles=[Line2D([],[],color='#333333',ls='none',marker=marker,ms=5.5,label=label)
                   for _,label,marker,_ in benches]
fig.legend(handles=topology_handles,loc='upper center',ncol=2,frameon=False,
           bbox_to_anchor=(.55,.99),columnspacing=2,handlelength=2.4)
fig.legend(handles=benchmark_handles,loc='upper center',ncol=3,frameon=False,
           bbox_to_anchor=(.55,.93),columnspacing=1.4,handlelength=1)
fig.subplots_adjust(left=.14,right=.98,bottom=.12,top=.80)
out=root/'figures'
for ext in ('png','pdf'):
    p=out/f'formal256_latency_overlay_0_200.{ext}'
    fig.savefig(p,dpi=300)
    print(p)
assert ax.get_box_aspect()==.8
plt.close(fig)
