#!/usr/bin/env python3
"""Extract the active Sync B8 router/plane path from the packet-665 VCD."""
from __future__ import annotations
import argparse, re
from collections import defaultdict
from pathlib import Path

KEEP = re.compile(
    r"syncPropL1_q[23]_i2_io_outputs_parent_[0-3]_hs_valid|"
    r"syncPropL1_q3_i2_io_inputs_parent_[0-3]_hs_ready|"
    r"syncPropL2_q[23]_k[0-3]_io_outputs_(parent_[0-3]|child_1_0)_hs_valid|"
    r"syncPropL3_j[0-3]_k[0-3]_io_outputs_child_[01]_0_hs_valid"
)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('vcd',type=Path); args=ap.parse_args()
    names=defaultdict(list); in_header=True; now=0; rises=[]; values={}
    with args.vcd.open(encoding='utf-8',errors='replace') as f:
        for line in f:
            line=line.rstrip('\n')
            if in_header:
                if line.startswith('$var '):
                    p=line.split()
                    if len(p)>=6 and KEEP.search(p[4]): names[p[3]].append(p[4])
                elif '$enddefinitions' in line: in_header=False
                continue
            if line.startswith('#'):
                now=int(line[1:]); continue
            if line and line[0] in '01xz':
                val,code=line[0],line[1:]
                if code in names and val=='1' and values.get(code)!='1':
                    for name in names[code]: rises.append((now,name))
                values[code]=val
    for t,name in rises:
        if 45000 <= t <= 75000: print(f'{t} ps,{name}')

if __name__=='__main__': main()
