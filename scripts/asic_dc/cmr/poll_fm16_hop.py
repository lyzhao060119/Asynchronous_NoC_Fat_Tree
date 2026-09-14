#!/usr/bin/env python3
"""Poll 4x4 mesh DC + hop-probe SDF.  Pass run_id as argv[1]."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
CASE = "DBG-16_fm16_3to13"


def main() -> int:
    run = sys.argv[1] if len(sys.argv) > 1 else ""
    if not run:
        print("usage: poll_fm16_hop.py <run_id>", flush=True)
        return 2
    client = connect()
    cmd = r"""
echo BJOBS
bjobs -u ghy19 -noheader -o 'jobid stat run_time exec_host name' 2>/dev/null | grep -E 'mesh16|fm16|%(run)s' || true
echo DC_MARK
grep -E 'CMR_MESH64_DC_PASS|CMR_MESH64_DC_FAIL|GRANT_HOLD|STRUCTURE|Error:' %(root)s/logs/dc/%(run)s.log %(root)s/logs/dc/%(run)s.log.err 2>/dev/null | tail -n 40
echo COMPILE
grep -E 'Error-|not found|undeclared' %(root)s/logs/gls/%(run)s/sdf/%(case)s/compile.log 2>/dev/null | head -n 40
echo HOP
grep -E 'TB_HOP|TB_HOP_COUNTS|TB_RESULT|TB_UNEXPECTED|TB_MESH_LOCAL13|Error-|Fatal' %(root)s/logs/gls/%(run)s/sdf/%(case)s/run.log %(root)s/logs/gls/%(run)s/sdf_%(case)s.bsub.log 2>/dev/null | head -n 120
echo OUTPUTS
ls -la %(root)s/outputs/%(run)s 2>/dev/null | head -n 20
""" % {"root": ROOT, "run": run, "case": CASE}
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
