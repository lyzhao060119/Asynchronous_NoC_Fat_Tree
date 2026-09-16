#!/usr/bin/env python3
"""Read-only Static64 DC inspection through SFTP; opens no exec channel."""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_remote_cmr_fat_tree_noc16_sdf import connect

RUN_ID = "20260915_144500_prop_temp64_static4_dc"
JOB_ID = "12338301"
ROOT = "/home/ghy19/Asynchronous_Router_CMR"


def read_tail(sftp, path: str, limit: int = 12000) -> str:
    try:
        size = sftp.stat(path).st_size
        with sftp.file(path, "rb") as handle:
            handle.seek(max(0, size - limit))
            data = handle.read(min(limit, size))
        return data.decode(errors="replace").replace("\x00", "")
    except IOError as exc:
        return f"SFTP_MISSING {path} {exc}\n"


def show_stat(sftp, path: str) -> None:
    try:
        info = sftp.stat(path)
        print(f"SFTP_EXISTS size={info.st_size} path={path}")
    except IOError as exc:
        print(f"SFTP_MISSING path={path} error={exc}")


def main() -> int:
    host = os.environ.get("C1_HOST", "192.168.2.8")
    os.environ["C1_HOST"] = host
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        # Do not read the exec channel.  Persist the bounded LSF query and read
        # it back through SFTP, avoiding the site's leaked stdout handles.
        status_path = f"/tmp/{RUN_ID}.bjobs.status"
        status_stdin, status_stdout, status_stderr = client.exec_command(
            f"timeout 12 bjobs -a {JOB_ID} -noheader -o 'jobid stat queue exec_host job_name' "
            f">{status_path} 2>&1; echo STATUS_RC=$? >>{status_path}"
        )
        _ = (status_stdin, status_stdout, status_stderr)
        time.sleep(14)
        paths = (
            f"{ROOT}/rtl/prop_temp64_{RUN_ID}/PROP_temp64_static4.v",
            f"{ROOT}/scripts/prop_temp64_{RUN_ID}/run_dc_prop_temp64.tcl",
            f"{ROOT}/logs/dc/{RUN_ID}.sh",
            f"{ROOT}/work/dc_ft_noc64_{RUN_ID}",
            f"{ROOT}/outputs/{RUN_ID}",
            f"{ROOT}/logs/dc/{RUN_ID}.retry.log",
            f"{ROOT}/logs/dc/{RUN_ID}.retry.log.err",
        )
        for path in paths:
            show_stat(sftp, path)
        try:
            for item in sftp.listdir_attr(f"{ROOT}/outputs/{RUN_ID}"):
                print(f"SFTP_OUTPUT name={item.filename} size={item.st_size}")
        except IOError as exc:
            print(f"SFTP_OUTPUT_LIST_FAIL {exc}")
        print("SFTP_RESUBMIT_LOG_BEGIN")
        print(read_tail(sftp, f"/tmp/{RUN_ID}.resubmit.log"), end="")
        print("SFTP_RESUBMIT_LOG_END")
        print("SFTP_BJOBS_BEGIN")
        print(read_tail(sftp, status_path), end="")
        print("SFTP_BJOBS_END")
        print("SFTP_DC_LOG_BEGIN")
        print(read_tail(sftp, f"{ROOT}/logs/dc/{RUN_ID}.retry.log"), end="")
        print("SFTP_DC_LOG_END")
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
