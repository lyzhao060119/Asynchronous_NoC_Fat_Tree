#!/usr/bin/env python3
"""Run one Thin CMR NoC16 case on a frozen post-DC netlist without SDF."""
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_fat_tree_noc16_sdf import connect, wait_job

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get("CMR_NOC16_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_thin_func_tab_p50")
NETLIST_RUN_ID = os.environ.get("CMR_NOC16_NETLIST_RUN_ID", "20260821_cmr_thin_pathclear_header_sdf_01")
CASE = os.environ.get("CMR_NOC16_CASE_NAME", "TAB-NET-UR-3f-r0p50")
L2_X_PROBE = os.environ.get("CMR_NOC16_L2_X_PROBE", "0") == "1"
THIN_STALL_PROBE = os.environ.get("CMR_NOC16_THIN_STALL_PROBE", "0") == "1"
FUNCTIONAL_STALL_PROBE = os.environ.get("CMR_NOC16_FUNCTIONAL_STALL_PROBE", "0") == "1"
IPM1_ACK_PROBE = os.environ.get("CMR_NOC16_IPM1_ACK_PROBE", "0") == "1"
LOCAL_CASE_FILE = (
    Path(os.environ["CMR_NOC16_LOCAL_CASE_FILE"]).resolve()
    if os.environ.get("CMR_NOC16_LOCAL_CASE_FILE") else None
)
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def fetch_artifacts(sftp, remote_log, remote_csv):
    RESULT.mkdir(parents=True, exist_ok=True)
    artifacts = {}
    for filename in (
        "input_hashes.log", "compile.log", "stdout.log", "run.log",
        "events.csv", "latency.csv", "result.csv",
    ):
        try:
            sftp.get(f"{remote_log}/{filename}", str(RESULT / filename))
            artifacts[filename] = True
        except IOError:
            artifacts[filename] = False
    try:
        sftp.get(remote_csv, str(RESULT / f"{CASE}.csv"))
        artifacts[f"{CASE}.csv"] = True
    except IOError:
        artifacts[f"{CASE}.csv"] = False
    return artifacts

def main():
    client = connect()
    if LOCAL_CASE_FILE:
        if not LOCAL_CASE_FILE.is_file():
            raise RuntimeError("missing local case " + str(LOCAL_CASE_FILE))
        case_file = f"{ROOT}/sim/cases/{LOCAL_CASE_FILE.name}"
    else:
        case_file = f"{ULTRA}/sim/cases/{CASE}.case"
        if "" == remote_run(client, f"test -s {shlex.quote(case_file)} && echo OK").strip():
            raise RuntimeError("missing remote case " + case_file)
    if "" == remote_run(client, f"test -s {ROOT}/outputs/{NETLIST_RUN_ID}/NoC_16nodes_post.v && echo OK").strip():
        raise RuntimeError("missing post-DC Thin netlist " + NETLIST_RUN_ID)
    remote_run(client, f"mkdir -p {ROOT}/scripts {ROOT}/sim/tb {ROOT}/sim/cases {ROOT}/logs/gls/{RUN_ID} {ROOT}/results/{RUN_ID}/csv")
    remote_run(client, f"cp {ULTRA}/sim/tb/async_noc16_port_adapter.sv {ROOT}/sim/tb/")
    uploads = {
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16_func.sh": f"{ROOT}/scripts/run_gls_cmr_noc16_func.sh",
        REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py": f"{ROOT}/scripts/patch_gls_netlist.py",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv": f"{ROOT}/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv": f"{ROOT}/sim/tb/tb_noc16_async_boundary.sv",
    }
    if L2_X_PROBE:
        uploads[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_l2_parent_x_probe.sv"] = \
            f"{ROOT}/sim/tb/tb_cmr_thin_l2_parent_x_probe.sv"
    if THIN_STALL_PROBE:
        uploads[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_core8_stall_probe.sv"] = \
            f"{ROOT}/sim/tb/tb_cmr_thin_core8_stall_probe.sv"
    if FUNCTIONAL_STALL_PROBE:
        uploads[REPO / "scripts/asic_dc/cmr/tb_cmr_functional_stall_probe.sv"] = \
            f"{ROOT}/sim/tb/tb_cmr_functional_stall_probe.sv"
    if IPM1_ACK_PROBE:
        uploads[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_ipm1_ack_probe.sv"] = \
            f"{ROOT}/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv"
    if LOCAL_CASE_FILE:
        uploads[LOCAL_CASE_FILE] = case_file
    sftp = client.open_sftp()
    for local, remote in uploads.items():
        atomic_put(client, sftp, local, remote)
    wrapper = f"{ROOT}/logs/gls/{RUN_ID}/func_{CASE}.sh"
    body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n" + (
        f"export CMR_REMOTE_ROOT={shlex.quote(ROOT)} CMR_NOC16_RUN_ID={shlex.quote(RUN_ID)} "
        f"CMR_NOC16_NETLIST_RUN_ID={shlex.quote(NETLIST_RUN_ID)} CMR_NOC16_CASE_NAME={shlex.quote(CASE)} "
        f"CMR_NOC16_CASE_FILE={shlex.quote(case_file)} "
        f"CMR_NOC16_L2_X_PROBE={'1' if L2_X_PROBE else '0'} "
        f"CMR_NOC16_THIN_STALL_PROBE={'1' if THIN_STALL_PROBE else '0'} "
        f"CMR_NOC16_FUNCTIONAL_STALL_PROBE={'1' if FUNCTIONAL_STALL_PROBE else '0'} "
        f"CMR_NOC16_IPM1_ACK_PROBE={'1' if IPM1_ACK_PROBE else '0'}\n"
        f"exec bash {ROOT}/scripts/run_gls_cmr_noc16_func.sh\n")
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, f"chmod +x {ROOT}/scripts/run_gls_cmr_noc16_func.sh {wrapper}")
    submit = remote_run(client, f"bsub -n 8 -o {ROOT}/logs/gls/{RUN_ID}/func_{CASE}.bsub.log -e {ROOT}/logs/gls/{RUN_ID}/func_{CASE}.bsub.err -J cmr_thin_func_{RUN_ID} {wrapper}")
    match = re.search(r"Job <(\d+)>", submit)
    if not match:
        raise RuntimeError("submission failed: " + submit)
    print("FUNC_GLS_JOB", match.group(1), flush=True)
    client = wait_job(client, match.group(1), "thin_func_tab", polls=240, allow_exit=True)
    remote_log = f"{ROOT}/logs/gls/{RUN_ID}/func/{CASE}"
    remote_csv = f"{ROOT}/results/{RUN_ID}/csv/{CASE}.csv"
    log = remote_run(client, f"cat {remote_log}/run.log 2>/dev/null")
    failure = next((line for line in log.splitlines() if any(x in line for x in ("TB_X_FAIL", "TB_UNEXPECTED_FAIL", "TB_STALL_FAIL", "TB_HARD_TIMEOUT", "TB_RESULT"))), "NO_RESULT")
    sftp = client.open_sftp()
    artifacts = fetch_artifacts(sftp, remote_log, remote_csv)
    sftp.close()
    (RESULT / "summary.json").write_text(json.dumps({
        "run_id": RUN_ID,
        "mode": "functional_gate_level_no_sdf",
        "netlist_run_id": NETLIST_RUN_ID,
        "case": CASE,
        "local_case_file": str(LOCAL_CASE_FILE) if LOCAL_CASE_FILE else None,
        "l2_x_probe": L2_X_PROBE,
        "thin_stall_probe": THIN_STALL_PROBE,
        "functional_stall_probe": FUNCTIONAL_STALL_PROBE,
        "ipm1_ack_probe": IPM1_ACK_PROBE,
        "failure": failure,
        "tb_pass": "TB_RESULT PASS" in log,
        "artifacts": artifacts,
    }, indent=2) + "\n", encoding="utf-8")
    print("FUNC_GLS_RESULT", failure, flush=True)
    print("LOCAL_RESULT", RESULT, flush=True)
    print(log[-12000:], flush=True)
    client.close()
    raise SystemExit(0 if "TB_RESULT PASS" in log else 1)

if __name__ == "__main__":
    main()
