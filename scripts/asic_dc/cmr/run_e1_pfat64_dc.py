#!/usr/bin/env python3
"""Authorize and submit a fresh PFAT64 (1248) DC run. SKIP_GLS.

User-authorized replacement after the previous frozen netlist
20260912_195012_cmr_pfat64_rpsdel050_1248 was deleted from remote outputs.
Uses a new timestamp; does not overwrite any frozen IDs.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(HERE))

from _tmp_paper64_common import base_env, stamp  # noqa: E402

CASE_DIR = HERE / "generated_cases" / "20260915_pfat64_asap_m5_800_202701" / "cases"
STATE_DIR = HERE / "results" / "e1_pfat64_ur_fill"
SMOKE_CASE = "TOPO-UR_n64_s202701_m5_PFAT64_top8"


def main() -> int:
    case_path = CASE_DIR / (SMOKE_CASE + ".case")
    if not case_path.is_file():
        raise SystemExit(
            "missing %s — run gen_pfat64_ur_cases.py first" % case_path
        )
    base = stamp() + "_cmr_pfat64_rpsdel050"
    netlist = base + "_1248"
    env = base_env()
    env.update(
        {
            "CMR_FAT_LANE_PROFILE": "1248",
            "CMR_Q64_PROFILE": "1248",
            "CMR_NOC64_RUN_ID": base,
            "CMR_NOC64_SKIP_GLS": "1",
            "CMR_NOC64_CASES": SMOKE_CASE,
            "CMR_NOC64_FUNC_CASES": SMOKE_CASE,
            "CMR_NOC64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_FORCE_EMIT": os.environ.get("CMR_FORCE_EMIT", "0"),
        }
    )
    env.pop("CMR_NOC64_NETLIST_RUN_ID", None)

    print("LAUNCH_DC_PFAT64 base=%s netlist=%s" % (base, netlist), flush=True)
    completed = subprocess.run(
        [sys.executable, str(HERE / "run_remote_cmr_noc64_sdf.py")],
        cwd=str(REPO),
        env=env,
    )
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state = {
        "schema": "date2027-e1-pfat64-dc-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "authorized_by": "user_request_restart_1248_dc",
        "replaces_missing_netlist": "20260912_195012_cmr_pfat64_rpsdel050_1248",
        "base_run_id": base,
        "netlist_run_id": netlist,
        "profile": "1248",
        "skip_gls": True,
        "smoke_case": SMOKE_CASE,
        "returncode": completed.returncode,
    }
    out = STATE_DIR / ("dc_state_%s.json" % netlist)
    out.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("DC_STATE", out, flush=True)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)
    print("PFAT64_DC_SUBMITTED netlist=%s" % netlist, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
