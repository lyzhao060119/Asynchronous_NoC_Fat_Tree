#!/usr/bin/env python3
"""Generate E2 canonical JSONLs once per point and two paired GLS cases.

Run inside a fresh E2 /prjtemp directory after staging the DATE V3 package.
Never creates or modifies a netlist or invokes DC.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parent
ROOT = SCRIPT_ROOT
candidate_scripts = ROOT / "experiments" / "scripts"
if not candidate_scripts.is_dir():
    candidate_scripts = SCRIPT_ROOT.parents[2] / "DATE paper" / "experiments" / "scripts"
sys.path.insert(0, str(candidate_scripts))

from date_v3.canonical_trace import dump_jsonl, generate_trace, load_jsonl, trace_id  # noqa: E402
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402

LOADS = (5, 10, 20, *range(40, 501, 20), 600, 700, 800)
BENCHMARKS = ("TOPO-BC", "HOTSPOT10")
DESIGNS = ("PROP_temp64", "FM64")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--traces-only", action="store_true")
    parser.add_argument("--materialize-existing", action="store_true")
    parser.add_argument("--root", type=Path)
    parser.add_argument("--load", type=int, action="append")
    parser.add_argument("--benchmark", choices=("TOPO-UR", "TOPO-BC", "HOTSPOT10"), action="append")
    parser.add_argument("--seed", type=int, action="append",
                        help="canonical traffic seed(s); default: 202701")
    parser.add_argument("--design", choices=("PROP_temp64", "FM64", "PFAT64", "SYNC_PROP_temp64_m16"),
                        action="append",
                        help="materialize only the selected design(s); default keeps the original paired E2 set")
    args = parser.parse_args()
    global ROOT
    if args.root:
        ROOT = args.root.resolve()
    (ROOT / "traces").mkdir(parents=True, exist_ok=True)
    (ROOT / "cases").mkdir(parents=True, exist_ok=True)
    rows = []
    selected_loads = tuple(args.load) if args.load else LOADS
    selected_benchmarks = tuple(args.benchmark) if args.benchmark else BENCHMARKS
    selected_seeds = tuple(args.seed) if args.seed else (202701,)
    selected_designs = tuple(args.design) if args.design else DESIGNS
    for benchmark in selected_benchmarks:
        for seed in selected_seeds:
            for load in selected_loads:
                expected_jsonl = ROOT / "traces" / f"{benchmark}_n64_s{seed}_m{load}.jsonl"
                trace = load_jsonl(expected_jsonl) if args.materialize_existing else generate_trace(
                    benchmark, seed=seed, nodes=64, load_point=load
                )
                header = trace["header"]
                assert header["warmup_original_events"] == 1000
                assert header["measurement_original_events"] == 10000
                jsonl = ROOT / "traces" / (trace_id(header) + ".jsonl")
                header_hash = header.get("trace_hash") if args.materialize_existing else dump_jsonl(trace, jsonl)
                canonical_hash = sha256(jsonl)
                if args.traces_only:
                    print("E2_TRACE", benchmark, seed, load, canonical_hash, flush=True)
                    continue
                first_row = len(rows)
                for design in selected_designs:
                    opts = materialize_opts(design)
                    path = materialize_path(
                        jsonl,
                        ROOT / "cases",
                        top_lanes=opts["top_lanes"],
                        routing=opts["routing"],
                        design_id=design,
                        sidecars=False,
                    )
                    rows.append({
                        "benchmark": benchmark,
                        "seed": seed,
                        "load": load,
                        "design": design,
                        "trace_sha256": canonical_hash,
                        "trace_header_hash": header_hash,
                        "case_sha256": sha256(path),
                        "case": path.name,
                    })
                if len(selected_designs) > 1:
                    assert all(row["trace_sha256"] == canonical_hash for row in rows[first_row:])
                print("E2_CASE_SET", benchmark, seed, load, canonical_hash,
                      ",".join(selected_designs), flush=True)
    if args.traces_only:
        print("E2_TRACE_GENERATION_PASS points=%d" %
              (len(selected_benchmarks) * len(selected_seeds) * len(selected_loads)), flush=True)
        return
    if args.load or args.design or args.seed:
        print("E2_SELECTED_GENERATION_PASS points=%d cases=%d" %
              (len(selected_benchmarks) * len(selected_seeds) * len(selected_loads), len(rows)), flush=True)
        return
    assert len(LOADS) == 30 and len(rows) == 120
    (ROOT / "e2_input_manifest.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    print("E2_GENERATION_PASS points=60 cases=120", flush=True)


if __name__ == "__main__":
    main()
