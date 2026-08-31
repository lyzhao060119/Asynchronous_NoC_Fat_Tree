#!/usr/bin/env python3
"""Read-only ACG last-stage dequeue X probe on the frozen Thin ACG netlist."""
import json
import os
import re
import shlex
import time
from pathlib import Path

from run_remote_cmr_noc16_sdf import connect, fetch_tree, wait_job
from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
NETLIST_RUN = os.environ.get(
    "CMR_NOC16_NETLIST_RUN_ID", "20260824_cmr_thin_acg_fifo3_dc_01"
)
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID", "20260825_cmr_thin_acg_fifo3_deq_x_diag_01"
)
CASE = os.environ.get("CMR_NOC16_CASE_NAME", "VCTM-MC5-NM-3f-r0p50")
CASE_FILE = os.environ.get(
    "CMR_NOC16_CASE_FILE", ULTRA + "/sim/cases/" + CASE + ".case"
)
DEBUG_LOG = REPO / "debug-949621.log"
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
if "nofifo" in NETLIST_RUN.lower():
    raise SystemExit("ACG dequeue probe needs the ACG FIFO netlist, got " + NETLIST_RUN)


def emit_debug(hypothesis_id, message, data):
    # #region agent log
    rec = {
        "sessionId": "949621",
        "runId": os.environ.get("CMR_DEBUG_RUN_ID", "acg-deq-x-pre"),
        "hypothesisId": hypothesis_id,
        "location": "run_remote_cmr_thin_acg_deq_x_diag.py",
        "message": message,
        "data": data,
        "timestamp": int(time.time() * 1000),
    }
    with DEBUG_LOG.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(rec, ensure_ascii=True) + "\n")
    # #endregion


def harvest(run_log):
    lines = [line for line in run_log.splitlines() if line.startswith("ACGX ")]
    races = [line for line in lines if "event=req_before_data" in line]
    first_race = [line for line in lines if "event=first_req_before_data" in line]
    d_known = [line for line in lines if "event=d_known_at_fire" in line or "event=arm_snap" in line]
    d_unknown = [line for line in lines if "event=d_unknown_at_fire" in line]
    pins = [line for line in lines if "event=pin " in line]
    hp = [line for line in lines if "event=hp_q_x" in line or "event=hp_pin" in line]
    port13 = [line for line in lines if "event=port13_x" in line]
    l101 = [line for line in lines if "event=l101_opm0_req_x" in line]
    emit_debug("A", "req_before_data events", {
        "lines": races[:12],
        "count": len(races),
        "pins": pins[:40],
    })
    emit_debug("B", "first fifo with req_before_data", {"lines": first_race[:4]})
    emit_debug("D", "D26 at last-stage fire", {
        "known": d_known[:12],
        "unknown": d_unknown[:12],
    })
    emit_debug("C", "HeadPredictor Q X", {"lines": hp[:40]})
    emit_debug("E", "port13 / L101 OPM0 X vs fifo race", {
        "port13": port13[:4],
        "l101": l101[:4],
        "race_count": len(races),
    })
    return lines


def main():
    client = connect()
    try:
        netlist = ROOT + "/outputs/" + NETLIST_RUN + "/NoC_16nodes_post.v"
        sdf = ROOT + "/outputs/" + NETLIST_RUN + "/NoC_16nodes.sdf"
        check = remote_run(client, "test -s %s && test -s %s && test -s %s && sha256sum %s %s" % (
            shlex.quote(netlist), shlex.quote(sdf), shlex.quote(CASE_FILE),
            shlex.quote(netlist), shlex.quote(sdf)))
        if len(re.findall(r"\b[0-9a-f]{64}\b", check)) != 2:
            raise RuntimeError("frozen netlist/SDF or case missing: " + check)
        print("FROZEN_INPUTS", check, flush=True)

        remote_run(client, "mkdir -p %s/sim/tb %s/scripts %s/logs/gls/%s" % (
            ROOT, ROOT, ROOT, RUN_ID))
        sftp = client.open_sftp()
        for local, remote in (
            (REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh", ROOT + "/scripts/run_gls_cmr_noc16.sh"),
            (REPO / "scripts/asic_dc/cmr/tb_cmr_thin_acg_deq_x_probe.sv",
             ROOT + "/sim/tb/tb_cmr_thin_acg_deq_x_probe.sv"),
            (REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv",
             ROOT + "/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv"),
        ):
            print("UPLOAD", local.name, atomic_put(client, sftp, local, remote), flush=True)
        wrapper = ROOT + "/logs/gls/" + RUN_ID + "/run.sh"
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT={root} CMR_NOC16_RUN_ID={run} "
            "CMR_NOC16_NETLIST_RUN_ID={net} CMR_NOC16_CASE_NAME={case} "
            "CMR_NOC16_CASE_FILE={casefile} CMR_NOC16_ACG_X_PROBE=1 "
            "CMR_NOC16_RX_CAPTURE_NS=5 CMR_NOC16_STALL_TIMEOUT_NS=50000 "
            "CMR_NOC16_HARD_TIMEOUT_NS=400000 "
            "CMR_NOC16_SIM_ARGS=+ACK_TO_NEXT_REQ_GUARD_NS=0.20\n"
            "exec bash {root}/scripts/run_gls_cmr_noc16.sh\n"
        ).format(root=ROOT, run=RUN_ID, net=NETLIST_RUN, case=CASE, casefile=CASE_FILE)
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        sftp.close()
        remote_run(client, "chmod +x %s %s" % (
            shlex.quote(wrapper), shlex.quote(ROOT + "/scripts/run_gls_cmr_noc16.sh")))
        submitted = remote_run(client, "bsub -n 8 -o %s/logs/gls/%s/bsub.log -e %s/logs/gls/%s/bsub.err -J cmr_acgx_%s %s" % (
            ROOT, RUN_ID, ROOT, RUN_ID, RUN_ID, wrapper))
        found = re.search(r"Job <(\d+)>", submitted)
        if not found:
            raise RuntimeError("LSF submission failed: " + submitted)
        job = found.group(1)
        print("SDF_JOB", job, flush=True)
        wait_job(client, job, "acg_deq_x", allow_exit=True)
        log = ROOT + "/logs/gls/" + RUN_ID + "/sdf/" + CASE + "/run.log"
        run_log = remote_run(client, "cat %s 2>/dev/null" % shlex.quote(log))
        markers = ("ACGX ", "TB_PROTOCOL_X", "TB_X_FAIL", "Timing violation", "TB_RESULT")
        print("\n".join(line for line in run_log.splitlines()
                        if any(marker in line for marker in markers)), flush=True)
        harvest(run_log)
        RESULT.mkdir(parents=True, exist_ok=True)
        sftp = client.open_sftp()
        fetch_tree(sftp, ROOT + "/logs/gls/" + RUN_ID, RESULT / "logs_gls")
        sftp.close()
    finally:
        client.close()


if __name__ == "__main__":
    main()
