#!/usr/bin/env python3
"""Remote DC + MAXIMUM-SDF GLS for the 2x2 CMR TopMesh.

DUT is CMRTopMesh(grid=2, meshLanes=2, localLanes=2): four (2,2) routers
with coordShift=3.  Traffic is 5-flit random/directed unicast and multicast
injected on Local lane 0 of each tile.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from cmr_descal_env import apply_bsub, submit_only
from cmr_frozen_run_ids import refuse_overwrite, require_emit_locked_delays
from run_remote_cmr_flow import atomic_put_bytes, remote_run
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
BASE_RUN_ID = os.environ.get(
    "CMR_TOPMESH2_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_topmesh2_p50",
)
NETLIST_RUN_ID_ENV = os.environ.get("CMR_TOPMESH2_NETLIST_RUN_ID", "").strip()
DEFAULT_CASES = ("tm2_directed_uc", "tm2_directed_mc", "tm2_random_mix")
CASES = tuple(
    name
    for name in os.environ.get("CMR_TOPMESH2_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_TOPMESH2_SKIP_GLS", "0") == "1"
SKIP_DC = bool(NETLIST_RUN_ID_ENV)
KEEP_GOING = os.environ.get("CMR_TOPMESH2_KEEP_GOING", "0") == "1"
RCU_STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
RCU_UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
DC_POLLS = int(os.environ.get("CMR_TOPMESH2_DC_POLLS", "480"))
GLS_POLLS = int(os.environ.get("CMR_TOPMESH2_GLS_POLLS", "240"))
DC_BSUB = apply_bsub(os.environ.get("CMR_TOPMESH2_DC_BSUB", "-n 8"))
GLS_BSUB = apply_bsub(os.environ.get("CMR_TOPMESH2_GLS_BSUB", "-n 4"))
SUBMIT_ONLY = submit_only()
EXPECTED_ROUTERS = 4
EXPECTED_PORTS = 40
EXPECTED_ADAPTERS = 160
GEN_DIR = REPO / "generated_cmr" / "top_mesh_22_g2"
CASE_DIR = REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases_topmesh2"
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"


def generate_cases() -> dict[str, Path]:
    subprocess.run(
        [sys.executable, str(REPO / "scripts/asic_dc/cmr/gen_topmesh2_cases.py")],
        cwd=REPO,
        check=True,
    )
    subprocess.run(
        [sys.executable, str(REPO / "sim/AsyncNoC/testbench/gen_topmesh2_port_adapter.py")],
        cwd=REPO,
        check=True,
    )
    paths = {}
    for name in CASES:
        path = CASE_DIR / (name + ".case")
        if not path.is_file():
            raise SystemExit("missing TopMesh2 case " + str(path))
        paths[name] = path
        print("LOCAL_CASE", name, path, flush=True)
    return paths


def _check_generated(generated: Path) -> Path:
    rtl = generated / "CMRTopMesh.v"
    if not rtl.is_file():
        raise SystemExit("missing generated TopMesh2: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+topMesh_", text, re.M))
    async_count = len(re.findall(r"^\s+AsyncFifo(?:_\d+)?\s+", text, re.M))
    ipm_count = len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    adapter_count = text.count("LanePhaseAdapter")
    if "module CMRTopMesh" not in text:
        raise SystemExit("generated DUT is not named CMRTopMesh")
    if router_count != EXPECTED_ROUTERS:
        raise SystemExit("topmesh2 router count %d != %d" % (router_count, EXPECTED_ROUTERS))
    if ipm_count != EXPECTED_PORTS:
        raise SystemExit("topmesh2 IPM count %d != %d" % (ipm_count, EXPECTED_PORTS))
    if adapter_count != EXPECTED_ADAPTERS:
        raise SystemExit("topmesh2 adapter count %d != %d" % (adapter_count, EXPECTED_ADAPTERS))
    if async_count:
        raise SystemExit("topmesh2 expected no FIFO got async=%d" % async_count)
    require_emit_locked_delays(text, label="topmesh2", ackin_unit_ps=int(ACKIN_UNIT_PS))
    print(
        "LOCAL_EMIT router=%d ipm=%d adapter=%d fifo=%d"
        % (router_count, ipm_count, adapter_count, async_count),
        flush=True,
    )
    return generated


def generate_rtl() -> Path:
    rtl = GEN_DIR / "CMRTopMesh.v"
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1"
    if rtl.is_file() and not force_emit:
        try:
            return _check_generated(GEN_DIR)
        except SystemExit as exc:
            print("LOCAL_EMIT_RECHECK", exc, flush=True)
    env = os.environ.copy()
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_FORCE_EMIT"] = "1"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = str(RCU_STEPS)
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = str(RCU_UNIT_PS)
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = str(ACKIN_UNIT_PS)
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    print("TOPMESH2_EMIT grid=2 lanes=2,2", flush=True)
    subprocess.run(
        [sbt, "runMain NoC.CMR.CMRTopMeshMain 2 2 2"],
        cwd=REPO,
        env=env,
        check=True,
    )
    return _check_generated(GEN_DIR)


def shared_input_files(generated: Path | None) -> dict[Path, str]:
    cmr_resource = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"
    async_resource = REPO / "src" / "main" / "resources" / "ASYNC"
    files = {}
    for name in (
        "DelayElement_ASIC.v",
        "Mutex2_ASIC.v",
        "Mutex4.v",
        "MullerC2.v",
        "DLatchBank.v",
        "V2CloseEvent.v",
    ):
        files[async_resource / name] = "rtl/" + name
    for name in (
        "CMRMutexN.v",
        "CMRFlattenedTAC.v",
        "Toggle.v",
        "HeadPredictor.v",
        "PhaseSelector.v",
        "AddressRegisterUnit.v",
        "InternalAckModule.v",
        "RouteSelAnd2.v",
        "OPMSelector.v",
        "PhaseResetDLatch.v",
        "LanePhaseAdapter.v",
        "WriteControlUnit.v",
        "WriteCounter.v",
        "WriteAckGenerator.v",
        "ReadControlUnit.v",
        "ReadCounter.v",
        "ReadRequestGenerator.v",
        "ReadPhaseSelector.v",
        "ReadAckGenerator.v",
    ):
        files[cmr_resource / name] = "rtl/" + name
    files.update(
        {
            REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
            REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
            REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
            REPO / "scripts/asic_dc/cmr/run_dc_cmr_topmesh2.tcl": "scripts/dc/run_dc_cmr_topmesh2.tcl",
            REPO / "scripts/asic_dc/cmr/run_gls_cmr_topmesh2.sh": "scripts/run_gls_cmr_topmesh2.sh",
            REPO / "scripts/asic_dc/cmr/tb_cmr_topmesh2.sv": "sim/tb/tb_cmr_topmesh2.sv",
            REPO / "sim/AsyncNoC/async_topmesh2_port_adapter.sv": "sim/tb/async_topmesh2_port_adapter.sv",
        }
    )
    if generated is not None:
        files[generated / "CMRTopMesh.v"] = "rtl/topmesh2/CMRTopMesh.v"
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing topmesh2 input files: " + ", ".join(missing))
    return files


def wait_dc_marker(client, dc_log):
    dc_text = ""
    for _ in range(12):
        client, dc_text = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_TOPMESH2_DC_PASS" in dc_text or "CMR_TOPMESH2_DC_FAIL" in dc_text:
            break
        import time

        time.sleep(5)
    if "CMR_TOPMESH2_DC_PASS" not in dc_text:
        print(dc_text[-16000:], flush=True)
        raise RuntimeError("CMR TopMesh2 DC failed")
    return client


def collect_gls_result(client, run_id, name, jid):
    base = ROOT + "/logs/gls/%s/sdf/%s" % (run_id, name)
    client, run_log = remote_run_retry(client, "cat %s/run.log 2>/dev/null" % base)
    client, annotate = remote_run_retry(
        client, "cat %s/sdf_annotate.log 2>/dev/null" % base
    )
    errors = re.search(r"Total errors:\s*(\d+)", annotate)
    failure_tokens = (
        "TB_RESULT FAIL",
        "TB_X_FAIL",
        "TB_UNEXPECTED_FAIL",
        "TB_STALL_FAIL",
        "TB_HARD_TIMEOUT",
        "TB_FATAL",
        "Timing violation",
    )
    first_failure = next(
        (line for line in run_log.splitlines() if any(t in line for t in failure_tokens)),
        None,
    )
    entry = {
        "job_id": jid,
        "tb_pass": "TB_RESULT PASS" in run_log,
        "x_failure": "TB_X_FAIL" in run_log,
        "unexpected_failure": "TB_UNEXPECTED_FAIL" in run_log,
        "stall_failure": "TB_STALL_FAIL" in run_log,
        "hard_timeout": "TB_HARD_TIMEOUT" in run_log,
        "fatal_failure": "TB_FATAL" in run_log or "Fatal:" in run_log,
        "timing_violation_count": run_log.count("Timing violation"),
        "first_failure": first_failure,
        "result_line": next(
            (line for line in run_log.splitlines() if "TB_RESULT " in line),
            None,
        ),
        "annotation_done": "Doing SDF annotation ...... Done" in run_log,
        "annotation_errors": int(errors.group(1)) if errors else None,
        "ifnsdfa": "IFNSDFA" in run_log,
    }
    passed = (
        entry["tb_pass"]
        and entry["annotation_done"]
        and entry["annotation_errors"] == 0
        and not entry["ifnsdfa"]
        and not entry["x_failure"]
        and not entry["unexpected_failure"]
        and not entry["stall_failure"]
        and not entry["hard_timeout"]
        and not entry["fatal_failure"]
        and entry["timing_violation_count"] == 0
    )
    return client, entry, passed


def submit_gls(client, run_id, netlist_run_id, name, case_path, dep_job=None):
    wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (run_id, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_TOPMESH2_RUN_ID=%s "
        "CMR_TOPMESH2_NETLIST_RUN_ID=%s CMR_TOPMESH2_CASE_NAME=%s "
        "CMR_TOPMESH2_CASE_FILE=%s\n"
        "exec bash %s/scripts/run_gls_cmr_topmesh2.sh\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(netlist_run_id),
            shlex.quote(name),
            shlex.quote(case_path),
            ROOT,
        )
    )
    client, _ = remote_run_retry(client, "mkdir -p %s/logs/gls/%s" % (ROOT, run_id))
    client, _ = remote_run_retry(
        client,
        "cat > %s << 'CMR_GLS_WRAP'\n%s\nCMR_GLS_WRAP\nchmod +x %s"
        % (wrapper, body, wrapper),
    )
    dep = ("-w %s " % shlex.quote("done(%s)" % dep_job)) if dep_job else ""
    client, submit = remote_run_retry(
        client,
        "bsub %s %s-o %s/logs/gls/%s/sdf_%s.bsub.log "
        "-e %s/logs/gls/%s/sdf_%s.bsub.err -J cmr_topmesh2_sdf_%s %s"
        % (
            GLS_BSUB,
            dep,
            ROOT,
            run_id,
            name,
            ROOT,
            run_id,
            name,
            name,
            wrapper,
        ),
    )
    jid = job_id(submit)
    print("GLS_JOB", name, jid, flush=True)
    if SUBMIT_ONLY:
        return client, {"job_id": jid, "submitted": True}, True
    client = wait_job(client, jid, "sdf_%s" % name, polls=GLS_POLLS, allow_exit=True)
    client, entry, passed = collect_gls_result(client, run_id, name, jid)
    print("GLS_CASE", name, "PASS" if passed else "FAIL", entry.get("result_line"), flush=True)
    return client, entry, passed


def run_topmesh(client, case_files: dict[str, Path]) -> dict:
    run_id = BASE_RUN_ID
    result_dir = RESULT_ROOT / run_id
    netlist_run_id = NETLIST_RUN_ID_ENV or run_id
    refuse_overwrite(run_id, action="topmesh2")
    if not SKIP_DC:
        refuse_overwrite(netlist_run_id, action="topmesh2-dc")
    generated = None if SKIP_DC else generate_rtl()
    files = shared_input_files(generated)
    dut_remote = ROOT + "/rtl/topmesh2/CMRTopMesh.v"
    dc_tcl_dest = "scripts/dc/run_dc_cmr_topmesh2.tcl"

    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/rtl/topmesh2 %s/scripts/dc %s/sim/tb %s/sim/cases_topmesh2 "
        "%s/outputs %s/reports/dc %s/logs/dc %s/logs/gls %s/results/%s/csv %s/work"
        % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, run_id, ROOT),
    )

    upload_hashes = {}
    sftp = client.open_sftp()
    for source, destination in files.items():
        print("UPLOAD", destination, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, source, destination)
        upload_hashes[destination] = digest
    case_hashes = {}
    remote_cases = {}
    for name, local in case_files.items():
        dest = "sim/cases_topmesh2/" + name + ".case"
        print("UPLOAD", dest, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        case_hashes[name] = digest
        remote_cases[name] = ROOT + "/" + dest
    sftp.close()
    remote_run(
        client,
        "chmod +x %s/scripts/run_gls_cmr_topmesh2.sh; sed -i 's/\\r$//' %s %s %s %s"
        % (
            ROOT,
            ROOT + "/scripts/run_gls_cmr_topmesh2.sh",
            ROOT + "/scripts/dc/run_dc_cmr_topmesh2.tcl",
            ROOT + "/sim/tb/tb_cmr_topmesh2.sv",
            ROOT + "/sim/tb/async_topmesh2_port_adapter.sv",
        ),
    )
    dc_tcl_snap = ROOT + "/logs/dc/" + run_id + "_run_dc_cmr_topmesh2.tcl"
    remote_run(client, "cp %s/scripts/dc/run_dc_cmr_topmesh2.tcl %s" % (ROOT, dc_tcl_snap))

    dc_job = None
    dc_log = ROOT + "/logs/dc/" + run_id + ".log"
    if SKIP_DC:
        print("SKIP_DC netlist_run_id=%s" % netlist_run_id, flush=True)
        client = reconnect(client)
        client, probe = remote_run_retry(
            client,
            "test -s %s/outputs/%s/CMRTopMesh_post.v && "
            "test -s %s/outputs/%s/CMRTopMesh.sdf && echo OK"
            % (ROOT, netlist_run_id, ROOT, netlist_run_id),
        )
        if "OK" not in probe:
            raise RuntimeError("frozen TopMesh2 netlist missing for %s" % netlist_run_id)
    else:
        dc_wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
        dc_body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "module load syn 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_TOPMESH2_RUN_ID=%s "
            "CMR_TOPMESH2_DUT_V=%s "
            "CMR_EXPECTED_ADAPTERS=%d CMR_EXPECTED_PORTS=%d "
            "CMR_EXPECTED_ROUTERS=%d "
            "CMR_RCU_MATCHED_DELAY_STEPS=%s CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
            "CMR_OPM_ACKIN_DELAY_UNIT_PS=%s\n"
            "cd %s\nexec dc_shell-t -64 -f %s\n"
            % (
                ROOT,
                shlex.quote(run_id),
                shlex.quote(dut_remote),
                EXPECTED_ADAPTERS,
                EXPECTED_PORTS,
                EXPECTED_ROUTERS,
                shlex.quote(str(RCU_STEPS)),
                shlex.quote(str(RCU_UNIT_PS)),
                shlex.quote(str(ACKIN_UNIT_PS)),
                ROOT,
                dc_tcl_snap,
            )
        )
        sftp = client.open_sftp()
        atomic_put_bytes(client, sftp, dc_body.encode(), dc_wrapper)
        sftp.close()
        client, _ = remote_run_retry(client, "chmod +x %s" % dc_wrapper)
        client, dc_submit = remote_run_retry(
            client,
            "bsub %s -o %s -e %s.err -J cmr_topmesh2_dc_%s %s"
            % (DC_BSUB, dc_log, dc_log, run_id, dc_wrapper),
        )
        dc_job = job_id(dc_submit)
        print("DC_JOB", dc_job, flush=True)
        if not SUBMIT_ONLY:
            client = wait_job(client, dc_job, "dc_topmesh2", polls=DC_POLLS)
            client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": run_id,
        "geometry": "topmesh_2x2_c2_p2",
        "expected_routers": EXPECTED_ROUTERS,
        "expected_ports": EXPECTED_PORTS,
        "expected_adapters": EXPECTED_ADAPTERS,
        "case_hashes": case_hashes,
        "upload_hashes": upload_hashes,
        "dc_job": dc_job,
        "netlist_run_id": netlist_run_id,
        "sdf_cases": {},
        "all_pass": True,
        "submit_only": SUBMIT_ONLY,
    }
    gls_dep = ("cmr_topmesh2_dc_%s" % run_id) if (SUBMIT_ONLY and not SKIP_DC and dc_job is not None) else None
    if not SKIP_GLS:
        client = reconnect(client)
        for index, name in enumerate(CASES):
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, name, remote_cases[name], dep_job=gls_dep
            )
            status["sdf_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                if KEEP_GOING:
                    print("SDF_FAIL continue case=%s" % name, flush=True)
                    continue
                print("SDF_FAIL stop case=%s" % name, flush=True)
                for skipped in CASES[index + 1 :]:
                    status["sdf_cases"][skipped] = {"skipped": True, "reason": "previous sdf failed"}
                break
    result_dir.mkdir(parents=True, exist_ok=True)
    (result_dir / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    if SUBMIT_ONLY:
        print("LOCAL_RESULT", result_dir, "SUBMITTED", flush=True)
        return status
    sftp = client.open_sftp()
    fetch_list = [
        (ROOT + "/reports/dc/" + netlist_run_id, result_dir / "reports_dc"),
        (ROOT + "/logs/dc/" + run_id + ".log", result_dir / "dc.log"),
    ]
    if not SKIP_GLS:
        fetch_list.append((ROOT + "/logs/gls/" + run_id, result_dir / "logs_gls"))
    for remote, local in fetch_list:
        try:
            if remote.endswith(".log"):
                result_dir.mkdir(parents=True, exist_ok=True)
                sftp.get(remote, str(local))
            else:
                fetch_tree(sftp, remote, local)
        except IOError:
            print("FETCH_SKIP", remote, flush=True)
    sftp.close()
    print("LOCAL_RESULT", result_dir, "PASS" if status["all_pass"] else "FAIL", flush=True)
    return status


def main() -> int:
    if int(ACKIN_UNIT_PS) != 50 or int(RCU_STEPS) != 1 or int(RCU_UNIT_PS) != 50:
        raise SystemExit("topmesh2 delay must be RCU 1xDEL050 / Ackin 1xDEL050")
    if not CASES:
        raise SystemExit("CMR_TOPMESH2_CASES is empty")
    print("TOPMESH2_LAUNCH cases=%s" % ",".join(CASES), flush=True)
    case_files = generate_cases()
    client = connect()
    try:
        status = run_topmesh(client, case_files)
    finally:
        client.close()
    print("TOPMESH2_SUMMARY", RESULT_ROOT / BASE_RUN_ID, "PASS" if status["all_pass"] else "FAIL", flush=True)
    if not status["all_pass"] and not SUBMIT_ONLY:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
