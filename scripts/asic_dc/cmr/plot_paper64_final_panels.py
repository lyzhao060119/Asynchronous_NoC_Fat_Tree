#!/usr/bin/env python3
"""Render Fig.64-A and the lane-scaling/multicast Fig.64-B."""
import csv,json
from datetime import datetime
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

REPO=Path(__file__).resolve().parents[3]
RAW=REPO/'DATE paper/experiments/raw/paper64'
FIG=REPO/'DATE paper/experiments/figures/paper64'
COLORS={'PROP_temp64':'#007e87','PFAT64':'#c28616','FM64':'#a83535','PROP_temp64_static4':'#6b4ab5'}

def rows(path):return list(csv.DictReader(path.open(newline='',encoding='utf-8')))
def latest(prefix):return sorted(RAW.glob(prefix+'_*'))[-1]
def save(fig,out,name):
 out.mkdir(parents=True,exist_ok=False)
 for ext in ('pdf','png'):fig.savefig(out/(name+'.'+ext),bbox_inches='tight',dpi=220)
 plt.close(fig)

def main():
 cohort=latest('cohort64')
 ur=rows(cohort/'ur_acceptance.csv');bc=rows(cohort/'bc_hotspot_acceptance.csv')
 mc=rows(RAW/'compact64_20260915_112900/multicast_acceptance.csv')
 router=json.loads((RAW.parent/'hop_ppa/20260914_cmr_multi_lane_agg_r1/summary.json').read_text(encoding='utf-8'))
 stamp=cohort.name.removeprefix('cohort64_')
 out=FIG/('final64_'+stamp+'_lane_scaling_'+datetime.now().strftime('%H%M%S'))
 fig,axs=plt.subplots(1,2,figsize=(10.1,3.7),constrained_layout=True)
 for d,label in (('PROP_temp64','PROP temp64 B8'),('PFAT64','PFAT64'),('FM64','FlatMesh64')):
  data=sorted((r for r in ur if r['design']==d),key=lambda r:int(r['load_setpoint_mflit_per_port_s']))
  assert len(data)==30 and all(r['pass_fail']=='PASS' for r in data)
  x=[int(r['load_setpoint_mflit_per_port_s']) for r in data]
  axs[0].plot(x,[float(r['delivered_mflit_per_port_s']) for r in data],color=COLORS[d],label=label,lw=1.7)
  clean=[r for r in data if r['paper_latency_eligible']=='True' and r['cohort_latency_status']=='PASS' and r['cohort_measurement_flits']=='50000']
  axs[1].plot([int(r['load_setpoint_mflit_per_port_s']) for r in clean],
    [float(r['cohort_p95_ns']) for r in clean],color=COLORS[d],label=label,lw=1.7,marker='.',ms=4)
 axs[0].set(xlabel='Offered load (Mflit/s/port)',ylabel='Delivered throughput (Mflit/s/port)',title='(a) Uniform-random throughput')
 axs[1].set(xlabel='Offered load (Mflit/s/port)',ylabel='Full-drain cohort p95 flit latency (ns)',title='(b) Pre-saturation latency')
 for ax in axs:ax.grid(alpha=.18);ax.legend(frameon=False,fontsize=7)
 # BC/Hotspot are boundary checks, not a substitute for the main matched UR curve.
 ratios={}
 for bench in ('TOPO-UR','TOPO-BC','HOTSPOT10'):
  source=ur if bench=='TOPO-UR' else [r for r in bc if r['benchmark']==bench]
  near=lambda d:[float(r['delivered_mflit_per_port_s']) for r in source if r['design']==d and r['near_lossless']=='True']
  ratios[bench]=max(near('PROP_temp64'))/max(near('FM64'))
 axs[1].text(.97,.02,'Near-lossless peak PROP/Flat\nUR %.2fx | BC %.2fx | Hotspot10 %.2fx'%tuple(ratios.values()),
  ha='right',va='bottom',transform=axs[1].transAxes,fontsize=7,bbox=dict(facecolor='white',edgecolor='none',alpha=.84))
 save(fig,out,'fig64-a-architecture')
 fig,axs=plt.subplots(1,2,figsize=(10.1,3.7),constrained_layout=True)
 aggregate={int(item['parent_lanes']):float(item['throughput_gflit_s']) for item in router['rows']
            if item['status']=='PASS' and item['async']}
 assert set(aggregate)=={1,2,4}
 lanes=[1,2,4];throughput=[aggregate[x] for x in lanes]
 speedup=[value/throughput[0] for value in throughput]
 efficiency=[100.0*value/lanes[i] for i,value in enumerate(speedup)]
 bars=axs[0].bar([str(x) for x in lanes],throughput,color=['#8ab7bd','#3c969e','#007e87'])
 axs[0].set(xlabel='Physical parent lanes',ylabel='Aggregate throughput (Gflit/s)',title='(a) Router lane-count scaling')
 axs[0].grid(axis='y',alpha=.18)
 for i,bar in enumerate(bars):
  axs[0].text(bar.get_x()+bar.get_width()/2,bar.get_height()+.04,
   '%.3f\n%.2fx, %.1f%%'%(throughput[i],speedup[i],efficiency[i]),ha='center',va='bottom',fontsize=7)
 axs[0].set_ylim(0,max(throughput)*1.22)
 f16=[r for r in mc if r['fanout']=='16' and int(r['load']) in (5,20,60) and r['acceptance']=='PASS']
 assert len(f16)==6
 for scheme,label,color in (('native','Native','#007e87'),('source_repeated_unicast','Repeated-unicast','#a83535')):
  d={int(r['load']):r for r in f16 if r['scheme']==scheme}
  axs[1].plot([5,20,60],[float(d[x]['p95_completion_latency']) for x in (5,20,60)],
   label=label,color=color,marker='o' if scheme=='native' else 's')
 axs[1].set(xlabel='Load (Mflit/s/port)',ylabel='p95 destination completion latency (ns)',title='(b) F16 native vs repeated')
 axs[1].text(.03,.97,'M60 stress/censored; diagnostic only',transform=axs[1].transAxes,va='top',fontsize=7)
 axs[1].legend(frameon=False,fontsize=7);axs[1].grid(alpha=.18)
 save(fig,out.with_name(out.name+'_b'),'fig64-b-mechanisms')
 (out/'data_manifest.json').write_text(json.dumps({'ur_source':str(cohort/'ur_acceptance.csv'),'bc_source':str(cohort/'bc_hotspot_acceptance.csv'),
  'router_lane_scaling_source':str(RAW.parent/'hop_ppa/20260914_cmr_multi_lane_agg_r1/summary.json'),
  'f16_source':str(RAW/'compact64_20260915_112900/multicast_acceptance.csv'),
  'ratios':ratios,'router_throughput_gflit_s':aggregate,
  'static_dynamic_result_scope':'limitation only; not plotted as a positive mechanism claim'},indent=2)+'\n',encoding='utf-8')
 print('FIG64_COHORT_PASS',out,flush=True)
if __name__=='__main__':main()
