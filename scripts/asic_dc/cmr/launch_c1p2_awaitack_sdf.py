#!/usr/bin/env python3
"""MAXIMUM-SDF hop rate-scan for the await-ack C1P2 netlist.

Uploads the fixed local TB via plain SFTP, then runs UC+F4 at 100 MFlit on
20260910_c1p2_awaitack_del150_dc.
"""
from __future__ import annotations

import hashlib
import os
import re
import shlex
import sys
import time
from datetime import datetime
from pathlib import Path

import paramiko

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from run_remote_cmr_flow import atomic_put_bytes_retry, password  # noqa: E402

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
TB_LOCAL = HERE / "tb_cmr_router_rate_scan.sv"
BATCH = datetime.now().strftime("%Y%m%d_%H%M%S") + "_hop_awaitack_m100"
HOP_NET = os.environ.get("CMR_HOP_NET_ID", "20260910_c1p2_awaitack_del150_dc")
HOP_GEOM = os.environ.get("CMR_HOP_GEOM", "C1_P2")
HOP_TRAFFIC = tuple(
    part.strip()
    for part in os.environ.get("CMR_HOP_TRAFFIC", "UC,F4").split(",")
    if part.strip()
)
RATES = tuple(
    int(part.strip())
    for part in os.environ.get("CMR_HOP_RATES", "100").split(",")
    if part.strip()
)
if not RATES or any(rate <= 0 for rate in RATES):
    raise SystemExit("CMR_HOP_RATES must be a non-empty comma-separated positive-rate list")
JOBS = tuple(
    (HOP_NET, HOP_GEOM, traffic, rate)
    for rate in RATES
    for traffic in HOP_TRAFFIC
)
JOB_POLLS = int(os.environ.get("CMR_JOB_POLLS", "480"))

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
\$display("PPA_INFO SDF_MAX net=$NET rate=$RATE traffic=$TRAFFIC geom=$BIND inject=exponential_flit"); end endmodule
EOF
printf "%%s\n" "$LIB" "$ROOT/outputs/$NET/CMRRouter_post.v" "$WORK/tb_cmr_router_rate_scan.sv" "$WORK/sdf_boot.sv" > "$WORK/filelist.f"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier +incdir+$WORK $GEOM_DEFINE -f filelist.f -top tb_cmr_router_rate_scan -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv +RATE_MFLIT=$RATE +TRAFFIC=$TRAFFIC +VCD="$LOG/trace.vcd" -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp "$WORK/sdf_annotate.log" "$LOG/" 2>/dev/null || true
printf "SIM_RC=%%s\n" "$rc" >> "$LOG/run.log"
exit "$rc"
"""

SSH_ERRORS = (OSError, EOFError, paramiko.SSHException)


def connect():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
        compress=False,
    )
    transport = client.get_transport()
    if transport is not None:
        transport.set_keepalive(30)
    return client


def reconnect(client):
    try:
        client.close()
    except Exception:
        pass
    return connect()


def remote_run(client, command: str) -> str:
    _, stdout, stderr = client.exec_command(command)
    return (stdout.read() + stderr.read()).decode(errors="replace")


def remote_run_retry(client, command: str, attempts: int = 8):
    last = None
    for attempt in range(attempts):
        try:
            return client, remote_run(client, command)
        except SSH_ERRORS as exc:
            last = exc
            print("SSH_RETRY", attempt, exc, flush=True)
            client = reconnect(client)
            time.sleep(3 + min(attempt, 5) * 2)
    raise RuntimeError("SSH retries exhausted: %s" % last)


def remote_put_bytes(client, data: bytes, remote: str):
    """Upload via base64 appended in small batches over exec_command.

    Neither SFTP (channel dropped mid-write, 10054/EOFError) nor a single
    large stdin write (connection reset by the server) works on this link.
    Small ``printf`` appends survive, so batch the base64 and verify with a
    remote md5 before moving it into place.
    """
    import base64

    digest = hashlib.md5(data).hexdigest()
    client, current = remote_run_retry(client, "md5sum %s 2>/dev/null" % shlex.quote(remote))
    if current.strip().split(" ")[0] == digest:
        print("UPLOAD_SKIP", remote, digest, flush=True)
        return client, digest

    encoded = base64.b64encode(data).decode("ascii")
    temporary = "%s.upload.%d" % (remote, os.getpid())
    client, _ = remote_run_retry(client, "rm -f %s" % shlex.quote(temporary))
    step = 1024
    for index, offset in enumerate(range(0, len(encoded), step)):
        chunk = encoded[offset : offset + step]
        client, _ = remote_run_retry(
            client,
            "printf '%%s' %s >> %s" % (shlex.quote(chunk), shlex.quote(temporary)),
        )
        if index % 10 == 9:
            print("UPLOAD_PROGRESS", remote, offset + step, len(encoded), flush=True)
    client, verify = remote_run_retry(
        client,
        "base64 -d %s > %s && rm -f %s && md5sum %s"
        % (
            shlex.quote(temporary),
            shlex.quote(remote),
            shlex.quote(temporary),
            shlex.quote(remote),
        ),
    )
    if verify.strip().split(" ")[0] != digest:
        raise RuntimeError("upload verification failed for %s: %s" % (remote, verify))
    return client, digest


def sftp_put_file(client, local: Path, remote: str) -> str:
    """Reliable SSH chunk upload for this remote host's unstable SFTP service."""
    return remote_put_bytes(client, local.read_bytes().replace(b"\r\n", b"\n"), remote)


def sftp_put_file_bytes(client, data: bytes, remote: str):
    """Atomic SFTP upload for generated wrapper text as well."""
    sftp = client.open_sftp()
    try:
        client, sftp, digest = atomic_put_bytes_retry(
            client, sftp, data, remote
        )
        return client, digest
    finally:
        sftp.close()


def job_id(submit_text: str) -> str:
    match = re.search(r"Job <(\d+)>", submit_text)
    if not match:
        raise RuntimeError("LSF submission failed: " + submit_text)
    return match.group(1)


def bsub_extra() -> str:
    extra = os.environ.get("CMR_DES_BSUB_EXTRA", "").strip()
    if extra:
        return extra
    return '-m "node21 node26 node24 node18"'


def wait_job(client, jid: str, label: str, allow_exit: bool = False):
    for poll_index in range(JOB_POLLS):
        client, response = remote_run_retry(
            client,
            "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); "
            "printf '__STATE__%%s\\n' \"$state\"" % shlex.quote(jid),
        )
        match = re.search(r"__STATE__([A-Z]*)", response)
        if not match:
            raise RuntimeError("could not parse LSF state: " + response)
        state = match.group(1)
        if not state or state == "DONE":
            print("JOB_DONE", label, jid, state or "PURGED", flush=True)
            return client
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            if allow_exit:
                print("JOB_EXIT", label, jid, state, flush=True)
                return client
            raise RuntimeError("LSF job %s %s ended in state %s" % (label, jid, state))
        print("JOB_WAIT", label, jid, state, "poll", poll_index, flush=True)
        time.sleep(30)
    raise RuntimeError("job polling timeout: %s %s" % (label, jid))


def fetch_tree(client, remote: str, local: Path) -> None:
    """Pull a remote directory as a base64 tar stream (SFTP is unusable)."""
    import base64
    import io
    import tarfile

    local.mkdir(parents=True, exist_ok=True)
    client, listing = remote_run_retry(
        client, "cd %s && tar --exclude=trace.vcd -czf - . | base64 -w 0" % shlex.quote(remote)
    )
    payload = "".join(listing.split())
    if not payload:
        return
    blob = base64.b64decode(payload)
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile():
                continue
            name = os.path.basename(member.name)
            if not name:
                continue
            handle = archive.extractfile(member)
            if handle is not None:
                (local / name).write_bytes(handle.read())


def submit_one(client, net: str, geom: str, traffic: str, rate: int):
    run = "%s_%s_%s_m%d" % (BATCH, geom.lower(), traffic.lower(), rate)
    bind = "async_ports_%s.vi" % geom.lower()
    body = WRAPPER % {
        "root": ROOT,
        "run": run,
        "net": net,
        "rate": rate,
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
    client, _ = sftp_put_file_bytes(client, body.encode(), wrapper)
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
    print("JOB_SUBMIT", run, jid, net, geom, traffic, rate, flush=True)
    return client, run, jid


def harvest(client, run: str) -> str:
    log = shlex.quote(ROOT + "/logs/router_rate/%s/run.log" % run)
    compile_log = shlex.quote(ROOT + "/logs/router_rate/%s/compile.log" % run)
    grep = (
        "echo RUN=%s; "
        "grep -E 'TB_RESULT|TB_RATE|TB_INFO inject|TB_FIRST|PPA_INFO|SIM_RC=|Error-' %s 2>/dev/null | head -n 80; "
        "grep -E 'Error-|TB_RESULT|CPU time' %s 2>/dev/null | head -n 20"
        % (run, log, compile_log)
    )
    client, summary = remote_run_retry(client, grep)
    print(summary, flush=True)
    local = HERE / "results" / BATCH / run
    fetch_tree(client, ROOT + "/logs/router_rate/" + run, local)
    return summary


def main() -> int:
    if not TB_LOCAL.is_file():
        raise SystemExit("missing hop rate-scan TB")
    bind = HERE / "hop_binds" / ("async_ports_%s.vi" % HOP_GEOM.lower())
    if not bind.is_file():
        raise SystemExit("missing bind " + str(bind))
    client = connect()
    try:
        for net, geom, _traffic, _rate in JOBS:
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
        client, tb_hash = sftp_put_file(
            client, TB_LOCAL, ROOT + "/sim/tb/tb_cmr_router_rate_scan.sv"
        )
        uploaded = set()
        for _net, geom, _traffic, _rate in JOBS:
            bind_name = "async_ports_%s.vi" % geom.lower()
            if bind_name in uploaded:
                continue
            client, _ = sftp_put_file(
                client,
                HERE / "hop_binds" / bind_name,
                ROOT + "/sim/tb/" + bind_name,
            )
            uploaded.add(bind_name)
        print("UPLOAD_TB", tb_hash, "BATCH", BATCH, "NET", HOP_NET, flush=True)
        jobs = []
        for net, geom, traffic, rate in JOBS:
            client, run, jid = submit_one(client, net, geom, traffic, rate)
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
        print("HOP_AWAITACK_DONE", BATCH, "failed", failed, "/", len(jobs), flush=True)
        return 0 if failed == 0 else 1
    finally:
        try:
            client.close()
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
