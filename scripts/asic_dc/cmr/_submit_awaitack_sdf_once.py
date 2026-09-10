#!/usr/bin/env python3
"""Upload fixed TB (one SSH session per file) and submit C1P2 awaitack UC+F4 SDF."""
from __future__ import annotations

import hashlib
import os
import re
import shlex
import time
from datetime import datetime
from pathlib import Path

import paramiko

HERE = Path(__file__).resolve().parent
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
TB = HERE / "tb_cmr_router_rate_scan.sv"
BIND = HERE / "hop_binds" / "async_ports_c1_p2.vi"
NET = "20260910_c1p2_awaitack_del150_dc"
BATCH = datetime.now().strftime("%Y%m%d_%H%M%S") + "_hop_awaitack_m100"
TRAFFICS = ("UC", "F4")
RATE = 100
PASS = "ghy19@2608"


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        "192.168.2.8",
        username="ghy19",
        password=PASS,
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
        compress=False,
    )
    t = c.get_transport()
    if t:
        t.set_keepalive(15)
    return c


def run(c, cmd):
    _, o, e = c.exec_command(cmd)
    return (o.read() + e.read()).decode(errors="replace")


def put_one(local: Path, remote: str, attempts=10):
    data = local.read_bytes().replace(b"\r\n", b"\n")
    digest = hashlib.sha256(data).hexdigest()
    last = None
    for i in range(attempts):
        c = None
        try:
            c = connect()
            sftp = c.open_sftp()
            tmp = "%s.upload.%d.%d" % (remote, os.getpid(), i)
            with sftp.file(tmp, "wb") as h:
                h.write(data)
                h.flush()
            try:
                sftp.remove(remote)
            except IOError:
                pass
            sftp.rename(tmp, remote)
            sftp.close()
            c.close()
            print("PUT_OK", remote, digest[:12], "attempt", i, flush=True)
            return digest
        except Exception as exc:
            last = exc
            print("PUT_FAIL", remote, i, type(exc).__name__, exc, flush=True)
            try:
                if c:
                    c.close()
            except Exception:
                pass
            time.sleep(2 + i)
    raise RuntimeError("put failed %s: %s" % (remote, last))


WRAPPER = r"""#!/bin/bash
set -euo pipefail
ROOT=%(root)s
RUN=%(run)s
NET=%(net)s
RATE=%(rate)d
TRAFFIC=%(traffic)s
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
cp "$ROOT/sim/tb/async_ports_c1_p2.vi" "$WORK/"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial begin
\$sdf_annotate("$ROOT/outputs/$NET/CMRRouter.sdf", tb_cmr_router_rate_scan.dut, , "sdf_annotate.log", "MAXIMUM", ,);
\$display("PPA_INFO SDF_MAX net=$NET rate=$RATE traffic=$TRAFFIC geom=async_ports_c1_p2.vi inject=exponential_serialized"); end endmodule
EOF
printf "%%s\n" "$LIB" "$ROOT/outputs/$NET/CMRRouter_post.v" "$WORK/tb_cmr_router_rate_scan.sv" "$WORK/sdf_boot.sv" > "$WORK/filelist.f"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier +incdir+$WORK +define+GEOM_C1_P2 -f filelist.f -top tb_cmr_router_rate_scan -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv +RATE_MFLIT=$RATE +TRAFFIC=$TRAFFIC -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp "$WORK/sdf_annotate.log" "$LOG/" 2>/dev/null || true
printf "SIM_RC=%%s\n" "$rc" >> "$LOG/run.log"
exit "$rc"
"""


def main():
    put_one(TB, ROOT + "/sim/tb/tb_cmr_router_rate_scan.sv")
    put_one(BIND, ROOT + "/sim/tb/async_ports_c1_p2.vi")

    c = connect()
    jobs = []
    try:
        check = run(
            c,
            "test -s %s/outputs/%s/CMRRouter_post.v && test -s %s/outputs/%s/CMRRouter.sdf && echo NET_OK"
            % (ROOT, NET, ROOT, NET),
        )
        if "NET_OK" not in check:
            raise SystemExit("missing netlist " + NET)
        for traffic in TRAFFICS:
            run_id = "%s_c1_p2_%s_m%d" % (BATCH, traffic.lower(), RATE)
            body = WRAPPER % {
                "root": ROOT,
                "run": run_id,
                "net": NET,
                "rate": RATE,
                "traffic": traffic,
            }
            run(c, "mkdir -p %s/logs/router_rate/%s %s/sim/work/router_rate" % (ROOT, run_id, ROOT))
            wrapper = ROOT + "/logs/router_rate/%s/run_sdf.sh" % run_id
            # write wrapper via a fresh put
            tmp = HERE / ("_tmp_wrapper_%s.sh" % traffic.lower())
            tmp.write_text(body, encoding="utf-8", newline="\n")
            c.close()
            put_one(tmp, wrapper)
            tmp.unlink(missing_ok=True)
            c = connect()
            run(c, "chmod +x " + shlex.quote(wrapper))
            resp = run(
                c,
                'bsub -n 8 -m "node21 node26 node24 node18" -oo %s -eo %s -J %s %s'
                % (
                    shlex.quote(ROOT + "/logs/router_rate/%s/lsf.out" % run_id),
                    shlex.quote(ROOT + "/logs/router_rate/%s/lsf.err" % run_id),
                    shlex.quote(run_id[:60]),
                    shlex.quote(wrapper),
                ),
            )
            print(resp, flush=True)
            m = re.search(r"Job <(\d+)>", resp)
            if not m:
                raise RuntimeError("bsub failed: " + resp)
            jobs.append((run_id, m.group(1)))
            print("JOB_SUBMIT", run_id, m.group(1), flush=True)

        # poll
        pending = dict(jobs)
        for poll in range(480):
            if not pending:
                break
            done = []
            for run_id, jid in list(pending.items()):
                st = run(
                    c,
                    "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); printf '%%s' \"$state\""
                    % shlex.quote(jid),
                ).strip()
                print("JOB_WAIT", run_id, jid, st or "PURGED", "poll", poll, flush=True)
                if st in ("", "DONE", "EXIT", "ZOMBI", "UNKWN"):
                    done.append(run_id)
            for run_id in done:
                pending.pop(run_id, None)
            if pending:
                time.sleep(30)
                # refresh session occasionally
                if poll % 10 == 9:
                    c.close()
                    c = connect()

        failed = 0
        for run_id, jid in jobs:
            summary = run(
                c,
                "echo RUN=%s; grep -E 'TB_RESULT|TB_FIRST|TB_RATE|PPA_INFO|SIM_RC=|Error-' %s/logs/router_rate/%s/run.log %s/logs/router_rate/%s/compile.log 2>/dev/null | head -n 60"
                % (run_id, ROOT, run_id, ROOT, run_id),
            )
            print(summary, flush=True)
            if "TB_RESULT PASS" not in summary:
                failed += 1
        print("HOP_AWAITACK_DONE", BATCH, "failed", failed, "/", len(jobs), flush=True)
        return 0 if failed == 0 else 1
    finally:
        try:
            c.close()
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
