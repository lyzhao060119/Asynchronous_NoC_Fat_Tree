#!/usr/bin/env python3
"""Read-only receipt/status probe for the Static64 selection batch."""
from __future__ import annotations
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

RUN_ID = "20260915_203000_prop_temp64_static4_selection"


def main() -> int:
    os.environ["C1_HOST"] = os.environ.get("C1_HOST", "192.168.2.8")
    client = connect(attempts=1)
    try:
        sftp = client.open_sftp()
        path = f"/tmp/{RUN_ID}.submit.log"
        try:
            with sftp.file(path, "rb") as handle:
                print(handle.read().decode(errors="replace"), end="")
        except IOError as exc:
            print(f"STATIC64_SELECTION_NO_RECEIPT {exc}")
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
