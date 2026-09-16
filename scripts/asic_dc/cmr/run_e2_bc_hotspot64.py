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
            case_bytes = case.read_bytes()
            rows.append({"benchmark": benchmark, "design": design, "case": str(case), "case_sha256": hashlib.sha256(case_bytes).hexdigest(), "case_lf_sha256": hashlib.sha256(case_bytes.replace(b"\r\n", b"\n")).hexdigest(), "trace_sha256": trace_hash})
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


def retry_smoke_without_recompile(client, run_id: str, state, rows):
    """Keep prior EXIT logs intact; rerun into distinct case directories."""
    root = remote_root(run_id)
    shell = f"{root}/run_e2_bc_hotspot64_retry_csv_gate.sh"
    client = upload(client, HERE / "run_e2_bc_hotspot64_remote.sh", shell)
    checks = ["set -e", f"bash -n {shell}", f"chmod +x {shell}"]
    for design in FROZEN:
        checks += [f"test -x {root}/work/{design}/simv", f"test -s {root}/work/{design}/sdf_annotate.log"]
    for row in rows:
        name = Path(row["case"]).name
        checks.append(f"echo {row['case_sha256']} ' {root}/cases/{name}' | sha256sum --check")
    client, out = remote(client, "\n".join(checks))
    print(out, flush=True)
    if out.count(": OK") != 4:
        raise RuntimeError("retry input SHA or frozen simv gate failed")
    old_jobs = state["run_jobs"]
    new_jobs = []
    last_design_job = {}
    for row in rows:
        design, benchmark = row["design"], row["benchmark"]
        base = case_name(benchmark, design)
        name = base + "_retry_csv_gate"
        netlist = FROZEN[design][0]
        env = f"env E2_REMOTE_ROOT={root} E2_RUN_ID={run_id} E2_NETLIST_RUN_ID={netlist} CMR_ARCHIVE_ROOT={ARCHIVE} E2_CASE_NAME={name} E2_CASE_FILE={root}/cases/{base}.case"
        client, jid = submit(client, f"{env} bash {shell} run {design}", f"e2v_{run_id[-10:]}_{benchmark.replace('-', '')}_{design}", f"{root}/jobs/retry_{design}_{benchmark}.log", dep=last_design_job.get(design))
        last_design_job[design] = jid
        new_jobs.append({"job": jid, "design": design, "benchmark": benchmark, "case": name, "input_case": base})
    state["prior_failed_smoke_jobs"] = old_jobs
    state["run_jobs"] = new_jobs
    state["stage"] = "retry_smoke_submitted"
    (HERE / "results" / run_id / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("E2_RETRY_SMOKE_SUBMITTED", run_id, new_jobs, flush=True)
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
        run_ids = {str(row["job"]) for row in state["run_jobs"]}
        if any(states.get(jid) == "RUN" for jid in run_ids) and "E2_CASE_RUN" in out and "run.log" in out:
            print("E2_SMOKE_CONFIRMED_RUNNING", run_id, flush=True)
            return client
        if "E2_CASE_RUN" in out and "run.log" in out and nonempty:
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
        shared = f"{root}/work/{row['design']}/sdf_annotate.log"
        checks.append(f"grep -hE 'E2_CASE_(PASS|FAIL)|TB_RESULT|Doing SDF annotation' {base}/stage.log {base}/run.log 2>/dev/null | tail -5 || true")
        checks.append(f"grep -hE 'Total errors:' {shared} 2>/dev/null | tail -1 || true")
        checks.append(f"test -s {base}/sdf_reference.sha256 && echo SDF_REFERENCE_NONZERO || true")
        checks.append(f"test -s {root}/results/{row['design']}/{row['case']}.csv && echo CSV_NONZERO || true")
    client, out = remote(client, "\n".join(checks))
    print(out, flush=True)
    if "E2_CASE_FAIL" in out or re.search(r"(?m)^\d+\s+EXIT\b", out):
        raise RuntimeError("E2 M5 smoke failed; do not submit remaining load grid")
    if (out.count("E2_CASE_PASS") == 4 and out.count("CSV_NONZERO") == 4
            and out.count("Total errors: 0") == 4
            and out.count("SDF_REFERENCE_NONZERO") == 4
            and out.count("Doing SDF annotation") == 4):
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
        checks += [f"echo E2_DIAG:{row['design']}:{row['benchmark']}", f"tail -n 30 {base}/run.log 2>/dev/null || true", f"grep -hE 'Total errors:|SDF (Error|Warning)|TB_RESULT|TB_INFO|Error:' {base}/sdf_annotate.log 2>/dev/null | tail -15 || true", f"tail -n 12 {root}/jobs/run_{row['design']}_{row['benchmark']}.log 2>/dev/null || true", f"tail -n 12 {root}/jobs/run_{row['design']}_{row['benchmark']}.log.err 2>/dev/null || true", f"ls -lh {base}/sdf_annotate.log {base}/run.log {root}/results/{row['design']}/{row['case']}.csv 2>/dev/null || true"]
    checks.append(f"find {root}/work {root}/logs -name sdf_annotate.log -type f -printf '%s %p\\n' 2>/dev/null | head -20")
    client, out = remote(client, "\n".join(checks))
    print(out, flush=True)
    return client


def stage_generator(client, run_id: str):
    root = remote_root(run_id)
    local = HERE / "results" / run_id
    bundle = local / "e2_generator.tar.gz"
    paper = REPO / "DATE paper" / "experiments"
    with tarfile.open(bundle, "w:gz") as archive:
        source_root = paper / "scripts" / "date_v3"
        for source in source_root.glob("*.py"):
            archive.add(source, arcname=f"experiments/scripts/date_v3/{source.name}")
        for name in ("topo_bc.json", "hotspot10.json"):
            archive.add(paper / "configs" / "benchmarks" / name, arcname=f"experiments/configs/benchmarks/{name}")
        for name in ("prop_temp64.json", "fm64.json"):
            archive.add(paper / "configs" / "designs" / name, arcname=f"experiments/configs/designs/{name}")
        for name in ("generate_e2_bc_hotspot64.py", "run_e2_bc_hotspot64_grid.sh", "run_e2_bc_hotspot64_remote.sh"):
            archive.add(HERE / name, arcname=name)
    encoded = local / "e2_generator.tar.gz.b64"
    encoded.write_bytes(base64.b64encode(bundle.read_bytes()))
    client = upload(client, encoded, f"{root}/e2_generator.tar.gz.b64")
    sha = hashlib.sha256(bundle.read_bytes()).hexdigest()
    client, out = remote(client, f"set -e; base64 --decode {root}/e2_generator.tar.gz.b64 > {root}/e2_generator.tar.gz; echo {sha} ' {root}/e2_generator.tar.gz' | sha256sum --check; tar -tzf {root}/e2_generator.tar.gz >/dev/null; tar -xzf {root}/e2_generator.tar.gz -C {root}; bash -n {root}/run_e2_bc_hotspot64_grid.sh; chmod +x {root}/run_e2_bc_hotspot64_grid.sh")
    if f"{root}/e2_generator.tar.gz: OK" not in out:
        raise RuntimeError("E2 generator package hash mismatch: " + out)
    print("E2_GENERATOR_STAGED", root, sha, flush=True)
    client, jid = submit(client, f"/soft/GNU/python3.12/bin/python3 {root}/generate_e2_bc_hotspot64.py", f"e2g_{run_id[-10:]}", f"{root}/jobs/generate.log")
    print("E2_GENERATOR_SUBMITTED", jid, flush=True)
    return client, jid


def wait_generator(client, run_id: str, jid: str):
    root = remote_root(run_id)
    for index in range(180):
        client, out = remote(client, f"bjobs -a {jid} -noheader -o 'jobid stat job_name' 2>/dev/null || true; tail -n 5 {root}/jobs/generate.log 2>/dev/null || true; test -s {root}/e2_input_manifest.json && echo E2_MANIFEST_NONZERO || true")
        print("E2_GENERATOR_POLL", index, out.replace("\n", " | "), flush=True)
        if re.search(rf"(?m)^{jid}\s+EXIT\b", out):
            raise RuntimeError("E2 full generator failed")
        if re.search(rf"(?m)^{jid}\s+DONE\b", out) and "E2_GENERATION_PASS points=60 cases=120" in out and "E2_MANIFEST_NONZERO" in out:
            return client
        time.sleep(20)
    raise RuntimeError("E2 full generator timed out")


def submit_full_grid(client, run_id: str, state):
    root = remote_root(run_id)
    # Linux materialization emits LF; smoke tar preserved Windows CRLF. Compare
    # normalized bytes so the gate checks semantic case identity, not newlines.
    rows = require_local_smoke()
    checks = ["set -e", f"test -s {root}/e2_input_manifest.json"]
    for row in rows:
        name = Path(row["case"]).name
        checks.append(f"echo {row['case_lf_sha256']} ' {root}/cases/{name}' | sha256sum --check")
    checks += [f"find {root}/cases -maxdepth 1 -name '*.case' -type f | wc -l", f"find {root}/traces -maxdepth 1 -name '*.jsonl' -type f | wc -l"]
    client, out = remote(client, "\n".join(checks))
    print(out, flush=True)
    if out.count(": OK") != 4 or not re.search(r"(?m)^120\s*$", out) or not re.search(r"(?m)^60\s*$", out):
        raise RuntimeError("E2 full grid cardinality/M5 hash gate failed")
    jobs = []
    for benchmark in BENCHMARKS:
        client, jid = submit(client, f"env E2_REMOTE_ROOT={root} E2_RUN_ID={run_id} CMR_ARCHIVE_ROOT={ARCHIVE} bash {root}/run_e2_bc_hotspot64_grid.sh {benchmark}", f"e2f_{run_id[-10:]}_{benchmark.replace('-', '')}", f"{root}/jobs/full_{benchmark}.log")
        jobs.append({"benchmark": benchmark, "job": jid})
    state["full_jobs"] = jobs
    state["stage"] = "full_submitted"
    (HERE / "results" / run_id / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("E2_FULL_SUBMITTED", run_id, jobs, flush=True)
    return client


def probe_private_simv(client, run_id: str):
    """Non-paper path to validate VCS per-case SDF logs on an existing simv."""
    root = remote_root(run_id)
    shell = f"{root}/run_e2_bc_hotspot64_probe.sh"
    client = upload(client, HERE / "run_e2_bc_hotspot64_remote.sh", shell)
    client, _ = remote(client, f"bash -n {shell}; chmod +x {shell}")
    name = case_name("HOTSPOT10", "PROP_temp64")
    probe = name + "_probe_private_simv"
    cmd = (f"env E2_REMOTE_ROOT={root} E2_RUN_ID={run_id} "
           f"E2_NETLIST_RUN_ID={FROZEN['PROP_temp64'][0]} CMR_ARCHIVE_ROOT={ARCHIVE} "
           f"E2_CASE_NAME={probe} E2_CASE_FILE={root}/cases/{name}.case "
           f"bash {shell} run PROP_temp64")
    client, jid = submit(client, cmd, f"e2p_{run_id[-10:]}", f"{root}/jobs/probe_private_simv.log")
    print("E2_PRIVATE_SIMV_PROBE_JOB", jid, flush=True)
    return client


def probe_status(client, run_id: str):
    root = remote_root(run_id)
    name = case_name("HOTSPOT10", "PROP_temp64") + "_probe_private_simv"
    base = f"{root}/logs/PROP_temp64/{name}"
    client, out = remote(client, f"bjobs -a 12299801 -noheader -o 'jobid stat job_name' 2>/dev/null || true; grep -hE 'E2_CASE_(RUN|PASS|FAIL)|TB_RESULT' {base}/stage.log {base}/run.log {root}/jobs/probe_private_simv.log 2>/dev/null | tail -8 || true; grep -hE 'Total errors:' {base}/sdf_annotate.log 2>/dev/null | tail -2 || true; ls -lh {base}/sdf_annotate.log {base}/simv {root}/results/PROP_temp64/{name}.csv 2>/dev/null || true")
    print(out, flush=True)
    return client


def check_remote_python(client):
    cmd = "for exe in /usr/bin/python3 /usr/local/bin/python3 /usr/bin/python /soft/anaconda3/bin/python3 /soft/*/bin/python3 /soft/*/*/bin/python3 /opt/*/bin/python3 /usr/local/*/bin/python3; do test -x \"$exe\" && \"$exe\" --version 2>&1 && echo E2_PYTHON:$exe; done; module avail python 2>&1 | tail -30 || true"
    client, out = remote(client, cmd)
    print(out, flush=True)
    return client


def generation_status(client, run_id: str):
    root = remote_root(run_id)
    client, out = remote(client, f"bjobs -a -J e2g_{run_id[-10:]} -noheader -o 'jobid stat job_name' 2>/dev/null || true; echo STDOUT; tail -n 30 {root}/jobs/generate.log 2>/dev/null || true; echo STDERR; tail -n 40 {root}/jobs/generate.log.err 2>/dev/null || true; printf 'TRACES '; find {root}/traces -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null | wc -l; printf 'CASES '; find {root}/cases -maxdepth 1 -name '*.case' -type f 2>/dev/null | wc -l; ls -lh {root}/e2_input_manifest.json 2>/dev/null || true")
    print(out, flush=True)
    return client


def python_version_probe(client, run_id: str):
    root = remote_root(run_id)
    probe = f"{root}/generate_e2_version_probe.py"
    client = upload(client, HERE / "generate_e2_bc_hotspot64.py", probe)
    commands = []
    for version, exe in (("py38", "/soft/GNU/python3.8.5/bin/python3"), ("py312", "/soft/GNU/python3.12/bin/python3")):
        out = f"{root}/version_probe_{version}"
        commands.append(f"{exe} {probe} --root {out} --load 5 --traces-only")
        commands.append(f"sha256sum {out}/traces/*.jsonl")
    client, out = remote(client, "set -e\n" + "\n".join(commands))
    print(out, flush=True)
    return client


def stage_canonical_traces(client, run_id: str):
    root = remote_root(run_id)
    local_root = HERE / "results" / run_id / "canonical"
    archive = local_root / "e2_canonical_traces.tar.gz"
    traces = list((local_root / "traces").glob("*.jsonl"))
    if len(traces) != 60 or not archive.is_file():
        raise RuntimeError("local canonical trace bundle gate failed")
    encoded = local_root / "e2_canonical_traces.tar.gz.b64"
    encoded.write_bytes(base64.b64encode(archive.read_bytes()))
    client = upload(client, encoded, f"{root}/e2_canonical_traces.tar.gz.b64")
    client = upload(client, HERE / "generate_e2_bc_hotspot64.py", f"{root}/generate_e2_bc_hotspot64.py")
    archive_hash = hashlib.sha256(archive.read_bytes()).hexdigest()
    bc_hash = sha256_path(local_root / "traces" / "TOPO-BC_n64_s202701_m5.jsonl")
    hot_hash = sha256_path(local_root / "traces" / "HOTSPOT10_n64_s202701_m5.jsonl")
    cmd = f"""set -e
test ! -e {root}/traces_remote_platform_rejected
test ! -e {root}/cases_remote_platform_rejected
mv {root}/traces {root}/traces_remote_platform_rejected
mv {root}/cases {root}/cases_remote_platform_rejected
mkdir -p {root}/traces {root}/cases
base64 --decode {root}/e2_canonical_traces.tar.gz.b64 > {root}/e2_canonical_traces.tar.gz
echo {archive_hash} ' {root}/e2_canonical_traces.tar.gz' | sha256sum --check
tar -tzf {root}/e2_canonical_traces.tar.gz >/dev/null
tar -xzf {root}/e2_canonical_traces.tar.gz -C {root}/traces
test \"$(find {root}/traces -maxdepth 1 -name '*.jsonl' -type f | wc -l)\" -eq 60
echo {bc_hash} ' {root}/traces/TOPO-BC_n64_s202701_m5.jsonl' | sha256sum --check
echo {hot_hash} ' {root}/traces/HOTSPOT10_n64_s202701_m5.jsonl' | sha256sum --check
"""
    client, out = remote(client, cmd)
    print(out, flush=True)
    if out.count(": OK") != 3:
        raise RuntimeError("remote local-canonical archive/hash gate failed")
    client, jid = submit(client, f"/soft/GNU/python3.12/bin/python3 {root}/generate_e2_bc_hotspot64.py --materialize-existing", f"e2m_{run_id[-10:]}", f"{root}/jobs/materialize_local_canonical.log")
    print("E2_LOCAL_CANONICAL_MATERIALIZE_SUBMITTED", jid, flush=True)
    return client, jid


def sha256_path(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def materialize_status(client, run_id: str):
    root = remote_root(run_id)
    client, out = remote(client, f"bjobs -a -J e2m_{run_id[-10:]} -noheader -o 'jobid stat job_name' 2>/dev/null || true; tail -n 8 {root}/jobs/materialize_local_canonical.log 2>/dev/null || true; tail -n 20 {root}/jobs/materialize_local_canonical.log.err 2>/dev/null || true; printf 'TRACES '; find {root}/traces -maxdepth 1 -name '*.jsonl' -type f | wc -l; printf 'CASES '; find {root}/cases -maxdepth 1 -name '*.case' -type f | wc -l; ls -lh {root}/e2_input_manifest.json 2>/dev/null || true")
    print(out, flush=True)
    return client


def grid_status(client, run_id: str):
    root = remote_root(run_id)
    state = json.loads((HERE / "results" / run_id / "state.json").read_text(encoding="utf-8"))
    jobs = " ".join(str(row["job"]) for row in state.get("full_jobs", []))
    command = f"""
bjobs -a {jobs} -noheader -o 'jobid stat job_name exec_host run_time' 2>/dev/null || true
for b in TOPO-BC HOTSPOT10; do
  echo GRID:$b
  ls -l {root}/jobs/full_$b.log {root}/jobs/full_$b.log.err 2>/dev/null || true
  grep -E 'E2_(PAIR_BEGIN|PAIR_PASS|BENCHMARK_STOP|BENCHMARK_PASS|CASE_RUN|CASE_PASS|CASE_FAIL)' {root}/jobs/full_$b.log 2>/dev/null | tail -12 || true
  tail -n 8 {root}/jobs/full_$b.log.err 2>/dev/null || true
done
echo M10_GATES
find {root}/logs -path '*_m10_*' -name run.log -type f -exec grep -H -E 'Doing SDF annotation|TB_RESULT|Total errors:|Fatal:|ERROR:' {{}} + 2>/dev/null || true
find {root}/logs -path '*_m10_*' -name stage.log -type f -exec tail -n 4 {{}} + 2>/dev/null || true
echo ACTIVE_LOAD_FILES
find {root}/logs -name run.log -type f -printf '%T@ %s %p\n' 2>/dev/null | sort -n | tail -8
echo M10_RESULTS
find {root}/results -name '*_m10_*.csv' -type f -size +0c -print 2>/dev/null | sort
printf 'FULL_RESULT_CSV '
find {root}/results -name '*.csv' -type f -size +0c ! -name '*_m5_*' | wc -l
printf 'FULL_STAGE_PASS '
find {root}/logs -name stage.log -type f ! -path '*_m5_*' -exec grep -l 'E2_CASE_PASS' {{}} + 2>/dev/null | wc -l
printf 'FULL_TB_PASS '
find {root}/logs -name run.log -type f ! -path '*_m5_*' -exec grep -l 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' {{}} + 2>/dev/null | wc -l
printf 'FULL_FAIL_MARKERS '
grep -RilE 'E2_CASE_FAIL|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation' {root}/logs/PROP_temp64 {root}/logs/FM64 2>/dev/null | grep -v '_m5_' | wc -l
printf 'RESULT_CSV_ALL '
find {root}/results -name '*.csv' -type f -size +0c | wc -l
"""
    client, out = remote(client, command)
    print(out, flush=True)
    return client


def wait_grid(client, run_id: str, polls: int = 360):
    """Monitor both benchmark jobs and accept only the complete 116-case grid."""
    root = remote_root(run_id)
    state = json.loads((HERE / "results" / run_id / "state.json").read_text(encoding="utf-8"))
    jobs = " ".join(str(row["job"]) for row in state.get("full_jobs", []))
    if len(state.get("full_jobs", [])) != 2:
        raise RuntimeError("E2 full-grid state must contain exactly two jobs")
    for index in range(polls):
        command = f"""
bjobs -a {jobs} -noheader -o 'jobid stat job_name exec_host run_time' 2>/dev/null || true
printf 'FULL_RESULT_CSV '
find {root}/results -name '*.csv' -type f -size +0c ! -name '*_m5_*' | wc -l
printf 'FULL_STAGE_PASS '
find {root}/logs -name stage.log -type f ! -path '*_m5_*' -exec grep -l 'E2_CASE_PASS' {{}} + 2>/dev/null | wc -l
printf 'FULL_TB_PASS '
find {root}/logs -name run.log -type f ! -path '*_m5_*' -exec grep -l 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' {{}} + 2>/dev/null | wc -l
printf 'FULL_FAIL_MARKERS '
grep -RilE 'E2_CASE_FAIL|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation' {root}/logs/PROP_temp64 {root}/logs/FM64 2>/dev/null | grep -v '_m5_' | wc -l
find {root}/logs -name stage.log -type f ! -path '*_m5_*' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1
grep -hE 'E2_(BENCHMARK_PASS|BENCHMARK_STOP)' {root}/jobs/full_TOPO-BC.log {root}/jobs/full_HOTSPOT10.log 2>/dev/null || true
"""
        client, out = remote(client, command)
        compact = " | ".join(line.strip() for line in out.splitlines() if line.strip() and "ModuleCmd_Load" not in line)
        print(f"E2_GRID_POLL {index} {compact}", flush=True)
        states = {m.group(1): m.group(2) for m in re.finditer(r"(?m)^(\d+)\s+(PEND|RUN|DONE|EXIT)\b", out)}
        if any(states.get(str(row["job"])) == "EXIT" for row in state["full_jobs"]):
            raise RuntimeError("E2 full-grid LSF job exited")
        failed = re.search(r"FULL_FAIL_MARKERS\s+([1-9]\d*)", out)
        if failed or "E2_BENCHMARK_STOP" in out:
            raise RuntimeError("E2 full-grid fail marker detected")
        counts = {
            key: int(match.group(1)) if (match := re.search(rf"{key}\s+(\d+)", out)) else -1
            for key in ("FULL_RESULT_CSV", "FULL_STAGE_PASS", "FULL_TB_PASS")
        }
        done = all(states.get(str(row["job"])) == "DONE" for row in state["full_jobs"])
        if done:
            if counts == {"FULL_RESULT_CSV": 116, "FULL_STAGE_PASS": 116, "FULL_TB_PASS": 116} and out.count("E2_BENCHMARK_PASS") == 2:
                print(f"E2_GRID_PASS run={run_id} m5=4 full=116 total=120", flush=True)
                return client
            raise RuntimeError(f"E2 jobs DONE but acceptance is incomplete: {counts}")
        time.sleep(20)
    raise RuntimeError("E2 full-grid monitoring timed out")


def queue_status(client):
    """Read-only check for active and historical ablation-like LSF jobs."""
    client, out = remote(client, """
echo ACTIVE_JOBS
bjobs -noheader -o 'jobid stat job_name exec_host' 2>/dev/null || true
echo ABLATION_MATCHES
bjobs -a -noheader -o 'jobid stat job_name submit_time' 2>/dev/null | grep -Ei 'ablat|static|mc10|m1|m2|m3' | tail -30 || true
""")
    print(out, flush=True)
    return client


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("preflight", "smoke", "retry-smoke", "status", "wait-smoke", "diagnose", "full", "release-grid", "probe", "probe-status", "check-env", "generation-status", "python-version-probe", "stage-canonical", "materialize-status", "grid-status", "wait-grid", "queue-status"))
    parser.add_argument("--run-id", default=datetime.now().strftime("%Y%m%d_%H%M%S") + "_date2027_e2_bc_hotspot64")
    parser.add_argument("--reuse-case-run", help="copy only SHA-gated prior M5 inputs into a fresh run")
    args = parser.parse_args()
    run_id = checked_run_id(args.run_id)
    rows = require_local_smoke()
    # Select one login explicitly; callers may switch to the currently
    # responsive peer without changing any run inputs or LSF jobs.
    login_host = os.environ.get("E2_LOGIN_HOST", "192.168.2.8")
    os.environ["C1_HOST"] = login_host
    prop_remote.LOGIN_HOSTS = (login_host,)
    client = connect(attempts=2)
    try:
        if args.stage not in ("status", "wait-smoke", "diagnose", "probe", "probe-status", "retry-smoke", "check-env", "generation-status", "release-grid", "python-version-probe", "stage-canonical", "materialize-status", "grid-status", "wait-grid", "queue-status"):
            client = preflight(client)
        if args.stage == "preflight":
            return 0
        if args.stage == "smoke":
            client = prepare(client, run_id, rows, args.reuse_case_run)
            client, state = submit_smoke(client, run_id, rows)
        else:
            state = json.loads((HERE / "results" / run_id / "state.json").read_text(encoding="utf-8"))
        if args.stage == "retry-smoke":
            client, state = retry_smoke_without_recompile(client, run_id, state, rows)
        if args.stage == "diagnose":
            diagnose(client, run_id, state)
        if args.stage == "probe":
            probe_private_simv(client, run_id)
        if args.stage == "probe-status":
            probe_status(client, run_id)
        if args.stage == "check-env":
            check_remote_python(client)
        if args.stage == "generation-status":
            generation_status(client, run_id)
        if args.stage == "python-version-probe":
            python_version_probe(client, run_id)
        if args.stage == "stage-canonical":
            stage_canonical_traces(client, run_id)
        if args.stage == "materialize-status":
            materialize_status(client, run_id)
        if args.stage == "grid-status":
            grid_status(client, run_id)
        if args.stage == "wait-grid":
            wait_grid(client, run_id)
        if args.stage == "queue-status":
            queue_status(client)
        if args.stage == "full":
            client, passed = smoke_status(client, run_id, state)
            if not passed:
                raise RuntimeError("E2 full submission blocked until four M5 smoke PASS")
            client, gen_jid = stage_generator(client, run_id)
            client = wait_generator(client, run_id, gen_jid)
            client = submit_full_grid(client, run_id, state)
        if args.stage == "release-grid":
            client, passed = smoke_status(client, run_id, state)
            if not passed:
                raise RuntimeError("E2 grid release blocked until four M5 smoke PASS")
            client = submit_full_grid(client, run_id, state)
        if args.stage in ("smoke", "retry-smoke", "status"):
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
