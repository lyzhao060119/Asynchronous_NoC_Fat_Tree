#!/usr/bin/env python3
"""Submit Static64 M100 and all common-high selection probes as one batch."""
from __future__ import annotations

import os
import shlex
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect
from submit_static64_m5_sftp import mkdirs, put_verified, read_text

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN_ID = "20260915_203000_prop_temp64_static4_selection"
NETLIST_RUN = "20260915_144500_prop_temp64_static4_dc"
LOADS = (100, 420, 340, 280, 220, 160)
SIM = f"{ROOT}/sim/prop_temp64_{RUN_ID}"
SCRIPT_DIR = f"{ROOT}/scripts/prop_temp64_{RUN_ID}"


def main() -> int:
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        mkdirs(sftp, SIM + "/cases")
        mkdirs(sftp, SCRIPT_DIR)
        common = {
            HERE / "run_gls_prop_temp64.sh": f"{SCRIPT_DIR}/run_gls_prop_temp64.sh",
            REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": f"{SIM}/async_prop_temp64_port_adapter.sv",
            REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": f"{SIM}/tb_noc64_async_boundary.sv",
            HERE / "tb_cmr_noc64_async_boundary_failfast.sv": f"{SIM}/tb_cmr_noc64_async_boundary_failfast.sv",
            REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py": f"{SIM}/patch_gls_netlist.py",
        }
        for source, destination in common.items():
            put_verified(sftp, source.read_bytes(), destination)
        submits = []
        for load in LOADS:
            case = f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"
            source = HERE / "generated_cases/20260913_prop_temp64_asap_m5_500_202701/cases" / (case + ".case")
            remote_case = f"{SIM}/cases/{case}.case"
            put_verified(sftp, source.read_bytes(), remote_case)
            log = f"{ROOT}/logs/gls/{RUN_ID}/sdf_{case}"
            mkdirs(sftp, log)
            wrapper = f"{log}/launch.sh"
            body = f"""#!/bin/bash
source /etc/profile 2>/dev/null || true
export CMR_REMOTE_ROOT={ROOT}
export PROP_TEMP64_RUN_ID={RUN_ID}
export PROP_TEMP64_DUT_NAME=PROP_temp64_static4
export PROP_TEMP64_NETLIST_RUN_ID={NETLIST_RUN}
export PROP_TEMP64_MODE=sdf
export PROP_TEMP64_CASE_NAME={case}
export PROP_TEMP64_CASE_FILE={remote_case}
export PROP_TEMP64_RX_CAPTURE_NS=0.1
exec bash {SCRIPT_DIR}/run_gls_prop_temp64.sh
"""
            put_verified(sftp, body.encode(), wrapper)
            submits.append(
                f"chmod +x {wrapper}; bsub -n 8 -m 'node21 node26 node24 node18' "
                f"-o {log}/job.log -e {log}/job.log.err -J static64_m{load}_{RUN_ID} {wrapper}"
            )
        receipt = f"/tmp/{RUN_ID}.submit.log"
        command = f"chmod +x {SCRIPT_DIR}/run_gls_prop_temp64.sh; " + "; ".join(submits)
        handles = client.exec_command(
            f"nohup bash -lc {shlex.quote(command)} >{receipt} 2>&1 &"
        )
        _ = handles
        time.sleep(12)
        reply = read_text(sftp, receipt)
        print(reply, end="")
        if reply.count("Job <") != len(LOADS):
            raise RuntimeError("expected six LSF receipts")
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
