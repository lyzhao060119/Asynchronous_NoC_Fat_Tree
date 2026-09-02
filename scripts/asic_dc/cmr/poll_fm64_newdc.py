#!/usr/bin/env python3
"""Poll FM64 new DC + SDF (20260901_172539)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STAMP = "20260901_172539"
JOBS = "11560001 11562401 11562501 11562601 11562701"


def main() -> int:
    client = connect()
    cmd = r"""
echo BJOBS_ALL
bjobs -u ghy19 2>/dev/null | grep -E 'JOBID|mesh64|descal_fm64|11560001|11562401|11562501|11562601|11562701' || true
echo BJOBS_IDS
bjobs -u ghy19 -noheader -o 'jobid stat run_time exec_host name' %s 2>/dev/null
echo BHIST_DC
bhist -l 11560001 2>/dev/null | grep -E 'Submitted|Dispatched|Done|Exited|CPU|PENDING' | head -n 20
echo GLS_DIR
ls -la %s/logs/gls/%s_cmr_descal_fm64/ 2>/dev/null | head -n 40
echo OUTPUTS
ls -la %s/outputs/%s_cmr_descal_fm64/ 2>/dev/null | head -n 30
echo DC_MARK
grep -E 'CMR_MESH64_DC_PASS|CMR_MESH64_DC_FAIL|Error:|error:' %s/logs/dc/%s_cmr_descal_fm64.log %s/logs/dc/%s_cmr_descal_fm64.log.err 2>/dev/null | tail -n 30
echo SDF
for p in \
  %s/logs/gls/%s_cmr_descal_fm64/sdf/DBG-64_fm64_6to44/run.log \
  %s/logs/gls/%s_cmr_descal_fm64/sdf/KEY-64_n64_s900001_zero_FM64_top0/run.log \
  %s/logs/gls/%s_cmr_descal_fm64/sdf/TOPO-UR_n64_s900001_zero_FM64_top0/run.log \
  %s/logs/gls/%s_cmr_descal_fm64/sdf/TOPO-UR_n64_s900001_r0p10_FM64_top0/run.log; do
  echo == $p
  grep -E 'TB_RESULT|TB_UNEXPECTED|TB_MESH_LOCAL44|TB_DUMP|CMR_MESH64_GLS|Error-|Fatal' "$p" 2>/dev/null | tail -n 25
done
echo SDF_BSUB
grep -E 'TB_RESULT|CMR_MESH64|Error-|Fatal|SDF' %s/logs/gls/%s_cmr_descal_fm64/sdf_*.bsub.log %s/logs/gls/%s_cmr_descal_fm64/sdf_*.bsub.err 2>/dev/null | tail -n 40
""" % (
        JOBS,
        ROOT, STAMP,
        ROOT, STAMP,
        ROOT, STAMP, ROOT, STAMP,
        ROOT, STAMP, ROOT, STAMP, ROOT, STAMP, ROOT, STAMP,
        ROOT, STAMP, ROOT, STAMP,
    )
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
