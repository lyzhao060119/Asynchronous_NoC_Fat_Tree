"""Separate M16 Native/Repeated latency bars, preserving the unified metric."""
import csv
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'results/m16_native_repeated_64_256_20261022_r1/plotted_data.csv'
OUT = ROOT / 'results/m16_native_repeated_separate_20261023_r1'
OUT.mkdir(parents=True, exist_ok=True)
with SOURCE.open(newline='') as stream:
    rows = list(csv.DictReader(stream))
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11,
                     'pdf.fonttype': 42, 'axes.spines.top': False,
                     'axes.spines.right': False})
benchmarks = ['MULTICAST10-AABB', 'ALL-MULTICAST-AABB']
for nodes in (64, 256):
    fig, ax = plt.subplots(figsize=(6.1, 4.6))
    fig.subplots_adjust(left=.15, right=.97, bottom=.19, top=.81)
    x = np.arange(2)
    upper = 0
    loads = []
    for mode, offset, color, hatch in [('native', -.19, '#8064A2', None),
                                      ('repeated', .19, '#43977A', '//')]:
        values, errors = [], []
        for benchmark in benchmarks:
            matches = [r for r in rows if int(r['nodes']) == nodes
                       and r['benchmark'] == benchmark and r['mode'] == mode]
            assert len(matches) == 1
            r = matches[0]
            assert int(r['seeds']) == 3
            values.append(float(r['mean_ns']))
            errors.append(float(r['sample_sd_ns']))
            if mode == 'native':
                loads.append(float(r['load_mflit_port_s']))
            else:
                assert float(r['load_mflit_port_s']) == loads[len(values)-1]
        bars = ax.bar(x + offset, values, width=.34, yerr=errors, capsize=4,
                      color=color, edgecolor='#333333', linewidth=.8,
                      hatch=hatch, label=mode.capitalize(), zorder=3)
        for bar, value, error in zip(bars, values, errors):
            ax.text(bar.get_x()+bar.get_width()/2, value+error, f'{value:.2f}',
                    ha='center', va='bottom', fontsize=10,
                    transform=ax.transData)
        upper = max(upper, max(v+e for v,e in zip(values,errors)))
    ax.set_ylim(0, upper * 1.22)
    ax.set_xticks(x, [f'Multicast10\n{loads[0]:g} Mflit/s/port',
                      f'All-Multicast\n{loads[1]:g} Mflit/s/port'])
    ax.set_ylabel('Window-completed copy latency (ns)')
    ax.set_axisbelow(True)
    ax.grid(axis='y', color='#dddddd', linewidth=.7)
    ax.legend(loc='upper left', frameon=False)
    fig.suptitle(f'M16 - {nodes} nodes', y=.96, fontsize=14)
    fig.text(.56, .875, 'Three-seed mean; error bars: sample SD',
             ha='center', fontsize=9, color='#555555')
    for extension in ('png', 'pdf'):
        fig.savefig(OUT / f'm16_{nodes}_native_repeated_latency.{extension}', dpi=320)
    plt.close(fig)
