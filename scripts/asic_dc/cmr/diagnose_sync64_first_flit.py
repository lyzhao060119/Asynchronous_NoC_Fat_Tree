#!/usr/bin/env python3
"""Bounded Sync B8 diagnosis: preserve old run, localize first bad flit, capture VCD."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect  # noqa: E402
from run_remote_prop_temp64 import remote  # noqa: E402

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = "20260916_004500_sync_prop_temp64_b8_m5"
CASE = "TOPO-UR_n64_s202701_m5_PROP_temp64_top16"
BASE = f"{ROOT}/logs/gls/{RUN}/sdf/{CASE}"
WORK = f"{ROOT}/sim/work/{RUN}/sdf/{CASE}"
CASE_FILE = f"{ROOT}/sim/prop_temp64_20260913_prop_temp64_asap_uc_m5_200/cases/{CASE}.case"
CORRECT_RUN = "20260916_sync64_m5_tick1_diagnosis"
CORRECT_DIR = f"{ROOT}/logs/gls/{CORRECT_RUN}/{CASE}"
PROBE_SEQ = 665
PROBE_DIR = f"{ROOT}/logs/gls/{CORRECT_RUN}/vcd_pkt{PROBE_SEQ}"


def connect_remote():
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    return connect(attempts=2)


def snapshot(client):
    cmd = "\n".join([
        "set -e",
        f"test -x {WORK}/simv",
        f"test -s {CASE_FILE}",
        f"echo SYNC64_SIMV_SHA; sha256sum {WORK}/simv",
        f"echo SYNC64_CASE_SHA; sha256sum {CASE_FILE}",
        f"echo SYNC64_BASE_FILES; find {BASE} -maxdepth 1 -type f -printf '%s %f\\n' | sort -n",
        f"echo SYNC64_WORK_FILES; find {WORK} -maxdepth 1 -type f -printf '%s %f\\n' | sort -n | tail -20",
        f"echo SYNC64_RESULT_FILES; find {ROOT}/results/{RUN} -type f -printf '%s %p\\n' 2>/dev/null || true",
        f"echo SYNC64_CASE_HEAD; head -20 {CASE_FILE}",
        f"echo SYNC64_CASE_COUNTS; awk '$1==\"input\"{{i++}} $1==\"expect\"{{e++}} END{{print i,e}}' {CASE_FILE}",
    ])
    client, out = remote(client, cmd)
    print(out, flush=True)
    return client


def collect(client, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = {
        CASE_FILE: "original.case",
        f"{BASE}/run.log": "run.log",
        f"{BASE}/events.csv": "events.csv",
        f"{BASE}/latency.csv": "latency.csv",
        f"{BASE}/flit_latency.csv": "flit_latency.csv",
        f"{BASE}/v3_metrics.csv": "v3_metrics.csv",
        f"{BASE}/sdf_annotate.log": "sdf_annotate.log",
    }
    sftp = client.open_sftp()
    try:
        for src, name in paths.items():
            try:
                sftp.get(src, str(out_dir / name))
                print("SYNC64_COLLECT", src, name, flush=True)
            except IOError:
                print("SYNC64_ABSENT", src, flush=True)
    finally:
        sftp.close()
    return client


def submit_correct_tick(client, out_dir: Path):
    wrapper = f"{ROOT}/logs/gls/{CORRECT_RUN}/run_tick1.sh"
    joblog = f"{ROOT}/logs/gls/{CORRECT_RUN}/lsf.log"
    body = f"""#!/bin/bash
set -euo pipefail
mkdir -p {CORRECT_DIR}
cd {CORRECT_DIR}
exec {WORK}/simv \\
 +CASE_FILE={CASE_FILE} +RESULT_CSV={CORRECT_DIR}/result.csv \\
 +EVENT_CSV={CORRECT_DIR}/events.csv +LATENCY_CSV={CORRECT_DIR}/latency.csv \\
 +FLIT_LATENCY_CSV={CORRECT_DIR}/flit_latency.csv +V3_METRICS_CSV={CORRECT_DIR}/v3_metrics.csv \\
 +CLOCK_PERIOD_NS=1.05 +CASE_TICK_NS=1 +RX_CAPTURE_NS=0 \\
 +STALL_TIMEOUT_NS=50000 +HARD_TIMEOUT_NS=400000 -l {CORRECT_DIR}/run.log
"""
    client, exists = remote(client, f"test -e {shlex.quote(wrapper)} && echo EXISTS || echo NEW")
    if "EXISTS" in exists:
        raise RuntimeError("refusing to overwrite diagnostic run")
    sftp = client.open_sftp()
    try:
        sftp.mkdir(f"{ROOT}/logs/gls/{CORRECT_RUN}")
    except IOError:
        pass
    with sftp.file(wrapper, "w") as f:
        f.write(body)
    sftp.chmod(wrapper, 0o755)
    sftp.close()
    client, out = remote(client, f"bsub -n 8 -m 'node21 node26 node24 node18' -oo {joblog} -eo {joblog}.err -J sync64_tick1_diag {wrapper}")
    print(out, flush=True)
    match = re.search(r"Job <(\d+)>", out)
    if not match:
        raise RuntimeError("diagnostic job submission failed")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "state.json").write_text(json.dumps({"job_id": match.group(1), "run": CORRECT_RUN}, indent=2) + "\n")
    print("SYNC64_TICK1_SUBMITTED", match.group(1), flush=True)
    return client


def correct_status(client, out_dir: Path):
    state = json.loads((out_dir / "state.json").read_text())
    jid = state["job_id"]
    client, out = remote(client, "\n".join([
        f"bjobs -a {jid} -noheader -o 'jobid stat job_name exec_host run_time' 2>/dev/null || true",
        f"test -s {CORRECT_DIR}/run.log && grep -E 'TB_INFO|TB_RESULT|TB_.*FAIL|TB_.*TIMEOUT|Fatal:' {CORRECT_DIR}/run.log | tail -20 || true",
        f"find {CORRECT_DIR} -maxdepth 1 -type f -printf '%s %f\\n' 2>/dev/null | sort -n || true",
    ]))
    print(out, flush=True)
    return client


def collect_correct(client, out_dir: Path):
    target = out_dir / "correct_tick1"
    target.mkdir(parents=True, exist_ok=True)
    names = ("run.log", "result.csv", "events.csv", "latency.csv", "flit_latency.csv", "v3_metrics.csv")
    sftp = client.open_sftp()
    hashes = {}
    try:
        for name in names:
            src, dst = f"{CORRECT_DIR}/{name}", target / name
            sftp.get(src, str(dst))
            hashes[name] = hashlib.sha256(dst.read_bytes()).hexdigest()
    finally:
        sftp.close()
    (target / "hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")
    print("SYNC64_TICK1_COLLECT_PASS", target, flush=True)
    return client


def make_probe_case(out_dir: Path) -> Path:
    src = out_dir / "original.case"
    dst = out_dir / f"pkt{PROBE_SEQ}_src6_dst38.case"
    lines = src.read_text(encoding="utf-8").splitlines()
    kept = []
    for line in lines:
        fields = line.split()
        if not fields:
            kept.append(line); continue
        tag = fields[0]
        if tag == "case": kept.append(f"case SYNC64_VCD_PKT{PROBE_SEQ}")
        elif tag == "input":
            if int(fields[3]) == PROBE_SEQ:
                fields[1] = "0"
                kept.append(" ".join(fields[:5]) + f" # e{PROBE_SEQ:06d} probe")
        elif tag == "expect":
            if int(fields[2]) == PROBE_SEQ: kept.append(line)
        elif tag == "event_map":
            if int(fields[1]) == PROBE_SEQ: kept.append(line)
        elif tag == "meta" and len(fields) >= 3 and fields[1] in ("original_event_count", "warmup_original_events", "measurement_original_events"):
            value = "1" if fields[1] in ("original_event_count", "measurement_original_events") else "0"
            kept.append(f"meta {fields[1]} {value}")
        else: kept.append(line)
    dst.write_text("\n".join(kept) + "\n", encoding="utf-8")
    if sum(1 for x in kept if x.startswith("input ")) != 5 or sum(1 for x in kept if x.startswith("expect ")) != 5:
        raise RuntimeError("probe case is not exactly one 5-flit packet")
    return dst


def submit_vcd_probe(client, out_dir: Path):
    case = make_probe_case(out_dir)
    remote_case = f"{ROOT}/logs/gls/{CORRECT_RUN}/{case.name}"
    wrapper = f"{ROOT}/logs/gls/{CORRECT_RUN}/run_vcd_pkt{PROBE_SEQ}.sh"
    sftp = client.open_sftp()
    sftp.put(str(case), remote_case)
    body = f"""#!/bin/bash
set -euo pipefail
mkdir -p {PROBE_DIR}
cd {PROBE_DIR}
exec {WORK}/simv +CASE_FILE={remote_case} +RESULT_CSV={PROBE_DIR}/result.csv \\
 +EVENT_CSV={PROBE_DIR}/events.csv +LATENCY_CSV={PROBE_DIR}/latency.csv \\
 +FLIT_LATENCY_CSV={PROBE_DIR}/flit_latency.csv +V3_METRICS_CSV={PROBE_DIR}/v3_metrics.csv \\
 +DUMP_VCD={PROBE_DIR}/pkt{PROBE_SEQ}.vcd +CLOCK_PERIOD_NS=1.05 +CASE_TICK_NS=1 \\
 +RX_CAPTURE_NS=0 +STALL_TIMEOUT_NS=5000 +HARD_TIMEOUT_NS=50000 -l {PROBE_DIR}/run.log
"""
    with sftp.file(wrapper, "w") as f: f.write(body)
    sftp.chmod(wrapper, 0o755); sftp.close()
    client, out = remote(client, f"bsub -n 8 -m 'node21 node26 node24 node18' -oo {PROBE_DIR}.lsf.log -eo {PROBE_DIR}.lsf.err -J sync64_vcd665 {wrapper}")
    print(out, flush=True)
    m = re.search(r"Job <(\d+)>", out)
    if not m: raise RuntimeError("VCD probe submit failed")
    state = json.loads((out_dir / "state.json").read_text())
    state["vcd_job_id"] = m.group(1)
    (out_dir / "state.json").write_text(json.dumps(state, indent=2) + "\n")
    return client


def vcd_status(client, out_dir: Path):
    state = json.loads((out_dir / "state.json").read_text()); jid = state["vcd_job_id"]
    client, out = remote(client, "\n".join([
        f"bjobs -a {jid} -noheader -o 'jobid stat job_name exec_host run_time' 2>/dev/null || true",
        f"grep -E 'TB_INFO|TB_RESULT|FAIL|TIMEOUT|Fatal:' {PROBE_DIR}/run.log 2>/dev/null | tail -20 || true",
        f"find {PROBE_DIR} -maxdepth 1 -type f -printf '%s %f\\n' 2>/dev/null | sort -n || true",
    ]))
    print(out, flush=True); return client


def collect_vcd(client, out_dir: Path):
    target = out_dir / "vcd_pkt665"; target.mkdir(parents=True, exist_ok=True)
    sftp = client.open_sftp()
    try:
        for name in ("pkt665.vcd", "run.log", "result.csv", "events.csv"):
            sftp.get(f"{PROBE_DIR}/{name}", str(target / name))
    finally: sftp.close()
    print("SYNC64_VCD_COLLECT_PASS", target, flush=True); return client


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("stage", choices=("snapshot", "collect", "submit-correct-tick", "correct-status", "collect-correct", "submit-vcd-probe", "vcd-status", "collect-vcd"))
    ap.add_argument("--out", type=Path, default=Path("DATE paper/experiments/raw/paper64/sync64_first_flit_20260916"))
    args = ap.parse_args()
    client = connect_remote()
    try:
        if args.stage == "snapshot": snapshot(client)
        elif args.stage == "collect": collect(client, args.out)
        elif args.stage == "submit-correct-tick": submit_correct_tick(client, args.out)
        elif args.stage == "correct-status": correct_status(client, args.out)
        elif args.stage == "collect-correct": collect_correct(client, args.out)
        elif args.stage == "submit-vcd-probe": submit_vcd_probe(client, args.out)
        elif args.stage == "vcd-status": vcd_status(client, args.out)
        else: collect_vcd(client, args.out)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
