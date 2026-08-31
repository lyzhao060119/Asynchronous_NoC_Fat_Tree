#!/usr/bin/env python3
"""Remote CMR-RCU-01 paired STA on a frozen standalone CMRRouter DDC.

Does not resize DelayElement cells and does not write production SDC.
The leftover verdict keeps the last 1xDEL050 instance; shortfall is filled
with BUFFD0 stages on MatchedDelay Z.
"""
import json
import math
import os
import shlex
import sys
from datetime import datetime
from pathlib import Path

from extract_cmr_paired_sta import rtm_required_and_shortfall
from extract_cmr_paired_sta import main as extract_main
from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import connect, fetch_tree, job_id, wait_job


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
BASELINE = os.environ.get(
    "CMR_ROUTER_STA_BASELINE", "20260827_cmr_router_l1_fast_unicast3"
)
RUN_ID = os.environ.get(
    "CMR_PAIRED_STA_RUN_ID",
    datetime.now().strftime("%Y%m%d") + "_cmr_router_l1_fast_rcu01_sta",
)
EXPECTED_RCUS = os.environ.get("CMR_STA_EXPECTED_RCUS", "5")
RTM_TARGET = float(os.environ.get("CMR_STA_RTM_TARGET", "0.05"))
BUFFD0_NS = float(os.environ.get("CMR_STA_BUFFD0_NS", "0.015"))
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
CMR = REPO / "scripts" / "asic_dc" / "cmr"


def main():
    client = connect()
    probe = remote_run(
        client,
        "test -s %s/outputs/%s/CMRRouter.ddc && echo OK" % (ROOT, BASELINE),
    )
    if "OK" not in probe:
        raise RuntimeError("missing Router DDC " + BASELINE)

    remote_run(
        client,
        "mkdir -p %s/scripts/sta %s/reports/sta/%s %s/logs/sta"
        % (ROOT, ROOT, RUN_ID, ROOT),
    )
    sftp = client.open_sftp()
    for name in ("sta_cmr_paired_lib.tcl", "run_sta_cmr_router_rcu01.tcl"):
        atomic_put(client, sftp, CMR / name, ROOT + "/scripts/sta/" + name)
    wrapper = ROOT + "/logs/sta/" + RUN_ID + ".sh"
    log = ROOT + "/logs/sta/" + RUN_ID + ".log"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_ROUTER_STA_BASELINE=%s "
        "CMR_PAIRED_STA_RUN_ID=%s CMR_STA_EXPECTED_RCUS=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/sta/run_sta_cmr_router_rcu01.tcl\n"
        % (
            ROOT,
            shlex.quote(BASELINE),
            shlex.quote(RUN_ID),
            shlex.quote(EXPECTED_RCUS),
            ROOT,
            ROOT,
        )
    )
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + wrapper)
    submit = remote_run(
        client,
        "bsub -n 4 -o %s -e %s.err -J cmr_router_rcu01_%s %s"
        % (log, log, RUN_ID, wrapper),
    )
    jid = job_id(submit)
    print("STA_JOB", jid, "baseline", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, jid, "router_rcu01_sta")
    text = remote_run(
        client,
        "grep -E 'CMR_PAIRED|Error:|Error-|PAIRED_FAIL' %s %s.err 2>/dev/null; "
        "echo '---TAIL---'; tail -n 40 %s %s.err 2>/dev/null"
        % (log, log, log, log),
    )
    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "sta.log").write_text(text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    fetch_tree(sftp, ROOT + "/reports/sta/" + RUN_ID, RESULT / "sta")
    sftp.close()
    print(text[-16000:], flush=True)
    if "CMR_PAIRED_STA_DONE" not in text:
        raise RuntimeError("Router RCU-01 STA failed")

    csv_dir = RESULT / "sta"
    sys.argv = [
        "extract_cmr_paired_sta.py",
        str(csv_dir),
        "--log",
        str(RESULT / "sta.log"),
        "--baseline",
        BASELINE,
        "--run-id",
        RUN_ID,
        "--rtm-target",
        str(RTM_TARGET),
        "--output",
        str(RESULT / "paired_sta_summary.json"),
        "--archive-csv",
        str(RESULT / "paired_catalog.csv"),
    ]
    extract_main()
    summary = json.loads((RESULT / "paired_sta_summary.json").read_text(encoding="utf-8"))
    rcu = summary["ids"].get("CMR-RCU-01", {})
    tdata = rcu.get("tdata_max_ns")
    tctrl = rcu.get("tctrl_min_ns")
    required, shortfall = rtm_required_and_shortfall(tdata, tctrl, RTM_TARGET)
    leftover = None
    if tdata is not None and tctrl is not None and required is not None:
        leftover = tctrl - required
    closed = shortfall == 0.0 if shortfall is not None else False
    suggested = 0
    if shortfall is not None and shortfall > 0.0:
        suggested = max(1, int(math.ceil(shortfall / BUFFD0_NS)))
    verdict = {
        "baseline": BASELINE,
        "run_id": RUN_ID,
        "rtm_target": RTM_TARGET,
        "tdata_max_ns": tdata,
        "tctrl_min_ns": tctrl,
        "required_tctrl_ns": required,
        "shortfall_at_rtm_ns": shortfall,
        "leftover_ns": leftover,
        "buffd0_ns": BUFFD0_NS,
        "closed_at_rtm": closed,
        "keep_del050": True,
        "keep_instance": True,
        "suggested_buf_stages": suggested,
        "eligible_drop_last_del150": False,
        "eligible_size_to_del050": False,
        "note": (
            "Last remaining RCU matched delay stays 1xDEL050 "
            "(DelayValue>=1).  closed_at_rtm is the stop.  If shortfall>0, "
            "insert suggested_buf_stages of BUFFD0 on MatchedDelay Z "
            "(15 ps/stage).  Do not drop the cell."
        ),
    }
    (RESULT / "rcu01_shrink_verdict.json").write_text(
        json.dumps(verdict, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(verdict, indent=2), flush=True)
    print("CMR_ROUTER_RCU01_STA_PASS", RUN_ID, flush=True)
    print("LOCAL_RESULT", RESULT, flush=True)


if __name__ == "__main__":
    main()
