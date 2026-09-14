#!/usr/bin/env python3
"""Gate B: four async 64-node whole-network DC + MAXIMUM-SDF smokes.

THIN64 / PROP64 / PFAT64 / FM64 only.  Never PROP256 / FM256 / 1024.
Never overwrite frozen hop / Sync64 / Ackin-250 / mesh-candidate dirs.
Never flip paper_matrix_allowed.  DES is not a paper substitute.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

CMR = Path(__file__).resolve().parent
REPO = CMR.parents[2]
EXPERIMENTS = REPO / "DATE paper" / "experiments"
SCRIPTS = EXPERIMENTS / "scripts"
MODEL = EXPERIMENTS / "model"
PACK = EXPERIMENTS / "intermediate" / "des_calibration"
CASE_DIR = PACK / "cases"
TRACE_DIR = PACK / "traces"
RESULT_ROOT = CMR / "results"
STATE_PATH = RESULT_ROOT / "gate_b_async64" / "state.json"
PLAN_PATH = EXPERIMENTS / "configs" / "plans" / "phase6_network_gates.json"

for path in (SCRIPTS, MODEL, CMR):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.canonical_trace import dump_jsonl, generate_trace  # noqa: E402
from date_v3.designs import load_design, materialize_opts  # noqa: E402
from date_v3.hashutil import load_json, sha256_file, write_json  # noqa: E402
from date_v3.manifest import config_hash_of, new_manifest, save_manifest  # noqa: E402
from date_v3.materialize_case import materialize_path  # noqa: E402
from date_v3.registry import upsert_run  # noqa: E402
from date_v3.schema import validate_file  # noqa: E402
from des import CALIBRATION_SEED, PAPER_SEEDS  # noqa: E402
from prepare_descal import directed_corners  # noqa: E402

from cmr_frozen_run_ids import (  # noqa: E402
    FROZEN_NOC64_ACKIN250_RUN_ID,
    FROZEN_WRITE_RUN_IDS,
    refuse_overwrite,
)
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry  # noqa: E402

FORBIDDEN_DESIGNS = ("PROP256", "FM256", "PROP1024", "FM1024", "HREP1024", "PROP1024_MESH4")
ASYNC64 = ("THIN64", "PROP64", "PFAT64", "FM64")
PROP64_DEL050 = "20260830_132453_cmr_noc64_1222_ackin50_p50_1222"
PFAT64_DEL050_CANDIDATE = "20260901_140918_cmr_descal_pfat64_1248"
FM64_DESCAL_CANDIDATE = "20260901_172539_cmr_descal_fm64"
MESH64_FROZEN = "20260831_115856_cmr_mesh64_p50"
DEFAULT_HOSTS = "node21 node20 node4"
ROOT_DEFAULT = "/home/ghy19/Asynchronous_Router_CMR"

CLASSES = (
    ("directed", "KEY-64_n64_s900001_zero", 0.0, "key"),
    ("zero", "TOPO-UR_n64_s900001_zero", 0.0, "ur"),
    ("medium", "TOPO-UR_n64_s900001_r0p10", 0.10, "ur"),
    ("near-sat", "TOPO-UR_n64_s900001_r0p30", 0.30, "ur"),
)
RETRY_NEAR_SAT = ("near-sat-r0p20", "TOPO-UR_n64_s900001_r0p20", 0.20, "ur")


def remote_root() -> str:
    return os.environ.get(
        "CMR_DES_REMOTE_ROOT",
        os.environ.get("CMR_REMOTE_ROOT", ROOT_DEFAULT),
    )


def profile_run_id(base: str, profile: str | None) -> str:
    if profile:
        return "%s_%s" % (base, profile)
    return base


def case_stem(trace_prefix: str, design_id: str, top_lanes: int) -> str:
    return "%s_%s_top%d" % (trace_prefix, design_id, top_lanes)


def design_specs() -> dict[str, dict]:
    return {
        "THIN64": {
            "runner": "noc64",
            "profile": "thin",
            "script": CMR / "run_remote_cmr_noc64_sdf.py",
            "top_lanes": 1,
            "post_v": "NoC_64nodes_post.v",
            "sdf": "NoC_64nodes.sdf",
            "dc_pass": "CMR_NOC64_DC_PASS",
            "skip_dc_forbidden": (FROZEN_NOC64_ACKIN250_RUN_ID,),
        },
        "PROP64": {
            "runner": "noc64",
            "profile": "1222",
            "script": CMR / "run_remote_cmr_noc64_sdf.py",
            "top_lanes": 2,
            "post_v": "NoC_64nodes_post.v",
            "sdf": "NoC_64nodes.sdf",
            "dc_pass": "CMR_NOC64_DC_PASS",
            "skip_dc_preferred": PROP64_DEL050,
            "skip_dc_forbidden": (FROZEN_NOC64_ACKIN250_RUN_ID,),
        },
        "PFAT64": {
            "runner": "noc64",
            "profile": "1248",
            "script": CMR / "run_remote_cmr_noc64_sdf.py",
            "top_lanes": 8,
            "post_v": "NoC_64nodes_post.v",
            "sdf": "NoC_64nodes.sdf",
            "dc_pass": "CMR_NOC64_DC_PASS",
            "skip_dc_preferred": PFAT64_DEL050_CANDIDATE,
            "skip_dc_forbidden": (FROZEN_NOC64_ACKIN250_RUN_ID,),
        },
        "FM64": {
            "runner": "mesh64",
            "profile": None,
            "script": CMR / "run_remote_cmr_mesh64_sdf.py",
            "top_lanes": 0,
            "post_v": "CMRMeshNoC_post.v",
            "sdf": "CMRMeshNoC.sdf",
            "dc_pass": "CMR_MESH64_DC_PASS",
            "skip_dc_preferred": FM64_DESCAL_CANDIDATE,
            "skip_dc_forbidden": (MESH64_FROZEN, FROZEN_NOC64_ACKIN250_RUN_ID),
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--emit-cases", action="store_true")
    parser.add_argument("--submit", action="store_true")
    parser.add_argument("--poll-fetch", action="store_true")
    parser.add_argument("--all", action="store_true", help="emit, probe, submit, then poll-fetch")
    parser.add_argument("--design", action="append", choices=list(ASYNC64))
    parser.add_argument("--state", type=Path, default=STATE_PATH)
    parser.add_argument("--poll-seconds", type=int, default=120)
    parser.add_argument("--timeout-hours", type=float, default=14.0)
    return parser.parse_args()


def selected_designs(args: argparse.Namespace) -> tuple[str, ...]:
    if args.design:
        return tuple(args.design)
    return ASYNC64


def default_bsub_extra() -> str:
    extra = os.environ.get("CMR_DES_BSUB_EXTRA", "").strip()
    if extra:
        return extra
    return '-m "%s"' % DEFAULT_HOSTS


def emit_cases() -> list[dict]:
    if CALIBRATION_SEED in PAPER_SEEDS:
        raise SystemExit("calibration seed collides with paper seeds")
    CASE_DIR.mkdir(parents=True, exist_ok=True)
    TRACE_DIR.mkdir(parents=True, exist_ok=True)
    traces: dict[str, Path] = {}
    key = TRACE_DIR / "KEY-64_n64_s900001.jsonl"
    dump_jsonl(
        directed_corners(
            nodes=64, seed=CALIBRATION_SEED, corners=[0, 7, 56, 63], random_unicasts=8
        ),
        key,
    )
    traces["directed"] = key
    for cls_name, _prefix, load, kind in CLASSES + (RETRY_NEAR_SAT,):
        if kind != "ur":
            continue
        path = TRACE_DIR / ("%s.jsonl" % _prefix)
        dump_jsonl(
            generate_trace(
                "TOPO-UR",
                seed=CALIBRATION_SEED,
                nodes=64,
                smoke=True,
                load_point=load,
            ),
            path,
        )
        traces[cls_name] = path
    jobs = []
    for design_id in ASYNC64:
        opts = materialize_opts(design_id)
        for cls_name, prefix, _load, kind in CLASSES + (RETRY_NEAR_SAT,):
            jsonl = traces["directed"] if kind == "key" else traces[cls_name]
            path = materialize_path(
                jsonl,
                CASE_DIR,
                top_lanes=opts["top_lanes"],
                hrep=opts["hrep"],
                routing=opts["routing"],
                design_id=design_id,
            )
            expected = case_stem(prefix, design_id, opts["top_lanes"])
            if path.stem != expected:
                raise SystemExit("case name %s != %s" % (path.stem, expected))
            jobs.append(
                {
                    "design_id": design_id,
                    "class": cls_name,
                    "case": str(path),
                    "stem": path.stem,
                }
            )
            print("CASE", design_id, cls_name, path.name, flush=True)
    matrix = {
        "schema": "date-v3-gate-b-pack-v1",
        "calibration_seed": CALIBRATION_SEED,
        "paper_seeds_excluded": list(PAPER_SEEDS),
        "packet_flits": 5,
        "designs": list(ASYNC64),
        "jobs": jobs,
        "notes": (
            "Gate B smoke pack. Directed KEY-64 corners plus TOPO-UR zero/0.10/0.30 "
            "(0.20 retry). Not paper 11k. Do not launch 256/1024."
        ),
    }
    write_json(PACK / "gate_b_matrix.json", matrix)
    print("EMIT_OK cases=%d dir=%s" % (len(jobs), CASE_DIR), flush=True)
    return jobs


def _ssh(client, cmd: str) -> str:
    client, text = remote_run_retry(client, cmd)
    return text or ""


def probe_netlist(client, root: str, run_id: str, post_v: str, sdf: str) -> dict:
    cmd = (
        "id=%s; "
        "echo NETLIST $id; "
        "if test -s %s/outputs/$id/%s; then echo HAVE_POST; else echo MISS_POST; fi; "
        "if test -s %s/outputs/$id/%s; then echo HAVE_SDF; else echo MISS_SDF; fi; "
        "echo -n AckinDelay; grep -c AckinDelay %s/outputs/$id/%s 2>/dev/null || echo 0; "
        "echo -n DelayUnitPs50; grep -c DelayUnitPs50 %s/outputs/$id/%s 2>/dev/null || echo 0; "
        "echo -n DelayUnitPs250; grep -c DelayUnitPs250 %s/outputs/$id/%s 2>/dev/null || echo 0; "
        "ls -lh %s/outputs/$id/%s %s/outputs/$id/%s 2>/dev/null"
        % (
            run_id,
            root, post_v, root, sdf,
            root, post_v, root, post_v, root, post_v,
            root, post_v, root, sdf,
        )
    )
    text = _ssh(client, cmd)
    ps50 = 0
    ps250 = 0
    match50 = re.search(r"DelayUnitPs50\s*(\d+)", text)
    match250 = re.search(r"DelayUnitPs250\s*(\d+)", text)
    if match50:
        ps50 = int(match50.group(1))
    if match250:
        ps250 = int(match250.group(1))
    ok = (
        "HAVE_POST" in text
        and "HAVE_SDF" in text
        and ps50 > 0
        and ps250 == 0
    )
    return {
        "run_id": run_id,
        "ok": ok,
        "have_post": "HAVE_POST" in text,
        "have_sdf": "HAVE_SDF" in text,
        "delay_unit_ps50": ps50,
        "delay_unit_ps250": ps250,
        "raw": text.strip(),
    }


def pick_hosts(lsload_text: str, bhosts_text: str) -> list[str]:
    closed = set()
    for line in bhosts_text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("node"):
            status = parts[1].lower()
            if "closed" in status or status not in ("ok", "unavail"):
                if "closed" in status:
                    closed.add(parts[0])
    ranked = []
    for line in lsload_text.splitlines():
        parts = line.split()
        if len(parts) < 6 or not parts[0].startswith("node"):
            continue
        host, status = parts[0], parts[1].lower()
        if host in closed or status != "ok":
            continue
        ut = parts[5]
        try:
            ut_val = float(ut.rstrip("%"))
        except ValueError:
            ut_val = 99.0
        ranked.append((ut_val, host))
    ranked.sort()
    return [host for _ut, host in ranked[:6]]


def probe(*, designs: tuple[str, ...]) -> dict:
    root = remote_root()
    client = connect()
    try:
        text = _ssh(
            client,
            "echo '---HOSTS---'; bhosts -w 2>/dev/null | head -n 50; "
            "echo '---LSLOAD---'; lsload 2>/dev/null | head -n 50; "
            "echo '---JOBS---'; bjobs -u ghy19 -noheader -o 'jobid stat name exec_host' 2>/dev/null | head -n 60; "
            "echo '---ACKIN250---'; "
            "if test -e %s/outputs/%s; then echo HAVE %s; else echo MISS %s; fi"
            % (root, FROZEN_NOC64_ACKIN250_RUN_ID, FROZEN_NOC64_ACKIN250_RUN_ID, FROZEN_NOC64_ACKIN250_RUN_ID),
        )
        print("PROBE_RAW", flush=True)
        print(text, flush=True)
        hosts_block = text.split("---LSLOAD---")[0] if "---LSLOAD---" in text else text
        load_block = ""
        if "---LSLOAD---" in text:
            load_block = text.split("---LSLOAD---")[1].split("---JOBS---")[0]
        idle = pick_hosts(load_block, hosts_block)
        extra = os.environ.get("CMR_DES_BSUB_EXTRA", "").strip()
        if not extra:
            extra = '-m "%s"' % " ".join(idle[:3] or DEFAULT_HOSTS.split())
        netlists = {}
        specs = design_specs()
        for design_id in designs:
            spec = specs[design_id]
            preferred = spec.get("skip_dc_preferred")
            if preferred:
                netlists[design_id] = probe_netlist(
                    client, root, preferred, spec["post_v"], spec["sdf"]
                )
            else:
                netlists[design_id] = {"run_id": None, "ok": False}
        ackin250 = probe_netlist(
            client, root, FROZEN_NOC64_ACKIN250_RUN_ID, "NoC_64nodes_post.v", "NoC_64nodes.sdf"
        )
        frozen_mesh = probe_netlist(
            client, root, MESH64_FROZEN, "CMRMeshNoC_post.v", "CMRMeshNoC.sdf"
        )
    finally:
        client.close()
    if ackin250.get("delay_unit_ps250", 0) and netlists.get("PROP64", {}).get("run_id") == FROZEN_NOC64_ACKIN250_RUN_ID:
        raise SystemExit("refusing Ackin-250 netlist")
    result = {
        "hosts": idle,
        "bsub_extra": extra,
        "netlists": netlists,
        "ackin250_have": ackin250.get("have_post"),
        "frozen_mesh_ok_but_do_not_skip": frozen_mesh.get("ok"),
        "root": root,
    }
    print("PROBE_OK hosts=%s extra=%s" % (",".join(idle) or "none", extra), flush=True)
    for design_id, info in netlists.items():
        print(
            "PROBE_NETLIST",
            design_id,
            "ok" if info.get("ok") else "need_dc",
            info.get("run_id"),
            "ps50=%s" % info.get("delay_unit_ps50"),
            "ps250=%s" % info.get("delay_unit_ps250"),
            flush=True,
        )
    print(
        "Ackin-250 %s is not a timing-cal netlist. Frozen mesh %s is not SKIP_DC for Gate B."
        % (FROZEN_NOC64_ACKIN250_RUN_ID, MESH64_FROZEN),
        flush=True,
    )
    return result


def resolve_netlist(design_id: str, spec: dict, probe_info: dict | None) -> str | None:
    forbidden = set(spec.get("skip_dc_forbidden") or ())
    preferred = spec.get("skip_dc_preferred")
    probed = (probe_info or {}).get("netlists", {}).get(design_id) or {}
    if design_id == "THIN64":
        return None
    if design_id == "FM64":
        # Never SKIP_DC the frozen mesh candidate. Reuse a completed descal DC if present.
        if probed.get("ok") and probed.get("run_id") == FM64_DESCAL_CANDIDATE:
            print("SKIP_DC FM64 reuse completed descal %s (not frozen mesh)" % FM64_DESCAL_CANDIDATE, flush=True)
            return FM64_DESCAL_CANDIDATE
        return None
    if preferred and probed.get("ok") and preferred not in forbidden:
        if preferred == FROZEN_NOC64_ACKIN250_RUN_ID:
            raise SystemExit("refusing Ackin-250")
        print("SKIP_DC %s netlist=%s" % (design_id, preferred), flush=True)
        return preferred
    return None


def build_env(design_id: str, spec: dict, base_id: str, netlist: str | None, cases: list[str]) -> dict[str, str]:
    env = os.environ.copy()
    extra = default_bsub_extra()
    joined = ",".join(cases)
    env.update(
        {
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_DES_BSUB_EXTRA": extra,
            "CMR_REMOTE_ROOT": remote_root(),
            "CMR_NOC64_ALLOW_V3": "1",
            "CMR_MESH64_ALLOW_V3": "1",
            "CMR_NOC64_SKIP_FUNC": "1",
            "CMR_MESH64_SKIP_FUNC": "1",
            "CMR_NOC64_SKIP_SDF": "0",
            "CMR_MESH64_SKIP_SDF": "0",
            "CMR_NOC64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_MESH64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_NOC64_CASES": joined,
            "CMR_NOC64_FUNC_CASES": joined,
            "CMR_MESH64_CASES": joined,
            "CMR_MESH64_FUNC_CASES": joined,
            "CMR_RCU_MATCHED_DELAY_STEPS": "1",
            "CMR_RCU_MATCHED_DELAY_UNIT_PS": "50",
            "CMR_OPM_ACKIN_DELAY_UNIT_PS": "50",
            "CMR_RCU_MATCHED_BUF_STAGES": "0",
        }
    )
    env.pop("CMR_FORCE_OVERWRITE_FROZEN", None)
    env.pop("CMR_NOC256_CASES", None)
    env.pop("CMR_NETWORK_DESIGN_ID", None)
    if spec["runner"] == "noc64":
        env["CMR_FAT_LANE_PROFILE"] = spec["profile"]
        env["CMR_Q64_PROFILE"] = spec["profile"]
        env["CMR_NOC64_RUN_ID"] = base_id
        if netlist:
            env["CMR_NOC64_NETLIST_RUN_ID"] = netlist
        else:
            env.pop("CMR_NOC64_NETLIST_RUN_ID", None)
    else:
        env["CMR_MESH64_RUN_ID"] = base_id
        if netlist:
            env["CMR_MESH64_NETLIST_RUN_ID"] = netlist
        else:
            env.pop("CMR_MESH64_NETLIST_RUN_ID", None)
    return env


def submit_designs(args: argparse.Namespace, probe_info: dict | None) -> dict:
    designs = selected_designs(args)
    for design_id in designs:
        if design_id in FORBIDDEN_DESIGNS:
            raise SystemExit("refusing design %s" % design_id)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    specs = design_specs()
    state = {
        "schema": "date-v3-gate-b-state-v1",
        "stamp": stamp,
        "bsub_extra": default_bsub_extra(),
        "root": remote_root(),
        "designs": {},
        "paper_matrix_allowed": False,
    }
    if args.state.is_file():
        try:
            previous = load_json(args.state)
            if previous.get("designs"):
                state["designs"] = dict(previous["designs"])
                state["previous_stamp"] = previous.get("stamp")
        except Exception:
            pass
    for design_id in designs:
        spec = specs[design_id]
        tag = design_id.lower()
        base_id = "%s_cmr_descal_%s" % (stamp, tag)
        refuse_overwrite(base_id, action="gate-b-submit")
        run_id = profile_run_id(base_id, spec["profile"])
        refuse_overwrite(run_id, action="gate-b-submit")
        netlist = resolve_netlist(design_id, spec, probe_info)
        if netlist:
            if netlist in spec.get("skip_dc_forbidden", ()):
                raise SystemExit("refusing forbidden SKIP_DC %s for %s" % (netlist, design_id))
            if netlist == FROZEN_NOC64_ACKIN250_RUN_ID:
                raise SystemExit("refusing Ackin-250")
            if netlist == MESH64_FROZEN:
                raise SystemExit("refusing frozen mesh SKIP_DC")
        cases = [
            case_stem(prefix, design_id, spec["top_lanes"])
            for _cls, prefix, _load, _kind in CLASSES
        ]
        missing = [name for name in cases if not (CASE_DIR / ("%s.case" % name)).is_file()]
        if missing:
            raise SystemExit("missing cases: " + ",".join(missing))
        env = build_env(design_id, spec, base_id, netlist, cases)
        print("LAUNCH", design_id, spec["script"].name, "run_id", run_id, "netlist", netlist or run_id, flush=True)
        completed = subprocess.run(
            [sys.executable, str(spec["script"])],
            cwd=str(REPO),
            env=env,
            check=False,
        )
        print("LAUNCH_DONE", design_id, "rc", completed.returncode, flush=True)
        summary_path = RESULT_ROOT / run_id / "summary.json"
        summary = load_json(summary_path) if summary_path.is_file() else {}
        if spec["runner"] == "noc64" and summary.get("profiles"):
            summary = summary["profiles"][0]
        state["designs"][design_id] = {
            "base_id": base_id,
            "run_id": summary.get("run_id") or run_id,
            "netlist_run_id": summary.get("netlist_run_id") or netlist or run_id,
            "skip_dc": bool(netlist),
            "cases": cases,
            "launch_rc": completed.returncode,
            "summary": str(summary_path) if summary_path.is_file() else None,
            "dc_job": summary.get("dc_job"),
            "sdf_jobs": {
                name: (entry or {}).get("job_id")
                for name, entry in (summary.get("sdf_cases") or {}).items()
            },
        }
        if completed.returncode != 0:
            state["designs"][design_id]["status"] = "submit_fail"
            print("SUBMIT_FAIL keep evidence, continue other designs:", design_id, flush=True)
        else:
            state["designs"][design_id]["status"] = "submitted"
    args.state.parent.mkdir(parents=True, exist_ok=True)
    write_json(args.state, state)
    print("SUBMIT_STATE", args.state, flush=True)
    return state


def fetch_gls_snippet(client, run_id: str, name: str) -> tuple[str, str]:
    root = remote_root()
    base = "%s/logs/gls/%s/sdf/%s" % (root, run_id, name)
    cmd = (
        "echo __RUN__; "
        "if test -s %s/run.log; then "
        "grep -E 'TB_RESULT |Doing SDF annotation ...... Done|TB_X_FAIL|TB_HARD_TIMEOUT|TB_FATAL|TB_STALL|TB_UNEXPECTED|TB_PROTOCOL_X|IFNSDFA|Fatal:' %s/run.log | head -n 40; "
        "echo __TVIOL_COUNT__; grep -c 'Timing violation' %s/run.log || true; "
        "else echo __MISSING_RUN__; "
        "tail -n 20 %s/logs/gls/%s/sdf_%s.bsub.log %s/logs/gls/%s/sdf_%s.bsub.err 2>/dev/null; "
        "fi; "
        "echo __ANNOTATE__; grep 'Total errors:' %s/sdf_annotate.log 2>/dev/null | tail -n 1"
        % (
            base, base, base,
            root, run_id, name, root, run_id, name,
            base,
        )
    )
    text = _ssh(client, cmd)
    run_part = text
    annotate = ""
    if "__ANNOTATE__" in text:
        run_part, annotate = text.split("__ANNOTATE__", 1)
    if "__TVIOL_COUNT__" in run_part:
        head, count_text = run_part.split("__TVIOL_COUNT__", 1)
        try:
            count = int(re.search(r"(\d+)", count_text).group(1))
        except Exception:
            count = 0
        run_part = head + "\nCMR_TVIOL_COUNT %d\n" % count
        if count:
            run_part += "Timing violation\n"
    return run_part, annotate


def parse_gls(run_log: str, annotate: str, jid: str | None) -> tuple[dict, bool]:
    errors = re.search(r"Total errors:\s*(\d+)", annotate)
    failure_tokens = (
        "TB_RESULT FAIL",
        "TB_X_FAIL",
        "TB_UNEXPECTED_FAIL",
        "TB_STALL_FAIL",
        "TB_HARD_TIMEOUT",
        "TB_PROTOCOL_X",
        "TB_FATAL",
        "Timing violation",
    )
    first_failure = next(
        (line for line in run_log.splitlines() if any(token in line for token in failure_tokens)),
        None,
    )
    entry = {
        "job_id": jid,
        "mode": "sdf",
        "tb_pass": "TB_RESULT PASS" in run_log,
        "x_failure": "TB_X_FAIL" in run_log or "TB_PROTOCOL_X" in run_log,
        "unexpected_failure": "TB_UNEXPECTED_FAIL" in run_log,
        "stall_failure": "TB_STALL_FAIL" in run_log,
        "hard_timeout": "TB_HARD_TIMEOUT" in run_log,
        "fatal_failure": "TB_FATAL" in run_log or "Fatal:" in run_log,
        "timing_violation_count": int(re.search(r"CMR_TVIOL_COUNT\s+(\d+)", run_log).group(1))
        if re.search(r"CMR_TVIOL_COUNT\s+(\d+)", run_log)
        else run_log.count("Timing violation"),
        "first_failure": first_failure,
        "result_line": next(
            (line for line in run_log.splitlines() if "TB_RESULT " in line),
            None,
        ),
        "annotation_done": "Doing SDF annotation ...... Done" in run_log,
        "annotation_errors": int(errors.group(1)) if errors else None,
        "ifnsdfa": "IFNSDFA" in run_log,
    }
    passed = (
        entry["tb_pass"]
        and entry["annotation_done"]
        and entry["annotation_errors"] == 0
        and not entry["ifnsdfa"]
        and not entry["x_failure"]
        and not entry["unexpected_failure"]
        and not entry["stall_failure"]
        and not entry["hard_timeout"]
        and not entry["fatal_failure"]
        and entry["timing_violation_count"] == 0
    )
    return entry, passed



def job_states(client, job_ids: list[str]) -> dict[str, str]:
    ids = [jid for jid in job_ids if jid]
    if not ids:
        return {}
    text = _ssh(
        client,
        "bjobs -noheader -o 'jobid stat' %s 2>/dev/null || true" % " ".join(ids),
    )
    states = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].isdigit():
            states[parts[0]] = parts[1]
    for jid in ids:
        if jid not in states:
            states[jid] = "DONE"
    return states


def remote_hash(client, path: str) -> str | None:
    text = _ssh(client, "if test -s %s; then sha256sum %s; fi" % (path, path))
    match = re.search(r"\b([0-9a-f]{64})\b", text)
    return match.group(1) if match else None


def collect_design(client, design_id: str, row: dict) -> dict:
    spec = design_specs()[design_id]
    root = remote_root()
    run_id = row["run_id"]
    netlist_id = row["netlist_run_id"]
    post = "%s/outputs/%s/%s" % (root, netlist_id, spec["post_v"])
    sdf = "%s/outputs/%s/%s" % (root, netlist_id, spec["sdf"])
    dc_log = "%s/logs/dc/%s.log" % (root, run_id)
    dc_text = _ssh(client, "cat %s %s.err 2>/dev/null | tail -n 80" % (dc_log, dc_log))
    dc_ok = spec["dc_pass"] in dc_text or bool(row.get("skip_dc"))
    if row.get("skip_dc"):
        dc_ok = True
    elif spec["dc_pass"] not in _ssh(client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)):
        dc_ok = False
    sdf_cases = {}
    all_pass = dc_ok
    class_of = {
        case_stem(prefix, design_id, spec["top_lanes"]): cls_name
        for cls_name, prefix, _load, _kind in CLASSES
    }
    for stem in row["cases"]:
        cls_name = class_of.get(stem, stem)
        run_log, annotate = fetch_gls_snippet(client, run_id, stem)
        jid = (row.get("sdf_jobs") or {}).get(stem)
        entry, passed = parse_gls(run_log, annotate, jid)
        entry["case"] = stem
        sdf_cases[cls_name] = entry
        if not passed:
            all_pass = False
            print("GLS_FAIL", design_id, cls_name, entry.get("result_line") or entry.get("first_failure"), flush=True)
        else:
            print("GLS_PASS", design_id, cls_name, flush=True)
    retry = row.get("retry_r0p20") or {}
    if retry.get("stem") and retry.get("run_id"):
        stem = retry["stem"]
        rrun = retry["run_id"]
        run_log, annotate = fetch_gls_snippet(client, rrun, stem)
        jid = (retry.get("sdf_jobs") or {}).get(stem)
        entry, passed = parse_gls(run_log, annotate, jid)
        entry["case"] = stem
        entry["retried_load"] = 0.20
        sdf_cases["near-sat-r0p30"] = dict(sdf_cases.get("near-sat") or {})
        sdf_cases["near-sat"] = entry
        print("GLS_RETRY", design_id, "PASS" if passed else "FAIL", entry.get("result_line"), flush=True)
    all_pass = dc_ok
    for cls_name, _prefix, _load, _kind in CLASSES:
        entry = sdf_cases.get(cls_name) or {}
        class_ok = (
            entry.get("tb_pass")
            and entry.get("annotation_done")
            and entry.get("annotation_errors") == 0
            and entry.get("timing_violation_count") == 0
            and not entry.get("hard_timeout")
            and not entry.get("x_failure")
            and not entry.get("ifnsdfa")
        )
        if not class_ok:
            all_pass = False
    netlist_hash = remote_hash(client, post)
    sdf_hash = remote_hash(client, sdf)
    if not netlist_hash or not sdf_hash:
        all_pass = False
    status = "pass" if all_pass else "fail"
    local_dir = RESULT_ROOT / run_id
    local_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "design_id": design_id,
        "run_id": run_id,
        "netlist_run_id": netlist_id,
        "status": status,
        "dc_ok": dc_ok,
        "netlist_hash": netlist_hash,
        "sdf_hash": sdf_hash,
        "sdf_cases": sdf_cases,
        "dc_tail": dc_text[-4000:],
    }
    write_json(local_dir / "gate_b_collect.json", payload)
    return payload


def write_manifest(collected: dict, row: dict) -> Path:
    design_id = collected["design_id"]
    design = load_design(design_id)
    case_hashes = {}
    for stem in row["cases"]:
        path = CASE_DIR / ("%s.case" % stem)
        if path.is_file():
            case_hashes[stem] = sha256_file(path)
    status = collected["status"]
    sdf_cases = collected["sdf_cases"]
    all_classes = all(
        (sdf_cases.get(name) or {}).get("tb_pass")
        and (sdf_cases.get(name) or {}).get("annotation_done")
        and (sdf_cases.get(name) or {}).get("annotation_errors") == 0
        and (sdf_cases.get(name) or {}).get("timing_violation_count") == 0
        for name, _prefix, _load, _kind in CLASSES
    )
    if status == "pass" and not all_classes:
        status = "fail"
    if not collected.get("netlist_hash") or not collected.get("sdf_hash"):
        status = "fail"
    manifest = new_manifest(
        run_id=collected["run_id"],
        status=status,
        design_id=design_id,
        benchmark_id=None,
        seed=CALIBRATION_SEED,
        adapter="network_sdf",
        config_hash=config_hash_of(design),
        case_hash=None,
        netlist_hash=collected.get("netlist_hash"),
        sdf_hash=collected.get("sdf_hash"),
        frozen_structure_ok=True,
        paper_eligible=False,
        physical_class="post-synthesis",
        archive_only_reason=None,
        remote_root=remote_root(),
        lsf_jobs=[jid for jid in [row.get("dc_job"), *list((row.get("sdf_jobs") or {}).values())] if jid],
        env={
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_NOC64_ALLOW_V3": "1",
            "CMR_MESH64_ALLOW_V3": "1",
            "CMR_DES_BSUB_EXTRA": default_bsub_extra(),
            "GATE_B_SMOKE": "1",
            "NETLIST_RUN_ID": collected["netlist_run_id"],
        },
        artifacts={
            "summary_json": row.get("summary"),
            "netlist_run_id": collected["netlist_run_id"],
            "skip_dc": bool(row.get("skip_dc")),
            "sdf_cases": sdf_cases,
            "case_hashes": case_hashes,
            "traffic": "KEY-64 directed + TOPO-UR smoke zero/0.10/0.30 seed 900001 5-flit",
            "paper_matrix_allowed": False,
        },
        notes=(
            "V3.1.0 Gate B whole-network MAXIMUM-SDF smoke (seed 900001, 5-flit). "
            "Not paper 11k. paper_eligible=false. Do not use DES Tmax as a substitute."
        ),
        command=[
            "python",
            "scripts/asic_dc/cmr/launch_gate_b_async64.py",
            "--design",
            design_id,
        ],
    )
    path = save_manifest(manifest)
    upsert_run(manifest)
    print("MANIFEST", path, status, flush=True)
    return path


def register_plan(state: dict) -> None:
    plan = load_json(PLAN_PATH)
    existing = {row.get("run_id") for row in plan.get("runs") or []}
    for design_id, row in state.get("designs", {}).items():
        run_id = row.get("run_id")
        if not run_id or run_id in existing:
            continue
        plan["runs"].append(
            {
                "run_id": run_id,
                "design_id": design_id,
                "benchmark_id": None,
                "adapter": "network_sdf",
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Gate B async 64-node whole-network MAXIMUM-SDF smoke. Not paper numbers.",
                "env": {
                    "CMR_V31_GATE": "B",
                    "CMR_DESCAL": "1",
                    "CMR_DESCAL_SUBMIT_ONLY": "1",
                },
            }
        )
        existing.add(run_id)
    write_json(PLAN_PATH, plan)
    validate_file(PLAN_PATH)


def check_gate_b() -> int:
    checker = SCRIPTS / "check_v31_gates.py"
    completed = subprocess.run(
        [sys.executable, str(checker), "--gate", "B"],
        cwd=str(REPO),
        check=False,
    )
    print("CHECK_GATE_B rc", completed.returncode, flush=True)
    return completed.returncode


def maybe_retry_r0p20(client, design_id: str, row: dict, collected: dict) -> dict | None:
    del client
    if row.get("retry_r0p20"):
        return None
    near = (collected.get("sdf_cases") or {}).get("near-sat") or {}
    if not near.get("hard_timeout"):
        return None
    spec = design_specs()[design_id]
    retry_stem = case_stem(RETRY_NEAR_SAT[1], design_id, spec["top_lanes"])
    retry_path = CASE_DIR / ("%s.case" % retry_stem)
    if not retry_path.is_file():
        print("RETRY_SKIP missing", retry_path, flush=True)
        return None
    print("RETRY_NEAR_SAT 0.20", design_id, retry_stem, flush=True)
    env = build_env(
        design_id,
        spec,
        row["base_id"] + "_r0p20",
        row["netlist_run_id"],
        [retry_stem],
    )
    env["CMR_DESCAL_SUBMIT_ONLY"] = "1"
    completed = subprocess.run(
        [sys.executable, str(spec["script"])],
        cwd=str(REPO),
        env=env,
        check=False,
    )
    retry_run = profile_run_id(row["base_id"] + "_r0p20", spec["profile"])
    summary_path = RESULT_ROOT / retry_run / "summary.json"
    summary = load_json(summary_path) if summary_path.is_file() else {}
    if spec["runner"] == "noc64" and summary.get("profiles"):
        summary = summary["profiles"][0]
    return {
        "launch_rc": completed.returncode,
        "run_id": summary.get("run_id") or retry_run,
        "stem": retry_stem,
        "sdf_jobs": {
            name: (entry or {}).get("job_id")
            for name, entry in (summary.get("sdf_cases") or {}).items()
        },
    }


def poll_fetch(args: argparse.Namespace) -> int:
    if not args.state.is_file():
        raise SystemExit("missing state %s (submit first)" % args.state)
    state = load_json(args.state)
    deadline = time.time() + args.timeout_hours * 3600
    pending = {
        design_id: row
        for design_id, row in state["designs"].items()
        if row.get("status") == "submitted"
    }
    finished: dict[str, dict] = {}
    while pending and time.time() < deadline:
        client = connect()
        try:
            snapshot = _ssh(
                client,
                "echo BJOBS; bjobs -u ghy19 -noheader -o 'jobid stat name exec_host' 2>/dev/null | "
                "grep -E 'cmr_descal' || true",
            )
            print(snapshot, flush=True)
            done = []
            for design_id, row in list(pending.items()):
                job_ids = [row.get("dc_job"), *list((row.get("sdf_jobs") or {}).values())]
                states = job_states(client, [jid for jid in job_ids if jid])
                active = [jid for jid, st in states.items() if st in ("PEND", "RUN", "PSUSP", "USUSP", "SSUSP")]
                exited = [jid for jid, st in states.items() if st in ("EXIT", "ZOMBI", "UNKWN")]
                print("POLL", design_id, "active", active, "exited", exited, flush=True)
                if active:
                    continue
                collected = collect_design(client, design_id, row)
                retry_jobs = maybe_retry_r0p20(client, design_id, row, collected)
                if retry_jobs:
                    row["retry_r0p20"] = retry_jobs
                    row.setdefault("sdf_jobs", {}).update(retry_jobs.get("sdf_jobs") or {})
                    print("RETRY_QUEUED", design_id, retry_jobs, flush=True)
                    continue
                finished[design_id] = collected
                row["status"] = collected["status"]
                row["collected"] = str(RESULT_ROOT / row["run_id"] / "gate_b_collect.json")
                write_manifest(collected, row)
                done.append(design_id)
                if collected["status"] != "pass":
                    print("DESIGN_FAIL keep evidence, do not fill with DES Tmax:", design_id, flush=True)
            for design_id in done:
                pending.pop(design_id, None)
        finally:
            client.close()
        write_json(args.state, state)
        if pending:
            time.sleep(max(30, args.poll_seconds))
    if pending:
        print("POLL_TIMEOUT still running:", ",".join(pending), flush=True)
        write_json(args.state, state)
        return 2
    register_plan(state)
    write_json(args.state, state)
    return check_gate_b()


def main() -> int:
    args = parse_args()
    if not (args.probe or args.emit_cases or args.submit or args.poll_fetch or args.all):
        args.all = True
    probe_info = None
    if args.all or args.emit_cases:
        emit_cases()
    if args.all or args.probe:
        probe_info = probe(designs=selected_designs(args))
        os.environ["CMR_DES_BSUB_EXTRA"] = probe_info["bsub_extra"]
        args.state.parent.mkdir(parents=True, exist_ok=True)
        write_json(args.state.parent / "probe.json", probe_info)
    if args.all or args.submit:
        if probe_info is None and (args.state.parent / "probe.json").is_file():
            probe_info = load_json(args.state.parent / "probe.json")
        submit_designs(args, probe_info)
    if args.all or args.poll_fetch:
        return poll_fetch(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
