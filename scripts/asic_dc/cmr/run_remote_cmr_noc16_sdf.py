#!/usr/bin/env python3
"""Build CMR NoC16 and run remote TAB/VCTM p50 strict-SDF cases.

The large case files are consumed directly from the read-only remote Ultra
tree.  They are never uploaded from or downloaded to the local workspace.
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

from cmr_frozen_run_ids import refuse_overwrite
from run_remote_cmr_flow import atomic_put, atomic_put_bytes, password, remote_run


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA_ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_noc16_p50_sdf"
)
CASES = tuple(
    name.strip() for name in os.environ.get(
        "CMR_NOC16_CASES", "TAB-NET-UR-3f-r0p50,VCTM-MC5-NM-3f-r0p50"
    ).split(",") if name.strip()
)
SKIP_SDF = os.environ.get("CMR_NOC16_SKIP_SDF", "0") == "1"
PHASE_SELECTOR_PROBE = os.environ.get("CMR_NOC16_PHASE_SELECTOR_PROBE", "0") == "1"
ACK_FEEDBACK_BUFFER_STAGES = os.environ.get("CMR_ACK_FEEDBACK_BUFFER_STAGES", "0")
ACK_FEEDBACK_SCOPE = os.environ.get("CMR_ACK_FEEDBACK_SCOPE", "all")
SIM_ARGS = os.environ.get("CMR_NOC16_SIM_ARGS", "")
RX_CAPTURE_NS = os.environ.get("CMR_NOC16_RX_CAPTURE_NS", "0.09")
STRUCTURAL_ENDPOINTS = os.environ.get("CMR_NOC16_STRUCTURAL_ENDPOINTS", "0") == "1"
# Diagnostic noFIFO: omit the eight inter-level FIFOs.  RX=90 ps is the
# smallest GLS capture window that passed TAB/VCTM p50-p90.
USE_CIRCULAR_FIFO = os.environ.get("CMR_USE_CIRCULAR_FIFO", "0") == "1"
BYPASS_INTERLEVEL_FIFO = os.environ.get("CMR_BYPASS_INTERLEVEL_FIFO", "1") == "1"
if BYPASS_INTERLEVEL_FIFO:
    USE_CIRCULAR_FIFO = False
CUSTOM_CASE_FILE = os.environ.get("CMR_NOC16_CASE_FILE", "").strip()
CUSTOM_CASE_NAME = os.environ.get("CMR_NOC16_CASE_NAME", "").strip()
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
CIRCULAR_RTL = (
    "CircularFIFO.v",
    "WriteControlBlock.v",
    "ReadControlBlock.v",
    "CircularWriteCounter.v",
    "CircularReadCounter.v",
)
CMR_RESOURCE = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"


def connect():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
        compress=False,
    )
    transport = client.get_transport()
    if transport is not None:
        transport.set_keepalive(30)
    return client


def job_id(text):
    match = re.search(r"Job <(\d+)>", text)
    if not match:
        raise RuntimeError("LSF submission failed: " + text)
    return match.group(1)


def wait_job(client, jid, label, allow_exit=False):
    for poll in range(360):
        response = remote_run(
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
            return
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            if allow_exit and state == "EXIT":
                print("JOB_FAIL_FAST_EXIT", label, jid, state, flush=True)
                return
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


def generate_rtl():
    generated = REPO / "generated_cmr" / "noc16"
    rtl = generated / "NoC_16nodes.v"
    text = rtl.read_text(encoding="utf-8") if rtl.is_file() else ""
    has_circular = "CircularFifo " in text
    has_async = bool(re.search(
        r"AsyncFifo(?:_\d+)?\s+(?:upwardLinkFifos_|downwardLinkFifos_)", text))
    uses_bypass = bool(text) and not has_circular and not has_async
    need_emit = (
        os.environ.get("CMR_FORCE_EMIT", "0") == "1"
        or not rtl.is_file()
        or uses_bypass != BYPASS_INTERLEVEL_FIFO
        or ((not BYPASS_INTERLEVEL_FIFO) and has_circular != USE_CIRCULAR_FIFO)
    )
    if need_emit:
        env = os.environ.copy()
        env["ASYNC_PRIMITIVES"] = "asic"
        env["CMR_BYPASS_INTERLEVEL_FIFO"] = "1" if BYPASS_INTERLEVEL_FIFO else "0"
        env["CMR_USE_CIRCULAR_FIFO"] = "1" if USE_CIRCULAR_FIFO else "0"
        sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
        subprocess.run(
            [sbt, "runMain NoC.CMR.CMRNoC16Main"],
            cwd=REPO,
            env=env,
            check=True,
        )
        text = rtl.read_text(encoding="utf-8")
    if re.search(r"LanePhaseAdapter", text):
        raise SystemExit("generated Thin NoC16 must not instantiate LanePhaseAdapter")
    grant_and = re.findall(
        r"assign InputPortModules_\d+_io_TailPassed_\d+ = [^;]*Grant[^;]*;",
        text,
    )
    if grant_and:
        raise SystemExit("generated TailPassed still ANDs Grant: " + grant_and[0])
    direct_tp = re.findall(
        r"assign InputPortModules_\d+_io_TailPassed_\d+ = "
        r"OutputPortModules_\d+_io_TailPassed_\d+;",
        text,
    )
    if len(direct_tp) != 100:
        raise SystemExit(
            "generated 1-lane TailPassed assigns=%d expected=100" % len(direct_tp)
        )
    async_count = len(re.findall(r"AsyncFifo(?:_\d+)?\s+(?:upwardLinkFifos_|downwardLinkFifos_)", text))
    circular_count = len(re.findall(r"CircularFifo(?:_\d+)?\s+(?:upwardLinkFifos_|downwardLinkFifos_)", text))
    if BYPASS_INTERLEVEL_FIFO:
        expected_async = 0
        expected_circular = 0
    else:
        expected_async = 0 if USE_CIRCULAR_FIFO else 8
        expected_circular = 8 if USE_CIRCULAR_FIFO else 0
    if async_count != expected_async or circular_count != expected_circular:
        raise SystemExit(
            "generated Thin NoC16 FIFO mismatch async=%d circular=%d expected async=%d circular=%d"
            % (async_count, circular_count, expected_async, expected_circular)
        )
    print(
        "LOCAL_EMIT bypass=%s circular=%s async_fifo=%d circular_fifo=%d"
        % (BYPASS_INTERLEVEL_FIFO, USE_CIRCULAR_FIFO, async_count, circular_count),
        flush=True,
    )
    return generated


def main():
    refuse_overwrite(RUN_ID, action="thin-noc16")
    if ACK_FEEDBACK_BUFFER_STAGES not in ("0", "1", "2"):
        raise SystemExit("CMR_ACK_FEEDBACK_BUFFER_STAGES must be 0, 1, or 2")
    generated = generate_rtl()
    async_resource = REPO / "src" / "main" / "resources" / "ASYNC"
    files = {generated / "NoC_16nodes.v": "rtl/NoC_16nodes.v"}
    for name in (
        "DelayElement_ASIC.v", "Mutex2_ASIC.v", "Mutex4.v", "MullerC2.v",
        "DLatchBank.v", "V2CloseEvent.v",
    ):
        files[async_resource / name] = "rtl/" + name
    for name in (
        "CMRFlattenedTAC.v", "CMRMutexN.v", "Toggle.v", "HeadPredictor.v",
        "PhaseSelector.v", "AddressRegisterUnit.v", "InternalAckModule.v",
        "RouteSelAnd2.v", "OPMSelector.v", "PhaseResetDLatch.v",
        "WriteControlUnit.v", "WriteCounter.v", "WriteAckGenerator.v",
        "ReadControlUnit.v", "ReadCounter.v", "ReadRequestGenerator.v",
        "ReadPhaseSelector.v", "ReadAckGenerator.v",
    ) + CIRCULAR_RTL:
        files[CMR_RESOURCE / name] = "rtl/" + name
    files.update({
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_noc16.tcl": "scripts/dc/run_dc_cmr_noc16.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh": "scripts/run_gls_cmr_noc16.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv":
            "sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv":
        "sim/tb/tb_noc16_async_boundary.sv",
    })
    if STRUCTURAL_ENDPOINTS:
        files.update({
            REPO / "sim/AsyncNoC/async_endpoint_source_turnaround_delay.sv":
                "sim/tb/async_endpoint_source_turnaround_delay.sv",
            REPO / "src/main/resources/ASYNC/AsyncEndpointAckDelay.v":
                "sim/tb/async_endpoint_ack_delay.sv",
            REPO / "sim/AsyncNoC/async_endpoint_bank20.sv":
                "sim/tb/async_endpoint_bank20.sv",
            REPO / "sim/AsyncNoC/async_noc16_boundary_dut.sv":
                "sim/tb/async_noc16_boundary_dut.sv",
            REPO / "src/main/resources/ASYNC/MousetrapStage.v":
                "sim/tb/MousetrapStage.v",
            REPO / "src/main/resources/ASYNC/DLatchBank.v": "sim/tb/DLatchBank.v",
        })
    if PHASE_SELECTOR_PROBE:
        files[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_phase_selector_probe.sv"] = \
            "sim/tb/tb_cmr_thin_phase_selector_probe.sv"
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing NoC16 input files: " + ", ".join(missing))

    client = connect()
    directories = (
        "rtl scripts/dc scripts sim/tb sim/work outputs reports/dc logs/dc "
        "logs/gls results/%s/csv work" % RUN_ID
    )
    remote_run(client, "mkdir -p " + " ".join(ROOT + "/" + d for d in directories.split()))

    # The canonical harness is copied server-side.  Large p50 cases remain in
    # ULTRA_ROOT and are referenced in place below.
    copy_cmd = (
        "cp {u}/sim/tb/async_noc16_port_adapter.sv {c}/sim/tb/ && "
        "cp {u}/sim/tb/tb_noc16_async_boundary.sv "
        "{c}/sim/tb/tb_noc16_async_boundary.ultra_reference.sv"
    ).format(u=shlex.quote(ULTRA_ROOT), c=shlex.quote(ROOT))
    output = remote_run(client, copy_cmd)
    if output.strip():
        print(output, flush=True)

    if CUSTOM_CASE_FILE:
        remote_cases = {CUSTOM_CASE_NAME or Path(CUSTOM_CASE_FILE).stem: CUSTOM_CASE_FILE}
    else:
        remote_cases = {name: ULTRA_ROOT + "/sim/cases/" + name + ".case" for name in CASES}
    case_hashes = {}
    for name, path in remote_cases.items():
        check = remote_run(client, "test -s %s && sha256sum %s" % (shlex.quote(path), shlex.quote(path)))
        hashes = re.findall(r"\b[0-9a-f]{64}\b", check)
        if not hashes:
            raise RuntimeError("missing remote case: " + path)
        case_hashes[name] = hashes[0]
        print("REMOTE_CASE", name, hashes[0], path, flush=True)

    sftp = client.open_sftp()
    upload_hashes = {}
    for source, destination in files.items():
        print("UPLOAD", destination, flush=True)
        upload_hashes[destination] = atomic_put(client, sftp, source, ROOT + "/" + destination)
    sftp.close()
    remote_run(client, "chmod +x %s/scripts/run_gls_cmr_noc16.sh" % ROOT)

    dc_wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
    dc_log = ROOT + "/logs/dc/" + RUN_ID + ".log"
    delay_exports = []
    for key in (
        "CMR_RCU_MATCHED_DELAY_STEPS",
        "CMR_RCU_MATCHED_DELAY_UNIT_PS",
        "CMR_RCU_MATCHED_BUF_STAGES",
        "CMR_OPM_ACKIN_DELAY_STEPS",
        "CMR_OPM_ACKIN_DELAY_UNIT_PS",
    ):
        val = os.environ.get(key)
        if val:
            delay_exports.append("%s=%s" % (key, shlex.quote(val)))
    delay_export = (" " + " ".join(delay_exports)) if delay_exports else ""
    dc_body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
        "CMR_ACK_FEEDBACK_BUFFER_STAGES=%s CMR_ACK_FEEDBACK_SCOPE=%s "
        "CMR_USE_CIRCULAR_FIFO=%s CMR_BYPASS_INTERLEVEL_FIFO=%s%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_noc16.tcl\n"
        % (ROOT, shlex.quote(RUN_ID), shlex.quote(ACK_FEEDBACK_BUFFER_STAGES),
           shlex.quote(ACK_FEEDBACK_SCOPE),
           "1" if USE_CIRCULAR_FIFO else "0",
           "1" if BYPASS_INTERLEVEL_FIFO else "0", delay_export, ROOT, ROOT)
    )
    sftp = client.open_sftp()
    atomic_put_bytes(client, sftp, dc_body.encode(), dc_wrapper)
    sftp.close()
    remote_run(client, "chmod +x %s" % dc_wrapper)
    dc_submit = remote_run(
        client,
        "bsub -n 8 -o %s -e %s.err -J cmr_noc16_dc_%s %s"
        % (dc_log, dc_log, RUN_ID, dc_wrapper),
    )
    dc_job = job_id(dc_submit)
    print("DC_JOB", dc_job, flush=True)
    dc_failed = False
    try:
        wait_job(client, dc_job, "dc")
    except Exception:
        dc_failed = True
    dc_text = remote_run(
        client,
        "grep -h -E '^CMR_NOC16_|^CMR_RCU_|^CMR_CFIFO_|^CMR_INNER_|^CMR_DATAPATH_|^CMR_DEL_SHRINK|^Error:' "
        "%s %s.err 2>/dev/null; echo '---TAIL---'; tail -n 40 %s %s.err 2>/dev/null"
        % (dc_log, dc_log, dc_log, dc_log),
    )
    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "dc.log").write_text(dc_text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    try:
        fetch_tree(sftp, ROOT + "/reports/dc/" + RUN_ID, RESULT / "reports_dc")
    except IOError:
        pass
    sftp.close()
    print(dc_text[-12000:], flush=True)
    if dc_failed or "CMR_NOC16_DC_PASS" not in dc_text:
        raise RuntimeError("CMR NoC16 DC failed")

    if SKIP_SDF:
        print("CMR_NOC16_DC_ONLY_PASS", RUN_ID, flush=True)
        client.close()
        return

    jobs = {}
    for name, case_path in remote_cases.items():
        wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (RUN_ID, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s CMR_NOC16_CASE_NAME=%s CMR_NOC16_CASE_FILE=%s CMR_NOC16_PHASE_SELECTOR_PROBE=%s CMR_NOC16_STRUCTURAL_ENDPOINTS=%s CMR_NOC16_RX_CAPTURE_NS=%s CMR_NOC16_SIM_ARGS=%s\n"
            "exec bash %s/scripts/run_gls_cmr_noc16.sh\n"
            % (ROOT, shlex.quote(RUN_ID), shlex.quote(name), shlex.quote(case_path), "1" if PHASE_SELECTOR_PROBE else "0", "1" if STRUCTURAL_ENDPOINTS else "0", shlex.quote(RX_CAPTURE_NS), shlex.quote(SIM_ARGS), ROOT)
        )
        remote_run(client, "mkdir -p %s/logs/gls/%s" % (ROOT, RUN_ID))
        sftp = client.open_sftp()
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        sftp.close()
        remote_run(client, "chmod +x %s" % wrapper)
        submit = remote_run(
            client,
            "bsub -n 8 -o %s/logs/gls/%s/sdf_%s.bsub.log -e %s/logs/gls/%s/sdf_%s.bsub.err -J cmr_noc16_%s_%s %s"
            % (ROOT, RUN_ID, name, ROOT, RUN_ID, name, RUN_ID, name, wrapper),
        )
        jobs[name] = job_id(submit)
        print("SDF_JOB", name, jobs[name], flush=True)
        wait_job(client, jobs[name], "sdf_" + name, allow_exit=True)
        base = ROOT + "/logs/gls/%s/sdf/%s" % (RUN_ID, name)
        quick_log = remote_run(client, "cat %s/run.log 2>/dev/null" % base)
        quick_annotate = remote_run(client, "cat %s/sdf_annotate.log 2>/dev/null" % base)
        quick_errors = re.search(r"Total errors:\s*(\d+)", quick_annotate)
        quick_pass = (
            "TB_RESULT PASS" in quick_log
            and "Doing SDF annotation ...... Done" in quick_log
            and quick_errors is not None
            and int(quick_errors.group(1)) == 0
            and not any(token in quick_log for token in (
                "IFNSDFA", "TB_X_FAIL", "TB_UNEXPECTED_FAIL",
                "TB_STALL_FAIL", "TB_HARD_TIMEOUT", "Timing violation",
            ))
        )
        if not quick_pass:
            print("SDF_STOP_AFTER_FAILURE", name, flush=True)
            break

    status = {
        "run_id": RUN_ID,
        "remote_root": ROOT,
        "case_source": "explicit remote case" if CUSTOM_CASE_FILE else "remote Ultra sim/cases (not uploaded)",
        "ack_feedback_buffer_stages": int(ACK_FEEDBACK_BUFFER_STAGES),
        "ack_feedback_scope": ACK_FEEDBACK_SCOPE,
        "sim_args": SIM_ARGS,
        "structural_endpoints": STRUCTURAL_ENDPOINTS,
        "use_circular_fifo": USE_CIRCULAR_FIFO,
        "bypass_interlevel_fifo": BYPASS_INTERLEVEL_FIFO,
        "case_hashes": case_hashes,
        "upload_hashes": upload_hashes,
        "dc_job": dc_job,
        "cases": {},
    }
    all_pass = True
    for name in remote_cases:
        if name not in jobs:
            status["cases"][name] = {
                "skipped": True,
                "reason": "previous case failed",
            }
            all_pass = False
            continue
        base = ROOT + "/logs/gls/%s/sdf/%s" % (RUN_ID, name)
        run_log = remote_run(client, "cat %s/run.log 2>/dev/null" % base)
        annotate = remote_run(client, "cat %s/sdf_annotate.log 2>/dev/null" % base)
        errors = re.search(r"Total errors:\s*(\d+)", annotate)
        boundary_x_lines = [
            line for line in run_log.splitlines()
            if "TB_DEBUG port_state" in line
            and re.search(r"(?:^|\s)(?:in_req|in_ack|out_req|out_ack)=[xXzZ](?:\s|$)", line)
        ]
        entry = {
            "job_id": jobs[name],
            "tb_pass": "TB_RESULT PASS" in run_log,
            "annotation_done": "Doing SDF annotation ...... Done" in run_log,
            "annotation_errors": int(errors.group(1)) if errors else None,
            "ifnsdfa": "IFNSDFA" in run_log,
            # The inherited Ultra bench emits final boundary states even when
            # it does not print TB_X_FAIL.  Treat an X/Z in those stable final
            # Req/Ack states as a real X failure as well.
            "x_failure": "TB_X_FAIL" in run_log or "TB_PROTOCOL_X" in run_log or bool(boundary_x_lines),
            "unexpected_failure": "TB_UNEXPECTED_FAIL" in run_log,
            "stall_failure": "TB_STALL_FAIL" in run_log,
            "hard_timeout": "TB_HARD_TIMEOUT" in run_log,
            "boundary_x_count": len(boundary_x_lines),
            "first_boundary_x": boundary_x_lines[0] if boundary_x_lines else None,
            "timing_violation_count": run_log.count("Timing violation"),
            "setup_count": run_log.count("$setup("),
            "hold_count": run_log.count("$hold("),
            "first_failure": next((line for line in run_log.splitlines() if any(token in line for token in (
                "TB_RESULT FAIL", "TB_X_FAIL", "TB_UNEXPECTED_FAIL",
                "TB_STALL_FAIL", "TB_HARD_TIMEOUT", "TB_PROTOCOL_X",
                "TB_FATAL", "Timing violation",
            ))), None),
        }
        status["cases"][name] = entry
        passed = entry["tb_pass"] and entry["annotation_done"] and entry["annotation_errors"] == 0 and not entry["ifnsdfa"] and not entry["x_failure"] and not entry["unexpected_failure"] and not entry["stall_failure"] and not entry["hard_timeout"] and entry["timing_violation_count"] == 0
        all_pass &= passed
        print("SDF_CASE", name, "PASS" if passed else "FAIL", entry, flush=True)

    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    sftp = client.open_sftp()
    for remote, local in (
        (ROOT + "/reports/dc/" + RUN_ID, RESULT / "reports_dc"),
        (ROOT + "/logs/gls/" + RUN_ID, RESULT / "logs_gls"),
    ):
        fetch_tree(sftp, remote, local)
    sftp.close()
    client.close()
    print("LOCAL_RESULT", RESULT, flush=True)
    if not all_pass:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
