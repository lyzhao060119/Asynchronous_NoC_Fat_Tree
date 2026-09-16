#!/usr/bin/env python3
"""Collect accepted frozen Static64 DC and GLS evidence without modifying remote inputs."""
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
DC_RUN = "20260915_144500_prop_temp64_static4_dc"
GLS_RUN = "20260915_162500_prop_temp64_static4_m5_smoke"
LOADS = (5, 100, 160, 220, 280, 340, 420)
RAW_FILES = ("latency.csv", "flit_latency.csv", "events.csv", "run.log", "input_hashes.log")
DC_FILES = ("PROP_temp64_static4.ddc", "PROP_temp64_static4_post.v",
            "PROP_temp64_static4.sdf", "PROP_temp64_static4.sdc")


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def remote_hashes(client, paths: list[str]) -> dict[str, str]:
    _, stdout, stderr = client.exec_command("sha256sum " + " ".join("'" + p + "'" for p in paths))
    text = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    pairs = re.findall(r"(?m)^([0-9a-f]{64})\s+(\S+)$", text)
    if len(pairs) != len(paths):
        raise RuntimeError(f"remote hash failure: {err[-500:]} {text[-500:]}")
    return {path: digest for digest, path in pairs}


def fetch_group(sftp, client, paths: list[str], root: Path, records: list[dict]) -> None:
    hashes = remote_hashes(client, paths)
    for remote in paths:
        size = sftp.stat(remote).st_size
        if size <= 0:
            raise RuntimeError("empty remote artifact: " + remote)
        local = root / remote.removeprefix(ROOT + "/")
        local.parent.mkdir(parents=True, exist_ok=True)
        sftp.get(remote, str(local))
        if local.stat().st_size != size or sha(local) != hashes[remote]:
            raise RuntimeError("download mismatch: " + remote)
        records.append({"remote": remote, "local": str(local.relative_to(root)),
                        "bytes": size, "sha256": hashes[remote]})


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    final = REPO / "DATE paper/experiments/raw/paper64" / f"static64_final_raw_{stamp}"
    staging = final.with_name(final.name + ".staging")
    staging.mkdir(parents=True, exist_ok=False)
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    records: list[dict] = []
    try:
        sftp = client.open_sftp()
        dc_paths = [f"{ROOT}/outputs/{DC_RUN}/{name}" for name in DC_FILES]
        fetch_group(sftp, client, dc_paths, staging, records)
        log = f"{ROOT}/logs/dc/{DC_RUN}.retry.log"
        if sftp.stat(log).st_size <= 0:
            log = f"{ROOT}/logs/dc/{DC_RUN}.log"
        fetch_group(sftp, client, [log], staging, records)
        dc_text = (staging / log.removeprefix(ROOT + "/")).read_text(errors="replace")
        if "PROP_TEMP64_STATIC4_DC_PASS" not in dc_text:
            raise RuntimeError("missing Static64 DC PASS marker")
        for load in LOADS:
            case = f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"
            base = f"{ROOT}/logs/gls/{GLS_RUN}/sdf/{case}"
            fetch_group(sftp, client, [f"{base}/{name}" for name in RAW_FILES], staging, records)
            sdf = f"{base}/sdf_annotate.log"
            size = sftp.stat(sdf).st_size
            with sftp.file(sdf, "rb") as handle:
                handle.seek(max(0, size - 2048))
                tail = handle.read().decode(errors="replace")
            if not re.search(r"Total errors:\s*0", tail):
                raise RuntimeError("Static SDF marker absent: " + case)
            run_text = (staging / f"logs/gls/{GLS_RUN}/sdf/{case}/run.log").read_text(errors="replace")
            if "TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0" not in run_text:
                raise RuntimeError("Static full-drain marker absent: " + case)
            print(f"STATIC64_RAW_COLLECT_OK load={load}", flush=True)
        sftp.close()
        with (staging / "hashes.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(records[0]))
            writer.writeheader(); writer.writerows(records)
        (staging / "manifest.json").write_text(json.dumps({
            "dc_run_id": DC_RUN, "gls_run_id": GLS_RUN,
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "loads": LOADS, "remote_preserved": True,
        }, indent=2) + "\n", encoding="utf-8")
        staging.replace(final)
        print(f"STATIC64_RAW_COLLECT_PASS archive={final}")
    except Exception:
        print(f"STATIC64_RAW_COLLECT_FAIL staging_preserved={staging}", file=sys.stderr)
        raise
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
