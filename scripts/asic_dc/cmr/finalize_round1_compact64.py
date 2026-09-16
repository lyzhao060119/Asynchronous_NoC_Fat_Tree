#!/usr/bin/env python3
"""Publish the round-1 frozen-netlist 64-node evidence view without mutating sources."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import matplotlib.pyplot as plt

REPO = Path(__file__).resolve().parents[3]
RAW = REPO / "DATE paper" / "experiments" / "raw" / "paper64"
FIG = REPO / "DATE paper" / "experiments" / "figures" / "paper64"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--ur", type=Path, required=True)
    p.add_argument("--router", type=Path, required=True)
    p.add_argument("--stamp", default=datetime.now().strftime("%Y%m%d_%H%M%S"))
    a = p.parse_args()
    out = RAW / ("compact64_" + a.stamp)
    fig = FIG / ("compact64_" + a.stamp)
    if out.exists() or fig.exists():
        raise SystemExit("refusing to overwrite compact64 publication")
    ur = a.ur.resolve(); router = a.router.resolve()
    if not (ur / "acceptance.csv").is_file() or not (router / "summary.json").is_file():
        raise SystemExit("UR or Router acceptance input missing")
    out.mkdir(parents=True); fig.mkdir(parents=True)
    # Index immutable published inputs rather than moving them.
    sources = [ur / "summary.csv", ur / "acceptance.csv", ur / "saturation_summary.csv", router / "summary.json", router / "metrics.csv"]
    mdirs = [
        RAW / "multicast_reaggregate_20260915_111200_f2",
        RAW / "multicast_reaggregate_20260915_111200_f32",
        RAW / "multicast_reaggregate_20260915_111300_f16_m5",
        RAW / "multicast_reaggregate_20260915_111300_f16_m20",
        RAW / "multicast_reaggregate_20260915_111300_f16_m60",
    ]
    details = []
    for d in mdirs:
        files = list(d.glob("*_detailed.csv"))
        if len(files) != 1:
            raise SystemExit("missing strict multicast detail in " + str(d))
        sources.append(files[0]); details.extend(read_csv(files[0]))
    # Strict full-drain reaggregation is already enforced by its runner; make
    # the paper-facing acceptance explicit here too.
    if len(details) != 10 or any(r["completed_count"] != "400" or r["measurement_transactions"] != "400" or r["backlog"] != "0" for r in details):
        raise SystemExit("multicast strict full-drain acceptance failed")
    grouped: dict[tuple[str, str], list[dict[str, str]]] = {}
    for r in details: grouped.setdefault((r["fanout"], r["load"]), []).append(r)
    if any(len(v) != 2 or len({r["trace_sha256"] for r in v}) != 1 for v in grouped.values()):
        raise SystemExit("multicast paired trace acceptance failed")
    for r in details:
        r["censored"] = str(r["load"]) == "60"
        r["medium_near_lossless"] = str(r["load"]) == "20"
        r["acceptance"] = "PASS"
    write_csv(out / "multicast_acceptance.csv", details)
    # Compact Fig.64-B: F16 curve plus fanout M5 inset source.
    fig_rows = [r for r in details if r["fanout"] == "16"]
    plt.figure(figsize=(5.2, 3.4))
    for scheme, label, color in (("native", "Native multicast", "#d62728"), ("source_repeated_unicast", "Repeated unicast", "#1f77b4")):
        s = sorted((r for r in fig_rows if r["scheme"] == scheme), key=lambda r: int(r["load"]))
        plt.plot([int(r["load"]) for r in s], [float(r["mean_completion_latency"]) for r in s], marker="o", label=label, color=color)
    plt.xlabel("Load setpoint (Mflit/s/port)"); plt.ylabel("Completion latency (ns)")
    plt.grid(True, ls=":", alpha=.65); plt.legend(fontsize=8); plt.tight_layout()
    plt.savefig(fig / "fig64-b-f16-native-repeated.pdf"); plt.savefig(fig / "fig64-b-f16-native-repeated.png", dpi=220); plt.close()
    write_csv(fig / "fig64_b_multicast_source.csv", details)
    # Copy small derived inputs only; raw sources remain indexed by hash/path.
    index = []
    for src in sources:
        index.append({"source": str(src.relative_to(REPO)).replace("\\", "/"), "sha256": sha(src), "bytes": src.stat().st_size})
    write_csv(out / "source_index.csv", index)
    ur_rows = read_csv(ur / "acceptance.csv")
    if len(ur_rows) != 90 or any(r["pass_fail"] != "PASS" for r in ur_rows):
        raise SystemExit("three-DUT UR acceptance cardinality failed")
    shutil.copy2(ur / "summary.csv", out / "ur_summary.csv")
    shutil.copy2(ur / "acceptance.csv", out / "ur_acceptance.csv")
    shutil.copy2(ur / "saturation_summary.csv", out / "ur_saturation.csv")
    shutil.copy2(router / "summary.json", out / "router_ptpx_summary.json")
    shutil.copy2(router / "metrics.csv", out / "router_ptpx_metrics.csv")
    router_obj = json.loads((router / "summary.json").read_text(encoding="utf-8"))
    router_rows = []
    for artifact in router_obj["artifacts"]:
        stream = artifact["modes"]["stream"]["power"]
        idle = artifact["modes"]["idle"]["power"]
        router_rows.append({
            "design": artifact["kind"], "area_um2": artifact["total_cell_area_um2"],
            "stream_dynamic_power_w": stream.get("dynamic_power_w"),
            "stream_leakage_power_w": stream.get("leakage_power_w"),
            "stream_total_power_w": stream.get("total_power_w"),
            "stream_pj_per_flit": (stream.get("energy_per_delivered_flit_j") or 0) * 1e12,
            "idle_total_power_w": idle.get("total_power_w"),
            "idle_dynamic_power_w": idle.get("dynamic_power_w"),
            "idle_leakage_power_w": idle.get("leakage_power_w"),
            "physical_class": "post-synthesis PT-PX estimate",
        })
    write_csv(out / "router_ppa_table.csv", router_rows)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--short"], cwd=REPO, text=True).strip())
    manifest = {
        "schema": "date2027-compact64-round1-v1", "created_utc": datetime.now(timezone.utc).isoformat(),
        "commit": commit, "dirty": dirty, "ur_points": 90, "multicast_points": 10,
        "router_modes": 8, "excluded": ["paper64_power", "core64_power failed/preflight", "six dependency-invalid E2 PEND jobs"],
        "sources": index,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (out / "RESULTS.md").write_text(
        "# Compact64 round-1 evidence\n\n"
        "- E1: three DUTs, 30 UR points each; saturated PFAT points are throughput-only.\n"
        "- E4/E5: F16 M5/M20/M60 and fanout F2/F16/F32 are strict post-drain 400/400, backlog 0. M60 is censored stress.\n"
        "- E6: Async/Sync c1p4 eight-mode PT-PX-only cleanup reuses accepted GLS VCDs; estimates are post-synthesis.\n"
        "- Excluded: network power preflights/failed core64_power and six invalid-dependency E2 PEND jobs.\n",
        encoding="utf-8")
    print("COMPACT64_ROUND1_PASS", out, fig, flush=True)


if __name__ == "__main__":
    main()
