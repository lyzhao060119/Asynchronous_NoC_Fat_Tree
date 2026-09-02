#!/usr/bin/env python3
"""Show why descal jobs are PEND and which hosts are free."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry


def main() -> int:
    client = connect()
    cmd = r"""
echo '===BJOBS==='
bjobs -u ghy19 -noheader -o 'jobid stat run_time slots exec_host name' 2>/dev/null | grep -E 'cmr_descal|JOBID' || bjobs -u ghy19 2>/dev/null | head -n 40
echo '===PEND_REASON==='
bjobs -p -u ghy19 2>/dev/null | head -n 80
echo '===JOB_DETAIL==='
for j in 11560001 11560501 11560601 11560701 11560801 11560901; do
  echo -- $j
  bjobs -l $j 2>/dev/null | sed -n '1,25p'
done
echo '===BHOSTS_PREF==='
bhosts -w node21 node26 node24 node18 2>/dev/null
echo '===LSLOAD_PREF==='
lsload node21 node26 node24 node18 2>/dev/null
echo '===BHOSTS_FREE==='
bhosts -w 2>/dev/null | awk 'NR==1 || $2=="ok"' | head -n 40
"""
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
