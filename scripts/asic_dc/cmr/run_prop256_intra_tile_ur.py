#!/usr/bin/env python3
"""PROP_temp256 same-tile (intra-tile) UR diagnostic.

Forces every unicast destination into the source's 8x8 tile so traffic never
needs the upper Mesh. Same ASAP injection / CASE_TICK=1 / frozen netlist as
tick1 Global UR. Stages: materialize | upload | submit | status | collect | all
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shlex
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from random import Random

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))

from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from cmr_frozen_run_ids import FROZEN_PROP_TEMP256_NETLIST_RUN_ID  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry, job_id  # noqa: E402

SEED = 202701
NODES = 256
WIDTH = 16
TILE = 8
DESIGN = "PROP_temp256"
TOP = "PROP_temp256"
KIND = "prop_temp"
NETLIST = FROZEN_PROP_TEMP256_NETLIST_RUN_ID
BUNDLE = HERE / "generated_cases" / "20260916_prop_temp256_intra_tile_ur_tick1"
CASE_DIR = BUNDLE / "cases"
TRACE_DIR = BUNDLE / "traces"
STATE_DIR = HERE / "results" / "prop256_intra_tile_ur"
REMOTE_ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

# Match Global UR coarse grid so the curves are directly comparable; extend
# higher in case local hierarchy recovers PROP64-like capacity.
COARSE_LOADS = (5, 20, 40, 80, 120, 160, 200, 280, 400, 600)
FINE_LOADS = (50, 60, 70, 90, 100, 110, 140, 180, 240, 320)
DEFAULT_LOADS = tuple(sorted(set(COARSE_LOADS + FINE_LOADS)))

WARMUP = 1000
MEASUREMENT = 10000
PACKET_FLITS = 5


def tile_of(pe: int) -> int:
    x = pe % WIDTH
    y = pe // WIDTH
    return (x // TILE) + 2 * (y // TILE)


def cluster_xy(pe: int) -> tuple[int, int]:
    x = pe % WIDTH
    y = pe // WIDTH
    return x // TILE, y // TILE


def choose_same_tile_dest(rng: Random, source: int) -> int:
    tx, ty = cluster_xy(source)
    pool = [
        pe
        for pe in range(NODES)
        if pe != source and cluster_xy(pe) == (tx, ty)
    ]
    if len(pool) != 63:
        raise RuntimeError("expected 63 same-tile peers for pe %d, got %d" % (source, len(pool)))
    return pool[rng.randrange(len(pool))]


def case_name(load: int) -> str:
    return "INTRA-TILE-UR_n256_s%d_m%d_%s_top0" % (SEED, load, DESIGN)


def materialize(loads: tuple[int, ...]) -> None:
    from date_v3.canonical_trace import (  # noqa: E402
        EVENT_SCHEMA,
        PACKET_FLITS as PF,
        TRACE_SCHEMA,
        bounding_rect,
        build_events,
        dump_jsonl,
        schedule_pairs,
        seed_mix,
        width_of,
    )
    from date_v3.hashutil import write_json  # noqa: E402
    from date_v3.materialize_case import materialize_path  # noqa: E402
    from date_v3.offered_load import load_tag, trace_load_fields  # noqa: E402

    assert PF == PACKET_FLITS
    assert width_of(NODES) == WIDTH
    TRACE_DIR.mkdir(parents=True, exist_ok=True)
    CASE_DIR.mkdir(parents=True, exist_ok=True)

    for load in loads:
        jsonl = TRACE_DIR / ("INTRA-TILE-UR_n256_s%d_m%d.jsonl" % (SEED, load))
        if not jsonl.is_file():
            dest_rng = Random(seed_mix(SEED, NODES, 17, 1))
            pairs = []
            cross = 0
            for _ in range(WARMUP + MEASUREMENT):
                source = dest_rng.randrange(NODES)
                dest = choose_same_tile_dest(dest_rng, source)
                if tile_of(dest) != tile_of(source):
                    cross += 1
                pairs.append(
                    {
                        "source": source,
                        "destinations": [dest],
                        "rect": bounding_rect([dest], WIDTH),
                        "multicast": False,
                    }
                )
            if cross:
                raise RuntimeError("intra-tile filter leaked %d cross-tile dests" % cross)
            sched_rng = Random(seed_mix(SEED, NODES, 17, int(load)))
            ready = schedule_pairs(
                pairs,
                nodes=NODES,
                packet_flits=PACKET_FLITS,
                load_point=float(load),
                rng=sched_rng,
            )
            events = build_events(
                pairs, ready, warmup=WARMUP, packet_flits=PACKET_FLITS
            )
            # Sanity: every measurement event stays in-tile.
            for ev in events:
                assert tile_of(ev["source"]) == tile_of(ev["destinations"][0])
            header = {
                "schema": TRACE_SCHEMA,
                "kind": "header",
                "benchmark_id": "INTRA-TILE-UR",
                "traffic": "intra_tile_ur",
                "nodes": NODES,
                "seed": SEED,
                "packet_flits": PACKET_FLITS,
                "warmup_original_events": WARMUP,
                "measurement_original_events": MEASUREMENT,
                "paired_trace": True,
                "injection_model": "v3_exp_header_asap_body",
                "tmax_definition": "last destination tail minus source header injection",
                "dest_constraint": "same_8x8_tile",
                "case_tick_ns": 1.0,
            }
            header.update(trace_load_fields(float(load)))
            dump_jsonl({"header": header, "events": events}, jsonl)
            print("TRACE", jsonl.name, "load_tag", load_tag(float(load)), flush=True)

        stem = case_name(load)
        target = CASE_DIR / (stem + ".case")
        if target.is_file():
            continue
        path = materialize_path(
            jsonl,
            CASE_DIR,
            top_lanes=0,
            hrep=False,
            routing="quadtree",
            design_id=DESIGN,
        )
        if path.resolve() != target.resolve():
            if target.exists():
                target.unlink()
            path.replace(target)
        print("CASE", target.name, flush=True)

    write_json(
        BUNDLE / "manifest.json",
        {
            "seed": SEED,
            "loads": list(loads),
            "designs": [DESIGN],
            "injection_model": "v3_exp_header_asap_body",
            "case_tick_ns": 1.0,
            "load_unit": "MFlit_per_port_s",
            "dest_constraint": "same_8x8_tile",
            "netlist": NETLIST,
            "note": "Diagnostic: 100% intra-tile UR on frozen PROP_temp256",
        },
    )


def upload(client, loads: tuple[int, ...]):
    sftp = client.open_sftp()
    remote_case_dir = "sim/cases_network"
    client, _ = remote_run_failover(
        client, "mkdir -p %s/%s" % (REMOTE_ROOT, remote_case_dir)
    )
    hashes = {}
    for load in loads:
        name = case_name(load)
        local = CASE_DIR / (name + ".case")
        if not local.is_file():
            raise SystemExit("missing " + str(local))
        dest = remote_case_dir + "/" + name + ".case"
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        hashes[name] = digest
    for local, dest in (
        (
            REPO / "sim/AsyncNoC/async_noc_scale_port_adapter.sv",
            "sim/tb/async_noc_scale_port_adapter.sv",
        ),
        (
            REPO / "sim/AsyncNoC/testbench/tb_noc_async_keycase.sv",
            "sim/tb/tb_noc_async_keycase.sv",
        ),
        (
            HERE / "run_gls_cmr_network.sh",
            "scripts/run_gls_cmr_network.sh",
        ),
    ):
        client, sftp, _ = atomic_put_retry(client, sftp, local, dest)
    sftp.close()
    return client, hashes


def submit(client, run_id: str, loads: tuple[int, ...]):
    jobs = []
    client, _ = remote_run_failover(
        client,
        "mkdir -p %s/logs/gls/%s %s/results/%s/csv"
        % (REMOTE_ROOT, run_id, REMOTE_ROOT, run_id),
    )
    for load in loads:
        name = case_name(load)
        wrapper = "logs/gls/%s/sdf_%s.sh" % (run_id, name)
        case_file = "%s/sim/cases_network/%s.case" % (REMOTE_ROOT, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NETWORK_RUN_ID=%s "
            "CMR_NETWORK_NETLIST_RUN_ID=%s CMR_NETWORK_CASE_NAME=%s "
            "CMR_NETWORK_CASE_FILE=%s CMR_NETWORK_GLS_MODE=sdf "
            "CMR_NETWORK_NODES=%s CMR_NETWORK_KIND=%s CMR_NETWORK_TOP=%s "
            "CMR_NETWORK_RX_CAPTURE_NS=0.1 "
            "CMR_NETWORK_STALL_TIMEOUT_NS=1200000 "
            "CMR_NETWORK_HARD_TIMEOUT_NS=6000000\n"
            "exec bash %s/scripts/run_gls_cmr_network.sh\n"
            % (
                REMOTE_ROOT,
                run_id,
                NETLIST,
                name,
                case_file,
                NODES,
                KIND,
                TOP,
                REMOTE_ROOT,
            )
        )
        from tempfile import NamedTemporaryFile

        with NamedTemporaryFile("w", encoding="utf-8", newline="\n", delete=False) as tmp:
            tmp.write(body)
            tmp_path = Path(tmp.name)
        sftp = client.open_sftp()
        client, sftp, _ = atomic_put_retry(client, sftp, tmp_path, wrapper)
        sftp.close()
        tmp_path.unlink(missing_ok=True)
        abs_wrapper = "%s/%s" % (REMOTE_ROOT, wrapper)
        client, _ = remote_run_failover(client, "chmod +x " + shlex.quote(abs_wrapper))
        log = "%s/logs/gls/%s/sdf_%s.job.log" % (REMOTE_ROOT, run_id, name)
        client, submitted = remote_run_failover(
            client,
            "bsub -n 8 -W 720 %s -o %s -e %s.err -J %s %s"
            % (
                HOSTS,
                shlex.quote(log),
                shlex.quote(log),
                shlex.quote("intra256_m%d" % load),
                shlex.quote(abs_wrapper),
            ),
        )
        jid = job_id(submitted)
        jobs.append({"design": DESIGN, "load": load, "case": name, "job": jid, "netlist": NETLIST})
        print("INTRA_TILE_UR_SUBMITTED", DESIGN, load, jid, flush=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state = {
        "run_id": run_id,
        "jobs": jobs,
        "loads": list(loads),
        "design": DESIGN,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    }
    (STATE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return client


def status(client, run_id: str, loads: tuple[int, ...], poll: bool = False) -> int:
    load_list = " ".join(str(m) for m in loads)
    script = r"""
ROOT=%s
RID=%s
done=0
total=0
for m in %s; do
  total=$((total+1))
  stem=INTRA-TILE-UR_n256_s202701_m${m}_PROP_temp256_top0
  res=$(grep -E 'TB_RESULT (PASS|FAIL)' $ROOT/logs/gls/$RID/sdf/$stem/run.log 2>/dev/null | tail -n 1)
  [ -z "$res" ] && res=$(grep -E 'TB_RESULT (PASS|FAIL)' $ROOT/logs/gls/$RID/sdf_${stem}.job.log 2>/dev/null | tail -n 1)
  [ -z "$res" ] && res=$(grep -E 'TB_RESULT (PASS|FAIL)' $ROOT/results/$RID/csv/sdf_${stem}.csv 2>/dev/null | tail -n 1)
  if echo "$res" | grep -q TB_RESULT; then
    done=$((done+1))
    echo OK m$m $res
  else
    echo PENDING m$m
  fi
done
echo SUMMARY done=$done total=$total
echo ACTIVE $(bjobs -u ghy19 -w 2>/dev/null | grep -c intra256 || echo 0)
""" % (
        REMOTE_ROOT,
        run_id,
        load_list,
    )
    rounds = 180 if poll else 1
    for i in range(rounds):
        client, out = remote_run_failover(client, script)
        lines = [ln for ln in out.splitlines() if not ln.startswith("ModuleCmd")]
        print("POLL", i, flush=True)
        for ln in lines:
            if ln.startswith(("OK ", "PENDING ", "SUMMARY", "ACTIVE")):
                print(ln, flush=True)
        summary = [ln for ln in lines if ln.startswith("SUMMARY")]
        if summary and ("done=%d" % len(loads)) in summary[-1]:
            print("INTRA_TILE_UR_COMPLETE", flush=True)
            return 0
        if not poll:
            return 1
        time.sleep(180)
    print("INTRA_TILE_UR_TIMEOUT", flush=True)
    return 2


def collect(client, run_id: str, loads: tuple[int, ...]) -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    fig_dir = (
        REPO
        / "DATE paper"
        / "experiments"
        / "figures"
        / "paper256"
        / ("prop256_intra_tile_ur_tick1_%s" % stamp)
    )
    raw_dir = (
        REPO
        / "DATE paper"
        / "experiments"
        / "raw"
        / "paper256"
        / ("prop256_intra_tile_ur_tick1_%s" % stamp)
        / "csv"
    )
    fig_dir.mkdir(parents=True, exist_ok=True)
    raw_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    sftp = client.open_sftp()
    remote_dir = "%s/results/%s/csv" % (REMOTE_ROOT, run_id)
    try:
        for load in loads:
            name = "sdf_%s.csv" % case_name(load)
            remote = "%s/%s" % (remote_dir, name)
            local = raw_dir / name
            try:
                sftp.get(remote, str(local))
            except IOError:
                print("MISSING_CSV", name, flush=True)
                continue
            with local.open(encoding="utf-8", newline="") as fh:
                row = next(csv.DictReader(fh))
            item = {
                "design": DESIGN,
                "traffic": "intra_tile_ur",
                "load": load,
                "pass_fail": row.get("pass_fail", ""),
                "delivered_throughput": float(row.get("delivered_throughput") or 0),
                "avg_packet_latency_ns": float(row.get("avg_packet_latency_ns") or 0),
                "p95_latency_ns": float(row.get("p95_latency_ns") or 0),
                "injected_flits": int(row.get("injected_flits") or 0),
                "delivered_flits": int(row.get("delivered_flits") or 0),
                "unexpected_flits": int(row.get("unexpected_flits") or 0),
                "case": name,
            }
            rows.append(item)
            print(
                "PULLED",
                load,
                item["pass_fail"],
                "thr=%.3f" % item["delivered_throughput"],
                "lat=%.3f" % item["avg_packet_latency_ns"],
                flush=True,
            )
    finally:
        sftp.close()

    summary = fig_dir / "summary.csv"
    with summary.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "design",
                "traffic",
                "load",
                "delivered_throughput",
                "avg_packet_latency_ns",
                "p95_latency_ns",
                "pass_fail",
                "injected_flits",
                "delivered_flits",
                "unexpected_flits",
                "case",
            ],
        )
        w.writeheader()
        for row in sorted(rows, key=lambda r: r["load"]):
            w.writerow(row)

    # Lightweight comparison note vs Global UR tick1 archive if present.
    global_sum = (
        REPO
        / "DATE paper"
        / "experiments"
        / "archives"
        / "paper256_final_tick1_20260916"
        / "fig256-1"
        / "summary.csv"
    )
    readme = [
        "# PROP_temp256 intra-tile UR (CASE_TICK=1)",
        "",
        "- Design: PROP_temp256 B8 (frozen `%s`)" % NETLIST,
        "- Constraint: destination always in same 8x8 tile as source (no upper Mesh)",
        "- Injection: v3_exp_header_asap_body",
        "- Run id: `%s`" % run_id,
        "- Loads: %s" % ",".join(str(m) for m in loads),
        "",
        "## Results",
        "",
        "| load | pass | thr | avg lat (ns) |",
        "|---:|:---:|---:|---:|",
    ]
    for row in sorted(rows, key=lambda r: r["load"]):
        readme.append(
            "| %d | %s | %.3f | %.3f |"
            % (
                row["load"],
                row["pass_fail"],
                row["delivered_throughput"],
                row["avg_packet_latency_ns"],
            )
        )
    if global_sum.is_file():
        readme.extend(["", "## Contrast vs Global UR tick1 (PROP only)", ""])
        with global_sum.open(encoding="utf-8", newline="") as fh:
            gmap = {
                int(r["load"]): r
                for r in csv.DictReader(fh)
                if r.get("design") == DESIGN
            }
        readme.append("| load | intra pass/lat | global pass/lat |")
        readme.append("|---:|---|---|")
        for load in loads:
            ir = next((r for r in rows if r["load"] == load), None)
            gr = gmap.get(load)
            i_s = (
                "%s / %.1f" % (ir["pass_fail"], ir["avg_packet_latency_ns"])
                if ir
                else "-"
            )
            g_s = (
                "%s / %.1f" % (gr["pass_fail"], float(gr["avg_packet_latency_ns"]))
                if gr
                else "-"
            )
            readme.append("| %d | %s | %s |" % (load, i_s, g_s))
    (fig_dir / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")
    print("COLLECT_OK", fig_dir, flush=True)
    return fig_dir


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "stage",
        choices=("materialize", "upload", "submit", "status", "collect", "all"),
    )
    parser.add_argument("--coarse-only", action="store_true")
    parser.add_argument("--fine-only", action="store_true")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--poll", action="store_true", help="status: poll until done")
    args = parser.parse_args()
    if args.coarse_only and args.fine_only:
        raise SystemExit("choose only one of --coarse-only / --fine-only")
    if args.fine_only:
        loads = FINE_LOADS
    elif args.coarse_only:
        loads = COARSE_LOADS
    else:
        loads = DEFAULT_LOADS

    if args.stage == "materialize":
        materialize(loads)
        return 0

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = args.run_id or ("%s_cmr_prop256_intra_tile_ur" % stamp)
    if not re.fullmatch(r"[A-Za-z0-9_]+", run_id):
        raise SystemExit("unsafe run id")

    if args.stage in ("all",):
        materialize(loads)

    client = connect_failover()
    try:
        if args.stage in ("upload", "all"):
            client, _ = upload(client, loads)
        if args.stage in ("submit", "all"):
            client = submit(client, run_id, loads)
        if args.stage == "status":
            return status(client, run_id, loads, poll=args.poll)
        if args.stage == "collect":
            collect(client, run_id, loads)
        if args.stage == "all":
            print("SUBMITTED_RUN_ID", run_id, flush=True)
            print("Poll with: python run_prop256_intra_tile_ur.py status --run-id %s --poll --coarse-only" % run_id, flush=True)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
