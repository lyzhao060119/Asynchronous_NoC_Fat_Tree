#!/usr/bin/env python3
"""Synthesize one Transition CircularFIFO and run its strict-SDF smoke."""
import json
import os
import re
import shlex
import stat
import time
from datetime import datetime
from pathlib import Path

import paramiko

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, password, remote_run

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get("CMR_CFIFO_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_cfifo_unit")
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
CMR = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"
ASYNC = REPO / "src" / "main" / "resources" / "ASYNC"


def connect():
    last_error = None
    for attempt in range(3):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(os.environ.get("C1_HOST", "192.168.2.8"), username=os.environ.get("C1_USER", "ghy19"),
                           password=password(), timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False,
                           compress=True)
            return client
        except OSError as error:
            client.close()
            last_error = error
            if attempt != 2:
                print("SSH_RETRY", attempt + 1, type(error).__name__, flush=True)
                time.sleep(10)
    raise RuntimeError("C1 SSH unavailable after 3 attempts: %s" % last_error)


def job_id(text):
    match = re.search(r"Job <(\d+)>", text)
    if not match:
        raise RuntimeError("LSF submission failed: " + text)
    return match.group(1)


def wait_job(client, jid, label):
    for poll in range(360):
        text = remote_run(client, "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); printf '__STATE__%%s\\n' \"$state\"" % shlex.quote(jid))
        match = re.search(r"__STATE__([A-Z]*)", text)
        state = match.group(1) if match else ""
        if not state or state == "DONE":
            print("JOB_DONE", label, jid, state or "PURGED", flush=True)
            return
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            raise RuntimeError("job %s ended %s" % (label, state))
        print("JOB_WAIT", label, jid, state, "poll", poll, flush=True)
        time.sleep(30)
    raise TimeoutError(label)


def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for entry in sftp.listdir_attr(remote):
        rp, lp = remote + "/" + entry.filename, local / entry.filename
        if stat.S_ISDIR(entry.st_mode):
            fetch_tree(sftp, rp, lp)
        else:
            sftp.get(rp, str(lp))


def main():
    files = {
        ASYNC / "DLatchBank.v": "rtl/DLatchBank.v",
        CMR / "PhaseResetDLatch.v": "rtl/PhaseResetDLatch.v",
        CMR / "CircularWriteCounter.v": "rtl/CircularWriteCounter.v",
        CMR / "CircularReadCounter.v": "rtl/CircularReadCounter.v",
        CMR / "WriteControlBlock.v": "rtl/WriteControlBlock.v",
        CMR / "ReadControlBlock.v": "rtl/ReadControlBlock.v",
        CMR / "CircularFIFO.v": "rtl/CircularFIFO.v",
        REPO / "scripts/asic_dc/cmr/CircularFifoUnit.v": "rtl/CircularFifoUnit.v",
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/async_circular_fifo_rtc.sdc": "scripts/dc/async_circular_fifo_rtc.sdc",
        REPO / "scripts/asic_dc/cmr/run_dc_circular_fifo_unit.tcl": "scripts/dc/run_dc_circular_fifo_unit.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_circular_fifo_unit.sh": "scripts/run_gls_circular_fifo_unit.sh",
        REPO / "scripts/asic_dc/cmr/tb_circular_fifo_gls.sv": "sim/tb/tb_circular_fifo_gls.sv",
    }
    missing = [str(p) for p in files if not p.is_file()]
    if missing:
        raise SystemExit("missing inputs: " + ", ".join(missing))
    client = connect()
    remote_run(client, "mkdir -p " + " ".join(ROOT + "/" + d for d in (
        "rtl scripts/dc scripts sim/tb sim/work work outputs reports/dc logs/dc logs/gls results".split())))
    sftp = client.open_sftp()
    hashes = {dest: atomic_put(client, sftp, src, ROOT + "/" + dest) for src, dest in files.items()}
    sftp.close()
    remote_run(client, "chmod +x %s/scripts/run_gls_circular_fifo_unit.sh" % ROOT)

    dc_wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
    dc_body = ("#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\n"
               "export CMR_REMOTE_ROOT=%s CMR_CFIFO_RUN_ID=%s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_circular_fifo_unit.tcl\n"
               % (ROOT, shlex.quote(RUN_ID), ROOT))
    sftp = client.open_sftp(); atomic_put_bytes(client, sftp, dc_body.encode(), dc_wrapper); sftp.close()
    remote_run(client, "chmod +x %s" % dc_wrapper)
    dc_log = ROOT + "/logs/dc/" + RUN_ID + ".log"
    dc_jid = job_id(remote_run(client, "bsub -n 8 -o %s -e %s.err -J cfifo_dc_%s %s" % (dc_log, dc_log, RUN_ID, dc_wrapper)))
    print("DC_JOB", dc_jid, flush=True); wait_job(client, dc_jid, "dc")
    dc_text = remote_run(client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log))
    if "TCF_DC_PASS" not in dc_text:
        print(dc_text[-16000:], flush=True)
        raise RuntimeError("Circular FIFO DC failed")

    gls_wrapper = ROOT + "/logs/gls/" + RUN_ID + "/circular_fifo_unit.sh"
    gls_body = ("#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                "export CMR_REMOTE_ROOT=%s CMR_CFIFO_RUN_ID=%s\nexec bash %s/scripts/run_gls_circular_fifo_unit.sh\n"
                % (ROOT, shlex.quote(RUN_ID), ROOT))
    remote_run(client, "mkdir -p %s/logs/gls/%s" % (ROOT, RUN_ID))
    sftp = client.open_sftp(); atomic_put_bytes(client, sftp, gls_body.encode(), gls_wrapper); sftp.close()
    remote_run(client, "chmod +x %s" % gls_wrapper)
    gls_jid = job_id(remote_run(client, "bsub -n 8 -o %s/logs/gls/%s/circular_fifo_unit.bsub.log -e %s/logs/gls/%s/circular_fifo_unit.bsub.err -J cfifo_gls_%s %s" % (ROOT, RUN_ID, ROOT, RUN_ID, RUN_ID, gls_wrapper)))
    print("GLS_JOB", gls_jid, flush=True); wait_job(client, gls_jid, "gls")
    base = ROOT + "/logs/gls/%s/circular_fifo_unit" % RUN_ID
    run_log = remote_run(client, "cat %s/run.log 2>/dev/null" % base)
    annotate = remote_run(client, "cat %s/sdf_annotate.log 2>/dev/null" % base)
    err = re.search(r"Total errors:\s*(\d+)", annotate)
    timing = run_log.count("Timing violation")
    bad = ("TCF_GLS_FAIL", "TCF_FAIL", "X/Z")
    passed = "TCF_GLS_PASS" in run_log and err and int(err.group(1)) == 0 and timing == 0 and not any(x in run_log for x in bad)
    status = {"run_id": RUN_ID, "dc_job": dc_jid, "gls_job": gls_jid, "annotation_errors": int(err.group(1)) if err else None,
              "timing_violation_count": timing, "tb_pass": bool(passed), "result_line": next((x for x in run_log.splitlines() if x.startswith("TCF_GLS_PASS") or x.startswith("TCF_GLS_FAIL")), None), "upload_hashes": hashes}
    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    sftp = client.open_sftp()
    for remote, local in ((ROOT + "/outputs/" + RUN_ID, RESULT / "outputs"), (ROOT + "/reports/dc/" + RUN_ID, RESULT / "reports_dc"), (ROOT + "/logs/dc", RESULT / "logs_dc"), (ROOT + "/logs/gls/" + RUN_ID, RESULT / "logs_gls")):
        fetch_tree(sftp, remote, local)
    sftp.close(); client.close()
    print("LOCAL_RESULT", RESULT, flush=True)
    if not passed:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
