#!/usr/bin/env python3
"""Snapshot LSF descal jobs, preferred hosts, and PROP256 fail log head."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

CMD = r"""
set +e
echo '===BJOBS==='
bjobs -u ghy19 2>/dev/null
echo '===BHOSTS==='
bhosts -w node21 node26 node24 node18 2>/dev/null
echo '===DC_NETLIST==='
ls -lh /home/ghy19/Asynchronous_Router_CMR/reports/dc/20260901_172539_cmr_descal_fm64/*post* 2>/dev/null | head
ls /home/ghy19/Asynchronous_Router_CMR/reports/dc/20260901_172539_cmr_descal_fm64/ 2>/dev/null | head -n 30
echo '===PROP256_LOG==='
ls -lh /home/ghy19/Asynchronous_Router_CMR/logs/gls/20260901_172855_cmr_descal_prop256/ 2>/dev/null | head -n 40
echo '===PROP256_BSUB_ERR==='
tail -n 80 /home/ghy19/Asynchronous_Router_CMR/logs/gls/20260901_172855_cmr_descal_prop256/rtl_KEY-256_n256_s900001_zero_PROP256_top0.bsub.err 2>/dev/null
echo '===PROP256_BSUB_LOG==='
tail -n 80 /home/ghy19/Asynchronous_Router_CMR/logs/gls/20260901_172855_cmr_descal_prop256/rtl_KEY-256_n256_s900001_zero_PROP256_top0.bsub.log 2>/dev/null
echo '===PROP256_RUN==='
ls /home/ghy19/Asynchronous_Router_CMR/logs/gls/20260901_172855_cmr_descal_prop256/ 2>/dev/null
find /home/ghy19/Asynchronous_Router_CMR/logs/gls/20260901_172855_cmr_descal_prop256 -name 'run.log' -o -name '*.log' 2>/dev/null | head
"""


def main() -> int:
    client = connect()
    client, text = remote_run_retry(client, CMD)
    print(text, flush=True)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
