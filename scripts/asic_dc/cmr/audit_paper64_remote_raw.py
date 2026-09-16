#!/usr/bin/env python3
"""Read-only SFTP inventory for legacy UR and Static64 raw evidence."""
from __future__ import annotations

import csv
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
ACCEPT = REPO / "DATE paper/experiments/raw/paper64/compact64_20260915_112900/ur_acceptance.csv"
REQUIRED = ("latency.csv", "flit_latency.csv", "events.csv", "run.log", "sdf_annotate.log")


def present(sftp, path: str) -> int:
    try:
        return sftp.stat(path).st_size
    except IOError:
        return 0


def main() -> int:
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client = connect(attempts=2)
    try:
        sftp = client.open_sftp()
        with ACCEPT.open(newline="", encoding="utf-8") as handle:
            rows = [row for row in csv.DictReader(handle) if row["near_lossless"] == "True"]
        for row in rows:
            base = f"{ROOT}/logs/gls/{row['gls_run_id']}/sdf/{row['case']}"
            sizes = {name: present(sftp, f"{base}/{name}") for name in REQUIRED}
            print("RAW_POINT", row["design"], row["load_setpoint_mflit_per_port_s"],
                  row["gls_run_id"], row["case"], sizes, flush=True)
        static = "20260915_162500_prop_temp64_static4_m5_smoke"
        for load in (5, 100, 420, 340, 280, 220, 160):
            case = f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"
            base = f"{ROOT}/logs/gls/{static}/sdf/{case}"
            print("STATIC_POINT", load, base,
                  {name: present(sftp, f"{base}/{name}") for name in REQUIRED}, flush=True)
        sftp.close()
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
