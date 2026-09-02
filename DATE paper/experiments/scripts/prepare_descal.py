#!/usr/bin/env python3
"""Build the DATE V3 Phase 5 DES-side calibration pack (seed 900001).

Writes traces, RTL .case / model JSON, and DES event JSONL under
intermediate/des_calibration/.  Does not submit LSF.  Does not use paper
seeds.  Network MAXIMUM-SDF comparison is --rtl-dir / run_descal_gls.py.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from random import Random
from typing import Any

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
    seed_mix,
    width_of,
)
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.event_record import dump_event_jsonl  # noqa: E402
from date_v3.hashutil import write_json  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from date_v3.paths import INTERMEDIATE  # noqa: E402
from des import CALIBRATION_SEED, MODEL_VERSION, PAPER_SEEDS, PHYSICAL_CLASS  # noqa: E402
from des.run import oracle_errors, simulate  # noqa: E402
from des.timing import TimingTable  # noqa: E402

CAL64 = ("THIN64", "PROP64", "PFAT64", "FM64")
CAL256 = ("PROP256", "FM256")
OUT = INTERMEDIATE / "des_calibration"

DUT_STATUS = {
    "THIN64": {
        "network_sdf": "need_dc",
        "note": (
            "No signed async Thin64 network netlist with locked DEL050. "
            "noc64 runner emits CMR_Q64_PROFILE=thin then hierarchical unique-router "
            "DC or one full-network DC. Do not reuse Ackin-250 Fat NoC64."
        ),
    },
    "PROP64": {
        "network_sdf": "have_del050_netlist_need_v3_gls",
        "netlist_run_id": "20260830_132453_cmr_noc64_1222_ackin50_p50_1222",
        "note": (
            "Remote Fat 1-2-2-2 post.v+SDF exists with uniquified Ackin DelayUnitPs50 "
            "(146 AckinDelay). Do not overwrite that directory. Do not SKIP_DC "
            "20260830_095259_cmr_noc64_p50_1222 (Ackin-250). V3 5-flit GLS still required "
            "on a new cmr_descal_ run ID."
        ),
    },
    "PFAT64": {
        "network_sdf": "need_dc",
        "note": (
            "Fat 1-2-4-8 network GLS is enabled. Probe remote *1248* for DelayUnitPs50 "
            "before SKIP_DC; otherwise hierarchical unique-router DC or one full-network DC."
        ),
    },
    "FM64": {
        "network_sdf": "have_candidate_need_recipe_check",
        "netlist_run_id": "20260831_115856_cmr_mesh64_p50",
        "note": (
            "mesh64 20260831_115856 is a read-only candidate if Ackin is DelayUnitPs50. "
            "Do not overwrite that directory. Otherwise hierarchical unique-router DC "
            "or one full-network DC on a new cmr_descal_ ID."
        ),
    },
    "PROP256": {
        "network_sdf": "pending_whole_network",
        "note": "V3.1.0: 256-node paper data requires whole-network logic synthesis and maximum-delay gate-level simulation. RTL key-case is not paper evidence.",
    },
    "FM256": {
        "network_sdf": "pending_whole_network",
        "note": "V3.1.0: 256-node paper data requires whole-network logic synthesis and maximum-delay gate-level simulation. RTL key-case is not paper evidence.",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument(
        "--quick",
        action="store_true",
        help="THIN64 directed + PROP256 two corners only (unit / infra gate)",
    )
    return parser.parse_args()


def directed_corners(*, nodes: int, seed: int, corners: list[int], random_unicasts: int) -> dict[str, Any]:
    width = width_of(nodes)
    pairs: list[dict[str, Any]] = []
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
        "offered_load": 0.0,
        "load_tag": "zero",
        "spread_S": None,
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
    }
    return {"header": header, "events": events}


def _write_des(out: Path, design_id: str, tag: str, result: dict) -> Path:
    folder = out / "des" / design_id / tag
    folder.mkdir(parents=True, exist_ok=True)
    dump_event_jsonl(result["records"], folder / "events.jsonl")
    slim = {k: v for k, v in result.items() if k != "records"}
    write_json(folder / "result.json", slim)
    return folder / "events.jsonl"


def _simulate(design_id: str, packets: list[dict], timing: TimingTable) -> dict:
    _sim, result = simulate(design_id, packets, timing=timing, arb_seed=CALIBRATION_SEED)
    result["oracle_errors"] = oracle_errors(design_id, packets, result["records"])
    return result


def _materialize_job(design_id: str, tag: str, jsonl: Path, cases: Path, zero: bool) -> tuple:
    opts = materialize_opts(design_id)
    case_path = materialize_path(
        jsonl,
        cases,
        top_lanes=opts["top_lanes"],
        hrep=opts["hrep"],
        routing=opts["routing"],
        design_id=design_id,
    )
    model = json.loads(case_path.with_suffix(".model.json").read_text(encoding="utf-8"))
    return (design_id, tag, model["packets"], zero, case_path)


def main() -> int:
    args = parse_args()
    if CALIBRATION_SEED in PAPER_SEEDS:
        print("FAIL calibration seed collides with paper seeds", flush=True)
        return 2
    timing = TimingTable()
    out = args.out
    traces = out / "traces"
    cases = out / "cases"
    traces.mkdir(parents=True, exist_ok=True)
    cases.mkdir(parents=True, exist_ok=True)
    (out / "rtl").mkdir(parents=True, exist_ok=True)
    jobs = []

    if args.quick:
        p64 = traces / "KEY-64_n64_s900001_quick.jsonl"
        dump_jsonl(
            directed_corners(nodes=64, seed=CALIBRATION_SEED, corners=[0, 63], random_unicasts=0),
            p64,
        )
        jobs.append(_materialize_job("THIN64", "directed", p64, cases, True))
        p256 = traces / "KEY-256_n256_s900001_quick.jsonl"
        dump_jsonl(
            directed_corners(nodes=256, seed=CALIBRATION_SEED, corners=[0, 255], random_unicasts=0),
            p256,
        )
        jobs.append(_materialize_job("PROP256", "directed", p256, cases, True))
    else:
        p64 = traces / "KEY-64_n64_s900001.jsonl"
        dump_jsonl(
            directed_corners(
                nodes=64, seed=CALIBRATION_SEED, corners=[0, 7, 56, 63], random_unicasts=8
            ),
            p64,
        )
        z64 = traces / "TOPO-UR_n64_s900001_zero.jsonl"
        dump_jsonl(
            generate_trace("TOPO-UR", seed=CALIBRATION_SEED, nodes=64, smoke=True, load_point=0.0),
            z64,
        )
        l64 = traces / "TOPO-UR_n64_s900001_r0p10.jsonl"
        dump_jsonl(
            generate_trace("TOPO-UR", seed=CALIBRATION_SEED, nodes=64, smoke=True, load_point=0.10),
            l64,
        )
        for design_id in CAL64:
            jobs.append(_materialize_job(design_id, "directed", p64, cases, True))
            jobs.append(_materialize_job(design_id, "zero", z64, cases, True))
            jobs.append(_materialize_job(design_id, "loaded", l64, cases, False))

        p256 = traces / "KEY-256_n256_s900001_corners.jsonl"
        dump_jsonl(
            directed_corners(
                nodes=256, seed=CALIBRATION_SEED, corners=[0, 15, 240, 255], random_unicasts=4
            ),
            p256,
        )
        u256 = traces / "TOPO-UR_n256_s900001_r0p05.jsonl"
        dump_jsonl(
            generate_trace("TOPO-UR", seed=CALIBRATION_SEED, nodes=256, smoke=True, load_point=0.05),
            u256,
        )
        m256 = traces / "TOPO-UR_n256_s900001_r0p10.jsonl"
        dump_jsonl(
            generate_trace("TOPO-UR", seed=CALIBRATION_SEED, nodes=256, smoke=True, load_point=0.10),
            m256,
        )
        for design_id in CAL256:
            jobs.append(_materialize_job(design_id, "directed", p256, cases, True))
            jobs.append(_materialize_job(design_id, "low", u256, cases, False))
            jobs.append(_materialize_job(design_id, "mid", m256, cases, False))

    reports = []
    failed = []
    for design_id, tag, packets, _zero, case_path in jobs:
        print("DES", design_id, tag, "packets", len(packets), flush=True)
        result = _simulate(design_id, packets, timing)
        path = _write_des(out, design_id, tag, result)
        ok = not result["errors"] and not result.get("oracle_errors")
        if not ok:
            failed.append("%s/%s" % (design_id, tag))
        reports.append(
            {
                "design_id": design_id,
                "tag": tag,
                "zero_load": bool(_zero),
                "case": str(case_path) if case_path else None,
                "packets_json": str(case_path.with_suffix(".packets.json")) if case_path else None,
                "des_events": str(path),
                "n_events": len(result["records"]),
                "n_packets": len(packets),
                "errors": result["errors"],
                "oracle_errors": result.get("oracle_errors") or [],
                "pass": ok,
            }
        )
        print("DES", design_id, tag, "PASS" if ok else "FAIL", flush=True)

    matrix = {
        "schema": "date-v3-descal-pack-v1",
        "model_version": MODEL_VERSION,
        "physical_class": PHYSICAL_CLASS,
        "calibration_seed": CALIBRATION_SEED,
        "paper_seeds_excluded": list(PAPER_SEEDS),
        "quick": bool(args.quick),
        "dut_status": DUT_STATUS,
        "jobs": reports,
        "failed": failed,
        "rtl_dir": str(out / "rtl"),
        "notes": (
            "DES-side pack only. Copy GLS/RTL events.jsonl to rtl/<design_id>/<tag>/events.jsonl "
            "then run calibrate_des.py --pack this directory --write-lock. "
            "Do not use 3-flit archive GLS. Do not overwrite frozen hop/Sync64 IDs. "
            "Ackin-250 NoC64 is not a timing-cal netlist. "
            "paper_matrix_allowed stays false until 64 and 256 MAXIMUM-SDF compares pass §21."
        ),
    }
    write_json(out / "matrix.json", matrix)
    print(json.dumps({"failed": failed, "jobs": len(reports), "out": str(out), "quick": args.quick}), flush=True)
    if failed:
        return 1
    print("PHASE5_DESCAL_PACK_PASS", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
