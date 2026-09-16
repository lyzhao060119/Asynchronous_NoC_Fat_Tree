#!/usr/bin/env python3
"""Read-only receipt probe for a Sync PROP_temp64 B8 GLS run."""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = os.environ.get("CMR_SYNC64_INSPECT_RUN", "20260916_004500_sync_prop_temp64_b8_m5")
JOB = os.environ.get("CMR_SYNC64_INSPECT_JOB", "12388301")


def main() -> int:
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        receipt = f"/tmp/{RUN}.bjobs.status"
        client.exec_command(
            f"bjobs -a {JOB} -noheader -o 'jobid stat queue exec_host job_name exit_code' "
            f">{receipt} 2>&1"
        )
        time.sleep(3)
        try:
            with sftp.file(receipt, "rb") as handle:
                print("SYNC64_GLS_JOB " + handle.read().decode(errors="replace"), end="")
        except IOError:
            print(f"SYNC64_GLS_JOB_UNKNOWN job={JOB}")
        root = f"{ROOT}/logs/gls/{RUN}"
        try:
            entries = sftp.listdir_attr(root)
        except IOError as exc:
            print(f"SYNC64_GLS_NOT_SUBMITTED run={RUN} error={exc}")
            return 1
        for entry in entries:
            print(f"SYNC64_GLS_ENTRY name={entry.filename} bytes={entry.st_size}")
        try:
            for entry in sftp.listdir_attr(root + "/sdf"):
                print(f"SYNC64_GLS_SDF_ENTRY name={entry.filename} bytes={entry.st_size}")
        except IOError:
            pass
        for suffix in (
            f"sdf/{os.environ.get('CMR_SYNC64_INSPECT_CASE', 'TOPO-UR_n64_s202701_m5_PROP_temp64_top16')}/lsf.log",
            f"sdf/{os.environ.get('CMR_SYNC64_INSPECT_CASE', 'TOPO-UR_n64_s202701_m5_PROP_temp64_top16')}/lsf.err",
            f"sdf/{os.environ.get('CMR_SYNC64_INSPECT_CASE', 'TOPO-UR_n64_s202701_m5_PROP_temp64_top16')}/run.log",
            f"sdf/{os.environ.get('CMR_SYNC64_INSPECT_CASE', 'TOPO-UR_n64_s202701_m5_PROP_temp64_top16')}/compile.log",
            f"sdf/{os.environ.get('CMR_SYNC64_INSPECT_CASE', 'TOPO-UR_n64_s202701_m5_PROP_temp64_top16')}/sdf_annotate.log",
            f"sdf/{os.environ.get('CMR_SYNC64_INSPECT_CASE', 'TOPO-UR_n64_s202701_m5_PROP_temp64_top16')}/result.csv",
        ):
            path = f"{root}/{suffix}"
            try:
                info = sftp.stat(path)
                with sftp.file(path, "rb") as handle:
                    handle.seek(max(0, info.st_size - 8000))
                    text = handle.read().decode(errors="replace")
                print(f"SYNC64_GLS_FILE path={path} bytes={info.st_size}")
                print(text)
            except IOError:
                pass
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
