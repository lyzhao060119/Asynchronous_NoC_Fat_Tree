#!/usr/bin/env python3
"""Remote step-C paired STA on the frozen thin NoC16 DDC.

Measures CMR-RCU-01 (all 25 RCUs, per-bit A1 vs Z) and CMR-OPM-01
(all 25 OPMs, Head/Body/Tail vs E fall).  Dummy STA windows stay in the
STA Tcl; this flow does not write production SDC or change DEL cells.
"""
import os
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import connect, fetch_tree, job_id, wait_job


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_PAIRED_STA_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_thin_paired_sta",
)
BASELINE = os.environ.get(
    "CMR_NOC16_BASELINE", "20260828_cmr_cfifo_tp_nogrant_p50"
)
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
CMR = REPO / "scripts" / "asic_dc" / "cmr"
STA_FILES = (
    "sta_cmr_paired_lib.tcl",
    "run_sta_cmr_paired_catalog.tcl",
    "run_sta_cmr_rcu_rtm.tcl",
    "run_sta_cmr_opm_rtm.tcl",
    "run_sta_cmr_mat_routesel.tcl",
)


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
    for name in STA_FILES:
        atomic_put(
            client, sftp,
            CMR / name,
            ROOT + "/scripts/sta/" + name,
        )
    wrapper = ROOT + "/logs/sta/" + RUN_ID + ".sh"
    log = ROOT + "/logs/sta/" + RUN_ID + ".log"
    measure_links = os.environ.get("CMR_STA_MEASURE_LINKS", "0")
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_BASELINE=%s "
        "CMR_PAIRED_STA_RUN_ID=%s CMR_STA_MEASURE_LINKS=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/sta/run_sta_cmr_paired_catalog.tcl\n"
        % (
            ROOT,
            shlex.quote(BASELINE),
            shlex.quote(RUN_ID),
            shlex.quote(measure_links),
            ROOT,
            ROOT,
        )
    )
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + wrapper)
    submit = remote_run(
        client,
        "bsub -n 4 -o %s -e %s.err -J cmr_paired_sta_%s %s"
        % (log, log, RUN_ID, wrapper),
    )
    jid = job_id(submit)
    print("STA_JOB", jid, "baseline", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, jid, "paired_sta")
    # The DC log is tens of MB of OPT-314 loop-break noise.  Keep markers
    # and a tail; the CSV lives under reports/sta/.
    text = remote_run(
        client,
        "grep -E 'CMR_PAIRED|CMR_RCU|CMR_OPM|CMR_LINK|TCF_|Error:|Error-|PAIRED_FAIL|RESET_PATH' %s "
        "%s.err 2>/dev/null; echo '---TAIL---'; tail -n 40 %s %s.err 2>/dev/null"
        % (log, log, log, log),
    )
    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "sta.log").write_text(text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    fetch_tree(sftp, ROOT + "/reports/sta/" + RUN_ID, RESULT / "sta")
    sftp.close()
    print(text[-16000:], flush=True)
    if "CMR_PAIRED_STA_DONE" not in text:
        raise RuntimeError("paired STA failed")
    print("CMR_PAIRED_STA_PASS", RUN_ID, flush=True)


if __name__ == "__main__":
    main()
