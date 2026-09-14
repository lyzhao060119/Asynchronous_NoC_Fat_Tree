#!/usr/bin/env python3
"""Generate E2 canonical JSONLs once per point and two paired GLS cases.

Run inside a fresh E2 /prjtemp directory after staging the DATE V3 package.
Never creates or modifies a netlist or invokes DC.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "experiments" / "scripts"))

from date_v3.canonical_trace import dump_jsonl, generate_trace, trace_id  # noqa: E402
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
    (ROOT / "traces").mkdir(exist_ok=True)
    (ROOT / "cases").mkdir(exist_ok=True)
    rows = []
    for benchmark in BENCHMARKS:
        for load in LOADS:
            trace = generate_trace(benchmark, seed=202701, nodes=64, load_point=load)
            header = trace["header"]
            assert header["warmup_original_events"] == 1000
            assert header["measurement_original_events"] == 10000
            jsonl = ROOT / "traces" / (trace_id(header) + ".jsonl")
            header_hash = dump_jsonl(trace, jsonl)
            canonical_hash = sha256(jsonl)
            for design in DESIGNS:
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
                    "load": load,
                    "design": design,
                    "trace_sha256": canonical_hash,
                    "trace_header_hash": header_hash,
                    "case_sha256": sha256(path),
                    "case": path.name,
                })
            assert rows[-1]["trace_sha256"] == rows[-2]["trace_sha256"]
            print("E2_CASE_PAIR", benchmark, load, canonical_hash, flush=True)
    assert len(LOADS) == 30 and len(rows) == 120
    (ROOT / "e2_input_manifest.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    print("E2_GENERATION_PASS points=60 cases=120", flush=True)


if __name__ == "__main__":
    main()
