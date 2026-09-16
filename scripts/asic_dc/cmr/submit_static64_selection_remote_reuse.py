#!/usr/bin/env python3
"""Submit Static64 selection GLS using only inputs already present remotely."""
from __future__ import annotations

import os
import re
import shlex
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STATIC_RUN = "20260915_162500_prop_temp64_static4_m5_smoke"
NETLIST_RUN = "20260915_144500_prop_temp64_static4_dc"
LOADS = (100, 420, 340, 280, 220, 160)
STATIC_SIM = f"{ROOT}/sim/prop_temp64_{STATIC_RUN}"
SHELL = f"{ROOT}/scripts/prop_temp64_{STATIC_RUN}/run_gls_prop_temp64.sh"
RECEIPT = f"/tmp/{STATIC_RUN}.selection_reuse.submit.log"


def read_text(sftp, path: str) -> str:
    with sftp.file(path, "rb") as handle:
        return handle.read().decode(errors="replace")


def find_remote_case(sftp, case: str, run_dirs: list[str]) -> str:
    preferred = "prop_temp64_20260913_prop_temp64_asap_uc_m5_200"
    ordered = ([preferred] if preferred in run_dirs else []) + [
        name for name in run_dirs if name != preferred
    ]
    for name in ordered:
        path = f"{ROOT}/sim/{name}/cases/{case}.case"
        try:
            if sftp.stat(path).st_size > 0:
                return path
        except IOError:
            continue
    raise RuntimeError("canonical remote case not found: " + case)


def main() -> int:
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        required = (
            SHELL,
            f"{STATIC_SIM}/async_prop_temp64_port_adapter.sv",
            f"{STATIC_SIM}/tb_noc64_async_boundary.sv",
            f"{STATIC_SIM}/tb_cmr_noc64_async_boundary_failfast.sv",
            f"{ROOT}/outputs/{NETLIST_RUN}/PROP_temp64_static4_post.v",
            f"{ROOT}/outputs/{NETLIST_RUN}/PROP_temp64_static4.sdf",
        )
        for path in required:
            size = sftp.stat(path).st_size
            if size <= 0:
                raise RuntimeError("empty remote input: " + path)
            print(f"STATIC64_REUSE_INPUT size={size} path={path}")
        commands = []
        case_paths = []
        run_dirs = [
            name for name in sftp.listdir(f"{ROOT}/sim")
            if name.startswith("prop_temp64_")
        ]
        for load in LOADS:
            case = f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"
            case_path = find_remote_case(sftp, case, run_dirs)
            size = sftp.stat(case_path).st_size
            if size <= 0:
                raise RuntimeError("empty remote case: " + case_path)
            print(f"STATIC64_REUSE_CASE load={load} size={size} path={case_path}")
            case_paths.append(case_path)
            log = f"{ROOT}/logs/gls/{STATIC_RUN}/sdf_{case}"
            env = (
                f"CMR_REMOTE_ROOT={ROOT} PROP_TEMP64_RUN_ID={STATIC_RUN} "
                f"PROP_TEMP64_DUT_NAME=PROP_temp64_static4 "
                f"PROP_TEMP64_NETLIST_RUN_ID={NETLIST_RUN} PROP_TEMP64_MODE=sdf "
                f"PROP_TEMP64_CASE_NAME={case} PROP_TEMP64_CASE_FILE={case_path} "
                "PROP_TEMP64_RX_CAPTURE_NS=0.1"
            )
            commands.append(
                f"mkdir -p {log}; bsub -n 8 -m 'node21 node26 node24 node18' "
                f"-o {log}/job.log -e {log}/job.log.err -J static64_m{load}_reuse "
                f"env {env} bash {SHELL}"
            )
        command = "sha256sum " + " ".join(case_paths) + "; " + "; ".join(commands)
        handles = client.exec_command(
            f"nohup bash -lc {shlex.quote(command)} >{RECEIPT} 2>&1 &"
        )
        _ = handles
        time.sleep(15)
        reply = read_text(sftp, RECEIPT)
        print(reply, end="")
        jobs = re.findall(r"Job <(\d+)>", reply)
        if len(jobs) != len(LOADS):
            raise RuntimeError(f"expected six jobs, received {jobs}")
        print("STATIC64_SELECTION_REUSE_SUBMITTED", ",".join(jobs))
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
