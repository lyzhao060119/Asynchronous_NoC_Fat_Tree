#!/usr/bin/env python3
"""Run the read-only port-10 SDF probe against a frozen Thin NoC16 netlist."""
import os
import re
import shlex
import time
from pathlib import Path

from run_remote_cmr_noc16_sdf import connect, fetch_tree
from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
NETLIST_RUN = os.environ.get(
    "CMR_NOC16_NETLIST_RUN_ID", "20260823_cmr_thin_phentoggle_prefix_t105_sdf_03"
)
RUN_ID = os.environ.get("CMR_NOC16_RUN_ID", "20260823_cmr_thin_port10_x_diag_01")
CASE = os.environ.get("CMR_NOC16_CASE_NAME", "TAB-NET-UR-3f-r0p50_prefix_t105")
CASE_FILE = os.environ.get(
    "CMR_NOC16_CASE_FILE", ROOT + "/sim/cases/" + CASE + ".case"
)
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def wait_job(client, job):
    for poll in range(120):
        status = remote_run(client, "bjobs -noheader -o stat %s 2>/dev/null" % job).strip()
        # Login wrappers append benign module-loader diagnostics after the
        # LSF state; accept a leading DONE instead of waiting forever.
        if not status or status.startswith("DONE"):
            return
        if status in ("EXIT", "ZOMBI", "UNKWN"):
            return
        print("JOB_WAIT", job, status, poll, flush=True)
        time.sleep(15)
    raise TimeoutError("port10 probe job did not finish")


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
            (REPO / "scripts/asic_dc/cmr/tb_cmr_thin_port10_x_probe.sv", ROOT + "/sim/tb/tb_cmr_thin_port10_x_probe.sv"),
        ):
            print("UPLOAD", local.name, atomic_put(client, sftp, local, remote), flush=True)
        wrapper = ROOT + "/logs/gls/" + RUN_ID + "/run.sh"
        body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n" \
               "export CMR_REMOTE_ROOT={root} CMR_NOC16_RUN_ID={run} " \
               "CMR_NOC16_NETLIST_RUN_ID={net} CMR_NOC16_CASE_NAME={case} " \
               "CMR_NOC16_CASE_FILE={casefile} CMR_NOC16_PORT10_X_PROBE=1 " \
               "CMR_NOC16_RX_CAPTURE_NS=5 CMR_NOC16_STALL_TIMEOUT_NS=50000 " \
               "CMR_NOC16_HARD_TIMEOUT_NS=400000\nexec bash {root}/scripts/run_gls_cmr_noc16.sh\n".format(
                   root=ROOT, run=RUN_ID, net=NETLIST_RUN, case=CASE, casefile=CASE_FILE)
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        sftp.close()
        remote_run(client, "chmod +x %s %s" % (shlex.quote(wrapper), shlex.quote(ROOT + "/scripts/run_gls_cmr_noc16.sh")))
        submitted = remote_run(client, "bsub -n 8 -o %s/logs/gls/%s/bsub.log -e %s/logs/gls/%s/bsub.err -J cmr_p10_%s %s" % (
            ROOT, RUN_ID, ROOT, RUN_ID, RUN_ID, wrapper))
        found = re.search(r"Job <(\d+)>", submitted)
        if not found:
            raise RuntimeError("LSF submission failed: " + submitted)
        job = found.group(1)
        print("SDF_JOB", job, flush=True)
        wait_job(client, job)
        log = ROOT + "/logs/gls/" + RUN_ID + "/sdf/" + CASE + "/run.log"
        run_log = remote_run(client, "cat %s 2>/dev/null" % shlex.quote(log))
        markers = ("P10_PROBE", "P10_EVT", "TB_PROTOCOL_X", "TB_X_FAIL", "Timing violation", "TB_RESULT")
        print("\n".join(line for line in run_log.splitlines() if any(marker in line for marker in markers)), flush=True)
        RESULT.mkdir(parents=True, exist_ok=True)
        sftp = client.open_sftp()
        fetch_tree(sftp, ROOT + "/logs/gls/" + RUN_ID, RESULT / "logs_gls")
        sftp.close()
    finally:
        client.close()


if __name__ == "__main__":
    main()
