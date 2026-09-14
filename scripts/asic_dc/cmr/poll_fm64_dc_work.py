#!/usr/bin/env python3
"""Inspect FM64 DC work/reports while LSF -o is still buffered."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STAMP = "20260901_172539"


def main() -> int:
    client = connect()
    cmd = r"""
echo WORK
ls -la %s/work/dc_mesh64_%s_cmr_descal_fm64 2>/dev/null | head -n 30
echo REPORTS
ls -la %s/reports/dc/%s_cmr_descal_fm64 2>/dev/null | head -n 30
echo NODE_PS
lsload node21 2>/dev/null
bjobs -u ghy19 -m node21 -noheader -o 'jobid stat run_time slots mem name' 2>/dev/null | head
""" % (ROOT, STAMP, ROOT, STAMP)
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
