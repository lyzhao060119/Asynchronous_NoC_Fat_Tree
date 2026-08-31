#!/usr/bin/env python3
"""Remote DC + MAXIMUM SDF GLS for 8x8 asynchronous CMR mesh (64 cores).

DUT is CMRMeshNoC: 64 Thin (1,1) routers, useMeshRouting constructor,
child 0-3 = W/S/E/N, parent = Local, TOP_LANES=0.  First gun is
TAB-NET-UR-3f-r0p50.  Delay is the locked hop recipe: RCU 1xDEL050,
matched buf=0, Ackin 1xDEL050.  Does not reuse NoC16 or Fat NoC64
netlists.  Unset CMR_NOC16_NETLIST_RUN_ID.  Functional GLS is opt-in
via CMR_MESH64_SKIP_FUNC=0.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from check_cmr_router_geometry import check_noc64
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
    "CMR_MESH64_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_mesh64_p50",
)
NETLIST_RUN_ID_ENV = os.environ.get("CMR_MESH64_NETLIST_RUN_ID", "").strip()
DEFAULT_CASES = ("TAB-NET-UR-3f-r0p50",)
SMOKE_CASES = (
    "noc64_00_to_10_3flit",
    "noc64_00_to_20_3flit",
    "noc64_00_to_40_3flit",
    "noc64_00_to_77_3flit",
)
ALLOWED_CASES = DEFAULT_CASES + SMOKE_CASES
CASES = tuple(
    name for name in os.environ.get("CMR_MESH64_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
FUNC_CASES = tuple(
    name
    for name in os.environ.get(
        "CMR_MESH64_FUNC_CASES",
        "noc64_00_to_10_3flit," + ",".join(CASES),
    ).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_MESH64_SKIP_GLS", "0") == "1"
SKIP_FUNC = os.environ.get("CMR_MESH64_SKIP_FUNC", "1") == "1"
SKIP_SDF = os.environ.get("CMR_MESH64_SKIP_SDF", "0") == "1"
INJECT_MAX_RATE = os.environ.get("CMR_MESH64_INJECT_MAX_RATE", "0") == "1"
SIM_ARGS = os.environ.get("CMR_MESH64_SIM_ARGS", "")
SDF_RX_CAPTURE_NS = os.environ.get("CMR_MESH64_RX_CAPTURE_NS", "0.1")
FUNC_RX_CAPTURE_NS = os.environ.get("CMR_MESH64_FUNC_RX_CAPTURE_NS", "5")
RCU_STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
RCU_UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
DC_POLLS = int(os.environ.get("CMR_MESH64_DC_POLLS", "1440"))
GLS_POLLS = int(os.environ.get("CMR_MESH64_GLS_POLLS", "720"))
DC_BSUB = os.environ.get("CMR_MESH64_DC_BSUB", "-n 16")
GLS_BSUB = os.environ.get("CMR_MESH64_GLS_BSUB", "-n 8")
EXPECTED_ROUTERS = 64
EXPECTED_PORTS = 320
EXPECTED_ADAPTERS = 0
GEN_DIR = REPO / "generated_cmr" / "mesh_noc64_11"
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"


def case_local_path(name: str) -> Path:
    if name in SMOKE_CASES:
        return REPO / "sim" / "AsyncNoC" / "testbench" / "small_cases" / (name + ".case")
    if name.startswith("TAB-"):
        return (
            REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases_noc64"
            / "TAB_64" / (name + ".case")
        )
    raise SystemExit("unknown mesh64 case " + name)


def generate_cases() -> dict[str, Path]:
    needed = tuple(dict.fromkeys(FUNC_CASES + CASES))
    missing_tab = any(name.startswith("TAB-") and not case_local_path(name).is_file() for name in needed)
    if missing_tab:
        subprocess.run(
            [
                sys.executable,
                str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_cases_noc64.py"),
                "--suite", "tab",
                "--scale", "firstgun",
                "--load-points", "0.50",
                "--packet-lengths", "3",
                "--top-lanes", "0",
                "--skip-smoke",
            ],
            cwd=REPO,
            check=True,
        )
    adapter = REPO / "sim" / "AsyncNoC" / "async_noc64_mesh_port_adapter.sv"
    if not adapter.is_file():
        subprocess.run(
            [
                sys.executable,
                str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_noc64_mesh_port_adapter.py"),
            ],
            cwd=REPO,
            check=True,
        )
    paths = {}
    for name in needed:
        path = case_local_path(name)
        if not path.is_file():
            raise SystemExit("missing mesh64 case " + str(path))
        paths[name] = path
        print("LOCAL_CASE", name, path, flush=True)
    return paths


def _check_generated(generated: Path) -> Path:
    rtl = generated / "CMRMeshNoC.v"
    if not rtl.is_file():
        raise SystemExit("missing generated mesh64: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+meshR_", text, re.M))
    async_count = len(re.findall(r"^\s+AsyncFifo(?:_\d+)?\s+", text, re.M))
    ipm_count = len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    adapter_count = len(re.findall(r"LanePhaseAdapter\s*#\s*\(\s*\.\s*LANES\s*\(\s*\d+\s*\)", text))
    top_ports = len(set(re.findall(r"io_top_input_(\d+)_", text)))
    if "module CMRMeshNoC" not in text:
        raise SystemExit("generated DUT is not named CMRMeshNoC")
    if router_count != EXPECTED_ROUTERS:
        raise SystemExit("mesh64 router count %d != %d" % (router_count, EXPECTED_ROUTERS))
    if ipm_count != EXPECTED_PORTS:
        raise SystemExit("mesh64 IPM count %d != %d" % (ipm_count, EXPECTED_PORTS))
    if adapter_count != EXPECTED_ADAPTERS:
        raise SystemExit("mesh64 adapter count %d != %d" % (adapter_count, EXPECTED_ADAPTERS))
    if top_ports != 0:
        raise SystemExit("mesh64 top ports %d != 0" % top_ports)
    if async_count:
        raise SystemExit("mesh64 expected no FIFO got async=%d" % async_count)
    require_emit_locked_delays(text, label="mesh64", ackin_unit_ps=int(ACKIN_UNIT_PS))
    check_noc64(generated, "mesh_noc64_11")
    print(
        "LOCAL_EMIT router=%d ipm=%d adapter=%d fifo=%d top=%d"
        % (router_count, ipm_count, adapter_count, async_count, top_ports),
        flush=True,
    )
    return generated


def generate_rtl() -> Path:
    rtl = GEN_DIR / "CMRMeshNoC.v"
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
    print("MESH64_EMIT n=8 lanes=1,1", flush=True)
    subprocess.run(
        [sbt, "runMain NoC.CMR.CMRMeshNoCMain"],
        cwd=REPO,
        env=env,
        check=True,
    )
    return _check_generated(GEN_DIR)


def shared_input_files() -> dict[Path, str]:
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
    files.update({
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_mesh64.tcl":
            "scripts/dc/run_dc_cmr_mesh64.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_mesh64.sh":
            "scripts/run_gls_cmr_mesh64.sh",
        REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py":
            "scripts/patch_gls_netlist.py",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc64_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv":
            "sim/tb/tb_noc64_async_boundary.sv",
        REPO / "sim/AsyncNoC/async_noc64_mesh_port_adapter.sv":
            "sim/tb/async_noc64_mesh_port_adapter.sv",
    })
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing mesh64 input files: " + ", ".join(missing))
    return files


def wait_dc_marker(client, dc_log):
    dc_text = ""
    for _ in range(12):
        client, dc_text = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_MESH64_DC_PASS" in dc_text or "CMR_MESH64_DC_FAIL" in dc_text:
            break
        time.sleep(5)
    if "CMR_MESH64_DC_PASS" not in dc_text:
        print(dc_text[-16000:], flush=True)
        raise RuntimeError("CMR mesh64 DC failed")
    return client


def collect_gls_result(client, run_id, mode, name, jid):
    base = ROOT + "/logs/gls/%s/%s/%s" % (run_id, mode, name)
    client, run_log = remote_run_retry(client, "cat %s/run.log 2>/dev/null" % base)
    annotate = ""
    if mode == "sdf":
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
        "TB_PROTOCOL_X",
        "TB_FATAL",
        "Timing violation",
    )
    first_failure = next(
        (line for line in run_log.splitlines() if any(t in line for t in failure_tokens)),
        None,
    )
    entry = {
        "job_id": jid,
        "mode": mode,
        "tb_pass": "TB_RESULT PASS" in run_log,
        "x_failure": "TB_X_FAIL" in run_log or "TB_PROTOCOL_X" in run_log,
        "unexpected_failure": "TB_UNEXPECTED_FAIL" in run_log,
        "stall_failure": "TB_STALL_FAIL" in run_log,
        "hard_timeout": "TB_HARD_TIMEOUT" in run_log,
        "fatal_failure": "TB_FATAL" in run_log or "Fatal:" in run_log,
        "timing_violation_count": run_log.count("Timing violation"),
        "setup_count": run_log.count("$setup("),
        "hold_count": run_log.count("$hold("),
        "first_failure": first_failure,
        "result_line": next(
            (line for line in run_log.splitlines() if "TB_RESULT " in line),
            None,
        ),
    }
    if mode == "sdf":
        entry["annotation_done"] = "Doing SDF annotation ...... Done" in run_log
        entry["annotation_errors"] = int(errors.group(1)) if errors else None
        entry["ifnsdfa"] = "IFNSDFA" in run_log
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
    else:
        passed = (
            entry["tb_pass"]
            and not entry["x_failure"]
            and not entry["unexpected_failure"]
            and not entry["stall_failure"]
            and not entry["hard_timeout"]
            and not entry["fatal_failure"]
        )
    return client, entry, passed


def submit_gls(client, run_id, netlist_run_id, mode, name, case_path, rx_capture):
    wrapper = ROOT + "/logs/gls/%s/%s_%s.sh" % (run_id, mode, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_MESH64_RUN_ID=%s "
        "CMR_MESH64_NETLIST_RUN_ID=%s CMR_MESH64_CASE_NAME=%s "
        "CMR_MESH64_CASE_FILE=%s CMR_MESH64_GLS_MODE=%s "
        "CMR_MESH64_RX_CAPTURE_NS=%s "
        "CMR_MESH64_INJECT_MAX_RATE=%s CMR_MESH64_SIM_ARGS=%s\n"
        "exec bash %s/scripts/run_gls_cmr_mesh64.sh\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(netlist_run_id),
            shlex.quote(name),
            shlex.quote(case_path),
            shlex.quote(mode),
            shlex.quote(rx_capture),
            "1" if INJECT_MAX_RATE else "0",
            shlex.quote(SIM_ARGS),
            ROOT,
        )
    )
    client, _ = remote_run_retry(client, "mkdir -p %s/logs/gls/%s" % (ROOT, run_id))
    client, _ = remote_run_retry(
        client,
        "cat > %s << 'CMR_GLS_WRAP'\n%s\nCMR_GLS_WRAP\nchmod +x %s"
        % (wrapper, body, wrapper),
    )
    client, submit = remote_run_retry(
        client,
        "bsub %s -o %s/logs/gls/%s/%s_%s.bsub.log "
        "-e %s/logs/gls/%s/%s_%s.bsub.err -J cmr_mesh64_%s_%s %s"
        % (
            GLS_BSUB, ROOT, run_id, mode, name,
            ROOT, run_id, mode, name,
            mode, name, wrapper,
        ),
    )
    jid = job_id(submit)
    print("GLS_JOB", mode, name, jid, flush=True)
    client = wait_job(client, jid, "%s_%s" % (mode, name), polls=GLS_POLLS, allow_exit=True)
    client, entry, passed = collect_gls_result(client, run_id, mode, name, jid)
    print(
        "GLS_CASE", mode, name, "PASS" if passed else "FAIL", entry.get("result_line"),
        flush=True,
    )
    return client, entry, passed


def run_mesh(client, case_files: dict[str, Path]) -> dict:
    run_id = BASE_RUN_ID
    result_dir = RESULT_ROOT / run_id
    skip_dc = bool(NETLIST_RUN_ID_ENV)
    netlist_run_id = NETLIST_RUN_ID_ENV or run_id
    refuse_overwrite(run_id, action="mesh64")
    if not skip_dc:
        refuse_overwrite(netlist_run_id, action="mesh64-dc")
    generated = generate_rtl()
    files = shared_input_files()
    files[generated / "CMRMeshNoC.v"] = "rtl/mesh64/CMRMeshNoC.v"
    dut_remote = ROOT + "/rtl/mesh64/CMRMeshNoC.v"
    dc_tcl_dest = "scripts/dc/run_dc_cmr_mesh64.tcl"

    client, job_text = remote_run_retry(
        client,
        "bjobs -J %s -noheader -o 'jobid stat' 2>/dev/null"
        % shlex.quote("cmr_mesh64_dc_%s" % run_id),
    )
    inflight_dc = bool(re.search(r"(\d+)\s+(PEND|RUN)", job_text))
    if inflight_dc:
        files = {src: dst for src, dst in files.items() if dst != dc_tcl_dest}
        print("SKIP_UPLOAD_DC_TCL inflight DC would replace a sourced script", flush=True)

    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/rtl/mesh64 %s/scripts/dc %s/sim/tb %s/sim/cases_mesh64 "
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
        dest = "sim/cases_mesh64/" + name + ".case"
        print("UPLOAD", dest, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        case_hashes[name] = digest
        remote_cases[name] = ROOT + "/" + dest
    sftp.close()
    sed_targets = [
        "%s/scripts/run_gls_cmr_mesh64.sh" % ROOT,
        "%s/sim/tb/tb_noc64_async_boundary.sv" % ROOT,
        "%s/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv" % ROOT,
        "%s/sim/tb/async_noc64_mesh_port_adapter.sv" % ROOT,
        "%s/scripts/patch_gls_netlist.py" % ROOT,
    ]
    if not inflight_dc:
        sed_targets.insert(1, "%s/scripts/dc/run_dc_cmr_mesh64.tcl" % ROOT)
    remote_run(
        client,
        "chmod +x %s/scripts/run_gls_cmr_mesh64.sh; sed -i 's/\\r$//' %s"
        % (ROOT, " ".join(sed_targets)),
    )
    dc_tcl_snap = ROOT + "/logs/dc/" + run_id + "_run_dc_cmr_mesh64.tcl"
    if not inflight_dc:
        remote_run(
            client,
            "cp %s/scripts/dc/run_dc_cmr_mesh64.tcl %s" % (ROOT, dc_tcl_snap),
        )

    dc_job = None
    dc_log = ROOT + "/logs/dc/" + run_id + ".log"
    if skip_dc:
        print("SKIP_DC netlist_run_id=%s" % netlist_run_id, flush=True)
        client = reconnect(client)
        client, probe = remote_run_retry(
            client,
            "test -s %s/outputs/%s/CMRMeshNoC_post.v && "
            "test -s %s/outputs/%s/CMRMeshNoC.sdf && echo OK"
            % (ROOT, netlist_run_id, ROOT, netlist_run_id),
        )
        if "OK" not in probe:
            raise RuntimeError("frozen mesh64 netlist missing for %s: %s" % (netlist_run_id, probe))
    else:
        client, existing_log = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_MESH64_DC_PASS" in existing_log:
            print("REUSE_DC_PASS", run_id, flush=True)
        else:
            client, job_text = remote_run_retry(
                client,
                "bjobs -J %s -noheader -o 'jobid stat' 2>/dev/null"
                % shlex.quote("cmr_mesh64_dc_%s" % run_id),
            )
            job_match = re.search(r"(\d+)\s+(PEND|RUN)", job_text)
            if job_match:
                dc_job = job_match.group(1)
                print("REUSE_DC_JOB", dc_job, job_match.group(2), flush=True)
                client = wait_job(client, dc_job, "dc_mesh64", polls=DC_POLLS)
                client = wait_dc_marker(client, dc_log)
            else:
                dc_wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
                dc_body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "module load syn 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_MESH64_RUN_ID=%s "
                    "CMR_MESH64_DUT_V=%s "
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
                    "bsub %s -o %s -e %s.err -J cmr_mesh64_dc_%s %s"
                    % (DC_BSUB, dc_log, dc_log, run_id, dc_wrapper),
                )
                dc_job = job_id(dc_submit)
                print("DC_JOB", dc_job, flush=True)
                client = wait_job(client, dc_job, "dc_mesh64", polls=DC_POLLS)
                client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": run_id,
        "geometry": "mesh_noc64_8x8_c1_p1",
        "top_lanes": 0,
        "expected_routers": EXPECTED_ROUTERS,
        "expected_ports": EXPECTED_PORTS,
        "expected_adapters": EXPECTED_ADAPTERS,
        "rcu_matched_delay_steps": int(RCU_STEPS),
        "rcu_matched_delay_unit_ps": int(RCU_UNIT_PS),
        "opm_ackin_delay_unit_ps": int(ACKIN_UNIT_PS),
        "sdf_rx_capture_ns": SDF_RX_CAPTURE_NS,
        "func_rx_capture_ns": FUNC_RX_CAPTURE_NS,
        "inject_max_rate": INJECT_MAX_RATE,
        "case_hashes": case_hashes,
        "upload_hashes": upload_hashes,
        "dc_job": dc_job,
        "netlist_run_id": netlist_run_id,
        "func_cases": {},
        "sdf_cases": {},
        "all_pass": True,
    }

    def skip_remaining(bucket, remaining, reason):
        for skipped in remaining:
            status[bucket][skipped] = {"skipped": True, "reason": reason}

    if not SKIP_GLS and not SKIP_FUNC:
        client = reconnect(client)
        for index, name in enumerate(FUNC_CASES):
            if name not in remote_cases:
                raise RuntimeError("missing uploaded func case " + name)
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, "func",
                name, remote_cases[name], FUNC_RX_CAPTURE_NS,
            )
            status["func_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                skip_remaining("func_cases", FUNC_CASES[index + 1:], "previous func failed: " + name)
                skip_remaining("sdf_cases", CASES, "func GLS failed: " + name)
                break
        else:
            if not SKIP_SDF:
                client = reconnect(client)
                for index, name in enumerate(CASES):
                    client, entry, passed = submit_gls(
                        client, run_id, netlist_run_id, "sdf",
                        name, remote_cases[name], SDF_RX_CAPTURE_NS,
                    )
                    status["sdf_cases"][name] = entry
                    if not passed:
                        status["all_pass"] = False
                        skip_remaining("sdf_cases", CASES[index + 1:], "previous sdf failed: " + name)
                        print(
                            "SDF_FAIL stop Mutex unchanged case=%s" % name,
                            flush=True,
                        )
                        break
    elif not SKIP_GLS and SKIP_FUNC and not SKIP_SDF:
        client = reconnect(client)
        for index, name in enumerate(CASES):
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, "sdf",
                name, remote_cases[name], SDF_RX_CAPTURE_NS,
            )
            status["sdf_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                print(
                    "SDF_FAIL stop Mutex unchanged case=%s remaining=%s"
                    % (name, ",".join(CASES[index + 1:])),
                    flush=True,
                )
                skip_remaining("sdf_cases", CASES[index + 1:], "previous sdf failed: " + name)
                break
    else:
        status["skip_gls"] = True

    result_dir.mkdir(parents=True, exist_ok=True)
    (result_dir / "summary.json").write_text(
        json.dumps(status, indent=2) + "\n", encoding="utf-8"
    )
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


def main():
    if os.environ.get("CMR_NOC16_NETLIST_RUN_ID"):
        print(
            "WARN ignoring CMR_NOC16_NETLIST_RUN_ID=%s; mesh64 always synthesizes "
            "unless CMR_MESH64_NETLIST_RUN_ID is set"
            % os.environ["CMR_NOC16_NETLIST_RUN_ID"],
            flush=True,
        )
    unknown = [name for name in dict.fromkeys(FUNC_CASES + CASES) if name not in ALLOWED_CASES]
    if unknown:
        raise SystemExit("unsupported mesh64 cases: " + ",".join(unknown))
    if not CASES:
        raise SystemExit("CMR_MESH64_CASES is empty")
    if int(ACKIN_UNIT_PS) != 50 or int(RCU_STEPS) != 1 or int(RCU_UNIT_PS) != 50:
        raise SystemExit(
            "mesh64 delay must be RCU 1xDEL050 / Ackin 1xDEL050, got rcu=%sx%s ackin=%s"
            % (RCU_STEPS, RCU_UNIT_PS, ACKIN_UNIT_PS)
        )
    print(
        "MESH64_LAUNCH cases=%s func_cases=%s rx_sdf=%s rx_func=%s skip_func=%s"
        % (
            ",".join(CASES),
            ",".join(FUNC_CASES),
            SDF_RX_CAPTURE_NS,
            FUNC_RX_CAPTURE_NS,
            "1" if SKIP_FUNC else "0",
        ),
        flush=True,
    )
    case_files = generate_cases()
    client = connect()
    status = run_mesh(client, case_files)
    client.close()
    print("MESH64_SUMMARY", RESULT_ROOT / BASE_RUN_ID, "PASS" if status["all_pass"] else "FAIL", flush=True)
    if not status["all_pass"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
