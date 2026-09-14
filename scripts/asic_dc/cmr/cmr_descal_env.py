"""LSF isolation helpers for DATE V3 DES-calibration DC/GLS.

When CMR_DESCAL=1, splice CMR_DES_BSUB_EXTRA into bsub resource strings
and prefix job names with cmr_descal.  Non-descal paths keep historical
job names so in-flight Phase 5 jobs are not disturbed.
"""
from __future__ import annotations

import os


def is_descal() -> bool:
    return os.environ.get("CMR_DESCAL", "0") == "1"


def submit_only() -> bool:
    return os.environ.get("CMR_DESCAL_SUBMIT_ONLY", "0") == "1"


def apply_bsub(base: str) -> str:
    extra = os.environ.get("CMR_DES_BSUB_EXTRA", "").strip()
    if is_descal() and extra:
        return ("%s %s" % (base, extra)).strip()
    return base


def job_name(kind: str, run_id: str) -> str:
    if is_descal():
        return "cmr_descal_%s_%s" % (kind, run_id)
    return "cmr_%s_%s" % (kind, run_id)
