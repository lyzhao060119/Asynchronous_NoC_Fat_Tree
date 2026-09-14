#!/usr/bin/env python3
"""Remote clocked DC + MAXIMUM SDF GLS for 64-core SyncCmrFatTree.

Profiles (CMR_SYNC64_PROFILE):
  thin     (1,1) three-level tree, 1 top lane, 105 ports (default)
  fat1222  L1 1->2, L2/L3 2->2, 2 top lanes, 146 ports, 264 SyncLaneSelector

No Mutex, no DelayElement, no LanePhaseAdapter.  Functional/no-SDF GLS is
not implemented: emit -> clock DC -> MAXIMUM SDF.

Clock default 1.0 ns (frozen; docs/CMR_Sync64_Clock_Freeze.md).  Does not
reuse NoC16, async NoC64, or the other geometry's signed netlist.
Unset CMR_NOC16_NETLIST_RUN_ID.
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

from cmr_frozen_run_ids import (
    FROZEN_SYNC64_FAT1222_RUN_ID,
    FROZEN_SYNC64_THIN_RUN_ID,
    refuse_overwrite,
)
from run_remote_cmr_fat_tree_noc16_sdf import (
    atomic_put_retry,
    connect,
    fetch_tree,
    job_id,
    reconnect,
    remote_run_retry,
    wait_job,
)
from run_remote_cmr_flow import atomic_put_bytes, remote_run


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
SIGNED_THIN_RUN_ID = FROZEN_SYNC64_THIN_RUN_ID
SIGNED_FAT1222_RUN_ID = FROZEN_SYNC64_FAT1222_RUN_ID

_raw_profile = os.environ.get("CMR_SYNC64_PROFILE", "thin").strip().lower()
_raw_profile = _raw_profile.replace("-", "").replace("_", "")
if _raw_profile in ("fat1222", "1222", "fat"):
    PROFILE = "fat1222"
elif _raw_profile in ("thin", "111"):
    PROFILE = "thin"
else:
    raise SystemExit(
        "CMR_SYNC64_PROFILE must be thin or fat1222, got %s"
        % os.environ.get("CMR_SYNC64_PROFILE", "")
    )

if PROFILE == "fat1222":
    RUN_SUFFIX = "_cmr_sync_noc64_fat1222_p50"
    DEFAULT_CASES = ("TAB-NET-UR-3f-r0p50", "VCTM-MC5-NM-3f-r0p50")
    EXPECTED_PORTS = 146
    EXPECTED_TOP = 2
    EXPECTED_SELECTORS = 264
    CASE_TOP_LANES = "2"
    RTL_REMOTE_DIR = "rtl/sync_noc64_fat1222"
    GEN_DIR = REPO / "generated_sync_cmr" / "fat_tree_noc64_1222"
    EMIT_MAIN = "NoC.CMR.SyncCmrFatTreeNoC64Fat1222Main"
    EMIT_LABEL = "fat 1-2-2-2 bypass"
    GEOMETRY = "fat_tree_noc64_l1_1to2_l2_2to2_l3_2to2"
else:
    RUN_SUFFIX = "_cmr_sync_noc64_thin_p50"
    DEFAULT_CASES = ("TAB-NET-UR-3f-r0p50",)
    EXPECTED_PORTS = 105
    EXPECTED_TOP = 1
    EXPECTED_SELECTORS = 0
    CASE_TOP_LANES = "1"
    RTL_REMOTE_DIR = "rtl/sync_noc64_thin"
    GEN_DIR = REPO / "generated_sync_cmr" / "fat_tree_noc64_thin"
    EMIT_MAIN = "NoC.CMR.SyncCmrFatTreeNoC64Main"
    EMIT_LABEL = "thin (1,1) bypass"
    GEOMETRY = "thin_tree_noc64_l1_1to1_l2_1to1_l3_1to1"

BASE_RUN_ID = os.environ.get(
    "CMR_SYNC64_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + RUN_SUFFIX,
)
NETLIST_RUN_ID_ENV = os.environ.get("CMR_SYNC64_NETLIST_RUN_ID", "").strip()
VCTM_CASES = ("VCTM-MC5-NM-3f-r0p50",)
SMOKE_CASES = (
    "noc64_00_to_10_3flit",
    "noc64_00_to_20_3flit",
    "noc64_00_to_40_3flit",
    "noc64_00_to_77_3flit",
)
ALLOWED_CASES = ("TAB-NET-UR-3f-r0p50",) + SMOKE_CASES + VCTM_CASES
CASES = tuple(
    name for name in os.environ.get("CMR_SYNC64_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_SYNC64_SKIP_GLS", "0") == "1"
INJECT_MAX_RATE = os.environ.get("CMR_SYNC64_INJECT_MAX_RATE", "0") == "1"
SIM_ARGS = os.environ.get("CMR_SYNC64_SIM_ARGS", "")
CLOCK_PERIOD_NS = os.environ.get("CMR_SYNC64_CLOCK_PERIOD_NS", "1.0")
SDF_RX_CAPTURE_NS = os.environ.get("CMR_SYNC64_RX_CAPTURE_NS", "0")
DC_POLLS = int(os.environ.get("CMR_SYNC64_DC_POLLS", "1440"))
GLS_POLLS = int(os.environ.get("CMR_SYNC64_GLS_POLLS", "720"))
DC_BSUB = os.environ.get("CMR_SYNC64_DC_BSUB", "-n 16")
GLS_BSUB = os.environ.get("CMR_SYNC64_GLS_BSUB", "-n 8")
EXPECTED_ROUTERS = 21
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"


def case_local_path(name: str) -> Path:
    if name in SMOKE_CASES:
        return REPO / "sim" / "AsyncNoC" / "testbench" / "small_cases" / (name + ".case")
    if name.startswith("TAB-"):
        return (
            REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases_noc64"
            / "TAB_64" / (name + ".case")
        )
    if name.startswith("VCTM-"):
        return (
            REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases_noc64"
            / "VCTM_64" / (name + ".case")
        )
    raise SystemExit("unknown sync NoC64 case " + name)


def generate_cases() -> dict[str, Path]:
    needed = tuple(dict.fromkeys(CASES))
    missing_tab = any(name.startswith("TAB-") and not case_local_path(name).is_file() for name in needed)
    missing_vctm = any(name.startswith("VCTM-") and not case_local_path(name).is_file() for name in needed)
    if missing_tab:
        subprocess.run(
            [
                sys.executable,
                str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_cases_noc64.py"),
                "--suite", "tab",
                "--scale", "firstgun",
                "--load-points", "0.50",
                "--packet-lengths", "3",
                "--top-lanes", CASE_TOP_LANES,
            ],
            cwd=REPO,
            check=True,
        )
    if missing_vctm:
        subprocess.run(
            [
                sys.executable,
                str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_cases_noc64.py"),
                "--suite", "vctm",
                "--scale", "firstgun",
                "--load-points", "0.50",
                "--packet-lengths", "3",
                "--top-lanes", CASE_TOP_LANES,
            ],
            cwd=REPO,
            check=True,
        )
    adapter = REPO / "sim" / "AsyncNoC" / "sync_noc64_port_adapter.sv"
    subprocess.run(
        [
            sys.executable,
            str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_sync_noc64_port_adapter.py"),
        ],
        cwd=REPO,
        check=True,
    )
    if not adapter.is_file():
        raise SystemExit("missing sync NoC64 adapter " + str(adapter))
    paths = {}
    for name in needed:
        path = case_local_path(name)
        if not path.is_file():
            raise SystemExit("missing sync NoC64 case " + str(path))
        paths[name] = path
        print("LOCAL_CASE", name, path, flush=True)
    return paths


def _check_generated(generated: Path) -> Path:
    rtl = generated / "SyncNoC_64nodes.v"
    if not rtl.is_file():
        raise SystemExit("missing generated SyncNoC64: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"^\s+SyncCmrRouter(?:_\d+)?\s+routers?L", text, re.M))
    ipm_count = len(re.findall(r"^\s+SyncCmrIPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    opm_count = len(re.findall(r"^\s+SyncOPM(?:_\d+)?\s+OutputPortModules_\d+", text, re.M))
    mutex_count = len(re.findall(r"\bMutex\d+\b", text))
    delay_count = len(re.findall(r"\bDelayElement\b", text))
    adapter_count = len(re.findall(r"\bLanePhaseAdapter\b", text))
    fifo_count = len(re.findall(r"\b(?:AsyncFifo|CircularFifo)\b", text))
    selector_count = len(re.findall(r"^\s+SyncLaneSelector(?:_\d+)?\s+\w+", text, re.M))
    top_ports = len(set(re.findall(r"io_top_input_(\d+)_", text)))
    if "module SyncNoC_64nodes" not in text:
        raise SystemExit("generated DUT is not named SyncNoC_64nodes")
    if "io_core_inputs_0_hs_valid" not in text:
        raise SystemExit("generated DUT is not valid/ready (missing hs_valid)")
    if "HS_Req" in text:
        raise SystemExit("generated DUT still has async HS_Req ports")
    if router_count != EXPECTED_ROUTERS:
        raise SystemExit("SyncNoC64 router count %d != %d" % (router_count, EXPECTED_ROUTERS))
    if ipm_count != EXPECTED_PORTS:
        raise SystemExit("SyncNoC64 IPM count %d != %d" % (ipm_count, EXPECTED_PORTS))
    if opm_count != EXPECTED_PORTS:
        raise SystemExit("SyncNoC64 OPM count %d != %d" % (opm_count, EXPECTED_PORTS))
    if mutex_count or delay_count or adapter_count or fifo_count:
        raise SystemExit(
            "SyncNoC64 async leak mutex=%d delay=%d adapter=%d fifo=%d"
            % (mutex_count, delay_count, adapter_count, fifo_count)
        )
    if "RRArbiter" in text:
        raise SystemExit("SyncNoC64 still instantiates RRArbiter")
    if top_ports != EXPECTED_TOP:
        raise SystemExit("SyncNoC64 top ports %d != %d" % (top_ports, EXPECTED_TOP))
    if selector_count != EXPECTED_SELECTORS:
        raise SystemExit(
            "SyncNoC64 SyncLaneSelector count %d != %d" % (selector_count, EXPECTED_SELECTORS)
        )
    print(
        "LOCAL_EMIT router=%d ipm=%d opm=%d top=%d selector=%d profile=%s"
        % (router_count, ipm_count, opm_count, top_ports, selector_count, PROFILE),
        flush=True,
    )
    return generated


def generate_rtl() -> Path:
    generated = GEN_DIR
    rtl = generated / "SyncNoC_64nodes.v"
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1"
    if rtl.is_file() and not force_emit:
        try:
            return _check_generated(generated)
        except SystemExit as exc:
            print("LOCAL_EMIT_RECHECK", exc, flush=True)
    env = os.environ.copy()
    env["CMR_FORCE_EMIT"] = "1"
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    print("SYNC64_EMIT", EMIT_LABEL, flush=True)
    subprocess.run(
        [sbt, "runMain " + EMIT_MAIN],
        cwd=REPO,
        env=env,
        check=True,
    )
    return _check_generated(generated)


def shared_input_files() -> dict[Path, str]:
    files = {
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/sync_cmr_noc64.sdc": "rtl/sync_cmr_noc64.sdc",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_sync_fat_tree_noc64.tcl":
            "scripts/dc/run_dc_cmr_sync_fat_tree_noc64.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_sync_noc64.sh":
            "scripts/run_gls_cmr_sync_noc64.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc64_sync_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc64_sync_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_sync_boundary.sv":
            "sim/tb/tb_noc64_sync_boundary.sv",
        REPO / "sim/AsyncNoC/sync_noc64_port_adapter.sv":
            "sim/tb/sync_noc64_port_adapter.sv",
    }
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing sync NoC64 input files: " + ", ".join(missing))
    return files


def wait_dc_marker(client, dc_log):
    dc_text = ""
    for _ in range(12):
        client, dc_text = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_SYNC64_DC_PASS" in dc_text or "CMR_SYNC64_DC_FAIL" in dc_text:
            break
        time.sleep(5)
    if "CMR_SYNC64_DC_PASS" not in dc_text:
        print(dc_text[-16000:], flush=True)
        raise RuntimeError("CMR sync NoC64 DC failed")
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
        "mode": "sdf",
        "tb_pass": "TB_RESULT PASS" in run_log,
        "x_failure": "TB_X_FAIL" in run_log or "TB_PROTOCOL_X" in run_log,
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


def submit_gls(client, run_id, netlist_run_id, name, case_path):
    wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (run_id, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_SYNC64_RUN_ID=%s "
        "CMR_SYNC64_NETLIST_RUN_ID=%s CMR_SYNC64_CASE_NAME=%s "
        "CMR_SYNC64_CASE_FILE=%s CMR_SYNC64_GLS_MODE=sdf "
        "CMR_SYNC64_CLOCK_PERIOD_NS=%s CMR_SYNC64_RX_CAPTURE_NS=%s "
        "CMR_SYNC64_INJECT_MAX_RATE=%s CMR_SYNC64_SIM_ARGS=%s "
        "CMR_SYNC64_TOP_LANES=%s\n"
        "exec bash %s/scripts/run_gls_cmr_sync_noc64.sh\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(netlist_run_id),
            shlex.quote(name),
            shlex.quote(case_path),
            shlex.quote(CLOCK_PERIOD_NS),
            shlex.quote(SDF_RX_CAPTURE_NS),
            "1" if INJECT_MAX_RATE else "0",
            shlex.quote(SIM_ARGS),
            shlex.quote(CASE_TOP_LANES),
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
        "bsub %s -o %s/logs/gls/%s/sdf_%s.bsub.log "
        "-e %s/logs/gls/%s/sdf_%s.bsub.err -J cmr_sync64_sdf_%s %s"
        % (
            GLS_BSUB, ROOT, run_id, name,
            ROOT, run_id, name,
            name, wrapper,
        ),
    )
    jid = job_id(submit)
    print("GLS_JOB sdf", name, jid, flush=True)
    client = wait_job(client, jid, "sdf_%s" % name, polls=GLS_POLLS, allow_exit=True)
    client, entry, passed = collect_gls_result(client, run_id, name, jid)
    print("GLS_CASE sdf", name, "PASS" if passed else "FAIL", entry.get("result_line"), flush=True)
    return client, entry, passed


def main():
    if os.environ.get("CMR_NOC16_NETLIST_RUN_ID"):
        print(
            "WARN ignoring CMR_NOC16_NETLIST_RUN_ID=%s; sync NoC64 always synthesizes "
            "unless CMR_SYNC64_NETLIST_RUN_ID is set"
            % os.environ["CMR_NOC16_NETLIST_RUN_ID"],
            flush=True,
        )
    unknown = [name for name in CASES if name not in ALLOWED_CASES]
    if unknown:
        raise SystemExit("unsupported sync NoC64 cases: " + ",".join(unknown))
    if not CASES:
        raise SystemExit("CMR_SYNC64_CASES is empty")

    run_id = BASE_RUN_ID
    refuse_overwrite(run_id, action="sync64")
    skip_dc = bool(NETLIST_RUN_ID_ENV)
    netlist_run_id = NETLIST_RUN_ID_ENV or run_id
    if PROFILE == "fat1222" and (
        run_id == SIGNED_THIN_RUN_ID or netlist_run_id == SIGNED_THIN_RUN_ID
    ):
        raise SystemExit(
            "Fat 1-2-2-2 must not reuse or overwrite signed Thin netlist "
            + SIGNED_THIN_RUN_ID
        )
    if PROFILE == "thin" and (
        run_id == SIGNED_FAT1222_RUN_ID or netlist_run_id == SIGNED_FAT1222_RUN_ID
    ):
        raise SystemExit(
            "Thin must not reuse or overwrite signed Fat 1-2-2-2 netlist "
            + SIGNED_FAT1222_RUN_ID
        )
    if not skip_dc:
        refuse_overwrite(netlist_run_id, action="sync64-dc")

    print(
        "SYNC64_LAUNCH profile=%s cases=%s clock=%sns top=%s skip_gls=%s"
        % (
            PROFILE,
            ",".join(CASES),
            CLOCK_PERIOD_NS,
            CASE_TOP_LANES,
            "1" if SKIP_GLS else "0",
        ),
        flush=True,
    )
    case_files = generate_cases()
    generated = generate_rtl()

    files = shared_input_files()
    files[generated / "SyncNoC_64nodes.v"] = RTL_REMOTE_DIR + "/SyncNoC_64nodes.v"
    dut_remote = ROOT + "/" + RTL_REMOTE_DIR + "/SyncNoC_64nodes.v"
    result_dir = RESULT_ROOT / run_id

    client = connect()
    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/%s %s/scripts/dc %s/sim/tb %s/sim/cases_noc64 "
        "%s/outputs %s/reports/dc %s/logs/dc %s/logs/gls %s/results/%s/csv %s/work"
        % (
            ROOT,
            RTL_REMOTE_DIR,
            ROOT,
            ROOT,
            ROOT,
            ROOT,
            ROOT,
            ROOT,
            ROOT,
            ROOT,
            run_id,
            ROOT,
        ),
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
        dest = "sim/cases_noc64/" + name + ".case"
        print("UPLOAD", dest, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        case_hashes[name] = digest
        remote_cases[name] = ROOT + "/" + dest
    sftp.close()
    remote_run(
        client,
        "chmod +x %s/scripts/run_gls_cmr_sync_noc64.sh; "
        "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_sync_noc64.sh "
        "%s/scripts/dc/run_dc_cmr_sync_fat_tree_noc64.tcl "
        "%s/rtl/sync_cmr_noc64.sdc "
        "%s/sim/tb/tb_noc64_sync_boundary.sv "
        "%s/sim/tb/tb_cmr_noc64_sync_boundary_failfast.sv "
        "%s/sim/tb/sync_noc64_port_adapter.sv"
        % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT),
    )

    dc_job = None
    dc_log = ROOT + "/logs/dc/" + run_id + ".log"
    if skip_dc:
        print("SKIP_DC netlist_run_id=%s" % netlist_run_id, flush=True)
        client = reconnect(client)
        client, probe = remote_run_retry(
            client,
            "test -s %s/outputs/%s/SyncNoC_64nodes_post.v && "
            "test -s %s/outputs/%s/SyncNoC_64nodes.sdf && echo OK"
            % (ROOT, netlist_run_id, ROOT, netlist_run_id),
        )
        if "OK" not in probe:
            raise RuntimeError("frozen sync NoC64 netlist missing for %s: %s" % (netlist_run_id, probe))
    else:
        client, existing_log = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_SYNC64_DC_PASS" in existing_log:
            print("REUSE_DC_PASS", run_id, flush=True)
        else:
            client, job_text = remote_run_retry(
                client,
                "bjobs -J %s -noheader -o 'jobid stat' 2>/dev/null"
                % shlex.quote("cmr_sync64_dc_%s" % run_id),
            )
            job_match = re.search(r"(\d+)\s+(PEND|RUN)", job_text)
            if job_match:
                dc_job = job_match.group(1)
                print("REUSE_DC_JOB", dc_job, job_match.group(2), flush=True)
                client = wait_job(client, dc_job, "dc_sync64", polls=DC_POLLS, allow_exit=True)
                client = wait_dc_marker(client, dc_log)
            else:
                dc_wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
                dc_body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "module load syn 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_SYNC64_RUN_ID=%s "
                    "CMR_SYNC64_DUT_V=%s CMR_SYNC64_CLOCK_PERIOD_NS=%s "
                    "CMR_EXPECTED_ROUTERS=%d CMR_EXPECTED_PORTS=%d "
                    "CMR_EXPECTED_SELECTORS=%d\n"
                    "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_sync_fat_tree_noc64.tcl\n"
                    % (
                        ROOT,
                        shlex.quote(run_id),
                        shlex.quote(dut_remote),
                        shlex.quote(CLOCK_PERIOD_NS),
                        EXPECTED_ROUTERS,
                        EXPECTED_PORTS,
                        EXPECTED_SELECTORS,
                        ROOT,
                        ROOT,
                    )
                )
                sftp = client.open_sftp()
                atomic_put_bytes(client, sftp, dc_body.encode(), dc_wrapper)
                sftp.close()
                client, _ = remote_run_retry(client, "chmod +x %s" % dc_wrapper)
                client, dc_submit = remote_run_retry(
                    client,
                    "bsub %s -o %s -e %s.err -J cmr_sync64_dc_%s %s"
                    % (DC_BSUB, dc_log, dc_log, run_id, dc_wrapper),
                )
                dc_job = job_id(dc_submit)
                print("DC_JOB", dc_job, flush=True)
                client = wait_job(client, dc_job, "dc_sync64", polls=DC_POLLS, allow_exit=True)
                client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": run_id,
        "profile": PROFILE,
        "geometry": GEOMETRY,
        "top_lanes": EXPECTED_TOP,
        "expected_ports": EXPECTED_PORTS,
        "expected_selectors": EXPECTED_SELECTORS,
        "clock_period_ns": CLOCK_PERIOD_NS,
        "sdf_rx_capture_ns": SDF_RX_CAPTURE_NS,
        "inject_max_rate": INJECT_MAX_RATE,
        "case_hashes": case_hashes,
        "upload_hashes": upload_hashes,
        "dc_job": dc_job,
        "netlist_run_id": netlist_run_id,
        "sdf_cases": {},
        "all_pass": True,
    }

    if not SKIP_GLS:
        client = reconnect(client)
        for index, name in enumerate(CASES):
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, name, remote_cases[name]
            )
            status["sdf_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                print("SDF_FAIL stop sync64 case=%s" % name, flush=True)
                for skipped in CASES[index + 1:]:
                    status["sdf_cases"][skipped] = {
                        "skipped": True,
                        "reason": "previous sdf failed: " + name,
                    }
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
    client.close()
    print("LOCAL_RESULT", result_dir, "PASS" if status["all_pass"] else "FAIL", flush=True)
    print("SYNC64_SUMMARY", result_dir, "PASS" if status["all_pass"] else "FAIL", flush=True)
    if not status["all_pass"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
