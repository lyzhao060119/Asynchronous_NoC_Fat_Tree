#!/usr/bin/env python3
"""One-FIFO ACK/HS-02 path probe on the F-closed buf16 DDC."""
import os
import shlex
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import ROOT, connect, job_id, wait_job

REPO = Path(__file__).resolve().parents[3]
CMR = REPO / "scripts" / "asic_dc" / "cmr"
BASELINE = "20260827_cmr_cfifo_outer_rtm5_rcu_del050_buf16"
RUN_ID = "20260827_cmr_cfifo_link_ack_probe4"


def main() -> None:
    client = connect()
    remote_run(
        client,
        "mkdir -p %s/scripts/sta %s/reports/sta/%s %s/logs/sta"
        % (ROOT, ROOT, RUN_ID, ROOT),
    )
    for name in ("sta_cmr_paired_lib.tcl", "probe_cmr_link_ack_sta.tcl"):
        atomic_put(client, None, CMR / name, ROOT + "/scripts/sta/" + name)
    wrapper = ROOT + "/logs/sta/" + RUN_ID + ".sh"
    log = ROOT + "/logs/sta/" + RUN_ID + ".log"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_BASELINE=%s CMR_PAIRED_STA_RUN_ID=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/sta/probe_cmr_link_ack_sta.tcl\n"
        % (ROOT, shlex.quote(BASELINE), shlex.quote(RUN_ID), ROOT, ROOT)
    )
    atomic_put_bytes(client, None, body.encode(), wrapper)
    remote_run(client, "chmod +x " + wrapper)
    remote_run(client, "rm -f %s %s.err" % (shlex.quote(log), shlex.quote(log)))
    submit = remote_run(
        client,
        "bsub -n 2 -o %s -e %s.err -J cmr_link_ack_probe %s" % (log, log, wrapper),
    )
    jid = job_id(submit)
    print("PROBE_JOB", jid, "baseline", BASELINE, flush=True)
    wait_job(client, jid, "ack_probe")
    text = remote_run(
        client,
        "grep -E 'CMR_LINK_PROBE|Error:|Error-' %s %s.err 2>/dev/null; "
        "echo '---TAIL---'; tail -n 30 %s %s.err 2>/dev/null"
        % (log, log, log, log),
    )
    out = CMR / "results" / RUN_ID
    out.mkdir(parents=True, exist_ok=True)
    (out / "probe.log").write_text(text, encoding="utf-8", errors="replace")
    print(text, flush=True)
    if "CMR_LINK_PROBE_DONE" not in text:
        raise SystemExit("ack probe failed")


if __name__ == "__main__":
    main()
