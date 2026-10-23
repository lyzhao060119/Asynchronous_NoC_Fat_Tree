"""Independently validate CSV aggregation and export compact final tables."""
import csv,json,statistics,math,hashlib
from pathlib import Path

ROOT=Path('results/formal256_20261019_r3_checks')
def read(p):
    with p.open(newline='') as f:return list(csv.DictReader(f))
def write(p,rows):
    with p.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def main():
    rows=read(ROOT/'summary/raw_metrics.csv');means=read(ROOT/'summary/three_seed_means.csv')
    assert len(rows)==552 and all(r['valid']=='True' for r in rows)
    keys=[tuple(r[k] for k in ('design','benchmark','seed','load','mode')) for r in rows]
    assert len(set(keys))==552
    for m in means:
        rs=[r for r in rows if all(r[k]==m[k] for k in ('design','benchmark','load','mode'))]
        assert len(rs)==3 and {r['seed'] for r in rs}=={'202701','202702','202703'}
        for col in ('mean_last_destination_ns','mean_first_destination_ns','mean_destination_ns','original_transactions_s','delivered_mflit_port_s','delivery_fraction','copy_backlog'):
            vals=[float(r[col]) for r in rs]
            assert math.isclose(float(m[col+'_mean']),statistics.mean(vals),rel_tol=1e-12,abs_tol=1e-9)
            assert math.isclose(float(m[col+'_std']),statistics.stdev(vals),rel_tol=1e-12,abs_tol=1e-9)
    assert len(means)==184
    comparison=[]
    for rep in [m for m in means if m['mode']=='repeated']:
        nat=next(m for m in means if m['mode']=='native' and all(m[k]==rep[k] for k in ('design','benchmark','load')))
        comparison.append(dict(design=rep['design'],benchmark=rep['benchmark'],load_mflit_port_s=rep['load'],
          native_latency_ns=nat['mean_last_destination_ns_mean'],repeated_latency_ns=rep['mean_last_destination_ns_mean'],
          native_latency_std_ns=nat['mean_last_destination_ns_std'],repeated_latency_std_ns=rep['mean_last_destination_ns_std'],
          latency_speedup=float(rep['mean_last_destination_ns_mean'])/float(nat['mean_last_destination_ns_mean']),
          native_copy_throughput_mflit_port_s=nat['delivered_mflit_port_s_mean'],repeated_copy_throughput_mflit_port_s=rep['delivered_mflit_port_s_mean'],
          native_window_delivery=nat['delivery_fraction_mean'],repeated_window_delivery=rep['delivery_fraction_mean'],seeds=3))
    write(ROOT/'summary/native_repeated_comparison.csv',comparison)
    area=[read(ROOT/f'area/{d}/area.csv')[0] for d in ('Mesh256','M16_256')]
    assert all(float(r['cell_area_um2'])>0 for r in area)
    write(ROOT/'summary/area_comparison.csv',area)
    coverage=[]
    for d in ('Mesh256','M16_256'):
        for b in ('TOPO-UR','MULTICAST10-AABB','ALL-MULTICAST-AABB'):
            rs=[r for r in rows if r['design']==d and r['benchmark']==b and r['mode']=='native']
            assert len(rs)==90
            coverage.append(dict(design=d,benchmark=b,passed=len(rs),expected=90,eligible_loads=sum(m['latency_curve_eligible']=='True' for m in means if m['design']==d and m['benchmark']==b and m['mode']=='native')))
    write(ROOT/'summary/scan_coverage.csv',coverage)
    audit=dict(records=552,unique_records=552,mean_groups=184,seeds_per_group=3,aggregation_check='PASS')
    (ROOT/'summary/local_aggregation_audit.json').write_text(json.dumps(audit,indent=2))
    print(json.dumps(dict(audit=audit,comparisons=comparison,area=area),indent=2))
if __name__=='__main__':main()
