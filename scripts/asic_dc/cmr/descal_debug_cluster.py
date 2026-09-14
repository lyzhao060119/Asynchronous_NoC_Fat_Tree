#!/usr/bin/env python3
"""Fetch DATE V3 descal GLS/RTL logs from the cluster (read-only)."""
from __future__ import annotations

import sys
from pathlib import Path

from run_remote_cmr_fat_tree_noc16_sdf import connect, fetch_tree, reconnect, remote_run_retry

REPO = Path(__file__).resolve().parents[3]
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
OUT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / "descal_debug_fetch"


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "ls"
    client = connect()
    OUT.mkdir(parents=True, exist_ok=True)
    if cmd == "ls":
        client, text = remote_run_retry(
            client,
            "ls -1dt %s/logs/gls/*descal* %s/logs/gls/*mesh64* %s/logs/gls/*noc256* "
            "2>/dev/null | head -n 40; echo '---RESULTS---'; "
            "ls -1dt %s/results/*descal* %s/results/*noc256* %s/results/*mesh64* "
            "2>/dev/null | head -n 40; echo '---BJOBS---'; "
            "bjobs -u ghy19 -noheader -o 'jobid stat name' 2>/dev/null | "
            "grep -E 'cmr_descal|cmr_mesh64|cmr_noc256' || true"
            % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT),
        )
        print(text)
        (OUT / "remote_ls.txt").write_text(text, encoding="utf-8")
        client.close()
        return 0
    remote = sys.argv[2]
    local = Path(sys.argv[3]) if len(sys.argv) > 3 else OUT / Path(remote).name
    local.parent.mkdir(parents=True, exist_ok=True)
    sftp = client.open_sftp()
    try:
        if remote.endswith(".log") or remote.endswith(".csv") or remote.endswith(".json") or remote.endswith(".txt"):
            sftp.get(remote, str(local))
            print("GOT", remote, "->", local)
        else:
            fetch_tree(sftp, remote, local)
            print("GOT_TREE", remote, "->", local)
    except IOError as exc:
        print("FETCH_FAIL", remote, exc)
        sftp.close()
        client.close()
        return 1
    sftp.close()
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
