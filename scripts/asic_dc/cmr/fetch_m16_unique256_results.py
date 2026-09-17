#!/usr/bin/env python3
"""Fetch the completed PROP_temp256 M16 unique-identity scan without duplicate SDF logs."""
from __future__ import annotations

import csv
import hashlib
import json
import sys
from datetime import datetime
from pathlib import Path

CMR = Path(__file__).resolve().parent
sys.path.insert(0, str(CMR))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry  # noqa: E402

REPO = Path(__file__).resolve().parents[3]
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
SMOKE = "20260917_prop_temp256_m16_unique_m20_01"
SCAN = "20260917_prop_temp256_m16_unique_scan01"
LOADS = (20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 240, 280, 320, 400, 600)
FILES = ("events.csv", "flit_latency.csv", "latency.csv", "result.csv", "run.log", "stdout.log", "v3_metrics.csv", "input_hashes.log")


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = REPO / "DATE paper" / "experiments" / "raw" / "paper256" / f"prop_temp256_m16_unique_{stamp}"
    staging = out.with_name(out.name + ".staging")
    staging.mkdir(parents=True, exist_ok=False)
    client = connect()
    sftp = client.open_sftp()
    manifest = []
    for load in LOADS:
        run = SMOKE if load == 20 else SCAN
        case = f"TOPO-UR_n256_s202701_m{load}_PROP_temp256_m16_top0"
        remote_base = f"{ROOT}/logs/gls/{run}/sdf/{case}"
        case_out = staging / "cases" / case
        case_out.mkdir(parents=True)
        available = {entry.filename for entry in sftp.listdir_attr(remote_base)}
        missing = sorted(set(FILES) - available)
        manifest.append({"load": load, "run_id": run, "case": case, "file": "__inventory__",
                         "bytes": 0, "sha256": "", "remote": remote_base,
                         "missing_expected_files": ";".join(missing)})
        for name in FILES:
            if name not in available:
                continue
            remote = f"{remote_base}/{name}"
            local = case_out / name
            sftp.get(remote, str(local))
            manifest.append({"load": load, "run_id": run, "case": case, "file": name,
                             "bytes": local.stat().st_size, "sha256": sha(local), "remote": remote,
                             "missing_expected_files": ""})
    # One shared full annotation report establishes the exact SDF gate.
    case20 = "TOPO-UR_n256_s202701_m20_PROP_temp256_m16_top0"
    remote_sdf = f"{ROOT}/logs/gls/{SMOKE}/sdf/{case20}/sdf_annotate.log"
    local_sdf = staging / "shared_sdf_annotate.log"
    sftp.get(remote_sdf, str(local_sdf))
    manifest.append({"load": 20, "run_id": SMOKE, "case": case20, "file": "shared_sdf_annotate.log",
                     "bytes": local_sdf.stat().st_size, "sha256": sha(local_sdf), "remote": remote_sdf,
                     "missing_expected_files": ""})
    sftp.close()
    hashed = [row for row in manifest if row["file"] != "__inventory__"]
    client, remote_hashes = remote_run_retry(client, "sha256sum " + " ".join(row["remote"] for row in hashed))
    client.close()
    remote_by_path = {line.split()[1]: line.split()[0] for line in remote_hashes.splitlines() if len(line.split()) >= 2}
    mismatches = [row["remote"] for row in hashed if remote_by_path.get(row["remote"]) != row["sha256"]]
    if mismatches:
        raise RuntimeError("remote/local hash mismatch: " + ", ".join(mismatches))
    (staging / "manifest.json").write_text(json.dumps({"runs": [SMOKE, SCAN], "loads": LOADS,
        "sdf_policy": "one shared full annotation report; per-case hashes retained", "files": manifest}, indent=2), encoding="utf-8")
    with (staging / "manifest.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(manifest[0]))
        writer.writeheader(); writer.writerows(manifest)
    staging.rename(out)
    print(out)
    print("FETCH_PASS", len(manifest), "files", sum(row["bytes"] for row in manifest), "bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
