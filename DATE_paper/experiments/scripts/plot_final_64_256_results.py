#!/usr/bin/env python3
"""Render the four unified DATE paper figures from final CSVs only."""

from __future__ import annotations

import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D


ROOT = Path(__file__).resolve().parents[3]
PAPER_DIR = ROOT / ("DATE_paper" if (ROOT / "DATE_paper").is_dir() else "DATE paper")
FINAL = PAPER_DIR / "experiments" / "final" / "20260918_64_256_final"
DATA = FINAL / "data"
FIGURES = FINAL / "figures"

COLORS = {
    "Mesh": "#0072B2", "PROP": "#D55E00", "FAT": "#009E73",
    "Native": "#D55E00", "Repeated": "#7A7A7A",
    "Dynamic": "#D55E00",
    "Async": "#D55E00", "Sync": "#56B4E9",
}
MARKERS = {"Mesh": "s", "PROP": "o", "FAT": "^", "Native": "o", "Repeated": "s",
           "Dynamic": "o", "Async": "o", "Sync": "s"}
MODE_MARKERS = {"UR (Async)": "o", "UR (Sync)": "X", "BC": "s", "Hotspot10": "^"}
FORBIDDEN_PUBLIC_TEXT = ("temp", "b8", "m16", "fm64", "fm256", "pfat64", "static")
FIXED_TIMESTAMP = datetime(2026, 9, 18, tzinfo=timezone.utc)


plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 8.2,
    "axes.titlesize": 9.2,
    "axes.labelsize": 8.5,
    "xtick.labelsize": 7.5,
    "ytick.labelsize": 7.5,
    "legend.fontsize": 7.5,
    "axes.linewidth": 0.7,
    "lines.linewidth": 1.7,
    "lines.markersize": 4.2,
    "pdf.fonttype": 42,
    "ps.fonttype": 42,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.04,
})


def read(name: str) -> list[dict[str, str]]:
    path = DATA / name
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"missing final data file: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def f(value: str) -> float:
    return float(value)


def style_axis(ax: plt.Axes, *, grid: bool = True) -> None:
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.tick_params(direction="out", length=3, width=0.7)
    if grid:
        ax.grid(axis="y", color="#D9D9D9", linewidth=0.55, alpha=0.8)
        ax.set_axisbelow(True)


def plot_lines(ax: plt.Axes, rows: list[dict[str, str]], series_order: list[str],
               x_field: str, y_field: str, *, latency_only: bool = False) -> None:
    for series in series_order:
        chosen = [row for row in rows if row["paper_label"] == series]
        if latency_only:
            chosen = [row for row in chosen if row.get("latency_eligible", "").lower() == "true"
                      and row.get(y_field, "") != ""]
        chosen.sort(key=lambda row: f(row[x_field]))
        if not chosen:
            continue
        ax.plot([f(row[x_field]) for row in chosen], [f(row[y_field]) for row in chosen],
                label=series, color=COLORS[series], marker=MARKERS[series],
                markerfacecolor="white", markeredgewidth=0.9)
    style_axis(ax)


def grouped_bars(ax: plt.Axes, categories: list[str], series: list[str], values: dict[tuple[str, str], float],
                 ylabel: str, *, value_format: str = ".1f") -> None:
    x = np.arange(len(categories), dtype=float)
    width = 0.72 / max(1, len(series))
    for index, name in enumerate(series):
        offset = (index - (len(series) - 1) / 2.0) * width
        heights = [values[(category, name)] for category in categories]
        bars = ax.bar(x + offset, heights, width * 0.92, label=name, color=COLORS[name],
                      edgecolor="black", linewidth=0.35)
        for bar, height in zip(bars, heights):
            ax.annotate(format(height, value_format),
                        (bar.get_x() + bar.get_width() / 2.0, bar.get_height()),
                        xytext=(0, 2), textcoords="offset points", ha="center", va="bottom", fontsize=6.5)
    ax.set_xticks(x, categories)
    ax.set_ylabel(ylabel)
    ax.set_ylim(bottom=0)
    style_axis(ax)


def panel_labels(fig: plt.Figure, axes: np.ndarray | list[plt.Axes]) -> None:
    flat = np.asarray(axes, dtype=object).reshape(-1)
    for index, ax in enumerate(flat):
        ax.text(-0.14, 1.04, f"({chr(ord('a') + index)})", transform=ax.transAxes,
                fontsize=8.5, fontweight="bold", va="bottom")


def collect_legend(fig: plt.Figure, axes: np.ndarray | list[plt.Axes], order: list[str], y: float = 1.01) -> None:
    found: dict[str, object] = {}
    for ax in np.asarray(axes, dtype=object).reshape(-1):
        handles, labels = ax.get_legend_handles_labels()
        found.update(dict(zip(labels, handles)))
    labels = [name for name in order if name in found]
    fig.legend([found[name] for name in labels], labels, loc="upper center", ncol=len(labels),
               frameon=False, bbox_to_anchor=(0.5, y), handlelength=2.2, columnspacing=1.2)


def save(fig: plt.Figure, stem: str) -> list[Path]:
    FIGURES.mkdir(parents=True, exist_ok=True)
    pdf = FIGURES / f"{stem}.pdf"
    png = FIGURES / f"{stem}.png"
    fig.savefig(pdf, metadata={"Title": stem, "Creator": "final-results plotter",
                               "CreationDate": FIXED_TIMESTAMP, "ModDate": FIXED_TIMESTAMP})
    fig.savefig(png, dpi=300, metadata={"Software": "final-results plotter", "Creation Time": "2026-09-18"})
    plt.close(fig)
    if pdf.stat().st_size == 0 or png.stat().st_size == 0:
        raise RuntimeError(f"empty figure output for {stem}")
    return [pdf, png]


def fig01() -> list[Path]:
    return shared_scan64(
        "fig01_64_throughput", "fig01_64_throughput.csv",
        "64-node throughput", "Delivered throughput (Mflit/s/port)",
    )


def fig02() -> list[Path]:
    return shared_scan64(
        "fig02_64_latency", "fig02_64_latency.csv",
        "64-node mean latency", "Mean flit latency (ps)",
    )


def shared_scan64(stem: str, data_file: str, title: str, ylabel: str) -> list[Path]:
    rows = read(data_file)
    topology_order = ["Mesh", "PROP", "FAT"]
    mode_order = ["UR (Async)", "UR (Sync)", "BC", "Hotspot10"]
    metric = "delivered_throughput" if "throughput" in stem else "mean_flit_latency"
    if any(row["metric"] != metric for row in rows):
        raise RuntimeError(f"unexpected metric in {data_file}")

    fig, ax = plt.subplots(figsize=(7.0, 7.0))
    fig.subplots_adjust(left=0.15, right=0.98, bottom=0.13, top=0.70)
    for topology in topology_order:
        for mode in mode_order:
            chosen = [row for row in rows if row["topology"] == topology and row["mode"] == mode]
            chosen.sort(key=lambda row: f(row["offered_mflit_s_per_port"]))
            if not chosen:
                continue
            ax.plot(
                [f(row["offered_mflit_s_per_port"]) for row in chosen],
                [f(row["value"]) * (1000.0 if metric == "mean_flit_latency" else 1.0)
                 for row in chosen],
                color=COLORS[topology], marker=MODE_MARKERS[mode],
                markerfacecolor="white", markeredgewidth=0.8,
                markersize=3.6, linewidth=1.35, alpha=0.92,
            )
    ax.set_title(title, pad=7)
    ax.set_xlabel("Measured offered throughput (Mflit/s/port)")
    ax.set_ylabel(ylabel)
    ax.set_xlim(0, 300)
    if metric == "mean_flit_latency":
        ax.set_ylim(3000, 25000)
        fig.subplots_adjust(bottom=0.15)
        fig.text(0.5, 0.025,
                 "Display window: offered 0–300 Mflit/s/port; mean latency 3,000–25,000 ps.",
                 ha="center", va="bottom", fontsize=6.8, color="#444444")
    else:
        ax.set_ylim(0, 300)
        fig.text(0.5, 0.025,
                 "Display window: 0–300 Mflit/s/port on both axes.",
                 ha="center", va="bottom", fontsize=6.8, color="#444444")
    ax.set_box_aspect(1)
    style_axis(ax)

    topology_handles = [
        Line2D([0], [0], color=COLORS[name], linewidth=1.8, label=name)
        for name in topology_order
        if any(row["topology"] == name for row in rows)
    ]
    mode_handles = [
        Line2D([0], [0], color="#4A4A4A", marker=MODE_MARKERS[mode],
               markerfacecolor="white", markeredgewidth=0.8, linewidth=0,
               markersize=4.2, label=mode)
        for mode in mode_order
        if any(row["mode"] == mode for row in rows)
    ]
    fig.legend(topology_handles, [handle.get_label() for handle in topology_handles],
               loc="upper center", bbox_to_anchor=(0.5, 0.995), ncol=3,
               frameon=False, title="Topology", handlelength=1.8, columnspacing=1.4)
    fig.legend(mode_handles, [handle.get_label() for handle in mode_handles],
               loc="upper center", bbox_to_anchor=(0.5, 0.885), ncol=5,
               frameon=False, title="Mode", handletextpad=0.45, columnspacing=1.15)
    return save(fig, stem)


def fig03() -> list[Path]:
    rows = read("fig02_unicast256.csv")
    global_rows = [row for row in rows if row["section"] == "global_ur"]
    locality_rows = [row for row in rows if row["section"] == "locality"]
    fig, axes = plt.subplots(1, 3, figsize=(7.15, 2.35))
    fig.subplots_adjust(left=0.085, right=0.995, bottom=0.22, top=0.78, wspace=0.38)
    plot_lines(axes[0], global_rows, ["Mesh", "PROP"], "x_value", "delivered_mflit_s_per_port")
    axes[0].set_title("Global UR")
    axes[0].set_xlabel("Offered throughput (Mflit/s/port)")
    axes[0].set_ylabel("Delivered throughput\n(Mflit/s/port)")
    global_latency_rows = [row for row in global_rows if int(row["load_m"]) != 60]
    plot_lines(axes[1], global_latency_rows, ["Mesh", "PROP"], "x_value", "mean_latency_ns",
               latency_only=True)
    axes[1].set_title("Global UR")
    axes[1].set_xlabel("Offered throughput (Mflit/s/port)")
    axes[1].set_ylabel("Mean latency (ns)")
    p_label = lambda value: ("0.247" if abs(f(value) - 63 / 255) < 1e-6 else f"{f(value):.2f}")
    categories = ["0.247", "0.50", "0.75"]
    locality_values = {
        (p_label(row["x_value"]), row["paper_label"]): f(row["mean_latency_ns"])
        for row in locality_rows
    }
    grouped_bars(axes[2], categories, ["Mesh", "PROP"], locality_values, "Mean latency (ns)")
    axes[2].set_title("Locality sensitivity")
    axes[2].set_xlabel("Local-destination probability")
    locality_loads = sorted({int(row["load_m"]) for row in locality_rows})
    if len(locality_loads) != 1:
        raise RuntimeError(f"locality points do not share one injection setpoint: {locality_loads}")
    axes[2].text(0.5, 1.13, f"Injection rate: M{locality_loads[0]}",
                 transform=axes[2].transAxes, ha="center", va="bottom", fontsize=6.5,
                 bbox={"facecolor": "white", "edgecolor": "none", "alpha": 0.8, "pad": 1.5})
    collect_legend(fig, axes, ["Mesh", "PROP"], y=0.99)
    panel_labels(fig, axes)
    return save(fig, "fig03_256_global_locality")


def fig04() -> list[Path]:
    rows = read("fig03_multicast.csv")
    fig, axes = plt.subplots(2, 2, figsize=(7.15, 4.55))
    fig.subplots_adjust(left=0.10, right=0.99, bottom=0.13, top=0.83,
                        wspace=0.42, hspace=0.58)
    fanout_rows = [row for row in rows if row["nodes"] == "64" and row["load_m"] == "5"]
    categories = ["F2", "F16", "F32"]
    fanout_values = {
        (f"F{row['fanout']}", row["paper_label"]): f(row["mean_completion_latency_ns"])
        for row in fanout_rows
    }
    grouped_bars(axes[0, 0], categories, ["Native", "Repeated"], fanout_values,
                 "Mean completion latency (ns)")
    axes[0, 0].set_title("64-node fanout, M5")
    axes[0, 0].set_xlabel("Fanout")

    for ax, section, title in ((axes[0, 1], "f16_64", "64-node F16"),
                               (axes[1, 0], "f16_256_cross_tier", "256-node cross-tier F16")):
        subset = [row for row in rows if row["section"] == section]
        load_categories = ["M5", "M20"]
        values = {(f"M{row['load_m']}", row["paper_label"]): f(row["mean_completion_latency_ns"])
                  for row in subset}
        grouped_bars(ax, load_categories, ["Native", "Repeated"], values, "Mean completion latency (ns)")
        ax.set_title(title)
        ax.set_xlabel("Load point")

    power = read("power64_all_accepted.csv")
    f16_energy = {
        ("M5", "Native"): f(next(row["energy_pj_per_useful_delivery"] for row in power
                                  if row["result_id"] == "f16_native_m5")),
        ("M5", "Repeated"): f(next(row["energy_pj_per_useful_delivery"] for row in power
                                    if row["result_id"] == "f16_repeated_m5")),
    }
    grouped_bars(axes[1, 1], ["M5"], ["Native", "Repeated"], f16_energy,
                 "Energy (pJ/useful destination)", value_format=".1f")
    axes[1, 1].set_title("64-node F16 energy")
    axes[1, 1].set_xlabel("Injection setpoint")
    collect_legend(fig, axes, ["Native", "Repeated"], y=0.99)
    panel_labels(fig, axes)
    return save(fig, "fig04_multicast")


def fig05() -> list[Path]:
    rows = read("power64_all_accepted.csv")
    fig, axes = plt.subplots(2, 2, figsize=(7.15, 4.55))
    fig.subplots_adjust(left=0.10, right=0.99, bottom=0.15, top=0.88,
                        wspace=0.43, hspace=0.65)
    configs = {
        "flatmesh_m100": ("Mesh", COLORS["Mesh"], ""),
        "prop_m100": ("PROP\nAsync", COLORS["PROP"], ""),
        "pfat_m100": ("FAT", COLORS["FAT"], ""),
        "sync_m100": ("PROP\nSync*", COLORS["PROP"], "xxx"),
    }
    common_high = {
        "dynamic_common_high": ("Async", COLORS["PROP"], ""),
        "sync_common_high": ("Sync*", COLORS["PROP"], "xxx"),
    }

    def draw_power_panel(ax: plt.Axes, result_ids: dict[str, tuple[str, str, str]],
                         field: str, title: str, ylabel: str, fmt: str) -> None:
        value_by_id = {row["result_id"]: f(row[field]) for row in rows if row[field] != ""}
        for index, (result_id, (label, color, hatch)) in enumerate(result_ids.items()):
            value = value_by_id[result_id]
            bar = ax.bar(index, value, width=0.48, color=color, edgecolor="black",
                         linewidth=0.45, hatch=hatch)
            ax.annotate(format(value, fmt),
                        (bar[0].get_x() + bar[0].get_width() / 2, value),
                        xytext=(0, 2), textcoords="offset points", ha="center",
                        va="bottom", fontsize=6.3)
        ax.set_xticks(np.arange(len(result_ids)), [item[0] for item in result_ids.values()])
        ax.set_title(title)
        ax.set_ylabel(ylabel)
        ax.set_ylim(bottom=0)
        style_axis(ax)

    draw_power_panel(axes[0, 0], configs, "total_power_w", "M100 total power", "Power (W)", ".3f")
    draw_power_panel(axes[0, 1], configs, "energy_pj_per_delivered_flit",
                     "M100 energy", "Energy (pJ/flit)", ".1f")
    draw_power_panel(axes[1, 0], common_high, "total_power_w",
                     "Common-high PROP power", "Power (W)", ".3f")
    draw_power_panel(axes[1, 1], common_high, "energy_pj_per_delivered_flit",
                     "Common-high PROP energy", "Energy (pJ/flit)", ".1f")
    fig.text(0.5, 0.025,
             "* Sync power uses pre-CTS clock activity; Sync bars are PROP variants.",
             ha="center", va="bottom", fontsize=6.8, color="#444444")
    panel_labels(fig, axes)
    return save(fig, "fig05_network_power64")


def validate_public_text(figures: list[Path]) -> None:
    # All display strings are defined above. Validate them before declaring pass;
    # provenance fields are deliberately allowed to keep internal identifiers.
    public_strings = [
        text.get_text()
        for figure_number in plt.get_fignums()
        for text in plt.figure(figure_number).findobj(match=lambda obj: hasattr(obj, "get_text"))
    ]
    scripted_text = " ".join([
        "Mesh PROP FAT UR Async UR Sync BC Hotspot10 Sync",
        "Global UR Locality sensitivity",
        "64-node throughput 64-node mean latency 64-node fanout 64-node F16",
        "256-node global locality 256-node cross-tier F16 Native Repeated",
        "M100 total power M100 energy Common-high PROP power Common-high PROP energy",
    ]).lower()
    combined = " ".join(public_strings).lower() + " " + scripted_text
    bad = [token for token in FORBIDDEN_PUBLIC_TEXT if token in combined]
    if bad:
        raise RuntimeError(f"internal identifiers leaked into public figure text: {bad}")
    for path in figures:
        if not path.is_file() or path.stat().st_size < 1000:
            raise RuntimeError(f"missing or suspiciously small figure: {path}")


def main() -> int:
    manifest = FINAL / "data_manifest.json"
    if not manifest.is_file() or json.loads(manifest.read_text(encoding="utf-8")).get("status") != "FINAL_RESULTS_DATA_PASS":
        raise RuntimeError("final data must pass before plotting")
    figures: list[Path] = []
    figures.extend(fig01())
    figures.extend(fig02())
    figures.extend(fig03())
    figures.extend(fig04())
    figures.extend(fig05())
    validate_public_text(figures)
    obsolete_stems = ("fig01_unicast64", "fig02_unicast256",
                      "fig03_multicast", "fig04_implementation64")
    for old_stem in obsolete_stems:
        for suffix in (".pdf", ".png"):
            (FIGURES / f"{old_stem}{suffix}").unlink(missing_ok=True)
    result = {
        "status": "FINAL_RESULTS_PASS",
        "figures": {str(path.relative_to(FINAL)).replace("\\", "/"): sha256(path) for path in figures},
        "style": {"topology_palette": {name: COLORS[name] for name in ("Mesh", "PROP", "FAT")},
                  "mode_markers": MODE_MARKERS, "64_node_shared_axes": True,
                  "latency": "mean only", "png_dpi": 300},
    }
    (FINAL / "figure_manifest.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    (FINAL / "FINAL_RESULTS_PASS").write_text("FINAL_RESULTS_PASS\n", encoding="ascii")
    print(json.dumps({"status": result["status"], "figure_files": len(figures),
                      "output": str(FINAL)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
