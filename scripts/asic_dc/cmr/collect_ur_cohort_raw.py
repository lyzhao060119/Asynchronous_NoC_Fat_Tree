#!/usr/bin/env python3
"""Hash-verified collection of missing near-lossless UR full-drain raw files."""
from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
ACCEPT = REPO / "DATE paper/experiments/raw/paper64/compact64_20260915_112900/ur_acceptance.csv"
LOCAL_RAW = REPO / "DATE paper/experiments/raw/paper64/20260913_asap_uc_m5_200_mesh64_pfat64/raw"
FILES = ("latency.csv", "flit_latency.csv", "events.csv", "run.log", "input_hashes.log")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def already_local(row: dict[str, str]) -> bool:
    case = row["case"]
    base = LOCAL_RAW / row["design"] / "sdf" / case
    return all((base / name).is_file() and (base / name).stat().st_size > 0
               for name in ("latency.csv", "flit_latency.csv", "events.csv"))


def remote_hashes(client, paths: list[str]) -> dict[str, str]:
    command = "sha256sum " + " ".join("'" + p + "'" for p in paths)
    _, stdout, stderr = client.exec_command(command)
    lines = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    found = dict(re.findall(r"(?m)^([0-9a-f]{64})\s+(\S+)$", lines))
    if len(found) != len(paths):
        raise RuntimeError(f"remote hash failure: {err[-1000:]} {lines[-1000:]}")
    return {path: sha for sha, path in found.items()}


def main() -> int:
    with ACCEPT.open(newline="", encoding="utf-8") as handle:
        eligible = [r for r in csv.DictReader(handle) if r["near_lossless"] == "True"]
    missing = [r for r in eligible if not already_local(r) and r["design"] != "PFAT64"]
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    final = REPO / "DATE paper/experiments/raw/paper64" / f"ur_cohort_raw_{stamp}"
    staging = final.with_name(final.name + ".staging")
    staging.mkdir(parents=True, exist_ok=False)
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    records: list[dict[str, str | int]] = []
    try:
        sftp = client.open_sftp()
        for index, row in enumerate(missing, 1):
            case = row["case"]
            base = f"{ROOT}/logs/gls/{row['gls_run_id']}/sdf/{case}"
            paths = [f"{base}/{name}" for name in FILES]
            hashes = remote_hashes(client, paths)
            for remote, name in zip(paths, FILES):
                size = sftp.stat(remote).st_size
                if size <= 0:
                    raise RuntimeError("empty remote artifact: " + remote)
                local = staging / row["design"] / case / name
                local.parent.mkdir(parents=True, exist_ok=True)
                sftp.get(remote, str(local))
                if local.stat().st_size != size or digest(local) != hashes[remote]:
                    raise RuntimeError("download hash/size mismatch: " + remote)
                records.append({"design": row["design"], "load": row["load_setpoint_mflit_per_port_s"],
                                "case": case, "remote": remote, "bytes": size, "sha256": hashes[remote]})
            sdf_remote = f"{base}/sdf_annotate.log"
            sdf_size = sftp.stat(sdf_remote).st_size
            with sftp.file(sdf_remote, "rb") as handle:
                handle.seek(max(0, sdf_size - 2048))
                tail = handle.read().decode(errors="replace")
            if not re.search(r"Total errors:\s*0", tail):
                raise RuntimeError("SDF marker absent: " + case)
            run_log = (staging / row["design"] / case / "run.log").read_text(errors="replace")
            if "TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0" not in run_log:
                raise RuntimeError("full-drain TB marker absent: " + case)
            print(f"UR_RAW_COLLECT_OK {index}/{len(missing)} {row['design']} M{row['load_setpoint_mflit_per_port_s']}", flush=True)
        sftp.close()
        with (staging / "hashes.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(records[0]) if records else
                                    ["design", "load", "case", "remote", "bytes", "sha256"])
            writer.writeheader(); writer.writerows(records)
        (staging / "manifest.json").write_text(json.dumps({
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "remote_preserved": True, "collected_points": len(missing),
            "existing_local_points": len(eligible) - len(missing), "files": len(records),
        }, indent=2) + "\n", encoding="utf-8")
        staging.replace(final)
        print(f"UR_RAW_COLLECT_PASS points={len(missing)} archive={final}")
    except Exception:
        print(f"UR_RAW_COLLECT_FAIL staging_preserved={staging}", file=sys.stderr)
        raise
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
