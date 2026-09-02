#!/usr/bin/env python3
"""Build unified V3 event JSONL + Tmax/saturation rows from async TB CSVs."""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.event_record import (  # noqa: E402
    assemble_event_records,
    dump_event_jsonl,
    run_metrics,
    validate_event_record,
)
from date_v3.saturation import hrep_common_tmax_load, next_fine_loads, saturation_point  # noqa: E402
from date_v3.stats import bootstrap_ci, seed_summary  # noqa: E402


def load_v3_summary(path: Path | None) -> dict:
    if path is None or not path.is_file():
        return {}
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packets", type=Path, required=True)
    parser.add_argument("--latency", type=Path)
    parser.add_argument("--events", type=Path)
    parser.add_argument("--v3-summary", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--metrics-out", type=Path)
    parser.add_argument("--include-warmup", action="store_true")
    parser.add_argument("--sweep", type=Path, help="JSON list of per-seed load rows")
    parser.add_argument("--seeds", type=int, nargs="*")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    records = assemble_event_records(
        packets_json=args.packets,
        latency_csv=args.latency,
        event_csv=args.events,
        include_warmup=args.include_warmup,
    )
    for rec in records:
        validate_event_record(rec, label=str(rec.get("original_event_id")))
    dump_event_jsonl(records, args.out)
    summary = load_v3_summary(args.v3_summary)
    metrics = run_metrics(records, v3_summary=summary)
    payload = {"event_jsonl": str(args.out), "metrics": metrics}
    if args.sweep and args.sweep.is_file():
        rows = json.loads(args.sweep.read_text(encoding="utf-8"))
        seeds = tuple(args.seeds) if args.seeds else tuple(sorted({int(r["seed"]) for r in rows}))
        sat = saturation_point(rows, seeds=seeds)
        payload["saturation"] = sat
        payload["next_fine_loads"] = next_fine_loads(rows, seeds=seeds)
        if sat is not None:
            payload["hrep_common_tmax_load"] = hrep_common_tmax_load(sat["offered_load"])
        if all("seed" in row for row in rows) and sat is not None:
            payload["seed_summary"] = seed_summary(rows, value_key="delivered_throughput", seeds=seeds)
        tmax_values = [rec["tmax_ns"] for rec in records if rec.get("tmax_ns") is not None]
        if len(tmax_values) >= 32:
            payload["tmax_bootstrap_95"] = bootstrap_ci(tmax_values, seed=0)
    if args.metrics_out:
        args.metrics_out.parent.mkdir(parents=True, exist_ok=True)
        args.metrics_out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print("METRICS", args.metrics_out, flush=True)
    print("EVENT_JSONL", args.out, "events", len(records), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
