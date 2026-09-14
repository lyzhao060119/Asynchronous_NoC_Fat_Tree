#!/usr/bin/env python3
"""Build step-D data-only max-delay targets from frozen step-C STA.

Scale is 0.95 of each catalog Tdata_max.  CMR-AR-01 was not measured in
step C (Tcl 0 = measure on seed).  TCF-RD-01 uses the baseline DC
SlotData->Data_out Tdata_max.  CMR-FIFO-01 is N/A on CircularFIFO.
This script does not write production SDC.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def _round_ns(value: float) -> float:
    return round(value, 3)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sta-summary",
        type=Path,
        default=Path("docs/timing_baselines/20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta_summary.json"),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("scripts/asic_dc/cmr/20260827_cmr_cfifo_datapath_r1_targets.tcl"),
    )
    parser.add_argument("--scale", type=float, default=0.95)
    parser.add_argument(
        "--rd01-tdata",
        type=float,
        default=0.295973,
        help="Baseline TCF-RD-01 SlotData->Data_out Tdata_max (ns)",
    )
    args = parser.parse_args()
    if not 0.0 < args.scale <= 1.0:
        raise SystemExit("scale must be in (0, 1]")

    summary = json.loads(args.sta_summary.read_text(encoding="utf-8"))
    ids = summary["ids"]
    mat = float(ids["CMR-RCU-01"]["tdata_max_ns"])
    opm = float(ids["CMR-OPM-01"]["tdata_max_ns"])
    rd01 = float(args.rd01_tdata)
    targets = {
        "scale": args.scale,
        "baseline_run": summary.get("baseline"),
        "sta_run": summary.get("run_id"),
        "baseline_tdata_max_ns": {
            "CMR-RCU-01": mat,
            "CMR-OPM-01": opm,
            "TCF-RD-01": rd01,
        },
        "targets_ns": {
            "MAT": _round_ns(mat * args.scale),
            "OPM": _round_ns(opm * args.scale),
            "AR": 0.0,
            "FIFO": _round_ns(rd01 * args.scale),
        },
        "measure_on_seed": ["CMR-AR-01", "TCF-WD-01"],
        "near_floor_ns": 0.020,
    }

    lines = [
        "# Generated; do not edit. Step-D datapath-only max-delay targets.",
        "# Source: %s (%s)." % (args.sta_summary.as_posix(), summary.get("run_id")),
        "# TCF-RD-01 FIFO target is 0.95 * baseline SlotData->Data_out Tdata_max.",
        "set CMR_DP_TARGET_SCALE %.6f" % args.scale,
        "set CMR_DP_MAT_NS %.3f" % targets["targets_ns"]["MAT"],
        "set CMR_DP_OPM_NS %.3f" % targets["targets_ns"]["OPM"],
        "set CMR_DP_AR_NS %.3f" % targets["targets_ns"]["AR"],
        "set CMR_DP_FIFO_NS %.3f" % targets["targets_ns"]["FIFO"],
        "set CMR_DP_NEAR_FLOOR_NS %.3f" % targets["near_floor_ns"],
        "",
    ]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(lines), encoding="utf-8")
    args.out.with_suffix(args.out.suffix + ".json").write_text(
        json.dumps(targets, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(targets, indent=2))


if __name__ == "__main__":
    main()
