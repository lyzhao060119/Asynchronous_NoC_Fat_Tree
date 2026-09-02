#!/usr/bin/env python3
"""Fetch the latest 2x2 TopMesh DC log tail and failure markers."""
from __future__ import annotations

import sys

from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

LOG = (
    "/home/ghy19/Asynchronous_Router_CMR/logs/dc/"
    "20260901_195840_cmr_topmesh2_p50.log"
)


def main() -> int:
    client = connect()
    client, out = remote_run_retry(
        client,
        "grep -E 'CMR_TOPMESH2_|Error:|FAIL|unresolved|Elaborated|Current design' %s | tail -n 100; "
        "echo =====TAIL=====; tail -n 80 %s" % (LOG, LOG),
    )
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
