#!/usr/bin/env python3
"""Find FM64 DC artifacts if LSF buffered the -o log."""
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
echo WRAPPER
ls -la %s/logs/dc/%s_cmr_descal_fm64* 2>/dev/null
echo CAT_SH
cat %s/logs/dc/%s_cmr_descal_fm64.sh 2>/dev/null
echo FIND_LOG
find %s/logs/dc %s/work %s/reports/dc -maxdepth 2 -iname '*172539*' 2>/dev/null | head -n 40
echo PS
ps -u ghy19 -o pid,etime,pcpu,pmem,comm,args 2>/dev/null | grep -E 'dc_shell|dc-t|syn' | grep -v grep | head
echo LSF
bjobs -l 11560001 2>/dev/null | head -n 80
""" % (ROOT, STAMP, ROOT, STAMP, ROOT, ROOT, ROOT)
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
