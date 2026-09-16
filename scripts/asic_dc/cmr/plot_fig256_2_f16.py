#!/usr/bin/env python3
"""Plot Fig.256-2: PROP_temp256 F16 cross-tier Native vs Repeated."""
from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt

REPO = Path(__file__).resolve().parents[3]
RAW = REPO / "DATE paper" / "experiments" / "raw" / "paper256" / "e2_f16_cross_tier256_20260915_181113"
FIG = REPO / "DATE paper" / "experiments" / "figures" / "paper256" / "e2_f16_cross_tier256_20260915_181113"
CSV_DIR = RAW / "csv"

ORDER = ("low", "medium", "high")
LOAD_LABEL = {"low": "low (M5)", "medium": "med (M40)", "high": "high (M80)"}


def load_rows() -> list[dict]:
    rows = []
    for path in sorted(CSV_DIR.glob("*.csv")):
        name = path.name
        # sdf_MC-F16_n256_s202701_<load>_<scheme>_PROP_temp256_top0.csv
        parts = name.replace(".csv", "").split("_")
        # find load and scheme tokens
        load = next(t for t in ("low", "medium", "high") if t in parts)
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
                "injected_pkts": int(row["injected_packets"]),
            }
        )
    return rows


def main() -> int:
    FIG.mkdir(parents=True, exist_ok=True)
    rows = load_rows()
    assert len(rows) == 6, rows

    xs = list(range(len(ORDER)))
    native = {r["load"]: r for r in rows if r["scheme"] == "native"}
    repeated = {r["load"]: r for r in rows if r["scheme"] == "repeated"}

    fig, axes = plt.subplots(1, 2, figsize=(9.2, 3.6), constrained_layout=True)

    ax = axes[0]
    ax.plot(xs, [native[k]["avg_lat"] for k in ORDER], "o-", label="Native MC", color="#1f77b4")
    ax.plot(xs, [repeated[k]["avg_lat"] for k in ORDER], "s--", label="Repeated UC", color="#d62728")
    ax.set_xticks(xs, [LOAD_LABEL[k] for k in ORDER])
    ax.set_ylabel("Mean completion latency (ns)")
    ax.set_title("Fig.256-2a Completion latency")
    ax.grid(True, alpha=0.3)
    ax.legend(frameon=False)

    ax = axes[1]
    ax.plot(xs, [native[k]["thr"] for k in ORDER], "o-", label="Native MC", color="#1f77b4")
    ax.plot(xs, [repeated[k]["thr"] for k in ORDER], "s--", label="Repeated UC", color="#d62728")
    ax.set_xticks(xs, [LOAD_LABEL[k] for k in ORDER])
    ax.set_ylabel("Delivered throughput (flits / cycle)")
    ax.set_title("Fig.256-2b Useful delivery throughput")
    ax.grid(True, alpha=0.3)
    ax.legend(frameon=False)

    out_png = FIG / "fig256-2-f16-native-vs-repeated.png"
    out_pdf = FIG / "fig256-2-f16-native-vs-repeated.pdf"
    fig.savefig(out_png, dpi=160)
    fig.savefig(out_pdf)
    plt.close(fig)

    summary = FIG / "summary.csv"
    with summary.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=["load", "scheme", "avg_lat_ns", "p95_lat_ns", "delivered_throughput", "delivered_packets"],
        )
        w.writeheader()
        for load in ORDER:
            for scheme, bag in (("native", native), ("repeated", repeated)):
                r = bag[load]
                w.writerow(
                    {
                        "load": load,
                        "scheme": scheme,
                        "avg_lat_ns": r["avg_lat"],
                        "p95_lat_ns": r["p95_lat"],
                        "delivered_throughput": r["thr"],
                        "delivered_packets": r["delivered_pkts"],
                    }
                )

    (FIG / "README.md").write_text(
        "\n".join(
            [
                "# Fig.256-2 PROP_temp256 F16 cross-tier",
                "",
                "Native multicast vs source-repeated unicast at low/med/high.",
                "",
                f"- `{out_png.name}`",
                f"- `{out_pdf.name}`",
                "- `summary.csv`",
                "",
                "Source run: `20260915_121842_cmr_e2_f16_cross_tier256` (6/6 PASS).",
                "",
            ]
        ),
        encoding="utf-8",
    )
    print("FIG256_2_OK", out_png, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
