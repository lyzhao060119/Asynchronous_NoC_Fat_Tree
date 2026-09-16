#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv
from pathlib import Path
import matplotlib.pyplot as plt

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root', type=Path, required=True); a=ap.parse_args()
    rows=list(csv.DictReader((a.root/'summary.csv').open(encoding='utf-8')))
    fig, ax=plt.subplots(1,2,figsize=(8.0,3.1), constrained_layout=True)
    for d, style in [('Dynamic4','o-'),('Static4','s--')]:
        r=[x for x in rows if x['design']==d]
        x=[int(z['load']) for z in r]
        ax[0].plot(x,[float(z['flit_lat_p95_ns']) for z in r],style,label=d)
        ax[1].plot(x,[float(z['delivery_ratio'])*100 for z in r],style,label=d)
    ax[0].set(xlabel='offered MFlit/s/port',ylabel='measurement p95 flit latency (ns)')
    ax[1].set(xlabel='offered MFlit/s/port',ylabel='measurement delivery (%)',ylim=(50,100.5))
    for p in ax: p.grid(True,alpha=.25); p.legend(frameon=False)
    fig.savefig(a.root/'dir-skew64-inset.pdf'); fig.savefig(a.root/'dir-skew64-inset.png',dpi=220)
if __name__=='__main__': main()
