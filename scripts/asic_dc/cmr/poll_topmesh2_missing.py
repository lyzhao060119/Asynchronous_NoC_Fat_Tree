#!/usr/bin/env python3
from __future__ import annotations

import sys

from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

BASE = (
    "/home/ghy19/Asynchronous_Router_CMR/logs/gls/"
    "20260901_203611_cmr_topmesh2_p50/sdf/tm2_random_mix"
)


def main() -> int:
    client = connect()
    client, out = remote_run_retry(
        client,
        "grep -E 'TB_MISSING|TB_STALL|TB_RESULT|TB_INFO case' %s/run.log %s/stdout.log"
        % (BASE, BASE),
    )
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
