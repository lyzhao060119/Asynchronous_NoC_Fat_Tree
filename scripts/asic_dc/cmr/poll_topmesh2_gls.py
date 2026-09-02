#!/usr/bin/env python3
"""Fetch 2x2 TopMesh GLS logs for the latest run."""
from __future__ import annotations

import sys

from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

RUN = "20260901_201830_cmr_topmesh2_p50"
ROOT = "/home/ghy19/Asynchronous_Router_CMR"


def main() -> int:
    client = connect()
    client, listing = remote_run_retry(
        client,
        "ls -1dt %s/logs/gls/*topmesh* %s/logs/dc/*topmesh2* 2>/dev/null | head -20; "
        "echo =====RAND=====; "
        "ls -lt %s/logs/gls/*/sdf/tm2_random_mix 2>/dev/null | head -20"
        % (ROOT, ROOT, ROOT),
    )
    sys.stdout.write(listing + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
