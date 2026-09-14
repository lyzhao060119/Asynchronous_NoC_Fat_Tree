#!/usr/bin/env python3
"""Generate, submit, collect, and summarize the 2026-09-14 PROP_temp64 MC ablation."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import shlex
import statistics
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
V3 = REPO / "DATE paper" / "experiments" / "scripts"
sys.path.insert(0, str(V3))
sys.path.insert(0, str(HERE))

from date_v3.canonical_trace import dump_jsonl, generate_trace, trace_id  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import job_id  # noqa: E402
from run_remote_prop_temp64 import (  # noqa: E402
    FROZEN_NETLIST,
    ROOT,
    connect_failover,
    put_text,
    remote,
    upload,
    validate_netlist,
)

STAMP = "20260914"
BASE_RUN = STAMP + "_prop_temp64_mc_emergency"
LOADS = (5, 10, 20, 40, 80, 120, 180, 260, 360, 500)
EXTENDED_LOADS = (600, 700, 800, 900)
FANOUTS = (2, 4, 8, 16, 32)
SCHEMES = ("native", "source_repeated_unicast")
CASE_ROOT = HERE / "generated_cases" / BASE_RUN
TRACE_DIR = CASE_ROOT / "traces"
CASE_DIR = CASE_ROOT / "cases"
RESULT_ROOT = HERE / "results" / BASE_RUN
RAW_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "prop_temp64" / BASE_RUN
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')


def bench(fanout: int) -> str:
    return "MC-REGION-F%d" % fanout


def case_stem(fanout: int, load: int, scheme: str) -> str:
    base = "%s_n64_s202701_m%d" % (bench(fanout), load)
    suffix = "PROP_temp64" if scheme == "native" else "source_repeated_unicast"
    return "%s_%s_top16" % (base, suffix)


def generate(loads: tuple[int, ...] = LOADS + EXTENDED_LOADS,
             fanouts: tuple[int, ...] = FANOUTS) -> None:
    TRACE_DIR.mkdir(parents=True, exist_ok=True)
    CASE_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for fanout in fanouts:
        for load in loads:
            trace = generate_trace(
                bench(fanout), seed=202701, nodes=64, load_point=load,
                warmup=64, measurement=400, smoke=False,
            )
            tid = trace_id(trace["header"])
            trace_path = TRACE_DIR / (tid + ".jsonl")
            digest = dump_jsonl(trace, trace_path)
            for scheme in SCHEMES:
                path = materialize_path(
                    trace_path, CASE_DIR, top_lanes=16, routing="quadtree",
                    design_id="PROP_temp64",
                    source_repeated_unicast=(scheme != "native"),
                )
                obj = json.loads(path.with_suffix(".packets.json").read_text(encoding="utf-8"))
                packets = obj["packets"]
                expected_packets = 464 if scheme == "native" else 464 * fanout
                if len(packets) != expected_packets:
                    raise RuntimeError("%s packet count %d != %d" % (path.name, len(packets), expected_packets))
                if max(int(p["pkt_seq"]) for p in packets) >= 16384:
                    raise RuntimeError("%s exceeds 14-bit packet identity" % path.name)
                delivered = sum(len(p["delivered_destinations"]) for p in packets)
                if delivered != 464 * fanout:
                    raise RuntimeError("%s destination copies %d" % (path.name, delivered))
                rows.append({"fanout": fanout, "load": load, "scheme": scheme,
                             "case": path.stem, "trace_sha256": digest})
    existing_manifest = CASE_ROOT / "manifest.json"
    if existing_manifest.is_file():
        prior = json.loads(existing_manifest.read_text(encoding="utf-8"))
        rows = list({entry["case"]: entry for entry in prior.get("rows", []) + rows}.values())
        loads = tuple(sorted({int(entry["load"]) for entry in rows}))
    existing_manifest.write_text(
        json.dumps({"run_id": BASE_RUN, "seed": 202701, "warmup": 64,
                    "measurement": 400, "loads": list(loads), "rows": rows}, indent=2) + "\n",
        encoding="utf-8",
    )
    print("EMERGENCY_MC_GENERATE_PASS cases=%d" % len(rows), flush=True)


def selected(args: argparse.Namespace) -> list[tuple[int, int, str]]:
    fanouts = tuple(args.fanout or (16,))
    loads = tuple(args.load or (5,))
    schemes = tuple(args.scheme or SCHEMES)
    return [(f, load, scheme) for f in fanouts for load in loads for scheme in schemes]


def remote_layout(run_id: str) -> tuple[str, str]:
    sim = "%s/sim/prop_temp64_%s" % (ROOT, run_id)
    shell = "%s/scripts/prop_temp64_%s/run_gls_prop_temp64.sh" % (ROOT, run_id)
    return sim, shell


def submit(args: argparse.Namespace) -> None:
    picks = selected(args)
    missing = [case_stem(*x) for x in picks if not (CASE_DIR / (case_stem(*x) + ".case")).is_file()]
    if missing:
        raise SystemExit("missing generated cases: " + ",".join(missing))
    client = connect_failover()
    try:
        client = validate_netlist(client, FROZEN_NETLIST)
        sim, shell = remote_layout(args.run_id)
        client, _ = remote(client, "mkdir -p %s/cases %s/scripts/prop_temp64_%s %s/logs/gls/%s %s/results/%s/csv" %
                           (sim, ROOT, args.run_id, ROOT, args.run_id, ROOT, args.run_id))
        common = {
            HERE / "run_gls_prop_temp64.sh": shell,
            REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": sim + "/async_prop_temp64_port_adapter.sv",
            REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": sim + "/tb_noc64_async_boundary.sv",
            HERE / "tb_cmr_noc64_async_boundary_failfast.sv": sim + "/tb_cmr_noc64_async_boundary_failfast.sv",
            REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py": sim + "/patch_gls_netlist.py",
        }
        for src, dst in common.items():
            client = upload(client, src, dst)
        client, _ = remote(client, "chmod +x " + shlex.quote(shell))
        jobs = []
        for fanout, load, scheme in picks:
            name = case_stem(fanout, load, scheme)
            local_case = CASE_DIR / (name + ".case")
            client = upload(client, local_case, sim + "/cases/" + local_case.name)
            wrapper = "%s/logs/gls/%s/sdf_%s.sh" % (ROOT, args.run_id, name)
            body = (
                "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                "export CMR_REMOTE_ROOT={root} PROP_TEMP64_RUN_ID={run} "
                "PROP_TEMP64_NETLIST_RUN_ID={netlist} PROP_TEMP64_MODE=sdf "
                "PROP_TEMP64_CASE_NAME={case} PROP_TEMP64_CASE_FILE={case_file} "
                "PROP_TEMP64_RX_CAPTURE_NS=0.1 PROP_TEMP64_STALL_TIMEOUT_NS=500000 "
                "PROP_TEMP64_HARD_TIMEOUT_NS=4000000\nexec bash {shell}\n"
            ).format(root=ROOT, run=args.run_id, netlist=FROZEN_NETLIST, case=name,
                     case_file=sim + "/cases/" + local_case.name, shell=shell)
            client = put_text(client, body, wrapper)
            client, _ = remote(client, "chmod +x " + shlex.quote(wrapper))
            log = "%s/logs/gls/%s/sdf_%s.job.log" % (ROOT, args.run_id, name)
            client, out = remote(client, "bsub -n 8 %s -o %s -e %s.err -J %s %s" %
                                 (HOSTS, shlex.quote(log), shlex.quote(log),
                                  shlex.quote("mc_f%d_m%d_%s" % (fanout, load, "n" if scheme == "native" else "r")),
                                  shlex.quote(wrapper)))
            jid = job_id(out)
            jobs.append({"fanout": fanout, "load": load, "scheme": scheme, "case": name, "job_id": jid})
            print("EMERGENCY_MC_SUBMITTED", name, jid, flush=True)
        RESULT_ROOT.mkdir(parents=True, exist_ok=True)
        (RESULT_ROOT / (args.run_id + "_jobs.json")).write_text(
            json.dumps({"run_id": args.run_id, "netlist_run_id": FROZEN_NETLIST, "jobs": jobs}, indent=2) + "\n",
            encoding="utf-8")
    finally:
        client.close()


def fetch_file(sftp, remote_path: str, local_path: Path) -> bool:
    try:
        local_path.parent.mkdir(parents=True, exist_ok=True)
        sftp.get(remote_path, str(local_path))
        return local_path.is_file() and local_path.stat().st_size > 0
    except OSError:
        return False


def collect(args: argparse.Namespace) -> None:
    picks = selected(args)
    client = connect_failover()
    try:
        sftp = client.open_sftp()
        states = []
        for fanout, load, scheme in picks:
            name = case_stem(fanout, load, scheme)
            local = RESULT_ROOT / args.run_id / name
            remote_log = "%s/logs/gls/%s/sdf/%s" % (ROOT, args.run_id, name)
            for fn in ("run.log", "stdout.log", "compile.log", "sdf_annotate.log", "events.csv", "latency.csv", "flit_latency.csv", "v3_metrics.csv", "input_hashes.log"):
                fetch_file(sftp, remote_log + "/" + fn, local / fn)
            fetch_file(sftp, "%s/results/%s/csv/sdf_%s.csv" % (ROOT, args.run_id, name), local / "result.csv")
            text = (local / "run.log").read_text(encoding="utf-8", errors="replace") if (local / "run.log").is_file() else ""
            sdf = (local / "sdf_annotate.log").read_text(encoding="utf-8", errors="replace") if (local / "sdf_annotate.log").is_file() else ""
            stdout = (local / "stdout.log").read_text(encoding="utf-8", errors="replace") if (local / "stdout.log").is_file() else ""
            bad = any(x in text for x in ("TB_RESULT FAIL", "TB_X_FAIL", "TB_PROTOCOL_X", "TB_STALL_FAIL", "TB_HARD_TIMEOUT", "TB_FATAL", "Fatal:", "Timing violation"))
            passed = (
                "TB_RESULT PASS" in text
                and "PROP_TEMP64_GLS_PASS " + name in stdout
            )
            passed = passed and not bad and bool(__import__("re").search(r"Total errors:\s*0\b", sdf))
            states.append({"case": name, "fanout": fanout, "load": load, "scheme": scheme,
                           "status": "PASS" if passed else ("FAIL" if text else "PENDING")})
            print("EMERGENCY_MC_STATUS", name, states[-1]["status"], flush=True)
        sftp.close()
        (RESULT_ROOT / args.run_id / "status.json").write_text(json.dumps(states, indent=2) + "\n", encoding="utf-8")
    finally:
        client.close()


def percentile(values: list[float], q: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, max(0, math.ceil(q * len(ordered)) - 1))]


def transaction_latency(scheduled_abs_ns: float, intended: set[int], tails: dict[int, float]) -> float | None:
    if not intended.issubset(tails):
        return None
    return max(tails[dest] for dest in intended) - scheduled_abs_ns


def summarize_case(run_id: str, fanout: int, load: int, scheme: str) -> dict[str, object]:
    name = case_stem(fanout, load, scheme)
    local = RESULT_ROOT / run_id / name
    result = next(csv.DictReader((local / "result.csv").open(encoding="utf-8", newline="")))
    if result.get("pass_fail") != "PASS":
        raise RuntimeError("%s result is not PASS" % name)
    packet_obj = json.loads((CASE_DIR / (name + ".packets.json")).read_text(encoding="utf-8"))
    packets = {int(p["pkt_seq"]): p for p in packet_obj["packets"]}
    tail_by_event: dict[str, dict[int, float]] = defaultdict(dict)
    with (local / "latency.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            meta = packets[int(row["pkt_seq"])]
            if meta["phase"] != "measurement":
                continue
            tail_by_event[meta["original_event_id"]][int(row["port"])] = float(row["tail_egress_req_ps"]) / 1000.0
    event_meta: dict[str, dict] = {}
    for meta in packets.values():
        if meta["phase"] == "measurement":
            event_meta.setdefault(meta["original_event_id"], meta)
    tx_rows = []
    with (local / "events.csv").open(encoding="utf-8", newline="") as handle:
        tx_rows = [row for row in csv.DictReader(handle) if row["kind"] == "TX"]
    epochs = []
    for row in tx_rows:
        pkt = int(row["pkt_seq"])
        if row.get("offer_ps") not in (None, "", "-1"):
            epochs.append(float(row["offer_ps"]) / 1000.0 - float(packets[pkt]["ready_cycle"]))
    if not epochs or max(epochs) - min(epochs) > 0.002:
        raise RuntimeError("%s cannot establish a single case epoch" % name)
    epoch_ns = statistics.median(epochs)
    scheduled = [float(meta["scheduled_cycle"]) for meta in event_meta.values()]
    window_start_ns = epoch_ns + min(scheduled)
    window_end_ns = epoch_ns + max(scheduled) + 1.0
    # Full-drain Abstract metric: count every measurement transaction whose
    # last intended destination Tail arrived (TB already ran to completion).
    # The old half-open window cut one late Tail and produced 399/400.
    lats, completed = [], 0
    for event_id, meta in event_meta.items():
        intended = set(meta["intended_destinations"])
        tails = tail_by_event.get(event_id, {})
        latency = transaction_latency(epoch_ns + float(meta["scheduled_cycle"]), intended, tails)
        if latency is not None:
            completed += 1
            lats.append(latency)
    drain_tails = [
        tail for event_id, times in tail_by_event.items()
        for tail in times.values() if event_id in event_meta
    ]
    drain_end_ns = max(drain_tails) if drain_tails else window_end_ns
    window_s = (max(window_end_ns, drain_end_ns) - window_start_ns) * 1e-9
    offered = len(event_meta) / window_s / 64 / 1e6
    completed_rate = completed / window_s / 64 / 1e6
    useful_copies = sum(
        1 for event_id, times in tail_by_event.items()
        for _dest, tail in times.items()
        if event_id in event_meta
    )
    useful = useful_copies / window_s / 64 / 1e6
    accepted_flits = []
    for row in tx_rows:
        pkt = int(row["pkt_seq"])
        if packets[pkt]["phase"] == "measurement" and row["matched"] == "1":
            accepted_flits.append(pkt)
    links = 0
    for pkt in accepted_flits:
        inter = [x for x in (packets[pkt].get("traversal") or {}).get("link_traversal", []) if "->PE(" not in x]
        links += len(inter)
    return {
        "scheme": scheme, "fanout": fanout, "load": load,
        "offered_transactions": offered, "completed_transactions": completed_rate,
        "useful_delivery_rate": useful,
        "mean_completion_latency": statistics.fmean(lats) if lats else math.nan,
        "p95_completion_latency": percentile(lats, .95), "p99_completion_latency": percentile(lats, .99),
        "injected_flits": len(accepted_flits), "link_traversals": links,
        "backlog": len(event_meta) - completed, "completed_count": completed,
        "measurement_transactions": len(event_meta),
        "trace_sha256": packet_obj["trace_hash"], "case": name,
    }


def summarize(args: argparse.Namespace) -> None:
    rows = [summarize_case(args.run_id, *pick) for pick in selected(args)]
    RAW_ROOT.mkdir(parents=True, exist_ok=True)
    detailed = RAW_ROOT / (args.run_id + "_detailed.csv")
    with detailed.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)
    if {int(row["fanout"]) for row in rows} == {16}:
        fields = ["load", "offered_transactions", "completed_transactions", "useful_delivery_rate",
                  "mean_completion_latency", "p95_completion_latency", "p99_completion_latency",
                  "injected_flits", "link_traversals", "backlog"]
        for scheme in SCHEMES:
            path = RAW_ROOT / ("multicast_main_%s.csv" % scheme)
            with path.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
                writer.writeheader(); writer.writerows(sorted((r for r in rows if r["scheme"] == scheme), key=lambda r: int(r["load"])))
    if len({int(row["fanout"]) for row in rows}) > 1 and len({int(row["load"]) for row in rows}) == 1:
        fields = ["scheme", "fanout", "mean_completion_latency", "link_traversals", "injected_flits", "useful_delivery_rate"]
        path = RAW_ROOT / "multicast_fanout.csv"
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
            writer.writeheader(); writer.writerows(sorted(rows, key=lambda r: (str(r["scheme"]), int(r["fanout"]))))
    print("EMERGENCY_MC_SUMMARY_PASS", detailed, flush=True)


def selftest() -> None:
    tails = {3: 14.0, 4: 11.0, 5: 19.0}
    assert transaction_latency(10.0, {3, 4, 5}, tails) == 9.0
    assert transaction_latency(10.0, {3, 4, 6}, tails) is None
    assert percentile([9.0, 1.0, 5.0, 3.0], .95) == 9.0
    print("EMERGENCY_MC_SELFTEST_PASS last_destination_tail", flush=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=("generate", "submit", "collect", "summarize", "selftest"))
    p.add_argument("--run-id", default=BASE_RUN + "_smoke")
    p.add_argument("--fanout", type=int, choices=FANOUTS, action="append")
    p.add_argument("--load", type=int, action="append")
    p.add_argument("--scheme", choices=SCHEMES, action="append")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    if args.action == "generate": generate(tuple(args.load or LOADS + EXTENDED_LOADS),
                                           tuple(args.fanout or FANOUTS))
    elif args.action == "submit": submit(args)
    elif args.action == "collect": collect(args)
    elif args.action == "summarize": summarize(args)
    else: selftest()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
