#!/usr/bin/env python3
"""Read-only fetch of the already-completed 202701 Mesh64/PROP_temp64 scan."""
from __future__ import annotations

import csv
import hashlib
import io
import json
from pathlib import Path

from _tmp_paper64_common import LOADS
from run_remote_prop_temp64 import ROOT, connect_failover

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "DATE paper/experiments/raw/paper64/unicast_m5_500_202701"
RUNS = (("FM64", "20260914_000444_cmr_fm64_asap_uc_m5_500", "FM64_top0"),
        ("PROP_temp64", "20260913_prop_temp64_asap_uc_m5_500", "PROP_temp64_top16"))
FIELDS = ("offered", "delivered", "mean_latency", "p95", "p99", "backlog")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    client = connect_failover()
    sftp = client.open_sftp()
    checks = []
    try:
        for design, run, suffix in RUNS:
            rows = []
            dst = OUT / design
            dst.mkdir(exist_ok=True)
            for load in LOADS:
                name = f"TOPO-UR_n64_s202701_m{load}_{suffix}"
                src = f"{ROOT}/results/{run}/csv/sdf_{name}.csv"
                with sftp.open(src, "rb") as handle:
                    data = handle.read()
                row = next(csv.DictReader(io.StringIO(data.decode("utf-8"))))
                assert row["pass_fail"] == "PASS" and all(
                    row[k] in ("0", "0.0") for k in
                    ("missing_expected_flits", "unexpected_flits", "timeout_hit")
                ), (design, load)
                (dst / (name + ".csv")).write_bytes(data)
                checks.append({"design": design, "load": load, "remote_run_id": run,
                               "remote_csv": src, "csv_sha256": hashlib.sha256(data).hexdigest(),
                               "csv_pass": True, "gls_log_reaudited": False})
                rows.append({"load": load, "offered": row["offered_mflit_port_s"],
                             "delivered": row["delivered_mflit_port_s"],
                             "mean_latency": row["flit_lat_mean_ns"],
                             "p95": row["flit_lat_p95_ns"], "p99": row["flit_lat_p99_ns"],
                             "backlog": row["measurement_backlog_flits"]})
            with (OUT / (design + "_summary.csv")).open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=("load",) + FIELDS)
                writer.writeheader()
                writer.writerows(rows)
    finally:
        sftp.close()
        client.close()
    assert len(checks) == 2 * len(LOADS)
    (OUT / "csv_manifest.json").write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
    print("UNICAST_CSV_COMPLETE", len(checks), "rows; GLS logs not reaudited", OUT)


if __name__ == "__main__":
    main()
