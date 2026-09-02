#!/usr/bin/env python3
"""Pull the existing 64/256 descal CSVs and TB logs used for debug."""
from __future__ import annotations

from pathlib import Path

from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
OUT = Path(__file__).resolve().parent / "results" / "descal_debug_fetch"

JOBS = [
    ("fm256_directed", f"{ROOT}/logs/gls/20260901_120000_cmr_descal_fm256"),
    ("prop256_directed", f"{ROOT}/logs/gls/20260901_120000_cmr_descal_prop256"),
    ("fm64_sdf", f"{ROOT}/logs/gls/20260901_120000_cmr_descal_fm64"),
]


def main() -> int:
    client = connect()
    OUT.mkdir(parents=True, exist_ok=True)
    client, listing = remote_run_retry(
        client,
        "find %s/logs/gls/20260901_120000_cmr_descal_fm256 "
        "%s/logs/gls/20260901_120000_cmr_descal_prop256 "
        "%s/logs/gls/20260901_120000_cmr_descal_fm64 "
        "-type f \\( -name 'latency.csv' -o -name 'events.csv' -o -name 'stdout.log' "
        "-o -name 'run.log' -o -name 'v3_metrics.csv' \\) 2>/dev/null"
        % (ROOT, ROOT, ROOT),
    )
    print(listing)
    (OUT / "file_list.txt").write_text(listing, encoding="utf-8")
    sftp = client.open_sftp()
    for line in listing.splitlines():
        remote = line.strip()
        if not remote:
            continue
        rel = remote.split("/logs/gls/", 1)[-1]
        local = OUT / rel.replace("/", "_")
        local.parent.mkdir(parents=True, exist_ok=True)
        try:
            sftp.get(remote, str(local))
            print("GOT", remote, "->", local.name)
        except IOError as exc:
            print("SKIP", remote, exc)
    sftp.close()
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
