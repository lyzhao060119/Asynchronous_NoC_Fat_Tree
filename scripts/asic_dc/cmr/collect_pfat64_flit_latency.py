#!/usr/bin/env python3
"""Fetch only the omitted PFAT64 M220-M800 full-drain flit latency files."""
from __future__ import annotations

import csv
import hashlib
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect  # noqa: E402

RUN = "20260915_091759_cmr_pfat64_asap_uc_m220_800_1248"
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
LOADS = tuple(range(220, 501, 20)) + (600, 700, 800)


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    final = REPO / "DATE paper" / "experiments" / "raw" / "paper64" / f"pfat64_flit_latency_{stamp}"
    staging = final.with_name(final.name + ".staging")
    staging.mkdir(parents=True, exist_ok=False)
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    rows = []
    try:
        sftp = client.open_sftp()
        for load in LOADS:
            case = f"TOPO-UR_n64_s202701_m{load}_PFAT64_top8"
            remote = f"{ROOT}/logs/gls/{RUN}/sdf/{case}/flit_latency.csv"
            local = staging / "cases" / case / "flit_latency.csv"
            local.parent.mkdir(parents=True, exist_ok=True)
            command = f"test -s '{remote}' && sha256sum '{remote}' && wc -c < '{remote}'"
            _, stdout, _ = client.exec_command(command)
            evidence = stdout.read().decode(errors="replace")
            match = re.search(r"([0-9a-f]{64})", evidence)
            sizes = re.findall(r"(?m)^(\d+)$", evidence)
            if not match or not sizes:
                raise RuntimeError(f"missing remote evidence for {remote}: {evidence}")
            sftp.get(remote, str(local))
            actual_hash = digest(local)
            actual_size = local.stat().st_size
            if actual_hash != match.group(1) or actual_size != int(sizes[-1]):
                raise RuntimeError(f"hash/size mismatch for {case}")
            rows.append({"load": load, "case": case, "remote_path": remote,
                         "size_bytes": actual_size, "sha256": actual_hash})
            print(f"PFAT64_FLIT_COLLECT {len(rows)}/{len(LOADS)} load={load} size={actual_size}", flush=True)
        sftp.close()
        with (staging / "hashes.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader(); writer.writerows(rows)
        (staging / "MANIFEST.txt").write_text(
            f"run_id={RUN}\ncreated_utc={datetime.now(timezone.utc).isoformat()}\n"
            f"files={len(rows)}\nremote_preserved=true\n", encoding="utf-8")
        staging.rename(final)
        print(f"PFAT64_FLIT_COLLECT_PASS files={len(rows)} archive={final}")
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
