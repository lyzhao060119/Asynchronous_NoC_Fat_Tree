#!/usr/bin/env python3
"""Round-2 FlatMesh256 smoke: KEY-256 + low-load UR on frozen hier netlist."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
EXPERIMENT_SCRIPTS = REPO / "DATE paper" / "experiments" / "scripts"
sys.path.insert(0, str(EXPERIMENT_SCRIPTS))

from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from cmr_frozen_run_ids import refuse_overwrite  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry, job_id  # noqa: E402

SEED = 202701
NETLIST = os.environ.get(
    "CMR_FM256_NETLIST", "20260915_122347_cmr_mesh256_hier_dc"
)
TOP = "CMRMeshNoC"
NODES = 256
KIND = "fm"
BUNDLE = HERE / "generated_cases" / "20260915_fm256_smoke_202701"
CASE_DIR = BUNDLE / "cases"
TRACE_DIR = BUNDLE / "traces"
STATE_DIR = HERE / "results" / "r2_fm256_smoke"
REMOTE_ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

SMOKE_CASES = (
    "KEY-256_n256_s%d_corners_CMRMeshNoC_top0" % SEED,
    "TOPO-UR_n256_s%d_m5_CMRMeshNoC_top0" % SEED,
)


def checked_run_id(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise SystemExit("unsafe run id")
    refuse_overwrite(value, action="fm256_smoke_gls")
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
        "seed_set_id": "paper256_fm_smoke",
        "packet_flits": PACKET_FLITS,
        "warmup_original_events": 0,
        "measurement_original_events": len(events),
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
        "injection_model": "v3_exp_header_asap_body",
    }
    header.update(trace_load_fields(0.0))
    key_jsonl = TRACE_DIR / ("KEY-256_n256_s%d_corners.jsonl" % SEED)
    dump_jsonl({"header": header, "events": events}, key_jsonl)

    ur = generate_trace("TOPO-UR", seed=SEED, nodes=NODES, smoke=True, load_point=5.0)
    ur["header"]["injection_model"] = "v3_exp_header_asap_body"
    ur_jsonl = TRACE_DIR / ("TOPO-UR_n256_s%d_m5.jsonl" % SEED)
    dump_jsonl(ur, ur_jsonl)

    for jsonl, stem in ((key_jsonl, SMOKE_CASES[0]), (ur_jsonl, SMOKE_CASES[1])):
        path = materialize_path(
            jsonl,
            CASE_DIR,
            top_lanes=0,
            hrep=False,
            routing="mesh",
            design_id="FM256",
        )
        target = CASE_DIR / (stem + ".case")
        if path.resolve() != target.resolve():
            if target.exists():
                target.unlink()
            path.replace(target)
        print("CASE", target.name, flush=True)

    write_json(
        BUNDLE / "manifest.json",
        {"cases": list(SMOKE_CASES), "netlist": NETLIST, "top": TOP},
    )
    print("MATERIALIZE_OK", CASE_DIR, flush=True)


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def upload_and_submit(client, run_id: str):
    hashes = {}
    sftp = client.open_sftp()
    remote_case_dir = "sim/cases_network"
    client, _ = remote_run_failover(
        client,
        "mkdir -p %s/%s %s/logs/gls/%s %s/results/%s/csv %s/sim/tb %s/scripts"
        % (
            REMOTE_ROOT,
            remote_case_dir,
            REMOTE_ROOT,
            run_id,
            REMOTE_ROOT,
            run_id,
            REMOTE_ROOT,
            REMOTE_ROOT,
        ),
    )
    for stem in SMOKE_CASES:
        local = CASE_DIR / (stem + ".case")
        if not local.is_file():
            raise SystemExit("missing case " + str(local))
        hashes[stem] = sha_file(local)
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
        (HERE / "run_gls_cmr_network.sh", "scripts/run_gls_cmr_network.sh"),
    ):
        client, sftp, _ = atomic_put_retry(client, sftp, local, dest)
    jobs = []
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
        client, sftp, _ = atomic_put_retry(client, sftp, tmp_path, wrapper)
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
                shlex.quote("FM256smoke_" + name.split("_")[0]),
                shlex.quote(abs_wrapper),
            ),
        )
        jid = job_id(submitted)
        jobs.append({"case": name, "job": jid})
        print("SMOKE_SUBMITTED", name, jid, flush=True)
    sftp.close()
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / "state.json").write_text(
        json.dumps(
            {
                "run_id": run_id,
                "netlist": NETLIST,
                "jobs": jobs,
                "case_sha256": hashes,
                "submitted_at": datetime.now(timezone.utc).isoformat(),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return client


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("materialize", "submit", "all"), nargs="?", default="all")
    parser.add_argument("--run-id", default="")
    args = parser.parse_args()
    from _tmp_paper64_common import stamp  # noqa: E402

    run_id = checked_run_id(args.run_id or ("%s_cmr_fm256_smoke" % stamp()))
    if args.stage in ("materialize", "all"):
        materialize()
    if args.stage in ("submit", "all"):
        client = connect_failover()
        try:
            upload_and_submit(client, run_id)
        finally:
            client.close()
        print("FM256_SMOKE_RUN", run_id, "netlist", NETLIST, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
