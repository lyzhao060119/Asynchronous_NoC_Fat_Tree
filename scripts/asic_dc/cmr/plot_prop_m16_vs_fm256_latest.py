#!/usr/bin/env python3
"""Plot the latest PROP-M16 diagnostic scan against accepted FlatMesh256 GLS."""
from __future__ import annotations

import csv
import json
import re
from collections import defaultdict, deque
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt


REPO = Path(__file__).resolve().parents[3]
RAW = REPO / "DATE paper" / "experiments" / "raw" / "paper256"
PROP = RAW / "prop_temp256_m16_unique_20260917_193541" / "cases"
FM = RAW / "m16_vs_fm256_flit_compare_20260917"
LOADS = (40, 60, 80, 100, 120, 140, 160, 180, 200, 240, 280, 320, 400)


def percentile(values: list[float], pct: int) -> float:
    ordered = sorted(values)
    rank = (pct * len(ordered) + 99) // 100
    return ordered[max(0, min(len(ordered) - 1, rank - 1))]


def one_row(path: Path) -> dict[str, str]:
    with path.open(newline="", encoding="utf-8") as handle:
        return next(csv.DictReader(handle))


def prop_row(load: int) -> dict[str, object]:
    case = PROP / f"TOPO-UR_n256_s202701_m{load}_PROP_temp256_m16_top0"
    result = one_row(case / "result.csv")
    with (case / "flit_latency.csv").open(newline="", encoding="utf-8") as handle:
        values = [float(row["lat_ns"]) for row in csv.DictReader(handle)]
    return {
        "design": "PROP-M16",
        "load": load,
        "status": result["pass_fail"],
        "measurement_packets": 10000,
        "packet_mean_ns": float(result["avg_packet_latency_ns"]),
        "packet_p95_ns": float(result["p95_latency_ns"]),
        "prop_flit_rows_diagnostic": len(values),
        "prop_flit_mean_ns_diagnostic": sum(values) / len(values),
        "delivered_mflit_s_port": float(result["delivered_throughput"]) * 1000.0 / 256.0,
        "unexpected_flits": int(result["unexpected_flits"]),
        "missing_flits": int(result["missing_expected_flits"]),
        "source": str(case),
    }


def fm_row(load: int) -> dict[str, object]:
    case_path = FM / f"fm_m{load}_case.case"
    result_path = FM / f"fm_m{load}_result.csv"
    events_path = FM / f"fm_m{load}_events.csv"
    result = one_row(result_path)
    return {
        "design": "FlatMesh256",
        "load": load,
        "status": result["pass_fail"],
        "measurement_packets": 10000,
        "packet_mean_ns": float(result["avg_packet_latency_ns"]),
        "packet_p95_ns": float(result["p95_latency_ns"]),
        "prop_flit_rows_diagnostic": "",
        "prop_flit_mean_ns_diagnostic": "",
        "delivered_mflit_s_port": float(result["delivered_throughput"]) * 1000.0 / 256.0,
        "unexpected_flits": int(result["unexpected_flits"]),
        "missing_flits": int(result["missing_expected_flits"]),
        "source": str(events_path),
    }


def main() -> None:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = REPO / "DATE paper" / "experiments" / "figures" / "paper256" / f"prop_m16_vs_flatmesh256_{stamp}"
    out.mkdir(parents=True)
    rows = [row for load in LOADS for row in (prop_row(load), fm_row(load))]
    with (out / "data.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    fig, (ax_t, ax_l) = plt.subplots(1, 2, figsize=(7.15, 2.75), constrained_layout=True)
    colors = {"PROP-M16": "#d55e00", "FlatMesh256": "#0072b2"}
    for design in ("FlatMesh256", "PROP-M16"):
        data = [row for row in rows if row["design"] == design]
        passed = [row for row in data if row["status"] == "PASS"]
        failed = [row for row in data if row["status"] != "PASS"]
        color = colors[design]
        ax_t.plot([r["load"] for r in data], [r["delivered_mflit_s_port"] for r in data],
                  color=color, lw=1.6, alpha=0.9, label=design)
        ax_t.scatter([r["load"] for r in passed], [r["delivered_mflit_s_port"] for r in passed],
                     color=color, s=25, marker="o", zorder=3)
        ax_t.scatter([r["load"] for r in failed], [r["delivered_mflit_s_port"] for r in failed],
                     facecolors="white", edgecolors=color, s=31, marker="X", linewidths=1.2, zorder=4)
        ax_l.plot([r["load"] for r in data], [r["packet_mean_ns"] for r in data], color=color,
                  lw=1.6, label=f"{design} mean")
        ax_l.plot([r["load"] for r in data], [r["packet_p95_ns"] for r in data], color=color,
                  lw=1.25, ls="--", alpha=0.85, label=f"{design} p95")
        for metric in ("packet_mean_ns", "packet_p95_ns"):
            ax_l.scatter([r["load"] for r in passed], [r[metric] for r in passed],
                         color=color, s=18, marker="o", zorder=3)
            ax_l.scatter([r["load"] for r in failed], [r[metric] for r in failed],
                         facecolors="white", edgecolors=color, s=27, marker="X", linewidths=1.1, zorder=4)

    for ax in (ax_t, ax_l):
        ax.grid(True, which="major", color="#d9d9d9", lw=0.55)
        ax.set_xlabel("Offered load setpoint (Mflit/s/port)")
        ax.tick_params(labelsize=8)
    ax_t.set_ylabel("Delivered throughput (Mflit/s/port)")
    ax_l.set_ylabel("Packet latency (ns)")
    ax_t.set_title("(a) Throughput", fontsize=9)
    ax_l.set_title("(b) Mean and p95 latency", fontsize=9)
    ax_t.legend(frameon=False, fontsize=8, loc="lower right")
    ax_l.legend(frameon=False, fontsize=7, ncol=2, loc="upper left")
    fig.suptitle("256-node uniform random traffic (5-flit packets)", fontsize=10)
    fig.text(0.5, -0.035, "Filled circles: correctness PASS; open X: diagnostic FAIL (duplicate/unexpected flits).",
             ha="center", fontsize=7.5)
    for suffix in ("png", "pdf"):
        fig.savefig(out / f"prop-m16-vs-flatmesh256.{suffix}", dpi=300, bbox_inches="tight")
    plt.close(fig)

    manifest = {
        "loads": LOADS,
        "latency_definition": "native packet-level result.csv metrics",
        "cohort": "10000 measurement packets",
        "prop_archive": str(PROP.parent),
        "flatmesh_archive": str(FM),
        "pass_counts": {name: sum(r["status"] == "PASS" for r in rows if r["design"] == name)
                        for name in ("PROP-M16", "FlatMesh256")},
        "warning": "PROP diagnostic FAIL points contain duplicate/unexpected flits and are not paper-eligible. Old FlatMesh payload identity is not unique per flit, so flit-level latency is not cross-plotted.",
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(out)
    print("PLOT_PASS", manifest["pass_counts"])


if __name__ == "__main__":
    main()
