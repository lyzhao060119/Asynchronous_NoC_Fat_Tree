"""Adapt independently emitted Router RTL to the existing gated DC driver."""
import csv
from collections import Counter
import json
import os
from pathlib import Path


def prepare(repo, bundle):
    root = repo / bundle
    audit = json.loads((root / 'audit.json').read_text())
    assert audit['status'] == 'PASS'
    # The bundle is uploaded and hash checked by launch_split1024_dc.py.
    wide = root.name == 'wide_tree64'
    m16 = root.name == 'm16'
    top = 'CMRWideTree64' if wide else ('PROP_temp1024_m16' if m16 else 'CMRMeshNoC')
    remote_base = 'rtl/split/' + root.name
    rows = list(csv.DictReader((root / 'routers.tsv').open(), delimiter='\t'))
    if wide:
        observed = Counter((int(r['level']), int(r['child']), int(r['parent'])) for r in rows)
        assert observed == {(1, 1, 4): 16, (2, 4, 16): 4, (3, 16, 16): 1}, observed
        assert all(r['mesh'] == 'false' for r in rows), 'wide tree contains Mesh router'
    jobs = []
    for r in rows:
        c, p = int(r['child']), int(r['parent'])
        jobs.append(dict(ref=r['ref'], expected_ports=4*c+p,
                         expected_adapters=(4*c if p > 1 else 0)+(12*c+4*p if c > 1 else 0),
                         remote_dut=f"{remote_base}/children/{r['ref']}/{r['ref']}.v"))
    return dict(generated=root/'top', dut_name=top+'.v', top=top,
                remote_dut=f'{remote_base}/top/{top}.v', jobs=jobs, files={},
                nodes=64 if wide else 1024, large=True, net_kind='prop_temp' if m16 or wide else 'fm',
                expected=dict(routers=21 if wide else 1024,
                              ports=336 if wide else (8192 if m16 else 5120),
                              adapters=896 if wide else (4096 if m16 else 0)))
