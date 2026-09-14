#!/usr/bin/env python3
"""C1P2 DC + MAXIMUM-SDF hop GLS (await-ack adapter / mutex-hold selector).

Recipe matches the diagnostic hop net used for UC/F4 100 MFlit:
RCU 1xDEL150, Ackin 1xDEL050, Lane01 buf=0, Mat 0.20 ns.

Does not overwrite frozen hop IDs or signed SR-before-mutex nets.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RUN_ID = os.environ.get("CMR_RUN_ID", "20260910_c1p2_awaitack_del150_dc")


def run(cmd: list[str], env: dict[str, str], label: str) -> None:
    print("RUN", label, " ".join(cmd), flush=True)
    completed = subprocess.run(cmd, cwd=str(REPO), env=env, check=False)
    print("DONE", label, "rc", completed.returncode, flush=True)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> int:
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    env.setdefault("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
    env.setdefault("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')
    dc_env = env.copy()
    dc_env.update(
        {
            "CMR_RUN_ID": RUN_ID,
            "CMR_DC_ONLY": "1",
            "CMR_CHILD_LANES": "1",
            "CMR_PARENT_LANES": "2",
            "CMR_ROUTER_LEVEL": "1",
            "CMR_SKIP_LOCAL_SMOKE": "1",
            "CMR_JOB_POLLS": "480",
            "CMR_ALLOW_DIAG_RCU": "1",
            "CMR_RCU_MATCHED_DELAY_STEPS": "1",
            "CMR_RCU_MATCHED_DELAY_UNIT_PS": "150",
            "CMR_RCU_MATCHED_BUF_STAGES": "0",
            "CMR_OPM_ACKIN_DELAY_STEPS": "1",
            "CMR_OPM_ACKIN_DELAY_UNIT_PS": "50",
            "CMR_OPM_ACKIN_USE_BUF": "0",
            "CMR_LANE01_BUF_STAGES": "0",
            "CMR_RCU_MAT_MAX_NS": "0.20",
        }
    )
    dc_env.pop("CMR_NOC64_NETLIST_RUN_ID", None)
    dc_env.pop("CMR_HIER_STITCH_RUN_ID", None)
    print("C1P2_DC_GLS", RUN_ID, flush=True)
    run(
        [sys.executable, str(HERE / "run_remote_cmr_flow.py")],
        dc_env,
        "C1P2_DC",
    )
    gls_env = env.copy()
    gls_env["CMR_HOP_NET_ID"] = RUN_ID
    gls_env["CMR_HOP_GEOM"] = "C1_P2"
    gls_env["CMR_HOP_TRAFFIC"] = "UC,F4"
    run(
        [sys.executable, str(HERE / "launch_hop_exp_gls.py")],
        gls_env,
        "C1P2_HOP_GLS",
    )
    print("C1P2_DC_GLS_PASS", RUN_ID, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
