#!/usr/bin/env python3
import os
import re
import shlex
import stat
import sys
import time
from datetime import datetime
from pathlib import Path

import paramiko

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_flow import atomic_put, job_id, password, remote_run

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_PATH_LATCH_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_path_latch_sdf",
)
LOCAL = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def connect():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
        compress=True,
    )
    transport = client.get_transport()
    if transport is not None:
        transport.set_keepalive(30)
    return client


def wait_job(client, jid, label):
    for poll in range(120):
        out = remote_run(
            client,
            "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); "
            "printf '__STATE__%%s\\n' \"$state\"" % shlex.quote(jid),
        )
        match = re.search(r"__STATE__([A-Z]*)", out)
        if not match:
            raise RuntimeError("cannot parse job state: " + out)
        state = match.group(1)
        if not state or state == "DONE":
            return
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            raise RuntimeError("%s job %s ended in %s" % (label, jid, state))
        print("JOB_WAIT", label, jid, state, poll, flush=True)
        time.sleep(10)
    raise RuntimeError("job timeout: " + label)


def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for entry in sftp.listdir_attr(remote):
        rp = remote + "/" + entry.filename
        lp = local / entry.filename
        if stat.S_ISDIR(entry.st_mode):
            fetch_tree(sftp, rp, lp)
        else:
            sftp.get(rp, str(lp))


def main():
    files = {
        REPO / "src/main/resources/ASYNC/CMR/OPMSelector.v": "rtl/OPMSelector.v",
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_path_latch.tcl": "scripts/dc/run_dc_cmr_path_latch.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_path_latch.sh": "scripts/run_gls_cmr_path_latch.sh",
        REPO / "sim/CMR/testbench/tb_opm_selector_path_latch_smoke.sv": "sim/tb/tb_opm_selector_path_latch_smoke.sv",
    }
    client = connect()
    remote_run(client, "mkdir -p " + " ".join(
        shlex.quote(ROOT + "/" + d) for d in (
            "rtl", "scripts/dc", "scripts", "sim/tb", "sim/work",
            "outputs", "reports/dc", "logs/dc", "logs/gls", "results/" + RUN_ID,
        )
    ))
    sftp = client.open_sftp()
    for source, dest in files.items():
        atomic_put(client, sftp, source, ROOT + "/" + dest)
    sftp.close()
    remote_run(client, "chmod +x %s/scripts/run_gls_cmr_path_latch.sh" % ROOT)

    dc_log = ROOT + "/logs/dc/" + RUN_ID + ".log"
    dc_cmd = (
        "bsub -n 2 -o {log} -e {log}.err -J path_latch_dc_{rid} "
        "'source /etc/profile >/dev/null 2>&1 || true; module load syn >/dev/null 2>&1 || true; "
        "export CMR_REMOTE_ROOT={root} CMR_PATH_LATCH_RUN_ID={rid}; "
        "dc_shell-t -64 -f {root}/scripts/dc/run_dc_cmr_path_latch.tcl'"
    ).format(log=dc_log, rid=RUN_ID, root=ROOT)
    dc_job = job_id(remote_run(client, dc_cmd))
    print("DC_JOB", dc_job, flush=True)
    wait_job(client, dc_job, "dc")
    dc_text = remote_run(client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log))
    if "CMR_PATH_LATCH_DC_PASS" not in dc_text:
        raise RuntimeError("PathLatch DC failed\n" + dc_text[-12000:])

    gls_log = ROOT + "/logs/gls/" + RUN_ID + ".bsub.log"
    gls_cmd = (
        "bsub -n 2 -o {log} -e {log}.err -J path_latch_sdf_{rid} "
        "'export CMR_REMOTE_ROOT={root} CMR_PATH_LATCH_RUN_ID={rid}; "
        "bash {root}/scripts/run_gls_cmr_path_latch.sh'"
    ).format(log=gls_log, rid=RUN_ID, root=ROOT)
    gls_job = job_id(remote_run(client, gls_cmd))
    print("GLS_JOB", gls_job, flush=True)
    wait_job(client, gls_job, "gls")
    gls_text = remote_run(client, "cat %s %s.err 2>/dev/null" % (gls_log, gls_log))
    if "CMR_PATH_LATCH_SDF_PASS" not in gls_text:
        raise RuntimeError("PathLatch SDF failed\n" + gls_text[-12000:])

    sftp = client.open_sftp()
    for remote_dir, local_dir in (
        (ROOT + "/reports/dc/" + RUN_ID, LOCAL / "reports_dc"),
        (ROOT + "/logs/gls/" + RUN_ID, LOCAL / "logs_gls"),
    ):
        fetch_tree(sftp, remote_dir, local_dir)
    for remote_file, local_file in (
        (dc_log, LOCAL / "dc.log"),
        (gls_log, LOCAL / "gls.bsub.log"),
    ):
        local_file.parent.mkdir(parents=True, exist_ok=True)
        sftp.get(remote_file, str(local_file))
    sftp.close()
    client.close()
    print("CMR_PATH_LATCH_REMOTE_PASS", RUN_ID)


if __name__ == "__main__":
    main()
