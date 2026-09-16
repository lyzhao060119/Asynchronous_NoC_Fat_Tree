#!/usr/bin/env python3
"""Publish accepted full-drain flit cohorts without modifying historical summaries."""
from __future__ import annotations

import csv
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from reaggregate_flit_latency import reaggregate

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
PAPER64 = REPO / "DATE paper/experiments/raw/paper64"
OLD = PAPER64 / "compact64_20260915_112900"
BC = PAPER64 / "compact64_20260915_000440"
LOW = PAPER64 / "20260913_asap_uc_m5_200_mesh64_pfat64/raw"
PFAT_HIGH = PAPER64 / "pfat64_ur_fill_20260915_110930/cases"
PFAT_FLIT = PAPER64 / "pfat64_flit_latency_20260915_230956/cases"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def newest_archive(prefix: str) -> Path:
    choices = sorted(p for p in PAPER64.glob(prefix + "_*") if p.is_dir() and not p.name.endswith(".staging"))
    if not choices:
        raise RuntimeError("missing archive: " + prefix)
    return choices[-1]


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        raise RuntimeError("empty output: " + str(path))
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)


def raw_for_ur(row: dict[str, str], collected: Path) -> tuple[Path, Path]:
    case = row["case"]
    design = row["design"]
    load = int(row["load_setpoint_mflit_per_port_s"])
    if design == "PFAT64" and load > 200:
        return PFAT_HIGH / case, PFAT_FLIT / case / "flit_latency.csv"
    local = LOW / design / "sdf" / case
    if local.joinpath("flit_latency.csv").is_file():
        return local, local / "flit_latency.csv"
    remote = collected / design / case
    return remote, remote / "flit_latency.csv"


def assert_clean(row: dict[str, str], raw: Path, *, bc: bool = False) -> None:
    run = raw / "run.log"
    if run.is_file():
        text = run.read_text(errors="replace")
        if "TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0" not in text:
            raise RuntimeError("raw TB marker failed: " + str(run))
        if any(token in text for token in ("TB_RESULT FAIL", "TB_HARD_TIMEOUT", "TB_X_FAIL", "Fatal:")):
            raise RuntimeError("raw failure marker: " + str(run))
    elif not bc:
        raise RuntimeError("missing raw run log: " + str(run))
    if bc:
        if row["full_drain_pass"] != "True" or row["sdf_pass"] != "True" or row["trace_pair_pass"] != "True":
            raise RuntimeError("BC/Hotspot acceptance failed: " + row["result_case"])
    else:
        if row["pass_fail"] != "PASS" or int(row["injected_flits"]) != 55000 or int(row["delivered_flits"]) != 55000:
            raise RuntimeError("UR acceptance failed: " + row["case"])
        if any(int(row[key]) for key in ("missing", "unexpected", "timeout")):
            raise RuntimeError("UR error count nonzero: " + row["case"])


def main() -> int:
    collected = newest_archive("ur_cohort_raw")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = PAPER64 / f"cohort64_{stamp}"
    dest.mkdir(parents=True, exist_ok=False)
    with (OLD / "ur_acceptance.csv").open(newline="", encoding="utf-8") as handle:
        ur_old = list(csv.DictReader(handle))
    with (BC / "acceptance.csv").open(newline="", encoding="utf-8") as handle:
        bc_old = list(csv.DictReader(handle))
    ur_rows = []
    for old in ur_old:
        row = dict(old)
        near = old["near_lossless"] == "True"
        if old["design"] == "PFAT64" or near:
            raw, flits = raw_for_ur(old, collected)
            assert_clean(old, raw)
            latency = raw / "latency.csv"
            events = raw / "events.csv"
            for path in (latency, flits, events):
                if not path.is_file() or path.stat().st_size <= 0:
                    raise RuntimeError("missing full-drain raw: " + str(path))
            stats = reaggregate(latency, flits)
            row.update({"cohort_latency_status": "PASS", "latency_contract": stats["metric_contract"],
                        "cohort_measurement_packets": stats["measurement_packets"],
                        "cohort_measurement_flits": stats["measurement_flits"],
                        "cohort_mean_ns": stats["flit_latency_mean_ns"],
                        "cohort_p50_ns": stats["flit_latency_p50_ns"],
                        "cohort_p95_ns": stats["flit_latency_p95_ns"],
                        "cohort_p99_ns": stats["flit_latency_p99_ns"],
                        "cohort_max_ns": stats["flit_latency_max_ns"],
                        "latency_csv_sha256": sha(latency), "flit_csv_sha256": sha(flits),
                        "events_csv_sha256": sha(events), "raw_path": str(raw)})
        else:
            row.update({"cohort_latency_status": "superseded_right_censored",
                        "latency_contract": "", "cohort_measurement_packets": "",
                        "cohort_measurement_flits": "", "cohort_mean_ns": "", "cohort_p50_ns": "",
                        "cohort_p95_ns": "", "cohort_p99_ns": "", "cohort_max_ns": "",
                        "latency_csv_sha256": "", "flit_csv_sha256": "", "events_csv_sha256": "",
                        "raw_path": ""})
        row["paper_latency_eligible"] = near and row["cohort_latency_status"] == "PASS"
        ur_rows.append(row)
        print("COHORT_UR", old["design"], old["load_setpoint_mflit_per_port_s"], row["cohort_latency_status"], flush=True)
    bc_rows = []
    for old in bc_old:
        raw = BC / "raw/logs" / old["design"] / old["result_case"]
        assert_clean(old, raw, bc=True)
        latency, flits, events = (raw / name for name in ("latency.csv", "flit_latency.csv", "events.csv"))
        for path in (latency, flits, events):
            if not path.is_file() or path.stat().st_size <= 0:
                raise RuntimeError("missing BC/Hotspot raw: " + str(path))
        stats = reaggregate(latency, flits)
        row = dict(old)
        row.update({"cohort_latency_status": "PASS", "latency_contract": stats["metric_contract"],
                    "cohort_measurement_packets": stats["measurement_packets"],
                    "cohort_measurement_flits": stats["measurement_flits"],
                    "cohort_mean_ns": stats["flit_latency_mean_ns"],
                    "cohort_p95_ns": stats["flit_latency_p95_ns"],
                    "cohort_p99_ns": stats["flit_latency_p99_ns"],
                    "cohort_max_ns": stats["flit_latency_max_ns"],
                    "latency_csv_sha256": sha(latency), "flit_csv_sha256": sha(flits),
                    "events_csv_sha256": sha(events), "raw_path": str(raw),
                    "paper_latency_eligible": old["near_lossless"] == "True"})
        bc_rows.append(row)
        print("COHORT_BC", old["design"], old["benchmark"], old["load_setpoint_mflit_per_port_s"], flush=True)
    if len(ur_rows) != 90 or len(bc_rows) != 120:
        raise RuntimeError(f"incorrect matrix size: UR={len(ur_rows)} BC/Hotspot={len(bc_rows)}")
    if sum(r["paper_latency_eligible"] for r in ur_rows) != 44:
        raise RuntimeError("pre-saturation cohort count is not 44")
    write_csv(dest / "ur_summary.csv", ur_rows)
    write_csv(dest / "ur_acceptance.csv", ur_rows)
    write_csv(dest / "bc_hotspot_summary.csv", bc_rows)
    write_csv(dest / "bc_hotspot_acceptance.csv", bc_rows)
    write_csv(dest / "latency_supersession.csv", [{"design": r["design"],
        "load": r["load_setpoint_mflit_per_port_s"], "old_metric": "window_censored_flit_latency",
        "new_metric": r["latency_contract"], "status": r["cohort_latency_status"]} for r in ur_rows])
    manifest = {"created_utc": datetime.now(timezone.utc).isoformat(),
                "git_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=REPO)),
                "ur_points": 90, "ur_positive_latency": 44, "bc_hotspot_points": 120,
                "source_ur": str(OLD), "source_bc_hotspot": str(BC), "source_raw": str(collected),
                "historical_files_unchanged": True}
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (dest / "RESULTS.md").write_text(
        "# Full-drain 64-node flit cohort\n\n"
        "UR: 90 accepted throughput points; 44 near-lossless points with new full-drain measurement-offer cohort latency.\n"
        "BC/Hotspot10: 120 accepted points reaggregated from local raw.\n"
        "Each cohort has 10,000 measurement packets and 50,000 measurement flits.\n"
        "Saturated UR latency is superseded/right-censored and excluded from positive latency conclusions.\n",
        encoding="utf-8")
    print(f"COHORT64_FINALIZE_PASS archive={dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
