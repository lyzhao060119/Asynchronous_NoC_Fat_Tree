#!/usr/bin/env python3
"""PFAT L3 (4,8) isolated R-U5 path probe: no-SDF then MAXIMUM-SDF.

Does not write curated results and does not require PPA_RESULT PASS.
"""
from __future__ import annotations

import os
import re
import shlex
from pathlib import Path

from run_remote_cmr_flow import (
    ROOT,
    atomic_put,
    job_id,
    remote_run,
    wait_job,
)
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_router_hop_ppa import copy_remote_file


HERE = Path(__file__).resolve().parent
NETLIST = os.environ.get(
    "CMR_PFAT_4X8_NETLIST_RUN_ID", "20260831_cmr_pfat_l3_c4p8_del050_ackin050"
)
LOCAL = HERE / "results" / "20260831_cmr_pfat48_path_probe"


def submit_probe(client, *, no_sdf: bool) -> str:
    tag = "nosdf" if no_sdf else "maxsdf"
    run = "20260831_cmr_pfat48_probe_%s" % tag
    log = "%s/logs/hop_ppa/%s_async_pfat_4x8_isolated/gls" % (ROOT, run)
    command = (
        "mkdir -p {log}; "
        "bsub -n 8 -oo {log}/lsf.log "
        "env CMR_REMOTE_ROOT={root} CMR_RUN_ID={run}_async_pfat_4x8_isolated "
        "CMR_NETLIST_RUN_ID={netlist} CMR_HOP_KIND=async_pfat_4x8 "
        "CMR_HOP_MODE=isolated CMR_HOP_MESH=0 "
        "CMR_RX_CAPTURE_NS=0.1 CMR_ACK_TO_NEXT_REQ_GUARD_NS=0.20 "
        "CMR_HOP_PATH_PROBE=1 CMR_HOP_NO_SDF={nosdf} "
        "bash {root}/scripts/run_gls_cmr_router_hop_ppa.sh"
    ).format(
        log=shlex.quote(log),
        root=shlex.quote(ROOT),
        run=shlex.quote(run),
        netlist=shlex.quote(NETLIST),
        nosdf="1" if no_sdf else "0",
    )
    response = remote_run(client, command)
    jid = job_id(response)
    print("JOB_SUBMIT", tag, jid, flush=True)
    wait_job(client, jid, "pfat48_" + tag)
    return log


def summarize(path: Path, label: str) -> None:
    text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
    print("===== %s %s =====" % (label, path), flush=True)
    if not text:
        print("MISSING_LOG", flush=True)
        return
    keys = (
        "PPA_RESULT",
        "PPA_DEBUG",
        "PPA_FAIL",
        "PFAT48_",
        "PPA_INFO",
        "Error",
        "error",
    )
    for line in text.splitlines():
        if any(key in line for key in keys) and "ModuleCmd" not in line:
            print(line, flush=True)


def main() -> None:
    uploads = [
        (
            HERE / "tb_cmr_router_hop_ppa.sv",
            "%s/sim/tb/tb_cmr_router_hop_ppa.sv" % ROOT,
        ),
        (
            HERE / "tb_cmr_pfat48_path_probe.sv",
            "%s/sim/tb/tb_cmr_pfat48_path_probe.sv" % ROOT,
        ),
        (
            HERE / "run_gls_cmr_router_hop_ppa.sh",
            "%s/scripts/run_gls_cmr_router_hop_ppa.sh" % ROOT,
        ),
    ]
    bind_dir = HERE / "hop_binds"
    client = connect()
    sftp = client.open_sftp()
    try:
        remote_run(client, "mkdir -p %s/sim/tb/hop_binds" % ROOT)
        for local, remote in uploads:
            atomic_put(client, sftp, local, remote)
        for vi in sorted(bind_dir.glob("*.vi")):
            atomic_put(client, sftp, vi, "%s/sim/tb/hop_binds/%s" % (ROOT, vi.name))
        remote_run(
            client,
            "chmod +x %s" % shlex.quote("%s/scripts/run_gls_cmr_router_hop_ppa.sh" % ROOT),
        )
        logs = []
        skip_nosdf = os.environ.get("CMR_PFAT48_SKIP_NOSDF", "0") == "1"
        for no_sdf in ((False,) if skip_nosdf else (True, False)):
            remote_log = submit_probe(client, no_sdf=no_sdf)
            label = "nosdf" if no_sdf else "maxsdf"
            local_dir = LOCAL / label
            local_dir.mkdir(parents=True, exist_ok=True)
            for name in (
                "run.log", "stdout.log", "compile.log", "sdf_annotate.log",
                "hop_events.csv", "lsf.log",
            ):
                try:
                    copy_remote_file(
                        sftp, "%s/%s" % (remote_log, name), local_dir / name
                    )
                except OSError:
                    pass
            summarize(local_dir / "run.log", label)
            logs.append(local_dir / "run.log")
        stuck = []
        for path in logs:
            text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
            match = re.search(r"PFAT48_STUCK.*", text)
            stuck.append(match.group(0) if match else "NO_STUCK_LINE")
        print("PFAT48_PROBE_SUMMARY %s" % " | ".join(stuck), flush=True)
    finally:
        sftp.close()
        client.close()


if __name__ == "__main__":
    main()
