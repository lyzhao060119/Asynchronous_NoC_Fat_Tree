#!/usr/bin/env python3
"""Build CMR fat-tree NoC16 and run remote TAB/VCTM p50 strict-SDF cases.

Default is the noFIFO diagnostic: L1 1->2 / L2 2->4 with inter-level FIFOs
omitted (BYPASS=1, CIRCULAR=0), LanePhaseAdapter CommittedAck, LANE01=0, and
RX_CAPTURE=100 ps.  Restore the paper CircularFIFO DUT with
CMR_BYPASS_INTERLEVEL_FIFO=0 CMR_USE_CIRCULAR_FIFO=1.  Delay defaults match
the locked hop recipe: RCU 1xDEL050, Ackin 1xDEL050, matched buf=0.
Do not cite Ackin 250 predecessors (20260829_cmr_ft_noc16_lane01_0) as
Fat vs Thin delay.  SKIP_DC that netlist with CMR_NOC16_NETLIST_RUN_ID.
On-disk generated_cmr/fat_tree_noc16 may still be CFifo or ACG; a FIFO-type
switch forces CMR_FORCE_EMIT=1.  Large case files are consumed directly from
the read-only remote Ultra tree.  They are never uploaded from or downloaded
to the local workspace.
"""
import json
import os
import re
import shlex
import stat
import subprocess
import time
from datetime import datetime
from pathlib import Path

import paramiko

from cmr_frozen_run_ids import refuse_overwrite, require_emit_locked_delays
from run_remote_cmr_flow import (
    atomic_put_bytes,
    password,
    remote_run,
    sha256_bytes,
)


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA_ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_ft_noc16_p50_sdf",
)
NETLIST_RUN_ID = os.environ.get("CMR_NOC16_NETLIST_RUN_ID", "")
DEFAULT_CASES = (
    "TAB-NET-UR-3f-r0p50",
    "VCTM-MC5-NM-3f-r0p50",
)
PREFIX_CASE = "TAB-NET-UR-3f-r0p50_prefix_t14"
TAB_RATE_CASES = (
    "TAB-NET-UR-3f-r0p02",
    "TAB-NET-UR-3f-r0p10",
    "TAB-NET-UR-3f-r0p20",
    "TAB-NET-UR-3f-r0p30",
    "TAB-NET-UR-3f-r0p40",
    "TAB-NET-UR-3f-r0p60",
    "TAB-NET-UR-3f-r0p70",
    "TAB-NET-UR-3f-r0p80",
    "TAB-NET-UR-3f-r0p90",
)
VCTM_RATE_CASES = (
    "VCTM-MC5-NM-3f-r0p02",
    "VCTM-MC5-NM-3f-r0p10",
    "VCTM-MC5-NM-3f-r0p20",
    "VCTM-MC5-NM-3f-r0p30",
    "VCTM-MC5-NM-3f-r0p40",
    "VCTM-MC5-NM-3f-r0p60",
    "VCTM-MC5-NM-3f-r0p70",
    "VCTM-MC5-NM-3f-r0p80",
    "VCTM-MC5-NM-3f-r0p90",
)
ALLOWED_CASES = DEFAULT_CASES + (PREFIX_CASE,) + TAB_RATE_CASES + VCTM_RATE_CASES
CASES = tuple(
    name for name in os.environ.get("CMR_NOC16_CASES", ",".join(DEFAULT_CASES)).split(",")
    if name
)
SKIP_GLS = os.environ.get("CMR_NOC16_SKIP_GLS", "0") == "1"
INJECT_MAX_RATE = os.environ.get("CMR_NOC16_INJECT_MAX_RATE", "0") == "1"
SIM_ARGS = os.environ.get("CMR_NOC16_SIM_ARGS", "")
RX_CAPTURE_NS = os.environ.get("CMR_NOC16_RX_CAPTURE_NS", "0.1")
UNEXPECTED_PROBE = os.environ.get("CMR_NOC16_UNEXPECTED_PROBE", "0") == "1"
HOP_PROBE = os.environ.get("CMR_NOC16_HOP_PROBE", "0") == "1"
L2_IPM1_PROBE = os.environ.get("CMR_NOC16_L2_IPM1_PROBE", "0") == "1"
L2_OPMSEL_PROBE = os.environ.get("CMR_NOC16_L2_OPMSEL_PROBE", "0") == "1"
UPFIFO_PROBE = os.environ.get("CMR_NOC16_UPFIFO_PROBE", "0") == "1"
L1P1_PROBE = os.environ.get("CMR_NOC16_L1P1_PROBE", "0") == "1"
L1ADAPT_PROBE = os.environ.get("CMR_NOC16_L1ADAPT_PROBE", "0") == "1"
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
EXPECTED_ROUTERS = 5
EXPECTED_PORTS = 36
# Diagnostic noFIFO.  Do not change Thin defaults from this launcher.
USE_CIRCULAR_FIFO = os.environ.get("CMR_USE_CIRCULAR_FIFO", "0") == "1"
BYPASS_INTERLEVEL_FIFO = os.environ.get("CMR_BYPASS_INTERLEVEL_FIFO", "1") == "1"
if BYPASS_INTERLEVEL_FIFO:
    USE_CIRCULAR_FIFO = False
LANE01_STAGES = os.environ.get("CMR_LANE01_BUF_STAGES", "0").strip() or "0"
RCU_STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
RCU_UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
EXPECTED_ADAPTERS = 4 * 4 + 48
FIFO_DEPTH = 3
EXPECTED_FIFOS = 0 if BYPASS_INTERLEVEL_FIFO else 16
EXPECTED_FIFO_OUTREQ = EXPECTED_FIFOS * FIFO_DEPTH
CIRCULAR_RTL = (
    "CircularFIFO.v",
    "WriteControlBlock.v",
    "ReadControlBlock.v",
    "CircularWriteCounter.v",
    "CircularReadCounter.v",
)


def connect(attempts=8):
    last = None
    for attempt in range(attempts):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                os.environ.get("C1_HOST", "192.168.2.8"),
                username=os.environ.get("C1_USER", "ghy19"),
                password=password(),
                timeout=40,
                banner_timeout=90,
                allow_agent=False,
                look_for_keys=False,
                compress=True,
            )
            transport = client.get_transport()
            if transport is not None:
                transport.set_keepalive(30)
            return client
        except (OSError, EOFError, paramiko.SSHException) as exc:
            last = exc
            print("SSH_CONNECT_RETRY", attempt, exc, flush=True)
            try:
                client.close()
            except Exception:
                pass
            time.sleep(5 + min(attempt, 6) * 5)
    raise RuntimeError("SSH connect failed: %s" % last)


def client_alive(client):
    transport = client.get_transport() if client is not None else None
    return bool(transport and transport.is_active())


def reconnect(client=None):
    if client is not None:
        try:
            client.close()
        except Exception:
            pass
    return connect()


SSH_ERRORS = (
    OSError,
    EOFError,
    paramiko.SSHException,
    paramiko.ssh_exception.SSHException,
)


def remote_run_retry(client, command, attempts=8):
    last = None
    for attempt in range(attempts):
        try:
            if not client_alive(client):
                print("SSH_RECONNECT attempt", attempt, flush=True)
                client = connect()
            return client, remote_run(client, command)
        except SSH_ERRORS as exc:
            last = exc
            print("SSH_RETRY", attempt, exc, flush=True)
            client = reconnect(client)
            time.sleep(5 + min(attempt, 6) * 5)
    raise RuntimeError("SSH retries exhausted: %s" % last)


def sftp_put_file(sftp, source, destination):
    data = source.read_bytes().replace(b"\r\n", b"\n")
    expected = sha256_bytes(data)
    remote = ROOT + "/" + destination
    temporary = "%s.upload.%d" % (remote, os.getpid())
    with sftp.file(temporary, "wb") as handle:
        handle.write(data)
        handle.flush()
    try:
        sftp.remove(remote)
    except IOError:
        pass
    sftp.rename(temporary, remote)
    return expected


def atomic_put_retry(client, sftp, source, destination, attempts=6):
    last = None
    for attempt in range(attempts):
        try:
            if not client_alive(client):
                print("SSH_RECONNECT_UPLOAD", destination, attempt, flush=True)
                client = connect()
                sftp = client.open_sftp()
            digest = sftp_put_file(sftp, source, destination)
            return client, sftp, digest
        except SSH_ERRORS as exc:
            last = exc
            print("UPLOAD_RETRY", destination, attempt, exc, flush=True)
            try:
                sftp.close()
            except Exception:
                pass
            client = reconnect(client)
            sftp = client.open_sftp()
            time.sleep(3 + min(attempt, 6) * 2)
    raise RuntimeError("upload retries exhausted %s: %s" % (destination, last))


def job_id(text):
    match = re.search(r"Job <(\d+)>", text)
    if not match:
        raise RuntimeError("LSF submission failed: " + text)
    return match.group(1)


def wait_job(client, jid, label, polls=480, allow_exit=False):
    for poll in range(polls):
        client, response = remote_run_retry(
            client,
            "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); "
            "printf '__CMR_NOC16_STATE__%%s\\n' \"$state\"" % shlex.quote(jid),
        )
        match = re.search(r"__CMR_NOC16_STATE__([A-Z]*)", response)
        if not match:
            raise RuntimeError("could not parse LSF state: " + response)
        state = match.group(1)
        if not state or state == "DONE":
            print("JOB_DONE", label, jid, state or "PURGED", flush=True)
            return client
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            if allow_exit and state == "EXIT":
                print("JOB_FAIL_FAST_EXIT", label, jid, state, flush=True)
                return client
            raise RuntimeError("LSF job %s %s ended in %s" % (label, jid, state))
        print("JOB_WAIT", label, jid, state, "poll", poll, flush=True)
        time.sleep(30)
    raise TimeoutError("job timeout: %s %s" % (label, jid))


def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for entry in sftp.listdir_attr(remote):
        remote_path = remote + "/" + entry.filename
        local_path = local / entry.filename
        if stat.S_ISDIR(entry.st_mode):
            fetch_tree(sftp, remote_path, local_path)
        else:
            sftp.get(remote_path, str(local_path))


def collect_case_result(client, name, jid):
    base = ROOT + "/logs/gls/%s/sdf/%s" % (RUN_ID, name)
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
        "tb_pass": "TB_RESULT PASS" in run_log,
        "annotation_done": "Doing SDF annotation ...... Done" in run_log,
        "annotation_errors": int(errors.group(1)) if errors else None,
        "ifnsdfa": "IFNSDFA" in run_log,
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


def generate_rtl():
    generated = REPO / "generated_cmr" / "fat_tree_noc16"
    rtl = generated / "NoC_16nodes.v"
    text = rtl.read_text(encoding="utf-8") if rtl.is_file() else ""
    uses_circular = bool(re.search(
        r"CircularFifo(?:_\d+)?\s+(?:upward|downward)", text
    ))
    uses_async = bool(re.search(
        r"AsyncFifo(?:_\d+)?\s+(?:upward|downward)", text
    ))
    disk_bypass = bool(rtl.is_file()) and not uses_circular and not uses_async
    fifo_switch = rtl.is_file() and (
        disk_bypass != BYPASS_INTERLEVEL_FIFO
        or ((not BYPASS_INTERLEVEL_FIFO) and uses_circular != USE_CIRCULAR_FIFO)
    )
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1" or fifo_switch
    if fifo_switch:
        print(
            "FAT_TREE_FORCE_EMIT fifo switch disk_circular=%s disk_async=%s disk_bypass=%s want_circular=%s want_bypass=%s"
            % (
                "1" if uses_circular else "0",
                "1" if uses_async else "0",
                "1" if disk_bypass else "0",
                "1" if USE_CIRCULAR_FIFO else "0",
                "1" if BYPASS_INTERLEVEL_FIFO else "0",
            ),
            flush=True,
        )
    skip_emit = (
        rtl.is_file()
        and not force_emit
        and disk_bypass == BYPASS_INTERLEVEL_FIFO
        and (BYPASS_INTERLEVEL_FIFO or uses_circular == USE_CIRCULAR_FIFO)
    )
    if skip_emit:
        try:
            return _check_generated(generated)
        except SystemExit:
            pass
    env = os.environ.copy()
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_FORCE_EMIT"] = "1" if force_emit else os.environ.get("CMR_FORCE_EMIT", "0")
    env["CMR_USE_CIRCULAR_FIFO"] = "1" if USE_CIRCULAR_FIFO else "0"
    env["CMR_BYPASS_INTERLEVEL_FIFO"] = "1" if BYPASS_INTERLEVEL_FIFO else "0"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = RCU_STEPS
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = str(RCU_UNIT_PS)
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = str(ACKIN_UNIT_PS)
    print(
        "FAT_TREE_EMIT circular=%s bypass=%s force_emit=%s rcu_steps=%s rcu_unit_ps=%s ackin_unit_ps=%s lane01_stages=%s adapters=%d"
        % (
            "1" if USE_CIRCULAR_FIFO else "0",
            "1" if BYPASS_INTERLEVEL_FIFO else "0",
            "1" if force_emit else "0",
            RCU_STEPS,
            RCU_UNIT_PS,
            ACKIN_UNIT_PS,
            LANE01_STAGES,
            EXPECTED_ADAPTERS,
        ),
        flush=True,
    )
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    subprocess.run(
        [sbt, "runMain NoC.CMR.CMRFatTreeNoC16Main"],
        cwd=REPO,
        env=env,
        check=True,
    )
    return _check_generated(generated)


def _check_generated(generated):
    rtl = generated / "NoC_16nodes.v"
    if not rtl.is_file():
        raise SystemExit("missing generated fat-tree NoC16: " + str(rtl))
    text = rtl.read_text(encoding="utf-8")
    router_count = len(re.findall(r"CMRRouter(?:_\d+)?\s+routerL", text))
    async_count = len(re.findall(r"AsyncFifo(?:_\d+)?\s+(?:upward|downward)", text))
    circular_count = len(re.findall(r"CircularFifo(?:_\d+)?\s+(?:upward|downward)", text))
    fifo_count = async_count + circular_count
    ipm_count = len(re.findall(r"IPM(?:_\d+)?\s+InputPortModules_\d+", text))
    # Chisel emits one AsyncStage module with one outReqDelay, then
    # depth-N AsyncStage instances inside AsyncFifo.  The elaborated
    # CMR-FIFO-01 count is fifos * depth; DC counts the mapped DEL150s.
    outreq_mod = len(re.findall(
        r"DelayElement\s+#\(\.DelayUnitPs\(150\),\s*\.DelayValue\(1\)\)\s+outReqDelay\s+\(",
        text,
    ))
    stage_inst = len(re.findall(r"AsyncStage(?:_\d+)?\s+stages_\d+", text))
    outreq_elab = async_count * FIFO_DEPTH if not USE_CIRCULAR_FIFO else 0
    if BYPASS_INTERLEVEL_FIFO:
        if circular_count != 0 or async_count != 0:
            raise SystemExit(
                "generated fat-tree bypass expected no inter-level FIFO got circular=%d async=%d"
                % (circular_count, async_count)
            )
    elif USE_CIRCULAR_FIFO:
        if circular_count != EXPECTED_FIFOS or async_count != 0:
            raise SystemExit(
                "generated fat-tree expected CircularFifo=%d got circular=%d async=%d"
                % (EXPECTED_FIFOS, circular_count, async_count)
            )
    else:
        if async_count != EXPECTED_FIFOS or circular_count != 0:
            raise SystemExit(
                "generated fat-tree expected AsyncFifo=%d got async=%d circular=%d"
                % (EXPECTED_FIFOS, async_count, circular_count)
            )
        if outreq_mod != 1:
            raise SystemExit(
                "generated fat-tree missing AsyncStage CMR-FIFO-01 outReqDelay module instance=%d"
                % outreq_mod
            )
        if stage_inst != FIFO_DEPTH:
            raise SystemExit(
                "generated fat-tree AsyncFifo depth mismatch stages=%d expected=%d"
                % (stage_inst, FIFO_DEPTH)
            )
        if outreq_elab != EXPECTED_FIFO_OUTREQ:
            raise SystemExit(
                "generated fat-tree ACG Out.Req DEL150 elaborated=%d expected=%d"
                % (outreq_elab, EXPECTED_FIFO_OUTREQ)
            )
    if "module NoC_16nodes" not in text:
        raise SystemExit("generated fat-tree DUT is not named NoC_16nodes")
    require_emit_locked_delays(
        text, label="fat-tree NoC16", ackin_unit_ps=int(ACKIN_UNIT_PS)
    )
    if (
        router_count != EXPECTED_ROUTERS
        or fifo_count != EXPECTED_FIFOS
        or ipm_count != EXPECTED_PORTS
    ):
        raise SystemExit(
            "generated fat-tree NoC16 structure mismatch "
            "router=%d fifo=%d ipm=%d"
            % (router_count, fifo_count, ipm_count)
        )
    value_count = len(re.findall(r"DelayValue\(", text))
    unit_count = len(re.findall(r"DelayUnitPs\(", text))
    and2_count = len(re.findall(r"RouteSelAnd2(?:_\d+)?\s+RouteSelAnd_\d+", text))
    rc_count = len(re.findall(r"^module RouteComputationLogic", text, re.M))
    if rc_count == 0 or and2_count != 4 * rc_count:
        raise SystemExit(
            "generated fat-tree NoC16 missing RouteSelAnd2 "
            "and2=%d rc=%d expected_and2=%d"
            % (and2_count, rc_count, 4 * rc_count)
        )
    print(
        "LOCAL_EMIT DelayValue=%d DelayUnitPs=%d router=%d fifo=%d async=%d circular=%d outReqDelay_mod=%d stages=%d outReqDelay_elab=%d ipm=%d and2=%d"
        % (
            value_count,
            unit_count,
            router_count,
            fifo_count,
            async_count,
            circular_count,
            outreq_mod,
            stage_inst,
            outreq_elab,
            ipm_count,
            and2_count,
        ),
        flush=True,
    )
    return generated


def input_files(generated):
    cmr_resource = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"
    async_resource = REPO / "src" / "main" / "resources" / "ASYNC"
    files = {generated / "NoC_16nodes.v": "rtl/NoC_16nodes.v"}
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
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh":
            "scripts/run_gls_cmr_noc16.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_unexpected_probe.sv":
            "sim/tb/tb_cmr_fat_tree_unexpected_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_800800b_hop_probe.sv":
            "sim/tb/tb_cmr_fat_tree_800800b_hop_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_l2_ipm1_800800b_probe.sv":
            "sim/tb/tb_cmr_fat_tree_l2_ipm1_800800b_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_l2_opmsel_800800b_probe.sv":
            "sim/tb/tb_cmr_fat_tree_l2_opmsel_800800b_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_l2_ipm1_upfifo_probe.sv":
            "sim/tb/tb_cmr_fat_tree_l2_ipm1_upfifo_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_l1_11_parent1_opm_probe.sv":
            "sim/tb/tb_cmr_fat_tree_l1_11_parent1_opm_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_l1_ipm1_adapter_probe.sv":
            "sim/tb/tb_cmr_fat_tree_l1_ipm1_adapter_probe.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv":
            "sim/tb/tb_noc16_async_boundary.sv",
    })
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing fat-tree NoC16 input files: " + ", ".join(missing))
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
        raise RuntimeError("CMR fat-tree NoC16 DC failed")
    return client


def main():
    if not CASES or any(name not in ALLOWED_CASES for name in CASES):
        raise SystemExit("CMR_NOC16_CASES must select TAB, VCTM, or the approved TAB prefix")
    if int(LANE01_STAGES) < 0:
        raise SystemExit("CMR_LANE01_BUF_STAGES must be >=0")
    refuse_overwrite(RUN_ID, action="fat-noc16")
    generated = generate_rtl()
    files = input_files(generated)
    skip_dc = bool(NETLIST_RUN_ID)
    netlist_run_id = NETLIST_RUN_ID or RUN_ID
    if not skip_dc:
        refuse_overwrite(netlist_run_id, action="fat-noc16-dc")

    client = connect()
    directories = (
        "rtl scripts/dc scripts sim/tb sim/work outputs reports/dc logs/dc "
        "logs/gls results/%s/csv work" % RUN_ID
    )
    remote_run(client, "mkdir -p " + " ".join(ROOT + "/" + d for d in directories.split()))

    copy_cmd = (
        "cp {u}/sim/tb/async_noc16_port_adapter.sv {c}/sim/tb/ && "
        "cp {u}/sim/tb/tb_noc16_async_boundary.sv "
        "{c}/sim/tb/tb_noc16_async_boundary.ultra_reference.sv"
    ).format(u=shlex.quote(ULTRA_ROOT), c=shlex.quote(ROOT))
    output = remote_run(client, copy_cmd)
    if output.strip():
        print(output, flush=True)

    # TAB/VCTM source cases stay read-only in the Ultra tree.  The small TAB
    # prefix is a CMR-owned diagnostic derivative produced from that source.
    remote_cases = {
        name: (ROOT if name == PREFIX_CASE else ULTRA_ROOT) + "/sim/cases/" + name + ".case"
        for name in CASES
    }
    case_hashes = {}
    for name, path in remote_cases.items():
        check = remote_run(
            client,
            "test -s %s && sha256sum %s" % (shlex.quote(path), shlex.quote(path)),
        )
        hashes = re.findall(r"\b[0-9a-f]{64}\b", check)
        if not hashes:
            raise RuntimeError("missing remote case: " + path)
        case_hashes[name] = hashes[0]
        print("REMOTE_CASE", name, hashes[0], path, flush=True)

    upload_hashes = {}
    if skip_dc:
        client, tb_probe = remote_run_retry(
            client,
            "grep -q INJECT_MAX_RATE %s/sim/tb/tb_noc16_async_boundary.sv && "
            "grep -q INJECT_MAX_RATE %s/scripts/run_gls_cmr_noc16.sh && "
            "test -s %s/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv && echo TB_OK"
            % (ROOT, ROOT, ROOT),
        )
        if "TB_OK" not in tb_probe:
            raise RuntimeError(
                "remote TB/GLS missing INJECT_MAX_RATE; "
                "run Thin async GLS once to seed the files"
            )
        print("SKIP_UPLOAD reuse remote TB/GLS with INJECT_MAX_RATE", flush=True)
        upload_hashes["skip_dc"] = "reuse remote TB/GLS"
    else:
        sftp = client.open_sftp()
        for source, destination in files.items():
            print("UPLOAD", destination, flush=True)
            client, sftp, digest = atomic_put_retry(client, sftp, source, destination)
            upload_hashes[destination] = digest
        sftp.close()
        remote_run(
            client,
            "chmod +x %s/scripts/run_gls_cmr_noc16.sh; "
            "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_noc16.sh "
            "%s/sim/tb/tb_noc16_async_boundary.sv "
            "%s/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv "
            "%s/scripts/dc/run_dc_cmr_fat_tree_noc16.tcl "
            "%s/sim/tb/tb_cmr_fat_tree_unexpected_probe.sv "
            "%s/sim/tb/tb_cmr_fat_tree_800800b_hop_probe.sv "
            "%s/sim/tb/tb_cmr_fat_tree_l2_ipm1_800800b_probe.sv "
            "%s/sim/tb/tb_cmr_fat_tree_l2_opmsel_800800b_probe.sv "
            "%s/sim/tb/tb_cmr_fat_tree_l2_ipm1_upfifo_probe.sv "
            "%s/sim/tb/tb_cmr_fat_tree_l1_11_parent1_opm_probe.sv "
            "%s/sim/tb/tb_cmr_fat_tree_l1_ipm1_adapter_probe.sv"
            % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT),
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
            print("NETLIST_PROBE_RETRY", probe, flush=True)
            client = reconnect(client)
            client, probe = remote_run_retry(
                client,
                "test -s %s/outputs/%s/NoC_16nodes_post.v && "
                "test -s %s/outputs/%s/NoC_16nodes.sdf && echo OK"
                % (ROOT, netlist_run_id, ROOT, netlist_run_id),
            )
        if "OK" not in probe:
            raise RuntimeError(
                "frozen fat-tree NoC16 netlist missing for %s: %s"
                % (netlist_run_id, probe)
            )
    else:
        client, existing_log = remote_run_retry(
            client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
        )
        if "CMR_NOC16_DC_PASS" in existing_log:
            print("REUSE_DC_PASS", RUN_ID, flush=True)
        else:
            client, job_text = remote_run_retry(
                client,
                "bjobs -J %s -noheader -o 'jobid stat' 2>/dev/null"
                % shlex.quote("cmr_ft_noc16_dc_%s" % RUN_ID),
            )
            job_match = re.search(r"(\d+)\s+(PEND|RUN)", job_text)
            if job_match:
                dc_job = job_match.group(1)
                print("REUSE_DC_JOB", dc_job, job_match.group(2), flush=True)
                client = wait_job(client, dc_job, "dc")
                client = wait_dc_marker(client, dc_log)
            else:
                dc_wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
                dc_body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "module load syn 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
                    "CMR_LANE01_BUF_STAGES=%s CMR_EXPECTED_ADAPTERS=%d "
                    "CMR_RCU_MATCHED_DELAY_STEPS=%s CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
                    "CMR_OPM_ACKIN_DELAY_UNIT_PS=%s CMR_BYPASS_INTERLEVEL_FIFO=%s\n"
                    "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_fat_tree_noc16.tcl\n"
                    % (
                        ROOT,
                        shlex.quote(RUN_ID),
                        shlex.quote(LANE01_STAGES),
                        EXPECTED_ADAPTERS,
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
                    "bsub -n 8 -o %s -e %s.err -J cmr_ft_noc16_dc_%s %s"
                    % (dc_log, dc_log, RUN_ID, dc_wrapper),
                )
                dc_job = job_id(dc_submit)
                print("DC_JOB", dc_job, flush=True)
                client = wait_job(client, dc_job, "dc")
                client = wait_dc_marker(client, dc_log)

    status = {
        "run_id": RUN_ID,
        "geometry": "fat_tree_noc16_l1_1to2_l2_2to4",
        "interlevel_fifo_depth": FIFO_DEPTH,
        "bypass_interlevel_fifo": BYPASS_INTERLEVEL_FIFO,
        "circular_fifo": USE_CIRCULAR_FIFO,
        "acg_fifo_outreq_del150": 0 if (USE_CIRCULAR_FIFO or BYPASS_INTERLEVEL_FIFO) else EXPECTED_FIFO_OUTREQ,
        "lane01_buf_stages": int(LANE01_STAGES),
        "expected_adapters": EXPECTED_ADAPTERS,
        "rcu_matched_delay_steps": int(RCU_STEPS),
        "rcu_matched_delay_unit_ps": int(RCU_UNIT_PS),
        "opm_ackin_delay_unit_ps": int(ACKIN_UNIT_PS),
        "remote_root": ROOT,
        "testbench": "event-driven asynchronous boundary with CMR fail-fast",
        "stall_timeout_ns": 20000,
        "hard_timeout_ns": 200000,
        "rx_capture_ns": RX_CAPTURE_NS,
        "inject_max_rate": INJECT_MAX_RATE,
        "sim_args": SIM_ARGS,
        "unexpected_probe": UNEXPECTED_PROBE,
        "hop_probe": HOP_PROBE,
        "l2_ipm1_probe": L2_IPM1_PROBE,
        "l2_opmsel_probe": L2_OPMSEL_PROBE,
        "upfifo_probe": UPFIFO_PROBE,
        "l1p1_probe": L1P1_PROBE,
        "l1adapt_probe": L1ADAPT_PROBE,
        "case_source": "remote Ultra sim/cases (not uploaded)",
        "case_hashes": case_hashes,
        "upload_hashes": upload_hashes,
        "dc_job": dc_job,
        "netlist_run_id": netlist_run_id,
        "cases": {},
    }
    jobs = {}
    all_pass = True
    if SKIP_GLS:
        print("SKIP_GLS dc_only run_id=%s" % RUN_ID, flush=True)
        remote_cases = {}
        status["skip_gls"] = True
    elif remote_cases:
        client = reconnect(client)
    for name, case_path in remote_cases.items():
        wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (RUN_ID, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
            "CMR_NOC16_NETLIST_RUN_ID=%s CMR_NOC16_CASE_NAME=%s "
            "CMR_NOC16_CASE_FILE=%s CMR_NOC16_RX_CAPTURE_NS=%s "
            "CMR_NOC16_INJECT_MAX_RATE=%s CMR_NOC16_SIM_ARGS=%s "
            "CMR_NOC16_UNEXPECTED_PROBE=%s CMR_NOC16_HOP_PROBE=%s "
            "CMR_NOC16_L2_IPM1_PROBE=%s CMR_NOC16_L2_OPMSEL_PROBE=%s "
            "CMR_NOC16_UPFIFO_PROBE=%s CMR_NOC16_L1P1_PROBE=%s "
            "CMR_NOC16_L1ADAPT_PROBE=%s\n"
            "exec bash %s/scripts/run_gls_cmr_noc16.sh\n"
            % (
                ROOT,
                shlex.quote(RUN_ID),
                shlex.quote(netlist_run_id),
                shlex.quote(name),
                shlex.quote(case_path),
                shlex.quote(RX_CAPTURE_NS),
                "1" if INJECT_MAX_RATE else "0",
                shlex.quote(SIM_ARGS),
                "1" if UNEXPECTED_PROBE else "0",
                "1" if HOP_PROBE else "0",
                "1" if L2_IPM1_PROBE else "0",
                "1" if L2_OPMSEL_PROBE else "0",
                "1" if UPFIFO_PROBE else "0",
                "1" if L1P1_PROBE else "0",
                "1" if L1ADAPT_PROBE else "0",
                ROOT,
            )
        )
        client, _ = remote_run_retry(
            client, "mkdir -p %s/logs/gls/%s" % (ROOT, RUN_ID)
        )
        if "CMR_GLS_WRAP" in body:
            raise RuntimeError("GLS wrapper body contains heredoc sentinel")
        client, _ = remote_run_retry(
            client,
            "cat > %s << 'CMR_GLS_WRAP'\n%s\nCMR_GLS_WRAP\nchmod +x %s"
            % (wrapper, body, wrapper),
        )
        client, submit = remote_run_retry(
            client,
            "bsub -n 8 -o %s/logs/gls/%s/sdf_%s.bsub.log "
            "-e %s/logs/gls/%s/sdf_%s.bsub.err -J cmr_ft_noc16_%s_%s %s"
            % (ROOT, RUN_ID, name, ROOT, RUN_ID, name, RUN_ID, name, wrapper),
        )
        jobs[name] = job_id(submit)
        print("SDF_JOB", name, jobs[name], flush=True)
        # Cases are intentionally serialized.  VCTM is never launched after a
        # TAB failure, so a poisoned netlist cannot consume another long slot.
        client = wait_job(client, jobs[name], "sdf_" + name, allow_exit=True)
        client, entry, passed = collect_case_result(client, name, jobs[name])
        status["cases"][name] = entry
        all_pass &= passed
        print("SDF_CASE", name, "PASS" if passed else "FAIL", entry, flush=True)
        if not passed:
            for skipped in CASES[CASES.index(name) + 1:]:
                status["cases"][skipped] = {
                    "skipped": True,
                    "reason": "previous case failed: " + name,
                }
            break

    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(
        json.dumps(status, indent=2) + "\n", encoding="utf-8"
    )
    sftp = client.open_sftp()
    fetch_list = [
        (ROOT + "/reports/dc/" + netlist_run_id, RESULT / "reports_dc"),
        (ROOT + "/logs/dc/" + RUN_ID + ".log", RESULT / "dc.log"),
    ]
    if not SKIP_GLS:
        fetch_list.append((ROOT + "/logs/gls/" + RUN_ID, RESULT / "logs_gls"))
        # Frozen-netlist GLS must not pull the multi-GB post.v/SDF again.
        if not skip_dc:
            fetch_list.append(
                (ROOT + "/outputs/" + netlist_run_id, RESULT / "outputs")
            )
    for remote, local in fetch_list:
        try:
            if remote.endswith(".log"):
                RESULT.mkdir(parents=True, exist_ok=True)
                sftp.get(remote, str(RESULT / "dc.log"))
            else:
                fetch_tree(sftp, remote, local)
        except IOError:
            print("FETCH_SKIP", remote, flush=True)
    sftp.close()
    client.close()
    print("LOCAL_RESULT", RESULT, flush=True)
    if not all_pass:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
