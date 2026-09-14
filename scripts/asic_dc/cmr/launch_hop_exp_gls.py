#!/usr/bin/env python3
"""MAXIMUM-SDF hop rate-scan: exponential packet-start injection.

Override netlist with CMR_HOP_NET_ID (default: await-ack C1P2).
Does not overwrite frozen hop directories.
"""
from __future__ import annotations

import os
import re
import shlex
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_remote_cmr_fat_tree_noc16_sdf import (  # noqa: E402
    connect,
    remote_run_retry,
    wait_job,
)
from run_remote_cmr_flow import (  # noqa: E402
    atomic_put_bytes_retry,
    atomic_put_retry,
    fetch_tree,
    job_id,
)

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
TB_LOCAL = HERE / "tb_cmr_router_rate_scan.sv"
BATCH = datetime.now().strftime("%Y%m%d_%H%M%S") + "_hop_serial_exp_m100"
HOP_NET = os.environ.get("CMR_HOP_NET_ID", "20260910_c1p2_awaitack_del150_dc")
HOP_GEOM = os.environ.get("CMR_HOP_GEOM", "C1_P2")
HOP_TRAFFIC = tuple(
    part.strip()
    for part in os.environ.get("CMR_HOP_TRAFFIC", "UC,F4").split(",")
    if part.strip()
)
JOBS = tuple((HOP_NET, HOP_GEOM, traffic) for traffic in HOP_TRAFFIC)
RATE = 100

WRAPPER = r"""#!/bin/bash
set -euo pipefail
ROOT=%(root)s
RUN=%(run)s
NET=%(net)s
RATE=%(rate)d
TRAFFIC=%(traffic)s
BIND=%(bind)s
GEOM_DEFINE=%(geom_define)s
LOG="$ROOT/logs/router_rate/$RUN"
WORK="$ROOT/sim/work/router_rate/$RUN"
mkdir -p "$LOG"
rm -rf -- "$WORK"
mkdir -p "$WORK"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
cp "$ROOT/sim/tb/tb_cmr_router_rate_scan.sv" "$WORK/tb_cmr_router_rate_scan.sv"
cp "$ROOT/sim/tb/$BIND" "$WORK/"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial begin
\$sdf_annotate("$ROOT/outputs/$NET/CMRRouter.sdf", tb_cmr_router_rate_scan.dut, , "sdf_annotate.log", "MAXIMUM", ,);
\$display("PPA_INFO SDF_MAX net=$NET rate=$RATE traffic=$TRAFFIC geom=$BIND inject=exponential_packet_start"); end endmodule
EOF
printf "%%s\n" "$LIB" "$ROOT/outputs/$NET/CMRRouter_post.v" "$WORK/tb_cmr_router_rate_scan.sv" "$WORK/sdf_boot.sv" > "$WORK/filelist.f"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier +incdir+$WORK $GEOM_DEFINE -f filelist.f -top tb_cmr_router_rate_scan -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv +RATE_MFLIT=$RATE +TRAFFIC=$TRAFFIC -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp "$WORK/sdf_annotate.log" "$LOG/" 2>/dev/null || true
printf "SIM_RC=%%s\n" "$rc" >> "$LOG/run.log"
exit "$rc"
"""


def bsub_extra() -> str:
    extra = os.environ.get("CMR_DES_BSUB_EXTRA", "").strip()
    if extra:
        return extra
    return '-m "node21 node26 node24 node18"'


def submit_one(client, net: str, geom: str, traffic: str):
    run = "%s_%s_%s_m%d" % (BATCH, geom.lower(), traffic.lower(), RATE)
    bind = "async_ports_%s.vi" % geom.lower()
    body = WRAPPER % {
        "root": ROOT,
        "run": run,
        "net": net,
        "rate": RATE,
        "traffic": traffic,
        "bind": bind,
        "geom_define": "+define+GEOM_%s" % geom,
    }
    client, _ = remote_run_retry(
        client,
        "mkdir -p %s %s"
        % (
            shlex.quote(ROOT + "/logs/router_rate/" + run),
            shlex.quote(ROOT + "/sim/work/router_rate"),
        ),
    )
    wrapper = ROOT + "/logs/router_rate/%s/run_sdf.sh" % run
    sftp = client.open_sftp()
    try:
        client, sftp, _ = atomic_put_bytes_retry(
            client, sftp, body.encode(), wrapper
        )
    finally:
        try:
            sftp.close()
        except Exception:
            pass
    client, _ = remote_run_retry(client, "chmod +x %s" % shlex.quote(wrapper))
    submit = (
        "bsub -n 8 %s -oo %s -eo %s -J %s %s"
        % (
            bsub_extra(),
            shlex.quote(ROOT + "/logs/router_rate/%s/lsf.out" % run),
            shlex.quote(ROOT + "/logs/router_rate/%s/lsf.err" % run),
            shlex.quote(run[:60]),
            shlex.quote(wrapper),
        )
    )
    client, response = remote_run_retry(client, submit)
    print(response, flush=True)
    jid = job_id(response)
    print("JOB_SUBMIT", run, jid, net, geom, traffic, flush=True)
    return client, run, jid


def harvest(client, run: str) -> str:
    log = shlex.quote(ROOT + "/logs/router_rate/%s/run.log" % run)
    grep = (
        "echo RUN=%s; grep -E 'TB_RESULT|TB_RATE|TB_INFO inject|TB_GAP |TB_FLIT |TB_FIRST|PPA_INFO|SIM_RC=' %s 2>/dev/null | head -n 60"
        % (run, log)
    )
    client, summary = remote_run_retry(client, grep)
    print(summary, flush=True)
    local = HERE / "results" / BATCH / run
    sftp = client.open_sftp()
    try:
        fetch_tree(sftp, ROOT + "/logs/router_rate/" + run, local)
    finally:
        sftp.close()
    return summary


def main() -> int:
    if not TB_LOCAL.is_file():
        raise SystemExit("missing hop rate-scan TB")
    client = connect()
    try:
        for net, geom, _traffic in JOBS:
            bind = HERE / "hop_binds" / ("async_ports_%s.vi" % geom.lower())
            if not bind.is_file():
                raise SystemExit("missing bind " + str(bind))
            client, check = remote_run_retry(
                client,
                "test -s %s && test -s %s && echo NET_OK"
                % (
                    shlex.quote("%s/outputs/%s/CMRRouter_post.v" % (ROOT, net)),
                    shlex.quote("%s/outputs/%s/CMRRouter.sdf" % (ROOT, net)),
                ),
            )
            if "NET_OK" not in check:
                raise SystemExit("missing hop netlist %s" % net)
        client, _ = remote_run_retry(client, "mkdir -p %s" % shlex.quote(ROOT + "/sim/tb"))
        sftp = client.open_sftp()
        try:
            client, sftp, tb_hash = atomic_put_retry(
                client, sftp, TB_LOCAL, ROOT + "/sim/tb/tb_cmr_router_rate_scan.sv"
            )
            uploaded = set()
            for _net, geom, _traffic in JOBS:
                bind_name = "async_ports_%s.vi" % geom.lower()
                if bind_name in uploaded:
                    continue
                client, sftp, _ = atomic_put_retry(
                    client,
                    sftp,
                    HERE / "hop_binds" / bind_name,
                    ROOT + "/sim/tb/" + bind_name,
                )
                uploaded.add(bind_name)
        finally:
            try:
                sftp.close()
            except Exception:
                pass
        print("UPLOAD_TB", tb_hash, "BATCH", BATCH, flush=True)
        jobs = []
        for net, geom, traffic in JOBS:
            client, run, jid = submit_one(client, net, geom, traffic)
            jobs.append((run, jid))
        failed = 0
        for run, jid in jobs:
            try:
                client = wait_job(client, jid, run, allow_exit=True)
            except RuntimeError as exc:
                print("JOB_ENDED", run, exc, flush=True)
            summary = harvest(client, run)
            if not re.search(r"TB_RESULT PASS", summary or ""):
                failed += 1
        print("HOP_EXP_DONE", BATCH, "failed", failed, "/", len(jobs), flush=True)
        return 0 if failed == 0 else 1
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
