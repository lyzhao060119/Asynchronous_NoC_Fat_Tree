#!/usr/bin/env python3
"""Materialize PFAT64 TOPO-UR ASAP cases (top_lanes=8) for the paper64 load grid.

Uses the same DATE V3 ASAP traces as PROP_temp64 / FlatMesh64 UR:
exponential packet headers, intra-packet same-cycle offer. No multicast.
No synthesis — cases only.

Traces are generated inline (seed-dependent, deterministic) so the 3-seed
paper grid (202701/202702/202703) does not depend on any pre-existing bundle.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(REPO / "DATE_paper" / "experiments" / "scripts"))
sys.path.insert(0, str(HERE))

from date_v3.canonical_trace import dump_jsonl, generate_trace  # noqa: E402
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402

# Frozen 64-node unicast grid used by the formal Mesh64/M16 three-seed run.
# Keep this generator self-contained: the former _tmp_paper64_common helper
# was an experimental launcher and is not part of the maintained source tree.
LOADS = (
    5, 10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220, 240, 260,
    280, 300, 320, 340, 360, 380, 400, 420, 440, 460, 480, 500, 600, 700, 800,
)

DEFAULT_SEED = 202701
DESIGN = "PFAT64"
FROZEN_NETLIST = "20260915_080229_cmr_pfat64_rpsdel050_1248"


def bundle_dirs(seed: int) -> tuple[Path, Path]:
    trace_dir = HERE / "generated_cases" / ("paper64_asap_m5_800_s%d" % seed) / "traces"
    out = HERE / "generated_cases" / ("pfat64_asap_m5_800_s%d" % seed)
    return trace_dir, out


def ensure_trace(trace_dir: Path, seed: int, load: int) -> Path:
    jsonl = trace_dir / ("TOPO-UR_n64_s%d_m%d.jsonl" % (seed, load))
    if jsonl.is_file():
        return jsonl
    trace = generate_trace("TOPO-UR", seed=seed, nodes=64, smoke=False, load_point=float(load))
    trace["header"]["injection_model"] = "v3_exp_header_asap_body"
    dump_jsonl(trace, jsonl)
    return jsonl


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED,
                        help="traffic seed (default %d)" % DEFAULT_SEED)
    args = parser.parse_args()
    seed = args.seed
    opts = materialize_opts(DESIGN)
    if opts["top_lanes"] != 8:
        raise SystemExit("expected top_lanes=8, got %s" % opts["top_lanes"])
    trace_dir, out = bundle_dirs(seed)
    case_dir = out / "cases"
    trace_dir.mkdir(parents=True, exist_ok=True)
    case_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for load in LOADS:
        jsonl = ensure_trace(trace_dir, seed, load)
        path = materialize_path(
            jsonl,
            case_dir,
            top_lanes=opts["top_lanes"],
            hrep=opts["hrep"],
            routing=opts["routing"],
            design_id=DESIGN,
            sidecars=False,
        )
        expected = "TOPO-UR_n64_s%d_m%d_%s_top%d.case" % (
            seed, load, DESIGN, opts["top_lanes"]
        )
        if path.name != expected:
            raise SystemExit("case name %s != %s" % (path.name, expected))
        written.append(path.name)
        print("CASE", path.name, flush=True)
    model = {
        "bundle": out.name,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "design_id": DESIGN,
        "injection_model": "v3_exp_header_asap_body",
        "seed": seed,
        "loads_mflit_per_port_s": list(LOADS),
        "benches": ["TOPO-UR"],
        "top_lanes": 8,
        "frozen_netlist_run_id": FROZEN_NETLIST,
        "same_traffic_as": "paper64_asap_m5_800 TOPO-UR traces",
        "purpose": "E1 PFAT64 UR fill to match PROP_temp64/FlatMesh64 30-point grid",
        "cases": len(written),
    }
    (out / "INJECTION_MODEL.json").write_text(
        json.dumps(model, indent=2) + "\n", encoding="utf-8"
    )
    print("PFAT64_CASES_OK written=%d dir=%s" % (len(written), case_dir), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
