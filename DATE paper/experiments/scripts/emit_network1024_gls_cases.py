#!/usr/bin/env python3
"""Materialize 1024-node PROP GLS cases (seed 900001). Does not submit LSF or FM1024."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MODEL = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.canonical_trace import dump_jsonl, generate_trace  # noqa: E402
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.hashutil import write_json  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from date_v3.offered_load import (  # noqa: E402
    GATE_CD_LOW_LOAD,
    GATE_CD_MC_LOAD,
    GATE_CD_MEDIUM_LOAD,
    GATE_CD_NEAR_SAT_LOAD,
    load_tag,
)
from date_v3.paths import INTERMEDIATE  # noqa: E402
from des import CALIBRATION_SEED  # noqa: E402
from emit_network256_gls_cases import mixed_multicast_smoke  # noqa: E402
from prepare_descal import directed_corners  # noqa: E402

OUT = INTERMEDIATE / "des_calibration"
DESIGN_ID = "PROP1024"
# 32x32 corners, same smoke scale as KEY-256 (4 corners + 4 random unicasts).
KEY_CORNERS = [0, 31, 992, 1023]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    return parser.parse_args()


def ensure_traces(traces: Path) -> list[str]:
    traces.mkdir(parents=True, exist_ok=True)
    names = []
    key = traces / "KEY-1024_n1024_s900001_corners.jsonl"
    dump_jsonl(
        directed_corners(
            nodes=1024,
            seed=CALIBRATION_SEED,
            corners=KEY_CORNERS,
            random_unicasts=4,
        ),
        key,
    )
    names.append(key.name)
    print("TRACE", key.name, flush=True)

    extras = (
        (
            "TOPO-UR_n1024_s900001_zero.jsonl",
            lambda: generate_trace(
                "TOPO-UR", seed=CALIBRATION_SEED, nodes=1024, smoke=True, load_point=0.0
            ),
        ),
        (
            "TOPO-UR_n1024_s900001_%s.jsonl" % load_tag(GATE_CD_LOW_LOAD),
            lambda: generate_trace(
                "TOPO-UR", seed=CALIBRATION_SEED, nodes=1024, smoke=True, load_point=GATE_CD_LOW_LOAD
            ),
        ),
        (
            "TOPO-UR_n1024_s900001_%s.jsonl" % load_tag(GATE_CD_MEDIUM_LOAD),
            lambda: generate_trace(
                "TOPO-UR", seed=CALIBRATION_SEED, nodes=1024, smoke=True, load_point=GATE_CD_MEDIUM_LOAD
            ),
        ),
        (
            "TOPO-UR_n1024_s900001_%s.jsonl" % load_tag(GATE_CD_NEAR_SAT_LOAD),
            lambda: generate_trace(
                "TOPO-UR", seed=CALIBRATION_SEED, nodes=1024, smoke=True, load_point=GATE_CD_NEAR_SAT_LOAD
            ),
        ),
        (
            "MC-UR_n1024_s900001_%s.jsonl" % load_tag(GATE_CD_MC_LOAD),
            lambda: mixed_multicast_smoke(nodes=1024, seed=CALIBRATION_SEED, load_point=GATE_CD_MC_LOAD),
        ),
    )
    for name, factory in extras:
        path = traces / name
        dump_jsonl(factory(), path)
        names.append(name)
        print("TRACE", name, flush=True)
    return ["KEY-1024_n1024_s900001_corners.jsonl"] + [name for name, _ in extras]


def emit_for_design(design_id: str, traces: Path, cases: Path, jsonl_names: list[str]) -> list[str]:
    opts = materialize_opts(design_id)
    stems: list[str] = []
    for jsonl_name in jsonl_names:
        jsonl = traces / jsonl_name
        if not jsonl.is_file():
            raise SystemExit("missing trace %s" % jsonl)
        case_path = materialize_path(
            jsonl,
            cases,
            top_lanes=opts["top_lanes"],
            hrep=opts["hrep"],
            routing=opts["routing"],
            design_id=design_id,
        )
        stems.append(case_path.stem)
        print("CASE", design_id, case_path.name, flush=True)
    return stems


def main() -> int:
    args = parse_args()
    out = args.out
    traces = out / "traces"
    cases = out / "cases"
    cases.mkdir(parents=True, exist_ok=True)
    jsonl_names = ensure_traces(traces)
    manifest = {DESIGN_ID: emit_for_design(DESIGN_ID, traces, cases, jsonl_names)}
    write_json(out / "network1024_gls_cases.json", manifest)
    print("NETWORK1024_GLS_CASES", json.dumps(manifest), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
