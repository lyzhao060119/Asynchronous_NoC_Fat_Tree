#!/usr/bin/env python3
"""Materialize 256-node whole-network GLS cases (seed 900001).

Smoke directed (KEY-256), TAB-like random unicast (TOPO-UR), and
VCTM-like mixed multicast (MC-UR).  Does not submit LSF.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from random import Random

SCRIPTS = Path(__file__).resolve().parent
MODEL = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.canonical_trace import (  # noqa: E402
    PACKET_FLITS,
    TRACE_SCHEMA,
    ZERO_LOAD_GAP,
    bounding_rect,
    build_events,
    choose_other,
    dump_jsonl,
    generate_trace,
    schedule_pairs,
    seed_mix,
    width_of,
)
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.hashutil import write_json  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from date_v3.offered_load import (  # noqa: E402
    GATE_CD_LOW_LOAD,
    GATE_CD_MC_LOAD,
    GATE_CD_MEDIUM_LOAD,
    GATE_CD_NEAR_SAT_LOAD,
    load_tag,
    load_tag_int,
    trace_load_fields,
)
from date_v3.paths import INTERMEDIATE  # noqa: E402

try:
    from des import CALIBRATION_SEED  # noqa: E402
except ImportError:
    CALIBRATION_SEED = 900001

CAL256 = ("PROP256", "FM256")
OUT = INTERMEDIATE / "des_calibration"


def directed_corners(*, nodes: int, seed: int, corners: list[int], random_unicasts: int) -> dict:
    width = width_of(nodes)
    pairs: list[dict] = []
    seen: set[tuple[int, int]] = set()
    for src in corners:
        for dest in corners:
            if src == dest:
                continue
            key = (src, dest)
            if key in seen:
                continue
            seen.add(key)
            pairs.append(
                {
                    "source": src,
                    "destinations": [dest],
                    "rect": bounding_rect([dest], width),
                    "multicast": False,
                }
            )
    rng = Random(seed_mix(seed, nodes, 0, 9))
    added = 0
    spins = 0
    while added < random_unicasts and spins < max(32, random_unicasts * 32):
        spins += 1
        src = rng.randrange(nodes)
        dest = choose_other(rng, src, nodes)
        key = (src, dest)
        if key in seen:
            continue
        seen.add(key)
        pairs.append(
            {
                "source": src,
                "destinations": [dest],
                "rect": bounding_rect([dest], width),
                "multicast": False,
            }
        )
        added += 1
    ready = [idx * (PACKET_FLITS + ZERO_LOAD_GAP) for idx in range(len(pairs))]
    events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": "KEY-%d" % nodes,
        "traffic": "directed_keycase",
        "nodes": nodes,
        "seed": seed,
        "seed_set_id": "v3_calibration_seed",
        "packet_flits": PACKET_FLITS,
        "warmup_original_events": 0,
        "measurement_original_events": len(events),
        "spread_S": None,
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
    }
    header.update(trace_load_fields(0.0))
    return {"header": header, "events": events}


def _pilot_trace_jobs() -> list[tuple[str, object]]:
    return [
        (
            "KEY-256_n256_s900001_corners.jsonl",
            lambda: directed_corners(
                nodes=256, seed=CALIBRATION_SEED, corners=[0, 15, 240, 255], random_unicasts=4
            ),
        ),
        (
            "TOPO-UR_n256_s900001_zero.jsonl",
            lambda: generate_trace(
                "TOPO-UR", seed=CALIBRATION_SEED, nodes=256, smoke=True, load_point=0.0
            ),
        ),
        (
            "TOPO-UR_n256_s900001_%s.jsonl" % load_tag(GATE_CD_LOW_LOAD),
            lambda: generate_trace(
                "TOPO-UR",
                seed=CALIBRATION_SEED,
                nodes=256,
                smoke=True,
                load_point=GATE_CD_LOW_LOAD,
            ),
        ),
        (
            "TOPO-UR_n256_s900001_%s.jsonl" % load_tag(GATE_CD_MEDIUM_LOAD),
            lambda: generate_trace(
                "TOPO-UR",
                seed=CALIBRATION_SEED,
                nodes=256,
                smoke=True,
                load_point=GATE_CD_MEDIUM_LOAD,
            ),
        ),
        (
            "TOPO-UR_n256_s900001_%s.jsonl" % load_tag(GATE_CD_NEAR_SAT_LOAD),
            lambda: generate_trace(
                "TOPO-UR",
                seed=CALIBRATION_SEED,
                nodes=256,
                smoke=True,
                load_point=GATE_CD_NEAR_SAT_LOAD,
            ),
        ),
        ("MC-UR_n256_s900001_%s.jsonl" % load_tag(GATE_CD_MC_LOAD), None),
    ]


def mixed_multicast_smoke(
    *,
    nodes: int = 256,
    seed: int = CALIBRATION_SEED,
    load_point: float = GATE_CD_MC_LOAD,
    count: int = 16,
    multicast_fraction: float = 0.10,
    fanout: int = 4,
) -> dict:
    """VCTM-like mixed unicast/multicast smoke (5-flit, calibration seed)."""
    width = width_of(nodes)
    rng = Random(seed_mix(seed, nodes, 77, 1))
    pairs = []
    for _ in range(count):
        source = rng.randrange(nodes)
        if rng.random() < multicast_fraction:
            want = rng.randint(2, min(fanout, 4))
            dests: list[int] = []
            spins = 0
            while len(dests) < want and spins < 64:
                spins += 1
                d = rng.randrange(nodes)
                if d == source or d in dests:
                    continue
                dests.append(d)
            if len(dests) < 2:
                dests = [choose_other(rng, source, nodes)]
                multicast = False
            else:
                multicast = True
        else:
            dests = [choose_other(rng, source, nodes)]
            multicast = False
        pairs.append(
            {
                "source": source,
                "destinations": dests,
                "rect": bounding_rect(dests, width),
                "multicast": multicast,
            }
        )
    sched_rng = Random(seed_mix(seed, nodes, 77, load_tag_int(load_point)))
    ready = schedule_pairs(
        pairs, nodes=nodes, packet_flits=PACKET_FLITS, load_point=load_point, rng=sched_rng
    )
    events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": "MC-UR",
        "traffic": "mixed_multicast_smoke",
        "nodes": nodes,
        "seed": seed,
        "seed_set_id": "v3_calibration_seed",
        "packet_flits": PACKET_FLITS,
        "warmup_original_events": 0,
        "measurement_original_events": count,
        "multicast_fraction": multicast_fraction,
        "fanout_F": fanout,
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
    }
    header.update(trace_load_fields(load_point))
    return {"header": header, "events": events}


def ensure_extra_traces(traces: Path) -> None:
    traces.mkdir(parents=True, exist_ok=True)
    for name, factory in _pilot_trace_jobs():
        path = traces / name
        if path.is_file():
            continue
        trace = mixed_multicast_smoke() if factory is None else factory()
        dump_jsonl(trace, path)
        print("TRACE", path.name, flush=True)


def emit_for_design(design_id: str, traces: Path, cases: Path) -> list[str]:
    opts = materialize_opts(design_id)
    stems: list[str] = []
    jsonl_names = [name for name, _factory in _pilot_trace_jobs()]
    for jsonl_name in jsonl_names:
        jsonl = traces / jsonl_name
        if not jsonl.is_file():
            raise SystemExit("missing trace %s (run prepare_descal first)" % jsonl)
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--case-out", type=Path, default=None)
    parser.add_argument("--design", action="append", choices=list(CAL256))
    parser.add_argument(
        "--skip-prepare",
        action="store_true",
        help="Do not invoke prepare_descal.py (pilot traces are generated here if missing)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    out = args.out
    traces = out / "traces"
    cases = args.case_out if args.case_out is not None else (out / "cases")
    cases.mkdir(parents=True, exist_ok=True)
    if not args.skip_prepare:
        rc = subprocess.call(
            [sys.executable, str(SCRIPTS / "prepare_descal.py"), "--out", str(out)],
            cwd=str(SCRIPTS.parents[2]),
        )
        if rc != 0:
            return rc
    ensure_extra_traces(traces)
    designs = tuple(args.design) if args.design else CAL256
    manifest: dict[str, list[str]] = {}
    for design_id in designs:
        manifest[design_id] = emit_for_design(design_id, traces, cases)
    write_json(out / "network256_gls_cases.json", manifest)
    print("NETWORK256_GLS_CASES", json.dumps(manifest), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
