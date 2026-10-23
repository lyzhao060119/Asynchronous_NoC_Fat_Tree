#!/usr/bin/env python3
"""Generate the frozen five-benchmark 64-node multicast campaign.

Designed to run in the remote campaign directory.  Canonical traces are made
once and materialized for all four DUTs; raw cases never need to be local.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
candidate = HERE / "experiments" / "scripts"
if not candidate.is_dir():
    candidate = HERE.parents[2] / "DATE_paper" / "experiments" / "scripts"
sys.path.insert(0, str(candidate))

from date_v3.canonical_trace import dump_jsonl, generate_trace, trace_id  # noqa: E402
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.materialize_case import cores_in_rect, materialize_path  # noqa: E402

LOADS = (5, 10, 20, *range(40, 501, 20), 600, 700, 800)
SEEDS = (202701, 202702, 202703)
BENCHMARKS = (
    "MULTICAST5-AABB",
    "MULTICAST10-AABB",
    "MULTICAST-STATIC-AABB",
    "ALL-MULTICAST-AABB",
    "ALL-BROADCAST",
)
DESIGNS = ("PROP_temp64_m16", "SYNC_PROP_temp64_m16", "FM64", "PFAT64")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def audit_trace(trace: dict) -> dict:
    events = trace["events"]
    counts: dict[int, int] = {}
    for event in events:
        destinations = set(map(int, event["destinations"]))
        if int(event["source"]) in destinations:
            raise ValueError("source appears in destination set")
        fanout = len(destinations)
        counts[fanout] = counts.get(fanout, 0) + 1
        if trace["header"]["benchmark_id"] == "ALL-BROADCAST":
            if destinations != set(range(64)) - {int(event["source"])}:
                raise ValueError("broadcast is not exactly the 63 non-source cores")
        else:
            delivered = set(cores_in_rect(list(event["rect"]), 8)) - {int(event["source"])}
            if destinations != delivered:
                raise ValueError("AABB would add or remove destinations")
    return {"events": len(events), "fanout_counts": counts}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--seed", type=int, action="append")
    parser.add_argument("--load", type=int, action="append")
    parser.add_argument("--benchmark", choices=BENCHMARKS, action="append")
    args = parser.parse_args()
    root = args.root.resolve()
    traces = root / "traces"
    cases = root / "cases"
    traces.mkdir(parents=True, exist_ok=True)
    cases.mkdir(parents=True, exist_ok=True)
    seeds = tuple(args.seed or SEEDS)
    loads = tuple(args.load or LOADS)
    benchmarks = tuple(args.benchmark or BENCHMARKS)
    if any(seed not in SEEDS for seed in seeds) or any(load not in LOADS for load in loads):
        raise SystemExit("seed/load is outside the frozen campaign")

    rows = []
    trace_rows = []
    for benchmark in benchmarks:
        for seed in seeds:
            for load in loads:
                trace = generate_trace(benchmark, seed=seed, nodes=64, load_point=load)
                audit = audit_trace(trace)
                jsonl = traces / (trace_id(trace["header"]) + ".jsonl")
                dump_jsonl(trace, jsonl)
                trace_hash = sha256(jsonl)
                trace_rows.append({
                    "benchmark": benchmark, "seed": seed, "load": load,
                    "trace": jsonl.name, "trace_sha256": trace_hash,
                    "events": audit["events"],
                    "fanout_counts": json.dumps(audit["fanout_counts"], sort_keys=True),
                })
                for design in DESIGNS:
                    opts = materialize_opts(design)
                    case = materialize_path(
                        jsonl, cases, top_lanes=opts["top_lanes"],
                        routing=opts["routing"], design_id=design, sidecars=False,
                    )
                    rows.append({
                        "benchmark": benchmark, "seed": seed, "load": load,
                        "design": design, "top_lanes": opts["top_lanes"],
                        "trace_sha256": trace_hash, "case": case.name,
                        "case_sha256": sha256(case),
                    })
                print("FORMAL64_MC_POINT", benchmark, seed, load, trace_hash, flush=True)

    with (root / "trace_manifest.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=trace_rows[0].keys())
        writer.writeheader(); writer.writerows(trace_rows)
    with (root / "case_manifest.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader(); writer.writerows(rows)
    manifest = {
        "schema": "formal64-multicast-input-v1", "loads": list(loads),
        "seeds": list(seeds), "benchmarks": list(benchmarks),
        "designs": list(DESIGNS), "trace_count": len(trace_rows),
        "case_count": len(rows), "source_queue_included_in_latency": True,
        "fanout_policy": "equal_probability_exact_AABB_2_4_8_16; broadcast=63",
    }
    (root / "input_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    expected_traces = len(benchmarks) * len(seeds) * len(loads)
    expected_cases = expected_traces * len(DESIGNS)
    if len(trace_rows) != expected_traces or len(rows) != expected_cases:
        raise RuntimeError("campaign count mismatch")
    print(f"FORMAL64_MULTICAST_GENERATION_PASS traces={expected_traces} cases={expected_cases}")


if __name__ == "__main__":
    main()
