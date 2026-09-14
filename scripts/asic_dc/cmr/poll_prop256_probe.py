#!/usr/bin/env python3
"""Poll PROP256 hop/2pkt jobs and fetch logs."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry, fetch_tree

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STAMP = "20260901_192534"
JOBS = ("11563001", "11563101")
RUNS = (
    STAMP + "_cmr_descal_prop256_hop",
    STAMP + "_cmr_descal_prop256_2pkt",
)
LOCAL = Path(__file__).resolve().parent / "results"


def main() -> int:
    client = connect()
    cmd = (
        "echo BJOBS; bjobs -u ghy19 -noheader -o 'jobid stat exec_host name' "
        "%s %s 2>/dev/null; echo DETAIL; "
        "bjobs -l %s %s 2>/dev/null | grep -E 'Status|Specified Hosts|EXEC_HOST|Exited|Done|Started|Dispatched' | head -n 40"
        % (JOBS[0], JOBS[1], JOBS[0], JOBS[1])
    )
    client, text = remote_run_retry(client, cmd)
    print(text, flush=True)
    done = ("DONE" in text or "EXIT" in text or "Exited" in text) and "RUN" not in text and "PEND" not in text
    # also treat empty bjobs as finished
    if "11563001" not in text and "11563101" not in text:
        done = True
    sftp = client.open_sftp()
    for run in RUNS:
        dest = LOCAL / run / "logs_gls"
        try:
            fetch_tree(sftp, ROOT + "/logs/gls/" + run, dest)
            print("FETCHED", dest, flush=True)
        except IOError as exc:
            print("FETCH_SKIP", run, exc, flush=True)
    sftp.close()
    client.close()
    return 0 if done else 1


if __name__ == "__main__":
    raise SystemExit(main())
