#!/usr/bin/env python3
"""Fetch and SHA-256 verify the PROP_temp64 DC deliverables into its raw archive."""
from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from run_remote_cmr_fat_tree_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

RUN_ID = "20260913_prop_temp64_asap_uc_m5_200"
REMOTE_ROOT = "/home/ghy19/Asynchronous_Router_CMR"
ARCHIVE = REPO / "DATE paper" / "experiments" / "raw" / "prop_temp64" / RUN_ID
FILES = ("PROP_temp64.ddc", "PROP_temp64_post.v", "PROP_temp64.sdf", "PROP_temp64.sdc")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    manifest_path = ARCHIVE / "manifest.json"
    if not manifest_path.is_file():
        raise SystemExit("missing performance archive: " + str(manifest_path))
    os.environ["C1_HOST"] = "192.168.2.8"
    client = connect(attempts=1)
    try:
        remote_dir = f"{REMOTE_ROOT}/outputs/{RUN_ID}"
        hashes = remote_run(client, "sha256sum " + " ".join(f"{remote_dir}/{name}" for name in FILES))
        expected = {}
        for line in hashes.splitlines():
            fields = line.split()
            if len(fields) == 2:
                expected[Path(fields[1]).name] = fields[0]
        if set(expected) != set(FILES):
            raise RuntimeError("missing remote SHA-256: " + hashes)
        sftp = client.open_sftp()
        try:
            output_dir = ARCHIVE / "dc" / "outputs"
            output_dir.mkdir(parents=True, exist_ok=True)
            for name in FILES:
                local = output_dir / name
                if local.exists():
                    raise RuntimeError("refusing to overwrite " + str(local))
                sftp.get(f"{remote_dir}/{name}", str(local))
                actual = sha256(local)
                if actual != expected[name]:
                    local.unlink(missing_ok=True)
                    raise RuntimeError(f"SHA-256 mismatch {name}: {actual} != {expected[name]}")
                print("PROP_TEMP64_OUTPUT_OK", name, local.stat().st_size, actual, flush=True)
        finally:
            sftp.close()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        manifest["dc"]["output_sha256"] = expected
        for name in FILES:
            relative = "dc/outputs/" + name
            manifest["sha256"][relative] = expected[name]
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        readme = ARCHIVE / "README.md"
        readme.write_text(readme.read_text(encoding="utf-8-sig").rstrip() + "\n\nDC DDC, post-layout Verilog, SDF, and SDC are retained in `dc/outputs/` and SHA-256 verified against the remote outputs.\n", encoding="utf-8")
        print("PROP_TEMP64_OUTPUT_ARCHIVE_PASS", ARCHIVE)
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
