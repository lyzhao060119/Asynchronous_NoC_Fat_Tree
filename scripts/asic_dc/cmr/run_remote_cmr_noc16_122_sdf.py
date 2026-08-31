#!/usr/bin/env python3
"""Remote DC + SDF GLS for 16-core Fat 1-2-2 (L1 1->2, L2 2->2).

Does not overwrite the 1-2-4 NoC16 netlist.  DUT is uploaded to
rtl/noc16_122/NoC_16nodes.v.  GLS matches the proven 1-2-4 fat-tree
flow: MAXIMUM SDF only (no cmr_func patch), RX_CAPTURE=5 ns,
sixteen depth-3 AsyncFifo links.  Functional GLS is opt-in via
CMR_NOC16_SKIP_FUNC=0.  Delay default is the locked hop recipe
(RCU 1xDEL050, Ackin 1xDEL050).  Ackin 250 is a predecessor, not the
Fat vs Thin delay number.
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
ULTRA_ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_noc16_122_p50",
)
NETLIST_RUN_ID = os.environ.get("CMR_NOC16_NETLIST_RUN_ID", "").strip()
DEFAULT_CASES = ("TAB-NET-UR-3f-r0p50",)
SMOKE_CASES = ("noc16_00_to_33_3flit_sdf",)
ALLOWED_CASES = DEFAULT_CASES + SMOKE_CASES
CASES = tuple(
    name for name in os.environ.get("CMR_NOC16_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
FUNC_CASES = tuple(
    name
    for name in os.environ.get(
        "CMR_NOC16_FUNC_CASES",
        "noc16_00_to_33_3flit_sdf," + ",".join(CASES),
    ).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_NOC16_SKIP_GLS", "0") == "1"
SKIP_FUNC = os.environ.get("CMR_NOC16_SKIP_FUNC", "1") == "1"
SKIP_SDF = os.environ.get("CMR_NOC16_SKIP_SDF", "0") == "1"
INJECT_MAX_RATE = os.environ.get("CMR_NOC16_INJECT_MAX_RATE", "0") == "1"
SIM_ARGS = os.environ.get("CMR_NOC16_SIM_ARGS", "")
SDF_RX_CAPTURE_NS = os.environ.get("CMR_NOC16_RX_CAPTURE_NS", "5")
FUNC_RX_CAPTURE_NS = os.environ.get("CMR_NOC16_FUNC_RX_CAPTURE_NS", "5")
BYPASS_INTERLEVEL_FIFO = os.environ.get("CMR_BYPASS_INTERLEVEL_FIFO", "0") == "1"
LANE01_STAGES = os.environ.get("CMR_LANE01_BUF_STAGES", "0").strip() or "0"
RCU_STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
RCU_UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
DC_POLLS = int(os.environ.get("CMR_NOC16_DC_POLLS", "480"))
GLS_POLLS = int(os.environ.get("CMR_NOC16_GLS_POLLS", "480"))
DC_BSUB = os.environ.get("CMR_NOC16_DC_BSUB", "-n 8")
GLS_BSUB = os.environ.get("CMR_NOC16_GLS_BSUB", "-n 8")
EXPECTED_ROUTERS = 5
EXPECTED_PORTS = 34
EXPECTED_ADAPTERS = 16 + 40
EXPECTED_FIFOS = 0 if BYPASS_INTERLEVEL_FIFO else 16
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def case_local_path(name: str) -> Path | None:
    if name in SMOKE_CASES:
        return REPO / "sim" / "AsyncNoC" / "testbench" / "small_cases" / (name + ".case")
    return None


def generate_adapter() -> Path:
    script = REPO / "sim" / "AsyncNoC" / "testbench" / "gen_noc16_port_adapter_top2.py"
    subprocess.run([sys.executable, str(script)], cwd=REPO, check=True)
    path = REPO / "sim" / "AsyncNoC" / "async_noc16_port_adapter_top2.sv"
    if not path.is_file():
        raise SystemExit("missing " + str(path))
    return path


def _check_generated(generated: Path) -> Path:
    rtl = generated / "NoC_16nodes.v"
    if not rtl.is_file():
        raise SystemExit("missing generated NoC16 1-2-2: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+routers?L", text, re.M))
    async_count = len(re.findall(r"^\s+AsyncFifo(?:_\d+)?\s+(?:upward|downward)", text, re.M))
    circular_count = len(re.findall(r"^\s+CircularFifo(?:_\d+)?\s+(?:upward|downward)", text, re.M))
    ipm_count = len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    adapter_count = len(re.findall(r"LanePhaseAdapter\s*#\s*\(\s*\.\s*LANES\s*\(\s*\d+\s*\)", text))
    top_ports = len(set(re.findall(r"io_top_input_(\d+)_", text)))
    if "module NoC_16nodes" not in text:
        raise SystemExit("generated DUT is not named NoC_16nodes")
    if router_count != EXPECTED_ROUTERS:
        raise SystemExit("NoC16 1-2-2 router count %d != %d" % (router_count, EXPECTED_ROUTERS))
    if ipm_count != EXPECTED_PORTS:
        raise SystemExit("NoC16 1-2-2 IPM count %d != %d" % (ipm_count, EXPECTED_PORTS))
    if adapter_count != EXPECTED_ADAPTERS:
        raise SystemExit("NoC16 1-2-2 adapter count %d != %d" % (adapter_count, EXPECTED_ADAPTERS))
    if top_ports != 2:
        raise SystemExit("NoC16 1-2-2 top ports %d != 2" % top_ports)
    require_emit_locked_delays(
        text, label="NoC16 1-2-2", ackin_unit_ps=int(ACKIN_UNIT_PS)
    )
    if BYPASS_INTERLEVEL_FIFO and (async_count or circular_count):
        raise SystemExit(
            "NoC16 1-2-2 bypass expected no FIFO got async=%d circular=%d"
            % (async_count, circular_count)
        )
    if (not BYPASS_INTERLEVEL_FIFO) and (async_count + circular_count) != EXPECTED_FIFOS:
        raise SystemExit(
            "NoC16 1-2-2 FIFO count async=%d circular=%d expected=%d"
            % (async_count, circular_count, EXPECTED_FIFOS)
        )
    print(
        "LOCAL_EMIT noc16_122 router=%d ipm=%d adapter=%d fifo_async=%d fifo_circ=%d top=%d"
        % (router_count, ipm_count, adapter_count, async_count, circular_count, top_ports),
        flush=True,
    )
    return generated


def generate_rtl() -> Path:
    generated = REPO / "generated_cmr" / "fat_tree_noc16_122"
    rtl = generated / "NoC_16nodes.v"
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1"
    if rtl.is_file() and not force_emit:
        try:
            return _check_generated(generated)
        except SystemExit as exc:
            print("LOCAL_EMIT_RECHECK", exc, flush=True)
    env = os.environ.copy()
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_FORCE_EMIT"] = "1"
    env["CMR_NOC16_L2_PARENT_LANES"] = "2"
    env["CMR_USE_CIRCULAR_FIFO"] = "0"
    env["CMR_BYPASS_INTERLEVEL_FIFO"] = "1" if BYPASS_INTERLEVEL_FIFO else "0"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = str(RCU_STEPS)
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = str(RCU_UNIT_PS)
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = str(ACKIN_UNIT_PS)
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    print("NOC16_122_EMIT bypass=%s" % ("1" if BYPASS_INTERLEVEL_FIFO else "0"), flush=True)
    subprocess.run(
        [sbt, "runMain NoC.CMR.CMRFatTreeNoC16Main"],
        cwd=REPO,
        env=env,
        check=True,
    )
    return _check_generated(generated)


def input_files(generated: Path) -> dict[Path, str]:
    cmr_resource = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"
    async_resource = REPO / "src" / "main" / "resources" / "ASYNC"
    files = {generated / "NoC_16nodes.v": "rtl/noc16_122/NoC_16nodes.v"}
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
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_fat_tree_noc16.tcl":
            "scripts/dc/run_dc_cmr_fat_tree_noc16.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16_122.sh":
            "scripts/run_gls_cmr_noc16_122.sh",
        REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py":
            "scripts/patch_gls_netlist.py",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv":
            "sim/tb/tb_noc16_async_boundary.sv",
        REPO / "sim/AsyncNoC/async_noc16_port_adapter_top2.sv":
            "sim/tb/async_noc16_port_adapter_top2.sv",
    })
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing NoC16 1-2-2 input files: " + ", ".join(missing))
    return files


def wait_dc_marker(client, dc_log):
    dc_text = ""
    for _ in range(12):
        client, dc_text = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_NOC16_DC_PASS" in dc_text or "CMR_NOC16_DC_FAIL" in dc_text:
            break
        time.sleep(5)
    if "CMR_NOC16_DC_PASS" not in dc_text:
        print(dc_text[-16000:], flush=True)
        raise RuntimeError("CMR NoC16 1-2-2 DC failed")
    return client


def collect_gls_result(client, mode, name, jid):
    base = ROOT + "/logs/gls/%s/%s/%s" % (RUN_ID, mode, name)
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


def submit_gls(client, netlist_run_id, mode, name, case_path, rx_capture):
    wrapper = ROOT + "/logs/gls/%s/%s_%s.sh" % (RUN_ID, mode, name)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
        "CMR_NOC16_NETLIST_RUN_ID=%s CMR_NOC16_CASE_NAME=%s "
        "CMR_NOC16_CASE_FILE=%s CMR_NOC16_GLS_MODE=%s "
        "CMR_NOC16_RX_CAPTURE_NS=%s CMR_NOC16_INJECT_MAX_RATE=%s "
        "CMR_NOC16_SIM_ARGS=%s\n"
        "exec bash %s/scripts/run_gls_cmr_noc16_122.sh\n"
        % (
            ROOT,
            shlex.quote(RUN_ID),
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
    client, _ = remote_run_retry(client, "mkdir -p %s/logs/gls/%s" % (ROOT, RUN_ID))
    client, _ = remote_run_retry(
        client,
        "cat > %s << 'CMR_GLS_WRAP'\n%s\nCMR_GLS_WRAP\nchmod +x %s"
        % (wrapper, body, wrapper),
    )
    client, submit = remote_run_retry(
        client,
        "bsub %s -o %s/logs/gls/%s/%s_%s.bsub.log "
        "-e %s/logs/gls/%s/%s_%s.bsub.err -J cmr_n16_122_%s_%s_%s %s"
        % (
            GLS_BSUB, ROOT, RUN_ID, mode, name,
            ROOT, RUN_ID, mode, name,
            RUN_ID, mode, name, wrapper,
        ),
    )
    jid = job_id(submit)
    print("GLS_JOB", "122", mode, name, jid, flush=True)
    client = wait_job(client, jid, "122_%s_%s" % (mode, name), polls=GLS_POLLS, allow_exit=True)
    client, entry, passed = collect_gls_result(client, mode, name, jid)
    print(
        "GLS_CASE", "122", mode, name, "PASS" if passed else "FAIL", entry.get("result_line"),
        flush=True,
    )
    return client, entry, passed


def main():
    unknown = [name for name in dict.fromkeys(FUNC_CASES + CASES) if name not in ALLOWED_CASES]
    if unknown:
        raise SystemExit("unsupported NoC16 1-2-2 cases: " + ",".join(unknown))
    generate_adapter()
    generated = generate_rtl()
    files = input_files(generated)
    skip_dc = bool(NETLIST_RUN_ID)
    netlist_run_id = NETLIST_RUN_ID or RUN_ID
    refuse_overwrite(RUN_ID, action="noc16-122")
    if not skip_dc:
        refuse_overwrite(netlist_run_id, action="noc16-122-dc")
    dut_remote = ROOT + "/rtl/noc16_122/NoC_16nodes.v"

    client = connect()
    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/rtl/noc16_122 %s/scripts/dc %s/sim/tb %s/sim/cases "
        "%s/outputs %s/reports/dc %s/logs/dc %s/logs/gls %s/results/%s/csv %s/work"
        % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, RUN_ID, ROOT),
    )

    remote_cases = {}
    case_hashes = {}
    for name in dict.fromkeys(FUNC_CASES + CASES):
        local = case_local_path(name)
        if local is None:
            path = ULTRA_ROOT + "/sim/cases/" + name + ".case"
            check = remote_run(
                client,
                "test -s %s && sha256sum %s" % (shlex.quote(path), shlex.quote(path)),
            )
            hashes = re.findall(r"\b[0-9a-f]{64}\b", check)
            if not hashes:
                raise RuntimeError("missing remote case: " + path)
            remote_cases[name] = path
            case_hashes[name] = hashes[0]
            print("REMOTE_CASE", name, hashes[0], path, flush=True)
        else:
            if not local.is_file():
                raise SystemExit("missing local case " + str(local))
            remote_cases[name] = None

    upload_hashes = {}
    sftp = client.open_sftp()
    for source, destination in files.items():
        print("UPLOAD", destination, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, source, destination)
        upload_hashes[destination] = digest
    for name, local in ((n, case_local_path(n)) for n in remote_cases):
        if local is None:
            continue
        dest = "sim/cases/" + name + ".case"
        print("UPLOAD", dest, flush=True)
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        case_hashes[name] = digest
        remote_cases[name] = ROOT + "/" + dest
    sftp.close()
    remote_run(
        client,
        "chmod +x %s/scripts/run_gls_cmr_noc16_122.sh; "
        "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_noc16_122.sh "
        "%s/scripts/dc/run_dc_cmr_fat_tree_noc16.tcl "
        "%s/sim/tb/tb_noc16_async_boundary.sv "
        "%s/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv "
        "%s/sim/tb/async_noc16_port_adapter_top2.sv "
        "%s/scripts/patch_gls_netlist.py"
        % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT),
    )

    dc_job = None
    dc_log = ROOT + "/logs/dc/" + RUN_ID + ".log"
    if skip_dc:
        print("SKIP_DC netlist_run_id=%s" % netlist_run_id, flush=True)
        client = reconnect(client)
        client, probe = remote_run_retry(
            client,
            "test -s %s/outputs/%s/NoC_16nodes_post.v && "
            "test -s %s/outputs/%s/NoC_16nodes.sdf && echo OK"
            % (ROOT, netlist_run_id, ROOT, netlist_run_id),
        )
        if "OK" not in probe:
            raise RuntimeError("frozen NoC16 1-2-2 netlist missing for %s" % netlist_run_id)
    else:
        dc_wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
        dc_body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "module load syn 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
            "CMR_NOC16_DUT_V=%s CMR_LANE01_BUF_STAGES=%s "
            "CMR_EXPECTED_ADAPTERS=%d CMR_EXPECTED_PORTS=%d "
            "CMR_RCU_MATCHED_DELAY_STEPS=%s CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
            "CMR_OPM_ACKIN_DELAY_UNIT_PS=%s CMR_BYPASS_INTERLEVEL_FIFO=%s\n"
            "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_fat_tree_noc16.tcl\n"
            % (
                ROOT,
                shlex.quote(RUN_ID),
                shlex.quote(dut_remote),
                shlex.quote(LANE01_STAGES),
                EXPECTED_ADAPTERS,
                EXPECTED_PORTS,
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
            "bsub %s -o %s -e %s.err -J cmr_n16_122_dc_%s %s"
            % (DC_BSUB, dc_log, dc_log, RUN_ID, dc_wrapper),
        )
        dc_job = job_id(dc_submit)
        print("DC_JOB", "122", dc_job, flush=True)
        client = wait_job(client, dc_job, "dc_122", polls=DC_POLLS)
        client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": RUN_ID,
        "geometry": "fat_tree_noc16_l1_1to2_l2_2to2",
        "top_lanes": 2,
        "expected_ports": EXPECTED_PORTS,
        "expected_adapters": EXPECTED_ADAPTERS,
        "bypass_interlevel_fifo": BYPASS_INTERLEVEL_FIFO,
        "circular_fifo": False,
        "expected_fifos": EXPECTED_FIFOS,
        "sdf_rx_capture_ns": SDF_RX_CAPTURE_NS,
        "func_rx_capture_ns": FUNC_RX_CAPTURE_NS,
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
            client, entry, passed = submit_gls(
                client, netlist_run_id, "func", name, remote_cases[name], FUNC_RX_CAPTURE_NS
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
                        client, netlist_run_id, "sdf", name, remote_cases[name], SDF_RX_CAPTURE_NS
                    )
                    status["sdf_cases"][name] = entry
                    if not passed:
                        status["all_pass"] = False
                        skip_remaining("sdf_cases", CASES[index + 1:], "previous sdf failed: " + name)
                        break
    elif not SKIP_GLS and SKIP_FUNC and not SKIP_SDF:
        client = reconnect(client)
        for index, name in enumerate(CASES):
            client, entry, passed = submit_gls(
                client, netlist_run_id, "sdf", name, remote_cases[name], SDF_RX_CAPTURE_NS
            )
            status["sdf_cases"][name] = entry
            if not passed:
                status["all_pass"] = False
                skip_remaining("sdf_cases", CASES[index + 1:], "previous sdf failed: " + name)
                break
    else:
        status["skip_gls"] = True

    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    sftp = client.open_sftp()
    for remote, local in (
        (ROOT + "/reports/dc/" + netlist_run_id, RESULT / "reports_dc"),
        (ROOT + "/logs/dc/" + RUN_ID + ".log", RESULT / "dc.log"),
        (ROOT + "/logs/gls/" + RUN_ID, RESULT / "logs_gls"),
    ):
        try:
            if remote.endswith(".log"):
                sftp.get(remote, str(local))
            else:
                fetch_tree(sftp, remote, local)
        except IOError:
            print("FETCH_SKIP", remote, flush=True)
    sftp.close()
    client.close()
    print("LOCAL_RESULT", RESULT, "PASS" if status["all_pass"] else "FAIL", flush=True)
    if not status["all_pass"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
