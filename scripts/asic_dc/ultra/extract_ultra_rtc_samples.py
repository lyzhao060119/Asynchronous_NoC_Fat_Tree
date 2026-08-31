#!/usr/bin/env python3
"""Convert SDF boundary timing observations into conservative RTC CSV rows.

The input uses TB_RTC_SAMPLE records emitted by the simulation-only router TB.
An RTM is calculated only when data/control share the same ReqIn reference.
Static STA reports remain segment evidence; they are not max-max substituted
for this continuous-time bundled-data comparison.
"""
from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

FIELDS = [
    "rtc_id", "phase", "flit_index", "data_start_ns", "data_end_ns",
    "ctrl_start_ns", "ctrl_end_ns", "Tdata_min_ps", "Tdata_max_ps",
    "Tctrl_min_ps", "Tctrl_max_ps", "margin_ps", "RTM_pct", "target_RTM_pct",
    "shortfall_ps", "overdesign_ps", "data_path_min_ps", "data_path_max_ps",
    "status", "source_log",
]
LINE = re.compile(r"TB_RTC_SAMPLE\s+(.*)")
KV = re.compile(r"(\w+)=([^\s]+)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("csv", type=Path)
    parser.add_argument("--target-rtm", type=float, default=5.0)
    args = parser.parse_args()
    rows = []
    for text in args.log.read_text(encoding="utf-8", errors="replace").splitlines():
        match = LINE.search(text)
        if not match:
            continue
        d = dict(KV.findall(match.group(1)))
        try:
            data_path = float(d["data_path_ns"]) * 1000.0
            tctrl = float(d["tctrl_ns"]) * 1000.0
        except (KeyError, ValueError):
            continue
        visible = float(d["tdata_visible_ns"]) * 1000.0
        # Both values use ReqIn as the shared reference: correctness is the
        # earliest control event versus the latest data event.  The physical
        # DataIn->DataOut delay remains in separate columns; for transparent
        # Body/Tail it must not be misreported as a negative physical delay.
        margin = tctrl - visible
        comparable = visible > 0.0
        required = visible * (1.0 + args.target_rtm / 100.0) if comparable else 0.0
        rows.append({
            "rtc_id": d.get("rtc", "OPM_V2_CHILD0_PARENT"),
            "phase": d.get("phase", "unknown"),
            "flit_index": d.get("flit", "unknown"),
            "data_start_ns": d.get("datain_ns", ""), "data_end_ns": d.get("data_ns", ""),
            "ctrl_start_ns": d.get("reqin_ns", ""), "ctrl_end_ns": d.get("reqout_ns", ""),
            # A single SDF execution is one physical sample.  These fields
            # are relative-to-Req paired timing, not raw physical data delay.
            "Tdata_min_ps": f"{visible:.3f}", "Tdata_max_ps": f"{visible:.3f}",
            "Tctrl_min_ps": f"{tctrl:.3f}", "Tctrl_max_ps": f"{tctrl:.3f}",
            "margin_ps": f"{margin:.3f}",
            "RTM_pct": f"{(100.0 * margin / visible) if comparable else 0.0:.3f}",
            "target_RTM_pct": f"{args.target_rtm:.3f}",
            "shortfall_ps": f"{max(0.0, required - tctrl):.3f}",
            "overdesign_ps": f"{max(0.0, margin - (visible * args.target_rtm / 100.0)) if comparable else 0.0:.3f}",
            "data_path_min_ps": f"{data_path:.3f}", "data_path_max_ps": f"{data_path:.3f}",
            "status": "MEASURED_SINGLE_CORNER" if comparable else "DATA_PRECEDES_REQ",
            "source_log": str(args.log),
        })
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader(); writer.writerows(rows)
    print(f"RTC_SAMPLES={len(rows)} output={args.csv}")


if __name__ == "__main__":
    main()
