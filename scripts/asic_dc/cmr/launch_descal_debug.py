#!/usr/bin/env python3
"""Submit FM64 func/SDF isolation and PROP256 single-packet RTL.

Read-only SKIP_DC of 20260831_115856.  New run IDs are cmr_descal_*.
Submit-only: does not wait for LSF.  Does not cook DelayElement_sim.
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CMR = Path(__file__).resolve().parent
EXPERIMENTS = REPO / "DATE paper" / "experiments"
CASE_DIR = EXPERIMENTS / "intermediate" / "des_calibration" / "cases"
MESH64 = "20260831_115856_cmr_mesh64_p50"
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


def _base_env() -> dict[str, str]:
    env = os.environ.copy()
    extra = env.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')
    env.update(
        {
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_DES_BSUB_EXTRA": extra,
            "CMR_REMOTE_ROOT": env.get(
                "CMR_DES_REMOTE_ROOT",
                env.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR"),
            ),
            "CMR_NOC64_ALLOW_V3": "1",
            "CMR_MESH64_ALLOW_V3": "1",
            "CMR_NOC256_ALLOW_V3": "1",
            "CMR_NOC64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_MESH64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_NOC256_V3_CASE_DIR": str(CASE_DIR),
        }
    )
    return env


def launch(script: Path, env: dict[str, str], label: str) -> int:
    print("LAUNCH", label, script.name, flush=True)
    completed = subprocess.run(
        [sys.executable, str(script)],
        cwd=str(REPO),
        env=env,
        check=False,
    )
    print("LAUNCH_DONE", label, "rc", completed.returncode, flush=True)
    return completed.returncode


def main() -> int:
    if not CASE_DIR.is_dir():
        raise SystemExit("missing V3 case dir " + str(CASE_DIR))
    needed = (
        "DBG-64_fm64_6to44.case",
        "KEY-64_n64_s900001_zero_FM64_top0.case",
        "DBG-256_prop_138to37.case",
        "DBG-256_prop_15to0.case",
    )
    missing = [name for name in needed if not (CASE_DIR / name).is_file()]
    if missing:
        raise SystemExit("missing cases: " + ",".join(missing))

    failed = []
    env = _base_env()

    func = dict(env)
    func.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64_func" % STAMP,
            "CMR_MESH64_NETLIST_RUN_ID": MESH64,
            "CMR_MESH64_SKIP_FUNC": "0",
            "CMR_MESH64_SKIP_SDF": "1",
            "CMR_MESH64_CASES": "DBG-64_fm64_6to44,KEY-64_n64_s900001_zero_FM64_top0",
            "CMR_MESH64_FUNC_CASES": "DBG-64_fm64_6to44,KEY-64_n64_s900001_zero_FM64_top0",
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE",
        }
    )
    if launch(CMR / "run_remote_cmr_mesh64_sdf.py", func, "fm64-func"):
        failed.append("fm64-func")

    sdf = dict(env)
    sdf.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64_sdf" % STAMP,
            "CMR_MESH64_NETLIST_RUN_ID": MESH64,
            "CMR_MESH64_SKIP_FUNC": "1",
            "CMR_MESH64_SKIP_SDF": "0",
            "CMR_MESH64_CASES": "DBG-64_fm64_6to44",
            "CMR_MESH64_FUNC_CASES": "DBG-64_fm64_6to44",
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE",
        }
    )
    if launch(CMR / "run_remote_cmr_mesh64_sdf.py", sdf, "fm64-sdf"):
        failed.append("fm64-sdf")

    prop = dict(env)
    prop.update(
        {
            "CMR_NOC256_KIND": "prop",
            "CMR_NOC256_RUN_ID": "%s_cmr_descal_prop256_iso" % STAMP,
            "CMR_NOC256_CASES": "DBG-256_prop_138to37,DBG-256_prop_15to0",
            "CMR_NOC256_SIM_ARGS": "+L3_PROBE",
            "CMR_FORCE_EMIT": "0",
        }
    )
    if launch(CMR / "run_remote_cmr_noc256_rtl.py", prop, "prop256-iso"):
        failed.append("prop256-iso")

    if failed:
        print("LAUNCH_FAIL", ",".join(failed), flush=True)
        return 1
    print("LAUNCH_OK stamp=%s" % STAMP, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
