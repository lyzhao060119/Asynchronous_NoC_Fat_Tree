#!/usr/bin/env python3
"""DATE V3 traffic generator: canonical JSONL, then RTL .case / model input.

Paired async/sync 64-node designs share one canonical trace.  Do not fold
these traces into sim/AsyncNoC/testbench/gen_cases_noc64.py.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.canonical_trace import (  # noqa: E402
    dump_jsonl,
    generate_directed_keycase,
    generate_trace,
    load_benchmark,
    load_seeds,
    paper_nodes_for,
    trace_id,
)
from date_v3.designs import NETWORK_IDS, materialize_opts  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from date_v3.paths import INTERMEDIATE  # noqa: E402
from date_v3.saturation import coarse_loads  # noqa: E402

BENCHMARKS = (
    "BF-STRESS64",
    "TOPO-UR",
    "XMC-F16",
    "XMC10-G",
    "MESH-INTERCLUSTER-UR",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark", choices=BENCHMARKS, action="append")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--nodes", type=int)
    parser.add_argument("--seed", type=int, action="append")
    parser.add_argument("--load", type=float, action="append")
    parser.add_argument("--spread", type=int, action="append")
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--paper", action="store_true", help="3 seeds, 1000+10000, coarse loads, TOPO-UR at 64/256/1024")
    parser.add_argument("--materialize", action="store_true")
    parser.add_argument("--design", choices=sorted(NETWORK_IDS), action="append")
    parser.add_argument("--keycase-256", action="store_true")
    parser.add_argument("--hrep", action="store_true")
    parser.add_argument("--out", type=Path, default=INTERMEDIATE / "traces")
    return parser.parse_args()


def selected_loads(args: argparse.Namespace, bench: dict) -> list[float]:
    if args.load:
        return list(args.load)
    if not bench.get("load_sweep", {}).get("enabled"):
        return [0.0]
    if args.smoke and not (args.full or args.paper):
        return [0.10]
    if args.full or args.paper:
        return coarse_loads(include_zero=True)
    return [0.10]


def selected_spreads(args: argparse.Namespace, bench: dict) -> list[int | None]:
    if args.spread:
        return list(args.spread)
    spreads = bench.get("spread_S")
    if isinstance(spreads, list) and spreads:
        return list(spreads) if args.full or args.paper or not args.smoke else [spreads[0]]
    return [None]


def selected_nodes(args: argparse.Namespace, bench: dict) -> list[int | None]:
    if args.nodes is not None:
        return [args.nodes]
    if args.paper or args.full:
        return list(paper_nodes_for(bench["benchmark_id"]))
    return [None]


def selected_designs(args: argparse.Namespace, nodes: int, bench: dict | None) -> list[str]:
    if not args.materialize:
        return []
    if args.design:
        return list(args.design)
    if (args.paper or args.full) and bench is not None:
        out = []
        for design_id in bench.get("applies_to_designs") or []:
            if design_id not in NETWORK_IDS:
                continue
            if materialize_opts(design_id)["nodes"] == nodes:
                out.append(design_id)
        return out
    if nodes == 64:
        return ["PROP64"]
    if nodes == 256:
        return ["PROP256"]
    return ["PROP1024"]


def emit_materialize(path: Path, designs: list[str], *, hrep: bool, nodes: int) -> None:
    for design in designs:
        opts = materialize_opts(design)
        if opts["nodes"] != nodes:
            continue
        case_path = materialize_path(
            path,
            path.parent / "cases",
            top_lanes=opts["top_lanes"],
            hrep=hrep or opts["hrep"],
            routing=opts["routing"],
            design_id=design,
        )
        print("CASE", design, case_path, flush=True)


def main() -> int:
    args = parse_args()
    paper = args.paper or args.full
    names = list(BENCHMARKS) if args.all or args.paper else (args.benchmark or ["BF-STRESS64"])
    seeds = args.seed or (load_seeds() if paper else load_seeds()[:1])
    smoke = (args.smoke or not paper) and not args.paper
    if paper:
        smoke = False
    out = args.out
    written = 0
    if args.keycase_256:
        for seed in seeds:
            trace = generate_directed_keycase(nodes=args.nodes or 256, seed=seed)
            header = trace["header"]
            name = trace_id(header)
            path = out / ("%s.jsonl" % name)
            digest = dump_jsonl(trace, path)
            print("TRACE", path, digest[:12], flush=True)
            written += 1
            emit_materialize(
                path,
                selected_designs(args, header["nodes"], None),
                hrep=args.hrep,
                nodes=header["nodes"],
            )
        print("GEN_CASES_V3_DONE traces=%d" % written, flush=True)
        return 0
    for benchmark_id in names:
        bench = load_benchmark(benchmark_id)
        for seed in seeds:
            for spread in selected_spreads(args, bench):
                for load in selected_loads(args, bench):
                    for nodes in selected_nodes(args, bench):
                        trace = generate_trace(
                            benchmark_id,
                            seed=seed,
                            nodes=nodes,
                            load_point=load,
                            spread=spread,
                            smoke=smoke,
                        )
                        header = trace["header"]
                        name = trace_id(header)
                        path = out / ("%s.jsonl" % name)
                        digest = dump_jsonl(trace, path)
                        print("TRACE", path, digest[:12], flush=True)
                        written += 1
                        emit_materialize(
                            path,
                            selected_designs(args, header["nodes"], bench),
                            hrep=args.hrep,
                            nodes=header["nodes"],
                        )
    print("GEN_CASES_V3_DONE traces=%d" % written, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
