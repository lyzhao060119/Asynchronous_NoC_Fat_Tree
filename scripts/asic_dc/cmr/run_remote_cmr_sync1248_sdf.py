#!/usr/bin/env python3
"""DC then strict MAXIMUM-SDF open-loop DATE-V3 scan for Sync Q64 Fat 1-2-4-8.

The case fixes exponential packet arrivals in MFlit/port/s.  Every Head..Tail
set is queued at one offer cycle; valid/ready only drains that queue.  There is
no TB Bernoulli generator and no ready-dependent packet creation.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from run_remote_cmr_fat_tree_noc16_sdf import (
    atomic_put_retry, connect, fetch_tree, job_id, remote_run_retry, wait_job,
)
from run_remote_cmr_flow import atomic_put_bytes_retry

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get("CMR_SYNC1248_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_sync_noc64_1248_case")
LOADS = tuple(int(x) for x in os.environ.get("CMR_SYNC1248_LOADS", "5,10,20,40,60,80,100,120,140,160,180,200").split(",") if x)
CLOCK_NS = os.environ.get("CMR_SYNC1248_CLOCK_NS", "1.0")
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
GEN = REPO / "generated_sync_cmr" / "fat_tree_noc64_1248" / "SyncNoC_64nodes.v"
CASE_DIR = Path(os.environ.get(
    "CMR_SYNC1248_CASE_DIR",
    str(REPO / "scripts/asic_dc/cmr/generated_cases/20260913_paper64_asap_m5_200_202701/cases"),
))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked(client, command: str, marker: str) -> tuple[object, str]:
    client, text = remote_run_retry(client, command)
    if marker not in text:
        raise RuntimeError("remote check failed: " + text[-4000:])
    return client, text


def main() -> int:
    if not GEN.is_file():
        raise SystemExit("missing synchronous 1248 emit: " + str(GEN))
    if any(load <= 0 for load in LOADS) or not LOADS:
        raise SystemExit("CMR_SYNC1248_LOADS must be non-empty positive MFlit/port/s values")
    case_files = {}
    for load in LOADS:
        case = CASE_DIR / ("TOPO-UR_n64_s202701_m%d_PFAT64_top8.case" % load)
        if not case.is_file():
            raise SystemExit("missing ASAP async-equivalent case: " + str(case))
        case_files[load] = case
    files = {
        GEN: "rtl/sync_noc64_1248/SyncNoC_64nodes.v",
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/sync_cmr_noc64.sdc": "rtl/sync_cmr_noc64.sdc",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_sync_fat_tree_noc64.tcl": "scripts/dc/run_dc_cmr_sync_fat_tree_noc64.tcl",
        REPO / "sim/AsyncNoC/sync_noc64_port_adapter.sv": "sim/tb/sync_noc64_port_adapter.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_sync_boundary.sv": "sim/tb/tb_noc64_sync_boundary.sv",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_sync1248_case.sh": "scripts/run_gls_cmr_sync1248_case.sh",
    }
    missing = [str(p) for p in files if not p.is_file()]
    if missing:
        raise SystemExit("missing inputs: " + ", ".join(missing))
    client = connect()
    sftp = None
    try:
        client, _ = remote_run_retry(client, "mkdir -p {r}/rtl/sync_noc64_1248 {r}/scripts/dc {r}/sim/tb {r}/cases/sync1248 {r}/outputs {r}/reports/dc {r}/logs/dc {r}/logs/gls {r}/sim/work {r}/results/{run}".format(r=ROOT, run=RUN_ID))
        sftp = client.open_sftp()
        upload_hashes = {}
        for local, rel in files.items():
            print("UPLOAD", rel, flush=True)
            # This helper prefixes ROOT itself; pass a repository-relative path.
            client, sftp, digest = atomic_put_retry(client, sftp, local, rel)
            upload_hashes[rel] = digest
        for load, case in case_files.items():
            remote_case = "cases/sync1248/%s" % case.name
            print("UPLOAD", remote_case, flush=True)
            client, sftp, digest = atomic_put_retry(client, sftp, case, remote_case)
            upload_hashes[remote_case] = digest
        client, _ = remote_run_retry(client, "chmod +x {r}/scripts/run_gls_cmr_sync1248_case.sh".format(r=ROOT))
        dc_log = ROOT + "/logs/dc/" + RUN_ID + ".log"
        dc_wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
        dc_body = """#!/bin/bash
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export CMR_REMOTE_ROOT={root} CMR_SYNC64_RUN_ID={run} CMR_SYNC64_DUT_V={dut} CMR_SYNC64_CLOCK_PERIOD_NS={clock} CMR_EXPECTED_ROUTERS=21 CMR_EXPECTED_PORTS=168 CMR_EXPECTED_TOP=8 CMR_EXPECTED_SELECTORS=352
cd {root}
exec dc_shell-t -64 -f {root}/scripts/dc/run_dc_cmr_sync_fat_tree_noc64.tcl
""".format(root=ROOT, run=RUN_ID, dut=ROOT + "/rtl/sync_noc64_1248/SyncNoC_64nodes.v", clock=CLOCK_NS)
        client, sftp, _ = atomic_put_bytes_retry(client, sftp, dc_body.encode(), dc_wrapper)
        client, dc_submit = remote_run_retry(client, "chmod +x {w}; bsub -n 16 -oo {l} -eo {l}.err -J cmr_sync1248_dc_{run} {w}".format(w=shlex.quote(dc_wrapper), l=shlex.quote(dc_log), run=RUN_ID))
        dc_job = job_id(dc_submit)
        print("DC_JOB", dc_job, flush=True)
        client = wait_job(client, dc_job, "sync1248_dc", allow_exit=True)
        client, dc_report = remote_run_retry(client, "cat {l} {l}.err 2>/dev/null".format(l=shlex.quote(dc_log)))
        if "CMR_SYNC64_DC_PASS" not in dc_report:
            raise RuntimeError("Sync1248 DC failed\n" + dc_report[-8000:])
        client, proof = remote_run_retry(client, "test -s {r}/outputs/{run}/SyncNoC_64nodes_post.v && test -s {r}/outputs/{run}/SyncNoC_64nodes.sdf && test -s {r}/reports/dc/{run}/cmr_sync_noc64_structure.rpt && test -s {r}/reports/dc/{run}/post_hashes.sha256 && echo DC_ARTIFACTS_OK".format(r=ROOT, run=RUN_ID))
        if "DC_ARTIFACTS_OK" not in proof:
            raise RuntimeError("DC marker exists but artifacts incomplete")
        jobs: list[tuple[int, str]] = []
        for load in LOADS:
            wrapper = ROOT + "/logs/gls/{}/sdf/m{}.sh".format(RUN_ID, load)
            remote_case = ROOT + "/cases/sync1248/" + case_files[load].name
            body = """#!/bin/bash
source /etc/profile 2>/dev/null || true
export CMR_REMOTE_ROOT={root} CMR_SYNC1248_RUN_ID={run} CMR_SYNC1248_NETLIST_RUN_ID={run} CMR_SYNC1248_LOAD_MFLIT={load} CMR_SYNC1248_CASE_FILE={case} CMR_SYNC1248_CLOCK_NS={clock} CMR_SYNC1248_CASE_TICK_NS=1.0
exec bash {root}/scripts/run_gls_cmr_sync1248_case.sh
""".format(root=ROOT, run=RUN_ID, load=load, case=shlex.quote(remote_case), clock=CLOCK_NS)
            client, sftp, _ = atomic_put_bytes_retry(client, sftp, body.encode(), wrapper)
            client, response = remote_run_retry(client, "chmod +x {w}; bsub -n 8 -oo {r}/logs/gls/{run}/sdf/m{load}/lsf.log -eo {r}/logs/gls/{run}/sdf/m{load}/lsf.err -J cmr_sync1248_m{load}_{run} {w}".format(w=shlex.quote(wrapper), r=ROOT, run=RUN_ID, load=load))
            jobs.append((load, job_id(response)))
            print("GLS_JOB", load, jobs[-1][1], flush=True)
        outcomes = {}
        for load, jid in jobs:
            client = wait_job(client, jid, "sync1248_m%d" % load, allow_exit=True)
            base = ROOT + "/logs/gls/{}/sdf/m{}".format(RUN_ID, load)
            client, log = remote_run_retry(client, "cat {b}/run.log {b}/sdf_annotate.log {b}/lsf.err 2>/dev/null".format(b=shlex.quote(base)))
            ok = "TB_RESULT PASS" in log and re.search(r"Total errors:\s*0", log) and "Timing violation" not in log
            outcomes[str(load)] = {"job_id": jid, "pass": bool(ok)}
            if not ok:
                raise RuntimeError("GLS M%d failed\n%s" % (load, log[-8000:]))
        RESULT.mkdir(parents=True, exist_ok=True)
        for remote, local in ((ROOT + "/outputs/" + RUN_ID, RESULT / "outputs"), (ROOT + "/reports/dc/" + RUN_ID, RESULT / "reports_dc"), (ROOT + "/logs/gls/" + RUN_ID, RESULT / "gls"), (ROOT + "/logs/dc/" + RUN_ID + ".log", RESULT / "dc.log")):
            try:
                if str(remote).endswith(".log"):
                    sftp.get(remote, str(local))
                else:
                    fetch_tree(sftp, remote, local)
            except OSError:
                pass
        (RESULT / "manifest.json").write_text(json.dumps({"run_id": RUN_ID, "clock_ns": float(CLOCK_NS), "case_tick_ns": 1.0, "injection_model": "v3_exp_header_asap_body_open_loop", "loads_mflit_per_port_s": LOADS, "case_dir": str(CASE_DIR), "dc_job": dc_job, "upload_hashes": upload_hashes, "outcomes": outcomes, "git_sha": subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True).stdout.strip()}, indent=2) + "\n", encoding="utf-8")
        print("CMR_SYNC1248_SDF_PASS", RUN_ID, flush=True)
        return 0
    finally:
        if sftp is not None:
            sftp.close()
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
