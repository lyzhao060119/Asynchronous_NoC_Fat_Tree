#!/usr/bin/env python3
"""Read-only status and result inspection for Static64 selection GLS."""
from __future__ import annotations
import csv
import io
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = "20260915_162500_prop_temp64_static4_m5_smoke"
JOBS = {100: "12376901", 420: "12377001", 340: "12377101", 280: "12377201", 220: "12377301", 160: "12377401"}


def read(sftp, path: str) -> str:
    try:
        with sftp.file(path, "rb") as handle:
            return handle.read().decode(errors="replace").replace("\x00", "")
    except IOError:
        return ""


def main() -> int:
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        status = f"/tmp/{RUN}.selection.status"
        ids = " ".join(JOBS.values())
        handles = client.exec_command(
            f"timeout 12 bjobs -a {ids} -noheader -o 'jobid stat queue exec_host job_name' >{status} 2>&1; echo STATUS_RC=$? >>{status}"
        )
        _ = handles
        time.sleep(14)
        print(read(sftp, status), end="")
        for load, job in JOBS.items():
            case = f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"
            csv_path = f"{ROOT}/results/{RUN}/csv/sdf_{case}.csv"
            text = read(sftp, csv_path)
            if not text:
                print(f"STATIC64_POINT load={load} job={job} result=PENDING")
                continue
            row = next(csv.DictReader(io.StringIO(text)))
            print(
                "STATIC64_POINT "
                f"load={load} job={job} result={row.get('pass_fail')} "
                f"injected={row.get('injected_flits')} delivered={row.get('delivered_flits')} "
                f"missing={row.get('missing_expected_flits')} unexpected={row.get('unexpected_flits')} "
                f"backlog={row.get('measurement_backlog_flits')} "
                f"delivery_rate={row.get('delivered_mflit_port_s')} "
                f"p95={row.get('flit_lat_p95_ns')} p99={row.get('flit_lat_p99_ns')}"
            )
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
