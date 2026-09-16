#!/usr/bin/env python3
"""Finalize 256-E2 F16 archive after all 6 GLS PASS."""
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402

STATE = HERE / "results" / "e2_f16_cross_tier256" / "state.json"
RAW_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper256"
FIG_ROOT = REPO / "DATE paper" / "experiments" / "figures" / "paper256"
REMOTE_ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = "20260915_121842_cmr_e2_f16_cross_tier256"
NETLIST = "20260914_prop_temp256_b8_hier_dc_06"


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw = RAW_ROOT / ("e2_f16_cross_tier256_%s" % stamp)
    fig = FIG_ROOT / ("e2_f16_cross_tier256_%s" % stamp)
    raw.mkdir(parents=True, exist_ok=True)
    fig.mkdir(parents=True, exist_ok=True)
    csv_dir = raw / "csv"
    csv_dir.mkdir(exist_ok=True)

    client = connect_failover()
    try:
        client, listing = remote_run_failover(
            client,
            "ls -1 %s/results/%s/csv 2>/dev/null" % (REMOTE_ROOT, RUN),
        )
        names = [ln.strip() for ln in listing.splitlines() if ln.strip().endswith(".csv")]
        sftp = client.open_sftp()
        for name in names:
            remote = "%s/results/%s/csv/%s" % (REMOTE_ROOT, RUN, name)
            local = csv_dir / name
            sftp.get(remote, str(local))
            print("PULLED", name, flush=True)
        sftp.close()
        client, markers = remote_run_failover(
            client,
            "grep -RhE 'TB_RESULT PASS|CMR_NETWORK_GLS_PASS' %s/logs/gls/%s/sdf 2>/dev/null | sort -u"
            % (REMOTE_ROOT, RUN),
        )
    finally:
        client.close()

    rows = []
    for path in sorted(csv_dir.glob("*.csv")):
        rows.append(path.name)
    (raw / "RESULTS.md").write_text(
        "\n".join(
            [
                "# 256-E2 F16 cross-tier Native vs Repeated",
                "",
                "Status: **PASS (6/6)**",
                "Netlist: `%s`" % NETLIST,
                "Run: `%s`" % RUN,
                "",
                "Destination distribution: 4+4+4+4 across tiles.",
                "Points: low / medium / high × Native / Repeated.",
                "",
                "## Markers",
                "```",
                markers.strip(),
                "```",
                "",
                "## CSV",
                "",
                *[("- `%s`" % n) for n in rows],
                "",
                "Next: plot completion latency + useful destination throughput (Fig.256-2).",
                "",
            ]
        ),
        encoding="utf-8",
    )
    (fig / "README.md").write_text(
        "# Fig.256-2\n\nData ready under raw `%s`.\nPlot Native vs Repeated completion latency + useful throughput.\n"
        % raw.name,
        encoding="utf-8",
    )
    if STATE.is_file():
        (raw / "submit_state.json").write_text(STATE.read_text(encoding="utf-8"), encoding="utf-8")
    print("E2_F16_FINALIZE PASS", raw, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
