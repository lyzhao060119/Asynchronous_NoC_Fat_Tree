#!/usr/bin/env python3
"""Aggregate immutable paper64 PT-PX points and render the two-panel figure."""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    rows = []
    for metric in sorted(args.raw.glob("*/m*/power/metrics.csv")):
        design, load_dir = metric.parts[-4], metric.parts[-3]
        row = next(csv.DictReader(metric.open(encoding="utf-8", newline="")))
        activity = metric.parents[1] / "activity" / "result.csv"
        traffic = next(csv.DictReader(activity.open(encoding="utf-8", newline="")))
        row.update({"design": design, "load_mflit_per_port_s": int(load_dir[1:]),
                    "offered_mflit_per_port_s": traffic["offered_mflit_port_s"],
                    "delivered_mflit_per_port_s": traffic["delivered_mflit_port_s"],
                    "backlog_flits": traffic["measurement_backlog_flits"],
                    "activity_metrics_sha256": __import__("hashlib").sha256(activity.read_bytes()).hexdigest(),
                    "power_metrics_sha256": __import__("hashlib").sha256(metric.read_bytes()).hexdigest()})
        rows.append(row)
    if len(rows) != 24:
        raise SystemExit("expected 24 power points, got %d" % len(rows))
    args.out.mkdir(parents=True, exist_ok=True)
    fields = list(rows[0])
    with (args.out / "power_metrics.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields); writer.writeheader(); writer.writerows(rows)
    import matplotlib.pyplot as plt
    colors = {"FM64": "#2878b5", "PFAT64": "#c55a11"}
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), constrained_layout=True)
    for design in ("FM64", "PFAT64"):
        data = sorted((r for r in rows if r["design"] == design), key=lambda r: int(r["load_mflit_per_port_s"]))
        x = [int(r["load_mflit_per_port_s"]) for r in data]
        color = colors[design]
        axes[0].plot(x, [float(r["dynamic_w"]) * 1e3 for r in data], "o-", color=color, label=design + " dynamic")
        axes[0].plot(x, [float(r["leakage_w"]) * 1e3 for r in data], "--", color=color, label=design + " leakage")
        axes[0].plot(x, [float(r["total_w"]) * 1e3 for r in data], "s-", color=color, alpha=.55, label=design + " total")
        axes[1].plot(x, [float(r["energy_dynamic_j_per_delivered_flit"]) * 1e12 for r in data], "o-", color=color, label=design + " dynamic")
        axes[1].plot(x, [float(r["energy_total_j_per_delivered_flit"]) * 1e12 for r in data], "s--", color=color, label=design + " total")
        for r in data:
            if int(r["backlog_flits"]) > 0:
                axes[1].annotate("backlog", (int(r["load_mflit_per_port_s"]), float(r["energy_total_j_per_delivered_flit"]) * 1e12), fontsize=7, rotation=35)
    axes[0].set(xlabel="Offered load (MFlit/port/s)", ylabel="Power (mW)", title="Time-based post-synthesis power")
    axes[1].set(xlabel="Offered load (MFlit/port/s)", ylabel="Energy / delivered flit (pJ)", title="Delivered-flit energy")
    for axis in axes: axis.grid(alpha=.25); axis.legend(fontsize=7, ncol=2)
    fig.savefig(args.out / "mesh64-pfat64-power.png", dpi=220)
    fig.savefig(args.out / "mesh64-pfat64-power.pdf")
    (args.out / "plot_manifest.json").write_text(json.dumps({"raw": str(args.raw), "rows": len(rows), "source": "PT-PX time-based MAXIMUM-SDF measurement-only VCD"}, indent=2) + "\n", encoding="utf-8")
    print("PAPER64_POWER_AGGREGATE_PASS rows=24 out=%s" % args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
