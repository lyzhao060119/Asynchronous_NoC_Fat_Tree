#!/usr/bin/env python3
"""bkill zombie PEND jobs whose LSF dependency can never be satisfied.

Does not touch RUN DC or live FM64 SDF jobs waiting on that DC.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

KEEP = "11560001 11562401 11562501 11562601 11562701"

CMD = r"""
set +e
KEEP='%(keep)s'
echo '===BEFORE==='
bjobs -u ghy19 2>/dev/null
echo '===PEND==='
bjobs -p -u ghy19 2>/dev/null
echo '===KILL==='
killed=0
skipped=0
for j in $(bjobs -u ghy19 -p -noheader -o jobid 2>/dev/null); do
  keep=0
  for k in $KEEP; do
    if [ "$j" = "$k" ]; then keep=1; break; fi
  done
  if [ "$keep" -eq 1 ]; then
    echo KEEP "$j"
    skipped=$((skipped+1))
    continue
  fi
  detail=$(bjobs -p "$j" 2>/dev/null)
  echo "$detail" | grep -qi 'Dependency condition invalid\|never satisfied'
  if [ $? -eq 0 ]; then
    echo BKILL_ZOMBIE "$j"
    bkill "$j" 2>&1
    killed=$((killed+1))
  else
    echo SKIP_LIVE_PEND "$j"
    echo "$detail" | head -n 6
    skipped=$((skipped+1))
  fi
done
echo KILLED="$killed" SKIPPED="$skipped"
sleep 3
echo '===AFTER==='
bjobs -u ghy19 2>/dev/null
echo '===AFTER_PEND==='
bjobs -p -u ghy19 2>/dev/null
""" % {"keep": KEEP}


def main() -> int:
    client = connect()
    client, text = remote_run_retry(client, CMD)
    print(text, flush=True)
    client.close()
    if "KILLED=" not in text:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
