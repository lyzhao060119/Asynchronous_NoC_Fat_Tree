#!/usr/bin/env python3
"""Create the Phase-3 data-only target Tcl from frozen RTC measurements."""
from __future__ import annotations
import argparse, csv, json, re
from collections import defaultdict
from pathlib import Path

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--rtc-csv", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--scale", type=float, default=0.95)
    p.add_argument("--datapath-log", required=True)
    args = p.parse_args()
    if not 0.0 < args.scale <= 1.0:
        raise SystemExit("scale must be in (0, 1]")
    rows = list(csv.DictReader(Path(args.rtc_csv).open(encoding="utf-8")))
    opm_max_ps = max(float(r["data_path_max_ps"]) for r in rows)
    samples = {}
    pattern = re.compile(r"TB_DATAPATH_SAMPLE rtc=(\S+) .*tdata_ps=([0-9.]+)")
    for line in Path(args.datapath_log).read_text(encoding="utf-8", errors="replace").splitlines():
        m = pattern.search(line)
        if m: samples[m.group(1)] = float(m.group(2))
    required = {"V1_CAPTURE", "PRS_DESCRIPTOR", "HEADCAP_DESCRIPTOR", "ATOMIC_DESCRIPTOR"}
    missing = required - samples.keys()
    if missing: raise SystemExit("missing datapath samples: " + ",".join(sorted(missing)))
    targets = {
        "OPM": round(opm_max_ps * args.scale / 1000.0, 3),
        "V1": round(samples["V1_CAPTURE"] * args.scale / 1000.0, 3),
        "PRS": round(samples["PRS_DESCRIPTOR"] * args.scale / 1000.0, 3),
        "HEADCAP": round(samples["HEADCAP_DESCRIPTOR"] * args.scale / 1000.0, 3),
        "ATOMIC": round(samples["ATOMIC_DESCRIPTOR"] * args.scale / 1000.0, 3),
    }
    text = [
        "# Generated; do not edit. Phase-3 datapath-only targets.",
        "set ULTRA_DP_TARGET_SCALE %.6f" % args.scale,
    ]
    for name, value in targets.items():
        text.append("set ULTRA_DP_%s_NS %.3f" % (name, value))
    Path(args.out).write_text("\n".join(text) + "\n", encoding="utf-8")
    Path(str(args.out) + ".json").write_text(json.dumps({"scale": args.scale, "targets_ns": targets, "baseline_ps": {**samples, "OPM_V2": opm_max_ps}}, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__": main()
