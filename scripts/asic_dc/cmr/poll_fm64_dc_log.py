#!/usr/bin/env python3
"""How far along is the FM64 DC job."""
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
echo JOB
bjobs -u ghy19 -noheader -o 'jobid stat run_time exec_host name' 11560001 2>/dev/null
echo LOG_BYTES
ls -la %s/logs/dc/%s_cmr_descal_fm64.log %s/logs/dc/%s_cmr_descal_fm64.log.err 2>/dev/null
echo LOG_TAIL
tail -n 40 %s/logs/dc/%s_cmr_descal_fm64.log 2>/dev/null
echo ERR_TAIL
tail -n 20 %s/logs/dc/%s_cmr_descal_fm64.log.err 2>/dev/null
echo OUTPUTS
ls -la %s/outputs/%s_cmr_descal_fm64 2>/dev/null | head
""" % (ROOT, STAMP, ROOT, STAMP, ROOT, STAMP, ROOT, STAMP, ROOT, STAMP)
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
