"""Plot the matched 64-node M16 Native/Repeated latency experiment."""
import csv
import hashlib
import json
from pathlib import Path
from statistics import mean, stdev

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'results/formal64_all_20261021_r1/native_repeated'
OUT = ROOT / 'results/formal64_native_repeated_latency_20261022_r1'
METRIC = 'offer_to_tail_mean_ns'
BENCHMARKS = [('MULTICAST10-AABB', 20), ('ALL-MULTICAST-AABB', 10)]
SEEDS = [202701, 202702, 202703]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records, sources = [], []
    for benchmark, load in BENCHMARKS:
        for mode in ['NATIVE', 'REPEATED']:
            values = []
            for seed in SEEDS:
                path = SOURCE / f'PROP_M16_{benchmark}_s{seed}_m{load}_{mode}.csv'
                with path.open(newline='', encoding='utf-8-sig') as stream:
                    rows = list(csv.DictReader(stream))
                assert len(rows) == 1, path
                row = rows[0]
                assert row['pass_fail'] == 'PASS', path
                for field in ['missing_expected_flits', 'unexpected_flits', 'timeout_hit']:
                    assert int(row[field]) == 0, (path, field)
                assert int(row['measurement_original_events']) == 1000, path
                values.append(float(row[METRIC]))
                sources.append({'path': str(path.relative_to(ROOT)),
                                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                'seed': seed, 'latency_ns': values[-1]})
            records.append({'benchmark': benchmark, 'load_mflit_port_s': load,
                            'mode': mode, 'mean_ns': mean(values),
                            'sample_sd_ns': stdev(values), 'n_seeds': len(values)})
    summary = ROOT / 'results/formal64_all_20261021_r1/native_repeated_seed_averages.csv'
    with summary.open(newline='', encoding='utf-8-sig') as stream:
        previous = {(r['benchmark'], r['mode']): r for r in csv.DictReader(stream)
                    if r['metric'] == METRIC}
    for r in records:
        old = previous[r['benchmark'], r['mode']]
        assert abs(r['mean_ns'] - float(old['mean'])) < 1e-9
        assert abs(r['sample_sd_ns'] - float(old['std'])) < 1e-9
    with (OUT / 'latency_summary.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)

    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11,
                         'pdf.fonttype': 42, 'ps.fonttype': 42,
                         'axes.linewidth': 1.0})
    fig, ax = plt.subplots(figsize=(6.2, 4.4), layout='constrained')
    x, width = np.arange(2), 0.30
    for index, (mode, color, label) in enumerate([
            ('NATIVE', '#2878B5', 'Native'),
            ('REPEATED', '#D95319', 'Repeated')]):
        subset = [r for r in records if r['mode'] == mode]
        heights = [r['mean_ns'] for r in subset]
        errors = [r['sample_sd_ns'] for r in subset]
        bars = ax.bar(x + (index - 0.5) * width, heights, width,
                      yerr=errors, capsize=4, color=color, label=label,
                      edgecolor='white', linewidth=0.8,
                      error_kw={'elinewidth': 1.2, 'capthick': 1.2, 'ecolor': '#333333'},
                      zorder=3)
        for bar, value, error in zip(bars, heights, errors):
            ax.text(bar.get_x() + bar.get_width()/2, value + error + 1.2,
                    f'{value:.2f}', ha='center', va='bottom', fontsize=11)
    ax.set_xticks(x, ['Multicast10\n20 Mflit/s/port', 'All-multicast\n10 Mflit/s/port'])
    ax.set_ylabel('Mean offer-to-tail latency (ns)')
    ax.set_ylim(0, 70)
    ax.set_yticks(np.arange(0, 71, 10))
    ax.set_xlim(-0.65, 1.65)
    ax.set_axisbelow(True)
    ax.grid(axis='y', color='#DDE2E7', linewidth=0.75)
    ax.spines[['top', 'right']].set_visible(False)
    ax.tick_params(axis='x', length=0, pad=9)
    ax.legend(loc='upper left', frameon=False, fontsize=10)
    ax.set_xlabel('Benchmark')
    ax.set_title('64-node M16: latency comparison', loc='left', pad=12, fontsize=12)
    stem = OUT / 'formal64_m16_native_repeated_latency'
    fig.savefig(stem.with_suffix('.png'), dpi=320, facecolor='white')
    fig.savefig(stem.with_suffix('.pdf'), facecolor='white')
    plt.close(fig)
    (OUT / 'manifest.json').write_text(json.dumps({
        'topology': 'M16', 'nodes': 64, 'metric': METRIC,
        'definition': 'TB-reported offer_to_tail_mean_ns, unchanged; not reinterpreted as per-original last-destination completion',
        'error_bars': 'sample standard deviation across three seeds',
        'warmup_original_events': 100, 'measurement_original_events': 1000,
        'seeds': SEEDS, 'sources': sources, 'summary': records,
    }, indent=2), encoding='utf-8')
    print(json.dumps(records, indent=2))
    print(stem.with_suffix('.pdf'))


if __name__ == '__main__':
    main()
