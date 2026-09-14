#!/usr/bin/env python3
"""Snapshot cluster DC/GLS and local rtl jsonl for the six DATE V3 designs."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
REPO = Path(__file__).resolve().parents[3]
PACK = REPO / "DATE paper" / "experiments" / "intermediate" / "des_calibration"


def main() -> int:
    client = connect()
    cmd = r"""
echo '===BJOBS_DESCAL==='
bjobs -u ghy19 -noheader -o 'jobid stat name' 2>/dev/null | grep -E 'cmr_descal|cmr_mesh64|cmr_noc64|cmr_noc256' || true
echo '===OUTPUTS_64==='
ls -1d %s/outputs/*1222* %s/outputs/*thin* %s/outputs/*1248* %s/outputs/*mesh64* %s/outputs/*cmr_descal* 2>/dev/null | tail -n 40
echo '===MARKERS==='
for id in \
  20260830_132453_cmr_noc64_1222_ackin50_p50_1222 \
  20260830_095259_cmr_noc64_p50_1222 \
  20260831_115856_cmr_mesh64_p50 \
  20260901_172539_cmr_descal_fm64; do
  echo -- $id
  ls %s/outputs/$id/*.sdf %s/outputs/$id/*post.v 2>/dev/null | head
  grep -l CMR_.*_DC_PASS %s/logs/dc/${id}.log %s/logs/dc/${id}* 2>/dev/null | head
done
echo '===JSONL_REMOTE==='
find %s/results -name 'latency.csv' 2>/dev/null | grep cmr_descal | tail -n 40
""" % tuple([ROOT] * 13)
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    rtl = PACK / "rtl"
    print("===LOCAL_RTL===")
    if rtl.is_dir():
        for path in sorted(rtl.rglob("events.jsonl")):
            print(path.relative_to(PACK), path.stat().st_size)
    else:
        print("no", rtl)
    log = PACK / "calibration_log.json"
    if log.is_file():
        data = json.loads(log.read_text(encoding="utf-8"))
        print("===CAL_LOG===")
        print("rtl64", data.get("network_rtl_64"), "rtl256", data.get("network_rtl_256"))
        print("paper", data.get("paper_matrix_allowed"))
        print("failed", data.get("failed"))
        print("pending_hw", data.get("pending_hw"))
        print("notes", (data.get("notes") or "")[:800])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
