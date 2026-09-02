#!/usr/bin/env python3
"""Remote DC + MAXIMUM SDF GLS for 4x4 asynchronous CMR mesh (16 cores).

Scaled from the 8x8 mesh64 flow.  DUT is CMRMeshNoC n=4: 16 Thin (1,1)
routers, TOP_LANES=0.  Isolation case is PE3→PE13 (west then north).
Does not reuse fat-tree NoC16.  No functional GLS.
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

from check_cmr_router_geometry import check_noc64
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
from run_remote_cmr_mesh64_sdf import collect_gls_result, wait_dc_marker


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
BASE_RUN_ID = os.environ.get(
    "CMR_MESH16_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_descal_fm16",
)
NETLIST_RUN_ID_ENV = os.environ.get("CMR_MESH16_NETLIST_RUN_ID", "").strip()
DEFAULT_CASES = ("DBG-16_fm16_3to13",)
CASES = tuple(
    name for name in os.environ.get("CMR_MESH16_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_MESH16_SKIP_GLS", "0") == "1"
SKIP_SDF = os.environ.get("CMR_MESH16_SKIP_SDF", "0") == "1"
ALLOW_V3 = os.environ.get("CMR_MESH16_ALLOW_V3", "0") == "1" or os.environ.get("CMR_NOC64_ALLOW_V3", "0") == "1"
V3_CASE_DIR = Path(os.environ["CMR_MESH16_V3_CASE_DIR"]) if os.environ.get("CMR_MESH16_V3_CASE_DIR") else (
    Path(os.environ["CMR_NOC64_V3_CASE_DIR"]) if os.environ.get("CMR_NOC64_V3_CASE_DIR") else None
)
DESCAL = os.environ.get("CMR_DESCAL", "0") == "1"
INJECT_MAX_RATE = os.environ.get("CMR_MESH16_INJECT_MAX_RATE", "0") == "1"
SIM_ARGS = os.environ.get("CMR_MESH16_SIM_ARGS", "")
SDF_RX_CAPTURE_NS = os.environ.get("CMR_MESH16_RX_CAPTURE_NS", "0.1")
RCU_STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
RCU_UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
GRANT_HOLD_BUF = os.environ.get("CMR_EXPECTED_GRANT_HOLD_BUF", "").strip()
DC_POLLS = int(os.environ.get("CMR_MESH16_DC_POLLS", "1440"))
GLS_POLLS = int(os.environ.get("CMR_MESH16_GLS_POLLS", "720"))
DC_BSUB = apply_bsub(os.environ.get("CMR_MESH16_DC_BSUB", "-n 8"))
GLS_BSUB = apply_bsub(os.environ.get("CMR_MESH16_GLS_BSUB", "-n 8"))
SUBMIT_ONLY = submit_only()
EXPECTED_ROUTERS = 16
EXPECTED_PORTS = 80
EXPECTED_ADAPTERS = 0
GEN_DIR = REPO / "generated_cmr" / "mesh_noc16_11"
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"
ADAPTER = REPO / "sim" / "AsyncNoC" / "async_noc16_mesh_port_adapter.sv"


def _dc_job_name(run_id: str) -> str:
    if DESCAL:
        return "cmr_descal_mesh16_dc_%s" % run_id
    return "cmr_mesh16_dc_%s" % run_id


def _gls_job_name(mode: str, name: str) -> str:
    if DESCAL:
        return "cmr_descal_mesh16_%s_%s" % (mode, name)
    return "cmr_mesh16_%s_%s" % (mode, name)


def case_local_path(name: str) -> Path:
    if ALLOW_V3 and V3_CASE_DIR is not None:
        candidate = V3_CASE_DIR / (name + ".case")
        if candidate.is_file():
            return candidate
    raise SystemExit("unknown mesh16 case " + name)


def generate_adapter() -> None:
    if ADAPTER.is_file():
        return
    subprocess.run(
        [sys.executable, str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_noc16_mesh_port_adapter.py")],
        cwd=REPO,
        check=True,
    )


def generate_cases() -> dict[str, Path]:
    generate_adapter()
    paths = {}
    for name in CASES:
        path = case_local_path(name)
        if not path.is_file():
            raise SystemExit("missing V3 mesh16 case " + str(path))
        paths[name] = path
        print("LOCAL_CASE", name, path, flush=True)
    return paths


def _check_generated(generated: Path) -> Path:
    rtl = generated / "CMRMeshNoC.v"
    if not rtl.is_file():
        raise SystemExit("missing generated mesh16: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+meshR_", text, re.M))
    async_count = len(re.findall(r"^\s+AsyncFifo(?:_\d+)?\s+", text, re.M))
    ipm_count = len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    adapter_count = len(re.findall(r"LanePhaseAdapter\s*#\s*\(\s*\.\s*LANES\s*\(\s*\d+\s*\)", text))
    top_ports = len(set(re.findall(r"io_top_input_(\d+)_", text)))
    if "module CMRMeshNoC" not in text:
        raise SystemExit("generated DUT is not named CMRMeshNoC")
    if router_count != EXPECTED_ROUTERS:
        raise SystemExit("mesh16 router count %d != %d" % (router_count, EXPECTED_ROUTERS))
    if ipm_count != EXPECTED_PORTS:
        raise SystemExit("mesh16 IPM count %d != %d" % (ipm_count, EXPECTED_PORTS))
    if adapter_count != EXPECTED_ADAPTERS:
        raise SystemExit("mesh16 adapter count %d != %d" % (adapter_count, EXPECTED_ADAPTERS))
    if top_ports != 0:
        raise SystemExit("mesh16 top ports %d != 0" % top_ports)
    if async_count:
        raise SystemExit("mesh16 expected no FIFO got async=%d" % async_count)
    require_emit_locked_delays(text, label="mesh16", ackin_unit_ps=int(ACKIN_UNIT_PS))
    check_noc64(generated, "mesh_noc16_11")
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
    print("MESH16_EMIT n=4 lanes=1,1", flush=True)
    subprocess.run(
        [sbt, "runMain NoC.CMR.CMRMeshNoCMain 4 1 1"],
        cwd=str(REPO),
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
        "DontTouchBuf_ASIC.v",
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
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_mesh16.sh":
            "scripts/run_gls_cmr_mesh16.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc64_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv":
            "sim/tb/tb_noc64_async_boundary.sv",
        ADAPTER: "sim/tb/async_noc16_mesh_port_adapter.sv",
    })
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing mesh16 input files: " + ", ".join(missing))
    return files


def submit_gls(client, run_id, netlist_run_id, name, case_path, dep_job=None):
    wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (run_id, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_MESH16_RUN_ID=%s "
        "CMR_MESH16_NETLIST_RUN_ID=%s CMR_MESH16_CASE_NAME=%s "
        "CMR_MESH16_CASE_FILE=%s CMR_MESH16_GLS_MODE=sdf "
        "CMR_MESH16_RX_CAPTURE_NS=%s "
        "CMR_MESH16_INJECT_MAX_RATE=%s CMR_MESH16_SIM_ARGS=%s\n"
        "exec bash %s/scripts/run_gls_cmr_mesh16.sh\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(netlist_run_id),
            shlex.quote(name),
            shlex.quote(case_path),
            shlex.quote(SDF_RX_CAPTURE_NS),
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
    dep = ("-w %s " % shlex.quote("done(%s)" % dep_job)) if dep_job else ""
    client, submit = remote_run_retry(
        client,
        "bsub %s %s-o %s/logs/gls/%s/sdf_%s.bsub.log "
        "-e %s/logs/gls/%s/sdf_%s.bsub.err -J %s %s"
        % (
            GLS_BSUB, dep, ROOT, run_id, name,
            ROOT, run_id, name,
            _gls_job_name("sdf", name), wrapper,
        ),
    )
    jid = job_id(submit)
    print("GLS_JOB sdf", name, jid, flush=True)
    if SUBMIT_ONLY:
        return client, {"job_id": jid, "mode": "sdf", "submitted": True}, True
    client = wait_job(client, jid, "sdf_%s" % name, polls=GLS_POLLS, allow_exit=True)
    client, entry, passed = collect_gls_result(client, run_id, "sdf", name, jid)
    print("GLS_CASE sdf", name, "PASS" if passed else "FAIL", entry.get("result_line"), flush=True)
    return client, entry, passed


def run_mesh(client, case_files: dict[str, Path]) -> dict:
    run_id = BASE_RUN_ID
    result_dir = RESULT_ROOT / run_id
    skip_dc = bool(NETLIST_RUN_ID_ENV)
    netlist_run_id = NETLIST_RUN_ID_ENV or run_id
    refuse_overwrite(run_id, action="mesh16")
    if not skip_dc:
        refuse_overwrite(netlist_run_id, action="mesh16-dc")
    generate_adapter()
    files = shared_input_files()
    dut_remote = ROOT + "/rtl/mesh16/CMRMeshNoC.v"
    if skip_dc:
        print(
            "SKIP_DC omit local CMRMeshNoC.v emit; GLS uses frozen post netlist %s"
            % netlist_run_id,
            flush=True,
        )
    else:
        generated = generate_rtl()
        files[generated / "CMRMeshNoC.v"] = "rtl/mesh16/CMRMeshNoC.v"
    dc_tcl_dest = "scripts/dc/run_dc_cmr_mesh64.tcl"

    client, job_text = remote_run_retry(
        client,
        "bjobs -J %s -noheader -o 'jobid stat' 2>/dev/null"
        % shlex.quote(_dc_job_name(run_id)),
    )
    inflight_dc = bool(re.search(r"(\d+)\s+(PEND|RUN)", job_text))
    if inflight_dc:
        files = {src: dst for src, dst in files.items() if dst != dc_tcl_dest}
        print("SKIP_UPLOAD_DC_TCL inflight DC would replace a sourced script", flush=True)

    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/rtl/mesh16 %s/scripts/dc %s/sim/tb %s/sim/cases_mesh16 "
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
        dest = "sim/cases_mesh16/" + name + ".case"
        print("UPLOAD", dest, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        case_hashes[name] = digest
        remote_cases[name] = ROOT + "/" + dest
    sftp.close()
    sed_targets = [
        "%s/scripts/run_gls_cmr_mesh16.sh" % ROOT,
        "%s/sim/tb/tb_noc64_async_boundary.sv" % ROOT,
        "%s/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv" % ROOT,
        "%s/sim/tb/async_noc16_mesh_port_adapter.sv" % ROOT,
    ]
    if not inflight_dc:
        sed_targets.insert(1, "%s/scripts/dc/run_dc_cmr_mesh64.tcl" % ROOT)
    remote_run(
        client,
        "chmod +x %s/scripts/run_gls_cmr_mesh16.sh; sed -i 's/\\r$//' %s"
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
            raise RuntimeError("frozen mesh16 netlist missing for %s: %s" % (netlist_run_id, probe))
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
                % shlex.quote(_dc_job_name(run_id)),
            )
            job_match = re.search(r"(\d+)\s+(PEND|RUN)", job_text)
            if job_match:
                dc_job = job_match.group(1)
                print("REUSE_DC_JOB", dc_job, job_match.group(2), flush=True)
                if SUBMIT_ONLY:
                    print("SUBMIT_ONLY reuse_dc=%s" % dc_job, flush=True)
                else:
                    client = wait_job(client, dc_job, "dc_mesh16", polls=DC_POLLS)
                    client = wait_dc_marker(client, dc_log)
            else:
                grant_export = (
                    " CMR_EXPECTED_GRANT_HOLD_BUF=%s" % shlex.quote(GRANT_HOLD_BUF)
                    if GRANT_HOLD_BUF else ""
                )
                dc_wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
                dc_body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "module load syn 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_MESH64_RUN_ID=%s "
                    "CMR_MESH64_DUT_V=%s "
                    "CMR_EXPECTED_ADAPTERS=%d CMR_EXPECTED_PORTS=%d "
                    "CMR_EXPECTED_ROUTERS=%d "
                    "CMR_RCU_MATCHED_DELAY_STEPS=%s CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
                    "CMR_OPM_ACKIN_DELAY_UNIT_PS=%s%s\n"
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
                        grant_export,
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
                    "bsub %s -o %s -e %s.err -J %s %s"
                    % (DC_BSUB, dc_log, dc_log, _dc_job_name(run_id), dc_wrapper),
                )
                dc_job = job_id(dc_submit)
                print("DC_JOB", dc_job, flush=True)
                if SUBMIT_ONLY:
                    print("SUBMIT_ONLY dc=%s" % dc_job, flush=True)
                else:
                    client = wait_job(client, dc_job, "dc_mesh16", polls=DC_POLLS)
                    client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": run_id,
        "geometry": "mesh_noc16_4x4_c1_p1",
        "top_lanes": 0,
        "expected_routers": EXPECTED_ROUTERS,
        "expected_ports": EXPECTED_PORTS,
        "expected_adapters": EXPECTED_ADAPTERS,
        "rcu_matched_delay_steps": int(RCU_STEPS),
        "rcu_matched_delay_unit_ps": int(RCU_UNIT_PS),
        "opm_ackin_delay_unit_ps": int(ACKIN_UNIT_PS),
        "grant_hold_buf": GRANT_HOLD_BUF,
        "sdf_rx_capture_ns": SDF_RX_CAPTURE_NS,
        "case_hashes": case_hashes,
        "upload_hashes": upload_hashes,
        "dc_job": dc_job,
        "netlist_run_id": netlist_run_id,
        "sdf_cases": {},
        "all_pass": True,
    }
    gls_dep = _dc_job_name(run_id) if (SUBMIT_ONLY and not skip_dc and dc_job is not None) else None

    if not SKIP_GLS and not SKIP_SDF:
        client = reconnect(client)
        for name in CASES:
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, name, remote_cases[name], dep_job=gls_dep,
            )
            status["sdf_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                print("SDF_FAIL case=%s" % name, flush=True)
                break
    else:
        status["skip_gls"] = True

    result_dir.mkdir(parents=True, exist_ok=True)
    status["submit_only"] = SUBMIT_ONLY
    status["gls_dep"] = gls_dep
    (result_dir / "summary.json").write_text(
        json.dumps(status, indent=2) + "\n", encoding="utf-8"
    )
    if SUBMIT_ONLY:
        print("LOCAL_RESULT", result_dir, "SUBMITTED", flush=True)
        return status
    sftp = client.open_sftp()
    fetch_list = [
        (ROOT + "/reports/dc/" + netlist_run_id, result_dir / "reports_dc"),
        (ROOT + "/logs/dc/" + run_id + ".log", result_dir / "dc.log"),
        (ROOT + "/logs/gls/" + run_id, result_dir / "logs_gls"),
    ]
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
            "WARN ignoring CMR_NOC16_NETLIST_RUN_ID=%s; mesh16 is not fat-tree NoC16"
            % os.environ["CMR_NOC16_NETLIST_RUN_ID"],
            flush=True,
        )
    if not ALLOW_V3:
        raise SystemExit("mesh16 GLS requires CMR_MESH16_ALLOW_V3=1 or CMR_NOC64_ALLOW_V3=1")
    if V3_CASE_DIR is None or not V3_CASE_DIR.is_dir():
        raise SystemExit("mesh16 V3 GLS requires CMR_MESH16_V3_CASE_DIR or CMR_NOC64_V3_CASE_DIR")
    if DESCAL:
        refuse_overwrite(BASE_RUN_ID, action="descal-mesh16")
    if not CASES:
        raise SystemExit("CMR_MESH16_CASES is empty")
    if int(ACKIN_UNIT_PS) != 50 or int(RCU_STEPS) != 1 or int(RCU_UNIT_PS) != 50:
        raise SystemExit(
            "mesh16 delay must be RCU 1xDEL050 / Ackin 1xDEL050, got rcu=%sx%s ackin=%s"
            % (RCU_STEPS, RCU_UNIT_PS, ACKIN_UNIT_PS)
        )
    print(
        "MESH16_LAUNCH cases=%s rx_sdf=%s skip_sdf=%s grant_hold=%s"
        % (",".join(CASES), SDF_RX_CAPTURE_NS, "1" if SKIP_SDF else "0", GRANT_HOLD_BUF or "unset"),
        flush=True,
    )
    case_files = generate_cases()
    client = connect()
    status = run_mesh(client, case_files)
    client.close()
    print("MESH16_SUMMARY", RESULT_ROOT / BASE_RUN_ID, "PASS" if status["all_pass"] else "FAIL", flush=True)
    if not status["all_pass"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
