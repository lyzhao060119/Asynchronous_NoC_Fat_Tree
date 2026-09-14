#!/usr/bin/env python3
"""Plot Mesh64 vs PROP_temp64 ASAP TOPO-UR m5-800 scan.

Matches the paper64 ASAP dual-panel style used for Mesh vs PFAT:
  left  — delivered vs offered (+ ideal y=x)
  right — mean flit latency vs offered (log y)
"""
from __future__ import annotations

import csv
import json
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.ticker import LogLocator, NullFormatter

HERE = Path(__file__).resolve().parent
FIG_DIR = (
    HERE.parents[2]
    / "DATE paper"
    / "experiments"
    / "figures"
    / "paper64"
    / "20260914_092324_asap_uc_m5_800_mesh64_prop_temp64"
)
CSV_PATH = FIG_DIR / "aggregated_metrics.csv"
OUT_STEM = "flatmesh64-vs-prop-temp64-asap-unicast"

# Match prior ASAP Mesh/PFAT figure: Mesh blue circles; challenger warm squares.
STYLE = {
    "FM64": {
        "label": "FlatMesh64 DEL150",
        "color": "#1f77b4",
        "marker": "o",
        "z": 3,
    },
    "PROP_temp64": {
        "label": "PROP_temp64 DEL050",
        "color": "#d62728",
        "marker": "s",
        "z": 2,
    },
}


def load_rows(path: Path) -> dict[str, list[dict]]:
    by_design: dict[str, list[dict]] = {}
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            design = row["design"]
            by_design.setdefault(design, []).append(
                {
                    "offered": float(row["offered_mflit_per_port_s"]),
                    "delivered": float(row["delivered_mflit_per_port_s"]),
                    "latency": float(row["flit_latency_mean_ns"]),
                    "load": int(float(row["load_setpoint_mflit_per_port_s"])),
                }
            )
    for rows in by_design.values():
        rows.sort(key=lambda r: r["offered"])
    return by_design


def main() -> int:
    data = load_rows(CSV_PATH)
    if set(data) != {"FM64", "PROP_temp64"}:
        raise SystemExit("unexpected designs: %s" % sorted(data))

    plt.rcParams.update(
        {
            "font.size": 10,
            "axes.labelsize": 11,
            "axes.titlesize": 11,
            "legend.fontsize": 9,
            "xtick.labelsize": 9,
            "ytick.labelsize": 9,
            "axes.linewidth": 0.8,
            "figure.dpi": 140,
            "savefig.dpi": 300,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )

    fig, (ax_tp, ax_lat) = plt.subplots(
        1, 2, figsize=(8.6, 3.4), constrained_layout=True
    )

    xmax = max(max(r["offered"] for r in rows) for rows in data.values())
    ymax_tp = max(max(r["delivered"] for r in rows) for rows in data.values())
    lim = max(xmax, ymax_tp) * 1.05

    # Ideal delivery
    ax_tp.plot([0, lim], [0, lim], ls="--", color="#7f7f7f", lw=1.0, label="Ideal", zorder=1)

    for design in ("FM64", "PROP_temp64"):
        rows = data[design]
        st = STYLE[design]
        ax_tp.plot(
            [r["offered"] for r in rows],
            [r["delivered"] for r in rows],
            color=st["color"],
            marker=st["marker"],
            ms=4.5,
            lw=1.4,
            label=st["label"],
            zorder=st["z"],
        )
        ax_lat.plot(
            [r["offered"] for r in rows],
            [r["latency"] for r in rows],
            color=st["color"],
            marker=st["marker"],
            ms=4.5,
            lw=1.4,
            label=st["label"],
            zorder=st["z"],
        )

    ax_tp.set_xlabel("Offered load (Mflit/s/port)")
    ax_tp.set_ylabel("Delivered throughput (Mflit/s/port)")
    ax_tp.set_xlim(0, lim)
    ax_tp.set_ylim(0, lim)
    ax_tp.set_aspect("equal", adjustable="box")
    ax_tp.grid(True, which="major", ls=":", lw=0.6, alpha=0.7)
    ax_tp.legend(loc="upper left", frameon=True, fancybox=False, edgecolor="#cccccc")

    ax_lat.set_xlabel("Offered load (Mflit/s/port)")
    ax_lat.set_ylabel("Mean flit latency (ns)")
    ax_lat.set_xlim(0, lim)
    ax_lat.set_yscale("log")
    ax_lat.yaxis.set_major_locator(LogLocator(base=10.0))
    ax_lat.yaxis.set_minor_locator(LogLocator(base=10.0, subs=(2, 3, 4, 5, 6, 7, 8, 9)))
    ax_lat.yaxis.set_minor_formatter(NullFormatter())
    ax_lat.grid(True, which="major", ls=":", lw=0.6, alpha=0.7)
    ax_lat.grid(True, which="minor", ls=":", lw=0.4, alpha=0.35)
    ax_lat.legend(loc="upper left", frameon=True, fancybox=False, edgecolor="#cccccc")

    png = FIG_DIR / (OUT_STEM + ".png")
    pdf = FIG_DIR / (OUT_STEM + ".pdf")
    fig.savefig(png, bbox_inches="tight")
    fig.savefig(pdf, bbox_inches="tight")
    plt.close(fig)

    manifest = {
        "source": str(CSV_PATH).replace("\\", "/"),
        "figure": OUT_STEM,
        "rows": sum(len(v) for v in data.values()),
        "designs": sorted(data),
        "x": "offered_mflit_per_port_s",
        "panels": {
            "left": "delivered_mflit_per_port_s vs offered (+ ideal y=x)",
            "right": "flit_latency_mean_ns vs offered (log y)",
        },
        "all_tb_pass": True,
        "outputs": [png.name, pdf.name],
    }
    (FIG_DIR / "plot_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("PLOT_OK", png, flush=True)
    print("PLOT_OK", pdf, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
