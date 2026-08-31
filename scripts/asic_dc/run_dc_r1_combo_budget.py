#!/usr/bin/env python3
"""Upload and run RouterL1 combo-budget DC timing on SIC_C1 (bypass DEL*)."""
from __future__ import print_function

import os
import time
from pathlib import Path

import paramiko

P = "/home/ghy19/Asynchronous_Router"
HOST = os.environ.get("C1_HOST", "192.168.2.8")
USER = os.environ.get("C1_USER", "ghy19")
PASSWORD = os.environ["C1_PASS"]
LOCAL_TCL = Path(__file__).resolve().parent / "timing" / "run_dc_routerl1_combo_budget.tcl"

FETCH_NAMES = (
    "combo_budget_bypass.csv",
    "combo_budget_bypass_summary.txt",
    "combo_budget.csv",
    "combo_budget_summary.txt",
    "combo_budget_hierarchy_hints.txt",
)


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        HOST,
        username=USER,
        password=PASSWORD,
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    return c


def run(c, cmd, timeout=120):
    _, o, e = c.exec_command(cmd, timeout=timeout)
    return o.read().decode(errors="replace") + e.read().decode(errors="replace")


def main():
    if not LOCAL_TCL.exists():
        raise SystemExit("missing %s" % LOCAL_TCL)
    c = connect()
    try:
        print(run(c, "mkdir -p %s/scripts/timing %s/logs %s/reports/RouterL1" % (P, P, P)))
        sftp = c.open_sftp()
        data = LOCAL_TCL.read_bytes().replace(b"\r\n", b"\n")
        with sftp.file("%s/scripts/timing/run_dc_routerl1_combo_budget.tcl" % P, "wb") as f:
            f.write(data)
        wrapper = "%s/logs/run_dc_r1_combo_budget.sh" % P
        # Do not use `set -u`: module/profile can reference unset vars and exit early.
        body = """#!/bin/bash
set -o pipefail
cd {P}
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
echo START_WRAPPER
which dc_shell-t || {{ echo NO_DC; exit 1; }}
exec dc_shell-t -64 -f scripts/timing/run_dc_routerl1_combo_budget.tcl
""".format(
            P=P
        )
        with sftp.file(wrapper, "w") as f:
            f.write(body.replace("\r\n", "\n"))
        sftp.close()

        print(
            run(
                c,
                """
chmod +x {w}; sed -i 's/\\r$//' {w} {P}/scripts/timing/run_dc_routerl1_combo_budget.tcl
: > {P}/logs/dc_r1_combo_budget.log; : > {P}/logs/dc_r1_combo_budget.err
ls -la {P}/outputs/RouterL1.ddc {P}/outputs/RouterL1_dc.sdc
bsub -n 4 -o {P}/logs/dc_r1_combo_budget.log -e {P}/logs/dc_r1_combo_budget.err \
  -J async_r1_combo_budget {w}
bjobs -w | head
""".format(
                    w=wrapper, P=P
                ),
            )
        )

        for i in range(80):
            time.sleep(15)
            text = run(
                c,
                """
bjobs -J async_r1_combo_budget 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: async RouterL1 combo budget|ERROR:|WARN:|covered|bypass|DEL\\*|hotspot|method=' \
  {P}/logs/dc_r1_combo_budget.log 2>/dev/null | tail -40
echo '=== bypass csv ==='
cat {P}/reports/RouterL1/combo_budget_bypass.csv 2>/dev/null || echo NO_BYPASS_CSV
echo '=== bypass summary ==='
cat {P}/reports/RouterL1/combo_budget_bypass_summary.txt 2>/dev/null || echo NO_BYPASS_SUMMARY
tail -5 {P}/logs/dc_r1_combo_budget.err 2>/dev/null
""".format(
                    P=P
                ),
            )
            print("=== poll %d ===" % i)
            print(text[-4000:])
            if "INFO: async RouterL1 combo budget complete" in text:
                break
            if "NO_JOB" in text and i > 2:
                if "NO_BYPASS_CSV" not in text:
                    break
                if "Exited" in text or "ERROR:" in text:
                    break

        sftp = c.open_sftp()
        local_dir = Path(__file__).resolve().parent / "timing" / "results"
        local_dir.mkdir(parents=True, exist_ok=True)
        for name in FETCH_NAMES:
            remote = "%s/reports/RouterL1/%s" % (P, name)
            try:
                sftp.get(remote, str(local_dir / name))
                print("GET", remote)
            except Exception as ex:
                print("skip", name, ex)
        # Also fetch a few bypass rpt files if present
        try:
            for ent in sftp.listdir("%s/reports/RouterL1" % P):
                if ent.startswith("combo_budget_bypass_") and ent.endswith(".rpt"):
                    remote = "%s/reports/RouterL1/%s" % (P, ent)
                    sftp.get(remote, str(local_dir / ent))
                    print("GET", remote)
        except Exception as ex:
            print("skip rpt glob", ex)
        sftp.close()
    finally:
        c.close()


if __name__ == "__main__":
    main()
