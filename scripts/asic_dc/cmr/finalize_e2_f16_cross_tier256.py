#!/usr/bin/env python3
"""Write Round-4 archive stub / RESULTS for PROP_temp256 F16 cross-tier."""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
STATE = HERE / "results" / "e2_f16_cross_tier256" / "state.json"
RAW_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper256"
FIG_ROOT = REPO / "DATE paper" / "experiments" / "figures" / "paper256"


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw = RAW_ROOT / ("e2_f16_cross_tier256_%s" % stamp)
    fig = FIG_ROOT / ("e2_f16_cross_tier256_%s" % stamp)
    raw.mkdir(parents=True, exist_ok=True)
    fig.mkdir(parents=True, exist_ok=True)
    state = {}
    if STATE.is_file():
        state = json.loads(STATE.read_text(encoding="utf-8"))
    status = "SUBMITTED" if state.get("jobs") else "CASES_ONLY"
    (raw / "RESULTS.md").write_text(
        "\n".join(
            [
                "# 256-E2 F16 cross-tier Native vs Repeated",
                "",
                "Status: `%s`" % status,
                "Netlist: `%s`" % state.get("netlist", "20260914_prop_temp256_b8_hier_dc_06"),
                "Run: `%s`" % state.get("run_id", ""),
                "",
                "Destination distribution: 4+4+4+4 across tiles.",
                "Paper points: low / medium / high (Native + Repeated).",
                "",
                "Pull remote GLS CSVs after PASS, then plot completion latency",
                "and useful destination throughput (Fig.256-2).",
                "",
            ]
        ),
        encoding="utf-8",
    )
    (fig / "README.md").write_text(
        "# Fig.256-2 placeholder\n\nNative vs Repeated completion latency + useful throughput.\n",
        encoding="utf-8",
    )
    if state:
        (raw / "submit_state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("E2_F16_FINALIZE", status, raw, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
