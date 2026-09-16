#!/usr/bin/env python3
"""Read-only SFTP inspection for the Static64 M5 MAXIMUM-SDF smoke."""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN_ID = "20260915_162500_prop_temp64_static4_m5_smoke"
JOB_ID = "12373401"
CASE = "TOPO-UR_n64_s202701_m5_PROP_temp64_top16"
LOG = f"{ROOT}/logs/gls/{RUN_ID}/sdf_{CASE}"
CSV = f"{ROOT}/results/{RUN_ID}/csv/sdf_{CASE}.csv"


def tail(sftp, path: str, limit: int = 12000) -> str:
    try:
        size = sftp.stat(path).st_size
        with sftp.file(path, "rb") as handle:
            handle.seek(max(0, size - limit))
            data = handle.read(min(size, limit))
        return data.decode(errors="replace").replace("\x00", "")
    except IOError as exc:
        return f"MISSING {path} {exc}\n"


def main() -> int:
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        status = f"/tmp/{RUN_ID}.bjobs.status"
        handles = client.exec_command(
            f"timeout 12 bjobs -a {JOB_ID} -noheader -o 'jobid stat queue exec_host job_name' "
            f">{status} 2>&1; echo STATUS_RC=$? >>{status}"
        )
        time.sleep(14)
        _ = handles
        print("LSF_STATUS_BEGIN")
        print(tail(sftp, status), end="")
        print("LSF_STATUS_END")
        for name, path in (
            ("job", f"{LOG}/job.log"),
            ("job_err", f"{LOG}/job.log.err"),
            ("compile", f"{LOG}/compile.log"),
            ("sdf", f"{LOG}/sdf_annotate.log"),
            ("run", f"{LOG}/run.log"),
            ("stdout", f"{LOG}/stdout.log"),
            ("csv", CSV),
        ):
            print(f"{name.upper()}_BEGIN")
            print(tail(sftp, path), end="")
            print(f"{name.upper()}_END")
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
