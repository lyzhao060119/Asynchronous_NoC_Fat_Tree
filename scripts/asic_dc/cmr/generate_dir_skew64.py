#!/usr/bin/env python3
"""Generate the eight paired DIR-SKEW1 canonical traces and PROP cases."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))

from date_v3.canonical_trace import dump_jsonl, generate_trace, trace_id  # noqa: E402
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402

LOADS = (5, 60, 100, 120, 140, 160, 180, 200)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    (root / "traces").mkdir(parents=True, exist_ok=False)
    (root / "cases").mkdir(parents=True, exist_ok=False)
    opts = materialize_opts("PROP_temp64")
    rows = []
    for load in LOADS:
        trace = generate_trace("DIR-SKEW1", seed=202701, nodes=64, load_point=load)
        path = root / "traces" / (trace_id(trace["header"]) + ".jsonl")
        dump_jsonl(trace, path)
        case = materialize_path(path, root / "cases", top_lanes=opts["top_lanes"],
                                routing=opts["routing"], design_id="PROP_temp64",
                                sidecars=False)
        rows.append({"load": load, "trace": path.name, "trace_sha256": sha256(path),
                     "case": case.name, "case_sha256": sha256(case)})
    if len(rows) != 8 or any(row["load"] != LOADS[i] for i, row in enumerate(rows)):
        raise RuntimeError("DIR-SKEW1 cardinality/order gate failed")
    (root / "input_manifest.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    print("DIR_SKEW_GENERATION_PASS points=8 paired_cases=16 shared_case_files=8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
