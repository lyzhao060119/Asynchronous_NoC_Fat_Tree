#!/usr/bin/env python3
"""Launch authorized Round-2 baseline hier DC (mesh256 + pfat_temp256).

User authorized both syntheses on 2026-09-15. New timestamps only; SKIP_GLS.
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
FM_RUN = f"{STAMP}_cmr_mesh256_hier_dc"
PFAT_RUN = f"{STAMP}_cmr_pfat_temp256_hier_dc"


def launch(kind: str, run_id: str) -> int:
    env = os.environ.copy()
    env.update(
        {
            "C1_HOST": env.get("C1_HOST", "192.168.2.8"),
            "CMR_HIER_KIND": kind,
            "CMR_HIER_STITCH_RUN_ID": run_id,
            "CMR_HIER_SKIP_GLS": "1",
            "CMR_HIER_CHILD_BATCH_SIZE": "4",
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_DES_BSUB_EXTRA": '-m "node21 node26 node24 node18"',
            "CMR_HIER_CHILD_BSUB": "-n 4",
            "CMR_HIER_STITCH_BSUB": "-n 8",
            "CMR_RCU_MATCHED_DELAY_UNIT_PS": "50",
            "CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS": "150",
            "PYTHONUNBUFFERED": "1",
        }
    )
    print("LAUNCH_DC", kind, run_id, flush=True)
    proc = subprocess.run(
        [sys.executable, str(HERE / "run_remote_cmr_hier_dc.py")],
        cwd=str(HERE),
        env=env,
    )
    print("LAUNCH_DC_DONE", kind, run_id, "rc", proc.returncode, flush=True)
    return int(proc.returncode)


def main() -> int:
    print("R2_DC_AUTH_ACCEPTED stamp", STAMP, flush=True)
    print("FM_RUN", FM_RUN, flush=True)
    print("PFAT_RUN", PFAT_RUN, flush=True)
    # FM first (larger upload), then PFAT. Sequential submit to avoid login SFTP contention.
    rc_fm = launch("mesh256", FM_RUN)
    if rc_fm != 0:
        print("FM256_DC_SUBMIT_FAIL", rc_fm, flush=True)
        return rc_fm
    rc_pfat = launch("pfat_temp256", PFAT_RUN)
    if rc_pfat != 0:
        print("PFAT256_DC_SUBMIT_FAIL", rc_pfat, flush=True)
        return rc_pfat
    state = HERE / "results" / "r2_baseline_dc_launch.json"
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(
        "{\n"
        f'  "stamp": "{STAMP}",\n'
        f'  "fm256": "{FM_RUN}",\n'
        f'  "pfat_temp256": "{PFAT_RUN}",\n'
        '  "skip_gls": true,\n'
        '  "authorized": true\n'
        "}\n",
        encoding="utf-8",
    )
    print("R2_DC_BOTH_SUBMITTED", state, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
