#!/usr/bin/env python3
"""Ingest V3 TB CSVs and probe/submit isolated DES-cal GLS.

64-core: MAXIMUM-SDF GLS (thin / 1-2-2-2 / 1-2-4-8 / mesh).  Missing netlists
use parallel unique-router DC + link-only stitch, or one full-network DC per
design.  256-core: cluster VCS RTL keycase (behavioral delay, not DC).

Does not overwrite frozen hop / Sync64 / Ackin-250 directories.
Does not use paper traffic seeds.  Probe-only is the default.
Submit never launches LSF unless --launch is also set.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
EXPERIMENTS = SCRIPTS.parent
REPO = EXPERIMENTS.parent.parent
CMR = REPO / "scripts" / "asic_dc" / "cmr"
MODEL = EXPERIMENTS / "model"
for path in (SCRIPTS, MODEL, CMR):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.event_record import assemble_event_records, dump_event_jsonl, validate_event_record  # noqa: E402
from des.lsf import JOB_PREFIX, run_id as descal_run_id  # noqa: E402

from cmr_frozen_run_ids import (  # noqa: E402
    FROZEN_NOC64_ACKIN250_RUN_ID,
    FROZEN_WRITE_RUN_IDS,
    NOT_FAT_VS_THIN_DELAY,
)

PROP64_DEL050_CANDIDATE = "20260830_132453_cmr_noc64_1222_ackin50_p50_1222"
MESH64_CANDIDATE = "20260831_115856_cmr_mesh64_p50"
PACK_DEFAULT = EXPERIMENTS / "intermediate" / "des_calibration"

DESIGN_RUNNERS = {
    "PROP64": {"runner": "noc64", "profile": "1222", "netlist": PROP64_DEL050_CANDIDATE},
    "FM64": {"runner": "mesh64", "profile": None, "netlist": MESH64_CANDIDATE},
    "PROP256": {"runner": "noc256", "kind": "prop", "netlist": None},
    "FM256": {"runner": "noc256", "kind": "fm", "netlist": None},
    "THIN64": {"runner": "noc64", "profile": "thin", "netlist": None},
    "PFAT64": {"runner": "noc64", "profile": "1248", "netlist": None},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ingest", action="store_true")
    parser.add_argument("--ingest-pack", action="store_true")
    parser.add_argument("--packets", type=Path)
    parser.add_argument("--latency", type=Path)
    parser.add_argument("--events", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--rtl-root", type=Path, help="pack rtl/ directory")
    parser.add_argument("--pack", type=Path, default=PACK_DEFAULT)
    parser.add_argument("--design")
    parser.add_argument("--tag", default="directed")
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--submit", action="store_true")
    parser.add_argument("--launch", action="store_true", help="actually invoke remote runners")
    parser.add_argument("--case", type=Path)
    parser.add_argument("--netlist-run-id")
    parser.add_argument("--allow-ackin250", action="store_true")
    parser.add_argument(
        "--dc-mode",
        choices=("hier", "full"),
        default="hier",
        help="missing 64-core netlists: unique-router stitch, or one full-network DC",
    )
    parser.add_argument("--submit-only", action="store_true", default=True)
    parser.add_argument("--wait", action="store_true", help="wait for LSF instead of submit-only")
    return parser.parse_args()


def ingest(args: argparse.Namespace) -> int:
    out = args.out
    if out is None and args.rtl_root and args.design:
        out = args.rtl_root / args.design / args.tag / "events.jsonl"
    if args.packets is None or out is None:
        print("FAIL --ingest needs --packets and --out (or --rtl-root --design)", flush=True)
        return 2
    records = assemble_event_records(
        packets_json=args.packets,
        latency_csv=args.latency,
        event_csv=args.events,
    )
    for rec in records:
        validate_event_record(rec, label=str(rec.get("original_event_id")))
    dump_event_jsonl(records, out)
    print("INGEST", out, "events", len(records), flush=True)
    return 0


def _find_case_csvs(case_stem: str) -> dict[str, Path]:
    results = CMR / "results"
    found: dict[str, Path] = {}
    if not results.is_dir():
        return found
    for path in results.rglob("latency.csv"):
        posix = path.as_posix()
        if case_stem not in posix:
            continue
        if "cmr_descal" not in posix:
            continue
        found["latency"] = path
        events = path.parent / "events.csv"
        if events.is_file():
            found["events"] = events
    return found


def ingest_pack(pack: Path) -> int:
    matrix_path = pack / "matrix.json"
    if not matrix_path.is_file():
        print("FAIL missing", matrix_path, flush=True)
        return 2
    matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
    rtl_root = Path(matrix.get("rtl_dir") or (pack / "rtl"))
    ingested = 0
    missing = []
    for job in matrix.get("jobs") or []:
        design_id = job["design_id"]
        tag = job["tag"]
        packets = Path(job["packets_json"]) if job.get("packets_json") else None
        case_path = Path(job["case"]) if job.get("case") else None
        out = rtl_root / design_id / tag / "events.jsonl"
        if out.is_file():
            ingested += 1
            print("INGEST_HAVE", out, flush=True)
            continue
        csvs = _find_case_csvs(case_path.stem) if case_path else {}
        if packets is None or not packets.is_file() or "latency" not in csvs:
            missing.append("%s/%s" % (design_id, tag))
            continue
        records = assemble_event_records(
            packets_json=packets,
            latency_csv=csvs.get("latency"),
            event_csv=csvs.get("events"),
        )
        for rec in records:
            validate_event_record(rec, label=str(rec.get("original_event_id")))
        dump_event_jsonl(records, out)
        ingested += 1
        print("INGEST", out, "events", len(records), flush=True)
    print("INGEST_PACK ingested=%d missing=%s" % (ingested, ",".join(missing) or "none"), flush=True)
    return 0 if not missing else 1


def probe() -> int:
    try:
        import paramiko
        from run_remote_cmr_flow import password
    except Exception as exc:
        print("PROBE_FAIL import", type(exc).__name__, str(exc)[:200], flush=True)
        return 1

    host = os.environ.get("C1_HOST", "192.168.2.8")
    user = os.environ.get("C1_USER", "ghy19")
    root = os.environ.get("CMR_DES_REMOTE_ROOT") or os.environ.get(
        "CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR"
    )
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(
            host,
            username=user,
            password=password(),
            timeout=40,
            banner_timeout=90,
            allow_agent=False,
            look_for_keys=False,
            compress=True,
        )
    except Exception as exc:
        print("PROBE_FAIL", type(exc).__name__, str(exc)[:200], flush=True)
        return 1
    ids_1248 = (
        "ls -d %s/outputs/*1248* 2>/dev/null | tail -n 8; "
        "for id in %s/outputs/*1248*; do "
        "base=$(basename \"$id\"); "
        "echo -n \"$base AckinDelay \"; grep -c AckinDelay $id/NoC_64nodes_post.v 2>/dev/null; "
        "echo -n \"$base DelayUnitPs50 \"; grep -c DelayUnitPs50 $id/NoC_64nodes_post.v 2>/dev/null; "
        "echo -n \"$base DelayUnitPs250 \"; grep -c DelayUnitPs250 $id/NoC_64nodes_post.v 2>/dev/null; "
        "done" % (root, root)
    )
    cmd = (
        "echo '---HOSTS---'; bhosts -w 2>/dev/null | head -n 40; "
        "echo '---LSLOAD---'; lsload 2>/dev/null | head -n 40; "
        "echo '---JOBS---'; bjobs -u %s -noheader 2>/dev/null | awk '{print $1,$3,$6,$7}' | head -n 40; "
        "echo '---PROP64_DEL050---'; "
        "ls -lh %s/outputs/%s/NoC_64nodes_post.v %s/outputs/%s/NoC_64nodes.sdf 2>/dev/null; "
        "echo -n 'AckinDelay '; grep -c AckinDelay %s/outputs/%s/NoC_64nodes_post.v 2>/dev/null; "
        "echo -n 'DelayUnitPs50 '; grep -c DelayUnitPs50 %s/outputs/%s/NoC_64nodes_post.v 2>/dev/null; "
        "echo -n 'DelayUnitPs250 '; grep -c DelayUnitPs250 %s/outputs/%s/NoC_64nodes_post.v 2>/dev/null; "
        "echo '---1248---'; %s; "
        "echo '---MESH64---'; "
        "ls -lh %s/outputs/%s/CMRMeshNoC_post.v %s/outputs/%s/CMRMeshNoC.sdf 2>/dev/null; "
        "echo -n 'mesh AckinDelay '; grep -c AckinDelay %s/outputs/%s/CMRMeshNoC_post.v 2>/dev/null; "
        "echo -n 'mesh DelayUnitPs50 '; grep -c DelayUnitPs50 %s/outputs/%s/CMRMeshNoC_post.v 2>/dev/null; "
        "echo -n 'mesh DelayUnitPs250 '; grep -c DelayUnitPs250 %s/outputs/%s/CMRMeshNoC_post.v 2>/dev/null; "
        "echo '---FROZEN---'; "
        "for id in %s; do if test -e %s/outputs/$id; then echo HAVE $id; else echo MISS $id; fi; done"
        % (
            user,
            root, PROP64_DEL050_CANDIDATE, root, PROP64_DEL050_CANDIDATE,
            root, PROP64_DEL050_CANDIDATE,
            root, PROP64_DEL050_CANDIDATE,
            root, PROP64_DEL050_CANDIDATE,
            ids_1248,
            root, MESH64_CANDIDATE, root, MESH64_CANDIDATE,
            root, MESH64_CANDIDATE,
            root, MESH64_CANDIDATE,
            root, MESH64_CANDIDATE,
            FROZEN_NOC64_ACKIN250_RUN_ID,
            root,
        )
    )
    _, stdout, stderr = client.exec_command(cmd)
    text = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    client.close()
    print("PROBE_OK host=%s root=%s" % (host, root), flush=True)
    print(text or err, flush=True)
    print(
        "Ackin-250 %s is not a timing-cal netlist. "
        "PROP64 DEL050 candidate (read-only SKIP_DC): %s. "
        "Mesh candidate (read-only if DelayUnitPs50): %s. "
        "Do not overwrite frozen hop/Sync64 IDs. "
        "Use CMR_DES_BSUB_EXTRA to pick idle hosts."
        % (FROZEN_NOC64_ACKIN250_RUN_ID, PROP64_DEL050_CANDIDATE, MESH64_CANDIDATE),
        flush=True,
    )
    return 0


def _refuse_netlist(netlist_run_id: str, *, allow_ackin250: bool) -> str | None:
    if not netlist_run_id:
        return None
    if netlist_run_id == FROZEN_NOC64_ACKIN250_RUN_ID and not allow_ackin250:
        return (
            "refusing netlist %s (Ackin-250). Timing cal needs a new DEL050 run id. "
            "--allow-ackin250 only if you mean a non-timing smoke. %s"
            % (netlist_run_id, NOT_FAT_VS_THIN_DELAY.get(netlist_run_id, ""))
        )
    if netlist_run_id in FROZEN_WRITE_RUN_IDS and netlist_run_id != FROZEN_NOC64_ACKIN250_RUN_ID:
        return "refusing frozen netlist %s (hop/Sync64/archive). Never overwrite." % netlist_run_id
    return None


def _jobs_for_design(pack: Path, design: str) -> list[dict]:
    matrix_path = pack / "matrix.json"
    if not matrix_path.is_file():
        return []
    matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
    return [job for job in (matrix.get("jobs") or []) if job.get("design_id") == design]


def _case_names(jobs: list[dict], fallback: Path | None) -> list[str]:
    names = []
    for job in jobs:
        if job.get("case"):
            names.append(Path(job["case"]).stem)
    if not names and fallback is not None:
        names.append(fallback.stem)
    return names


def _build_env(args: argparse.Namespace, design: str, jobs: list[dict]) -> dict[str, str]:
    spec = DESIGN_RUNNERS[design]
    run = descal_run_id(design.lower())
    case_dir = None
    names = _case_names(jobs, args.case)
    if jobs:
        case_dir = str(Path(jobs[0]["case"]).parent.resolve())
    elif args.case:
        case_dir = str(args.case.parent.resolve())
    netlist = args.netlist_run_id or spec.get("netlist")
    env = {
        "CMR_DESCAL": "1",
        "CMR_DESCAL_SUBMIT_ONLY": "0" if args.wait else "1",
        "CMR_NOC64_ALLOW_V3": "1",
        "CMR_MESH64_ALLOW_V3": "1",
        "CMR_NOC256_ALLOW_V3": "1",
        "CMR_NOC64_SKIP_FUNC": "1",
        "CMR_MESH64_SKIP_FUNC": "1",
        "CMR_DES_BSUB_EXTRA": os.environ.get("CMR_DES_BSUB_EXTRA", ""),
        "CMR_REMOTE_ROOT": os.environ.get(
            "CMR_DES_REMOTE_ROOT",
            os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR"),
        ),
    }
    if case_dir:
        env["CMR_NOC64_V3_CASE_DIR"] = case_dir
        env["CMR_MESH64_V3_CASE_DIR"] = case_dir
        env["CMR_NOC256_V3_CASE_DIR"] = case_dir
    if names:
        joined = ",".join(names)
        env["CMR_NOC64_CASES"] = joined
        env["CMR_NOC64_FUNC_CASES"] = joined
        env["CMR_MESH64_CASES"] = joined
        env["CMR_MESH64_FUNC_CASES"] = joined
        env["CMR_NOC256_CASES"] = joined
    if spec["runner"] == "noc64":
        env["CMR_FAT_LANE_PROFILE"] = spec["profile"]
        env["CMR_Q64_PROFILE"] = spec["profile"]
        env["CMR_NOC64_RUN_ID"] = run
        if netlist:
            env["CMR_NOC64_NETLIST_RUN_ID"] = netlist
        elif args.dc_mode == "hier":
            env["CMR_HIER_KIND"] = spec["profile"]
            env["CMR_HIER_STITCH_RUN_ID"] = run
    elif spec["runner"] == "mesh64":
        env["CMR_MESH64_RUN_ID"] = run
        if netlist:
            env["CMR_MESH64_NETLIST_RUN_ID"] = netlist
        elif args.dc_mode == "hier":
            env["CMR_HIER_KIND"] = "mesh"
            env["CMR_HIER_STITCH_RUN_ID"] = run
    else:
        env["CMR_NOC256_KIND"] = spec["kind"]
        env["CMR_NOC256_RUN_ID"] = run
    return env


def _runner_script(args: argparse.Namespace, design: str, env: dict[str, str]) -> Path:
    spec = DESIGN_RUNNERS[design]
    if spec["runner"] == "noc256":
        return CMR / "run_remote_cmr_noc256_rtl.py"
    if args.dc_mode == "hier" and not env.get("CMR_NOC64_NETLIST_RUN_ID") and not env.get("CMR_MESH64_NETLIST_RUN_ID"):
        if spec["runner"] in ("noc64", "mesh64"):
            return CMR / "run_remote_cmr_hier_dc.py"
    if spec["runner"] == "mesh64":
        return CMR / "run_remote_cmr_mesh64_sdf.py"
    return CMR / "run_remote_cmr_noc64_sdf.py"


def submit(args: argparse.Namespace) -> int:
    designs = [args.design] if args.design else list(DESIGN_RUNNERS)
    unknown = [d for d in designs if d not in DESIGN_RUNNERS]
    if unknown:
        print("FAIL unknown design", ",".join(unknown), flush=True)
        return 2
    plans = []
    for design in designs:
        jobs = _jobs_for_design(args.pack, design)
        if args.case and not jobs:
            jobs = [{"design_id": design, "tag": args.tag, "case": str(args.case)}]
        if not jobs and not args.case:
            print("FAIL no cases for", design, "(need --pack with matrix.json or --case)", flush=True)
            return 2
        env = _build_env(args, design, jobs)
        netlist = env.get("CMR_NOC64_NETLIST_RUN_ID") or env.get("CMR_MESH64_NETLIST_RUN_ID") or ""
        reason = _refuse_netlist(netlist, allow_ackin250=args.allow_ackin250)
        if reason:
            print("FAIL", design, reason, flush=True)
            return 2
        script = _runner_script(args, design, env)
        plan = {
            "design": design,
            "script": str(script),
            "job_prefix": JOB_PREFIX,
            "env": env,
            "cases": _case_names(jobs, args.case),
            "dc_mode": args.dc_mode,
            "launch": bool(args.launch),
        }
        plans.append(plan)
        print("SUBMIT_PLAN", json.dumps(plan, indent=2), flush=True)

    if not args.launch:
        print(
            "Not launching. Re-run with --launch only after probe. "
            "Do not overwrite frozen IDs. Hierarchical DC is default for missing netlists; "
            "pass --dc-mode full for one full-network DC per design (still parallel on LSF).",
            flush=True,
        )
        return 0

    failed = []
    for plan in plans:
        env = os.environ.copy()
        env.update(plan["env"])
        print("LAUNCH", plan["design"], plan["script"], flush=True)
        completed = subprocess.run(
            [sys.executable, plan["script"]],
            cwd=str(REPO),
            env=env,
            check=False,
        )
        print("LAUNCH_DONE", plan["design"], "rc", completed.returncode, flush=True)
        if completed.returncode != 0:
            failed.append("%s:%s" % (plan["design"], completed.returncode))
    if failed:
        print("LAUNCH_FAIL", ",".join(failed), flush=True)
        return 1
    print("LAUNCH_OK designs=%d" % len(plans), flush=True)
    return 0


def main() -> int:
    args = parse_args()
    if args.wait:
        args.submit_only = False
    if args.ingest_pack:
        return ingest_pack(args.pack)
    if args.ingest:
        return ingest(args)
    if args.submit:
        return submit(args)
    return probe()


if __name__ == "__main__":
    raise SystemExit(main())
