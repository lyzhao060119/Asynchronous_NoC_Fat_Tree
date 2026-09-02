#!/usr/bin/env python3
"""Kill FM64 func GLS; keep DC and SDF."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

FUNC_JOBS = "11560101 11560201 11560301 11560401"
KEEP = "11560001 11560501 11560601 11560701 11560801"


def main() -> int:
    client = connect()
    client, before = remote_run_retry(
        client,
        "echo BEFORE; bjobs -u ghy19 -noheader -o 'jobid stat name' %s %s 2>/dev/null"
        % (FUNC_JOBS, KEEP),
    )
    print(before, flush=True)
    client, killed = remote_run_retry(client, "bkill %s 2>&1" % FUNC_JOBS)
    print(killed, flush=True)
    client, after = remote_run_retry(
        client,
        "echo AFTER; bjobs -u ghy19 -noheader -o 'jobid stat name' %s %s 2>/dev/null; "
        "echo DC; bjobs -u ghy19 -noheader -o 'jobid stat name' 11560001 2>/dev/null"
        % (FUNC_JOBS, KEEP),
    )
    print(after, flush=True)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
