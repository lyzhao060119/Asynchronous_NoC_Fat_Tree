#!/usr/bin/env python3
"""Remote DC + SDF GLS for 64-core CMR fat-tree.

Profiles (CMR_FAT_LANE_PROFILE or CMR_Q64_PROFILE):
  1222  L1 1->2, L2/L3 2->2, two top lanes (default)
  1248  L1 1->2, L2 2->4, L3 4->8, eight top lanes
  thin  L1/L2/L3 1->1, one top lane.  Emit sets CMR_Q64_PROFILE=thin;
        do not set CMR_FAT_LANE_PROFILE=thin on the Scala fat-lane parser.

Does not reuse NoC16 netlists.  Unset CMR_NOC16_NETLIST_RUN_ID.
GLS is MAXIMUM SDF only (no cmr_func patch), RX_CAPTURE=0.1 ns.
Functional GLS is opt-in via CMR_NOC64_SKIP_FUNC=0.
Delay default is RCU 1xDEL050 / Ackin 1xDEL050.  The signed network
netlist 20260830_095259_cmr_noc64_p50_1222 is Ackin DEL250: SKIP_DC it,
do not overwrite it, and do not cite it as Fat vs Thin hop delay.

DATE V3 5-flit cases are opt-in: CMR_NOC64_ALLOW_V3=1 and
CMR_NOC64_V3_CASE_DIR pointing at materialized .case files.  Do not add
V3 names to the 3-flit ALLOWED_CASES list.  CMR_DESCAL=1 refuses the
Ackin-250 netlist unless CMR_NOC64_ALLOW_ACKIN250=1.  1-2-4-8 and thin
network GLS are allowed on the DES-cal path.
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
from cmr_descal_env import apply_bsub, submit_only
from cmr_frozen_run_ids import refuse_overwrite, require_emit_locked_delays
from run_remote_cmr_flow import atomic_put_bytes, remote_run
from run_remote_cmr_fat_tree_noc16_sdf import (
    CIRCULAR_RTL,
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
    "CMR_NOC64_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_noc64_p50",
)
NETLIST_RUN_ID_ENV = os.environ.get("CMR_NOC64_NETLIST_RUN_ID", "").strip()
DEFAULT_CASES = ("TAB-NET-UR-3f-r0p50",)
SMOKE_CASES = (
    "noc64_00_to_10_3flit",
    "noc64_00_to_20_3flit",
    "noc64_00_to_40_3flit",
    "noc64_00_to_77_3flit",
)
VCTM_CASES = ("VCTM-MC5-NM-3f-r0p50",)
ALLOWED_CASES = DEFAULT_CASES + SMOKE_CASES + VCTM_CASES
CASES = tuple(
    name for name in os.environ.get("CMR_NOC64_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
FUNC_CASES = tuple(
    name
    for name in os.environ.get(
        "CMR_NOC64_FUNC_CASES",
        "noc64_00_to_77_3flit," + ",".join(CASES),
    ).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_NOC64_SKIP_GLS", "0") == "1"
SKIP_FUNC = os.environ.get("CMR_NOC64_SKIP_FUNC", "1") == "1"
SKIP_SDF = os.environ.get("CMR_NOC64_SKIP_SDF", "0") == "1"
ALLOW_V3 = os.environ.get("CMR_NOC64_ALLOW_V3", "0") == "1"
V3_CASE_DIR = Path(os.environ["CMR_NOC64_V3_CASE_DIR"]) if os.environ.get("CMR_NOC64_V3_CASE_DIR") else None
DESCAL = os.environ.get("CMR_DESCAL", "0") == "1"
INJECT_MAX_RATE = os.environ.get("CMR_NOC64_INJECT_MAX_RATE", "0") == "1"
SIM_ARGS = os.environ.get("CMR_NOC64_SIM_ARGS", "")
SDF_RX_CAPTURE_NS = os.environ.get("CMR_NOC64_RX_CAPTURE_NS", "0.1")
FUNC_RX_CAPTURE_NS = os.environ.get("CMR_NOC64_FUNC_RX_CAPTURE_NS", "5")
USE_CIRCULAR_FIFO = os.environ.get("CMR_USE_CIRCULAR_FIFO", "0") == "1"
BYPASS_INTERLEVEL_FIFO = os.environ.get("CMR_BYPASS_INTERLEVEL_FIFO", "1") == "1"
if BYPASS_INTERLEVEL_FIFO:
    USE_CIRCULAR_FIFO = False
LANE01_STAGES = os.environ.get("CMR_LANE01_BUF_STAGES", "0").strip() or "0"
RCU_STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
RCU_UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
DC_POLLS = int(os.environ.get("CMR_NOC64_DC_POLLS", "1440"))
GLS_POLLS = int(os.environ.get("CMR_NOC64_GLS_POLLS", "720"))
DC_BSUB = apply_bsub(os.environ.get("CMR_NOC64_DC_BSUB", "-n 16"))
GLS_BSUB = apply_bsub(os.environ.get("CMR_NOC64_GLS_BSUB", "-n 8"))
SUBMIT_ONLY = submit_only()
EXPECTED_ROUTERS = 21
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"

PROFILES = {
    "1222": {
        "geometry": "fat_tree_noc64_l1_1to2_l2_2to2_l3_2to2",
        "top_lanes": 2,
        "expected_ports": 146,
        "expected_adapters": 264,
        "expected_fifos_if_enabled": 80,
    },
    "1248": {
        "geometry": "fat_tree_noc64_l1_1to2_l2_2to4_l3_4to8",
        "top_lanes": 8,
        "expected_ports": 168,
        "expected_adapters": 352,
        "expected_fifos_if_enabled": 96,
    },
    "thin": {
        "geometry": "fat_tree_noc64_l1_1to1_l2_1to1_l3_1to1",
        "top_lanes": 1,
        "expected_ports": 105,
        "expected_adapters": 0,
        "expected_fifos_if_enabled": 80,
    },
}


def selected_profiles() -> tuple[str, ...]:
    raw = (
        os.environ.get("CMR_FAT_LANE_PROFILE")
        or os.environ.get("CMR_Q64_PROFILE")
        or "1222"
    )
    raw = raw.strip().lower()
    raw = raw.replace("-", "").replace("_", "")
    if raw in ("both", "all", "1248,1222", "1222,1248"):
        return ("1222", "1248")
    if raw in ("1222", "fatlane1222"):
        return ("1222",)
    if raw in ("1248", "fatlane1248", "pfat"):
        return ("1248",)
    if raw in ("thin", "111", "1111", "thin111"):
        return ("thin",)
    raise SystemExit(
        "CMR_FAT_LANE_PROFILE / CMR_Q64_PROFILE must be 1222, 1248, thin, or both; got %r"
        % raw
    )


def _dc_job_name(run_id: str) -> str:
    if DESCAL:
        return "cmr_descal_noc64_dc_%s" % run_id
    return "cmr_noc64_dc_%s" % run_id


def _gls_job_name(profile: str, mode: str, name: str) -> str:
    if DESCAL:
        return "cmr_descal_noc64_%s_%s_%s" % (profile, mode, name)
    return "cmr_noc64_%s_%s_%s" % (profile, mode, name)


def case_local_path(name: str) -> Path:
    if ALLOW_V3 and V3_CASE_DIR is not None:
        candidate = V3_CASE_DIR / (name + ".case")
        if candidate.is_file():
            return candidate
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
    raise SystemExit("unknown NoC64 case " + name)


def generate_cases(top_lanes: int = 2, needed: tuple[str, ...] | None = None) -> dict[str, Path]:
    needed = needed or tuple(dict.fromkeys(FUNC_CASES + CASES))
    if ALLOW_V3:
        paths = {}
        for name in needed:
            path = case_local_path(name)
            if not path.is_file():
                raise SystemExit("missing V3 NoC64 case " + str(path))
            paths[name] = path
            print("LOCAL_CASE", name, path, flush=True)
        adapter = REPO / "sim" / "AsyncNoC" / "async_noc64_port_adapter.sv"
        if not adapter.is_file():
            subprocess.run(
                [
                    sys.executable,
                    str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_noc64_port_adapter.py"),
                ],
                cwd=REPO,
                check=True,
            )
        return paths
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
                "--top-lanes", str(top_lanes),
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
                "--top-lanes", str(top_lanes),
            ],
            cwd=REPO,
            check=True,
        )
    adapter = REPO / "sim" / "AsyncNoC" / "async_noc64_port_adapter.sv"
    if not adapter.is_file():
        subprocess.run(
            [
                sys.executable,
                str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_noc64_port_adapter.py"),
            ],
            cwd=REPO,
            check=True,
        )
    paths = {}
    for name in needed:
        path = case_local_path(name)
        if not path.is_file():
            raise SystemExit("missing NoC64 case " + str(path))
        paths[name] = path
        print("LOCAL_CASE", name, path, flush=True)
    return paths


def _check_generated(generated: Path, profile: str) -> Path:
    cfg = PROFILES[profile]
    rtl = generated / "NoC_64nodes.v"
    if not rtl.is_file():
        raise SystemExit("missing generated NoC64: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+routers?L", text, re.M))
    async_count = len(re.findall(r"^\s+AsyncFifo(?:_\d+)?\s+(?:upward|downward)", text, re.M))
    circular_count = len(re.findall(r"^\s+CircularFifo(?:_\d+)?\s+(?:upward|downward)", text, re.M))
    ipm_count = len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    adapter_count = len(re.findall(r"LanePhaseAdapter\s*#\s*\(\s*\.\s*LANES\s*\(\s*\d+\s*\)", text))
    top_ports = len(set(re.findall(r"io_top_input_(\d+)_", text)))
    expected_fifos = 0 if BYPASS_INTERLEVEL_FIFO else cfg["expected_fifos_if_enabled"]
    if "module NoC_64nodes" not in text:
        raise SystemExit("generated DUT is not named NoC_64nodes")
    if router_count != EXPECTED_ROUTERS:
        raise SystemExit("NoC64 router count %d != %d" % (router_count, EXPECTED_ROUTERS))
    if ipm_count != cfg["expected_ports"]:
        raise SystemExit("NoC64 IPM count %d != %d" % (ipm_count, cfg["expected_ports"]))
    if adapter_count != cfg["expected_adapters"]:
        raise SystemExit("NoC64 adapter count %d != %d" % (adapter_count, cfg["expected_adapters"]))
    if top_ports != cfg["top_lanes"]:
        raise SystemExit("NoC64 top ports %d != %d" % (top_ports, cfg["top_lanes"]))
    require_emit_locked_delays(text, label="NoC64", ackin_unit_ps=int(ACKIN_UNIT_PS))
    if BYPASS_INTERLEVEL_FIFO and (async_count or circular_count):
        raise SystemExit(
            "NoC64 bypass expected no FIFO got async=%d circular=%d"
            % (async_count, circular_count)
        )
    if (not BYPASS_INTERLEVEL_FIFO) and (async_count + circular_count) != expected_fifos:
        raise SystemExit(
            "NoC64 FIFO count async=%d circular=%d expected=%d"
            % (async_count, circular_count, expected_fifos)
        )
    check_noc64(generated, "fat_tree_noc64_" + profile)
    print(
        "LOCAL_EMIT profile=%s router=%d ipm=%d adapter=%d fifo_async=%d fifo_circ=%d top=%d"
        % (profile, router_count, ipm_count, adapter_count, async_count, circular_count, top_ports),
        flush=True,
    )
    return generated


def generate_rtl(profile: str) -> Path:
    generated = REPO / "generated_cmr" / ("fat_tree_noc64_" + profile)
    rtl = generated / "NoC_64nodes.v"
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1"
    if rtl.is_file() and not force_emit:
        try:
            return _check_generated(generated, profile)
        except SystemExit as exc:
            print("LOCAL_EMIT_RECHECK", exc, flush=True)
    env = os.environ.copy()
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_FORCE_EMIT"] = "1"
    env["CMR_Q64_PROFILE"] = profile
    if profile == "thin":
        env.pop("CMR_FAT_LANE_PROFILE", None)
    else:
        env["CMR_FAT_LANE_PROFILE"] = profile
    env["CMR_USE_CIRCULAR_FIFO"] = "1" if USE_CIRCULAR_FIFO else "0"
    env["CMR_BYPASS_INTERLEVEL_FIFO"] = "1" if BYPASS_INTERLEVEL_FIFO else "0"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = str(RCU_STEPS)
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = str(RCU_UNIT_PS)
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = str(ACKIN_UNIT_PS)
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    print("FAT64_EMIT profile=%s bypass=%s" % (profile, "1" if BYPASS_INTERLEVEL_FIFO else "0"), flush=True)
    subprocess.run(
        [sbt, "runMain NoC.CMR.CMRFatTreeNoC64Main"],
        cwd=REPO,
        env=env,
        check=True,
    )
    return _check_generated(generated, profile)


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
        "LanePhaseAdapter.v",
        "WriteControlUnit.v",
        "WriteCounter.v",
        "WriteAckGenerator.v",
        "ReadControlUnit.v",
        "ReadCounter.v",
        "ReadRequestGenerator.v",
        "ReadPhaseSelector.v",
        "ReadAckGenerator.v",
    ) + CIRCULAR_RTL:
        files[cmr_resource / name] = "rtl/" + name
    files.update({
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_fat_tree_noc64.tcl":
            "scripts/dc/run_dc_cmr_fat_tree_noc64.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc64.sh":
            "scripts/run_gls_cmr_noc64.sh",
        REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py":
            "scripts/patch_gls_netlist.py",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc64_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv":
            "sim/tb/tb_noc64_async_boundary.sv",
        REPO / "sim/AsyncNoC/async_noc64_port_adapter.sv":
            "sim/tb/async_noc64_port_adapter.sv",
    })
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing NoC64 input files: " + ", ".join(missing))
    return files


def wait_dc_marker(client, dc_log):
    dc_text = ""
    for _ in range(12):
        client, dc_text = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_NOC64_DC_PASS" in dc_text or "CMR_NOC64_DC_FAIL" in dc_text:
            break
        time.sleep(5)
    if "CMR_NOC64_DC_PASS" not in dc_text:
        print(dc_text[-16000:], flush=True)
        raise RuntimeError("CMR fat-tree NoC64 DC failed")
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


def submit_gls(client, run_id, netlist_run_id, profile, mode, name, case_path, rx_capture, dep_job=None):
    wrapper = ROOT + "/logs/gls/%s/%s_%s.sh" % (run_id, mode, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC64_RUN_ID=%s "
        "CMR_NOC64_NETLIST_RUN_ID=%s CMR_NOC64_CASE_NAME=%s "
        "CMR_NOC64_CASE_FILE=%s CMR_NOC64_GLS_MODE=%s "
        "CMR_FAT_LANE_PROFILE=%s CMR_NOC64_RX_CAPTURE_NS=%s "
        "CMR_NOC64_INJECT_MAX_RATE=%s CMR_NOC64_SIM_ARGS=%s\n"
        "exec bash %s/scripts/run_gls_cmr_noc64.sh\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(netlist_run_id),
            shlex.quote(name),
            shlex.quote(case_path),
            shlex.quote(mode),
            shlex.quote(profile),
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
    dep = ("-w %s " % shlex.quote("done(%s)" % dep_job)) if dep_job else ""
    client, submit = remote_run_retry(
        client,
        "bsub %s %s-o %s/logs/gls/%s/%s_%s.bsub.log "
        "-e %s/logs/gls/%s/%s_%s.bsub.err -J %s %s"
        % (
            GLS_BSUB, dep, ROOT, run_id, mode, name,
            ROOT, run_id, mode, name,
            _gls_job_name(profile, mode, name), wrapper,
        ),
    )
    jid = job_id(submit)
    print("GLS_JOB", profile, mode, name, jid, flush=True)
    if SUBMIT_ONLY:
        return client, {"job_id": jid, "mode": mode, "submitted": True}, True
    client = wait_job(client, jid, "%s_%s_%s" % (profile, mode, name), polls=GLS_POLLS, allow_exit=True)
    client, entry, passed = collect_gls_result(client, run_id, mode, name, jid)
    print(
        "GLS_CASE", profile, mode, name, "PASS" if passed else "FAIL", entry.get("result_line"),
        flush=True,
    )
    return client, entry, passed


def run_profile(client, profile: str, case_files: dict[str, Path], upload_shared: bool) -> dict:
    cfg = PROFILES[profile]
    run_id = BASE_RUN_ID + "_" + profile
    result_dir = RESULT_ROOT / run_id
    skip_dc = bool(NETLIST_RUN_ID_ENV)
    netlist_run_id = NETLIST_RUN_ID_ENV or run_id
    refuse_overwrite(run_id, action="noc64")
    if not skip_dc:
        refuse_overwrite(netlist_run_id, action="noc64-dc")
    generated = generate_rtl(profile)
    files = shared_input_files()
    files[generated / "NoC_64nodes.v"] = "rtl/noc64_%s/NoC_64nodes.v" % profile
    dut_remote = ROOT + "/rtl/noc64_%s/NoC_64nodes.v" % profile
    expected_fifos = 0 if BYPASS_INTERLEVEL_FIFO else cfg["expected_fifos_if_enabled"]

    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/rtl/noc64_%s %s/scripts/dc %s/sim/tb %s/sim/cases_noc64 "
        "%s/outputs %s/reports/dc %s/logs/dc %s/logs/gls %s/results/%s/csv %s/work"
        % (ROOT, profile, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, run_id, ROOT),
    )

    upload_hashes = {}
    sftp = client.open_sftp()
    upload_list = dict(files) if upload_shared else {
        generated / "NoC_64nodes.v": "rtl/noc64_%s/NoC_64nodes.v" % profile,
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_fat_tree_noc64.tcl":
            "scripts/dc/run_dc_cmr_fat_tree_noc64.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc64.sh":
            "scripts/run_gls_cmr_noc64.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc64_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv":
            "sim/tb/tb_noc64_async_boundary.sv",
        REPO / "sim/AsyncNoC/async_noc64_port_adapter.sv":
            "sim/tb/async_noc64_port_adapter.sv",
    }
    for source, destination in upload_list.items():
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
        "chmod +x %s/scripts/run_gls_cmr_noc64.sh; "
        "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_noc64.sh "
        "%s/scripts/dc/run_dc_cmr_fat_tree_noc64.tcl "
        "%s/sim/tb/tb_noc64_async_boundary.sv "
        "%s/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv "
        "%s/sim/tb/async_noc64_port_adapter.sv "
        "%s/scripts/patch_gls_netlist.py"
        % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT),
    )

    dc_job = None
    dc_log = ROOT + "/logs/dc/" + run_id + ".log"
    if skip_dc:
        print("SKIP_DC netlist_run_id=%s profile=%s" % (netlist_run_id, profile), flush=True)
        client = reconnect(client)
        client, probe = remote_run_retry(
            client,
            "test -s %s/outputs/%s/NoC_64nodes_post.v && "
            "test -s %s/outputs/%s/NoC_64nodes.sdf && echo OK"
            % (ROOT, netlist_run_id, ROOT, netlist_run_id),
        )
        if "OK" not in probe:
            raise RuntimeError("frozen NoC64 netlist missing for %s: %s" % (netlist_run_id, probe))
    else:
        client, existing_log = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_NOC64_DC_PASS" in existing_log:
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
                    print("SUBMIT_ONLY reuse_dc=%s profile=%s" % (dc_job, profile), flush=True)
                else:
                    client = wait_job(client, dc_job, "dc_" + profile, polls=DC_POLLS)
                    client = wait_dc_marker(client, dc_log)
            else:
                dc_wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
                dc_body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "module load syn 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_NOC64_RUN_ID=%s "
                    "CMR_NOC64_DUT_V=%s CMR_FAT_LANE_PROFILE=%s "
                    "CMR_LANE01_BUF_STAGES=%s CMR_EXPECTED_ADAPTERS=%d "
                    "CMR_EXPECTED_PORTS=%d CMR_EXPECTED_FIFOS=%d "
                    "CMR_RCU_MATCHED_DELAY_STEPS=%s CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
                    "CMR_OPM_ACKIN_DELAY_UNIT_PS=%s CMR_BYPASS_INTERLEVEL_FIFO=%s\n"
                    "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_fat_tree_noc64.tcl\n"
                    % (
                        ROOT,
                        shlex.quote(run_id),
                        shlex.quote(dut_remote),
                        shlex.quote(profile),
                        shlex.quote(LANE01_STAGES),
                        cfg["expected_adapters"],
                        cfg["expected_ports"],
                        expected_fifos,
                        shlex.quote(str(RCU_STEPS)),
                        shlex.quote(str(RCU_UNIT_PS)),
                        shlex.quote(str(ACKIN_UNIT_PS)),
                        "1" if BYPASS_INTERLEVEL_FIFO else "0",
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
                    "bsub %s -o %s -e %s.err -J %s %s"
                    % (DC_BSUB, dc_log, dc_log, _dc_job_name(run_id), dc_wrapper),
                )
                dc_job = job_id(dc_submit)
                print("DC_JOB", profile, dc_job, flush=True)
                if SUBMIT_ONLY:
                    print("SUBMIT_ONLY dc=%s profile=%s" % (dc_job, profile), flush=True)
                else:
                    client = wait_job(client, dc_job, "dc_" + profile, polls=DC_POLLS)
                    client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": run_id,
        "profile": profile,
        "geometry": cfg["geometry"],
        "top_lanes": cfg["top_lanes"],
        "expected_ports": cfg["expected_ports"],
        "expected_adapters": cfg["expected_adapters"],
        "bypass_interlevel_fifo": BYPASS_INTERLEVEL_FIFO,
        "circular_fifo": USE_CIRCULAR_FIFO,
        "lane01_buf_stages": int(LANE01_STAGES),
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
    gls_dep = _dc_job_name(run_id) if (SUBMIT_ONLY and not skip_dc and dc_job is not None) else None

    def skip_remaining(bucket, remaining, reason):
        for skipped in remaining:
            status[bucket][skipped] = {"skipped": True, "reason": reason}

    if not SKIP_GLS and not SKIP_FUNC:
        client = reconnect(client)
        for index, name in enumerate(FUNC_CASES):
            if name not in remote_cases:
                raise RuntimeError("missing uploaded func case " + name)
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, profile, "func",
                name, remote_cases[name], FUNC_RX_CAPTURE_NS, dep_job=gls_dep,
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
                        client, run_id, netlist_run_id, profile, "sdf",
                        name, remote_cases[name], SDF_RX_CAPTURE_NS, dep_job=gls_dep,
                    )
                    status["sdf_cases"][name] = entry
                    if not passed:
                        status["all_pass"] = False
                        skip_remaining("sdf_cases", CASES[index + 1:], "previous sdf failed: " + name)
                        print(
                            "SDF_FAIL stop Mutex unchanged profile=%s case=%s"
                            % (profile, name),
                            flush=True,
                        )
                        break
    elif not SKIP_GLS and SKIP_FUNC and not SKIP_SDF:
        client = reconnect(client)
        for index, name in enumerate(CASES):
            client, entry, passed = submit_gls(
                client, run_id, netlist_run_id, profile, "sdf",
                name, remote_cases[name], SDF_RX_CAPTURE_NS, dep_job=gls_dep,
            )
            status["sdf_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                print(
                    "SDF_FAIL continue profile=%s case=%s remaining=%s"
                    % (profile, name, ",".join(CASES[index + 1:])),
                    flush=True,
                )
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
    from cmr_frozen_run_ids import FROZEN_NOC64_ACKIN250_RUN_ID, refuse_overwrite

    if os.environ.get("CMR_NOC16_NETLIST_RUN_ID"):
        print(
            "WARN ignoring CMR_NOC16_NETLIST_RUN_ID=%s; NoC64 always synthesizes "
            "unless CMR_NOC64_NETLIST_RUN_ID is set"
            % os.environ["CMR_NOC16_NETLIST_RUN_ID"],
            flush=True,
        )
    global FUNC_CASES
    if ALLOW_V3:
        if V3_CASE_DIR is None or not V3_CASE_DIR.is_dir():
            raise SystemExit("CMR_NOC64_ALLOW_V3=1 requires CMR_NOC64_V3_CASE_DIR")
        if SKIP_FUNC:
            FUNC_CASES = tuple(name for name in FUNC_CASES if name in CASES)
    else:
        unknown = [name for name in dict.fromkeys(FUNC_CASES + CASES) if name not in ALLOWED_CASES]
        if unknown:
            raise SystemExit("unsupported NoC64 cases: " + ",".join(unknown))
    if DESCAL:
        refuse_overwrite(BASE_RUN_ID, action="descal-gls")
        if (
            NETLIST_RUN_ID_ENV == FROZEN_NOC64_ACKIN250_RUN_ID
            and os.environ.get("CMR_NOC64_ALLOW_ACKIN250", "0") != "1"
        ):
            raise SystemExit(
                "DES cal refuses Ackin-250 netlist %s; timing cal needs a new DEL050 ID"
                % NETLIST_RUN_ID_ENV
            )
    if not CASES:
        raise SystemExit("CMR_NOC64_CASES is empty")
    if int(LANE01_STAGES) < 0:
        raise SystemExit("CMR_LANE01_BUF_STAGES must be >=0")
    profiles = selected_profiles()
    print(
        "NOC64_LAUNCH profiles=%s cases=%s func_cases=%s bypass=%s rx_sdf=%s rx_func=%s"
        % (
            ",".join(profiles),
            ",".join(CASES),
            ",".join(FUNC_CASES),
            "1" if BYPASS_INTERLEVEL_FIFO else "0",
            SDF_RX_CAPTURE_NS,
            FUNC_RX_CAPTURE_NS,
        ),
        flush=True,
    )
    case_files = generate_cases(PROFILES[profiles[0]]["top_lanes"] if len(profiles) == 1 else 2)
    client = connect()
    summaries = []
    all_pass = True
    for index, profile in enumerate(profiles):
        status = run_profile(client, profile, case_files, upload_shared=(index == 0))
        summaries.append(status)
        all_pass = all_pass and status["all_pass"]
        client = reconnect(client)
    combined = RESULT_ROOT / BASE_RUN_ID
    combined.mkdir(parents=True, exist_ok=True)
    (combined / "summary.json").write_text(
        json.dumps({"run_id": BASE_RUN_ID, "profiles": summaries, "all_pass": all_pass}, indent=2)
        + "\n",
        encoding="utf-8",
    )
    client.close()
    print("NOC64_SUMMARY", combined, "PASS" if all_pass else "FAIL", flush=True)
    if not all_pass:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
