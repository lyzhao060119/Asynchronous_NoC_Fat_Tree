#!/usr/bin/env python3
"""Round-1 PROP_temp256 smoke: KEY-256 + low-load UR on frozen hier netlist.

Stages:
  materialize   emit local smoke cases
  upload        upload cases + TB adapters
  submit        SKIP_DC MAXIMUM-SDF GLS
  status        poll remote jobs
  all           materialize -> upload -> submit
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
EXPERIMENT_SCRIPTS = REPO / "DATE paper" / "experiments" / "scripts"
sys.path.insert(0, str(EXPERIMENT_SCRIPTS))

from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from cmr_frozen_run_ids import FROZEN_PROP_TEMP256_NETLIST_RUN_ID, refuse_overwrite  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry, job_id  # noqa: E402

SEED = 202701
NETLIST = FROZEN_PROP_TEMP256_NETLIST_RUN_ID
TOP = "PROP_temp256"
NODES = 256
KIND = "prop_temp"
BUNDLE = HERE / "generated_cases" / "20260915_prop_temp256_smoke_202701"
CASE_DIR = BUNDLE / "cases"
TRACE_DIR = BUNDLE / "traces"
STATE_DIR = HERE / "results" / "r1_prop_temp256_smoke"
REMOTE_ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

SMOKE_CASES = (
    "KEY-256_n256_s%d_corners_PROP_temp256_top0" % SEED,
    "TOPO-UR_n256_s%d_m5_PROP_temp256_top0" % SEED,
)


def checked_run_id(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise SystemExit("unsafe run id")
    refuse_overwrite(value, action="prop_temp256_smoke_gls")
    return value


def materialize() -> None:
    from date_v3.canonical_trace import (  # noqa: E402
        PACKET_FLITS,
        TRACE_SCHEMA,
        ZERO_LOAD_GAP,
        bounding_rect,
        build_events,
        choose_other,
        dump_jsonl,
        generate_trace,
        seed_mix,
    )
    from date_v3.hashutil import write_json  # noqa: E402
    from date_v3.materialize_case import materialize_path  # noqa: E402
    from date_v3.offered_load import trace_load_fields  # noqa: E402
    from random import Random

    TRACE_DIR.mkdir(parents=True, exist_ok=True)
    CASE_DIR.mkdir(parents=True, exist_ok=True)

    # Directed corners + a few random unicasts (smoke).
    corners = [0, 15, 240, 255]
    pairs = []
    seen = set()
    for src in corners:
        for dest in corners:
            if src == dest:
                continue
            key = (src, dest)
            if key in seen:
                continue
            seen.add(key)
            pairs.append(
                {
                    "source": src,
                    "destinations": [dest],
                    "rect": bounding_rect([dest], 16),
                    "multicast": False,
                }
            )
    rng = Random(seed_mix(SEED, NODES, 0, 9))
    added = 0
    while added < 4:
        src = rng.randrange(NODES)
        dest = choose_other(rng, src, NODES)
        key = (src, dest)
        if key in seen:
            continue
        seen.add(key)
        pairs.append(
            {
                "source": src,
                "destinations": [dest],
                "rect": bounding_rect([dest], 16),
                "multicast": False,
            }
        )
        added += 1
    ready = [idx * (PACKET_FLITS + ZERO_LOAD_GAP) for idx in range(len(pairs))]
    events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": "KEY-256",
        "traffic": "directed_keycase",
        "nodes": NODES,
        "seed": SEED,
        "seed_set_id": "paper256_smoke",
        "packet_flits": PACKET_FLITS,
        "warmup_original_events": 0,
        "measurement_original_events": len(events),
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
        "injection_model": "v3_exp_header_asap_body",
    }
    header.update(trace_load_fields(0.0))
    key_trace = {"header": header, "events": events}
    key_jsonl = TRACE_DIR / ("KEY-256_n256_s%d_corners.jsonl" % SEED)
    dump_jsonl(key_trace, key_jsonl)

    ur = generate_trace(
        "TOPO-UR",
        seed=SEED,
        nodes=NODES,
        smoke=True,
        load_point=5.0,
    )
    ur["header"]["injection_model"] = "v3_exp_header_asap_body"
    ur_jsonl = TRACE_DIR / ("TOPO-UR_n256_s%d_m5.jsonl" % SEED)
    dump_jsonl(ur, ur_jsonl)

    for jsonl, stem in (
        (key_jsonl, SMOKE_CASES[0]),
        (ur_jsonl, SMOKE_CASES[1]),
    ):
        path = materialize_path(
            jsonl,
            CASE_DIR,
            top_lanes=0,
            hrep=False,
            routing="quadtree",
            design_id="PROP_temp256",
        )
        # materialize_path chooses its own stem; rename if needed.
        target = CASE_DIR / (stem + ".case")
        if path.resolve() != target.resolve():
            if target.exists():
                target.unlink()
            path.replace(target)
        print("CASE", target.name, flush=True)

    write_json(
        BUNDLE / "INJECTION_MODEL.json",
        {
            "injection_model": "v3_exp_header_asap_body",
            "intra_packet_offer": "same_cycle_asap",
            "seed": SEED,
            "nodes": NODES,
            "design": "PROP_temp256",
            "netlist": NETLIST,
        },
    )
    print("MATERIALIZE_OK", CASE_DIR, flush=True)


def upload(client):
    sftp = client.open_sftp()
    # atomic_put_retry/sftp_put_file prepend REMOTE ROOT — pass relative paths only.
    remote_case_dir = "sim/cases_network"
    client, out = remote_run_failover(
        client,
        "mkdir -p %s/%s %s/sim/tb %s/scripts %s/logs/gls %s/results && ls -ld %s/%s"
        % (REMOTE_ROOT, remote_case_dir, REMOTE_ROOT, REMOTE_ROOT, REMOTE_ROOT, REMOTE_ROOT, REMOTE_ROOT, remote_case_dir),
    )
    print("REMOTE_MKDIR", out.replace("\n", " | "), flush=True)
    hashes = {}
    for name in SMOKE_CASES:
        local = CASE_DIR / (name + ".case")
        if not local.is_file():
            raise SystemExit("missing case " + str(local))
        dest = remote_case_dir + "/" + name + ".case"
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        hashes[name] = digest
        print("UPLOAD_CASE", name, digest[:12], flush=True)
    # Upload TB + GLS shell used by network runner.
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
        client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
        print("UPLOAD_FILE", dest, digest[:12], flush=True)
    sftp.close()
    return client, hashes


def submit(client, run_id: str, hashes: dict[str, str]):
    # SKIP_DC GLS only reuses the frozen netlist; do not call refuse_overwrite
    # (that guard blocks write/overwrite of the DC stamp, not read-only GLS).
    jobs = []
    client, _ = remote_run_failover(
        client,
        "mkdir -p %s/logs/gls/%s %s/results/%s/csv"
        % (REMOTE_ROOT, run_id, REMOTE_ROOT, run_id),
    )
    for name in SMOKE_CASES:
        wrapper = "logs/gls/%s/sdf_%s.sh" % (run_id, name)
        case_file = "%s/sim/cases_network/%s.case" % (REMOTE_ROOT, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NETWORK_RUN_ID=%s "
            "CMR_NETWORK_NETLIST_RUN_ID=%s CMR_NETWORK_CASE_NAME=%s "
            "CMR_NETWORK_CASE_FILE=%s CMR_NETWORK_GLS_MODE=sdf "
            "CMR_NETWORK_NODES=%s CMR_NETWORK_KIND=%s CMR_NETWORK_TOP=%s "
            "CMR_NETWORK_RX_CAPTURE_NS=0.1 "
            "CMR_NETWORK_STALL_TIMEOUT_NS=800000 "
            "CMR_NETWORK_HARD_TIMEOUT_NS=4000000\n"
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
            "bsub -n 8 %s -o %s -e %s.err -J %s %s"
            % (
                HOSTS,
                shlex.quote(log),
                shlex.quote(log),
                shlex.quote("p256smoke_%s" % name.split("_")[0]),
                shlex.quote(abs_wrapper),
            ),
        )
        jid = job_id(submitted)
        jobs.append({"case": name, "job": jid})
        print("SMOKE_SUBMITTED", name, jid, flush=True)

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state = {
        "run_id": run_id,
        "netlist": NETLIST,
        "stage": "gls_submitted",
        "cases": SMOKE_CASES,
        "jobs": jobs,
        "case_sha256": hashes,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    }
    (STATE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return client


def status(client) -> int:
    state_path = STATE_DIR / "state.json"
    if not state_path.is_file():
        print("NO_STATE", flush=True)
        return 1
    state = json.loads(state_path.read_text(encoding="utf-8"))
    run_id = state["run_id"]
    ok = 0
    for job in state.get("jobs", []):
        name = job["case"]
        log = "%s/logs/gls/%s/sdf/%s/run.log" % (REMOTE_ROOT, run_id, name)
        client, out = remote_run_failover(
            client,
            "grep -E 'TB_RESULT|CMR_NETWORK_GLS_(PASS|FAIL)|Total errors' %s 2>/dev/null | tail -n 8; "
            "bjobs -u ghy19 2>/dev/null | grep -F %s | head -n 2 || true"
            % (shlex.quote(log), shlex.quote(str(job.get("job", "")))),
        )
        print("STATUS", name, out.replace("\n", " | "), flush=True)
        if "TB_RESULT PASS" in out or "CMR_NETWORK_GLS_PASS" in out:
            ok += 1
    print("SMOKE_PASS_COUNT", ok, "/", len(state.get("jobs", [])), flush=True)
    return 0 if ok == len(state.get("jobs", [])) else 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "stage",
        choices=("materialize", "upload", "submit", "status", "all"),
    )
    parser.add_argument("--run-id", default="")
    args = parser.parse_args()
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = checked_run_id(
        args.run_id
        or os.environ.get("CMR_NETWORK_RUN_ID")
        or ("%s_cmr_prop_temp256_smoke" % stamp)
    )

    if args.stage in ("materialize", "all"):
        materialize()
    if args.stage == "materialize":
        return 0

    client = connect_failover()
    try:
        hashes = {}
        if args.stage in ("upload", "all"):
            client, hashes = upload(client)
        if args.stage in ("submit", "all"):
            if not hashes:
                # reload from previous upload if present
                state_path = STATE_DIR / "state.json"
                if state_path.is_file():
                    hashes = json.loads(state_path.read_text(encoding="utf-8")).get(
                        "case_sha256", {}
                    )
            if args.stage == "submit" and not hashes:
                client, hashes = upload(client)
            client = submit(client, run_id, hashes)
        if args.stage == "status":
            return status(client)
    finally:
        client.close()
    print("R1_SMOKE_SUBMIT_DONE", run_id, "netlist", NETLIST, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
