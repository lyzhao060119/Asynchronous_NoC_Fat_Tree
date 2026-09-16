#!/usr/bin/env python3
"""Audit the existing 12-point common UR grid across PROP_temp64 / PFAT64 / FM64.

Fail-closed for three-DUT claims: only loads present in all three historical
CSVs are compared. Marks provisional / blocked where measurement columns or
SDF evidence are incomplete. Does not invent missing high-load PFAT points.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
FIG = REPO / "DATE paper" / "experiments" / "figures" / "paper64"
PROP_CSV = FIG / "20260914_092324_asap_uc_m5_800_mesh64_prop_temp64" / "aggregated_metrics.csv"
PFAT_CSV = FIG / "20260913_asap_uc_m5_200_mesh64_pfat64" / "aggregated_metrics.csv"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_rows(path: Path, design: str) -> dict[int, dict[str, str]]:
    rows = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            if row["design"] != design:
                continue
            load = int(row["load_setpoint_mflit_per_port_s"])
            rows[load] = row
    return rows


def near_lossless(row: dict[str, str]) -> bool:
    injected = float(row.get("injected_flits") or 0)
    delivered = float(row.get("delivered_flits") or 0)
    backlog = float(row.get("backlog") or 0)
    if injected <= 0:
        return False
    # Historical CSVs use end-of-run backlog, not always measurement backlog.
    ratio = delivered / injected
    return ratio >= 0.99 and backlog <= 5


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        default=REPO
        / "DATE paper"
        / "experiments"
        / "raw"
        / "paper64"
        / ("e1_ur_common12_audit_" + datetime.now().strftime("%Y%m%d_%H%M%S")),
    )
    args = parser.parse_args()
    out: Path = args.out
    if out.exists():
        raise SystemExit("refusing to overwrite %s" % out)

    prop = load_rows(PROP_CSV, "PROP_temp64")
    fm_prop = load_rows(PROP_CSV, "FM64")
    pfat = load_rows(PFAT_CSV, "PFAT64")
    fm_pfat = load_rows(PFAT_CSV, "FM64")
    common = sorted(set(prop) & set(fm_prop) & set(pfat) & set(fm_pfat))
    if len(common) != 12:
        raise SystemExit("expected 12 common loads, got %d: %s" % (len(common), common))

    # FM64 must agree on offered/delivered between the two historical extracts.
    fm_mismatch = []
    for load in common:
        a, b = fm_prop[load], fm_pfat[load]
        keys = (
            "offered_mflit_per_port_s",
            "delivered_mflit_per_port_s",
            "injected_flits",
            "delivered_flits",
        )
        if any(a.get(k) != b.get(k) for k in keys):
            fm_mismatch.append(load)

    rows_out = []
    for load in common:
        trio = {
            "PROP_temp64": prop[load],
            "PFAT64": pfat[load],
            "FM64": fm_prop[load],
        }
        offered = {d: trio[d]["offered_mflit_per_port_s"] for d in trio}
        offered_ok = len(set(offered.values())) == 1
        drain_ok = all(
            trio[d].get("injected_flits") == "55000"
            and trio[d].get("delivered_flits") == "55000"
            and trio[d].get("missing", "0") in ("0", "", None)
            and trio[d].get("unexpected", "0") in ("0", "", None)
            and trio[d].get("timeout", "0") in ("0", "", None)
            for d in trio
        )
        # PFAT historical CSV has sdf_total_errors; PROP/FM 30-pt CSV has pass_fail.
        sdf_ok = (
            pfat[load].get("sdf_total_errors", "0") == "0"
            and prop[load].get("pass_fail", "PASS") == "PASS"
            and fm_prop[load].get("pass_fail", "PASS") == "PASS"
        )
        nl = {d: near_lossless(trio[d]) for d in trio}
        claim = "throughput_and_latency" if all(nl.values()) else "throughput_only_if_saturated"
        if not (offered_ok and drain_ok and sdf_ok and not fm_mismatch):
            status = "blocked_audit"
        elif all(nl.values()):
            status = "accepted_near_lossless_provisional"
        else:
            status = "accepted_throughput_saturation_provisional"
        rows_out.append(
            {
                "load_setpoint_mflit_per_port_s": load,
                "offered_mflit_per_port_s": offered["PROP_temp64"],
                "offered_paired": offered_ok,
                "full_drain_55000": drain_ok,
                "sdf_or_pass_ok": sdf_ok,
                "fm64_cross_csv_match": load not in fm_mismatch,
                "prop_near_lossless": nl["PROP_temp64"],
                "pfat_near_lossless": nl["PFAT64"],
                "fm_near_lossless": nl["FM64"],
                "prop_delivered": trio["PROP_temp64"]["delivered_mflit_per_port_s"],
                "pfat_delivered": trio["PFAT64"]["delivered_mflit_per_port_s"],
                "fm_delivered": trio["FM64"]["delivered_mflit_per_port_s"],
                "prop_lat_mean_ns": trio["PROP_temp64"].get("flit_latency_mean_ns", ""),
                "pfat_lat_mean_ns": trio["PFAT64"].get("flit_latency_mean_ns", ""),
                "fm_lat_mean_ns": trio["FM64"].get("flit_latency_mean_ns", ""),
                "latency_claim": claim if status.startswith("accepted") else "none",
                "status": status,
            }
        )

    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    dirty = bool(
        subprocess.check_output(
            ["git", "status", "--short"], cwd=REPO, text=True, errors="replace"
        ).strip()
    )
    out.mkdir(parents=True)
    fields = list(rows_out[0])
    with (out / "common12_audit.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows_out)
    accepted = sum(1 for r in rows_out if r["status"].startswith("accepted"))
    blocked = sum(1 for r in rows_out if r["status"].startswith("blocked"))
    nl_n = sum(1 for r in rows_out if r["status"] == "accepted_near_lossless_provisional")
    manifest = {
        "schema": "date2027-e1-ur-common12-audit-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "commit": commit,
        "dirty": dirty,
        "sources": {
            "prop_fm_30pt": {"path": str(PROP_CSV.relative_to(REPO)), "sha256": sha256(PROP_CSV)},
            "pfat_fm_12pt": {"path": str(PFAT_CSV.relative_to(REPO)), "sha256": sha256(PFAT_CSV)},
        },
        "common_loads": common,
        "rows": len(rows_out),
        "accepted": accepted,
        "blocked": blocked,
        "near_lossless_provisional": nl_n,
        "fm64_cross_csv_mismatches": fm_mismatch,
        "limitations": [
            "PFAT64 high-load points 220..800 still missing; no three-DUT full-grid claim",
            "Historical backlog column is end-of-run, not always measurement backlog",
            "Raw per-case latency/events/SDF logs not re-fetched in this audit",
            "Status is provisional pending unified raw re-archive",
        ],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# E1 UR common-12 audit (provisional)",
        "",
        "Three-DUT overlap only: loads %s." % ", ".join("M%d" % x for x in common),
        "",
        "Accepted provisional rows: %d / 12 (near-lossless latency-eligible: %d)."
        % (accepted, nl_n),
        "Blocked: %d. FM64 cross-CSV mismatches: %s."
        % (blocked, fm_mismatch or "none"),
        "",
        "This does **not** complete E1. PFAT64 still needs M220–M800 fill on frozen netlist",
        "`20260912_195012_cmr_pfat64_rpsdel050_1248`, then a unified raw archive.",
        "",
    ]
    (out / "RESULTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("E1_COMMON12_AUDIT_OK out=%s accepted=%d blocked=%d nl=%d" % (out, accepted, blocked, nl_n), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
