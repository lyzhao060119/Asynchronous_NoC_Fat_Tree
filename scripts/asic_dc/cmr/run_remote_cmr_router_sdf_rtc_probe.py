#!/usr/bin/env python3
"""Run a single diagnostic SDF probe against the immutable RouterL1 r6 netlist."""

import hashlib
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, remote_run
from run_remote_cmr_noc16_sdf import connect, fetch_tree, job_id, wait_job


REPO = Path(__file__).resolve().parents[3]
CMR = REPO / "scripts" / "asic_dc" / "cmr"
BASELINE = "20260925_cmr_routerl1_dff_sdf_r6"
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_ROUTER_SDF_RTC_PROBE_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_routerl1_sdf_rtc_probe_r1",
)
SOURCE_TB = REPO / "sim" / "CMR" / "testbench" / "tb_cmr_router_boundary_r6_source.sv"
PROBE_TB = REPO / "sim" / "CMR" / "testbench" / "tb_cmr_router_boundary_r6_diag.sv"
BASELINE_TB_SHA256 = "dd438ab662b50a3bfba275216424c3775d591481ad650e65127c46fe09831867"
BASELINE_DDC_SHA256 = "fb0d5c2ec62674c8553a37881913ce98321bdd30065faabe83b40f32d666fd60"
RESULT = CMR / "results" / RUN_ID


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", RUN_ID):
        raise RuntimeError("unsafe run id: " + RUN_ID)
    if RESULT.exists():
        raise RuntimeError("refusing to overwrite local probe result " + str(RESULT))
    if not SOURCE_TB.is_file() or not PROBE_TB.is_file():
        raise RuntimeError("missing frozen-source copy or diagnostic testbench")

    manifest = json.loads((CMR / "results" / BASELINE / "summary.json").read_text(encoding="utf-8"))["manifest"]
    if digest(SOURCE_TB) != BASELINE_TB_SHA256:
        raise RuntimeError("local frozen baseline testbench hash mismatch")
    if manifest["files"].get("sim/tb/tb_cmr_router_boundary_smoke.sv") != BASELINE_TB_SHA256:
        raise RuntimeError("r6 manifest testbench hash mismatch")

    local_ddc = CMR / "results" / BASELINE / "outputs" / "CMRRouter.ddc"
    local_netlist = CMR / "results" / BASELINE / "outputs" / "CMRRouter_post.v"
    local_sdf = CMR / "results" / BASELINE / "outputs" / "CMRRouter.sdf"
    if any(not p.is_file() or p.stat().st_size == 0 for p in (local_ddc, local_netlist, local_sdf)):
        raise RuntimeError("missing frozen r6 DDC/post-netlist/SDF")
    if digest(local_ddc) != BASELINE_DDC_SHA256:
        raise RuntimeError("local frozen r6 DDC hash mismatch")

    client = connect()
    remote_base = f"{ROOT}/outputs/{BASELINE}"
    remote_hashes = remote_run(
        client,
        "sha256sum %s/CMRRouter.ddc %s/CMRRouter_post.v %s/CMRRouter.sdf"
        % (shlex.quote(remote_base), shlex.quote(remote_base), shlex.quote(remote_base)),
    )
    found = {line.split()[-1]: line.split()[0] for line in remote_hashes.splitlines() if len(line.split()) >= 2}
    for name, local in (("CMRRouter.ddc", local_ddc), ("CMRRouter_post.v", local_netlist), ("CMRRouter.sdf", local_sdf)):
        expected = digest(local)
        if found.get(remote_base + "/" + name) != expected:
            client.close()
            raise RuntimeError("local/remote frozen artifact hash mismatch: " + name)

    probe_name = "tb_cmr_router_boundary_r6_diag_%s.sv" % RUN_ID
    remote_tb = ROOT + "/sim/tb/" + probe_name
    remote_log = ROOT + "/logs/gls/" + RUN_ID + "/sdf"
    remote_work = ROOT + "/sim/work/" + RUN_ID + "/sdf"
    fresh = remote_run(
        client,
        "test ! -e %s && test ! -e %s && test ! -e %s && echo FRESH"
        % (shlex.quote(remote_tb), shlex.quote(remote_log), shlex.quote(remote_work)),
    )
    if "FRESH" not in fresh:
        client.close()
        raise RuntimeError("refusing to overwrite remote probe artifacts: " + fresh)

    remote_run(client, "mkdir -p %s %s" % (shlex.quote(ROOT + "/sim/tb"), shlex.quote(ROOT + "/logs/gls/" + RUN_ID)))
    sftp = client.open_sftp()
    uploaded_hash = atomic_put(client, sftp, PROBE_TB, remote_tb)
    wrapper = ROOT + "/logs/gls/" + RUN_ID + "/sdf.sh"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_RUN_ID=%s CMR_NETLIST_RUN_ID=%s "
        "CMR_SDF_CASES=rtc_probe CMR_TB_FILE=%s CMR_TB_TOP=tb_cmr_router_boundary_smoke\n"
        "exec bash %s/scripts/run_gls_cmr_router.sh\n"
        % (shlex.quote(ROOT), shlex.quote(RUN_ID), shlex.quote(BASELINE), shlex.quote(probe_name), shlex.quote(ROOT))
    )
    atomic_remote = wrapper + ".upload"
    with sftp.file(atomic_remote, "wb") as stream:
        stream.write(body.encode())
    sftp.rename(atomic_remote, wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + shlex.quote(wrapper))
    submit = remote_run(
        client,
        "bsub -n 8 -o %s/sdf.bsub.log -e %s/sdf.bsub.err -J cmr_rtc_probe_%s %s"
        % (shlex.quote(ROOT + "/logs/gls/" + RUN_ID), shlex.quote(ROOT + "/logs/gls/" + RUN_ID),
           shlex.quote(RUN_ID), shlex.quote(wrapper)),
    )
    jid = job_id(submit)
    print("RTC_PROBE_JOB", jid, "baseline", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, jid, "routerl1_sdf_rtc_probe")

    RESULT.mkdir(parents=True)
    logs_local = RESULT / "logs_gls" / "sdf"
    sftp = client.open_sftp()
    fetch_tree(sftp, remote_log, logs_local)
    for filename in ("sdf.bsub.log", "sdf.bsub.err"):
        source = ROOT + "/logs/gls/" + RUN_ID + "/" + filename
        try:
            sftp.get(source, str(RESULT / filename))
        except OSError:
            pass
    sftp.close()

    run_log_path = logs_local / "rtc_probe" / "run.log"
    compile_path = logs_local / "compile.log"
    annotation_path = logs_local / "sdf_annotate.log"
    required = (run_log_path, compile_path, annotation_path, logs_local / "input_hashes.log")
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        client.close()
        raise RuntimeError("probe run omitted artifacts: " + ", ".join(missing))

    run_log = run_log_path.read_text(encoding="utf-8", errors="replace")
    compile_log = compile_path.read_text(encoding="utf-8", errors="replace")
    annotation_log = annotation_path.read_text(encoding="utf-8", errors="replace")
    all_text = run_log + "\n" + compile_log + "\n" + annotation_log
    result_match = re.search(
        r"TB_DIAG_RESULT complete=(\d+) req_seen=(\d+) ack_seen=(\d+) "
        r"data_last_ns=([0-9.]+) ack_ns=([0-9.]+) failures=(\d+) timeout=(\d+)",
        run_log,
    )
    no_x = "TB_RTC_X" not in run_log
    annotation_errors = re.search(r"(?im)^\s*Total errors:\s*(\d+)\s*$", annotation_log)
    annotation_error_count = int(annotation_errors.group(1)) if annotation_errors else None
    annotation_warning_count = sum(
        int(match.group(1)) for match in re.finditer(r"(?im)^\s*Total warnings:\s*(\d+)\s*$", annotation_log)
    )
    annotation_warning_types: dict[str, int] = {}
    for code in re.findall(r"(?im)^Warning-\[([^]]+)\]", annotation_log):
        annotation_warning_types[code] = annotation_warning_types.get(code, 0) + 1
    annotation_error = (
        annotation_error_count is None
        or annotation_error_count != 0
        or bool(re.search(r"(?im)^\s*(?:Error|Fatal)-\[SDFCOM|SDF Error:|IFNSDFA\b", annotation_log))
    )
    compile_error = bool(re.search(r"(?m)^(Error|Fatal)-|\*\* Error:", compile_log))
    trace_rows = [line for line in run_log.splitlines() if "TB_RTC_TRACE" in line]
    binding_seen = any("ipm3_req0=" in line and "opm0_reqin2=" in line for line in trace_rows)
    route_enabled_seen = any(re.search(r"opm0_path2=1\b", line) for line in trace_rows)
    req_event = re.search(r"TB_RTC_EVENT event=opm0_req t_ns=([0-9.]+)", run_log)
    data_event = re.search(r"TB_RTC_EVENT event=out0_data t_ns=([0-9.]+)", run_log)
    delta_ps = None
    if req_event and data_event:
        delta_ps = round((float(data_event.group(1)) - float(req_event.group(1))) * 1000.0, 3)
    diag_complete = bool(
        result_match
        and result_match.group(1) == "1"
        and result_match.group(2) == "1"
        and result_match.group(3) == "1"
        and result_match.group(7) == "0"
    )
    inputs = (logs_local / "input_hashes.log").read_text(encoding="utf-8", errors="replace")
    expected_hashes = {
        "CMRRouter_post.v": digest(local_netlist),
        "CMRRouter.sdf": digest(local_sdf),
        probe_name: hashlib.sha256(PROBE_TB.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
    }
    input_hash_pass = all(value in inputs and key in inputs for key, value in expected_hashes.items())
    summary = {
        "run_id": RUN_ID,
        "baseline": BASELINE,
        "baseline_tb_sha256": BASELINE_TB_SHA256,
        "baseline_ddc_sha256": BASELINE_DDC_SHA256,
        "baseline_post_netlist_sha256": digest(local_netlist),
        "baseline_sdf_sha256": digest(local_sdf),
        "probe_tb_sha256_uploaded": uploaded_hash,
        "probe_tb_sha256_expected": expected_hashes[probe_name],
        "input_hash_pass": input_hash_pass,
        "diag_complete": diag_complete,
        "trace_count": len(trace_rows),
        "signal_binding_observed": binding_seen,
        "route_source_enabled_observed": route_enabled_seen,
        "req_event_ns": float(req_event.group(1)) if req_event else None,
        "first_output_data_event_ns": float(data_event.group(1)) if data_event else None,
        "first_output_data_minus_req_ps": delta_ps,
        "no_x_observed": no_x,
        "sdf_annotation_error": annotation_error,
        "sdf_annotation_errors_reported": annotation_error_count,
        "sdf_annotation_warnings_reported": annotation_warning_count,
        "sdf_annotation_warning_types": annotation_warning_types,
        "compile_error": compile_error,
        "expected_baseline_data_mismatch_count": len(re.findall(r"TB_RESULT FAIL .*reason=output_data", run_log)),
        "tb_diagnostic_failures": int(result_match.group(6)) if result_match else None,
        "sta_loop_cuts_created": False,
        "production_sdc_changed": False,
        "rtl_changed": False,
    }
    (RESULT / "rtc_probe_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)
    print("LOCAL_RESULT", RESULT, flush=True)
    client.close()
    if not (input_hash_pass and diag_complete and binding_seen and route_enabled_seen and no_x and not annotation_error and not compile_error):
        raise RuntimeError("SDF RTC probe failed a binding, timing-history, X, annotation, or compile gate")


if __name__ == "__main__":
    main()
