#!/usr/bin/env python3
"""Poll FM64 DC + SDF and record the first extra-hop location on fail.

Usage: poll_fm64_hop.py [run_id]
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
CASES = (
    "DBG-64_fm64_6to44",
    "KEY-64_n64_s900001_zero_FM64_top0",
    "TOPO-UR_n64_s900001_zero_FM64_top0",
    "TOPO-UR_n64_s900001_r0p10_FM64_top0",
)


def main() -> int:
    run = sys.argv[1] if len(sys.argv) > 1 else "20260901_205606_cmr_descal_fm64_hop"
    cases = " ".join("%s/logs/gls/%s/sdf/%s/run.log" % (ROOT, run, name) for name in CASES)
    client = connect()
    cmd = r"""
echo BJOBS
bjobs -u ghy19 -noheader -o 'jobid stat run_time exec_host name' 2>/dev/null | grep -E 'mesh64|fm64|%(run)s' || true
echo DC_MARK
grep -E 'CMR_MESH64_DC_PASS|CMR_MESH64_DC_FAIL|CMR_MESH64_STRUCTURE|GRANT_HOLD|LATCH_REOPEN' %(root)s/logs/dc/%(run)s.log 2>/dev/null | grep -v 'puts ' | tail -n 20
echo SDF_CASES
for p in %(cases)s; do
  echo == $p
  grep -E 'TB_RESULT|TB_UNEXPECTED|TB_STALL|TB_X_FAIL|TB_HOP_COUNTS|TB_UNEX_PORT|TB_UNEX_CLASS|Doing SDF|IFNSDFA|Error-|Fatal' "$p" 2>/dev/null | tail -n 20
done
echo LOCATE_DBG
GLS=%(root)s/logs/gls/%(run)s/sdf/DBG-64_fm64_6to44
grep -E 'TB_HOP_COUNTS|TB_UNEXPECTED|TB_UNEX_|TB_RESULT' $GLS/run.log 2>/dev/null | head -n 40
echo FIRST_EXTRA
python3 - <<'PY'
import re
from pathlib import Path
p = Path("%(root)s/logs/gls/%(run)s/sdf/DBG-64_fm64_6to44/run.log")
if not p.is_file():
    raise SystemExit(0)
counts = {}
first_extra = None
for line in p.read_text(errors="replace").splitlines():
    m = re.search(r"TB_HOP t=(\S+) link=(\S+) n=(\d+).*ht=(\d+).*flit=(\S+)", line)
    if not m:
        continue
    t, link, n, ht, flit = m.group(1), m.group(2), int(m.group(3)), m.group(4), m.group(5)
    counts[link] = n
    if n > 5 and first_extra is None and "PathEnabled" not in link and "TailPassed" not in link:
        first_extra = (t, link, n, ht, flit)
print("HOP_MAX", " ".join("%%s=%%d" %% (k, v) for k, v in counts.items()))
if first_extra:
    t, link, n, ht, flit = first_extra
    print("FIRST_EXTRA_HOP t=%%s link=%%s n=%%d ht=%%s flit=%%s" %% (t, link, n, ht, flit))
else:
    print("FIRST_EXTRA_HOP none")
PY
""" % {"root": ROOT, "run": run, "cases": cases}
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
