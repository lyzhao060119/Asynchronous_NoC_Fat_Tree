#!/usr/bin/env python3
"""Finalize 256-E1 three-DUT UR archive + Fig.256-1 after GLS PASS.

Pulls remote CSVs when available; otherwise writes a blocked RESULTS stub.
"""
from __future__ import annotations

import csv
import json
import os
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from cmr_frozen_run_ids import FROZEN_PROP_TEMP256_NETLIST_RUN_ID  # noqa: E402

RAW_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper256"
FIG_ROOT = REPO / "DATE paper" / "experiments" / "figures" / "paper256"
STATE = HERE / "results" / "e1_ur_three_dut256" / "state.json"


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw = RAW_ROOT / ("e1_ur_three_dut256_%s" % stamp)
    fig = FIG_ROOT / ("e1_ur_three_dut256_%s" % stamp)
    raw.mkdir(parents=True, exist_ok=True)
    fig.mkdir(parents=True, exist_ok=True)

    blocked = []
    for env, design in (
        ("CMR_PFAT_TEMP256_NETLIST", "PFAT_temp256"),
        ("CMR_FM256_NETLIST", "FM256"),
    ):
        if not os.environ.get(env, "").strip():
            blocked.append(design)

    lines = [
        "# E1 three-DUT UR 256-node results",
        "",
        "Archive: `%s`" % raw.as_posix().split("asynchronous_fat_tree_multicast/")[-1],
        "Figures: `%s`" % fig.as_posix().split("asynchronous_fat_tree_multicast/")[-1],
        "",
        "Injection: `v3_exp_header_asap_body`, seed 202701.",
        "PROP_temp256 frozen netlist: `%s`." % FROZEN_PROP_TEMP256_NETLIST_RUN_ID,
        "",
    ]
    if blocked:
        lines += [
            "## Status: BLOCKED_PENDING_BASELINE_DC",
            "",
            "Missing frozen netlists for: " + ", ".join(blocked),
            "",
            "Round-2 auth gate: see `DATE paper/experiments/setup/256node_round_plan_20260915.md`.",
            "After DC PASS, set `CMR_PFAT_TEMP256_NETLIST` / `CMR_FM256_NETLIST`, rerun",
            "`run_e1_ur_three_dut256.py all`, then re-run this finalize script.",
            "",
        ]
        status = "BLOCKED_PENDING_BASELINE_DC"
    else:
        lines += [
            "## Status: READY_FOR_CSV_PULL",
            "",
            "Netlists present in env; pull remote GLS CSVs next.",
            "",
        ]
        status = "READY_FOR_CSV_PULL"

    if STATE.is_file():
        lines += ["## Submit state", "", "```json", STATE.read_text(encoding="utf-8"), "```", ""]

    (raw / "RESULTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (fig / "README.md").write_text(
        "# Fig.256-1 placeholder\n\nThroughput + pre-sat latency after three-DUT GLS.\n",
        encoding="utf-8",
    )
    summary = raw / "saturation_summary.csv"
    with summary.open("w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(
            [
                "design",
                "peak_delivered_mflit_per_port_s",
                "near_lossless_load_setpoint",
                "status",
            ]
        )
        w.writerow(["PROP_temp256", "", "", status])
        w.writerow(["PFAT_temp256", "", "", status])
        w.writerow(["FM256", "", "", status])

    print("E1_UR256_FINALIZE", status, raw, flush=True)
    return 0 if not blocked else 2


if __name__ == "__main__":
    raise SystemExit(main())
