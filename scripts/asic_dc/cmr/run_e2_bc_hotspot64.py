#!/usr/bin/env python3
"""Prepare, submit, and monitor DATE 2027 E2 frozen-netlist GLS.

This runner has no synthesis stage. New cases/work/logs live below /prjtemp;
the two archived output directories are read-only inputs.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shlex
import sys
import tarfile
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from run_remote_prop_temp64 import remote, upload  # noqa: E402
import run_remote_prop_temp64 as prop_remote  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import connect, job_id  # noqa: E402

ARCHIVE = "/home/ghy19/Asynchronous_Router_CMR"
PRJTEMP = "/prjtemp/ghy19/date2027_e2"
FROZEN = {
    "PROP_temp64": ("20260913_prop_temp64_asap_uc_m5_200", "PROP_temp64", "PROP_TEMP64_DC_PASS"),
    "FM64": ("20260913_104506_cmr_fm64_rpsdel150", "CMRMeshNoC", "CMR_MESH64_DC_PASS"),
}
LOADS = (5, 10, 20, *range(40, 501, 20), 600, 700, 800)
BENCHMARKS = ("TOPO-BC", "HOTSPOT10")
CASE_DIR = REPO / "DATE paper" / "experiments" / "intermediate" / "e2_smoke_cases"
TRACE_DIR = REPO / "DATE paper" / "experiments" / "intermediate" / "e2_smoke_traces"


def checked_run_id(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise SystemExit("unsafe run ID")
    if "core64_power" in value:
        raise SystemExit("failed core64_power namespace is forbidden")
    return value


def case_name(benchmark: str, design: str, load: int = 5) -> str:
    return f"{benchmark}_n64_s202701_m{load}_{design}_top{16 if design == 'PROP_temp64' else 0}"


def remote_root(run_id: str) -> str:
    return f"{PRJTEMP}/{run_id}"


def preflight(client):
    commands = ["set -e", f"test -d {PRJTEMP.rsplit('/', 1)[0]}", f"test -w {PRJTEMP.rsplit('/', 1)[0]}"]
    for design, (rid, prefix, marker) in FROZEN.items():
        files = [f"{prefix}.ddc", f"{prefix}_post.v", f"{prefix}.sdf", f"{prefix}.sdc"]
        commands.append(f"echo E2_NETLIST_BEGIN:{design}:{rid}")
        for name in files:
            path = f"{ARCHIVE}/outputs/{rid}/{name}"
            commands += [f"test -s {shlex.quote(path)}", f"stat -c 'SIZE:%s:%n' {shlex.quote(path)}", f"sha256sum {shlex.quote(path)}"]
        log = f"{ARCHIVE}/logs/dc/{rid}.log"
        commands.append(f"grep -q '^{marker}' {shlex.quote(log)}")
        commands.append(f"grep '^{marker}' {shlex.quote(log)} | tail -1")
        commands.append(f"echo E2_NETLIST_PASS:{design}:{rid}")
    client, out = remote(client, "\n".join(commands))
    print(out, flush=True)
    if out.count("E2_NETLIST_PASS:") != 2:
        raise RuntimeError("frozen-netlist preflight incomplete")
    return client


def require_local_smoke():
    rows = []
    for benchmark in BENCHMARKS:
        trace = TRACE_DIR / f"{benchmark}_n64_s202701_m5.jsonl"
        if not trace.is_file():
            raise SystemExit(f"missing canonical trace {trace}")
        trace_hash = hashlib.sha256(trace.read_bytes()).hexdigest()
        for design in FROZEN:
            case = CASE_DIR / (case_name(benchmark, design) + ".case")
            if not case.is_file() or case.stat().st_size < 1_000_000:
                raise SystemExit(f"missing/full-size gate failed: {case}")
            text = case.read_text(encoding="utf-8", errors="replace")[:4096]
            for marker in ("meta original_event_count 11000", "meta warmup_original_events 1000", "meta measurement_original_events 10000"):
                if marker not in text:
                    raise SystemExit(f"case metadata gate failed {case}: {marker}")
            rows.append({"benchmark": benchmark, "design": design, "case": str(case), "case_sha256": hashlib.sha256(case.read_bytes()).hexdigest(), "trace_sha256": trace_hash})
    if len(rows) != 4 or len(LOADS) != 30:
        raise SystemExit("E2 cardinality gate failed")
    return rows


def prepare(client, run_id: str, rows, reuse_case_run: str | None = None):
    root = remote_root(run_id)
    client, exists = remote(client, f"test -e {shlex.quote(root)} && echo EXISTS || echo NEW")
    if "EXISTS" in exists:
        raise RuntimeError(f"refusing to overwrite {root}")
    client, _ = remote(client, f"mkdir -p {root}/src {root}/cases {root}/jobs {root}/logs {root}/results {root}/work")
    files = {
        HERE / "run_e2_bc_hotspot64_remote.sh": f"{root}/run_e2_bc_hotspot64_remote.sh",
        REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": f"{root}/src/async_prop_temp64_port_adapter.sv",
        REPO / "sim/AsyncNoC/async_noc64_mesh_port_adapter.sv": f"{root}/src/async_noc64_mesh_port_adapter.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": f"{root}/src/tb_noc64_async_boundary.sv",
        HERE / "tb_cmr_noc64_async_boundary_failfast.sv": f"{root}/src/tb_cmr_noc64_async_boundary_failfast.sv",
    }
    for source, destination in files.items():
        client = upload(client, source, destination)
    local = HERE / "results" / run_id
    local.mkdir(parents=True, exist_ok=False)
    if reuse_case_run:
        previous = remote_root(checked_run_id(reuse_case_run))
        for row in rows:
            name = Path(row["case"]).name
            client, _ = remote(client, f"test -s {previous}/cases/{name}; cp {previous}/cases/{name} {root}/cases/{name}")
    else:
        bundle = local / "e2_smoke_cases.tar.gz"
        with tarfile.open(bundle, "w:gz") as archive:
            for row in rows:
                case = Path(row["case"])
                archive.add(case, arcname=case.name)
        # Existing text uploader normalizes CRLF bytes; tunnel the binary
        # archive through base64 and verify decoded SHA before extraction.
        encoded = local / "e2_smoke_cases.tar.gz.b64"
        encoded.write_bytes(base64.b64encode(bundle.read_bytes()))
        client = upload(client, encoded, f"{root}/cases/e2_smoke_cases.tar.gz.b64")
        archive_hash = hashlib.sha256(bundle.read_bytes()).hexdigest()
        client, out = remote(client, f"set -e; base64 --decode {root}/cases/e2_smoke_cases.tar.gz.b64 > {root}/cases/e2_smoke_cases.tar.gz; echo {archive_hash} ' {root}/cases/e2_smoke_cases.tar.gz' | sha256sum --check; tar -tzf {root}/cases/e2_smoke_cases.tar.gz >/dev/null; tar -xzf {root}/cases/e2_smoke_cases.tar.gz -C {root}/cases")
        if f"{root}/cases/e2_smoke_cases.tar.gz: OK" not in out:
            raise RuntimeError("remote compressed case archive failed SHA gate: " + out)
    expected_hashes = "\n".join(f"{row['case_sha256']}  {root}/cases/{Path(row['case']).name}" for row in rows)
    client, out = remote(client, f"set -e; chmod +x {root}/run_e2_bc_hotspot64_remote.sh; bash -n {root}/run_e2_bc_hotspot64_remote.sh; sha256sum {root}/cases/*.case; find {root}/src {root}/cases -type f -size 0 -print")
    print(out, flush=True)
    for line in expected_hashes.splitlines():
        if line not in out:
            raise RuntimeError("decompressed case SHA-256 mismatch: " + line)
    manifest = {"run_id": run_id, "commit": "21fb2ac4659a75bc4bb7ed95f77d70bb68cc7002", "dirty": True, "loads": list(LOADS), "benchmarks": list(BENCHMARKS), "designs": FROZEN, "smoke": rows, "remote_root": root}
    (local / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("E2_PREPARE_PASS", run_id, root, flush=True)
    return client


def submit(client, command: str, name: str, out: str, dep: str | None = None):
    dependency = f"-w {shlex.quote('done(' + dep + ')')} " if dep else ""
    client, text = remote(client, f"bsub -n 8 -m {shlex.quote('node21 node26 node24 node18')} {dependency}-o {shlex.quote(out)} -e {shlex.quote(out + '.err')} -J {shlex.quote(name)} {command}")
    jid = job_id(text)
    print("E2_JOB_SUBMITTED", name, jid, flush=True)
    return client, jid


def submit_smoke(client, run_id: str, rows):
    root = remote_root(run_id)
    shell = f"{root}/run_e2_bc_hotspot64_remote.sh"
    compile_jobs = {}
    for design, (netlist, _, _) in FROZEN.items():
        env = f"env E2_REMOTE_ROOT={root} E2_RUN_ID={run_id} E2_NETLIST_RUN_ID={netlist} CMR_ARCHIVE_ROOT={ARCHIVE}"
        client, jid = submit(client, f"{env} bash {shell} compile {design}", f"e2c_{run_id[-10:]}_{design}", f"{root}/jobs/compile_{design}.log")
        compile_jobs[design] = jid
    run_jobs = []
    last_design_job = dict(compile_jobs)
    for row in rows:
        design, benchmark = row["design"], row["benchmark"]
        netlist = FROZEN[design][0]
        name = case_name(benchmark, design)
        env = f"env E2_REMOTE_ROOT={root} E2_RUN_ID={run_id} E2_NETLIST_RUN_ID={netlist} CMR_ARCHIVE_ROOT={ARCHIVE} E2_CASE_NAME={name} E2_CASE_FILE={root}/cases/{name}.case"
        client, jid = submit(client, f"{env} bash {shell} run {design}", f"e2r_{run_id[-10:]}_{benchmark.replace('-', '')}_{design}", f"{root}/jobs/run_{design}_{benchmark}.log", dep=last_design_job[design])
        last_design_job[design] = jid
        run_jobs.append({"job": jid, "design": design, "benchmark": benchmark, "case": name})
    state = {"run_id": run_id, "compile_jobs": compile_jobs, "run_jobs": run_jobs, "stage": "smoke_submitted"}
    path = HERE / "results" / run_id / "state.json"
    path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("E2_SMOKE_SUBMITTED", run_id, "jobs=6", flush=True)
    return client, state


def monitor_started(client, run_id: str, state, polls: int = 60):
    root = remote_root(run_id)
    ids = list(state["compile_jobs"].values()) + [row["job"] for row in state["run_jobs"]]
    for index in range(polls):
        client, out = remote(client, f"bjobs -a {' '.join(ids)} -noheader -o 'jobid stat job_name' 2>/dev/null || true; grep -RhE 'E2_(COMPILE_PASS|CASE_RUN|CASE_PASS|CASE_FAIL)' {root}/jobs {root}/logs 2>/dev/null | tail -20 || true; find {root}/work {root}/logs -type f -name 'compile.log' -o -name 'run.log' 2>/dev/null | while read f; do test -s \"$f\" && echo E2_REAL_LOG:$f; done")
        print(f"E2_POLL {index}\n{out}", flush=True)
        states = {m.group(1): m.group(2) for m in re.finditer(r"(?m)^(\d+)\s+(PEND|RUN|DONE|EXIT)\b", out)}
        nonempty = "E2_REAL_LOG:" in out
        if any(value == "EXIT" for value in states.values()):
            raise RuntimeError("E2 smoke job exited")
        if any(value == "RUN" for value in states.values()) and nonempty:
            print("E2_SMOKE_CONFIRMED_RUNNING", run_id, flush=True)
            return client
        if "E2_CASE_RUN" in out and nonempty:
            print("E2_SMOKE_CONFIRMED_RUNNING", run_id, flush=True)
            return client
        time.sleep(10)
    raise RuntimeError("E2 smoke did not reach RUN with nonempty logs")


def smoke_status(client, run_id: str, state):
    root = remote_root(run_id)
    jobs = [str(row["job"]) for row in state["run_jobs"]]
    checks = [f"bjobs -a {' '.join(jobs)} -noheader -o 'jobid stat job_name' 2>/dev/null || true"]
    for row in state["run_jobs"]:
        base = f"{root}/logs/{row['design']}/{row['case']}"
        checks.append(f"echo CASE:{row['design']}:{row['benchmark']}:{row['job']}")
        checks.append(f"grep -hE 'E2_CASE_(PASS|FAIL)|TB_RESULT|Total errors:' {base}/stage.log {base}/run.log {base}/sdf_annotate.log 2>/dev/null | tail -5 || true")
        checks.append(f"test -s {root}/results/{row['design']}/{row['case']}.csv && echo CSV_NONZERO || true")
    client, out = remote(client, "\n".join(checks))
    print(out, flush=True)
    if "E2_CASE_FAIL" in out or re.search(r"(?m)^\d+\s+EXIT\b", out):
        raise RuntimeError("E2 M5 smoke failed; do not submit remaining load grid")
    if out.count("E2_CASE_PASS") == 4 and out.count("CSV_NONZERO") == 4 and out.count("Total errors: 0") == 4:
        print("E2_SMOKE_PASS", run_id, flush=True)
        return client, True
    return client, False


def diagnose(client, run_id: str, state):
    root = remote_root(run_id)
    checks = []
    for design in FROZEN:
        checks += [f"echo E2_COMPILE_DIAG:{design}", f"tail -n 40 {root}/work/{design}/compile.log 2>/dev/null || true", f"tail -n 15 {root}/jobs/compile_{design}.log.err 2>/dev/null || true"]
    for row in state["run_jobs"]:
        base = f"{root}/logs/{row['design']}/{row['case']}"
        checks += [f"echo E2_DIAG:{row['design']}:{row['benchmark']}", f"tail -n 30 {base}/run.log 2>/dev/null || true", f"grep -hE 'Total errors:|SDF (Error|Warning)|TB_RESULT|TB_INFO|Error:' {base}/sdf_annotate.log 2>/dev/null | tail -15 || true", f"ls -lh {base}/sdf_annotate.log {base}/run.log {root}/results/{row['design']}/{row['case']}.csv 2>/dev/null || true"]
    checks.append(f"find {root}/work {root}/logs -name sdf_annotate.log -type f -printf '%s %p\\n' 2>/dev/null | head -20")
    client, out = remote(client, "\n".join(checks))
    print(out, flush=True)
    return client


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("preflight", "smoke", "status", "wait-smoke", "diagnose"))
    parser.add_argument("--run-id", default=datetime.now().strftime("%Y%m%d_%H%M%S") + "_date2027_e2_bc_hotspot64")
    parser.add_argument("--reuse-case-run", help="copy only SHA-gated prior M5 inputs into a fresh run")
    args = parser.parse_args()
    run_id = checked_run_id(args.run_id)
    rows = require_local_smoke()
    # Login .9 has accepted SSH but stalled on remote commands; .8 is the
    # verified responsive login for this E2 run.
    os.environ["C1_HOST"] = "192.168.2.8"
    prop_remote.LOGIN_HOSTS = ("192.168.2.8",)
    client = connect(attempts=2)
    try:
        if args.stage not in ("status", "wait-smoke", "diagnose"):
            client = preflight(client)
        if args.stage == "preflight":
            return 0
        if args.stage == "smoke":
            client = prepare(client, run_id, rows, args.reuse_case_run)
            client, state = submit_smoke(client, run_id, rows)
        else:
            state = json.loads((HERE / "results" / run_id / "state.json").read_text(encoding="utf-8"))
        if args.stage == "diagnose":
            diagnose(client, run_id, state)
        if args.stage in ("smoke", "status"):
            client = monitor_started(client, run_id, state)
        if args.stage in ("status", "wait-smoke"):
            if args.stage == "wait-smoke":
                for _ in range(120):
                    client, passed = smoke_status(client, run_id, state)
                    if passed:
                        break
                    time.sleep(30)
                else:
                    raise RuntimeError("E2 smoke completion deadline exceeded")
            else:
                smoke_status(client, run_id, state)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
