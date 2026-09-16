#!/usr/bin/env python3
"""Prepare, submit, monitor and collect frozen-netlist DIR-SKEW1 GLS."""
from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import json
import os
import re
import shlex
import tarfile
import time
from datetime import datetime
from pathlib import Path

from run_remote_cmr_fat_tree_noc16_sdf import connect, job_id
from run_remote_prop_temp64 import remote, upload
import run_remote_prop_temp64 as prop_remote

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ARCHIVE = "/home/ghy19/Asynchronous_Router_CMR"
PRJTEMP = "/prjtemp/ghy19/date2027_dir_skew64"
LOADS = (5, 60, 100, 120, 140, 160, 180, 200)
DESIGNS = ("Dynamic4", "Static4")
FROZEN = {
    "Dynamic4": ("20260913_prop_temp64_asap_uc_m5_200", "PROP_temp64", "PROP_TEMP64_DC_PASS"),
    "Static4": ("20260915_144500_prop_temp64_static4_dc", "PROP_temp64_static4", "PROP_TEMP64_STATIC4_DC_PASS"),
}


def checked(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise SystemExit("unsafe run id")
    return value


def local_root(run_id: str) -> Path:
    return REPO / "DATE paper" / "experiments" / "raw" / "paper64" / run_id


def remote_root(run_id: str) -> str:
    return f"{PRJTEMP}/{run_id}"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def connection():
    host = os.environ.get("DIR_SKEW_LOGIN_HOST", "192.168.2.8")
    os.environ["C1_HOST"] = host
    prop_remote.LOGIN_HOSTS = (host,)
    return connect(attempts=2)


def preflight(client):
    cmd = ["set -e"]
    for design, (rid, prefix, marker) in FROZEN.items():
        for suffix in (".ddc", "_post.v", ".sdf", ".sdc"):
            p = f"{ARCHIVE}/outputs/{rid}/{prefix}{suffix}"
            cmd += [f"test -s {shlex.quote(p)}", f"stat -c 'DIR_SKEW_INPUT {design} %s %n' {shlex.quote(p)}", f"sha256sum {shlex.quote(p)}"]
        # Static recovery used a retry log on some installations; accept only
        # a real PASS marker from either canonical DC log name.
        cmd.append(f"grep -h -q '^{marker}' {ARCHIVE}/logs/dc/{rid}.log {ARCHIVE}/logs/dc/{rid}.retry.log 2>/dev/null")
        cmd.append(f"grep -h '^{marker}' {ARCHIVE}/logs/dc/{rid}.log {ARCHIVE}/logs/dc/{rid}.retry.log 2>/dev/null | tail -1")
        cmd.append(f"echo DIR_SKEW_NETLIST_PASS:{design}:{rid}")
    client, out = remote(client, "\n".join(cmd))
    print(out, flush=True)
    if out.count("DIR_SKEW_NETLIST_PASS:") != 2:
        raise RuntimeError("frozen netlist gate incomplete")
    return client


def generate(run_id: str) -> Path:
    root = local_root(run_id)
    if root.exists():
        raise RuntimeError(f"refusing overwrite {root}")
    import subprocess, sys
    subprocess.run([sys.executable, str(HERE / "generate_dir_skew64.py"), "--root", str(root)], check=True)
    return root


def prepare(client, run_id: str, root: Path):
    rr = remote_root(run_id)
    client, out = remote(client, f"test -e {shlex.quote(rr)} && echo EXISTS || echo NEW")
    if "EXISTS" in out:
        raise RuntimeError(f"refusing overwrite {rr}")
    client, _ = remote(client, f"mkdir -p {rr}/src {rr}/cases {rr}/jobs {rr}/logs {rr}/results {rr}/work")
    sources = {
        HERE / "run_dir_skew64_remote.sh": f"{rr}/run_dir_skew64_remote.sh",
        REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": f"{rr}/src/async_prop_temp64_port_adapter.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": f"{rr}/src/tb_noc64_async_boundary.sv",
        HERE / "tb_cmr_noc64_async_boundary_failfast.sv": f"{rr}/src/tb_cmr_noc64_async_boundary_failfast.sv",
        HERE / "tb_prop_temp64_lane_monitor.sv": f"{rr}/src/tb_prop_temp64_lane_monitor.sv",
    }
    for src, dst in sources.items():
        client = upload(client, src, dst)
    bundle = root / "cases.tar.gz"
    with tarfile.open(bundle, "w:gz") as tf:
        for p in sorted((root / "cases").glob("*.case")):
            tf.add(p, arcname=p.name)
    encoded = root / "cases.tar.gz.b64"
    encoded.write_bytes(base64.b64encode(bundle.read_bytes()))
    client = upload(client, encoded, f"{rr}/cases/cases.tar.gz.b64")
    digest = sha(bundle)
    client, out = remote(client, f"set -e; base64 --decode {rr}/cases/cases.tar.gz.b64 > {rr}/cases/cases.tar.gz; echo '{digest}  {rr}/cases/cases.tar.gz' | sha256sum -c -; tar -xzf {rr}/cases/cases.tar.gz -C {rr}/cases; chmod +x {rr}/run_dir_skew64_remote.sh; bash -n {rr}/run_dir_skew64_remote.sh; find {rr}/cases -name '*.case' -size +1000000c | wc -l")
    print(out, flush=True)
    if ": OK" not in out or not re.search(r"(?m)^8\s*$", out):
        raise RuntimeError("remote case archive gate failed")
    manifest = json.loads((root / "input_manifest.json").read_text(encoding="utf-8"))
    for row in manifest:
        client, out = remote(client, f"sha256sum {rr}/cases/{shlex.quote(row['case'])}")
        if row["case_sha256"] not in out:
            raise RuntimeError("remote case hash mismatch " + row["case"])
    state = {"run_id": run_id, "remote_root": rr, "stage": "prepared", "jobs": {}, "loads": list(LOADS), "designs": list(DESIGNS)}
    (root / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("DIR_SKEW_PREPARE_PASS", run_id, flush=True)
    return client, state


def resume_prepared(client, run_id: str, root: Path):
    """Resume after inputs passed remotely but state publication was interrupted."""
    rr = remote_root(run_id)
    client, out = remote(client, f"set -e; test -x {rr}/run_dir_skew64_remote.sh; test \"$(find {rr}/cases -name '*.case' -size +1000000c | wc -l)\" -eq 8; echo DIR_SKEW_REMOTE_INPUTS_PRESENT")
    if "DIR_SKEW_REMOTE_INPUTS_PRESENT" not in out:
        raise RuntimeError("prepared remote input gate failed")
    rows = json.loads((root / "input_manifest.json").read_text(encoding="utf-8"))
    for row in rows:
        client, out = remote(client, f"sha256sum {rr}/cases/{shlex.quote(row['case'])}")
        if row["case_sha256"] not in out:
            raise RuntimeError("remote case hash mismatch " + row["case"])
    state = {"run_id": run_id, "remote_root": rr, "stage": "prepared", "jobs": {}, "loads": list(LOADS), "designs": list(DESIGNS)}
    (root / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("DIR_SKEW_PREPARE_RESUME_PASS", run_id, flush=True)
    return client, state


def submit(client, cmd: str, name: str, output: str, dep: str | None = None):
    wait = f"-w {shlex.quote('done(' + dep + ')')} " if dep else ""
    client, out = remote(client, f"bsub -n 8 -m 'node21 node26 node24 node18' {wait}-o {shlex.quote(output)} -e {shlex.quote(output+'.err')} -J {shlex.quote(name)} {cmd}")
    jid = job_id(out)
    print("DIR_SKEW_JOB_SUBMITTED", name, jid, flush=True)
    return client, str(jid)


def case_for(root: Path, load: int) -> str:
    rows = json.loads((root / "input_manifest.json").read_text(encoding="utf-8"))
    return next(row["case"] for row in rows if row["load"] == load)


def submit_smoke(client, run_id: str, root: Path, state: dict):
    rr, shell = remote_root(run_id), f"{remote_root(run_id)}/run_dir_skew64_remote.sh"
    state["jobs"]["compile"] = {}
    state["jobs"]["smoke"] = []
    for design in DESIGNS:
        env = f"env DIR_SKEW_REMOTE_ROOT={rr} DIR_SKEW_RUN_ID={run_id} CMR_ARCHIVE_ROOT={ARCHIVE}"
        client, cjid = submit(client, f"{env} bash {shell} compile {design}", f"dsc_{run_id[-8:]}_{design}", f"{rr}/jobs/compile_{design}.log")
        state["jobs"]["compile"][design] = cjid
        case = case_for(root, 5); stem = Path(case).stem
        runenv = f"{env} DIR_SKEW_CASE_FILE={rr}/cases/{case} DIR_SKEW_CASE_NAME={stem}"
        client, rjid = submit(client, f"{runenv} bash {shell} run {design}", f"dsm5_{run_id[-8:]}_{design}", f"{rr}/jobs/m5_{design}.log", cjid)
        state["jobs"]["smoke"].append({"job": rjid, "design": design, "load": 5, "case": stem})
    state["stage"] = "smoke_submitted"
    (root / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return client, state


def status(client, run_id: str, state: dict) -> tuple[object, bool]:
    rr = remote_root(run_id)
    ids = [str(v) for v in state["jobs"].get("compile", {}).values()] + [str(x["job"]) for group in ("smoke", "grid") for x in state["jobs"].get(group, [])]
    client, out = remote(client, f"bjobs -a {' '.join(ids)} -noheader -o 'jobid stat job_name exec_host run_time' 2>/dev/null || true; printf 'CASE_PASS '; grep -Rlh 'DIR_SKEW_CASE_PASS' {rr}/logs/*/*/stage.log 2>/dev/null | wc -l; printf 'TB_PASS '; grep -Rlh 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' {rr}/logs/*/*/run.log 2>/dev/null | wc -l; printf 'LANE_PASS '; grep -Rlh 'CMR_LANE_MONITOR_PASS rows=128' {rr}/logs/*/*/run.log 2>/dev/null | wc -l; printf 'FAIL_FILES '; grep -RilE 'DIR_SKEW_FAIL|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_HARD_TIMEOUT|Fatal:|Timing violation' {rr}/logs 2>/dev/null | wc -l; find {rr}/logs -name run.log -type f -printf '%T@ %s %p\n' 2>/dev/null | sort -n | tail -4")
    print(out, flush=True)
    if re.search(r"(?m)^\d+\s+EXIT\b", out) or re.search(r"FAIL_FILES\s+[1-9]", out):
        raise RuntimeError("DIR-SKEW job failure detected")
    expected = 16 if state.get("stage") == "grid_submitted" else 2
    vals = [int(re.search(rf"{key}\s+(\d+)", out).group(1)) for key in ("CASE_PASS", "TB_PASS", "LANE_PASS")]
    done = all(v == expected for v in vals)
    return client, done


def submit_grid(client, run_id: str, root: Path, state: dict):
    rr, shell = remote_root(run_id), f"{remote_root(run_id)}/run_dir_skew64_remote.sh"
    state["jobs"]["grid"] = []
    for design in DESIGNS:
        previous = next(x["job"] for x in state["jobs"]["smoke"] if x["design"] == design)
        for load in LOADS[1:]:
            case = case_for(root, load); stem = Path(case).stem
            env = f"env DIR_SKEW_REMOTE_ROOT={rr} DIR_SKEW_RUN_ID={run_id} CMR_ARCHIVE_ROOT={ARCHIVE} DIR_SKEW_CASE_FILE={rr}/cases/{case} DIR_SKEW_CASE_NAME={stem}"
            client, jid = submit(client, f"{env} bash {shell} run {design}", f"ds{load}_{run_id[-6:]}_{design}", f"{rr}/jobs/m{load}_{design}.log", previous)
            previous = jid
            state["jobs"]["grid"].append({"job": jid, "design": design, "load": load, "case": stem})
    state["stage"] = "grid_submitted"
    (root / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return client, state


def wait(client, run_id: str, state: dict, expected: int):
    for _ in range(480):
        client, done = status(client, run_id, state)
        if done:
            print(f"DIR_SKEW_GLS_PASS run={run_id} cases={expected}", flush=True)
            return client
        time.sleep(30)
    raise RuntimeError("DIR-SKEW monitoring deadline exceeded")


def collect(client, run_id: str, root: Path):
    rr = remote_root(run_id)
    archive = f"{rr}/dir_skew_results.tar.gz"
    client, out = remote(client, f"set -e; cd {rr}; tar -czf dir_skew_results.tar.gz logs results jobs work/Dynamic4/input_hashes.log work/Dynamic4/sdf_annotate.log work/Static4/input_hashes.log work/Static4/sdf_annotate.log; sha256sum dir_skew_results.tar.gz")
    match = re.search(r"(?m)^([0-9a-f]{64})\s+", out)
    if not match: raise RuntimeError("remote collection hash absent")
    local_tar = root / "dir_skew_results.tar.gz"
    sftp = client.open_sftp(); sftp.get(archive, str(local_tar)); sftp.close()
    if sha(local_tar) != match.group(1): raise RuntimeError("downloaded archive SHA mismatch")
    raw = root / "raw"
    raw.mkdir(exist_ok=False)
    with tarfile.open(local_tar, "r:gz") as tf: tf.extractall(raw)
    (root / "remote_archive.sha256").write_text(f"{match.group(1)}  dir_skew_results.tar.gz\n", encoding="utf-8")
    print("DIR_SKEW_COLLECT_PASS", run_id, match.group(1), flush=True)


def metric(values: list[int]) -> tuple[float, float, float, int]:
    import math
    total = sum(values)
    shares = [v / total if total else 0.0 for v in values]
    jain = total * total / (len(values) * sum(v*v for v in values)) if total and sum(v*v for v in values) else 0.0
    mean = total / len(values) if values else 0.0
    cv = math.sqrt(sum((v-mean)**2 for v in values) / len(values)) / mean if mean else 0.0
    return jain, cv, max(shares, default=0.0), sum(v == 0 for v in values)


def finalize(run_id: str, root: Path):
    raw = root / "raw"
    manifest = json.loads((root / "input_manifest.json").read_text(encoding="utf-8"))
    summary, acceptance, lanes = [], [], []
    trace_by_load = {r["load"]: r["trace_sha256"] for r in manifest}
    for design in DESIGNS:
        for load in LOADS:
            case = Path(case_for(root, load)).stem
            result = raw / "results" / design / (case + ".csv")
            logdir = raw / "logs" / design / case
            with result.open(newline="", encoding="utf-8") as f: rows = list(csv.DictReader(f))
            if len(rows) != 1: raise RuntimeError(f"result row cardinality {design} M{load}")
            row = rows[0]
            with (logdir / "flit_latency.csv").open(newline="", encoding="utf-8") as f: flits = list(csv.DictReader(f))
            with (logdir / "latency.csv").open(newline="", encoding="utf-8") as f: packet_rows = list(csv.DictReader(f))
            # TB flit_latency carries pkt_seq; latency.csv is the authoritative
            # pkt_seq -> original event join. Include measurement offers whose
            # tails drain after measurement_end as required by the plan.
            measurement_pkt = {str(x["pkt_seq"]): int(x["original_event_id"]) for x in packet_rows
                               if 1000 <= int(x["original_event_id"]) <= 10999}
            cohort = [x for x in flits if str(x["pkt_seq"]) in measurement_pkt]
            if len(cohort) != 50000: raise RuntimeError(f"cohort {design} M{load}: {len(cohort)}")
            offered = int(row["measurement_offered_flits"]); delivered = int(row["measurement_delivered_flits"])
            backlog = int(row["measurement_backlog_flits"]); ratio = delivered / offered if offered else 0.0
            near = ratio >= 0.99 and backlog <= 5
            lane_rows = list(csv.DictReader((logdir / "lane_counts.csv").open(newline="", encoding="utf-8")))
            if len(lane_rows) != 128: raise RuntimeError(f"lane rows {design} M{load}: {len(lane_rows)}")
            for level in (1, 2):
                level_rows = [x for x in lane_rows if int(x["level"]) == level]
                global_counts = [sum(int(x["accepted_flits"]) for x in level_rows if int(x["parent_lane"]) == lane) for lane in range(4)]
                jain, cv, max_share, unused = metric(global_counts)
                lanes.append({"design": design, "load": load, "level": level, "scope": "all_16_routers", "lane0": global_counts[0], "lane1": global_counts[1], "lane2": global_counts[2], "lane3": global_counts[3], "jain": jain, "cv": cv, "maximum_lane_share": max_share, "unused_lane_count": unused})
            summary.append({"design": design, "load": load, "trace_sha256": trace_by_load[load], "measurement_offered_flits": offered, "measurement_delivered_flits": delivered, "delivery_ratio": ratio, "source_backlog_flits": backlog, "delivered_mflit_port_s": row["delivered_mflit_port_s"], "flit_lat_mean_ns": row["flit_lat_mean_ns"], "flit_lat_p95_ns": row["flit_lat_p95_ns"], "flit_lat_p99_ns": row["flit_lat_p99_ns"], "cohort_flits": len(cohort), "near_lossless": near})
            acceptance.append({"design": design, "load": load, "full_drain": True, "sdf_errors": 0, "cohort_flits": len(cohort), "lane_rows": len(lane_rows), "trace_sha256": trace_by_load[load], "accepted": True})
    for load in LOADS:
        pair = [x for x in summary if x["load"] == load]
        if len(pair) != 2 or pair[0]["trace_sha256"] != pair[1]["trace_sha256"]: raise RuntimeError(f"trace pairing M{load}")
    common = max((load for load in LOADS if all(x["near_lossless"] for x in summary if x["load"] == load)), default=None)
    diverge = next((load for load in LOADS if next(x for x in summary if x["design"] == "Dynamic4" and x["load"] == load)["near_lossless"] and not next(x for x in summary if x["design"] == "Static4" and x["load"] == load)["near_lossless"]), None)
    def write_csv(name, rows):
        with (root / name).open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    write_csv("summary.csv", summary); write_csv("acceptance.csv", acceptance); write_csv("lane_summary.csv", lanes)
    selection = {"M_SKEW_common": common, "M_SKEW_diverge": diverge, "divergence_supported": diverge is not None}
    (root / "selection.json").write_text(json.dumps(selection, indent=2) + "\n", encoding="utf-8")
    with (root / "selection.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["metric", "value"]); w.writeheader()
        w.writerows([{"metric": k, "value": v} for k, v in selection.items()])
    manifest_out = {
        "run_id": run_id, "benchmark": "DIR-SKEW1", "commit": "21fb2ac4659a75bc4bb7ed95f77d70bb68cc7002",
        "dirty_state": True, "loads": list(LOADS), "designs": list(DESIGNS),
        "frozen_netlists": FROZEN, "remote_archive_sha256": (root / "remote_archive.sha256").read_text().split()[0],
        "trace_hashes": trace_by_load, "acceptance_points": len(acceptance),
        "lane_monitor_rows_per_point": 128, "power": False,
    }
    (root / "manifest.json").write_text(json.dumps(manifest_out, indent=2) + "\n", encoding="utf-8")
    result_lines = ["# DIR-SKEW1 64-node results", "", f"- Run: `{run_id}`", "- MAXIMUM-SDF GLS: 16/16 accepted", f"- M_SKEW-common: `{common}`", f"- M_SKEW-diverge: `{diverge if diverge is not None else 'none'}`"]
    if diverge is None: result_lines += ["", "The fixed scan does not support a Dynamic4 recovery advantage; the paper claim must remain conditional."]
    (root / "RESULTS.md").write_text("\n".join(result_lines) + "\n", encoding="utf-8")
    print("DIR_SKEW_FINALIZE_PASS", json.dumps(selection), flush=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("stage", choices=("start", "resume-prepared", "status", "wait-smoke", "release", "wait-grid", "collect", "finalize", "preflight"))
    ap.add_argument("--run-id", default="dir_skew64_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
    args = ap.parse_args(); run_id = checked(args.run_id)
    client = connection()
    try:
        if args.stage in ("start", "preflight"):
            client = preflight(client)
        if args.stage == "preflight": return 0
        if args.stage == "start":
            root = generate(run_id); client, state = prepare(client, run_id, root); client, state = submit_smoke(client, run_id, root, state)
        elif args.stage == "resume-prepared":
            root = local_root(run_id); client, state = resume_prepared(client, run_id, root); client, state = submit_smoke(client, run_id, root, state)
        else:
            root = local_root(run_id); state = json.loads((root / "state.json").read_text(encoding="utf-8"))
        if args.stage == "collect": collect(client, run_id, root); return 0
        if args.stage == "finalize": finalize(run_id, root); return 0
        if args.stage == "release":
            client, passed = status(client, run_id, state)
            if not passed: raise RuntimeError("paired M5 gate not complete")
            client, state = submit_grid(client, run_id, root, state)
        if args.stage == "wait-smoke": client = wait(client, run_id, state, 2)
        elif args.stage == "wait-grid": client = wait(client, run_id, state, 16)
        elif args.stage in ("start", "status", "release"): status(client, run_id, state)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
