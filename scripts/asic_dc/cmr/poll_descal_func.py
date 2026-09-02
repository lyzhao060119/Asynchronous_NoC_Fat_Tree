#!/usr/bin/env python3
"""Poll the FM64 func retry jobs (20260901_171919)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STAMP = "20260901_171919"
JOBS = "11559801 11559901"


def main() -> int:
    client = connect()
    cmd = r"""
echo BJOBS
bjobs -u ghy19 -noheader -o 'jobid stat name' %s 2>/dev/null
echo MARKERS
for p in \
  %s/logs/gls/%s_cmr_descal_fm64_func/func/DBG-64_fm64_6to44/run.log \
  %s/logs/gls/%s_cmr_descal_fm64_func/func/DBG-64_fm64_6to44/stdout.log \
  %s/logs/gls/%s_cmr_descal_fm64_func/func/KEY-64_n64_s900001_zero_FM64_top0/run.log \
  %s/logs/gls/%s_cmr_descal_fm64_func/func_DBG-64_fm64_6to44.bsub.log; do
  echo == $p
  grep -E 'TB_RESULT|TB_UNEXPECTED|TB_MESH_LOCAL44|CMR_MESH64_GLS|simv missing|continuing because' "$p" 2>/dev/null | tail -n 30
done
echo SIMV
ls -la %s/sim/work/%s_cmr_descal_fm64_func/func/DBG-64_fm64_6to44/simv 2>/dev/null
""" % (
        JOBS,
        ROOT, STAMP, ROOT, STAMP, ROOT, STAMP, ROOT, STAMP,
        ROOT, STAMP,
    )
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
