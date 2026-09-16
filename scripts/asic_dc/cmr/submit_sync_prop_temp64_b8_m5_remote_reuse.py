#!/usr/bin/env python3
"""Submit the already-staged Sync B8 M5 wrapper without uploading any case."""
from __future__ import annotations

import os
import shlex
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = "20260916_004500_sync_prop_temp64_b8_m5"
CASE = "TOPO-UR_n64_s202701_m5_PROP_temp64_top16"


def main() -> int:
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    wrapper = f"{ROOT}/logs/gls/{RUN}/sdf_{CASE}.sh"
    log = f"{ROOT}/logs/gls/{RUN}/sdf/{CASE}"
    receipt = f"/tmp/{RUN}.m5.submit.log"
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        if sftp.stat(wrapper).st_size <= 0:
            raise RuntimeError("missing staged wrapper: " + wrapper)
        command = (
            f"mkdir -p {shlex.quote(log)}; "
            f"bsub -n 8 -m 'node21 node26 node24 node18' "
            f"-oo {shlex.quote(log + '/lsf.log')} -eo {shlex.quote(log + '/lsf.err')} "
            f"-J {shlex.quote('sync_b8_m5')} {shlex.quote(wrapper)}"
        )
        client.exec_command(f"nohup bash -lc {shlex.quote(command)} >{shlex.quote(receipt)} 2>&1 &")
        text = ""
        for _ in range(6):
            time.sleep(5)
            try:
                with sftp.file(receipt, "rb") as handle:
                    text = handle.read().decode(errors="replace")
                break
            except IOError:
                continue
        if not text:
            raise RuntimeError("M5 submit receipt did not appear within 30 seconds")
        print(text, end="")
        if "Job <" not in text:
            raise RuntimeError("M5 submit receipt lacks LSF job id")
        print("SYNC_B8_M5_SUBMITTED")
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
