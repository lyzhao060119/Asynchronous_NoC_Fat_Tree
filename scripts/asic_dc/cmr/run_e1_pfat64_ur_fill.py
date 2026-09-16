#!/usr/bin/env python3
"""E1 PFAT64 UR fill: materialize cases, upload, SKIP_DC GLS on frozen netlist.

Fills the 18 missing loads (220..800) so PFAT64 can join the PROP_temp64 /
FlatMesh64 30-point ASAP TOPO-UR grid. Does not re-synthesize.

Stages:
  materialize   local case generation only
  upload        SHA-gated upload of fill cases (+ optional full 30)
  submit        SKIP_DC GLS for missing loads only
  status        remote job / result probe
  all           materialize -> upload -> submit
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
# cmr -> asic_dc -> scripts -> repository; parents[2] is the workspace.
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from _tmp_paper64_common import (  # noqa: E402
    LOADS,
    base_env,
    connect_failover,
    remote_run_failover,
)
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry  # noqa: E402

# Default is the deleted historical ID; override with --netlist after a new DC PASS.
DEFAULT_NETLIST = "20260912_195012_cmr_pfat64_rpsdel050_1248"
FROZEN_NETLIST = os.environ.get("CMR_PFAT64_NETLIST_RUN_ID", DEFAULT_NETLIST)
EXISTING_LOADS = (5, 10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200)
FILL_LOADS = tuple(load for load in LOADS if load not in EXISTING_LOADS)
SEED = 202701
DESIGN = "PFAT64"
TOP = 8
BUNDLE = HERE / "generated_cases" / "20260915_pfat64_asap_m5_800_202701"
CASE_DIR = BUNDLE / "cases"
STATE_DIR = HERE / "results" / "e1_pfat64_ur_fill"
ARCHIVE_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper64"
REMOTE_ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')


def case_name(load: int) -> str:
    return "TOPO-UR_n64_s%d_m%d_%s_top%d" % (SEED, load, DESIGN, TOP)


def checked_id(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        raise SystemExit("unsafe run ID")
    if "dc" in value.lower() and "gls" not in value.lower() and "fill" not in value.lower():
        # Prefer explicit gls/fill tags; still allow caller-provided stamps.
        pass
    return value


def git_evidence() -> tuple[str, bool]:
    root = REPO
    if not (root / ".git").exists():
        for parent in Path(__file__).resolve().parents:
            if (parent / ".git").exists():
                root = parent
                break
    try:
        commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True
        ).strip()
        dirty = bool(
            subprocess.check_output(
                ["git", "status", "--short"], cwd=root, text=True, errors="replace"
            ).strip()
        )
    except subprocess.CalledProcessError:
        return "unknown", True
    return commit, dirty


def materialize() -> None:
    script = HERE / "gen_pfat64_ur_cases.py"
    subprocess.check_call([sys.executable, str(script)], cwd=str(HERE))
    missing = [case_name(load) for load in FILL_LOADS if not (CASE_DIR / (case_name(load) + ".case")).is_file()]
    if missing:
        raise SystemExit("materialize incomplete: " + ",".join(missing[:6]))


def upload_cases(client, loads: tuple[int, ...]) -> dict[str, str]:
    sftp = client.open_sftp()
    hashes = {}
    try:
        for load in loads:
            name = case_name(load)
            local = CASE_DIR / (name + ".case")
            if not local.is_file():
                raise SystemExit("missing local case %s" % local)
            dest = "sim/cases_noc64/" + name + ".case"
            print("UPLOAD", dest, flush=True)
            client, sftp, digest = atomic_put_retry(client, sftp, local, dest)
            hashes[name] = digest
        model = BUNDLE / "INJECTION_MODEL.json"
        if model.is_file():
            client, sftp, digest = atomic_put_retry(
                client, sftp, model, "sim/cases_noc64/INJECTION_MODEL_PFAT64_FILL.json"
            )
            hashes["INJECTION_MODEL_PFAT64_FILL.json"] = digest
    finally:
        sftp.close()
    return hashes


def submit_gls(client, run_id: str, loads: tuple[int, ...], netlist: str) -> dict:
    names = [case_name(load) for load in loads]
    joined = ",".join(names)
    client, probe = remote_run_failover(
        client,
        "if [ -s {root}/outputs/{nid}/NoC_64nodes_post.v ] && "
        "[ -s {root}/outputs/{nid}/NoC_64nodes.sdf ]; "
        "then echo NETLIST_OK; else echo NETLIST_MISSING; "
        "ls -1 {root}/outputs 2>/dev/null | grep -i pfat | head -n 20; fi".format(
            root=REMOTE_ROOT, nid=netlist
        ),
    )
    if "NETLIST_OK" not in probe:
        raise RuntimeError("frozen PFAT64 netlist missing: %s" % probe)

    env = base_env()
    env.update(
        {
            "CMR_FAT_LANE_PROFILE": "1248",
            "CMR_Q64_PROFILE": "1248",
            "CMR_NOC64_RUN_ID": run_id,
            "CMR_NOC64_NETLIST_RUN_ID": netlist,
            "CMR_NOC64_CASES": joined,
            "CMR_NOC64_FUNC_CASES": joined,
            "CMR_NOC64_SKIP_GLS": "0",
            "CMR_NOC64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
        }
    )
    script = HERE / "run_remote_cmr_noc64_sdf.py"
    print(
        "LAUNCH_PFAT64_FILL",
        "run",
        run_id,
        "netlist",
        netlist,
        "cases",
        len(names),
        flush=True,
    )
    completed = subprocess.run(
        [sys.executable, str(script)], cwd=str(REPO), env=env, check=False
    )
    commit, dirty = git_evidence()
    state = {
        "schema": "date2027-e1-pfat64-ur-fill-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "frozen_netlist": netlist,
        "loads": list(loads),
        "cases": names,
        "commit": commit,
        "dirty": dirty,
        "returncode": completed.returncode,
        "remote_root": REMOTE_ROOT,
        "note": "SKIP_DC GLS only; no re-synthesis",
    }
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / ("state_%s.json" % run_id)).write_text(
        json.dumps(state, indent=2) + "\n", encoding="utf-8"
    )
    if completed.returncode != 0:
        raise RuntimeError("PFAT64 fill GLS submit failed rc=%s" % completed.returncode)
    return state


def status(client, run_id: str) -> None:
    client, out = remote_run_failover(
        client,
        "printf 'JOBS '; bjobs -a -J 'cmr_noc64*' 2>/dev/null | head -n 30 || true; "
        "printf 'LOG '; ls -lh %s/logs/gls/%s* 2>/dev/null | head -n 20 || true; "
        "printf 'CSV '; find %s/results -maxdepth 3 -name '*PFAT64*' 2>/dev/null | head -n 20 || true; "
        "printf 'SDF '; ls %s/logs/gls/%s/sdf 2>/dev/null | head -n 30 || true"
        % (REMOTE_ROOT, run_id, REMOTE_ROOT, REMOTE_ROOT, run_id),
    )
    print(out, flush=True)


COLLECT_FILES = (
    "result.csv",
    "run.log",
    "sdf_annotate.log",
    "latency.csv",
    "flit_latency.csv",
    "events.csv",
    "input_hashes.log",
    "v3_metrics.csv",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validate_collected_case(case_dir: Path, load: int) -> dict[str, object]:
    name = case_name(load)
    run_text = (case_dir / "run.log").read_text(encoding="utf-8", errors="replace")
    sdf_text = (case_dir / "sdf_annotate.log").read_text(encoding="utf-8", errors="replace")
    with (case_dir / "result.csv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise RuntimeError(f"{name}: expected exactly one result row, got {len(rows)}")
    row = rows[0]
    required_pass = (
        "TB_RESULT PASS injected=55000 delivered=55000 "
        "missing=0 unexpected=0 timeout=0"
    )
    errors = []
    if required_pass not in run_text:
        errors.append("missing full-drain TB_RESULT")
    if row.get("pass_fail") != "PASS":
        errors.append(f"pass_fail={row.get('pass_fail')}")
    for field, expected in (
        ("injected_flits", "55000"),
        ("delivered_flits", "55000"),
        ("missing_expected_flits", "0"),
        ("unexpected_flits", "0"),
        ("timeout_hit", "0"),
    ):
        if row.get(field) != expected:
            errors.append(f"{field}={row.get(field)}")
    if "Total errors: 0" not in sdf_text:
        errors.append("SDF Total errors: 0 missing")
    if re.search(r"(?:TB_RESULT FAIL|\$fatal|\bFatal:|\bERROR:)", run_text, re.I):
        errors.append("failure marker in run.log")
    if errors:
        raise RuntimeError(f"{name}: " + "; ".join(errors))
    return {
        "load": load,
        "case": name,
        "pass": True,
        "injected": 55000,
        "delivered": 55000,
        "measurement_offered": int(row["measurement_offered_flits"]),
        "measurement_delivered": int(row["measurement_delivered_flits"]),
        "measurement_backlog": int(float(row["measurement_backlog_flits"])),
        "sdf_total_errors": 0,
    }


def collect(client, run_id: str, output: Path | None = None) -> Path:
    """Download and hash-verify the immutable 18-point PFAT fill evidence."""
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    final = output or (ARCHIVE_ROOT / f"pfat64_ur_fill_{stamp}")
    final = final.resolve()
    staging = final.with_name(final.name + ".staging")
    if final.exists() or staging.exists():
        raise RuntimeError(f"refusing to overwrite collection: {final}")
    staging.mkdir(parents=True)
    remote_base = f"{REMOTE_ROOT}/logs/gls/{run_id}/sdf"
    manifest_lines = []
    for load in FILL_LOADS:
        name = case_name(load)
        for filename in COLLECT_FILES:
            remote = f"{remote_base}/{name}/{filename}"
            manifest_lines.append(remote)
    # Obtain size and SHA from the remote source before downloading. Quoted
    # explicit paths avoid a broad find and make a missing artifact fatal.
    quoted = " ".join(shlex.quote(path) for path in manifest_lines)
    command = (
        "set -e; for f in " + quoted + "; do "
        "test -s \"$f\"; s=$(wc -c < \"$f\"); h=$(sha256sum \"$f\" | awk '{print $1}'); "
        "printf '%s\\t%s\\t%s\\n' \"$h\" \"$s\" \"$f\"; done"
    )
    client, out = remote_run_failover(client, command)
    remote_meta: dict[str, tuple[str, int]] = {}
    for line in out.splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3 and re.fullmatch(r"[0-9a-f]{64}", parts[0]):
            remote_meta[parts[2]] = (parts[0], int(parts[1]))
    if len(remote_meta) != len(manifest_lines):
        shutil.rmtree(staging)
        raise RuntimeError(
            f"remote manifest incomplete: {len(remote_meta)}/{len(manifest_lines)}"
        )

    sftp = client.open_sftp()
    hash_rows = []
    try:
        for index, remote in enumerate(manifest_lines, 1):
            rel = Path(remote).relative_to(Path(remote_base))
            local = staging / "cases" / rel
            local.parent.mkdir(parents=True, exist_ok=True)
            expected_hash, expected_size = remote_meta[remote]
            print(f"COLLECT {index}/{len(manifest_lines)} {rel.as_posix()}", flush=True)
            sftp.get(remote, str(local))
            actual_size = local.stat().st_size
            actual_hash = sha256_file(local)
            if actual_size != expected_size or actual_hash != expected_hash:
                raise RuntimeError(
                    f"download verification failed {rel}: "
                    f"size {actual_size}/{expected_size}, sha {actual_hash}/{expected_hash}"
                )
            hash_rows.append(
                {
                    "relative_path": (Path("cases") / rel).as_posix(),
                    "remote_path": remote,
                    "size_bytes": actual_size,
                    "sha256": actual_hash,
                }
            )
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    finally:
        sftp.close()

    acceptance = [
        _validate_collected_case(staging / "cases" / case_name(load), load)
        for load in FILL_LOADS
    ]
    with (staging / "acceptance.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(acceptance[0]))
        writer.writeheader()
        writer.writerows(acceptance)
    with (staging / "hashes.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(hash_rows[0]))
        writer.writeheader()
        writer.writerows(hash_rows)
    commit, dirty = git_evidence()
    manifest = {
        "schema": "date2027-e1-pfat64-ur-fill-collection-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "remote_root": REMOTE_ROOT,
        "loads": list(FILL_LOADS),
        "case_count": len(acceptance),
        "artifact_count": len(hash_rows),
        "all_full_drain_pass": True,
        "all_sdf_total_errors_zero": True,
        "commit": commit,
        "dirty": dirty,
        "remote_preserved": True,
    }
    (staging / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    staging.rename(final)
    print(f"PFAT64_COLLECT_PASS cases={len(acceptance)} artifacts={len(hash_rows)} {final}", flush=True)
    return final


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "stage",
        choices=("materialize", "upload", "submit", "status", "collect", "finalize", "all"),
    )
    parser.add_argument(
        "--run-id",
        default="",
        help="GLS run id; default stamp_cmr_pfat64_asap_uc_m220_800",
    )
    parser.add_argument(
        "--all-loads",
        action="store_true",
        help="upload/submit full 30-point grid instead of fill-only",
    )
    parser.add_argument(
        "--netlist",
        default=FROZEN_NETLIST,
        help="SKIP_DC netlist run id (after new PFAT64 DC PASS)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="new local collection/finalize directory (must not already exist)",
    )
    args = parser.parse_args()
    loads = LOADS if args.all_loads else FILL_LOADS
    netlist = args.netlist
    run_id = checked_id(
        args.run_id
        or (datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_pfat64_asap_uc_m220_800")
    )

    if args.stage in ("materialize", "all"):
        materialize()
        if args.stage == "materialize":
            return 0

    if args.stage == "finalize":
        finalizer = HERE / "finalize_e1_ur_three_dut.py"
        command = [sys.executable, str(finalizer)]
        if args.output:
            command += ["--pfat-fill-archive", str(args.output)]
        return subprocess.run(command, cwd=str(REPO), check=False).returncode

    client = connect_failover()
    try:
        if args.stage in ("upload", "all"):
            hashes = upload_cases(client, loads)
            print("UPLOAD_OK cases=%d" % (len(hashes) - (1 if "INJECTION_MODEL_PFAT64_FILL.json" in hashes else 0)), flush=True)
            (STATE_DIR).mkdir(parents=True, exist_ok=True)
            (STATE_DIR / ("upload_%s.json" % run_id)).write_text(
                json.dumps({"run_id": run_id, "hashes": hashes, "loads": list(loads), "netlist": netlist}, indent=2)
                + "\n",
                encoding="utf-8",
            )
        if args.stage in ("submit", "all"):
            submit_gls(client, run_id, loads, netlist)
            print("SUBMIT_RECORDED", run_id, "netlist", netlist, flush=True)
        if args.stage == "status":
            status(client, run_id)
        if args.stage == "collect":
            collect(client, run_id, args.output)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
