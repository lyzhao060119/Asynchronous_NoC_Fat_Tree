#!/usr/bin/env python3
"""Upload RTL/scripts and submit DC / GLS jobs on SIC_C1 Asynchronous_Router.

Credentials via env:
  C1_HOST  default 192.168.2.8
  C1_USER  default ghy19
  C1_PASS  required

Examples:
  python remote_upload_and_run.py upload
  python remote_upload_and_run.py submit-dc
  python remote_upload_and_run.py status
  python remote_upload_and_run.py submit-gls   # sdf smoke via run_gls_smoke.sh
  python remote_upload_and_run.py gls-log
  # Prefer upload_and_run_gls_smoke.py for func+sdf staged smoke.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import paramiko

HOST = os.environ.get("C1_HOST", "192.168.2.8")
USER = os.environ.get("C1_USER", "ghy19")
PROJECT = "/home/ghy19/Asynchronous_Router"

REPO = Path(__file__).resolve().parents[2]
ASIC_DC = Path(__file__).resolve().parent
GEN = REPO / ("generated_ultra" if os.environ.get("ULTRA_NOC16_RTL") == "1" else "generated")
ROUTERL1_GEN = REPO / "generated"
ASYNC = REPO / "src" / "main" / "resources" / "ASYNC"


def get_password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        text = doc.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"^[ \t-]*\u5bc6\u7801[:\uff1a][ \t]*(\S+)", text, re.M)
        if match:
            return match.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def connect():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=get_password(), timeout=30, banner_timeout=30)
    return client


def ssh_exec(client, cmd, timeout=120):
    _, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    code = stdout.channel.recv_exit_status()
    return code, out, err


def sftp_put(sftp, local: Path, remote: str):
    print(f"PUT {local} -> {remote}")
    sftp.put(str(local), remote)


def action_upload(client):
    _, out, _ = ssh_exec(
        client,
        f"mkdir -p {PROJECT}/rtl {PROJECT}/scripts {PROJECT}/sim_gls "
        f"{PROJECT}/logs {PROJECT}/reports {PROJECT}/outputs {PROJECT}/work {PROJECT}/work_routerl1",
    )
    print(out)
    sftp = client.open_sftp()
    uploads = [
        (ASYNC / "DelayElement_ASIC.v", f"{PROJECT}/rtl/DelayElement_ASIC.v"),
        (ASYNC / "Mutex2_ASIC.v", f"{PROJECT}/rtl/Mutex2_ASIC.v"),
        (ASYNC / "MullerC2.v", f"{PROJECT}/rtl/MullerC2.v"),
        (ASYNC / "MullerC3.v", f"{PROJECT}/rtl/MullerC3.v"),
        (ASYNC / "DLatchBank.v", f"{PROJECT}/rtl/DLatchBank.v"),
        (ASYNC / "MousetrapStage.v", f"{PROJECT}/rtl/MousetrapStage.v"),
        (ASYNC / "TAC2.v", f"{PROJECT}/rtl/TAC2.v"),
        (ASYNC / "Mutex3Grant.v", f"{PROJECT}/rtl/Mutex3Grant.v"),
        (ASYNC / "Mutex5Anchor.v", f"{PROJECT}/rtl/Mutex5Anchor.v"),
        (GEN / "NoC_16nodes.v", f"{PROJECT}/rtl/NoC_16nodes.v"),
        (ASIC_DC / "tech_t28ss.tcl", f"{PROJECT}/scripts/tech_t28ss.tcl"),
        (ASIC_DC / "async_primitives.tcl", f"{PROJECT}/scripts/async_primitives.tcl"),
        (ASIC_DC / "async_noc16_t28.sdc", f"{PROJECT}/scripts/async_noc16_t28.sdc"),
        (ASIC_DC / "async_routerl1_t28.sdc", f"{PROJECT}/scripts/async_routerl1_t28.sdc"),
        (ASIC_DC / "run_dc_noc16_t28ss.tcl", f"{PROJECT}/scripts/run_dc_noc16_t28ss.tcl"),
        (ASIC_DC / "run_dc_routerl1_t28ss.tcl", f"{PROJECT}/scripts/run_dc_routerl1_t28ss.tcl"),
        (ASIC_DC / "assert_no_gtech.tcl", f"{PROJECT}/scripts/assert_no_gtech.tcl"),
        (ASIC_DC / "sim_gls" / "patch_gls_netlist.py", f"{PROJECT}/sim_gls/patch_gls_netlist.py"),
        (ASIC_DC / "sim_gls" / "run_gls_smoke.sh", f"{PROJECT}/sim_gls/run_gls_smoke.sh"),
        (ASIC_DC / "sim_gls" / "run_gls_func.sh", f"{PROJECT}/sim_gls/run_gls_func.sh"),
        (ASIC_DC / "sim_gls" / "tb_gls_routerl1_func.sv", f"{PROJECT}/sim_gls/tb_gls_routerl1_func.sv"),
        (ASIC_DC / "sim_gls" / "tb_gls_noc16_func.sv", f"{PROJECT}/sim_gls/tb_gls_noc16_func.sv"),
        (ASIC_DC / "sim_gls" / "async_hs_port.sv", f"{PROJECT}/sim_gls/async_hs_port.sv"),
        (ASIC_DC / "sim_gls" / "filelist_routerl1_func.f", f"{PROJECT}/sim_gls/filelist_routerl1_func.f"),
        (ASIC_DC / "sim_gls" / "filelist_noc16_func.f", f"{PROJECT}/sim_gls/filelist_noc16_func.f"),
    ]
    routerl1 = ROUTERL1_GEN / "RouterL1.v"
    if routerl1.exists():
        uploads.insert(6, (routerl1, f"{PROJECT}/rtl/RouterL1.v"))
    for local, remote in uploads:
        if not local.exists():
            raise SystemExit(f"missing local file: {local}")
        sftp_put(sftp, local, remote)
    sftp.close()
    code, out, err = ssh_exec(
        client,
        f"chmod +x {PROJECT}/sim_gls/run_gls_smoke.sh {PROJECT}/sim_gls/run_gls_func.sh; "
        f"sed -i 's/\\r$//' {PROJECT}/sim_gls/*.sh {PROJECT}/scripts/*.tcl; "
        f"ls -la {PROJECT}/rtl {PROJECT}/scripts {PROJECT}/sim_gls",
    )
    print(out)
    if err:
        print(err)
    print("upload exit", code)


def submit_one(client, job_name: str, wrapper_name: str, tcl: str, logfile: str):
    cmd = f"""
cd {PROJECT}
cat > logs/{wrapper_name} << 'EOF'
#!/bin/bash
source /etc/profile 2>/dev/null || true
module load syn
cd {PROJECT}
exec dc_shell-t -64 -f scripts/{tcl}
EOF
chmod +x logs/{wrapper_name}
bsub -o {PROJECT}/logs/{logfile}.log -e {PROJECT}/logs/{logfile}.err -J {job_name} {PROJECT}/logs/{wrapper_name}
"""
    code, out, err = ssh_exec(client, cmd)
    print(out)
    if err:
        print(err)
    print("submit", job_name, "exit", code)


def action_submit_dc(client):
    submit_one(client, "async_routerl1_dc", "run_dc_routerl1_wrapper.sh", "run_dc_routerl1_t28ss.tcl", "dc_routerl1")
    submit_one(client, "async_noc16_dc", "run_dc_noc16_wrapper.sh", "run_dc_noc16_t28ss.tcl", "dc_noc16")
    code, out, err = ssh_exec(client, "bjobs | head -40")
    print(out)


def action_status(client):
    code, out, err = ssh_exec(
        client,
        f"""
bjobs 2>/dev/null | head -40
echo '--- outputs ---'
ls -la {PROJECT}/outputs 2>/dev/null
echo '--- reports ---'
ls -la {PROJECT}/reports {PROJECT}/reports/RouterL1 2>/dev/null
echo '--- log tails ---'
echo '== dc_routerl1 =='; tail -n 30 {PROJECT}/logs/dc_routerl1.log 2>/dev/null
echo '== dc_noc16 =='; tail -n 30 {PROJECT}/logs/dc_noc16.log 2>/dev/null
echo '== dc_noc16 unresolved =='; grep -Ei 'unresolved references|unresolved reference' {PROJECT}/logs/dc_noc16.log 2>/dev/null | tail -10
echo -n 'NOC16_DEL250='; grep -c 'DEL250D1BWP' {PROJECT}/outputs/NoC_16nodes_post.v 2>/dev/null || true
echo '== gls_routerl1 =='; grep -E 'TB_RESULT|T_router|Error|ERROR' {PROJECT}/logs/gls_smoke_routerl1*.log {PROJECT}/logs/gls_routerl1*.log 2>/dev/null | tail -20
echo '== gls_noc16 =='; grep -E 'TB_RESULT|T_noc|Error|ERROR' {PROJECT}/logs/gls_smoke_noc16*.log {PROJECT}/logs/gls_noc16*.log 2>/dev/null | tail -20
""",
        timeout=60,
    )
    print(out)
    if err:
        print(err)


def action_submit_gls(client):
    cmd = f"""
cd {PROJECT}
cat > logs/run_gls_routerl1_wrapper.sh << 'EOF'
#!/bin/bash
source /etc/profile 2>/dev/null || true
cd {PROJECT}
exec bash sim_gls/run_gls_smoke.sh sdf routerl1
EOF
cat > logs/run_gls_noc16_wrapper.sh << 'EOF'
#!/bin/bash
source /etc/profile 2>/dev/null || true
cd {PROJECT}
exec bash sim_gls/run_gls_smoke.sh sdf noc16
EOF
chmod +x logs/run_gls_routerl1_wrapper.sh logs/run_gls_noc16_wrapper.sh
bsub -o {PROJECT}/logs/gls_routerl1_bsub.log -e {PROJECT}/logs/gls_routerl1_bsub.err -J async_gls_r1 {PROJECT}/logs/run_gls_routerl1_wrapper.sh
bsub -o {PROJECT}/logs/gls_noc16_bsub.log -e {PROJECT}/logs/gls_noc16_bsub.err -J async_gls_noc16 {PROJECT}/logs/run_gls_noc16_wrapper.sh
bjobs | head -40
"""
    code, out, err = ssh_exec(client, cmd)
    print(out)
    if err:
        print(err)


def action_gls_log(client):
    code, out, err = ssh_exec(
        client,
        f"""
echo '=== routerl1 smoke ==='
grep -E 'TB_RESULT|T_router|TIMEOUT|Error' {PROJECT}/logs/gls_*routerl1*.log 2>/dev/null | tail -40
echo '=== noc16 smoke ==='
grep -E 'TB_RESULT|T_noc|TIMEOUT|Error' {PROJECT}/logs/gls_*noc16*.log 2>/dev/null | tail -40
echo '=== compile tails ==='
tail -n 40 {PROJECT}/logs/gls_routerl1_compile.log 2>/dev/null
tail -n 40 {PROJECT}/logs/gls_noc16_compile.log 2>/dev/null
""",
        timeout=60,
    )
    print(out)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    client = connect()
    try:
        if action == "upload":
            action_upload(client)
        elif action == "submit-dc":
            action_submit_dc(client)
        elif action == "status":
            action_status(client)
        elif action == "submit-gls":
            action_submit_gls(client)
        elif action == "gls-log":
            action_gls_log(client)
        else:
            print(__doc__)
            sys.exit(2)
    finally:
        client.close()


if __name__ == "__main__":
    main()
