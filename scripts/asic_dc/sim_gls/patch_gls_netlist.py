#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Sim-only netlist patch for post-synth GLS smoke.

Modes:
  func     — fixed-priority Mutex #(0.1) + DelayElement #(1.0)
  cmr_func — skewed state-holding Mutex + DelayElement #(1.0)
  sdf      — identity copy: keep mapped Mutex ND2/INV + DEL* for full gate-level SDF

Does not modify DC production *_post.v; writes a separate destination file.
Compatible with older cluster Python 2/3.
"""
from __future__ import print_function

import argparse
import re
import shutil
import sys

MUTEX_BODY = """  input req0, req1;
  output gnt0, gnt1;
  // Functional GLS only: deterministic resolution with a visible delay.
  // Stateful or cross-coupled Mutex models form an artificial event loop when
  // three instances are connected as the Fig.2 ring without SDF.  Physical
  // persistence/fairness remains covered by the untouched SDF netlist.
  assign #(0.1) gnt0 = req0;
  assign #(0.1) gnt1 = req1 & ~req0;
"""

CMR_MUTEX_BODY = """  input req0, req1;
  output gnt0, gnt1;
  // CMR functional GLS: retain mutex history while 10 ps asymmetry resolves
  // equal request arrival without imposing permanent requester priority.
  wire q0, q1;
  assign #(0.10) q0 = ~(req0 & q1);
  assign #(0.11) q1 = ~(req1 & q0);
  assign gnt0 = ~q0;
  assign gnt1 = ~q1;
"""

DELAY_BODY = """  input I;
  output Z;
  // sim-only: guarantee visible pulse width for async FF / ACG clocks
  assign #(1.0) Z = I;
"""

MUTEX_RE = re.compile(
    r"^module\s+(Mutex2(?:_\d+)?)\s*\(([^)]*)\)\s*;.*?^endmodule",
    re.MULTILINE | re.DOTALL,
)
DELAY_RE = re.compile(
    r"^module\s+(DelayElement_DelayValue\d+(?:_DelayUnitPs\d+)?(?:_\d+)?)\s*\(([^)]*)\)\s*;.*?^endmodule",
    re.MULTILINE | re.DOTALL,
)
def patch_text(text, mode):
    n_mutex = [0]
    n_delay = [0]

    mutex_body = CMR_MUTEX_BODY if mode == "cmr_func" else MUTEX_BODY

    def repl_mutex(m):
        n_mutex[0] += 1
        return "module %s ( %s );\n%sendmodule" % (m.group(1), m.group(2).strip(), mutex_body)

    def repl_delay(m):
        n_delay[0] += 1
        return "module %s ( %s );\n%sendmodule" % (m.group(1), m.group(2).strip(), DELAY_BODY)

    if mode in ("func", "cmr_func"):
        text = MUTEX_RE.sub(repl_mutex, text)
        text = DELAY_RE.sub(repl_delay, text)
    # sdf: identity — full gate-level Mutex + DEL*
    return text, n_mutex[0], n_delay[0]


def main():
    ap = argparse.ArgumentParser(description="Patch GLS netlist for func/sdf smoke")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument(
        "--mode",
        choices=("func", "cmr_func", "sdf"),
        default="func",
        help="func=fixed-priority; cmr_func=skewed mutex; sdf=identity gate-level",
    )
    args = ap.parse_args()
    if args.mode == "sdf":
        # SDF annotation is hierarchy/name sensitive.  Preserve the production
        # netlist byte-for-byte instead of normalizing newlines through text IO.
        shutil.copyfile(args.src, args.dst)
        print("mode=sdf patched_mutex_modules=0 patched_delay_modules=0 dst=%s" % args.dst)
        return 0
    with open(args.src, "r") as f:
        text = f.read()
    new, nm, nd = patch_text(text, args.mode)
    with open(args.dst, "w") as f:
        f.write(new)
    print(
        "mode=%s patched_mutex_modules=%d patched_delay_modules=%d dst=%s"
        % (args.mode, nm, nd, args.dst)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
