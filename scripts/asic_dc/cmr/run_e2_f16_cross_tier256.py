#!/usr/bin/env python3
"""256-E2 PROP_temp256 F16 cross-tier Native vs Repeated (3 paper points).

Destination set forced 4+4+4+4 across tiles. Stages:
  materialize | upload | submit | status | all
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import sys
from datetime import datetime, timezone
from pathlib import Path
from random import Random

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))

from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from cmr_frozen_run_ids import FROZEN_PROP_TEMP256_NETLIST_RUN_ID, refuse_overwrite  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry, job_id  # noqa: E402

SEED = 202701
NODES = 256
FANOUT = 16
NETLIST = FROZEN_PROP_TEMP256_NETLIST_RUN_ID
TOP = "PROP_temp256"
# Rebuilt 2026-09-15 after CASE_TICK_NS=1 fix; do not reuse tick=20-era cases.
BUNDLE = HERE / "generated_cases" / "20260915_prop_temp256_f16_cross_tier_tick1"
CASE_DIR = BUNDLE / "cases"
TRACE_DIR = BUNDLE / "traces"
STATE_DIR = HERE / "results" / "e2_f16_cross_tier256"
REMOTE_ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

# Calibrated from tick=1 E1 PROP near-lossless knee (~m40 PASS, m80 FAIL).
LOAD_POINTS = {
    "low": 5.0,
    "medium": 20.0,
    "high": 40.0,
}


def tile_of(pe: int) -> int:
    x = pe % 16
    y = pe // 16
    return (x // 8) + 2 * (y // 8)


def choose_cross_tier_dests(rng: Random, source: int) -> list[int]:
    """Exactly 4 destinations in each of the 4 tiles (16 total), exclude source."""
    buckets: dict[int, list[int]] = {0: [], 1: [], 2: [], 3: []}
    for pe in range(NODES):
        if pe == source:
            continue
        buckets[tile_of(pe)].append(pe)
    dests: list[int] = []
    for t in range(4):
        pool = buckets[t][:]
        rng.shuffle(pool)
        if len(pool) < 4:
            raise RuntimeError("tile %d too small" % t)
        dests.extend(pool[:4])
    rng.shuffle(dests)
    assert len(dests) == FANOUT
    assert len(set(dests)) == FANOUT
    counts = [0, 0, 0, 0]
    for d in dests:
        counts[tile_of(d)] += 1
    assert counts == [4, 4, 4, 4]
    return dests


def materialize() -> None:
    from date_v3.canonical_trace import (  # noqa: E402
        PACKET_FLITS,
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

    TRACE_DIR.mkdir(parents=True, exist_ok=True)
    CASE_DIR.mkdir(parents=True, exist_ok=True)
    width = width_of(NODES)
    stems = []
    for label, load in LOAD_POINTS.items():
        rng = Random(seed_mix(SEED, NODES, FANOUT, int(load)))
        # Build a modest set of original multicast transactions.
        n_tx = 32 if label == "low" else 64
        pairs = []
        for _ in range(n_tx):
            source = rng.randrange(NODES)
            dests = choose_cross_tier_dests(rng, source)
            pairs.append(
                {
                    "source": source,
                    "destinations": dests,
                    "rect": bounding_rect(dests, width),
                    "multicast": True,
                }
            )
        sched_rng = Random(seed_mix(SEED, NODES, 99, int(load)))
        ready = schedule_pairs(
            pairs, nodes=NODES, packet_flits=PACKET_FLITS, load_point=load, rng=sched_rng
        )
        events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
        header = {
            "schema": TRACE_SCHEMA,
            "kind": "header",
            "benchmark_id": "MC-F16-CROSS",
            "traffic": "cross_tier_f16",
            "nodes": NODES,
            "seed": SEED,
            "fanout_F": FANOUT,
            "dest_distribution": "4+4+4+4",
            "packet_flits": PACKET_FLITS,
            "warmup_original_events": 0,
            "measurement_original_events": n_tx,
            "paired_trace": True,
            "injection_model": "v3_exp_header_asap_body",
            "tmax_definition": "last destination tail minus source header injection",
            "paper_point": label,
        }
        header.update(trace_load_fields(load))
        native_jsonl = TRACE_DIR / ("MC-F16_n256_s%d_%s_native.jsonl" % (SEED, label))
        dump_jsonl({"header": header, "events": events}, native_jsonl)

        # Repeated unicast: expand each original tx into 16 unicasts same ready time.
        rep_pairs = []
        rep_ready = []
        for pair, t0 in zip(pairs, ready):
            for dest in pair["destinations"]:
                rep_pairs.append(
                    {
                        "source": pair["source"],
                        "destinations": [dest],
                        "rect": bounding_rect([dest], width),
                        "multicast": False,
                    }
                )
                rep_ready.append(t0)
        rep_events = build_events(rep_pairs, rep_ready, warmup=0, packet_flits=PACKET_FLITS)
        rep_header = dict(header)
        rep_header["benchmark_id"] = "MC-F16-CROSS-REP"
        rep_header["traffic"] = "cross_tier_f16_repeated_unicast"
        rep_header["measurement_original_events"] = len(rep_pairs)
        rep_header["original_multicast_transactions"] = n_tx
        rep_jsonl = TRACE_DIR / ("MC-F16_n256_s%d_%s_repeated.jsonl" % (SEED, label))
        dump_jsonl({"header": rep_header, "events": rep_events}, rep_jsonl)

        for mode, jsonl in (("native", native_jsonl), ("repeated", rep_jsonl)):
            stem = "MC-F16_n256_s%d_%s_%s_PROP_temp256_top0" % (SEED, label, mode)
            path = materialize_path(
                jsonl,
                CASE_DIR,
                top_lanes=0,
                hrep=False,
                routing="quadtree",
                design_id="PROP_temp256",
            )
            target = CASE_DIR / (stem + ".case")
            if path.resolve() != target.resolve():
                if target.exists():
                    target.unlink()
                path.replace(target)
            stems.append(stem)
            print("CASE", target.name, flush=True)

    write_json(
        BUNDLE / "manifest.json",
        {
            "seed": SEED,
            "fanout": FANOUT,
            "dest_distribution": "4+4+4+4",
            "points": LOAD_POINTS,
            "cases": stems,
            "netlist": NETLIST,
        },
    )


def upload_and_submit(client, run_id: str):
    # SKIP_DC GLS reuses PROP_temp256 frozen netlist (read-only).
    manifest = json.loads((BUNDLE / "manifest.json").read_text(encoding="utf-8"))
    stems = manifest["cases"]
    sftp = client.open_sftp()
    remote_case_dir = "sim/cases_network"
    client, _ = remote_run_failover(
        client,
        "mkdir -p %s/%s %s/logs/gls/%s %s/results/%s/csv %s/sim/tb %s/scripts"
        % (REMOTE_ROOT, remote_case_dir, REMOTE_ROOT, run_id, REMOTE_ROOT, run_id, REMOTE_ROOT, REMOTE_ROOT),
    )
    for stem in stems:
        local = CASE_DIR / (stem + ".case")
        dest = remote_case_dir + "/" + stem + ".case"
        client, sftp, _ = atomic_put_retry(client, sftp, local, dest)
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
    jobs = []
    for stem in stems:
        wrapper = "logs/gls/%s/sdf_%s.sh" % (run_id, stem)
        case_file = "%s/sim/cases_network/%s.case" % (REMOTE_ROOT, stem)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NETWORK_RUN_ID=%s "
            "CMR_NETWORK_NETLIST_RUN_ID=%s CMR_NETWORK_CASE_NAME=%s "
            "CMR_NETWORK_CASE_FILE=%s CMR_NETWORK_GLS_MODE=sdf "
            "CMR_NETWORK_NODES=256 CMR_NETWORK_KIND=prop_temp CMR_NETWORK_TOP=%s "
            "CMR_NETWORK_RX_CAPTURE_NS=0.1 "
            "CMR_NETWORK_STALL_TIMEOUT_NS=1200000 "
            "CMR_NETWORK_HARD_TIMEOUT_NS=6000000\n"
            "exec bash %s/scripts/run_gls_cmr_network.sh\n"
            % (REMOTE_ROOT, run_id, NETLIST, stem, case_file, TOP, REMOTE_ROOT)
        )
        from tempfile import NamedTemporaryFile

        with NamedTemporaryFile("w", encoding="utf-8", newline="\n", delete=False) as tmp:
            tmp.write(body)
            tmp_path = Path(tmp.name)
        client, sftp, _ = atomic_put_retry(client, sftp, tmp_path, wrapper)
        tmp_path.unlink(missing_ok=True)
        abs_wrapper = "%s/%s" % (REMOTE_ROOT, wrapper)
        client, _ = remote_run_failover(client, "chmod +x " + shlex.quote(abs_wrapper))
        log = "%s/logs/gls/%s/sdf_%s.job.log" % (REMOTE_ROOT, run_id, stem)
        client, submitted = remote_run_failover(
            client,
            "bsub -n 8 %s -o %s -e %s.err -J %s %s"
            % (
                HOSTS,
                shlex.quote(log),
                shlex.quote(log),
                shlex.quote("e2f16_" + stem.split("_")[3] + "_" + stem.split("_")[4]),
                shlex.quote(abs_wrapper),
            ),
        )
        jid = job_id(submitted)
        jobs.append({"case": stem, "job": jid})
        print("E2_F16_SUBMITTED", stem, jid, flush=True)
    sftp.close()
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / "state.json").write_text(
        json.dumps(
            {
                "run_id": run_id,
                "netlist": NETLIST,
                "jobs": jobs,
                "submitted_at": datetime.now(timezone.utc).isoformat(),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return client


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("materialize", "upload", "submit", "all"))
    parser.add_argument("--run-id", default="")
    args = parser.parse_args()
    if args.stage in ("materialize", "all"):
        materialize()
        if args.stage == "materialize":
            return 0
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = args.run_id or ("%s_cmr_e2_f16_cross_tier256" % stamp)
    if not re.fullmatch(r"[A-Za-z0-9_]+", run_id):
        raise SystemExit("unsafe run id")
    client = connect_failover()
    try:
        client = upload_and_submit(client, run_id)
    finally:
        client.close()
    print("E2_F16_SUBMIT_DONE", run_id, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
