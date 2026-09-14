#!/usr/bin/env python3
"""Fetch KEY-256 events.csv from the failed 20260901_172855 run."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

REMOTE = (
    "/home/ghy19/Asynchronous_Router_CMR/logs/gls/"
    "20260901_172855_cmr_descal_prop256/rtl/"
    "KEY-256_n256_s900001_zero_PROP256_top0"
)
LOCAL = (
    Path(__file__).resolve().parents[3]
    / "scripts"
    / "asic_dc"
    / "cmr"
    / "results"
    / "20260901_172855_cmr_descal_prop256"
)


def main() -> int:
    LOCAL.mkdir(parents=True, exist_ok=True)
    client = connect()
    client, listing = remote_run_retry(client, "ls -lh %s" % REMOTE)
    print(listing, flush=True)
    sftp = client.open_sftp()
    for name in ("events.csv", "latency.csv", "run.log", "v3_metrics.csv"):
        remote = REMOTE + "/" + name
        dest = LOCAL / name
        try:
            sftp.get(remote, str(dest))
            print("FETCHED", dest, dest.stat().st_size, flush=True)
        except IOError as exc:
            print("MISSING", name, exc, flush=True)
    sftp.close()
    client.close()
    events = LOCAL / "events.csv"
    if not events.is_file():
        return 2
    pkt13_flits = ("8c0cc0d", "0c0cc0d", "4c0cc0d")
    pkt15_head = "8214217"
    pkt15_body = "0214217"
    pkt15_tail = "4214217"
    rx195 = []
    rx37 = []
    tx13 = []
    tx15 = []
    any_rx_15 = []
    with events.open(encoding="utf-8", errors="replace") as handle:
        header = handle.readline()
        print("HEADER", header.strip(), flush=True)
        for line in handle:
            parts = line.strip().split(",")
            if len(parts) < 4:
                continue
            kind, port, pkt, flit = parts[0], parts[1], parts[2], parts[3].lower()
            if kind == "TX" and pkt == "13":
                tx13.append(line.strip())
            if kind == "TX" and pkt == "15":
                tx15.append(line.strip())
            if kind == "RX" and port == "195":
                rx195.append(line.strip())
            if kind == "RX" and port == "37":
                rx37.append(line.strip())
            if kind == "RX" and any(token in flit for token in (pkt15_head, pkt15_body, pkt15_tail)):
                any_rx_15.append(line.strip())
    print("TX13", len(tx13), flush=True)
    for row in tx13:
        print(" ", row, flush=True)
    print("TX15", len(tx15), flush=True)
    for row in tx15:
        print(" ", row, flush=True)
    print("RX195", len(rx195), flush=True)
    for row in rx195:
        print(" ", row, flush=True)
    print("RX37", len(rx37), flush=True)
    for row in rx37:
        print(" ", row, flush=True)
    print("RX_FLIT_PKT15", len(any_rx_15), flush=True)
    for row in any_rx_15:
        print(" ", row, flush=True)
    print(
        "CONFIRM pkt13_flits=%s pkt15_head_on_rx=%s"
        % (pkt13_flits, bool(any_rx_15)),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
