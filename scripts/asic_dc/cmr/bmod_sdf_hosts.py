#!/usr/bin/env python3
"""Move pending FM64 SDF jobs off node21. Cluster bmod is zsub (cannot rehost).

Keeps done(DC) dependency. Does not touch the running DC job.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = "20260901_172539_cmr_descal_fm64"
DEP = "cmr_descal_mesh64_dc_%s" % RUN
HOSTS = "node26 node24 node18"
OLD_JIDS = ("11560501", "11560601", "11560701", "11560801")
CASES = (
    "DBG-64_fm64_6to44",
    "KEY-64_n64_s900001_zero_FM64_top0",
    "TOPO-UR_n64_s900001_zero_FM64_top0",
    "TOPO-UR_n64_s900001_r0p10_FM64_top0",
)


def main() -> int:
    cases = " ".join(CASES)
    old = " ".join(OLD_JIDS)
    cmd = r"""
set +e
echo '===PROBE==='
echo LSF_BINDIR="$LSF_BINDIR"
type bmod 2>&1 | head -n 2
type bsub 2>&1 | head -n 2
echo '===BEFORE==='
bjobs -u ghy19 2>/dev/null
echo '===PEND_DETAIL==='
for j in %(old)s; do
  echo -- "$j"
  bjobs -noheader -o 'jobid stat exec_host name' "$j" 2>/dev/null
  bjobs -l "$j" 2>/dev/null | grep -E 'Status|Specified Hosts|Dependency|PENDING REASONS|Job <' | head -n 12
done
echo '===BHOSTS==='
bhosts -w node21 node26 node24 node18 2>/dev/null

echo '===KILL_PEND_SDF==='
for j in %(old)s; do
  st=$(bjobs -noheader -o stat "$j" 2>/dev/null | awk '{print $1}')
  echo JOB "$j" STAT "$st"
  if [ "$st" = PEND ]; then
    bkill "$j" 2>&1
  else
    echo SKIP_NOT_PEND "$j" "$st"
  fi
done
sleep 3
echo '===POST_KILL==='
bjobs %(old)s 2>&1 | head -n 20

echo '===RESUBMIT==='
ROOT=%(root)s
RUN=%(run)s
DEP=%(dep)s
HOSTS='%(hosts)s'
ok=0
fail=0
for name in %(cases)s; do
  wrap="$ROOT/logs/gls/$RUN/sdf_${name}.sh"
  log="$ROOT/logs/gls/$RUN/sdf_${name}.bsub.log"
  err="$ROOT/logs/gls/$RUN/sdf_${name}.bsub.err"
  jn="cmr_descal_mesh64_sdf_${name}"
  if [ ! -f "$wrap" ]; then
    echo MISSING_WRAPPER "$wrap"
    fail=$((fail+1))
    continue
  fi
  chmod +x "$wrap" 2>/dev/null
  echo SUBMIT "$jn"
  bsub -n 8 -m "$HOSTS" -w "done($DEP)" -o "$log" -e "$err" -J "$jn" "$wrap"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok=$((ok+1))
  else
    echo SUBMIT_FAIL "$jn" rc="$rc"
    fail=$((fail+1))
  fi
done
echo RESUBMIT_OK="$ok" FAIL="$fail"

echo '===AFTER==='
bjobs -u ghy19 2>/dev/null
echo '===NEW_HOSTS==='
bjobs -u ghy19 -p 2>/dev/null | head -n 40
for jn in %(cases)s; do
  echo -- sdf_"$jn"
  bjobs -u ghy19 -J "cmr_descal_mesh64_sdf_${jn}" -l 2>/dev/null | grep -E 'Job <|Status|Specified Hosts|Dependency|PENDING' | head -n 10
done
echo '===DC==='
bjobs -noheader -o 'jobid stat run_time exec_host name' 11560001 2>/dev/null
""" % {
        "old": old,
        "root": ROOT,
        "run": RUN,
        "dep": DEP,
        "hosts": HOSTS,
        "cases": cases,
    }
    client = connect()
    client, text = remote_run_retry(client, cmd)
    print(text, flush=True)
    client.close()
    if "RESUBMIT_OK=" not in text:
        return 2
    if "RESUBMIT_OK=4 FAIL=0" not in text and "RESUBMIT_OK=4" not in text:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
