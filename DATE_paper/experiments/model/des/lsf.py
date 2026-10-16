"""LSF isolation for optional DES-calibration GLS.

Do not share hosts or run IDs with in-flight Phase 5 DC/GLS.  Never write
frozen hop / Sync64 directories.  Override hosts with CMR_DES_BSUB_EXTRA,
for example: -m "hostA hostB" or -R "select[hname!=busyhost]".
"""

from __future__ import annotations

import os
from datetime import datetime

JOB_PREFIX = "cmr_descal"
DEFAULT_BSUB = "-n 4 -R span[hosts=1]"


def run_id(tag: str) -> str:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return "%s_%s_%s" % (stamp, JOB_PREFIX, tag)


def bsub_args(*, job: str) -> str:
    extra = os.environ.get("CMR_DES_BSUB_EXTRA", "").strip()
    base = os.environ.get("CMR_DES_BSUB", DEFAULT_BSUB).strip()
    return "bsub %s %s -J %s_%s" % (base, extra, JOB_PREFIX, job)


def remote_root() -> str:
    return os.environ.get(
        "CMR_DES_REMOTE_ROOT",
        os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR"),
    )
