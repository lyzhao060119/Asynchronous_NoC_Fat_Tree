#!/usr/bin/env python3
"""Fetch the existing mesh64 DUT Verilog for a new cmr_descal_ DC."""
from __future__ import annotations

from pathlib import Path

from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
REPO = Path(__file__).resolve().parents[3]
LOCAL = REPO / "generated_cmr" / "mesh_noc64_11" / "CMRMeshNoC.v"


def main() -> int:
    LOCAL.parent.mkdir(parents=True, exist_ok=True)
    client = connect()
    client, probe = remote_run_retry(
        client,
        "test -s %s/rtl/mesh64/CMRMeshNoC.v && wc -c %s/rtl/mesh64/CMRMeshNoC.v "
        "&& grep -c 'module OPMSelector' %s/rtl/mesh64/CMRMeshNoC.v "
        "&& grep -c 'module CMRMeshNoC' %s/rtl/mesh64/CMRMeshNoC.v"
        % (ROOT, ROOT, ROOT, ROOT),
    )
    print("REMOTE", probe, flush=True)
    sftp = client.open_sftp()
    print("GET", ROOT + "/rtl/mesh64/CMRMeshNoC.v", "->", LOCAL, flush=True)
    sftp.get(ROOT + "/rtl/mesh64/CMRMeshNoC.v", str(LOCAL))
    sftp.close()
    client.close()
    print("LOCAL_BYTES", LOCAL.stat().st_size, flush=True)
    text = LOCAL.read_text(encoding="utf-8", errors="replace")
    print("HAS_MODULE", "module CMRMeshNoC" in text, flush=True)
    print("OPMSELECTOR_IN_DUT", text.count("module OPMSelector"), flush=True)
    print("BLOCKSET_IN_DUT", "BlockSet" in text, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
