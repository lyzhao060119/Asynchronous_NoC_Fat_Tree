#!/usr/bin/env python3
"""Run the read-only 8004004 fat-tree misroute diagnosis on a frozen SDF."""
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_fat_tree_noc16_sdf import connect, job_id, wait_job

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
NETLIST = os.environ.get("CMR_MISROUTE_NETLIST", "20260821_cmr_ft_mutex_nd2d2_01")
RUN_ID = os.environ.get(
    "CMR_MISROUTE_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_ft_8004004_probe",
)
CASE = "TAB-NET-UR-3f-r0p50"
PREFIX = "TAB-NET-UR-3f-r0p50_prefix_t14"
LOCAL = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def submit(client, case_name, case_file):
    wrapper = ROOT + "/logs/gls/%s/%s.sh" % (RUN_ID, case_name)
    body = """#!/bin/bash
source /etc/profile 2>/dev/null || true
export CMR_REMOTE_ROOT={root}
export CMR_NOC16_RUN_ID={run}
export CMR_NOC16_NETLIST_RUN_ID={net}
export CMR_NOC16_CASE_NAME={case}
export CMR_NOC16_CASE_FILE={case_file}
export CMR_NOC16_RX_CAPTURE_NS=5
export CMR_NOC16_STALL_TIMEOUT_NS=20000
export CMR_NOC16_HARD_TIMEOUT_NS=200000
export CMR_NOC16_UNEXPECTED_PROBE=1
export CMR_NOC16_MISROUTE_PROBE=1
exec bash {root}/scripts/run_gls_cmr_noc16.sh
""".format(root=ROOT, run=RUN_ID, net=NETLIST, case=case_name,
           case_file=case_file)
    sftp = client.open_sftp()
    atomic_put_bytes(client, sftp, body.encode("utf-8"), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + shlex.quote(wrapper))
    text = remote_run(client,
        "bsub -n 8 -o {root}/logs/gls/{run}/{case}.bsub.log "
        "-e {root}/logs/gls/{run}/{case}.bsub.err -J cmr_misroute_{run}_{case} {wrapper}".format(
            root=ROOT, run=RUN_ID, case=case_name, wrapper=shlex.quote(wrapper)))
    return job_id(text)


def main():
    client = connect()
    remote_run(client, "mkdir -p {0}/sim/tb {0}/sim/cases {0}/scripts {0}/logs/gls/{1} {0}/results/{1}/csv".format(ROOT, RUN_ID))
    remote_run(client,
        "cp {u}/sim/tb/async_noc16_port_adapter.sv {r}/sim/tb/; "
        "cp {u}/sim/tb/tb_noc16_async_boundary.sv {r}/sim/tb/tb_noc16_async_boundary.ultra_reference.sv".format(u=ULTRA, r=ROOT))
    files = {
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh": ROOT + "/scripts/run_gls_cmr_noc16.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv": ROOT + "/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_unexpected_probe.sv": ROOT + "/sim/tb/tb_cmr_fat_tree_unexpected_probe.sv",
        REPO / "scripts/asic_dc/cmr/tb_cmr_fat_tree_8004004_probe.sv": ROOT + "/sim/tb/tb_cmr_fat_tree_8004004_probe.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv": ROOT + "/sim/tb/tb_noc16_async_boundary.sv",
    }
    sftp = client.open_sftp()
    for source, destination in files.items():
        atomic_put(client, sftp, source, destination)
    sftp.close()
    remote_run(client, "sed -i 's/\\r$//' {0}/scripts/run_gls_cmr_noc16.sh; chmod +x {0}/scripts/run_gls_cmr_noc16.sh".format(ROOT))
    remote_run(client,
        "test -s {r}/outputs/{n}/NoC_16nodes_post.v && test -s {r}/outputs/{n}/NoC_16nodes.sdf".format(r=ROOT, n=NETLIST))

    source_case = ULTRA + "/sim/cases/" + CASE + ".case"
    prefix_case = ROOT + "/sim/cases/" + PREFIX + ".case"
    # Keep all metadata and comments, inputs through tick 14, and only the
    # matching expected records (expect mask, event-id, tail, flit).
    make_prefix = r'''awk '
      $1 == "input" && $2 <= 14 { keep[$4] = 1 }
      { lines[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          split(lines[i], f, /[ \t]+/)
          if (f[1] == "input") { if (f[2] <= 14) print lines[i] }
          else if (f[1] == "expect") { if (keep[f[3]]) print lines[i] }
          else print lines[i]
        }
      }' __SOURCE_CASE__ > __PREFIX_CASE__'''.replace(
          "__SOURCE_CASE__", shlex.quote(source_case)
      ).replace("__PREFIX_CASE__", shlex.quote(prefix_case))
    remote_run(client, make_prefix)
    prefix_hash = remote_run(client, "sha256sum " + shlex.quote(prefix_case)).split()[0]
    print("PREFIX_CASE", prefix_hash, prefix_case, flush=True)

    runs = ((CASE, source_case), (PREFIX, prefix_case))
    rows = []
    for case_name, case_file in runs:
        jid = submit(client, case_name, case_file)
        print("MISROUTE_JOB", case_name, jid, flush=True)
        client = wait_job(client, jid, case_name, polls=120, allow_exit=True)
        log = ROOT + "/logs/gls/%s/sdf/%s/run.log" % (RUN_ID, case_name)
        text = remote_run(client, "cat " + shlex.quote(log) + " 2>/dev/null")
        rows.append({
            "case": case_name, "job_id": jid,
            "unexpected": "TB_UNEXPECTED_FAIL" in text,
            "pass": "TB_RESULT PASS" in text,
            "first_q": next((x for x in text.splitlines() if x.startswith("TB_UNEX_CLASS")), None),
            "first_probe": next((x for x in text.splitlines() if x.startswith("CMR_8004004_SNAPSHOT")), None),
        })
        LOCAL.mkdir(parents=True, exist_ok=True)
        (LOCAL / (case_name + ".run.log")).write_text(text, encoding="utf-8")
    (LOCAL / "summary.json").write_text(json.dumps({
        "run_id": RUN_ID, "netlist": NETLIST, "prefix_case_sha256": prefix_hash,
        "rows": rows,
    }, indent=2) + "\n", encoding="utf-8")
    client.close()
    print("MISROUTE_SUMMARY", LOCAL / "summary.json", flush=True)


if __name__ == "__main__":
    main()
