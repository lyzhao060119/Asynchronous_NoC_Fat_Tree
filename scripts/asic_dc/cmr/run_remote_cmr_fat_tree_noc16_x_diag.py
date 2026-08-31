#!/usr/bin/env python3
"""First-X probe on the frozen CMR fat-tree NoC16 SDF netlist. No emit/DC."""
import os
import re
import shlex
import stat
import time
from pathlib import Path

import paramiko

from run_remote_cmr_flow import atomic_put, password, remote_run


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
BASELINE = os.environ.get(
    "CMR_NOC16_DIAG_BASELINE", "20260821_cmr_ft_noc16_addrbuf_p50_sdf"
)
RUN_ID = os.environ.get("CMR_NOC16_DIAG_RUN_ID", "20260821_cmr_ft_noc16_x_diag")
CASE = os.environ.get("CMR_NOC16_CASE_NAME", "TAB-NET-UR-3f-r0p50")
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def connect(attempts=8):
    last = None
    for attempt in range(attempts):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                os.environ.get("C1_HOST", "192.168.2.8"),
                username=os.environ.get("C1_USER", "ghy19"),
                password=password(),
                timeout=40,
                banner_timeout=90,
                allow_agent=False,
                look_for_keys=False,
                compress=True,
            )
            transport = client.get_transport()
            if transport is not None:
                transport.set_keepalive(30)
            return client
        except (OSError, EOFError, paramiko.SSHException) as exc:
            last = exc
            print("SSH_CONNECT_RETRY", attempt, exc, flush=True)
            try:
                client.close()
            except Exception:
                pass
            time.sleep(5 + min(attempt, 6) * 5)
    raise RuntimeError("SSH connect failed: %s" % last)


def client_alive(client):
    transport = client.get_transport() if client is not None else None
    return bool(transport and transport.is_active())


SSH_ERRORS = (
    OSError,
    EOFError,
    paramiko.SSHException,
    paramiko.ssh_exception.SSHException,
)


def remote_run_retry(client, command, attempts=8):
    last = None
    for attempt in range(attempts):
        try:
            if not client_alive(client):
                print("SSH_RECONNECT attempt", attempt, flush=True)
                client = connect()
            return client, remote_run(client, command)
        except SSH_ERRORS as exc:
            last = exc
            print("SSH_RETRY", attempt, exc, flush=True)
            try:
                client.close()
            except Exception:
                pass
            client = connect()
            time.sleep(5 + min(attempt, 6) * 5)
    raise RuntimeError("SSH retries exhausted: %s" % last)


def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for entry in sftp.listdir_attr(remote):
        remote_path = remote + "/" + entry.filename
        local_path = local / entry.filename
        if stat.S_ISDIR(entry.st_mode):
            fetch_tree(sftp, remote_path, local_path)
        else:
            sftp.get(remote_path, str(local_path))


def main():
    client = connect()
    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/sim/tb %s/scripts %s/logs/gls/%s"
        % (ROOT, ROOT, ROOT, RUN_ID),
    )
    sftp = client.open_sftp()
    atomic_put(
        client,
        sftp,
        REPO / "scripts/asic_dc/cmr/tb_cmr_ft_noc16_x_probe.sv",
        "%s/sim/tb/tb_cmr_ft_noc16_x_probe.sv" % ROOT,
    )
    atomic_put(
        client,
        sftp,
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_ft_noc16_x_diag.sh",
        "%s/scripts/run_gls_cmr_ft_noc16_x_diag.sh" % ROOT,
    )
    sftp.close()
    client, _ = remote_run_retry(
        client, "chmod +x %s/scripts/run_gls_cmr_ft_noc16_x_diag.sh" % ROOT
    )
    case_file = "%s/sim/cases/%s.case" % (ULTRA, CASE)
    wrapper = "%s/logs/gls/%s/run.sh" % (ROOT, RUN_ID)
    body = (
        "#!/bin/bash\nset -euo pipefail\n"
        "export CMR_REMOTE_ROOT=%s\n"
        "export CMR_NOC16_RUN_ID=%s\n"
        "export CMR_NOC16_NETLIST_RUN_ID=%s\n"
        "export CMR_NOC16_CASE_NAME=%s\n"
        "export CMR_NOC16_CASE_FILE=%s\n"
        "exec %s/scripts/run_gls_cmr_ft_noc16_x_diag.sh\n"
        % (
            shlex.quote(ROOT),
            shlex.quote(RUN_ID),
            shlex.quote(BASELINE),
            shlex.quote(CASE),
            shlex.quote(case_file),
            ROOT,
        )
    )
    sftp = client.open_sftp()
    with sftp.file(wrapper + ".tmp", "w") as handle:
        handle.write(body)
    try:
        sftp.posix_rename(wrapper + ".tmp", wrapper)
    except IOError:
        sftp.rename(wrapper + ".tmp", wrapper)
    sftp.close()
    client, _ = remote_run_retry(client, "chmod +x %s" % wrapper)
    client, submit = remote_run_retry(
        client,
        "bsub -n 8 -o %s/logs/gls/%s/bsub.log -e %s/logs/gls/%s/bsub.err "
        "-J cmr_ft_x_diag %s" % (ROOT, RUN_ID, ROOT, RUN_ID, wrapper),
    )
    match = re.search(r"Job <(\d+)>", submit)
    if not match:
        raise RuntimeError("LSF submission failed: " + submit)
    jid = match.group(1)
    print("DIAG_JOB", jid, "RUN_ID", RUN_ID, "NETLIST", BASELINE, flush=True)
    for poll in range(240):
        client, state_out = remote_run_retry(
            client,
            "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); "
            "printf '__STATE__%%s\\n' \"$state\"" % shlex.quote(jid),
        )
        state_match = re.search(r"__STATE__([A-Z]*)", state_out)
        state = state_match.group(1) if state_match else ""
        if not state or state == "DONE":
            print("DIAG_DONE", jid, state or "PURGED", flush=True)
            break
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            print("DIAG_FAIL", jid, state, flush=True)
            break
        print("DIAG_WAIT", state, "poll", poll, flush=True)
        time.sleep(15)
    else:
        raise TimeoutError(jid)
    sftp = client.open_sftp()
    fetch_tree(sftp, "%s/logs/gls/%s" % (ROOT, RUN_ID), RESULT)
    sftp.close()
    client.close()
    print("LOCAL_RESULT", RESULT, flush=True)
    x_log = RESULT / "sdf" / CASE / "x_first.log"
    stdout = RESULT / "sdf" / CASE / "stdout.log"
    for path in (x_log, stdout, RESULT / "sdf" / CASE / "compile.log"):
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            hits = [
                line
                for line in text.splitlines()
                if line.startswith("X_") or "Error" in line or "error" in line
            ]
            print("FILE", path.name, "hits", len(hits), flush=True)
            for line in hits[:80]:
                print(line, flush=True)


if __name__ == "__main__":
    main()
