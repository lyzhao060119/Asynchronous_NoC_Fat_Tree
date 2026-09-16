#!/usr/bin/env python3
"""Run the matched 30-point Sync PROP_temp64 B8 UR sweep.

This runner is intentionally frozen-netlist only.  It reuses the canonical
PROP_temp64 cases and the already compiled, MAXIMUM-SDF Sync B8 simulator;
it never emits RTL, uploads cases, or invokes Design Compiler.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shlex
import statistics
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect  # noqa: E402
from run_remote_prop_temp64 import remote  # noqa: E402
from reaggregate_flit_latency import reaggregate  # noqa: E402

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
NETLIST_RUN = "20260915_231600_sync_prop_temp64_b8_dc"
SOURCE_RUN = "20260916_004500_sync_prop_temp64_b8_m5"
SOURCE_CASE = "TOPO-UR_n64_s202701_m5_PROP_temp64_top16"
SOURCE_WORK = f"{ROOT}/sim/work/{SOURCE_RUN}/sdf/{SOURCE_CASE}"
SIMV = f"{SOURCE_WORK}/simv"
SHARED_SDF_LOG = f"{SOURCE_WORK}/sdf_annotate.log"
# The later canonical archive contains the complete 30-point grid.  Its
# overlapping M5--M200 files are byte-identical to the earlier m5_200 archive.
CASE_DIR = f"{ROOT}/sim/prop_temp64_20260913_prop_temp64_asap_uc_m5_500/cases"
M5_RUN = "20260916_sync64_m5_tick1_diagnosis"
M5_DIR = f"{ROOT}/logs/gls/{M5_RUN}/{SOURCE_CASE}"
LOADS = (5, 10, 20, *range(40, 501, 20), 600, 700, 800)
SUBMIT_LOADS = tuple(load for load in LOADS if load != 5)
FAIL_TOKENS = (
    "TB_RESULT FAIL", "TB_X_FAIL", "TB_PROTOCOL_X", "TB_UNEXPECTED_FAIL",
    "TB_STALL_FAIL", "TB_HARD_TIMEOUT", "TB_FATAL", "Fatal:",
    "Timing violation",
)


def case_name(load: int) -> str:
    return f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"


def connect_remote():
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    return connect(attempts=3)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_default(run_id: str) -> Path:
    return REPO / "DATE paper/experiments/raw/paper64" / run_id


def remote_run_dir(run_id: str) -> str:
    return f"{ROOT}/logs/gls/{run_id}"


def remote_preflight(client) -> tuple[object, dict]:
    cases = " ".join(shlex.quote(f"{CASE_DIR}/{case_name(load)}.case") for load in LOADS)
    cmd = f"""
set -e
test -x {shlex.quote(SIMV)}
test -s {shlex.quote(SHARED_SDF_LOG)}
grep -q 'Total errors: 0' {shlex.quote(SHARED_SDF_LOG)}
test -s {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes.ddc')}
test -s {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes.sdc')}
test -s {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes_post.v')}
test -s {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes.sdf')}
test -s {shlex.quote(M5_DIR + '/run.log')}
grep -q 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' {shlex.quote(M5_DIR + '/run.log')}
for f in {cases}; do
  test -s "$f"
  test "$(awk '$1==\"meta\" && $2==\"case_tick_ns\" {{print $3; exit}}' "$f")" = 1.000
  test "$(awk '$1==\"meta\" && $2==\"seed\" {{print $3; exit}}' "$f")" = 202701
  test "$(awk '$1==\"meta\" && $2==\"packet_flits\" {{print $3; exit}}' "$f")" = 5
  test "$(awk '$1==\"meta\" && $2==\"original_event_count\" {{print $3; exit}}' "$f")" = 11000
done
echo PREFLIGHT_FILES
sha256sum {shlex.quote(SIMV)} \
 {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes.ddc')} \
 {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes.sdc')} \
 {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes_post.v')} \
 {shlex.quote(ROOT + '/outputs/' + NETLIST_RUN + '/SyncNoC_64nodes.sdf')}
echo PREFLIGHT_CASES
sha256sum {cases}
echo SYNC64_UR30_PREFLIGHT_PASS
"""
    client, output = remote(client, cmd)
    if "SYNC64_UR30_PREFLIGHT_PASS" not in output:
        raise RuntimeError("remote Sync64 UR30 preflight failed")
    hashes = {}
    for digest, path in re.findall(r"(?m)^([0-9a-f]{64})\s+(.+)$", output):
        hashes[path.strip()] = digest
    if len([p for p in hashes if p.endswith(".case")]) != 30:
        raise RuntimeError("preflight did not hash exactly 30 canonical cases")
    return client, {"output": output, "hashes": hashes}


def wrapper_text(run_id: str) -> str:
    loads = " ".join(str(x) for x in SUBMIT_LOADS)
    return f"""#!/bin/bash
set -euo pipefail
ROOT={shlex.quote(ROOT)}
RUN_ID={shlex.quote(run_id)}
SIMV={shlex.quote(SIMV)}
SHARED_SDF_LOG={shlex.quote(SHARED_SDF_LOG)}
CASE_DIR={shlex.quote(CASE_DIR)}
NETLIST_RUN={shlex.quote(NETLIST_RUN)}
LOADS=({loads})
INDEX=${{LSB_JOBINDEX:?LSF array index required}}
LOAD=${{LOADS[$((INDEX-1))]}}
CASE=TOPO-UR_n64_s202701_m${{LOAD}}_PROP_temp64_top16
CASE_FILE=$CASE_DIR/$CASE.case
LOG=$ROOT/logs/gls/$RUN_ID/sdf/$CASE
mkdir -p "$LOG"
cd "$LOG"
META_TICK=$(awk '$1=="meta" && $2=="case_tick_ns" {{print $3; exit}}' "$CASE_FILE")
if [[ "$META_TICK" != 1.000 ]]; then
  echo "SYNC64_UR30_FAIL load=$LOAD case_tick=$META_TICK" >&2
  exit 2
fi
sha256sum "$CASE_FILE" "$SIMV" \
 "$ROOT/outputs/$NETLIST_RUN/SyncNoC_64nodes_post.v" \
 "$ROOT/outputs/$NETLIST_RUN/SyncNoC_64nodes.sdf" > input_hashes.log
echo "clock_period_ns=1.05 case_tick_ns=1.000 netlist_run=$NETLIST_RUN" >> input_hashes.log
set +e
"$SIMV" +CASE_FILE="$CASE_FILE" +RESULT_CSV="$LOG/result.csv" \
 +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
 +FLIT_LATENCY_CSV="$LOG/flit_latency.csv" +V3_METRICS_CSV="$LOG/v3_metrics.csv" \
 +CLOCK_PERIOD_NS=1.05 +CASE_TICK_NS=1 +RX_CAPTURE_NS=0 \
 +STALL_TIMEOUT_NS=100000 +HARD_TIMEOUT_NS=2000000 \
 -l "$LOG/run.log" > "$LOG/stdout.log" 2>&1
RC=$?
set -e
cp "$SHARED_SDF_LOG" "$LOG/sdf_annotate.log"
test "$RC" -eq 0
grep -q 'Doing SDF annotation ...... Done' "$LOG/run.log"
grep -q 'Total errors: 0' "$LOG/sdf_annotate.log"
grep -q 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' "$LOG/run.log"
! grep -Eiq 'TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation' "$LOG/run.log" "$LOG/stdout.log"
test -s "$LOG/result.csv" && test -s "$LOG/events.csv"
test -s "$LOG/latency.csv" && test -s "$LOG/flit_latency.csv"
echo "SYNC64_UR30_CASE_PASS load=$LOAD case=$CASE" | tee "$LOG/acceptance.log"
"""


def write_state(out: Path, state: dict) -> None:
    out.mkdir(parents=True, exist_ok=True)
    (out / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")


def load_state(out: Path) -> dict:
    return json.loads((out / "state.json").read_text(encoding="utf-8"))


def do_preflight(client, run_id: str, out: Path) -> object:
    client, evidence = remote_preflight(client)
    state = {
        "run_id": run_id,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "netlist_run_id": NETLIST_RUN,
        "clock_period_ns": 1.05,
        "case_tick_ns": 1.0,
        "loads": list(LOADS),
        "submit_loads": list(SUBMIT_LOADS),
        "m5_reuse_run": M5_RUN,
        "remote_hashes": evidence["hashes"],
        "status": "preflight_pass",
    }
    write_state(out, state)
    (out / "preflight.log").write_text(evidence["output"], encoding="utf-8")
    print(f"SYNC64_UR30_PREFLIGHT_PASS run={run_id} out={out}", flush=True)
    return client


def do_submit(client, run_id: str, out: Path) -> object:
    if not (out / "state.json").is_file():
        client = do_preflight(client, run_id, out)
    state = load_state(out)
    if state.get("array_job_id"):
        raise RuntimeError("refusing duplicate submission: " + str(state["array_job_id"]))
    run_dir = remote_run_dir(run_id)
    client, exists = remote(client, f"test -e {shlex.quote(run_dir)} && echo EXISTS || echo NEW")
    if "EXISTS" in exists:
        raise RuntimeError("refusing to overwrite remote run " + run_id)
    wrapper = f"{run_dir}/run_array.sh"
    sftp = client.open_sftp()
    try:
        sftp.mkdir(run_dir)
        with sftp.file(wrapper, "w") as handle:
            handle.write(wrapper_text(run_id))
        sftp.chmod(wrapper, 0o755)
    finally:
        sftp.close()
    job_name = f"s64ur_{run_id[-13:]}[1-{len(SUBMIT_LOADS)}]%4"
    command = (
        f"bsub -n 8 -m 'node21 node26 node24 node18' "
        f"-J {shlex.quote(job_name)} -oo {shlex.quote(run_dir + '/lsf.%I.log')} "
        f"-eo {shlex.quote(run_dir + '/lsf.%I.err')} {shlex.quote(wrapper)}"
    )
    client, submitted = remote(client, command)
    match = re.search(r"Job <(\d+)>", submitted)
    if not match:
        raise RuntimeError("LSF array submission failed: " + submitted)
    state.update({"array_job_id": match.group(1), "status": "submitted", "submit_output": submitted.strip()})
    write_state(out, state)
    print(f"SYNC64_UR30_SUBMITTED job={match.group(1)} cases={len(SUBMIT_LOADS)} run={run_id}", flush=True)
    return client


def do_status(client, out: Path) -> object:
    state = load_state(out)
    run_id, jid = state["run_id"], state["array_job_id"]
    run_dir = remote_run_dir(run_id)
    cmd = f"""
echo LSF_STATUS
bjobs -a {shlex.quote(jid)} 2>/dev/null || true
echo CASE_COUNTS
echo PASS $(grep -Rhl '^SYNC64_UR30_CASE_PASS' {shlex.quote(run_dir + '/sdf')}/*/acceptance.log 2>/dev/null | wc -l)
echo RUNNING $(find {shlex.quote(run_dir + '/sdf')} -mindepth 2 -maxdepth 2 -name run.log -type f 2>/dev/null | wc -l)
echo FAIL $(grep -RilE 'TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation|SYNC64_UR30_FAIL' {shlex.quote(run_dir + '/sdf')} 2>/dev/null | wc -l)
grep -RhE 'TB_RESULT (PASS|FAIL)|SYNC64_UR30_CASE_PASS' {shlex.quote(run_dir + '/sdf')} 2>/dev/null | tail -40 || true
"""
    client, output = remote(client, cmd)
    print(output, flush=True)
    return client


def fetch_file(sftp, remote_path: str, local_path: Path, required: bool = True) -> None:
    local_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        sftp.get(remote_path, str(local_path))
    except IOError:
        if required:
            raise


def do_collect(client, out: Path) -> object:
    state = load_state(out)
    run_id = state["run_id"]
    raw = out / "raw"
    sftp = client.open_sftp()
    try:
        for load in SUBMIT_LOADS:
            case = case_name(load)
            src = f"{remote_run_dir(run_id)}/sdf/{case}"
            dst = raw / case
            for name in ("acceptance.log", "run.log", "stdout.log", "result.csv", "events.csv",
                         "latency.csv", "flit_latency.csv", "v3_metrics.csv",
                         "sdf_annotate.log", "input_hashes.log"):
                fetch_file(sftp, f"{src}/{name}", dst / name)
        for name in ("run.log", "result.csv", "events.csv", "latency.csv",
                     "flit_latency.csv", "v3_metrics.csv", "sdf_annotate.log"):
            fetch_file(sftp, f"{M5_DIR}/{name}", raw / SOURCE_CASE / name,
                       required=name != "sdf_annotate.log")
    finally:
        sftp.close()
    state["status"] = "collected"
    write_state(out, state)
    print(f"SYNC64_UR30_COLLECT_PASS run={run_id} out={out}", flush=True)
    return client


def parse_result(path: Path) -> dict[str, str]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise ValueError("result CSV must have one row: " + str(path))
    return rows[0]


def measurement_window_metrics(latency_csv: Path, events_csv: Path) -> dict[str, int | float]:
    packet_to_event: dict[int, int] = {}
    with latency_csv.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            packet = int(row["pkt_seq"])
            event = int(row["original_event_id"])
            previous = packet_to_event.setdefault(packet, event)
            if previous != event:
                raise ValueError(f"packet {packet} has inconsistent original events")
    selected = {packet for packet, event in packet_to_event.items() if 1000 <= event < 11000}
    if len(selected) != 10000:
        raise ValueError(f"measurement window has {len(selected)} packets, expected 10000")
    tx: list[dict[str, str]] = []
    rx: list[dict[str, str]] = []
    with events_csv.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if int(row["pkt_seq"]) not in selected:
                continue
            if row["kind"] == "TX":
                tx.append(row)
            elif row["kind"] == "RX":
                rx.append(row)
    if len(tx) != 50000 or len(rx) != 50000:
        raise ValueError(f"measurement events TX/RX={len(tx)}/{len(rx)}, expected 50000/50000")
    start_ps = min(int(row["offer_ps"]) for row in tx)
    end_ps = max(int(row["offer_ps"]) for row in tx)
    if end_ps <= start_ps:
        raise ValueError("non-positive measurement window")
    injected = sum(int(row["req_ps"]) <= end_ps for row in tx)
    delivered = sum(int(row["egress_req_ps"]) <= end_ps and row["matched"] == "1" for row in rx)
    source_backlog = len(tx) - injected
    network_inflight = injected - delivered
    if source_backlog < 0 or network_inflight < 0:
        raise ValueError("negative measurement backlog accounting")
    duration_ns = (end_ps - start_ps) / 1000.0
    return {
        "measurement_start_ps": start_ps,
        "measurement_end_ps": end_ps,
        "measurement_offered_flits": len(tx),
        "measurement_injected_flits": injected,
        "measurement_delivered_flits": delivered,
        "measurement_source_backlog_flits": source_backlog,
        "measurement_network_inflight_flits": network_inflight,
        "measurement_total_backlog_flits": len(tx) - delivered,
        "measurement_delivery_ratio": delivered / len(tx),
        "offered_mflit_per_port_s": 1000.0 * len(tx) / duration_ns / 64.0,
        "delivered_mflit_per_port_s": 1000.0 * delivered / duration_ns / 64.0,
    }


def rankdata(values: list[float]) -> list[float]:
    order = sorted(range(len(values)), key=values.__getitem__)
    ranks = [0.0] * len(values)
    pos = 0
    while pos < len(order):
        end = pos + 1
        while end < len(order) and values[order[end]] == values[order[pos]]:
            end += 1
        rank = (pos + end - 1) / 2.0 + 1.0
        for idx in order[pos:end]:
            ranks[idx] = rank
        pos = end
    return ranks


def spearman(xs: list[float], ys: list[float]) -> float:
    rx, ry = rankdata(xs), rankdata(ys)
    mx, my = statistics.mean(rx), statistics.mean(ry)
    num = sum((x - mx) * (y - my) for x, y in zip(rx, ry))
    denx = sum((x - mx) ** 2 for x in rx)
    deny = sum((y - my) ** 2 for y in ry)
    return num / (denx * deny) ** 0.5 if denx and deny else 1.0


def do_finalize(out: Path) -> None:
    state = load_state(out)
    rows = []
    for load in LOADS:
        case = case_name(load)
        base = out / "raw" / case
        run_text = (base / "run.log").read_text(errors="replace")
        if "TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0" not in run_text:
            raise RuntimeError("missing clean full-drain marker: " + case)
        if any(token in run_text for token in FAIL_TOKENS):
            raise RuntimeError("failure token in " + case)
        result = parse_result(base / "result.csv")
        if result["pass_fail"] != "PASS" or int(result["injected_flits"]) != 55000 or int(result["delivered_flits"]) != 55000:
            raise RuntimeError("result count failure: " + case)
        cohort = reaggregate(base / "latency.csv", base / "flit_latency.csv")
        window = measurement_window_metrics(base / "latency.csv", base / "events.csv")
        rows.append({
            "design": "SYNC_PROP_temp64_B8", "load": load, "case": case,
            "clock_period_ns": 1.05, "case_tick_ns": 1.0,
            "injected_flits": 55000, "delivered_flits": 55000,
            "measurement_packets": cohort["measurement_packets"],
            "measurement_flits": cohort["measurement_flits"],
            **window,
            "cohort_mean_ns": cohort["flit_latency_mean_ns"],
            "cohort_p50_ns": cohort["flit_latency_p50_ns"],
            "cohort_p95_ns": cohort["flit_latency_p95_ns"],
            "cohort_p99_ns": cohort["flit_latency_p99_ns"],
            "cohort_max_ns": cohort["flit_latency_max_ns"],
            "delivered_throughput_flit_per_ns": result["delivered_throughput"],
            "case_sha256": state["remote_hashes"][f"{CASE_DIR}/{case}.case"],
            "latency_sha256": sha(base / "latency.csv"),
            "flit_latency_sha256": sha(base / "flit_latency.csv"),
            "events_sha256": sha(base / "events.csv"),
            "full_drain_pass": True,
            "near_lossless": window["measurement_delivery_ratio"] >= 0.99 and
                              window["measurement_source_backlog_flits"] <= 5,
            "paper_latency_eligible": window["measurement_delivery_ratio"] >= 0.99 and
                                      window["measurement_source_backlog_flits"] <= 5,
        })
    if len(rows) != 30 or len({int(row["load"]) for row in rows}) != 30:
        raise RuntimeError("Sync UR matrix is not exactly 30 unique loads")
    fields = list(rows[0])
    for name in ("summary.csv", "acceptance.csv"):
        with (out / name).open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader(); writer.writerows(rows)
    trend_rows = []
    eligible_rows = [row for row in rows if row["paper_latency_eligible"]]
    for metric in ("cohort_mean_ns", "cohort_p95_ns"):
        decreases = []
        for previous, current in zip(eligible_rows, eligible_rows[1:]):
            old, new = float(previous[metric]), float(current[metric])
            if new < old:
                decreases.append((previous["load"], current["load"], 100.0 * (old - new) / old))
        trend_rows.append({
            "design": "SYNC_PROP_temp64_B8", "metric": metric,
            "points": len(eligible_rows), "excluded_censored_points": len(rows) - len(eligible_rows),
            "adjacent_decreases": len(decreases),
            "maximum_decrease_percent": max((x[2] for x in decreases), default=0.0),
            "spearman_rho": spearman([float(r["load"]) for r in eligible_rows],
                                     [float(r[metric]) for r in eligible_rows]),
            "soft_anomaly": any(x[2] > 5.0 for x in decreases),
        })
    with (out / "latency_trend.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(trend_rows[0]))
        writer.writeheader(); writer.writerows(trend_rows)
    state["status"] = "finalized"
    state["git_commit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    state["dirty"] = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=REPO))
    write_state(out, state)
    (out / "RESULTS.md").write_text(
        "# Sync PROP_temp64 B8 UR30\n\n"
        "Frozen post-synthesis MAXIMUM-SDF sweep at a 1.05 ns clock and 1 ns canonical case tick.\n"
        "All accepted points use the 10,000-packet / 50,000-flit full-drain measurement-offer cohort.\n",
        encoding="utf-8",
    )
    print(f"SYNC64_UR30_FINALIZE_PASS out={out}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("preflight", "submit", "status", "collect", "finalize"))
    parser.add_argument("--run-id")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    run_id = args.run_id or ("sync64_ur_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
    out = args.out or local_default(run_id)
    if args.stage == "finalize":
        do_finalize(out)
        return 0
    client = connect_remote()
    try:
        if args.stage == "preflight":
            do_preflight(client, run_id, out)
        elif args.stage == "submit":
            do_submit(client, run_id, out)
        elif args.stage == "status":
            do_status(client, out)
        else:
            do_collect(client, out)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
