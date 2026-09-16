#!/usr/bin/env python3
"""256-E1 Global UR three-DUT runner (PROP_temp256 / PFAT_temp256 / FM256).

Materializes matched ASAP TOPO-UR cases on a coarse+fine load grid, then
SKIP_DC GLS once each design has a frozen netlist. Without baseline netlists
the submit stage refuses PFAT/FM and only allows PROP if --prop-only.

Stages: materialize | upload | submit | status | plot | all
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

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))

from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from cmr_frozen_run_ids import (  # noqa: E402
    FROZEN_FM256_NETLIST_RUN_ID,
    FROZEN_PFAT_TEMP256_NETLIST_RUN_ID,
    FROZEN_PROP_TEMP256_NETLIST_RUN_ID,
    refuse_overwrite,
)
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry, job_id  # noqa: E402

SEED = 202701
NODES = 256
# Rebuilt 2026-09-15 after CASE_TICK_NS=1 fix; do not reuse tick=20-era cases.
BUNDLE = HERE / "generated_cases" / "20260915_paper256_ur_tick1_m5_800_202701"
CASE_DIR = BUNDLE / "cases"
TRACE_DIR = BUNDLE / "traces"
STATE_DIR = HERE / "results" / "e1_ur_three_dut256"
REMOTE_ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

# Coarse grid (~10) then fine fills near observed knees (tick=1 restart).
# PROP saturates ~m40–80; PFAT holds longer; FM stays healthy high.
COARSE_LOADS = (5, 20, 40, 80, 120, 160, 200, 280, 400, 600)
FINE_LOADS = (50, 60, 70, 90, 100, 110, 140, 180, 240, 320)
DEFAULT_LOADS = tuple(sorted(set(COARSE_LOADS + FINE_LOADS)))

DESIGNS = {
    "PROP_temp256": {
        "top": "PROP_temp256",
        "kind": "prop_temp",
        "netlist_env": "CMR_PROP_TEMP256_NETLIST",
        "default_netlist": FROZEN_PROP_TEMP256_NETLIST_RUN_ID,
    },
    "PFAT_temp256": {
        "top": "PFAT_temp256",
        "kind": "pfat_temp",
        "netlist_env": "CMR_PFAT_TEMP256_NETLIST",
        "default_netlist": FROZEN_PFAT_TEMP256_NETLIST_RUN_ID,
    },
    "FM256": {
        "top": "CMRMeshNoC",
        "kind": "fm",
        "netlist_env": "CMR_FM256_NETLIST",
        "default_netlist": FROZEN_FM256_NETLIST_RUN_ID,
    },
}


def case_name(design: str, load: int) -> str:
    return "TOPO-UR_n256_s%d_m%d_%s_top0" % (SEED, load, design)


def netlist_for(design: str) -> str:
    meta = DESIGNS[design]
    return os.environ.get(meta["netlist_env"], meta["default_netlist"]).strip()


def materialize(loads: tuple[int, ...]) -> None:
    from date_v3.canonical_trace import dump_jsonl, generate_trace  # noqa: E402
    from date_v3.hashutil import write_json  # noqa: E402
    from date_v3.materialize_case import materialize_path  # noqa: E402

    TRACE_DIR.mkdir(parents=True, exist_ok=True)
    CASE_DIR.mkdir(parents=True, exist_ok=True)
    for load in loads:
        jsonl = TRACE_DIR / ("TOPO-UR_n256_s%d_m%d.jsonl" % (SEED, load))
        if not jsonl.is_file():
            trace = generate_trace(
                "TOPO-UR", seed=SEED, nodes=NODES, smoke=False, load_point=float(load)
            )
            trace["header"]["injection_model"] = "v3_exp_header_asap_body"
            dump_jsonl(trace, jsonl)
            print("TRACE", jsonl.name, flush=True)
        for design in DESIGNS:
            stem = case_name(design, load)
            target = CASE_DIR / (stem + ".case")
            if target.is_file():
                continue
            path = materialize_path(
                jsonl,
                CASE_DIR,
                top_lanes=0,
                hrep=False,
                routing="mesh" if design == "FM256" else "quadtree",
                design_id=design,
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
            "designs": list(DESIGNS),
            "injection_model": "v3_exp_header_asap_body",
            "case_tick_ns": 1.0,
            "load_unit": "MFlit_per_port_s",
            "note": "Rebuilt after fixing run_gls_cmr_network.sh CASE_TICK_NS 20->1",
        },
    )


def upload(client, designs: list[str], loads: tuple[int, ...]):
    sftp = client.open_sftp()
    remote_case_dir = "sim/cases_network"
    client, _ = remote_run_failover(
        client, "mkdir -p %s/%s" % (REMOTE_ROOT, remote_case_dir)
    )
    hashes = {}
    for design in designs:
        for load in loads:
            name = case_name(design, load)
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


def submit(client, run_id: str, designs: list[str], loads: tuple[int, ...]):
    jobs = []
    client, _ = remote_run_failover(
        client,
        "mkdir -p %s/logs/gls/%s %s/results/%s/csv"
        % (REMOTE_ROOT, run_id, REMOTE_ROOT, run_id),
    )
    for design in designs:
        nid = netlist_for(design)
        if not nid:
            raise SystemExit(
                "missing frozen netlist for %s (set %s=... after Round-2 DC PASS)"
                % (design, DESIGNS[design]["netlist_env"])
            )
        # Read-only SKIP_DC reuse; refuse_overwrite is for write protection only.
        meta = DESIGNS[design]
        for load in loads:
            name = case_name(design, load)
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
                    nid,
                    name,
                    case_file,
                    NODES,
                    meta["kind"],
                    meta["top"],
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
                    shlex.quote("e1ur256_m%d_%s" % (load, design[:4])),
                    shlex.quote(abs_wrapper),
                ),
            )
            jid = job_id(submitted)
            jobs.append({"design": design, "load": load, "case": name, "job": jid, "netlist": nid})
            print("E1_UR256_SUBMITTED", design, load, jid, flush=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    state = {
        "run_id": run_id,
        "jobs": jobs,
        "loads": list(loads),
        "designs": designs,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    }
    (STATE_DIR / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    return client


def plot_placeholder() -> None:
    """Write a README pointing finalize script; figures need GLS CSV pull."""
    out = REPO / "DATE paper" / "experiments" / "figures" / "paper256"
    out.mkdir(parents=True, exist_ok=True)
    note = out / "e1_ur_three_dut256_PENDING.md"
    note.write_text(
        "# 256-E1 figures pending\n\n"
        "Run `finalize_e1_ur_three_dut256.py` after three-DUT GLS PASS.\n"
        "Target: throughput + pre-saturation latency (Fig.256-1) and 64↔256 summary.\n",
        encoding="utf-8",
    )
    print("PLOT_PLACEHOLDER", note, flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "stage",
        choices=("materialize", "upload", "submit", "status", "plot", "all"),
    )
    parser.add_argument("--prop-only", action="store_true")
    parser.add_argument("--coarse-only", action="store_true")
    parser.add_argument("--fine-only", action="store_true")
    parser.add_argument(
        "--designs",
        default="",
        help="Comma-separated design ids (default: all three)",
    )
    parser.add_argument("--run-id", default="")
    args = parser.parse_args()
    if args.coarse_only and args.fine_only:
        raise SystemExit("choose only one of --coarse-only / --fine-only")
    if args.fine_only:
        loads = FINE_LOADS
    elif args.coarse_only:
        loads = COARSE_LOADS
    else:
        loads = DEFAULT_LOADS
    if args.prop_only:
        designs = ["PROP_temp256"]
    elif args.designs.strip():
        designs = [d.strip() for d in args.designs.split(",") if d.strip()]
        bad = [d for d in designs if d not in DESIGNS]
        if bad:
            raise SystemExit("unknown designs: %s" % ",".join(bad))
    else:
        designs = list(DESIGNS)
    if args.stage == "plot":
        plot_placeholder()
        return 0
    if args.stage in ("materialize", "all"):
        materialize(loads)
        if args.stage == "materialize":
            return 0
    if args.stage == "all" and not args.prop_only:
        missing = [d for d in designs if d != "PROP_temp256" and not netlist_for(d)]
        if missing:
            print(
                "E1_UR256_BLOCKED_PENDING_BASELINE_DC",
                ",".join(missing),
                flush=True,
            )
            plot_placeholder()
            return 0
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = args.run_id or ("%s_cmr_e1_ur_three_dut256" % stamp)
    if not re.fullmatch(r"[A-Za-z0-9_]+", run_id):
        raise SystemExit("unsafe run id")
    client = connect_failover()
    try:
        if args.stage in ("upload", "all"):
            client, _ = upload(client, designs, loads)
        if args.stage in ("submit", "all"):
            client = submit(client, run_id, designs, loads)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
