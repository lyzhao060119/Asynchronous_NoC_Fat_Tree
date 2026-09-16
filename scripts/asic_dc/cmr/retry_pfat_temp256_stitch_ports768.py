#!/usr/bin/env python3
"""Resubmit PFAT_temp256 stitch only with corrected expected_ports=768.

Children already PASS under 20260915_122347_cmr_pfat_temp256_hier_dc.
Reuses the same parent run id (not frozen); skips child DC via artifact check.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PFAT_RUN = "20260915_122347_cmr_pfat_temp256_hier_dc"


def main() -> int:
    env = os.environ.copy()
    env.update(
        {
            "C1_HOST": os.environ.get("C1_HOST", "192.168.2.8"),
            "CMR_HIER_KIND": "pfat_temp256",
            "CMR_HIER_STITCH_RUN_ID": PFAT_RUN,
            "CMR_HIER_SKIP_GLS": "1",
            "CMR_HIER_CHILD_BATCH_SIZE": "8",
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
    print("PFAT_STITCH_RETRY", PFAT_RUN, "expected_ports=768", flush=True)
    return subprocess.run(
        [sys.executable, str(HERE / "run_remote_cmr_hier_dc.py")],
        cwd=str(HERE),
        env=env,
    ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
