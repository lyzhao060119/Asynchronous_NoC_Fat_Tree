#!/usr/bin/env python3
"""Remote VCS RTL key-case for 256-core PROP clustered / FM mesh.

Behavioral DelayElement_sim, not SDF and not a 256-node DC.  Uploads emitted
Verilog plus tb_noc256_async_keycase.sv.  CMR_NOC256_KIND=prop|fm.
DATE V3 cases: CMR_NOC256_ALLOW_V3=1 and CMR_NOC256_V3_CASE_DIR (or the
shared CMR_NOC64_V3_CASE_DIR).
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
from datetime import datetime
from pathlib import Path

from cmr_descal_env import apply_bsub, is_descal, submit_only
from cmr_frozen_run_ids import refuse_overwrite
from run_remote_cmr_flow import atomic_put_bytes
from run_remote_cmr_fat_tree_noc16_sdf import (
    atomic_put_retry,
    connect,
    fetch_tree,
    job_id,
    reconnect,
    remote_run_retry,
    wait_job,
)


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
KIND = os.environ.get("CMR_NOC256_KIND", "prop").strip().lower()
if KIND in ("fm", "fm256"):
    KIND = "fm"
else:
    KIND = "prop"
BASE_RUN_ID = os.environ.get(
    "CMR_NOC256_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_descal_noc256_" + KIND,
)
CASES = tuple(
    name for name in os.environ.get("CMR_NOC256_CASES", "").split(",") if name
)
ALLOW_V3 = os.environ.get("CMR_NOC256_ALLOW_V3", "0") == "1" or os.environ.get("CMR_NOC64_ALLOW_V3", "0") == "1"
V3_CASE_DIR = Path(os.environ["CMR_NOC256_V3_CASE_DIR"]) if os.environ.get("CMR_NOC256_V3_CASE_DIR") else (
    Path(os.environ["CMR_NOC64_V3_CASE_DIR"]) if os.environ.get("CMR_NOC64_V3_CASE_DIR") else None
)
DESCAL = os.environ.get("CMR_DESCAL", "0") == "1"
SIM_ARGS = os.environ.get("CMR_NOC256_SIM_ARGS", "")
RX_CAPTURE_NS = os.environ.get("CMR_NOC256_RX_CAPTURE_NS", "0.05")
GLS_POLLS = int(os.environ.get("CMR_NOC256_GLS_POLLS", "720"))
GLS_BSUB = apply_bsub(os.environ.get("CMR_NOC256_GLS_BSUB", "-n 8"))
SUBMIT_ONLY = submit_only()
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"
GEN_DIR = (
    REPO / "generated_cmr" / "mesh_noc256_11"
    if KIND == "fm"
    else REPO / "generated_cmr" / "clustered_noc_g2_m2"
)
DUT_NAME = "CMRMeshNoC.v" if KIND == "fm" else "NoC_256nodes.v"


def _gls_job_name(name: str) -> str:
    if DESCAL or is_descal():
        return "cmr_descal_noc256_%s_%s" % (KIND, name)
    return "cmr_noc256_%s_%s" % (KIND, name)


def case_local_path(name: str) -> Path:
    if ALLOW_V3 and V3_CASE_DIR is not None:
        candidate = V3_CASE_DIR / (name + ".case")
        if candidate.is_file():
            return candidate
    raise SystemExit("unknown noc256 case " + name)


def generate_rtl() -> Path:
    rtl = GEN_DIR / DUT_NAME
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1"
    if rtl.is_file() and not force_emit:
        print("LOCAL_EMIT reuse", rtl, flush=True)
        return GEN_DIR
    env = os.environ.copy()
    env["ASYNC_PRIMITIVES"] = "sim"
    env["CMR_FORCE_EMIT"] = "1"
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    if KIND == "fm":
        cmd = [sbt, "runMain NoC.CMR.CMRMeshNoCMain 16 1 1"]
    else:
        cmd = [sbt, "runMain NoC.CMR.CMRClusteredNoCMain"]
    print("NOC256_EMIT", KIND, cmd[-1], flush=True)
    subprocess.run(cmd, cwd=REPO, env=env, check=True)
    if not rtl.is_file():
        raise SystemExit("missing emitted 256 DUT " + str(rtl))
    return GEN_DIR


def input_files() -> dict[Path, str]:
    async_resource = REPO / "src" / "main" / "resources" / "ASYNC"
    cmr_resource = async_resource / "CMR"
    files = {
        async_resource / "DelayElement_sim.v": "rtl/DelayElement_sim.v",
        async_resource / "Mutex2_sim.v": "rtl/Mutex2_sim.v",
        async_resource / "Mutex4.v": "rtl/Mutex4.v",
        async_resource / "MullerC2.v": "rtl/MullerC2.v",
        cmr_resource / "CMRMutexN.v": "rtl/CMRMutexN.v",
        cmr_resource / "CMRFlattenedTAC.v": "rtl/CMRFlattenedTAC.v",
        cmr_resource / "LanePhaseAdapter.v": "rtl/LanePhaseAdapter.v",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc256.sh": "scripts/run_gls_cmr_noc256.sh",
        REPO / "sim/AsyncNoC/async_noc256_port_adapter.sv": "sim/tb/async_noc256_port_adapter.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc256_async_keycase.sv":
            "sim/tb/tb_noc256_async_keycase.sv",
    }
    gen = generate_rtl()
    remote_gen = "rtl/noc256_%s" % KIND
    for path in sorted(gen.glob("*.v")):
        files[path] = remote_gen + "/" + path.name
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing NoC256 input files: " + ", ".join(missing))
    return files


def submit_one(client, name: str, case_path: str):
    wrapper = ROOT + "/logs/gls/%s/rtl_%s.sh" % (BASE_RUN_ID, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC256_RUN_ID=%s CMR_NOC256_KIND=%s "
        "CMR_NOC256_CASE_NAME=%s CMR_NOC256_CASE_FILE=%s "
        "CMR_NOC256_GEN_DIR=%s CMR_NOC256_RX_CAPTURE_NS=%s "
        "CMR_NOC256_SIM_ARGS=%s\n"
        "exec bash %s/scripts/run_gls_cmr_noc256.sh\n"
        % (
            ROOT,
            shlex.quote(BASE_RUN_ID),
            shlex.quote(KIND),
            shlex.quote(name),
            shlex.quote(case_path),
            shlex.quote(ROOT + "/rtl/noc256_%s" % KIND),
            shlex.quote(RX_CAPTURE_NS),
            shlex.quote(SIM_ARGS),
            ROOT,
        )
    )
    client, _ = remote_run_retry(client, "mkdir -p %s/logs/gls/%s" % (ROOT, BASE_RUN_ID))
    sftp = client.open_sftp()
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    client, _ = remote_run_retry(client, "chmod +x %s; sed -i 's/\\r$//' %s" % (wrapper, wrapper))
    client, submit = remote_run_retry(
        client,
        "bsub %s -o %s/logs/gls/%s/rtl_%s.bsub.log "
        "-e %s/logs/gls/%s/rtl_%s.bsub.err -J %s %s"
        % (
            GLS_BSUB, ROOT, BASE_RUN_ID, name,
            ROOT, BASE_RUN_ID, name,
            _gls_job_name(name), wrapper,
        ),
    )
    jid = job_id(submit)
    print("NOC256_JOB", KIND, name, jid, flush=True)
    return client, jid


def collect(client, name: str, jid: str) -> tuple:
    base = ROOT + "/logs/gls/%s/rtl/%s" % (BASE_RUN_ID, name)
    client, run_log = remote_run_retry(client, "cat %s/run.log 2>/dev/null" % base)
    entry = {
        "job_id": jid,
        "tb_pass": "TB_RESULT PASS" in run_log,
        "result_line": next((line for line in run_log.splitlines() if "TB_RESULT " in line), None),
        "fatal": "TB_FATAL" in run_log,
    }
    passed = bool(entry["tb_pass"] and not entry["fatal"])
    return client, entry, passed


def main() -> None:
    refuse_overwrite(BASE_RUN_ID, action="noc256-rtl")
    if not CASES:
        raise SystemExit("CMR_NOC256_CASES is empty")
    if ALLOW_V3 and (V3_CASE_DIR is None or not V3_CASE_DIR.is_dir()):
        raise SystemExit("CMR_NOC256_ALLOW_V3=1 requires a V3 case directory")
    case_files = {}
    for name in CASES:
        path = case_local_path(name)
        if not path.is_file():
            raise SystemExit("missing NoC256 case " + str(path))
        case_files[name] = path
        print("LOCAL_CASE", name, path, flush=True)
    files = input_files()
    client = connect()
    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/rtl/noc256_%s %s/scripts %s/sim/tb %s/sim/cases_noc256 "
        "%s/logs/gls %s/results/%s/csv"
        % (ROOT, KIND, ROOT, ROOT, ROOT, ROOT, ROOT, BASE_RUN_ID),
    )
    sftp = client.open_sftp()
    for source, destination in files.items():
        print("UPLOAD", destination, flush=True)
        client, sftp, _digest = atomic_put_retry(client, sftp, source, destination)
    remote_cases = {}
    for name, local in case_files.items():
        dest = "sim/cases_noc256/" + name + ".case"
        client, sftp, _digest = atomic_put_retry(client, sftp, local, dest)
        remote_cases[name] = ROOT + "/" + dest
    sftp.close()
    remote_run_retry(
        client,
        "chmod +x %s/scripts/run_gls_cmr_noc256.sh; sed -i 's/\\r$//' "
        "%s/scripts/run_gls_cmr_noc256.sh %s/sim/tb/tb_noc256_async_keycase.sv "
        "%s/sim/tb/async_noc256_port_adapter.sv"
        % (ROOT, ROOT, ROOT, ROOT),
    )
    jobs = []
    for name in CASES:
        client, jid = submit_one(client, name, remote_cases[name])
        jobs.append((name, jid))
    status = {
        "run_id": BASE_RUN_ID,
        "kind": KIND,
        "cases": {name: {"job_id": jid} for name, jid in jobs},
        "submit_only": SUBMIT_ONLY,
        "all_pass": True,
    }
    result_dir = RESULT_ROOT / BASE_RUN_ID
    result_dir.mkdir(parents=True, exist_ok=True)
    if SUBMIT_ONLY:
        (result_dir / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
        print("NOC256_SUBMITTED", BASE_RUN_ID, flush=True)
        client.close()
        return
    for name, jid in jobs:
        client = wait_job(client, jid, "noc256_" + name, polls=GLS_POLLS, allow_exit=True)
        client, entry, passed = collect(client, name, jid)
        status["cases"][name] = entry
        if not passed:
            status["all_pass"] = False
        print("NOC256_CASE", KIND, name, "PASS" if passed else "FAIL", flush=True)
    sftp = client.open_sftp()
    try:
        fetch_tree(sftp, ROOT + "/logs/gls/" + BASE_RUN_ID, result_dir / "logs_gls")
    except IOError:
        print("FETCH_SKIP gls logs", flush=True)
    sftp.close()
    (result_dir / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    client.close()
    print("NOC256_SUMMARY", result_dir, "PASS" if status["all_pass"] else "FAIL", flush=True)
    if not status["all_pass"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
