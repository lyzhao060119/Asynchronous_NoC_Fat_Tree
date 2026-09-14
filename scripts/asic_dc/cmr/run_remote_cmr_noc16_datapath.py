#!/usr/bin/env python3
"""Step D: incremental datapath-first DC from the frozen CircularFIFO DDC.

Starts from 20260827_cmr_cfifo_noc16_rd01_eco16_p50_01.  Applies data-only
set_max_delay (0.95 x baseline Tdata_max) on Address/Mat, OPM Mux1H and
TCF-RD-01.  Does not shrink DEL or TCF ECO buffers and does not add
control min-delay.  TAB/VCTM p50 strict-SDF must pass before freeze.
"""
from __future__ import annotations

import os
import shlex
import subprocess
import sys
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import (
    ROOT,
    connect,
    fetch_tree,
    job_id,
    wait_job,
)


REPO = Path(__file__).resolve().parents[3]
CMR = REPO / "scripts" / "asic_dc" / "cmr"
BASELINE = os.environ.get(
    "CMR_NOC16_BASELINE", "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01"
)
SEED_DDC_SHA256 = os.environ.get(
    "CMR_DATAPATH_SEED_SHA256",
    "f93611f5e83748663b335cf98f43e504957a93d35932929d769aa74db41b4363",
)
RUN_ID = os.environ.get("CMR_NOC16_RUN_ID", "20260827_cmr_cfifo_datapath_r1")
SKIP_SDF = os.environ.get("CMR_NOC16_SKIP_SDF", "0") == "1"
RESULT = CMR / "results" / RUN_ID
TARGET = CMR / "20260827_cmr_cfifo_datapath_r1_targets.tcl"
OVERLAY = CMR / "async_cmr_noc16_datapath.sdc"


def generate_targets() -> None:
    subprocess.run(
        [
            sys.executable,
            str(CMR / "create_cmr_datapath_targets.py"),
            "--sta-summary",
            str(
                REPO
                / "docs"
                / "timing_baselines"
                / "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta_summary.json"
            ),
            "--out",
            str(TARGET),
            "--scale",
            "0.95",
            "--rd01-tdata",
            "0.295973",
        ],
        cwd=REPO,
        check=True,
    )


def main() -> None:
    generate_targets()
    if not OVERLAY.is_file() or not TARGET.is_file():
        raise SystemExit("missing datapath overlay or targets")

    client = connect()
    seed = "%s/outputs/%s/NoC_16nodes.ddc" % (ROOT, BASELINE)
    probe = remote_run(client, "test -s %s && sha256sum %s" % (shlex.quote(seed), shlex.quote(seed)))
    if SEED_DDC_SHA256 not in probe:
        raise RuntimeError("frozen DDC hash mismatch: " + probe)

    remote_run(
        client,
        "mkdir -p %s/rtl %s/scripts/dc %s/reports/dc/%s %s/logs/dc %s/outputs/%s"
        % (ROOT, ROOT, ROOT, RUN_ID, ROOT, ROOT, RUN_ID),
    )
    files = {
        CMR / "run_dc_cmr_noc16.tcl": "scripts/dc/run_dc_cmr_noc16.tcl",
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        OVERLAY: "rtl/async_cmr_noc16_datapath.sdc",
        TARGET: "rtl/" + TARGET.name,
    }
    sftp = client.open_sftp()
    for source, destination in files.items():
        print("UPLOAD", destination, flush=True)
        atomic_put(client, sftp, source, ROOT + "/" + destination)

    overlay = ROOT + "/rtl/async_cmr_noc16_datapath.sdc"
    target = ROOT + "/rtl/" + TARGET.name
    report_dir = ROOT + "/reports/dc/" + RUN_ID
    wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
    log = ROOT + "/logs/dc/" + RUN_ID + ".log"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
        "CMR_USE_CIRCULAR_FIFO=1 CMR_BYPASS_INTERLEVEL_FIFO=0 "
        "CMR_DATAPATH_SEED_DDC=%s CMR_DATAPATH_OVERLAY=%s "
        "CMR_DATAPATH_TARGET_FILE=%s CMR_DATAPATH_REPORT_DIR=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_noc16.tcl\n"
        % (
            ROOT,
            shlex.quote(RUN_ID),
            shlex.quote(seed),
            shlex.quote(overlay),
            shlex.quote(target),
            shlex.quote(report_dir),
            ROOT,
            ROOT,
        )
    )
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + wrapper)
    submit = remote_run(
        client,
        "bsub -n 8 -o %s -e %s.err -J cmr_noc16_dc_%s %s"
        % (log, log, RUN_ID, wrapper),
    )
    dc_job = job_id(submit)
    print("DC_JOB", dc_job, "seed", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, dc_job, "dc")
    dc_text = remote_run(client, "cat %s %s.err 2>/dev/null" % (log, log))
    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "dc.log").write_text(dc_text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    try:
        fetch_tree(sftp, ROOT + "/reports/dc/" + RUN_ID, RESULT / "reports_dc")
        fetch_tree(sftp, ROOT + "/outputs/" + RUN_ID, RESULT / "outputs")
    except IOError:
        pass
    sftp.close()
    print(dc_text[-12000:], flush=True)
    if "CMR_NOC16_DC_PASS" not in dc_text:
        raise RuntimeError("datapath incremental DC failed")
    if "CMR_DATAPATH_FAIL" in dc_text:
        raise RuntimeError("datapath overlay failed")
    print("CMR_DATAPATH_DC_PASS", RUN_ID, flush=True)
    client.close()

    if SKIP_SDF:
        print("CMR_DATAPATH_DC_ONLY_PASS", RUN_ID, flush=True)
        return

    env = os.environ.copy()
    env["CMR_NOC16_RUN_ID"] = RUN_ID
    env["CMR_NOC16_NETLIST_RUN_ID"] = RUN_ID
    env["CMR_NOC16_RX_CAPTURE_NS"] = "5"
    env["CMR_NOC16_SIM_ARGS"] = "+ACK_TO_NEXT_REQ_GUARD_NS=0.20"
    env["CMR_NOC16_CASES"] = "TAB-NET-UR-3f-r0p50,VCTM-MC5-NM-3f-r0p50"
    env["CMR_NOC16_STRUCTURAL_ENDPOINTS"] = "0"
    subprocess.run(
        [sys.executable, str(CMR / "run_remote_cmr_noc16_async_sdf.py")],
        cwd=CMR,
        env=env,
        check=True,
    )
    print("CMR_DATAPATH_REGRESSION_PASS", RUN_ID, flush=True)


if __name__ == "__main__":
    main()
