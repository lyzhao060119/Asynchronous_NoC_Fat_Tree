#!/usr/bin/env python3
"""Poll the active 256 campaign or pull only small final data products."""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

ROOT = "/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks"
REPO = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("status", "pull"))
    a = parser.parse_args()
    c = connect()
    try:
        if a.action == "status":
            command = f'''bjobs -a 14571601 14571701 14571801 14571901 14572001 14572101 14572201 14572301 14572401
for d in Mesh256 M16_256; do
test ! -s {ROOT}/work/$d/annotation_status.json || cat {ROOT}/work/$d/annotation_status.json
done
find {ROOT}/logs -maxdepth 4 -name metrics.json -print 2>/dev/null | wc -l
for f in {ROOT}/summary/coverage.json {ROOT}/manifests/quarter_saturation.json {ROOT}/manifests/HALT_*.json; do test ! -s "$f" || cat "$f"; done
'''
            print(remote_run(c, command))
            return
        wanted = ["summary/raw_metrics.csv", "summary/three_seed_means.csv", "summary/coverage.json",
                  "manifests/quarter_saturation.json", "manifests/netlist_hashes.sha256",
                  "manifests/library_hashes.sha256", "manifests/source_hashes.sha256",
                  "manifests/grid_jobs_Mesh256.json", "manifests/grid_jobs_M16_256.json",
                  "manifests/repeated_jobs.json", "sdf/Mesh256.sdf.json", "sdf/M16_256.sdf.json",
                  "area/Mesh256/area.csv", "area/M16_256/area.csv"]
        destination = REPO / "results/formal256_20261019_r3_checks"
        sftp = c.open_sftp()
        try:
            for relative in wanted:
                remote = ROOT + "/" + relative
                try:
                    stat = sftp.stat(remote)
                except FileNotFoundError:
                    print("PENDING", relative)
                    continue
                if stat.st_size > 10 * 1024 * 1024:
                    raise RuntimeError("refusing large evidence download: " + relative)
                local = destination / relative
                local.parent.mkdir(parents=True, exist_ok=True)
                sftp.get(remote, str(local))
                print("PULLED", relative, stat.st_size)
        finally:
            sftp.close()
    finally:
        c.close()


if __name__ == "__main__":
    main()
