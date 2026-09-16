#!/usr/bin/env python3
"""Submit one Static64 M5 MAXIMUM-SDF smoke using SFTP for all evidence I/O."""
from __future__ import annotations

import hashlib
import os
import shlex
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
LOAD = int(os.environ.get("STATIC64_GLS_LOAD", "5"))
RUN_ID = os.environ.get(
    "STATIC64_GLS_RUN_ID", f"20260915_static64_m{LOAD}_gls"
)
NETLIST_RUN = "20260915_144500_prop_temp64_static4_dc"
CASE_NAME = f"TOPO-UR_n64_s202701_m{LOAD}_PROP_temp64_top16"
SIM = f"{ROOT}/sim/prop_temp64_{RUN_ID}"
SCRIPT_DIR = f"{ROOT}/scripts/prop_temp64_{RUN_ID}"
LOG_DIR = f"{ROOT}/logs/gls/{RUN_ID}/sdf_{CASE_NAME}"


def mkdirs(sftp, path: str) -> None:
    current = ""
    for part in path.strip("/").split("/"):
        current += "/" + part
        try:
            sftp.stat(current)
        except IOError:
            sftp.mkdir(current)


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def put_verified(sftp, data: bytes, destination: str) -> str:
    data = data.replace(b"\r\n", b"\n")
    temporary = destination + f".upload_{os.getpid()}"
    with sftp.file(temporary, "wb") as handle:
        handle.write(data)
        handle.flush()
    if sftp.stat(temporary).st_size != len(data):
        raise RuntimeError("remote size mismatch: " + destination)
    try:
        sftp.remove(destination)
    except IOError:
        pass
    sftp.rename(temporary, destination)
    digest = hashlib.sha256()
    with sftp.file(destination, "rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    if digest.hexdigest() != sha_bytes(data):
        raise RuntimeError("remote SHA-256 mismatch: " + destination)
    print(f"STATIC64_M5_UPLOAD_OK {destination} {len(data)} {digest.hexdigest()}")
    return digest.hexdigest()


def read_text(sftp, path: str) -> str:
    with sftp.file(path, "rb") as handle:
        return handle.read().decode(errors="replace")


def main() -> int:
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        for directory in (SIM + "/cases", SCRIPT_DIR, LOG_DIR):
            mkdirs(sftp, directory)
        files = {
            HERE / "run_gls_prop_temp64.sh": f"{SCRIPT_DIR}/run_gls_prop_temp64.sh",
            REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": f"{SIM}/async_prop_temp64_port_adapter.sv",
            REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": f"{SIM}/tb_noc64_async_boundary.sv",
            HERE / "tb_cmr_noc64_async_boundary_failfast.sv": f"{SIM}/tb_cmr_noc64_async_boundary_failfast.sv",
            REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py": f"{SIM}/patch_gls_netlist.py",
            HERE / "generated_cases/20260913_prop_temp64_asap_m5_500_202701/cases" / (CASE_NAME + ".case"): f"{SIM}/cases/{CASE_NAME}.case",
        }
        for source, destination in files.items():
            if not source.is_file() or source.stat().st_size == 0:
                raise RuntimeError("missing local input: " + str(source))
            put_verified(sftp, source.read_bytes(), destination)
        wrapper = f"{LOG_DIR}/launch.sh"
        body = f"""#!/bin/bash
source /etc/profile 2>/dev/null || true
export CMR_REMOTE_ROOT={ROOT}
export PROP_TEMP64_RUN_ID={RUN_ID}
export PROP_TEMP64_DUT_NAME=PROP_temp64_static4
export PROP_TEMP64_NETLIST_RUN_ID={NETLIST_RUN}
export PROP_TEMP64_MODE=sdf
export PROP_TEMP64_CASE_NAME={CASE_NAME}
export PROP_TEMP64_CASE_FILE={SIM}/cases/{CASE_NAME}.case
export PROP_TEMP64_RX_CAPTURE_NS=0.1
exec bash {SCRIPT_DIR}/run_gls_prop_temp64.sh
"""
        put_verified(sftp, body.encode(), wrapper)
        submit_file = f"/tmp/{RUN_ID}.submit.log"
        command = (
            f"chmod +x {SCRIPT_DIR}/run_gls_prop_temp64.sh {wrapper}; "
            f"bsub -n 8 -m 'node21 node26 node24 node18' "
            f"-o {LOG_DIR}/job.log -e {LOG_DIR}/job.log.err "
            f"-J static64_m5_{RUN_ID} {wrapper}"
        )
        stdin, stdout, stderr = client.exec_command(
            f"nohup bash -lc {shlex.quote(command)} >{submit_file} 2>&1 &"
        )
        _ = (stdin, stdout, stderr)
        time.sleep(8)
        reply = read_text(sftp, submit_file)
        print(reply, end="")
        if "Job <" not in reply:
            raise RuntimeError("missing LSF submission receipt")
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
