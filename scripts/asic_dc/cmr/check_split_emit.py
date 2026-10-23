"""Audit a split emission bundle without loading a monolithic network RTL."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


def audit(root: Path):
    rows = list(csv.DictReader((root / 'routers.tsv').open(), delimiter='\t'))
    assert rows and len({r['ref'] for r in rows}) == len(rows)
    top_files = list((root / 'top').glob('*.v'))
    text = '\n'.join(p.read_text() for p in top_files)
    refs = re.findall(r'\b(CMRRouter_split_\w+)\s+external\s*\(', text)
    assert set(refs) == {r['ref'] for r in rows}, 'top/catalog mismatch'
    assert len(refs) == len(rows), 'duplicate unique kernel wrapper'
    complete, missing, hashes = [], [], {}
    for row in rows:
        ref = row['ref']
        folder = root / 'children' / ref
        path = folder / (ref + '.v')
        if not (folder / 'EMIT_PASS').exists() or not path.exists():
            missing.append(ref)
            continue
        body = path.read_text()
        module = re.search(r'module\s+' + re.escape(ref) + r'\s*\((.*?)\);', body, re.S)
        inst = re.search(r'\b' + re.escape(ref) + r'\s+external\s*\((.*?)\n  \);', text, re.S)
        assert module and inst, ref
        ports = set(re.findall(r'\b(?:input|output)\s+(?:\[.*?\]\s*)?(\w+)', module[1]))
        connections = set(re.findall(r'\.(\w+)\(', inst[1]))
        assert ports == connections, (ref, ports ^ connections)
        for p in folder.iterdir():
            if p.is_file() and p.suffix == '.v':
                hashes[p.relative_to(root).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
        complete.append(ref)
    for p in top_files:
        hashes[p.relative_to(root).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    result = dict(unique=len(rows), completed=len(complete), missing=missing,
                  ports_validated=len(complete), hashes=hashes,
                  status='PASS' if not missing else 'INCOMPLETE')
    (root / 'audit.json').write_text(json.dumps(result, indent=2))
    print(json.dumps({k: v for k, v in result.items() if k not in ('hashes', 'missing')}))
    return not missing


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    raise SystemExit(0 if audit(args.root) else 1)
