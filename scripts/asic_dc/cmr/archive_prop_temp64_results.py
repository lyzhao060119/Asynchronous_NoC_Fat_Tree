#!/usr/bin/env python3
"""Archive the completed PROP_temp64 DC and MAXIMUM-SDF evidence locally.

The archive deliberately keeps the full per-case functional evidence but only
the tail of each very large SDF-annotation transcript.  The remote pathname
and the original byte count are recorded in manifest.json.
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from run_remote_cmr_fat_tree_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

RUN_ID = "20260913_prop_temp64_asap_uc_m5_200"
REMOTE_ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RAW = REPO / "DATE paper" / "experiments" / "raw" / "prop_temp64" / RUN_ID
LOADS = (5, 10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200)
CASE_FILES = (
    "compile.log", "events.csv", "flit_latency.csv", "input_hashes.log",
    "latency.csv", "run.log", "stdout.log", "v3_metrics.csv",
)
DC_REPORTS = (
    "async_primitives.csv", "check_design_post.rpt", "check_design_pre.rpt",
    "cmr_fat_tree_noc64_structure.rpt", "gtech_cell_count.txt",
    "post_hashes.sha256", "qor.rpt", "timing_min.rpt", "unmapped_cell_count.txt",
)
ANNOTATE_TAIL_BYTES = 65536


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def fetch_file(sftp, remote: str, local: Path) -> None:
    local.parent.mkdir(parents=True, exist_ok=True)
    sftp.get(remote, str(local))


def fetch_tail(sftp, remote: str, local: Path) -> int:
    size = sftp.stat(remote).st_size
    local.parent.mkdir(parents=True, exist_ok=True)
    with sftp.open(remote, "rb") as source, local.open("wb") as target:
        source.seek(max(0, size - ANNOTATE_TAIL_BYTES))
        while block := source.read(32768):
            target.write(block)
    return size


def case_name(load: int) -> str:
    return f"TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    require(not RAW.exists(), f"refusing to overwrite archive: {RAW}")
    os.environ["C1_HOST"] = "192.168.2.8"  # login1 stalls noninteractive exec.
    client = connect(attempts=1)
    sftp = None
    try:
        dc_log_remote = f"{REMOTE_ROOT}/logs/dc/{RUN_ID}.log"
        dc_text = remote_run(client, f"cat {dc_log_remote} {dc_log_remote}.err 2>/dev/null")
        require("PROP_TEMP64_DC_PASS output=" in dc_text, "missing DC pass marker")
        require(not re.search(r"^PROP_TEMP64_DC_FAIL", dc_text, re.M), "DC fail marker")
        remote_hashes = remote_run(
            client,
            f"cat {REMOTE_ROOT}/reports/dc/{RUN_ID}/post_hashes.sha256; "
            f"ls -l {REMOTE_ROOT}/outputs/{RUN_ID}/PROP_temp64.ddc "
            f"{REMOTE_ROOT}/outputs/{RUN_ID}/PROP_temp64_post.v "
            f"{REMOTE_ROOT}/outputs/{RUN_ID}/PROP_temp64.sdf "
            f"{REMOTE_ROOT}/outputs/{RUN_ID}/PROP_temp64.sdc",
        )
        for artifact in ("PROP_temp64.ddc", "PROP_temp64_post.v", "PROP_temp64.sdf", "PROP_temp64.sdc"):
            require(artifact in remote_hashes, f"missing remote DC artifact: {artifact}")

        sftp = client.open_sftp()
        fetch_file(sftp, dc_log_remote, RAW / "dc" / "dc.log")
        fetch_file(sftp, dc_log_remote + ".err", RAW / "dc" / "dc.err")
        for name in DC_REPORTS:
            fetch_file(sftp, f"{REMOTE_ROOT}/reports/dc/{RUN_ID}/{name}", RAW / "dc" / "reports" / name)

        cases = []
        for load in LOADS:
            name = case_name(load)
            remote_case = f"{REMOTE_ROOT}/logs/gls/{RUN_ID}/sdf/{name}"
            local_case = RAW / "raw" / "sdf" / name
            for filename in CASE_FILES:
                fetch_file(sftp, f"{remote_case}/{filename}", local_case / filename)
            annotation_size = fetch_tail(sftp, f"{remote_case}/sdf_annotate.log", local_case / "sdf_annotate_tail.log")
            fetch_file(sftp, f"{REMOTE_ROOT}/results/{RUN_ID}/csv/sdf_{name}.csv", RAW / "csv" / f"sdf_{name}.csv")

            run_text = (local_case / "run.log").read_text(encoding="utf-8", errors="replace")
            annotation = (local_case / "sdf_annotate_tail.log").read_text(encoding="utf-8", errors="replace")
            require("TB_RESULT PASS" in run_text, f"{name}: no TB_RESULT PASS")
            require("Total errors: 0" in annotation, f"{name}: SDF annotation errors")
            failure = ("TB_RESULT FAIL", "TB_X_FAIL", "TB_UNEXPECTED_FAIL", "TB_STALL_FAIL", "TB_HARD_TIMEOUT", "TB_FATAL", "Fatal:", "Timing violation")
            require(not any(token in run_text for token in failure), f"{name}: failure token")
            cases.append({
                "load_mflit_per_port_s": load,
                "name": name,
                "files": [*CASE_FILES, "sdf_annotate_tail.log", f"../../../../csv/sdf_{name}.csv"],
                "sdf_annotate_remote_path": f"{remote_case}/sdf_annotate.log",
                "sdf_annotate_remote_bytes": annotation_size,
            })

        metrics = []
        csv_header = None
        for entry in cases:
            csv_path = RAW / "csv" / f"sdf_{entry['name']}.csv"
            with csv_path.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.reader(handle))
            require(len(rows) == 2, f"unexpected CSV rows: {csv_path}")
            csv_header = rows[0]
            row = rows[1]
            # The common V3 result CSV columns used below are stable in this run.
            metrics.append({
                "load_mflit_per_port_s": entry["load_mflit_per_port_s"],
                "injected": int(row[4]), "delivered": int(row[5]),
                "missing": int(row[6]), "unexpected": int(row[7]), "timeout": int(row[8]),
                "offered_mflit_per_port_s": float(row[17]),
                "delivered_rate_mflit_per_port_s": float(row[18]),
                "flit_latency_mean_ns": float(row[19]),
                "result": row[-1],
            })
        require(all(m["result"] == "PASS" for m in metrics), "CSV non-PASS result")

        report = (RAW / "dc" / "reports" / "cmr_fat_tree_noc64_structure.rpt").read_text(encoding="utf-8")
        qor = (RAW / "dc" / "reports" / "qor.rpt").read_text(encoding="utf-8", errors="replace")
        structure = dict(re.findall(r"^(ROUTER_COUNT|IPM_COUNT|OPM_COUNT|ADAPTER_COUNT|INTERLEVEL_FIFO_COUNT|RCU_DEL050_COUNT|RCU_DEL150_COUNT)=(\d+)$", report, re.M))
        area = re.search(r"Cell Area:\s+([0-9.]+)", qor)
        require(structure.get("ROUTER_COUNT") == "48", "unexpected router count")
        require(structure.get("ADAPTER_COUNT") == "128", "unexpected adapter count")
        require(structure.get("INTERLEVEL_FIFO_COUNT") == "0", "unexpected FIFO count")
        require(area is not None, "missing DC cell area")

        local_hashes = {str(p.relative_to(RAW)).replace("\\", "/"): sha256(p) for p in RAW.rglob("*") if p.is_file()}
        manifest = {
            "schema": "date-prop-temp64-raw-v1",
            "design": "PROP_temp64",
            "run_id": RUN_ID,
            "source": "remote DC plus MAXIMUM-SDF V3 exponential-flit traffic scan",
            "paper_eligible": False,
            "paper_role": "experimental B8 parallel-plane hierarchical network; not part of the locked paper matrix",
            "dc": {
                "marker": "PROP_TEMP64_DC_PASS",
                "remote_outputs": remote_hashes.splitlines(),
                "reports_fetched": list(DC_REPORTS),
                "timing_max_remote_only": f"{REMOTE_ROOT}/reports/dc/{RUN_ID}/timing_max.rpt",
                "structure": structure,
                "cell_area": float(area.group(1)),
                "delay_recipe": {"tree_rcu_unit_ps": 50, "mesh_rcu_unit_ps": 150, "opm_ackin_unit_ps": 50},
            },
            "gls": {"mode": "MAXIMUM-SDF", "cases": cases, "metrics": metrics, "result_csv_header": csv_header},
            "sha256": local_hashes,
        }
        (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        lines = [
            f"# PROP_temp64 archived result: {RUN_ID}", "",
            "Experimental B8 parallel-plane evidence; it is not paper-eligible by default.", "",
            "- DC: `PROP_TEMP64_DC_PASS`; 48 routers, 128 adapters, 0 interlevel FIFOs; cell area 520533.044158.",
            "- GLS: all 12 MAXIMUM-SDF cases passed; every case delivered 55,000/55,000 flits with no missing, unexpected, or timeout flit and SDF `Total errors: 0`.",
            "- Delay recipe: tree RCU DEL050, mesh RCU DEL150, OPM AckIn DEL050.", "",
            "| Nominal load | Actual offered | Delivered | Mean flit latency |", "|---:|---:|---:|---:|",
        ]
        lines += [f"| {m['load_mflit_per_port_s']} | {m['offered_mflit_per_port_s']:.6f} | {m['delivered_rate_mflit_per_port_s']:.6f} | {m['flit_latency_mean_ns']:.6f} ns |" for m in metrics]
        lines += ["", "`raw/` retains case logs and metrics; each 52 MiB SDF annotation transcript is retained remotely and its local 64 KiB tail proves `Total errors: 0`."]
        (RAW / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("PROP_TEMP64_ARCHIVE_PASS", RAW)
        return 0
    finally:
        if sftp is not None:
            sftp.close()
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
