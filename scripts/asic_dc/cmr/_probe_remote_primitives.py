#!/usr/bin/env python3
from run_remote_cmr_flow import remote_run
from run_remote_cmr_noc16_sdf import connect

c = connect()
print(
    remote_run(
        c,
        "echo STATS; bjobs -u ghy19 -noheader -o stat 2>/dev/null | sort | uniq -c; "
        "echo FROZEN_L3; ls /home/ghy19/Asynchronous_Router_CMR/outputs/20260830_cmr_fat_l3_hop_del050_ackin050 2>&1 | head; "
        "echo NEW; ls -d /home/ghy19/Asynchronous_Router_CMR/outputs/20260831_cmr_* 2>&1 | head",
    )
)
c.close()
