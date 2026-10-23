#!/usr/bin/env python3
"""Plot three-design 64-node peak delivered-copy throughput by benchmark."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import statistics
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

DESIGNS = {"PROP_M16": ("M16", "#156082"), "FM64": ("Mesh", "#E97132"), "PFAT64": ("PFAT", "#70AD47")}
BENCHMARKS = [("TOPO-UR", "UR"), ("TOPO-BC", "Bit complement"), ("HOTSPOT10", "Hotspot10"),
              ("MULTICAST5-AABB", "Multicast5"), ("MULTICAST10-AABB", "Multicast10"),
              ("MULTICAST-STATIC-AABB", "Multicast-static")]

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))

def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)

def plot_bars(ax, rows):
    x = np.arange(len(BENCHMARKS)); width = 0.24
    for index, (design, (label, color)) in enumerate(DESIGNS.items()):
        positions = x + (index - 1) * width
        selected = [next(row for row in rows if row["design"] == design and row["benchmark"] == benchmark)
                    for benchmark, _ in BENCHMARKS]
        values = [float(row["peak_copy_throughput"]) for row in selected]
        errors = [float(row["peak_copy_std"]) for row in selected]
        bars = ax.bar(positions, values, width, color=color, edgecolor="black", linewidth=0.45, label=label, zorder=3)
        ax.errorbar(positions, values, yerr=errors, fmt="none", ecolor="#404040",
                    elinewidth=0.7, capsize=2.2, capthick=0.7, zorder=4)
        for bar, row, value in zip(bars, selected, values):
            incomplete = row["validation_status"] != "verified"
            if incomplete:
                bar.set_facecolor("white"); bar.set_edgecolor(color); bar.set_hatch("///"); bar.set_linewidth(1.2)
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 15,
                    f"{value:.0f}{'*' if incomplete else ''}", ha="center", va="bottom", fontsize=7.5, color="#303030")
    ax.set_xticks(x, [label for _, label in BENCHMARKS], rotation=22, ha="right")
    ax.set_ylabel("Peak delivered destination-copy throughput\n(Mflit/s/port)")
    ax.grid(axis="y", alpha=0.22, linewidth=0.7, zorder=0); ax.set_axisbelow(True)
    ax.spines[["top", "right"]].set_visible(False); ax.legend(ncol=3, frameon=False, loc="upper right")

def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--scan-source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True); args = parser.parse_args(); args.output.mkdir(parents=True, exist_ok=True)
    source_rows = read_csv(args.source); scan_rows = read_csv(args.scan_source); rows = []
    provisional = [row for row in scan_rows if row["design"] == "FM64" and row["benchmark"] == "ALL-BROADCAST"]
    provisional_groups = {}
    for row in provisional:
        provisional_groups.setdefault(int(row["load"]), []).append(float(row["delivered_mflit_port_s"]))
    provisional_groups = {load: values for load, values in provisional_groups.items() if len(values) == 3}
    provisional_load, provisional_values = max(provisional_groups.items(), key=lambda item: statistics.mean(item[1]))
    for benchmark, benchmark_label in BENCHMARKS:
        for design, (design_label, _) in DESIGNS.items():
            source = next(row for row in source_rows if row["design"] == design and row["benchmark"] == benchmark)
            incomplete = design == "FM64" and benchmark == "ALL-BROADCAST"
            peak = statistics.mean(provisional_values) if incomplete else float(source["peak_copy_throughput"])
            peak_std = statistics.stdev(provisional_values) if incomplete else float(source["peak_copy_std"])
            peak_load = provisional_load if incomplete else int(source["peak_load"])
            rows.append({"design": design, "design_label": design_label, "benchmark": benchmark,
                         "benchmark_label": benchmark_label,
                         "sustainable_injection_load_mflit_port_s": source["highest_near_lossless_load"],
                         "sustainable_copy_throughput_mflit_port_s": source["safe_copy_throughput"],
                         "sustainable_copy_throughput_std": source["safe_copy_std"],
                         "observed_peak_copy_throughput_mflit_port_s": f"{peak:.6f}",
                         "observed_peak_copy_throughput_std": f"{peak_std:.6f}",
                         "observed_peak_load_mflit_port_s": peak_load,
                         "n_three_seed_points": source["n_three_seed_points"],
                         "validation_status": "provisional_old_csv_current_rerun_pending" if incomplete else "verified"})
    csv_path = args.output/"formal64_peak_throughput.csv"; write_csv(csv_path, rows)
    plot_rows = [{"design": r["design"], "benchmark": r["benchmark"],
                  "peak_copy_throughput": r["observed_peak_copy_throughput_mflit_port_s"],
                  "peak_copy_std": r["observed_peak_copy_throughput_std"],
                  "validation_status": r["validation_status"]} for r in rows]
    plt.rcParams.update({"font.family":"DejaVu Sans", "font.size":9, "pdf.fonttype":42, "ps.fonttype":42})
    fig, ax = plt.subplots(figsize=(12.2, 5.1), layout="constrained"); plot_bars(ax, plot_rows)
    fig.suptitle("64-node asynchronous NoC peak throughput", fontsize=14, weight="bold")
    fig.supxlabel("Delivered destination-copy flits during the measurement window, normalized by 64 ports. "
                  "Error bars: sample SD across three seeds.", fontsize=8.5)
    png_path=args.output/"formal64_peak_throughput.png"; pdf_path=args.output/"formal64_peak_throughput.pdf"
    fig.savefig(png_path,dpi=300,bbox_inches="tight"); fig.savefig(pdf_path,bbox_inches="tight"); plt.close(fig)
    outputs=[csv_path,png_path,pdf_path]
    manifest={"source":str(args.source.resolve()),
              "scan_source":str(args.scan_source.resolve()),
              "metric":"maximum three-seed mean measurement-window delivered destination-copy throughput",
              "units":"Mflit/s/port", "designs":list(DESIGNS), "benchmarks":[b for b,_ in BENCHMARKS],
              "limitations":["Mesh all-broadcast M20 is plotted provisionally from unvalidated CSV values pending strict-SDF rerun."],
              "sha256":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in outputs}}
    (args.output/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    print(json.dumps({"rows":len(rows),"outputs":[str(p) for p in outputs]},indent=2))

if __name__ == "__main__": main()
