"""Two-panel M16 latency comparison with explicit unequal offered loads."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

def read(p):
 with Path(p).open() as f:return list(csv.DictReader(f))
r64=read('results/formal64_native_repeated_latency_20261022_r1/latency_summary.csv')
r256=read('results/formal256_native_repeated_latency_64definition_20261022_r1/latency_summary.csv')
out=Path('results/m16_native_repeated_64_256_20261022_r1');out.mkdir(exist_ok=True)
plt.rcParams.update({'font.size':10,'pdf.fonttype':42})
fig,axes=plt.subplots(1,2,figsize=(10,4.4))
fig.subplots_adjust(left=.08,right=.98,bottom=.22,top=.77,wspace=.29)
colors={64:'#8064A2',256:'#43977A'}
records=[]
for ax,b,title,limit in zip(axes,['MULTICAST10-AABB','ALL-MULTICAST-AABB'],['Multicast10','All-Multicast'],[75,720]):
 vals=[];errs=[]
 for nodes in (64,256):
  for mode in ('native','repeated'):
   if nodes==64:
    r=next(r for r in r64 if r['benchmark']==b and r['mode'].lower()==mode)
    val=float(r['mean_ns']);err=float(r['sample_sd_ns']);load=r['load_mflit_port_s']
   else:
    r=next(r for r in r256 if r['design']=='M16_256' and r['benchmark']==b and r['mode']==mode)
    val=float(r['mean_window_copy_latency_ns']);err=float(r['mean_window_copy_latency_ns_sample_std']);load=r['load']
   vals.append(val);errs.append(err)
   records.append(dict(nodes=nodes,benchmark=b,mode=mode,load_mflit_port_s=load,mean_ns=val,sample_sd_ns=err,seeds=3))
 def bars(target,labels=True):
  for i,(val,err) in enumerate(zip(vals,errs)):
   nodes=64 if i<2 else 256;repeat=i%2==1;c=colors[nodes]
   bs=target.bar(i,val,.65,color='white' if repeat else c,edgecolor=c,hatch='//' if repeat else None,
     linewidth=1.2,yerr=err,capsize=3)
   if labels:target.bar_label(bs,labels=[f'{val:.1f}'],padding=4,fontsize=9)
 bars(ax)
 ax.set_xticks([.5,2.5],['64 nodes','256 nodes']);ax.set_ylim(0,limit)
 ax.set_title(title);ax.set_ylabel('Window-completed copy latency (ns)')
 ax.set_xlabel('Offered load: 64 / 256 = '+('20 / 40' if b.startswith('MULTICAST10') else '10 / 20')+' Mflit/s/port',labelpad=9,fontsize=9)
 ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
 if b=='ALL-MULTICAST-AABB':
  small=inset_axes(ax,width='53%',height='44%',loc='upper left',bbox_to_anchor=(.04,-.03,1,1),bbox_transform=ax.transAxes,borderpad=1)
  bars(small,labels=False);small.set_ylim(0,80);small.set_xlim(-.6,3.6)
  small.set_xticks([.5,2.5],['64','256'],fontsize=8);small.set_yticks([0,40,80]);small.tick_params(labelsize=8)
  small.set_title('Zoom: 0-80 ns',fontsize=8,pad=3);small.grid(axis='y',alpha=.15);small.set_axisbelow(True)
fig.legend(handles=[Patch(facecolor=colors[64],label='64 nodes'),Patch(facecolor=colors[256],label='256 nodes'),
 Patch(facecolor='#777777',label='Native'),Patch(facecolor='white',edgecolor='#777777',hatch='//',label='Repeated')],
 loc='upper center',ncol=4,frameon=False,bbox_to_anchor=(.53,.98))
for ext in ('png','pdf'):fig.savefig(out/f'm16_native_repeated_64_256.{ext}',dpi=300)
with (out/'plotted_data.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
plt.close(fig)
