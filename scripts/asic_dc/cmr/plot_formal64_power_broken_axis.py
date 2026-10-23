"""Broken-axis presentation of unchanged Sync/Async power means and SDs."""
import json, hashlib
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from fetch_plot_formal64_sync_async_power import OUT, SERIES, BENCHMARKS

def main():
    source=OUT/'plot_manifest.json'
    meta=json.loads(source.read_text());means=meta['means']
    assert len(means)==18
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,
        'ps.fonttype':42,'axes.spines.top':False,'axes.spines.right':False,
        'axes.linewidth':.8,'hatch.linewidth':.85})
    fig,(upper,lower)=plt.subplots(2,1,sharex=True,figsize=(9.8,5.6),
                                  gridspec_kw={'height_ratios':[1,1.7],'hspace':.14})
    fig.subplots_adjust(left=.09,right=.985,bottom=.27,top=.82)
    x=np.arange(6);width=.235
    for ax,limits in [(upper,(260,290)),(lower,(0,45))]:
        ax.set(xlim=(-.55,5.55),ylim=limits)
        ax.axvspan(2.5,5.55,color='#F2F5F8',zorder=0)
        ax.axvline(2.5,color='#BFC8D1',lw=.8,ls=(0,(3,3)),zorder=1)
        for i,(design,label,color,hatch) in enumerate(SERIES):
            rr=[]
            for b,_,_ in BENCHMARKS:
                matches=[r for r in means if r['design']==design and r['benchmark']==b]
                assert len(matches)==1 and matches[0]['n_seeds']==3
                rr.append(matches[0])
            y=[r['power_mw_mean'] for r in rr];sd=[r['power_mw_sample_sd'] for r in rr]
            bars=ax.bar(x+(i-1)*width,y,width=width*.94,color=color,edgecolor='white',
                        linewidth=.65,hatch=hatch,label=label,zorder=3)
            ax.errorbar(x+(i-1)*width,y,yerr=sd,fmt='none',ecolor='#27333F',
                        elinewidth=.8,capsize=2.5,capthick=.8,zorder=4)
            for bar,value,error in zip(bars,y,sd):
                if limits[0] <= value <= limits[1]:
                    ax.text(bar.get_x()+bar.get_width()/2,value+error+.9,
                            f'{value:.1f}',ha='center',va='bottom',fontsize=8,color='#354250')
        ax.grid(axis='y',color='#DCE2E8',linewidth=.65);ax.set_axisbelow(True)
        ax.spines['left'].set_color('#66717C');ax.spines['bottom'].set_color('#66717C')
    upper.spines['bottom'].set_visible(False)
    upper.tick_params(axis='x',which='both',bottom=False,labelbottom=False)
    lower.tick_params(axis='x',length=0,pad=8)
    upper.set_yticks([260,270,280,290]);lower.set_yticks([0,10,20,30,40,45])
    lower.set_xticks(x)
    lower.set_xticklabels([f'{label}\n({load} Mflit/s/port)' for _,label,load in BENCHMARKS],fontsize=9)
    # Diagonal strokes mark the actual y-axis discontinuity, not data values.
    for ax,ypos in [(upper,0),(lower,1)]:
        ax.plot([-.009,.009],[ypos-.025,ypos+.025],transform=ax.transAxes,
                color='#46515D',lw=1.1,clip_on=False,zorder=6)
    gap=(upper.get_position().y0+lower.get_position().y1)/2
    fig.text(.985,gap,'45-260 mW omitted',ha='right',va='center',fontsize=7.8,color='#65707C')
    fig.text(.025,.55,'Total network power (mW)',rotation=90,ha='center',va='center',fontsize=11)
    fig.text(.09,.955,'64-node network power',fontsize=14,fontweight='semibold',color='#17212B',va='top')
    fig.legend(*lower.get_legend_handles_labels(),loc='upper left',bbox_to_anchor=(.084,.91),
               ncol=3,frameon=False,fontsize=10,columnspacing=1.8,handlelength=1.5)
    fig.text(.09,.10,'Three-seed mean with sample SD; TT 0.8 V, 25 C; Sync clock: 1 GHz.',fontsize=8.5,color='#5D6772')
    fig.text(.09,.062,'Broken y-axis: 0-45 and 260-290 mW. Hatched bars: synchronous M16; Mesh: historical routing.',fontsize=8,color='#5D6772')
    fig.text(.09,.025,'Provisional synthesis estimates: PT/library warnings remain; extended Sync waveform audit is pending.',fontsize=8,color='#5D6772')
    stem='formal64_sync_async_power_broken_axis'
    for ext in ['png','pdf']:fig.savefig(OUT/f'{stem}.{ext}',dpi=320)
    plt.close(fig)
    (OUT/f'{stem}_manifest.json').write_text(json.dumps(dict(
        source=str(source),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        means=means,series=SERIES,ylim_lower_mw=[0,45],ylim_upper_mw=[260,290],
        y_scale_within_each_panel='linear',linear_plot_preserved=True,
        outputs_sha256={ext:hashlib.sha256((OUT/f'{stem}.{ext}').read_bytes()).hexdigest() for ext in ['png','pdf']}),indent=2))
    print('BROKEN_AXIS_POWER_PLOT_PASS data_groups=18 data_unchanged=1')

if __name__=='__main__':main()
