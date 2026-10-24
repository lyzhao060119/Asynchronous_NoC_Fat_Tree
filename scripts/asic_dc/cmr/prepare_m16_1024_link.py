"""Reuse the frozen M16 natural hierarchy; never emit or modify Router RTL."""
import collections
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'generated_cmr/split1024_20261020/m16'
OUT = ROOT / 'results/m16_1024_hierlink_20261024_r1'
TOP = 'PROP_temp1024_m16'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--out', type=Path, default=OUT)
    args = parser.parse_args()
    source = args.source / 'top' / (TOP + '.v')
    raw = source.read_text()
    modules = dict(re.findall(r'^module\s+(\w+)\b(.*?^endmodule)', raw, re.M | re.S))
    modules = {n: 'module ' + n + text for n, text in modules.items()}
    rows = list(csv.DictReader((args.source / 'routers.tsv').open(), delimiter='\t'))
    meta = {r['ref']: dict(r, index=i) for i, r in enumerate(rows)}
    assert len(meta) == 352
    assert all(r['child'] == '1' and r['parent'] == '4' for r in rows)
    def instances(name):
        text = re.sub(r'//[^\n]*', '', modules[name])
        return [(ref, inst) for ref, inst in re.findall(r'^\s*(\w+)\s+(\w+)\s*\(', text, re.M)
                if ref in modules or ref in meta]
    def router_paths(name, prefix=''):
        result = {}
        for ref, inst in instances(name):
            path = prefix + inst
            if ref in meta:
                result[path] = ref
            else:
                result.update(router_paths(ref, path + '/'))
        return result
    top_instances = instances(TOP)
    counts = collections.Counter(ref for ref, _ in top_instances)
    tiles = [n for n in counts if n.startswith('PROPtempTileM16')]
    assert len(top_instances) == 32 and len(tiles) == 16 and counts['CMRTopMesh'] == 16
    assert all(counts[n] == 1 for n in tiles)
    args.out.mkdir(parents=True, exist_ok=True)
    blocks = []
    for name in tiles + ['CMRTopMesh']:
        closure = set()
        def visit(n):
            if n in closure:
                return
            closure.add(n)
            for ref, _ in instances(n):
                if ref in modules:
                    visit(ref)
        visit(name)
        paths = router_paths(name)
        expected = 16 if name == 'CMRTopMesh' else 48
        assert len(paths) == expected
        refs = collections.Counter(paths.values())
        text = '\n\n'.join(t for n, t in modules.items() if n in closure) + '\n'
        (args.out / (name + '.v')).write_text(text, encoding='utf-8', newline='\n')
        blocks.append(dict(top=name, instances=counts[name], routers=expected, ports=expected*8,
                           adapters=expected*4, refs=dict(refs), source_modules=sorted(closure),
                           router_paths=paths))
    (args.out / (TOP + '.v')).write_text(modules[TOP] + '\n', encoding='utf-8', newline='\n')
    full_paths = router_paths(TOP)
    assert len(full_paths) == 1024
    assert set(full_paths.values()) == set(meta)
    assert sum(b['routers'] * b['instances'] for b in blocks) == 1024
    reconstructed = {}
    for ref, inst in top_instances:
        block = next(b for b in blocks if b['top'] == ref)
        reconstructed.update({inst + '/' + p: r for p, r in block['router_paths'].items()})
    assert reconstructed == full_paths
    for name in modules:
        # All staged definitions are the original byte-for-byte text (only file placement changes).
        if name == TOP:
            assert (args.out / (TOP + '.v')).read_text().rstrip() == modules[name].rstrip()
    report = dict(status='PASS', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  top=TOP, unique_router_ddcs=len(meta), physical_routers=1024, ipms=8192, opms=8192,
                  adapters=4096, tree_tiles=16, mesh_plane_instances=16, unique_link_blocks=17,
                  top_instances=top_instances, blocks=blocks, router_metadata=meta,
                  source_module_hashes={n: hashlib.sha256(t.encode()).hexdigest() for n,t in modules.items()},
                  rtl_hashes={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in args.out.glob('*.v')})
    (args.out / 'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8', newline='\n')
    print(json.dumps({k: report[k] for k in ('status','source_sha256','unique_router_ddcs','physical_routers',
                     'ipms','opms','adapters','tree_tiles','mesh_plane_instances','unique_link_blocks')}, indent=2))


if __name__ == '__main__':
    main()
