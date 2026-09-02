#!/usr/bin/env python3
from __future__ import annotations

import sys

from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

BASE = (
    "/home/ghy19/Asynchronous_Router_CMR/logs/gls/"
    "20260901_201835_cmr_topmesh2_p50/sdf/tm2_random_mix"
)
DC = "/home/ghy19/Asynchronous_Router_CMR/logs/dc/20260901_201835_cmr_topmesh2_p50.log"


def main() -> int:
    client = connect()
    client, out = remote_run_retry(
        client,
        "echo =====RUN=====; cat %s/run.log; echo =====STDOUT=====; cat %s/stdout.log; "
        "echo =====CSV=====; cat %s/result.csv; echo =====SDF=====; "
        "grep -E 'Total errors:|Doing SDF annotation|IFNSDFA|Warning' %s/sdf_annotate.log | head -n 40; "
        "echo =====DC=====; grep -E 'CMR_TOPMESH2_DC_PASS|CMR_TOPMESH2_STRUCTURE|gtech' %s"
        % (BASE, BASE, BASE, BASE, DC),
    )
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
