#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

LOG = (
    "/home/ghy19/Asynchronous_Router_CMR/logs/gls/"
    "20260901_205606_cmr_descal_fm64_hop/sdf/DBG-64_fm64_6to44/run.log"
)


def main() -> int:
    client = connect()
    cmd = r"""
echo ===COUNTS===
grep TB_HOP_COUNTS %(log)s
echo ===PATH_TAIL===
grep -E 'PathEnabled|TailPassed' %(log)s
echo ===LATE===
grep 'TB_HOP t=29' %(log)s
echo ===LOCAL45===
grep 'link=meshR_4_5.local_out' %(log)s
echo ===SOUTH45===
grep 'link=meshR_4_5.south_in' %(log)s
echo ===N44===
grep 'link=meshR_4_4.north_out' %(log)s
echo ===N41===
grep 'link=meshR_4_1.north_out' %(log)s
echo ===W60===
grep 'link=meshR_6_0.west_out' %(log)s
echo ===W50===
grep 'link=meshR_5_0.west_out' %(log)s
echo ===N40===
grep 'link=meshR_4_0.north_out' %(log)s
""" % {"log": LOG}
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
