#!/usr/bin/env python3
"""Pull coarse E1 UR256 CSVs, archive, plot Fig.256-1, then submit fine loads."""
from __future__ import annotations

import csv
import re
import sys
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402

REMOTE_ROOT = "/home/ghy19/Asynchronous_Router_CMR"
# tick=1 restart (2026-09-15); previous tick=20 run IDs are obsolete.
TICK1_RUN = "20260915_tick1_cmr_e1_ur_three_dut256"
PROP_RUN = TICK1_RUN
BASE_RUN = TICK1_RUN
RAW_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper256"
FIG_ROOT = REPO / "DATE paper" / "experiments" / "figures" / "paper256"

DESIGNS = {
    "PROP_temp256": ("PROP_temp256", PROP_RUN, "#2ca02c"),
    "PFAT_temp256": ("PFAT_temp256", BASE_RUN, "#ff7f0e"),
    "FM256": ("FM256", BASE_RUN, "#1f77b4"),
}


def pull_csvs(raw_csv: Path) -> list[dict]:
    raw_csv.mkdir(parents=True, exist_ok=True)
    client = connect_failover()
    rows: list[dict] = []
    try:
        sftp = client.open_sftp()
        for design, (tag, run, _color) in DESIGNS.items():
            remote_dir = "%s/results/%s/csv" % (REMOTE_ROOT, run)
            client, listing = remote_run_failover(client, "ls -1 %s 2>/dev/null" % remote_dir)
            for name in listing.splitlines():
                name = name.strip()
                if not name.endswith(".csv") or ("_%s_top" % tag) not in name:
                    continue
                m = re.search(r"_m(\d+)_", name)
                if not m:
                    continue
                load = int(m.group(1))
                local = raw_csv / ("%s__%s" % (design, name))
                sftp.get("%s/%s" % (remote_dir, name), str(local))
                with local.open(encoding="utf-8", newline="") as fh:
                    row = next(csv.DictReader(fh))
                rows.append(
                    {
                        "design": design,
                        "load": load,
                        "pass_fail": row.get("pass_fail", ""),
                        "delivered_throughput": float(row["delivered_throughput"]),
                        "avg_packet_latency_ns": float(row["avg_packet_latency_ns"]),
                        "p95_latency_ns": float(row["p95_latency_ns"]),
                        "injected_flits": int(row["injected_flits"]),
                        "delivered_flits": int(row["delivered_flits"]),
                        "unexpected_flits": int(row.get("unexpected_flits", 0) or 0),
                        "case": name,
                    }
                )
                print("PULLED", design, load, flush=True)
        sftp.close()
    finally:
        client.close()
    return rows


def near_lossless(row: dict, base_lat: float) -> bool:
    if row["pass_fail"] != "PASS":
        return False
    if row["unexpected_flits"] != 0:
        return False
    if row["injected_flits"] != row["delivered_flits"]:
        return False
    # Pre-sat latency claim: keep points within 3x zero/low-load latency.
    return row["avg_packet_latency_ns"] <= max(3.0 * base_lat, base_lat + 50.0)


def plot(rows: list[dict], fig_dir: Path) -> None:
    fig_dir.mkdir(parents=True, exist_ok=True)
    summary = fig_dir / "summary.csv"
    with summary.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "design",
                "load",
                "delivered_throughput",
                "avg_packet_latency_ns",
                "p95_latency_ns",
                "pass_fail",
                "near_lossless",
                "case",
            ],
        )
        w.writeheader()
        for design, (_tag, _run, _color) in DESIGNS.items():
            drows = sorted([r for r in rows if r["design"] == design], key=lambda r: r["load"])
            if not drows:
                continue
            base = next((r["avg_packet_latency_ns"] for r in drows if r["load"] <= 20 and r["pass_fail"] == "PASS"), drows[0]["avg_packet_latency_ns"])
            for r in drows:
                r["near_lossless"] = near_lossless(r, base)
                w.writerow(
                    {
                        "design": r["design"],
                        "load": r["load"],
                        "delivered_throughput": r["delivered_throughput"],
                        "avg_packet_latency_ns": r["avg_packet_latency_ns"],
                        "p95_latency_ns": r["p95_latency_ns"],
                        "pass_fail": r["pass_fail"],
                        "near_lossless": r["near_lossless"],
                        "case": r["case"],
                    }
                )

    fig, ax = plt.subplots(figsize=(6.2, 4.2), constrained_layout=True)
    for design, (_tag, _run, color) in DESIGNS.items():
        drows = sorted([r for r in rows if r["design"] == design and r.get("near_lossless")], key=lambda r: r["delivered_throughput"])
        if not drows:
            drows = sorted([r for r in rows if r["design"] == design and r["pass_fail"] == "PASS"], key=lambda r: r["delivered_throughput"])
        ax.plot(
            [r["delivered_throughput"] for r in drows],
            [r["avg_packet_latency_ns"] for r in drows],
            "o-",
            label=design,
            color=color,
        )
    ax.set_xlabel("Delivered throughput (MFlit/port/s)")
    ax.set_ylabel("Mean packet latency (ns)")
    ax.set_title("Fig.256-1 Three-DUT Global UR (tick=1)")
    ax.grid(True, alpha=0.3)
    ax.legend(frameon=False)
    out_png = fig_dir / "three-dut-ur-throughput-pre-saturation-latency.png"
    out_pdf = fig_dir / "three-dut-ur-throughput-pre-saturation-latency.pdf"
    fig.savefig(out_png, dpi=160)
    fig.savefig(out_pdf)
    plt.close(fig)
    (fig_dir / "README.md").write_text(
        "# Fig.256-1 (tick=1 restart)\n\n"
        "CASE_TICK_NS=1; bundle `20260915_paper256_ur_tick1_m5_800_202701`.\n"
        "Coarse three-DUT UR: PROP / PFAT / FM256.\n"
        "Pre-sat filter: PASS + no unexpected + latency ≤ 3× low-load.\n"
        "Run: `%s`.\n" % TICK1_RUN,
        encoding="utf-8",
    )
    print("FIG256_1_OK", out_png, flush=True)


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw = RAW_ROOT / ("e1_ur_three_dut256_tick1_coarse_%s" % stamp)
    fig = FIG_ROOT / ("e1_ur_three_dut256_tick1_coarse_%s" % stamp)
    raw.mkdir(parents=True, exist_ok=True)
    rows = pull_csvs(raw / "csv")
    plot(rows, fig)
    (raw / "RESULTS.md").write_text(
        "\n".join(
            [
                "# 256-E1 three-DUT UR coarse (CASE_TICK_NS=1)",
                "",
                "Run: `%s`" % TICK1_RUN,
                "Case bundle: `20260915_paper256_ur_tick1_m5_800_202701`",
                "",
                "Counts: coarse points pulled = %d" % len(rows),
                "",
                "Fig.256-1: `%s`" % fig.name,
                "",
            ]
        ),
        encoding="utf-8",
    )
    print("E1_COARSE_ARCHIVE", raw, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
