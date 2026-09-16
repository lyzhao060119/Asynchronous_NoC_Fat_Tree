#!/usr/bin/env python3
"""PROP_temp64 experiment flow: remote DC, then ASAP TOPO-UR SDF GLS scan.

Usage:
  python run_remote_prop_temp64.py dc [--static4] [--run-id ID] [--submit-only]
  python run_remote_prop_temp64.py gls [--static4] [--run-id ID] [--submit-only]
  python run_remote_prop_temp64.py all [--static4] [--run-id ID]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import sys
import time
from datetime import datetime
from pathlib import Path

import paramiko

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from cmr_frozen_run_ids import (  # noqa: E402
    FROZEN_PROP_TEMP64_NETLIST_RUN_ID,
    refuse_overwrite,
    require_emit_locked_delays,
)
from run_remote_cmr_fat_tree_noc16_sdf import (  # noqa: E402
    connect,
    job_id,
    remote_run_retry,
    wait_job,
)
from run_remote_cmr_noc64_sdf import collect_gls_result, shared_input_files  # noqa: E402
from _tmp_paper64_common import LOADS  # noqa: E402

REPO = HERE.parents[2]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
CASE_DIR = HERE / "generated_cases" / "20260913_prop_temp64_asap_m5_500_202701" / "cases"
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')
LOGIN_HOSTS = ("192.168.2.9", "192.168.2.8")
FROZEN_NETLIST = FROZEN_PROP_TEMP64_NETLIST_RUN_ID
STATE_DIR = HERE / "generated_cases" / "20260913_prop_temp64_asap_m5_500_202701"


def dut_name() -> str:
    return os.environ.get("PROP_TEMP64_DUT_NAME", "PROP_temp64")


def static4() -> bool:
    return dut_name() == "PROP_temp64_static4"


def dc_marker() -> str:
    return "PROP_TEMP64_STATIC4_DC_PASS" if static4() else "PROP_TEMP64_DC_PASS"


def output_files() -> tuple[str, str, str, str]:
    name = dut_name()
    return (name + ".ddc", name + "_post.v", name + ".sdf", name + ".sdc")


def state_dir() -> Path:
    return STATE_DIR / ("static4" if static4() else "dynamic")


def case_name(load: int) -> str:
    return "TOPO-UR_n64_s202701_m%d_PROP_temp64_top16" % load


def case_names(loads=None) -> list[str]:
    selected = LOADS if loads is None else loads
    return [case_name(load) for load in selected]


def checked_id(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise ValueError("unsafe run ID")
    refuse_overwrite(value, action="PROP_temp64")
    return value


def connect_failover(attempts_per_host: int = 2):
    last = None
    for host in LOGIN_HOSTS:
        os.environ["C1_HOST"] = host
        print("LOGIN_TRY", host, flush=True)
        try:
            client = connect(attempts=attempts_per_host)
            print("LOGIN_OK", host, flush=True)
            return client
        except Exception as exc:
            last = exc
            print("LOGIN_FAIL", host, exc, flush=True)
    raise RuntimeError("all login nodes failed: %s" % last)


def remote(client, command: str):
    return remote_run_retry(client, command)


def upload(client, local: Path, dest: str):
    data = local.read_bytes().replace(b"\r\n", b"\n")
    expected = hashlib.sha256(data).hexdigest()
    temporary = dest + ".upload_" + str(os.getpid())
    for attempt in range(5):
        try:
            sftp = client.open_sftp()
            with sftp.file(temporary, "wb") as handle:
                for offset in range(0, len(data), 32768):
                    handle.write(data[offset : offset + 32768])
                handle.flush()
            if sftp.stat(temporary).st_size != len(data):
                raise RuntimeError("size mismatch " + dest)
            client, output = remote(client, "sha256sum " + shlex.quote(temporary))
            if expected not in output:
                raise RuntimeError("SHA-256 mismatch " + dest)
            try:
                sftp.remove(dest)
            except IOError:
                pass
            sftp.rename(temporary, dest)
            sftp.close()
            print("UPLOAD_OK", dest, len(data), flush=True)
            return client
        except (OSError, EOFError, paramiko.SSHException, RuntimeError) as exc:
            print("UPLOAD_RETRY", attempt, dest, str(exc), flush=True)
            try:
                client.close()
            except Exception:
                pass
            client = connect_failover()
    raise RuntimeError("upload failed " + dest)


def put_text(client, text: str, dest: str):
    from tempfile import NamedTemporaryFile

    with NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".sh", delete=False) as tmp:
        tmp.write(text.replace("\r\n", "\n"))
        path = Path(tmp.name)
    try:
        return upload(client, path, dest)
    finally:
        path.unlink(missing_ok=True)


def require_cases(loads=None) -> list[str]:
    names = case_names(loads)
    missing = [n for n in names if not (CASE_DIR / (n + ".case")).is_file()]
    if missing:
        raise SystemExit("missing cases (run gen_prop_temp64_cases.py): " + ",".join(missing[:6]))
    return names


def dc(client, run_id: str, submit_only: bool, reuse_rtl_run_id: str | None = None):
    name = dut_name()
    source_dir = "prop_temp64_static4" if static4() else "prop_temp64"
    dut = REPO / "generated_cmr" / source_dir / (name + ".v")
    if not dut.is_file():
        raise FileNotFoundError(dut)
    require_emit_locked_delays(
        dut.read_text(encoding="utf-8"), label=name, ackin_unit_ps=50
    )
    client, exists = remote(
        client, "test -e %s/outputs/%s && echo EXISTS || echo NEW" % (ROOT, run_id)
    )
    if "EXISTS" in exists:
        raise RuntimeError("run output already exists: " + run_id)
    rtl = "%s/rtl/prop_temp64_%s" % (ROOT, run_id)
    client, _ = remote(
        client,
        "mkdir -p %s %s/scripts/prop_temp64_%s %s/logs/dc %s/outputs %s/reports/dc %s/work"
        % (rtl, ROOT, run_id, ROOT, ROOT, ROOT, ROOT),
    )
    files = {}
    if reuse_rtl_run_id is None:
        files = {
            source: rtl + "/" + Path(dest).name
            for source, dest in shared_input_files().items()
            if dest.startswith("rtl/")
        }
        files[dut] = rtl + "/" + name + ".v"
    files[HERE / "run_dc_prop_temp64.tcl"] = (
        "%s/scripts/prop_temp64_%s/run_dc_prop_temp64.tcl" % (ROOT, run_id)
    )
    for source, dest in files.items():
        client = upload(client, source, dest)
    log = "%s/logs/dc/%s.log" % (ROOT, run_id)
    wrapper = "%s/logs/dc/%s.sh" % (ROOT, run_id)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s PROP_TEMP64_RUN_ID=%s PROP_TEMP64_DUT_NAME=%s CMR_EXPECTED_SELECTORS=%s PROP_TEMP64_RTL_DIR=%s CMR_BYPASS_INTERLEVEL_FIFO=1 "
        "CMR_LANE01_BUF_STAGES=0 "
        "CMR_RCU_MATCHED_DELAY_STEPS=1 CMR_RCU_MATCHED_DELAY_UNIT_PS=50 "
        "CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS=150 "
        "CMR_OPM_ACKIN_DELAY_UNIT_PS=50\n"
        "exec dc_shell-t -64 -f %s/scripts/prop_temp64_%s/run_dc_prop_temp64.tcl\n"
        % (ROOT, run_id, name, "0" if static4() else "128", rtl if reuse_rtl_run_id is None else "%s/rtl/prop_temp64_%s" % (ROOT, reuse_rtl_run_id), ROOT, run_id)
    )
    client = put_text(client, body, wrapper)
    client, _ = remote(client, "chmod +x " + shlex.quote(wrapper))
    bsub = "bsub -n 16 %s -o %s -e %s.err -J %s %s" % (
        HOSTS,
        shlex.quote(log),
        shlex.quote(log),
        shlex.quote("prop_temp64_dc_" + run_id),
        shlex.quote(wrapper),
    )
    client, submitted = remote(client, bsub)
    jid = job_id(submitted)
    print("PROP_TEMP64_DC_SUBMITTED", run_id, jid, flush=True)
    state = {
        "run_id": run_id,
        "dc_job": jid,
        "stage": "dc_submitted",
        "cases": case_names(),
        "injection": "v3_exp_header_asap_body",
        "loads": list(LOADS),
    }
    state_path = state_dir() / "launch_state.json"
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    if submit_only:
        print("PROP_TEMP64_DC_SUBMIT_ONLY", run_id, jid, flush=True)
        return client, jid
    client = wait_job(client, jid, "prop_temp64_dc", polls=960, allow_exit=True)
    client = validate_dc(client, run_id)
    return client, jid


def validate_netlist(client, netlist_run_id: str):
    expected = output_files()
    client, files = remote(
        client,
        "for f in %s; do test -s %s/outputs/%s/$f || echo MISSING:$f; done"
        % (" ".join(expected), ROOT, netlist_run_id),
    )
    if "MISSING:" in files:
        raise RuntimeError("PROP_temp64 frozen netlist incomplete: " + files)
    print("PROP_TEMP64_NETLIST_OK", netlist_run_id, flush=True)
    return client


def validate_dc(client, run_id: str):
    expected = output_files()
    marker = dc_marker()
    log = "%s/logs/dc/%s.log" % (ROOT, run_id)
    retry_log = "%s/logs/dc/%s.retry.log" % (ROOT, run_id)
    client, output = remote(
        client,
        "cat %s %s.err %s %s.err 2>/dev/null | tail -n 240"
        % (log, log, retry_log, retry_log),
    )
    print(output, flush=True)
    client, files = remote(
        client,
        "for f in %s; do test -s %s/outputs/%s/$f || echo MISSING:$f; done"
        % (" ".join(expected), ROOT, run_id),
    )
    # TCL source contains puts "PROP_TEMP64_DC_FAIL ..."; only real marker lines count.
    real_fail = any(
        line.strip().startswith("PROP_TEMP64_DC_FAIL") for line in output.splitlines()
    )
    real_pass = any(
        line.strip().startswith(marker) for line in output.splitlines()
    )
    if not real_pass or real_fail or "MISSING:" in files:
        raise RuntimeError("PROP_temp64 DC did not pass: " + files)
    print(marker + "_VALIDATED", run_id, flush=True)
    return client


def wait_dc_pass(client, run_id: str, polls: int = 960):
    log = "%s/logs/dc/%s.log" % (ROOT, run_id)
    marker = dc_marker()
    post = output_files()[1]
    for i in range(polls):
        # Ignore TCL source echoes like: puts "PROP_TEMP64_DC_FAIL ..."
        client, out = remote(
            client,
            "grep -E 'PROP_TEMP64(_STATIC4)?_DC_PASS|PROP_TEMP64(_STATIC4)?_DC_FAIL' %s 2>/dev/null | "
            "grep -v 'puts \\\"PROP_TEMP64' | tail -n 5; "
            "test -s %s/outputs/%s/%s && echo HAS_POST || echo NO_POST; "
            "bjobs -u ghy19 2>/dev/null | grep -F prop_temp64_dc_%s | head -n 2 || true"
            % (log, ROOT, run_id, post, run_id),
        )
        print("DC_POLL", i, out.replace("\n", " | "), flush=True)
        # Only treat a real marker line (not a puts "..." template) as FAIL.
        if any(
            line.strip().startswith("PROP_TEMP64_DC_FAIL")
            for line in out.splitlines()
        ):
            raise RuntimeError("PROP_temp64 DC failed")
        if marker in out and "HAS_POST" in out:
            return validate_dc(client, run_id)
        time.sleep(60)
    raise RuntimeError("PROP_temp64 DC poll timeout")


def gls(client, run_id: str, submit_only: bool, netlist_run_id: str | None = None, loads=None):
    selected_loads = list(LOADS if loads is None else loads)
    names = require_cases(selected_loads)
    netlist_id = (
        netlist_run_id
        or os.environ.get("PROP_TEMP64_NETLIST_RUN_ID", "").strip()
        or run_id
    )
    if netlist_id != run_id:
        client = validate_netlist(client, netlist_id)
        print("PROP_TEMP64_SKIP_DC netlist=%s gls_run=%s" % (netlist_id, run_id), flush=True)
    else:
        client = validate_dc(client, run_id)
    sim = "%s/sim/prop_temp64_%s" % (ROOT, run_id)
    client, _ = remote(
        client,
        "mkdir -p %s/cases %s/scripts/prop_temp64_%s %s/results/%s/csv %s/logs/gls/%s"
        % (sim, ROOT, run_id, ROOT, run_id, ROOT, run_id),
    )
    files = {
        HERE / "run_gls_prop_temp64.sh": "%s/scripts/prop_temp64_%s/run_gls_prop_temp64.sh"
        % (ROOT, run_id),
        REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": sim
        + "/async_prop_temp64_port_adapter.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": sim
        + "/tb_noc64_async_boundary.sv",
        HERE / "tb_cmr_noc64_async_boundary_failfast.sv": sim
        + "/tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py": sim + "/patch_gls_netlist.py",
    }
    for name in names:
        files[CASE_DIR / (name + ".case")] = sim + "/cases/" + name + ".case"
    model = CASE_DIR.parent / "INJECTION_MODEL.json"
    if model.is_file():
        files[model] = sim + "/cases/INJECTION_MODEL.json"
    for source, dest in files.items():
        client = upload(client, source, dest)
    shell = "%s/scripts/prop_temp64_%s/run_gls_prop_temp64.sh" % (ROOT, run_id)
    client, _ = remote(client, "chmod +x " + shlex.quote(shell))
    jobs = []
    for name in names:
        mode = "sdf"
        wrapper = "%s/logs/gls/%s/%s_%s.sh" % (ROOT, run_id, mode, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s PROP_TEMP64_RUN_ID=%s PROP_TEMP64_DUT_NAME=%s "
            "PROP_TEMP64_NETLIST_RUN_ID=%s PROP_TEMP64_MODE=%s "
            "PROP_TEMP64_CASE_NAME=%s PROP_TEMP64_CASE_FILE=%s/cases/%s.case "
            "PROP_TEMP64_RX_CAPTURE_NS=0.1\n"
            "exec bash %s\n"
            % (ROOT, run_id, dut_name(), netlist_id, mode, name, sim, name, shell)
        )
        client = put_text(client, body, wrapper)
        client, _ = remote(client, "chmod +x " + shlex.quote(wrapper))
        log = "%s/logs/gls/%s/%s_%s.job.log" % (ROOT, run_id, mode, name)
        client, submitted = remote(
            client,
            "bsub -n 8 %s -o %s -e %s.err -J %s %s"
            % (
                HOSTS,
                shlex.quote(log),
                shlex.quote(log),
                shlex.quote("pt64_%s_m%s" % (mode, name.split("_m")[1].split("_")[0])),
                shlex.quote(wrapper),
            ),
        )
        jid = job_id(submitted)
        jobs.append({"case": name, "mode": mode, "job": jid, "netlist": netlist_id})
        print("PROP_TEMP64_GLS_SUBMITTED", mode, name, jid, flush=True)
    state_path = state_dir() / "launch_state.json"
    state = {}
    if state_path.is_file():
        state = json.loads(state_path.read_text(encoding="utf-8"))
    state.update(
        {
            "run_id": run_id,
            "design": dut_name(),
            "netlist_run_id": netlist_id,
            "stage": "gls_submitted",
            "gls_jobs": jobs,
            "loads": selected_loads,
        }
    )
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    if submit_only:
        print("PROP_TEMP64_GLS_SUBMIT_ONLY jobs=%d" % len(jobs), flush=True)
        return client
    results = []
    for row in jobs:
        client = wait_job(
            client, row["job"], row["mode"] + "_" + row["case"], polls=960, allow_exit=True
        )
        client, result, passed = collect_gls_result(
            client, run_id, row["mode"], row["case"], row["job"]
        )
        results.append({"case": row["case"], **result, "pass": passed})
        print("PROP_TEMP64_GLS_RESULT", json.dumps(results[-1]), flush=True)
    local = HERE / "results" / run_id
    local.mkdir(parents=True, exist_ok=True)
    (local / "prop_temp64_results.json").write_text(
        json.dumps(results, indent=2) + "\n", encoding="utf-8"
    )
    if not all(r.get("pass") for r in results):
        raise RuntimeError("PROP_temp64 GLS had failures")
    print("PROP_TEMP64_GLS_VALIDATED", run_id, flush=True)
    return client


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("dc", "gls", "all", "waitdc"))
    parser.add_argument(
        "--run-id",
        default=os.environ.get("PROP_TEMP64_RUN_ID")
        or datetime.now().strftime("%Y%m%d_%H%M%S") + "_prop_temp64_asap_uc_m5_500",
    )
    parser.add_argument(
        "--netlist-run-id",
        default=os.environ.get("PROP_TEMP64_NETLIST_RUN_ID", "").strip() or None,
        help="SKIP_DC: reuse frozen outputs under this id (default for gls: %s)"
        % FROZEN_NETLIST,
    )
    parser.add_argument(
        "--submit-only",
        action="store_true",
        default=os.environ.get("CMR_DESCAL_SUBMIT_ONLY", "0") == "1",
    )
    parser.add_argument(
        "--static4", action="store_true",
        help="use PROP_temp64_static4 and require zero dynamic LaneSelector cells",
    )
    parser.add_argument(
        "--reuse-rtl-run-id", default=None,
        help="DC only: reuse verified remote rtl/prop_temp64_<run-id> without upload",
    )
    parser.add_argument(
        "--loads", default=None,
        help="comma-separated GLS loads; default is the complete canonical grid",
    )
    args = parser.parse_args()
    if args.static4:
        os.environ["PROP_TEMP64_DUT_NAME"] = "PROP_temp64_static4"
    selected_loads = None
    if args.loads:
        selected_loads = [int(value.strip()) for value in args.loads.split(",") if value.strip()]
        if not selected_loads or any(value not in LOADS for value in selected_loads):
            raise SystemExit("--loads must be a nonempty subset of the canonical load grid")
    run_id = checked_id(args.run_id)
    require_cases()
    client = connect_failover()
    try:
        if args.stage == "dc":
            dc(client, run_id, submit_only=args.submit_only, reuse_rtl_run_id=args.reuse_rtl_run_id)
        elif args.stage == "waitdc":
            wait_dc_pass(client, run_id)
        elif args.stage == "gls":
            netlist = args.netlist_run_id or FROZEN_NETLIST
            gls(client, run_id, submit_only=args.submit_only, netlist_run_id=netlist, loads=selected_loads)
        else:
            # all: submit DC, wait, then submit GLS (parallel, submit-only by default for long scan)
            dc(client, run_id, submit_only=False, reuse_rtl_run_id=args.reuse_rtl_run_id)
            gls(client, run_id, submit_only=True, loads=selected_loads)
            print("PROP_TEMP64_ALL_DC_DONE_GLS_SUBMITTED", run_id, flush=True)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
