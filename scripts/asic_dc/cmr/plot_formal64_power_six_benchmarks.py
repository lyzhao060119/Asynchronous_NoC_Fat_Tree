"""Plot audited non-broadcast 64-node power estimates; exclude all-multicast."""
import csv
import hashlib
import json
import statistics
import argparse
import math
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import MultipleLocator

BASE=Path(__file__).resolve().parents[3]
SOURCE=BASE/'results/formal64_all_20261021_r1/power_results_all_seeds.csv'
OUT=BASE/'results/formal64_power_bars_20261022_r1'
TOPOLOGIES=[('PROP_M16','M16','#2463A0','current'),
            ('FM64','Mesh (legacy routing)','#D77732','pre_xfirst_route'),
            ('PFAT64','PFAT','#4A8962','current')]
BENCHMARKS=[('TOPO-UR','Uniform\nrandom',80),
            ('TOPO-BC','Bit\ncomplement',40),
            ('HOTSPOT10','Hotspot10',80),
            ('MULTICAST5-AABB','Multicast5',40),
            ('MULTICAST10-AABB','Multicast10',20),
            ('MULTICAST-STATIC-AABB','Multicast-\nstatic',20)]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--metric',choices=['power','energy'],default='power')
    args=ap.parse_args()
    energy=args.metric=='energy'
    out=BASE/'results/formal64_energy_bars_20261022_r1' if energy else OUT
    mean_key='mean_nj' if energy else 'mean_mw'
    sd_key='sample_sd_nj' if energy else 'sample_sd_mw'
    with SOURCE.open(newline='',encoding='utf-8-sig') as stream:
        records=list(csv.DictReader(stream))
    data=[]
    for d,label,color,variant in TOPOLOGIES:
        for b,blabel,load in BENCHMARKS:
            rr=[r for r in records if r['design']==d and r['benchmark']==b
                and r['variant']==variant and r['accepted'].lower()=='true']
            assert len(rr)==3 and {r['seed'] for r in rr}=={'202701','202702','202703'},(d,b)
            assert {int(r['load']) for r in rr}=={load},(d,b)
            values=[float(r['total_w'])*float(r['window_s'])*1e9 if energy
                    else float(r['total_w'])*1000 for r in rr]
            if energy:
                assert all(math.isclose(v,float(r['energy_nj']),rel_tol=1e-10,abs_tol=1e-8)
                           for v,r in zip(values,rr)),(d,b,'energy mismatch')
            data.append(dict(design=d,benchmark=b,load=load,variant=variant,
                             n_seeds=3,**{mean_key:statistics.mean(values),
                             sd_key:statistics.stdev(values)},
                             seed_values={r['seed']:v for r,v in zip(rr,values)},
                             seed_window_s={r['seed']:float(r['window_s']) for r in rr}))

    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,
        'pdf.fonttype':42,'ps.fonttype':42,'axes.spines.top':False,
        'axes.spines.right':False,'axes.linewidth':.8,'savefig.facecolor':'white'})
    fig,ax=plt.subplots(figsize=(9.2,4.8))
    fig.subplots_adjust(left=.09,right=.985,bottom=.27,top=.81)
    x=np.arange(len(BENCHMARKS));width=.235
    ymax=math.ceil(max(r[mean_key]+r[sd_key] for r in data)*1.14/100)*100 if energy else 42
    ax.axvspan(2.5,5.55,color='#F2F5F8',zorder=0)
    ax.axvline(2.5,color='#BFC8D1',lw=.8,ls=(0,(3,3)),zorder=1)
    for i,(d,label,color,variant) in enumerate(TOPOLOGIES):
        rr=[r for r in data if r['design']==d]
        y=[r[mean_key] for r in rr];err=[r[sd_key] for r in rr]
        bars=ax.bar(x+(i-1)*width,y,width=width*.94,color=color,
                    edgecolor='white',linewidth=.65,label=label,zorder=3)
        ax.errorbar(x+(i-1)*width,y,yerr=err,fmt='none',ecolor='#27333F',
                    elinewidth=.8,capsize=2.5,capthick=.8,zorder=4)
        for bar,value,sd in zip(bars,y,err):
            ax.text(bar.get_x()+bar.get_width()/2,value+sd+ymax*.015,
                    f'{value:.0f}' if energy else f'{value:.1f}',
                    ha='center',va='bottom',fontsize=8,color='#354250')
    ax.set(xlim=(-.55,5.55),ylim=(0,ymax),
           ylabel='Total network energy (nJ)' if energy else 'Total network power (mW)')
    ax.set_xticks(x)
    ax.set_xticklabels([f'{label}\n({load} Mflit/s/port)' for _,label,load in BENCHMARKS],fontsize=9)
    ax.yaxis.set_major_locator(MultipleLocator(100 if energy else 10))
    ax.grid(axis='y',color='#DCE2E8',linewidth=.65,zorder=0)
    ax.set_axisbelow(True);ax.tick_params(axis='x',length=0,pad=8)
    ax.spines['left'].set_color('#66717C');ax.spines['bottom'].set_color('#66717C')
    fig.text(.09,.955,'64-node network energy' if energy else '64-node network power',fontsize=14,fontweight='semibold',
             color='#17212B',va='top')
    fig.legend(*ax.get_legend_handles_labels(),loc='upper left',bbox_to_anchor=(.084,.91),
               ncol=3,frameon=False,fontsize=10,columnspacing=2,handlelength=1.4)
    fig.text(.09,.085,'Offer-window energy = mean power x window duration; three-seed mean with sample SD.' if energy
             else 'Three-seed mean with sample SD; 5-flit packets; TT 0.8 V, 25 C.',
             fontsize=8.5,color='#5D6772')
    fig.text(.09,.043,'Mesh: historical routing. Synthesis-level estimates; library-table extrapolation / PT warnings remain.',
             fontsize=8,color='#5D6772')
    out.mkdir(parents=True,exist_ok=True)
    for ext in ('png','pdf'):
        fig.savefig(out/f'formal64_{args.metric}_six_benchmarks.{ext}',dpi=320)
    plt.close(fig)
    manifest=dict(source=str(SOURCE.relative_to(BASE)),source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        exclusions=['ALL-MULTICAST-AABB','ALL-BROADCAST','SYNC_M16','native_repeated_compact'],
        metric='total offer-window energy (nJ), including internal, switching and leakage' if energy
            else 'total network power, including internal, switching and leakage',
        energy_definition='per-seed power (W) x per-seed measurement window (s) x 1e9; no packet/copy normalization',
        corner='TT 0.8 V 25 C',packet_flits=5,
        error_bars='sample standard deviation (ddof=1)',data=data,
        scope='64-node synthesis-level estimates; not PVT/physical power signoff',
        waveform_audit='results/formal64_power_waveform_audit_20261022_r1/README.md')
    manifest['output_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.suffix in ('.png','.pdf')}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(out)
    print(f'{args.metric.upper()}_PLOT_PASS groups=18 seeds=54 benchmarks=6 sync_excluded=1')

if __name__=='__main__':main()
