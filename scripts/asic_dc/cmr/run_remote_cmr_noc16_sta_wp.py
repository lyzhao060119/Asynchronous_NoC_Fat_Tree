#!/usr/bin/env python3
"""Remote pin-level STA of CMR-WP-01 / HS-02 on a frozen NoC16 DDC."""
import os
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import connect, fetch_tree, job_id, wait_job


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_WP_RTM_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_thin_wp_sta",
)
BASELINE = os.environ.get("CMR_NOC16_BASELINE", "20260822_cmr_thin_rcu_matched4_dc_01")
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def main():
    client = connect()
    probe = remote_run(
        client,
        "test -s %s/outputs/%s/NoC_16nodes.ddc && echo OK" % (ROOT, BASELINE),
    )
    if "OK" not in probe:
        raise RuntimeError("missing frozen DDC " + BASELINE)

    remote_run(client, "mkdir -p %s/scripts/sta %s/reports/sta/%s %s/logs/sta" % (
        ROOT, ROOT, RUN_ID, ROOT
    ))
    sftp = client.open_sftp()
    atomic_put(
        client, sftp,
        REPO / "scripts/asic_dc/cmr/run_sta_cmr_wp_rtm.tcl",
        ROOT + "/scripts/sta/run_sta_cmr_wp_rtm.tcl",
    )
    wrapper = ROOT + "/logs/sta/" + RUN_ID + ".sh"
    log = ROOT + "/logs/sta/" + RUN_ID + ".log"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_BASELINE=%s CMR_WP_RTM_RUN_ID=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/sta/run_sta_cmr_wp_rtm.tcl\n"
        % (ROOT, shlex.quote(BASELINE), shlex.quote(RUN_ID), ROOT, ROOT)
    )
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + wrapper)
    submit = remote_run(
        client,
        "bsub -n 4 -o %s -e %s.err -J cmr_wp_sta_%s %s" % (log, log, RUN_ID, wrapper),
    )
    jid = job_id(submit)
    print("STA_JOB", jid, "baseline", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, jid, "wp_sta")
    text = remote_run(client, "cat %s %s.err 2>/dev/null" % (log, log))
    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "sta.log").write_text(text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    fetch_tree(sftp, ROOT + "/reports/sta/" + RUN_ID, RESULT / "sta")
    sftp.close()
    print(text[-8000:], flush=True)
    if "CMR_WP_RTM_STA_DONE" not in text:
        raise RuntimeError("WP STA failed")
    print("CMR_WP_STA_PASS", RUN_ID, flush=True)


if __name__ == "__main__":
    main()
