#!/usr/bin/env python3
"""Read-only, hash-verified collection of the frozen Sync PROP_temp64 B8 DC run."""
from __future__ import annotations

import hashlib
import json
import os
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN_ID = "20260915_231600_sync_prop_temp64_b8_dc"
REPO = HERE.parents[3]
DEST_ROOT = REPO / "DATE paper" / "experiments" / "raw" / "paper64"

FILES = (
    f"outputs/{RUN_ID}/SyncNoC_64nodes.ddc",
    f"outputs/{RUN_ID}/SyncNoC_64nodes_post.v",
    f"outputs/{RUN_ID}/SyncNoC_64nodes.sdf",
    f"outputs/{RUN_ID}/SyncNoC_64nodes.sdc",
    f"reports/dc/{RUN_ID}/check_design_post.rpt",
    f"reports/dc/{RUN_ID}/cmr_sync_noc64_structure.rpt",
    f"reports/dc/{RUN_ID}/qor.rpt",
    f"reports/dc/{RUN_ID}/timing_max.rpt",
    f"reports/dc/{RUN_ID}/timing_min.rpt",
    f"reports/dc/{RUN_ID}/clock.rpt",
    f"reports/dc/{RUN_ID}/post_hashes.sha256",
    f"logs/dc/{RUN_ID}.log",
    f"logs/dc/{RUN_ID}.log.err",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dest = DEST_ROOT / f"sync_prop_temp64_b8_dc_{stamp}"
    staging = dest.with_name(dest.name + ".staging")
    staging.mkdir(parents=True, exist_ok=False)
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    manifest: dict[str, object] = {"run_id": RUN_ID, "files": {}}
    try:
        sftp = client.open_sftp()
        for rel in FILES:
            remote = f"{ROOT}/{rel}"
            local = staging / rel
            local.parent.mkdir(parents=True, exist_ok=True)
            with sftp.file(remote, "rb") as handle:
                data = handle.read()
            if not data:
                raise RuntimeError(f"empty remote artifact: {remote}")
            local.write_bytes(data)
            digest = sha256_bytes(data)
            if sha256_bytes(local.read_bytes()) != digest:
                raise RuntimeError(f"local hash mismatch: {rel}")
            manifest["files"][rel] = {"bytes": len(data), "sha256": digest}
            print(f"SYNC_B8_DC_COLLECT_OK bytes={len(data)} sha256={digest} file={rel}")
        dc_log = (staging / f"logs/dc/{RUN_ID}.log").read_text(errors="replace")
        if "CMR_SYNC64_DC_PASS" not in dc_log:
            raise RuntimeError("missing CMR_SYNC64_DC_PASS")
        if "CMR_SYNC64_DC_FAIL" in dc_log:
            raise RuntimeError("DC failure marker present")
        if "INFO: GTECH cell count after compile = 0" not in dc_log:
            raise RuntimeError("missing GTECH-clean marker")
        manifest["acceptance"] = "DC_PASS"
        (staging / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        staging.replace(dest)
        print(f"SYNC_B8_DC_COLLECT_PASS archive={dest}")
    except Exception:
        print(f"SYNC_B8_DC_COLLECT_FAIL staging={staging}", file=sys.stderr)
        raise
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
