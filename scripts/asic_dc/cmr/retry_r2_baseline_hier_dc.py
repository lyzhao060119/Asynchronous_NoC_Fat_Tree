#!/usr/bin/env python3
"""Retry Round-2 authorized hier DC submit (same stamps after SSH drop)."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Keep the authorized stamp from the first launch attempt.
FM_RUN = "20260915_122347_cmr_mesh256_hier_dc"
PFAT_RUN = "20260915_122347_cmr_pfat_temp256_hier_dc"
HOSTS = ("192.168.2.8", "192.168.2.9", "192.168.2.6", "192.168.2.5")


def launch(kind: str, run_id: str, host: str) -> int:
    env = os.environ.copy()
    env.update(
        {
            "C1_HOST": host,
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
    print("RETRY_LAUNCH", kind, run_id, "host", host, flush=True)
    return subprocess.run(
        [sys.executable, str(HERE / "run_remote_cmr_hier_dc.py")],
        cwd=str(HERE),
        env=env,
    ).returncode


def launch_with_failover(kind: str, run_id: str) -> int:
    last = 1
    for host in HOSTS:
        try:
            rc = launch(kind, run_id, host)
        except Exception as exc:
            print("RETRY_EXCEPTION", kind, host, exc, flush=True)
            last = 1
            continue
        if rc == 0:
            print("RETRY_OK", kind, run_id, host, flush=True)
            return 0
        print("RETRY_RC", kind, host, rc, flush=True)
        last = rc
    return last


def main() -> int:
    # PFAT first (smaller RTL upload), then FM256.
    rc_pfat = launch_with_failover("pfat_temp256", PFAT_RUN)
    if rc_pfat != 0:
        print("PFAT256_STILL_FAIL", rc_pfat, flush=True)
    rc_fm = launch_with_failover("mesh256", FM_RUN)
    if rc_fm != 0:
        print("FM256_STILL_FAIL", rc_fm, flush=True)
    if rc_fm == 0 and rc_pfat == 0:
        print("R2_DC_BOTH_SUBMITTED", FM_RUN, PFAT_RUN, flush=True)
        return 0
    print("R2_DC_PARTIAL", "fm", rc_fm, "pfat", rc_pfat, flush=True)
    return 1 if rc_fm != 0 or rc_pfat != 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
