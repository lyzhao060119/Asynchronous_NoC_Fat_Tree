#!/usr/bin/env python3
"""Pull tick1 E2 CSVs, archive, and plot Fig.256-2."""
from __future__ import annotations

import csv
import sys
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402

RUN = "20260915_tick1_cmr_e2_f16_cross_tier256"
NETLIST = "20260914_prop_temp256_b8_hier_dc_06"
REMOTE_ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RAW_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper256"
FIG_ROOT = REPO / "DATE paper" / "experiments" / "figures" / "paper256"
ORDER = ("low", "medium", "high")
LOAD_LABEL = {"low": "low (M5)", "medium": "med (M20)", "high": "high (M40)"}


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw = RAW_ROOT / ("e2_f16_cross_tier256_tick1_%s" % stamp)
    fig_dir = FIG_ROOT / ("e2_f16_cross_tier256_tick1_%s" % stamp)
    csv_dir = raw / "csv"
    csv_dir.mkdir(parents=True, exist_ok=True)
    fig_dir.mkdir(parents=True, exist_ok=True)

    client = connect_failover()
    try:
        client, listing = remote_run_failover(
            client, "ls -1 %s/results/%s/csv 2>/dev/null" % (REMOTE_ROOT, RUN)
        )
        names = [ln.strip() for ln in listing.splitlines() if ln.strip().endswith(".csv")]
        if len(names) < 6:
            raise SystemExit("expected 6 csv, got %d: %s" % (len(names), names))
        sftp = client.open_sftp()
        for name in names:
            sftp.get("%s/results/%s/csv/%s" % (REMOTE_ROOT, RUN, name), str(csv_dir / name))
            print("PULLED", name, flush=True)
        sftp.close()
        client, markers = remote_run_failover(
            client,
            "grep -RhE 'TB_RESULT (PASS|FAIL)' %s/logs/gls/%s 2>/dev/null | sort -u"
            % (REMOTE_ROOT, RUN),
        )
    finally:
        client.close()

    rows = []
    for path in sorted(csv_dir.glob("*.csv")):
        parts = path.name.replace(".csv", "").split("_")
        load = next(t for t in ORDER if t in parts)
        scheme = "native" if "native" in parts else "repeated"
        with path.open(encoding="utf-8", newline="") as fh:
            row = next(csv.DictReader(fh))
        rows.append(
            {
                "load": load,
                "scheme": scheme,
                "avg_lat": float(row["avg_packet_latency_ns"]),
                "p95_lat": float(row["p95_latency_ns"]),
                "thr": float(row["delivered_throughput"]),
                "delivered_pkts": int(row["delivered_packets"]),
                "pass_fail": row.get("pass_fail", ""),
            }
        )

    native = {r["load"]: r for r in rows if r["scheme"] == "native"}
    repeated = {r["load"]: r for r in rows if r["scheme"] == "repeated"}
    xs = list(range(len(ORDER)))
    fig, axes = plt.subplots(1, 2, figsize=(9.2, 3.6), constrained_layout=True)
    ax = axes[0]
    ax.plot(xs, [native[k]["avg_lat"] for k in ORDER], "o-", label="Native MC", color="#1f77b4")
    ax.plot(xs, [repeated[k]["avg_lat"] for k in ORDER], "s--", label="Repeated UC", color="#d62728")
    ax.set_xticks(xs, [LOAD_LABEL[k] for k in ORDER])
    ax.set_ylabel("Mean completion latency (ns)")
    ax.set_title("Fig.256-2a Completion latency (tick=1)")
    ax.grid(True, alpha=0.3)
    ax.legend(frameon=False)
    ax = axes[1]
    ax.plot(xs, [native[k]["thr"] for k in ORDER], "o-", label="Native MC", color="#1f77b4")
    ax.plot(xs, [repeated[k]["thr"] for k in ORDER], "s--", label="Repeated UC", color="#d62728")
    ax.set_xticks(xs, [LOAD_LABEL[k] for k in ORDER])
    ax.set_ylabel("Delivered throughput (MFlit/port/s)")
    ax.set_title("Fig.256-2b Useful delivery throughput")
    ax.grid(True, alpha=0.3)
    ax.legend(frameon=False)
    out_png = fig_dir / "fig256-2-f16-native-vs-repeated.png"
    out_pdf = fig_dir / "fig256-2-f16-native-vs-repeated.pdf"
    fig.savefig(out_png, dpi=160)
    fig.savefig(out_pdf)
    plt.close(fig)

    with (fig_dir / "summary.csv").open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=["load", "scheme", "avg_lat_ns", "p95_lat_ns", "delivered_throughput", "pass_fail"],
        )
        w.writeheader()
        for r in rows:
            w.writerow(
                {
                    "load": r["load"],
                    "scheme": r["scheme"],
                    "avg_lat_ns": r["avg_lat"],
                    "p95_lat_ns": r["p95_lat"],
                    "delivered_throughput": r["thr"],
                    "pass_fail": r["pass_fail"],
                }
            )

    readme = "\n".join(
        [
            "# Fig.256-2 (tick=1 restart)",
            "",
            "- CASE_TICK_NS=1",
            "- Run: `%s`" % RUN,
            "- Netlist: `%s`" % NETLIST,
            "- Loads: M5 / M20 / M40 (PROP pre-sat calibrated from E1)",
            "- Destinations: 4+4+4+4 across tiles",
            "",
            "## Markers",
            "```",
            markers.strip(),
            "```",
            "",
        ]
    )
    (fig_dir / "README.md").write_text(readme, encoding="utf-8")
    (raw / "RESULTS.md").write_text(readme, encoding="utf-8")
    print("FIG256_2_OK", out_png, flush=True)
    print("E2_TICK1_ARCHIVE", raw, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
