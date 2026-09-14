#!/usr/bin/env python3
"""Sweep asynchronous sink Ack delay on frozen thin and fat-tree NoC16 SDF."""
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_fat_tree_noc16_sdf import connect, wait_job


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get(
    "CMR_SWEEP_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_rx_capture_sweep",
)
CASE_NAME = os.environ.get("CMR_SWEEP_CASE", "noc16_00_to_33_3flit_sdf")
DELAYS_NS = tuple(float(v) for v in os.environ.get(
    "CMR_SWEEP_DELAYS_NS", "0.05,1,2,5,10"
).split(","))
NETLISTS = {
    "thin": os.environ.get(
        "CMR_SWEEP_THIN_NETLIST", "20260820_cmr_rcu_1xdel250_noc16_sdf"
    ),
    "fat": os.environ.get(
        "CMR_SWEEP_FAT_NETLIST", "20260821_cmr_ft_pathclear_tab_p50_sdf_01"
    ),
}
SELECTED_GEOMETRIES = tuple(v.strip() for v in os.environ.get(
    "CMR_SWEEP_GEOMETRIES", "thin,fat"
).split(",") if v.strip())
PHASE_PROBE = os.environ.get("CMR_SWEEP_PHASE_PROBE", "0") == "1"
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def delay_tag(value):
    return ("%g" % value).replace(".", "p")


def main():
    client = connect()
    remote_run(client, "mkdir -p %s/sim/tb %s/scripts %s/logs/gls/%s %s/results/%s/csv" % (
        ROOT, ROOT, ROOT, RUN_ID, ROOT, RUN_ID
    ))
    remote_run(client,
        "cp %s/sim/tb/async_noc16_port_adapter.sv %s/sim/tb/; "
        "cp %s/sim/tb/tb_noc16_async_boundary.sv "
        "%s/sim/tb/tb_noc16_async_boundary.ultra_reference.sv" %
        (ULTRA, ROOT, ULTRA, ROOT)
    )
    local_files = {
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh":
            ROOT + "/scripts/run_gls_cmr_noc16.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv":
            ROOT + "/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv":
            ROOT + "/sim/tb/tb_noc16_async_boundary.sv",
    }
    if PHASE_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_phase_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_fat_tree_phase_probe.sv"
    sftp = client.open_sftp()
    for source, destination in local_files.items():
        atomic_put(client, sftp, source, destination)
    sftp.close()
    remote_run(client, "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_noc16.sh; "
                       "chmod +x %s/scripts/run_gls_cmr_noc16.sh" % (ROOT, ROOT))

    case_file = ULTRA + "/sim/cases/" + CASE_NAME + ".case"
    check = remote_run(client, "test -s %s && sha256sum %s" %
                       (shlex.quote(case_file), shlex.quote(case_file)))
    case_hash = re.search(r"\b[0-9a-f]{64}\b", check).group(0)

    jobs = {}
    for geometry in SELECTED_GEOMETRIES:
        if geometry not in NETLISTS:
            raise ValueError("unsupported CMR_SWEEP_GEOMETRIES entry: " + geometry)
        netlist_run = NETLISTS[geometry]
        probe = remote_run(client,
            "test -s %s/outputs/%s/NoC_16nodes_post.v && "
            "test -s %s/outputs/%s/NoC_16nodes.sdf && echo OK" %
            (ROOT, netlist_run, ROOT, netlist_run))
        if "OK" not in probe:
            raise RuntimeError("missing frozen netlist " + netlist_run)
        for delay in DELAYS_NS:
            tag = "%s_rx%s" % (geometry, delay_tag(delay))
            wrapper = ROOT + "/logs/gls/%s/%s.sh" % (RUN_ID, tag)
            body = (
                "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
                "CMR_NOC16_NETLIST_RUN_ID=%s CMR_NOC16_CASE_NAME=%s "
                "CMR_NOC16_CASE_FILE=%s CMR_NOC16_RX_CAPTURE_NS=%s\n"
                "exec bash %s/scripts/run_gls_cmr_noc16.sh\n" %
                (ROOT, RUN_ID, netlist_run, tag, case_file, delay, ROOT)
            )
            if PHASE_PROBE:
                body = body.replace(
                    "\nexec bash", "\nexport CMR_NOC16_PHASE_PROBE=1\nexec bash"
                )
            sftp = client.open_sftp()
            atomic_put_bytes(client, sftp, body.encode(), wrapper)
            sftp.close()
            remote_run(client, "chmod +x " + wrapper)
            submit = remote_run(client,
                "bsub -n 8 -o %s/logs/gls/%s/%s.bsub.log "
                "-e %s/logs/gls/%s/%s.bsub.err -J cmr_rx_%s_%s %s" %
                (ROOT, RUN_ID, tag, ROOT, RUN_ID, tag, RUN_ID, tag, wrapper))
            match = re.search(r"Job <(\d+)>", submit)
            if not match:
                raise RuntimeError("submit failed: " + submit)
            jobs[tag] = {
                "job_id": match.group(1), "geometry": geometry,
                "delay_ns": delay, "netlist_run_id": netlist_run,
            }
            print("SWEEP_JOB", tag, match.group(1), flush=True)

    for tag, entry in jobs.items():
        client = wait_job(client, entry["job_id"], tag, polls=120, allow_exit=True)

    all_rows = []
    for tag, entry in jobs.items():
        base = ROOT + "/logs/gls/%s/sdf/%s" % (RUN_ID, tag)
        run_log = remote_run(client, "cat %s/run.log 2>/dev/null" % base)
        row = dict(entry)
        row.update({
            "tag": tag,
            "pass": "TB_RESULT PASS" in run_log,
            "stall": "TB_STALL_FAIL" in run_log,
            "x_failure": "TB_X_FAIL" in run_log or "TB_PROTOCOL_X" in run_log,
            "unexpected": "TB_UNEXPECTED_FAIL" in run_log,
            "timing_violation_count": run_log.count("Timing violation"),
            "result_line": next((line for line in run_log.splitlines()
                                 if "TB_RESULT " in line or "TB_STALL_FAIL t=" in line
                                 or "TB_X_FAIL" in line or "TB_UNEXPECTED_FAIL" in line), None),
        })
        all_rows.append(row)
        print("SWEEP_RESULT", json.dumps(row, sort_keys=True), flush=True)

    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(json.dumps({
        "run_id": RUN_ID, "case": CASE_NAME, "case_hash": case_hash,
        "rows": all_rows,
    }, indent=2) + "\n", encoding="utf-8")
    sftp = client.open_sftp()
    for tag in jobs:
        remote = ROOT + "/logs/gls/%s/sdf/%s/run.log" % (RUN_ID, tag)
        local = RESULT / (tag + ".run.log")
        try:
            sftp.get(remote, str(local))
        except IOError:
            pass
    sftp.close()
    client.close()
    print("SWEEP_SUMMARY", RESULT / "summary.json", flush=True)


if __name__ == "__main__":
    main()
