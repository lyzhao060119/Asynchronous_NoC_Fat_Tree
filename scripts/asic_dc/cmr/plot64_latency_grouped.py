"""Two matched-scale latency overlays: topology color, benchmark marker/style."""
import csv,json,hashlib
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MultipleLocator

BASE=Path(__file__).resolve().parents[3]
SOURCE=BASE/'results/formal64_all_20261021_r1/formal64_seed_averages.csv'
OUT=BASE/'results/formal64_grouped_latency_20261021_r1'
TOPOLOGIES=[('PROP_M16','M16','#2463A0'),('FM64','Mesh','#D77732'),('PFAT64','PFAT','#4A8962')]
GROUPS=[('unicast','Unicast traffic',[
 ('TOPO-UR','Uniform random','o','-'),
 ('TOPO-BC','Bit complement','s',(0,(5,2.5))),
 ('HOTSPOT10','Hotspot10','^',(0,(5,2,1.2,2)))]),
 ('multicast','Mixed unicast / multicast traffic',[
 ('MULTICAST5-AABB','M5','o','-'),
 ('MULTICAST10-AABB','M10','s',(0,(5,2.5))),
 ('MULTICAST-STATIC-AABB','M-static','^',(0,(5,2,1.2,2)))])]

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 with SOURCE.open(newline='',encoding='utf-8') as f:rows=list(csv.DictReader(f))
 plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.labelsize':11,
  'xtick.labelsize':9,'ytick.labelsize':9,'pdf.fonttype':42,'ps.fonttype':42,
  'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.8,
  'xtick.direction':'out','ytick.direction':'out','savefig.facecolor':'white'})
 manifest={'source':str(SOURCE.relative_to(BASE)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
  'xlim':[0,300],'ylim_by_group':{'unicast':[1,40],'multicast':[1,60]},'yscale':'linear','metric':'offer_to_tail_mean_ns_mean',
  'topology_color':{d:c for d,_,c in TOPOLOGIES},'smoothing':False,'sync_included':False,
  'axes_box_aspect':.8,'line_width_pt':2,'marker_size_pt':6,
  'benchmark_line_styles':['solid','dashed','dashdot'],'curves':[]}
 plotdata=[]
 for group,title,benchmarks in GROUPS:
  ymax=40 if group=='unicast' else 60
  width=7.4
  height=8.5-.2*.84*width
  bottom=1.02/height
  fig,ax=plt.subplots(figsize=(width,height))
  fig.subplots_adjust(left=.13,right=.97,bottom=bottom,top=bottom+.8*.84*width/height)
  ax.set_box_aspect(.8)
  fig.text(.13,1-.17/height,title,fontsize=14,fontweight='semibold',ha='left',va='top',color='#17212B')
  fig.text(.13,1-.527/height,'TOPOLOGY',fontsize=8,fontweight='bold',color='#65707C',va='center')
  handles=[Line2D([],[],color=c,lw=2.3,label=label) for _,label,c in TOPOLOGIES]
  fig.legend(handles=handles,loc='center left',bbox_to_anchor=(.27,1-.527/height),ncol=3,
   frameon=False,fontsize=9.5,handlelength=2.1,columnspacing=2,borderaxespad=0)
  fig.text(.13,1-.8925/height,'BENCHMARK',fontsize=8,fontweight='bold',color='#65707C',va='center')
  handles=[Line2D([],[],color='#46515D',marker=marker,ms=6,lw=2,linestyle=style,label=label) for _,label,marker,style in benchmarks]
  fig.legend(handles=handles,loc='center left',bbox_to_anchor=(.27,1-.8925/height),ncol=3,
   frameon=False,fontsize=9.5,handlelength=2.2,columnspacing=1.5,borderaxespad=0)
  for d,label,color in TOPOLOGIES:
   for b,blabel,marker,style in benchmarks:
    rr=sorted([r for r in rows if r['design']==d and r['benchmark']==b and int(r['load'])<=300],key=lambda r:int(r['load']))
    assert rr and all(r['n_seeds']=='3' for r in rr)
    assert len(rr)==len({r['load'] for r in rr})
    x=[int(r['load']) for r in rr];y=[float(r['offer_to_tail_mean_ns_mean']) for r in rr]
    ax.plot(x,y,color=color,lw=2,linestyle=style,alpha=.97,zorder=2)
    for eligible,face in [('True',color),('False','white')]:
     subset=[r for r in rr if r['latency_curve_eligible']==eligible]
     ax.plot([int(r['load']) for r in subset],[float(r['offer_to_tail_mean_ns_mean']) for r in subset],
      linestyle='none',marker=marker,ms=6,markerfacecolor=face,
      markeredgecolor=color,markeredgewidth=.85,zorder=3)
    manifest['curves'].append(dict(group=group,design=d,benchmark=b,marker=marker,points=len(rr),
     above_display=sum(v>ymax for v in y),below_display=sum(v<1 for v in y)))
    plotdata.extend(dict(group=group,design=d,benchmark=b,load=r['load'],latency_ns=r['offer_to_tail_mean_ns_mean'],
     sample_sd_ns=r['offer_to_tail_mean_ns_std'],n_seeds=r['n_seeds'],near_lossless=r['latency_curve_eligible']) for r in rr)
  ax.set(xlim=(0,300),ylim=(1,ymax),xlabel='Injection rate (Mflit/s/port)',ylabel='Offer-to-last-tail latency (ns)')
  ax.xaxis.set_major_locator(MultipleLocator(50));ax.set_yticks([1]+list(range(10,ymax+1,10)))
  ax.grid(axis='y',color='#DCE2E8',linewidth=.65)
  ax.grid(axis='x',color='#E8ECF0',linewidth=.45)
  ax.set_axisbelow(True);ax.tick_params(length=3.5,width=.7,pad=5)
  ax.spines['left'].set_color('#66717C');ax.spines['bottom'].set_color('#66717C')
  fig.text(.13,.2295/height,'64 nodes  |  5-flit packets  |  Three-seed means',fontsize=8,color='#5D6772')
  fig.text(.97,.2295/height,'Open markers: pressure points',fontsize=8,color='#5D6772',ha='right')
  fig.canvas.draw()
  box=ax.get_window_extent()
  assert abs(box.height/box.width-.8)<1e-6
  for ext in ['png','pdf']:fig.savefig(OUT/('latency_'+group+'.'+ext),dpi=320)
  plt.close(fig)
 with (OUT/'plot_data.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(plotdata[0]));w.writeheader();w.writerows(plotdata)
 manifest['outputs_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.suffix in ['.png','.pdf']}
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
 print('GROUPED_LATENCY_PASS curves=%d points=%d output=%s'%(len(manifest['curves']),len(plotdata),OUT))

if __name__=='__main__':main()
