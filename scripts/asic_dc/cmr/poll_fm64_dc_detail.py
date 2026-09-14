#!/usr/bin/env python3
"""Find FM64 DC log and runtime."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"


def main() -> int:
    client = connect()
    cmd = r"""
echo BJOBS_L
bjobs -l 11560001 2>/dev/null | head -n 40
echo DC_DIR
ls -lt %s/logs/dc | grep 172539 | head
echo DC_GLOB
ls -lt %s/logs/dc/*172539* %s/work/dc_mesh64_20260901_172539_cmr_descal_fm64 2>/dev/null | head -n 20
echo WRAPPER
ls -la %s/logs/dc/20260901_172539_cmr_descal_fm64.sh %s/logs/dc/20260901_172539_cmr_descal_fm64.log 2>/dev/null
echo FIND_LOG
find %s/logs/dc %s/work -name '*172539*' -mtime -1 2>/dev/null | head -n 30
echo PROP256
bjobs -u ghy19 -noheader -o 'jobid stat name' 11560901 2>/dev/null
""" % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT)
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
