"""Reproduce the two asynchronous single-router comparison figures."""
from pathlib import Path
import csv
import hashlib
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent.parent
sources = [ROOT / 'results/single_router_final_20261022/final_results.json',
           ROOT / 'results/single_router_c2p4_c4p8_20261022_r5/summary.json']
thin = next(r for r in json.loads(sources[0].read_text(encoding='utf-8')) if r['config'] == 'async_c1p1')
others = {r['config']: r for r in json.loads(sources[1].read_text(encoding='utf-8'))}
rows = [{'router': 'Thin (c1p1)', 'area_um2': thin['area_um2'],
         'packet_completion_div5_ns': thin['random_packet_completion_div5_ns']}]
for name in ['c2p4', 'c4p8']:
    r = others['async_' + name]
    rows.append({'router': name, 'area_um2': r['area_um2'],
                 'packet_completion_div5_ns': r['packet_completion_div5_ns']})
with (OUT / 'plot_data.csv').open('w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)

plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 12,
                     'axes.titlesize': 15, 'axes.labelsize': 12,
                     'pdf.fonttype': 42, 'ps.fonttype': 42,
                     'axes.spines.top': False, 'axes.spines.right': False})
colors = ['#4878A8', '#389A88', '#D98A40']

def plot(metric, ylabel, title, filename, scale, fmt, note):
    fig, ax = plt.subplots(figsize=(6.4, 4.5))
    values = [r[metric] / scale for r in rows]
    bars = ax.bar([r['router'] for r in rows], values, width=0.58,
                  color=colors, edgecolor='white', linewidth=0.8, zorder=3)
    ax.set_ylabel(ylabel)
    ax.set_title(title, pad=17)
    ax.set_ylim(0, max(values) * 1.20)
    ax.yaxis.grid(True, color='#DDDDDD', linewidth=0.7, zorder=0)
    ax.set_axisbelow(True)
    ax.tick_params(axis='x', length=0, pad=9)
    for bar, value in zip(bars, values):
        ax.annotate(format(value, fmt), (bar.get_x()+bar.get_width()/2, value),
                    xytext=(0, 7), textcoords='offset points', ha='center', fontsize=12)
    fig.text(0.5, 0.035, note, ha='center', fontsize=9, color='#555555')
    fig.subplots_adjust(left=0.16, right=0.97, bottom=0.18, top=0.85)
    for ext in ['pdf', 'png', 'svg']:
        fig.savefig(OUT / (filename + '.' + ext), dpi=300, facecolor='white')
    plt.close(fig)

plot('area_um2', 'Synthesized cell area (10³ µm²)',
     'Single-router area', 'single_router_area', 1000, '.2f',
     'Asynchronous routers · TT, 0.8 V, 25 °C')
plot('packet_completion_div5_ns', 'Amortized flit latency (ns)',
     'Single-router flit latency', 'single_router_amortized_flit_latency', 1, '.4f',
     'Asynchronous routers · 5-flit packet completion time / 5')

(OUT / 'provenance.json').write_text(json.dumps({
    'sources': [{'path': str(p.relative_to(ROOT)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sources],
    'latency_definition': 'Head request at ingress to tail request at egress, divided by 5; not mean individual flit residence time.',
    'area_definition': 'Synthesized standard-cell area, um^2; before place and route.',
    'data': rows,
}, indent=2), encoding='utf-8')
print(json.dumps(rows, indent=2))
