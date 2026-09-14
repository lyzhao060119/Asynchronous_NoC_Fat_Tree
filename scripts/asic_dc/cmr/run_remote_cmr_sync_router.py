#!/usr/bin/env python3
"""Isolated SyncCmrRouter: emit -> DC (1.0 ns) -> leave MAXIMUM-SDF to hop_ppa."""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from cmr_frozen_run_ids import FROZEN_SYNC64_CLOCK_NS, refuse_overwrite
from cmr_primitive_geometries import lookup
from run_remote_cmr_flow import (
    atomic_put,
    atomic_put_bytes,
    fetch_tree,
    job_id,
    remote_run,
    wait_job,
)
from run_remote_cmr_noc16_sdf import connect


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
KIND = os.environ.get("CMR_HOP_KIND", "sync_thin_1x1")
GEOM = lookup(KIND)
if GEOM["async"]:
    raise SystemExit("run_remote_cmr_sync_router.py is for Sync primitives, got %s" % KIND)
RUN_ID = os.environ.get(
    "CMR_SYNC_ROUTER_RUN_ID",
    os.environ.get("CMR_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_" + KIND),
)
CLOCK_NS = os.environ.get("CMR_SYNC64_CLOCK_PERIOD_NS", str(FROZEN_SYNC64_CLOCK_NS))
LOCAL_RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def emit_local() -> Path:
    entry = REPO / GEOM["emit_relpath"] / "SyncCmrRouter.v"
    if os.environ.get("CMR_SKIP_EMIT", "0") != "1":
        sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
        subprocess.run(
            [
                sbt,
                " ".join(
                    [
                        "runMain",
                        "Router_Architecture.sync_cmr.SyncCmrRouterMain",
                        str(GEOM["level"]),
                        str(GEOM["child"]),
                        str(GEOM["parent"]),
                    ]
                ),
            ],
            cwd=REPO,
            check=True,
        )
    if not entry.is_file():
        raise SystemExit("missing emitted %s" % entry)
    subprocess.run(
        [
            sys.executable,
            str(REPO / "scripts" / "asic_dc" / "cmr" / "check_cmr_router_geometry.py"),
            "--sync",
            "--sync-root",
            str(REPO / "generated_sync_cmr"),
        ],
        cwd=REPO,
        check=True,
    )
    return entry


def main() -> None:
    refuse_overwrite(RUN_ID, action="dc")
    entry = emit_local()
    client = connect()
    sftp = client.open_sftp()
    try:
        remote_run(
            client,
            "mkdir -p %s %s %s %s %s %s %s"
            % (
                shlex.quote(ROOT + "/rtl/runs/" + RUN_ID),
                shlex.quote(ROOT + "/scripts/dc"),
                shlex.quote(ROOT + "/sim/tb/hop_binds"),
                shlex.quote(ROOT + "/outputs"),
                shlex.quote(ROOT + "/reports/dc/" + RUN_ID),
                shlex.quote(ROOT + "/logs/dc"),
                shlex.quote(ROOT + "/results/" + RUN_ID),
            ),
        )
        files = {
            entry: "rtl/runs/%s/SyncCmrRouter.v" % RUN_ID,
            REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
            REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
            REPO / "scripts/asic_dc/cmr/sync_cmr_noc64.sdc": "rtl/sync_cmr_noc64.sdc",
            REPO / "scripts/asic_dc/cmr/run_dc_cmr_sync_router.tcl":
                "scripts/dc/run_dc_cmr_sync_router.tcl",
            REPO / "scripts/asic_dc/cmr/tb_sync_cmr_router_hop_ppa.sv":
                "sim/tb/tb_sync_cmr_router_hop_ppa.sv",
            REPO / "scripts/asic_dc/cmr/run_gls_cmr_sync_router_hop_ppa.sh":
                "scripts/run_gls_cmr_sync_router_hop_ppa.sh",
        }
        bind_dir = REPO / "scripts" / "asic_dc" / "cmr" / "hop_binds"
        for vi in sorted(bind_dir.glob("sync_ports_*.vi")):
            files[vi] = "sim/tb/hop_binds/" + vi.name
        missing = [str(path) for path in files if not path.is_file()]
        if missing:
            raise SystemExit("Missing sync router inputs: " + ", ".join(missing))
        for source, destination in files.items():
            print("UPLOAD", destination, flush=True)
            atomic_put(client, sftp, source, ROOT + "/" + destination)
        remote_run(
            client,
            "chmod +x %s"
            % shlex.quote(ROOT + "/scripts/run_gls_cmr_sync_router_hop_ppa.sh"),
        )
        wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
        log = ROOT + "/logs/dc/" + RUN_ID + ".log"
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "module load syn 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_SYNC_ROUTER_RUN_ID=%s "
            "CMR_EXPECTED_PORTS=%d CMR_EXPECTED_SELECTORS=%d "
            "CMR_SYNC64_CLOCK_PERIOD_NS=%s CMR_DUT_V=%s\n"
            "cd %s\ndc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_sync_router.tcl\n"
            % (
                ROOT,
                shlex.quote(RUN_ID),
                GEOM["ports"],
                GEOM["selectors"],
                shlex.quote(str(CLOCK_NS)),
                shlex.quote(ROOT + "/rtl/runs/" + RUN_ID + "/SyncCmrRouter.v"),
                ROOT,
                ROOT,
            )
        )
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        remote_run(client, "chmod +x %s" % wrapper)
        submit = remote_run(
            client,
            "bsub -n 8 -o %s -e %s.err -J cmr_sync_dc_%s %s"
            % (log, log, RUN_ID, wrapper),
        )
        jid = job_id(submit)
        print("DC_JOB", jid, flush=True)
        wait_job(client, jid, "sync_dc")
        text = remote_run(client, "cat %s %s.err 2>/dev/null" % (log, log))
        if "CMR_DC_PASS" not in text:
            print(text[-12000:], flush=True)
            raise RuntimeError("Sync router DC failed")
        summary = {
            "run_id": RUN_ID,
            "kind": KIND,
            "clock_ns": float(CLOCK_NS),
            "dc_job": jid,
            "ports": GEOM["ports"],
            "selectors": GEOM["selectors"],
            "physical_class": "post-synthesis",
        }
        LOCAL_RESULT.mkdir(parents=True, exist_ok=True)
        for remote_path, local_name in (
            (ROOT + "/outputs/" + RUN_ID, "outputs"),
            (ROOT + "/reports/dc/" + RUN_ID, "reports_dc"),
        ):
            try:
                fetch_tree(sftp, remote_path, LOCAL_RESULT / local_name)
            except IOError:
                pass
        (LOCAL_RESULT / "summary.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8"
        )
        print("CMR_SYNC_ROUTER_DC_PASS", RUN_ID, KIND, flush=True)
    finally:
        sftp.close()
        client.close()


if __name__ == "__main__":
    main()
