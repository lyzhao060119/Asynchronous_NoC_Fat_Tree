#!/usr/bin/env python3
"""Cancel a failed Static64 DC attempt and resubmit its verified remote wrapper.

No RTL, Tcl, or wrapper is uploaded.  This recovery path is only valid after
the original upload manifest recorded SHA-256-verified inputs.
"""
from __future__ import annotations

import shlex
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_remote_cmr_fat_tree_noc16_sdf import connect

RUN_ID = "20260915_144500_prop_temp64_static4_dc"
OLD_JOB = "12330301"
ROOT = "/home/ghy19/Asynchronous_Router_CMR"


def main() -> int:
    client = connect(attempts=2)
    try:
        wrapper = f"{ROOT}/logs/dc/{RUN_ID}.sh"
        log = f"{ROOT}/logs/dc/{RUN_ID}.retry.log"
        rtl = f"{ROOT}/rtl/prop_temp64_{RUN_ID}"
        tcl = f"{ROOT}/scripts/prop_temp64_{RUN_ID}/run_dc_prop_temp64.tcl"
        command = (
            f"test -s {wrapper} && test -s {tcl} && test -s {rtl}/PROP_temp64_static4.v "
            f"|| {{ echo STATIC64_REUSE_INPUT_MISSING; exit 2; }}; "
            f"bkill {OLD_JOB} >/dev/null 2>&1 || true; "
            f"rm -rf {ROOT}/work/dc_ft_noc64_{RUN_ID}; "
            f"bsub -n 16 -m 'node21 node26 node24 node18' -o {log} -e {log}.err "
            f"-J prop_temp64_static4_dc_retry_{RUN_ID} {wrapper}"
        )
        # The site intermittently stalls while reading command stdout. Submit
        # in a detached shell; the wrapper/log/artifacts remain authoritative.
        dispatch = (
            f"nohup bash -lc {shlex.quote(command)} "
            f">/tmp/{RUN_ID}.resubmit.log 2>&1 & echo STATIC64_DC_DISPATCHED"
        )
        channel = client.get_transport().open_session()
        channel.exec_command(dispatch)
        time.sleep(2)
        if channel.recv_ready():
            print(channel.recv(4096).decode(errors="replace"), end="")
        else:
            print("STATIC64_DC_DISPATCH_NO_STDOUT", RUN_ID, flush=True)
        channel.close()
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
