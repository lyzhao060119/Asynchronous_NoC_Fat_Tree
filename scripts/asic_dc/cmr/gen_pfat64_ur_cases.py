#!/usr/bin/env python3
"""Materialize PFAT64 TOPO-UR ASAP cases (top_lanes=8) for the paper64 load grid.

Uses the same DATE V3 ASAP traces as PROP_temp64 / FlatMesh64 UR:
exponential packet headers, intra-packet same-cycle offer. No multicast.
No synthesis — cases only.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))
sys.path.insert(0, str(HERE))

from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from _tmp_paper64_common import LOADS  # noqa: E402

SEED = 202701
TRACE_DIR = HERE / "generated_cases" / "20260913_paper64_asap_m5_500_202701" / "traces"
OUT = HERE / "generated_cases" / "20260915_pfat64_asap_m5_800_202701"
CASE_DIR = OUT / "cases"
DESIGN = "PFAT64"
FROZEN_NETLIST = "20260912_195012_cmr_pfat64_rpsdel050_1248"


def main() -> int:
    opts = materialize_opts(DESIGN)
    if opts["top_lanes"] != 8:
        raise SystemExit("expected top_lanes=8, got %s" % opts["top_lanes"])
    if not TRACE_DIR.is_dir():
        raise SystemExit("missing ASAP trace dir %s" % TRACE_DIR)
    CASE_DIR.mkdir(parents=True, exist_ok=True)
    written = []
    for load in LOADS:
        jsonl = TRACE_DIR / ("TOPO-UR_n64_s%d_m%d.jsonl" % (SEED, load))
        if not jsonl.is_file():
            raise SystemExit("missing trace %s" % jsonl)
        path = materialize_path(
            jsonl,
            CASE_DIR,
            top_lanes=opts["top_lanes"],
            hrep=opts["hrep"],
            routing=opts["routing"],
            design_id=DESIGN,
            sidecars=False,
        )
        expected = "TOPO-UR_n64_s%d_m%d_%s_top%d.case" % (
            SEED, load, DESIGN, opts["top_lanes"]
        )
        if path.name != expected:
            raise SystemExit("case name %s != %s" % (path.name, expected))
        written.append(path.name)
        print("CASE", path.name, flush=True)
    model = {
        "bundle": OUT.name,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "design_id": DESIGN,
        "injection_model": "v3_exp_header_asap_body",
        "seed": SEED,
        "loads_mflit_per_port_s": list(LOADS),
        "benches": ["TOPO-UR"],
        "top_lanes": 8,
        "frozen_netlist_run_id": FROZEN_NETLIST,
        "same_traffic_as": "20260913_paper64_asap_m5_500_202701 TOPO-UR traces",
        "purpose": "E1 PFAT64 UR fill to match PROP_temp64/FlatMesh64 30-point grid",
        "cases": len(written),
    }
    (OUT / "INJECTION_MODEL.json").write_text(
        json.dumps(model, indent=2) + "\n", encoding="utf-8"
    )
    print("PFAT64_CASES_OK written=%d dir=%s" % (len(written), CASE_DIR), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
