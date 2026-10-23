#!/usr/bin/env python3
"""Plot asynchronous 64-node benchmark curves from a frozen formal64 summary."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


DESIGNS = {
    "PROP_M16": ("Async M16", "#146C94", "o"),
    "FM64": ("Mesh64", "#D57A22", "s"),
    "PFAT64": ("PFAT64", "#428A4B", "^"),
}
BENCHMARKS = [
    ("TOPO-UR", "Uniform random"),
    ("TOPO-BC", "Bit complement"),
    ("HOTSPOT10", "Hotspot10"),
    ("MULTICAST5-AABB", "Multicast5"),
    ("MULTICAST10-AABB", "Multicast10"),
    ("MULTICAST-STATIC-AABB", "Multicast-static"),
    ("ALL-MULTICAST-AABB", "All-multicast"),
    ("ALL-BROADCAST", "All-broadcast"),
]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def plot(rows: list[dict[str, str]], output: Path, kind: str) -> None:
    fig, axs = plt.subplots(4, 2, figsize=(13.2, 15.2))
    for ax, (benchmark, title) in zip(axs.flat, BENCHMARKS):
        ax.set_title(title, fontsize=12, weight="semibold")
        for design, (label, color, marker) in DESIGNS.items():
            group = sorted(
                (row for row in rows if row["design"] == design and row["benchmark"] == benchmark),
                key=lambda row: int(row["load"]),
            )
            key = ("offer_to_tail_mean_ns_mean" if kind == "latency"
                   else "delivered_mflit_port_s_mean")
            group = [row for row in group if row.get(key, "")]
            if not group:
                continue
            eligible = [row for row in group if row["latency_curve_eligible"] == "True"]
            pressure = [row for row in group if row["latency_curve_eligible"] != "True"]
            if eligible:
                ax.plot([int(row["load"]) for row in eligible],
                        [float(row[key]) for row in eligible],
                        color=color, marker=marker, markersize=3.2,
                        linewidth=1.55, label=label)
            if pressure:
                bridge = ([eligible[-1]] if eligible and
                          int(eligible[-1]["load"]) < int(pressure[0]["load"]) else [])
                segment = bridge + pressure
                ax.plot([int(row["load"]) for row in segment],
                        [float(row[key]) for row in segment],
                        color=color, linestyle="--", linewidth=1.2,
                        label=label if not eligible else None)
                ax.scatter([int(row["load"]) for row in pressure],
                           [float(row[key]) for row in pressure],
                           s=25, marker=marker, facecolors="white", edgecolors=color,
                           linewidths=1.2, zorder=4)
        if not any(row["design"] == "PFAT64" and row["benchmark"] == benchmark
                   for row in rows):
            ax.text(0.98, 0.04, "PFAT64: no accepted 3-seed points",
                    transform=ax.transAxes, ha="right", va="bottom", fontsize=8,
                    color="#69727A")
        ax.grid(alpha=0.22, linewidth=0.7)
        ax.set_xlim(left=0, right=820)
        if kind == "latency":
            ax.set_yscale("log")
        ax.set_xlabel("Nominal injection (Mflit/s/port)")
        ax.set_ylabel("Offer-to-last-tail latency (ns, log scale)" if kind == "latency"
                      else "Delivered copy throughput (Mflit/s/port)")
    handles, labels = axs.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", bbox_to_anchor=(0.5, 0.978),
               ncol=3, frameon=False, fontsize=11)
    fig.suptitle("64-node asynchronous NoC: " + ("latency" if kind == "latency" else "throughput"),
                 y=0.998, fontsize=17, weight="semibold")
    note = ("Three-seed means. Open markers: accepted pressure points below 99% window delivery; "
            "latency of completed events only." if kind == "latency" else
            "Three-seed means from accepted cases; open markers are accepted pressure "
            "points below the 99% window-delivery threshold.")
    fig.supxlabel(note + "  Sync M16 excluded.", y=0.004, fontsize=9, color="#49535B")
    fig.tight_layout(rect=(0.01, 0.018, 0.99, 0.948), h_pad=2.1, w_pad=1.5)
    for ext in ("png", "pdf"):
        fig.savefig(output / f"formal64_async_{kind}_curves.{ext}", dpi=220)
    plt.close(fig)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--summary", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    manifest = json.loads((args.summary / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema") != "formal64-full-aggregation-v1":
        raise ValueError("unexpected summary schema")
    rows = read_csv(args.summary / "formal64_seed_averages.csv")
    if any(row["design"] not in (*DESIGNS, "SYNC_M16") for row in rows):
        raise ValueError("unexpected design")
    if len({(row["design"], row["benchmark"], row["load"]) for row in rows}) != len(rows):
        raise ValueError("duplicate curve point")
    if any(row["n_seeds"] != "3" for row in rows):
        raise ValueError("non-three-seed curve point")
    args.output.mkdir(parents=True, exist_ok=True)
    plot(rows, args.output, "latency")
    plot(rows, args.output, "throughput")
    print("FORMAL64_ASYNC_CURVES", args.output)


if __name__ == "__main__":
    main()
