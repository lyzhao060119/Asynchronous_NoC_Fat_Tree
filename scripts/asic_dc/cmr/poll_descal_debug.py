#!/usr/bin/env python3
"""Poll the 20260901_165731 descal debug LSF jobs (read-only)."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STAMP = "20260901_165731"
JOBS = "11558401 11558501 11558601 11558701 11558801"


def main() -> int:
    client = connect()
    cmd = (
        "echo '---BJOBS---'; bjobs -u ghy19 -noheader -o 'jobid stat name' %s 2>/dev/null; "
        "echo '---MARKERS---'; "
        "for p in "
        "%s/logs/gls/%s_cmr_descal_fm64_func/func/DBG-64_fm64_6to44/run.log "
        "%s/logs/gls/%s_cmr_descal_fm64_func/func/KEY-64_n64_s900001_zero_FM64_top0/run.log "
        "%s/logs/gls/%s_cmr_descal_fm64_sdf/sdf/DBG-64_fm64_6to44/run.log "
        "%s/logs/gls/%s_cmr_descal_prop256_iso/rtl/DBG-256_prop_138to37/run.log "
        "%s/logs/gls/%s_cmr_descal_prop256_iso/rtl/DBG-256_prop_15to0/run.log; do "
        "echo == $p; "
        "grep -E 'TB_RESULT|TB_UNEXPECTED|TB_DUMP_ON_FAIL|TB_MESH_LOCAL44|TB_L3_00|TB_MISSING|Error-|Fatal' $p 2>/dev/null | tail -n 20; "
        "done"
        % (
            JOBS,
            ROOT, STAMP, ROOT, STAMP, ROOT, STAMP, ROOT, STAMP, ROOT, STAMP,
        )
    )
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
