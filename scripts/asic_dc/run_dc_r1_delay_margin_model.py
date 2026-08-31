#!/usr/bin/env python3
"""Upload and run RouterL1 precise DelayElement margin STA on SIC_C1."""
from __future__ import print_function

import os
import time
from pathlib import Path

import paramiko

P = "/home/ghy19/Asynchronous_Router"
HOST = os.environ.get("C1_HOST", "192.168.2.8")
USER = os.environ.get("C1_USER", "ghy19")
PASSWORD = os.environ["C1_PASS"]
LOCAL_TCL = (
    Path(__file__).resolve().parent
    / "timing"
    / "run_dc_routerl1_delay_margin_model.tcl"
)

FETCH_NAMES = (
    "delay_margin_model.csv",
    "delay_margin_model_summary.txt",
    "delay_margin_model_hints.txt",
    "delay_margin_model_check_timing.rpt",
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


def sftp_get_retry(sftp, remote, local, attempts=5, sleep_s=5):
    last = None
    for _ in range(attempts):
        try:
            sftp.get(remote, str(local))
            return True, None
        except Exception as ex:
            last = ex
            time.sleep(sleep_s)
    return False, last


def main():
    if not LOCAL_TCL.exists():
        raise SystemExit("missing %s" % LOCAL_TCL)
    c = connect()
    try:
        print(run(c, "mkdir -p %s/scripts/timing %s/logs %s/reports/RouterL1" % (P, P, P)))
        sftp = c.open_sftp()
        data = LOCAL_TCL.read_bytes().replace(b"\r\n", b"\n")
        with sftp.file("%s/scripts/timing/run_dc_routerl1_delay_margin_model.tcl" % P, "wb") as f:
            f.write(data)
        wrapper = "%s/logs/run_dc_r1_delay_margin_model.sh" % P
        body = """#!/bin/bash
set -o pipefail
cd {P}
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
echo START_WRAPPER
which dc_shell-t || {{ echo NO_DC; exit 1; }}
exec dc_shell-t -64 -f scripts/timing/run_dc_routerl1_delay_margin_model.tcl
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
chmod +x {w}; sed -i 's/\\r$//' {w} {P}/scripts/timing/run_dc_routerl1_delay_margin_model.tcl
: > {P}/logs/dc_r1_delay_margin_model.log; : > {P}/logs/dc_r1_delay_margin_model.err
ls -la {P}/outputs/RouterL1.ddc {P}/outputs/RouterL1_dc.sdc
bsub -n 4 -o {P}/logs/dc_r1_delay_margin_model.log -e {P}/logs/dc_r1_delay_margin_model.err \
  -J async_r1_delay_margin {w}
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
bjobs -J async_r1_delay_margin 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: async RouterL1 delay margin|ERROR:|WARN:|DEL\\*|modeled_domains|domain rows|wrote|PARTIAL|NO_CLOCK|NO_SAMPLED' \
  {P}/logs/dc_r1_delay_margin_model.log 2>/dev/null | tail -60
echo '=== margin csv ==='
cat {P}/reports/RouterL1/delay_margin_model.csv 2>/dev/null || echo NO_MARGIN_CSV
echo '=== margin summary ==='
cat {P}/reports/RouterL1/delay_margin_model_summary.txt 2>/dev/null || echo NO_MARGIN_SUMMARY
tail -8 {P}/logs/dc_r1_delay_margin_model.err 2>/dev/null
""".format(
                    P=P
                ),
            )
            print("=== poll %d ===" % i)
            print(text[-6000:])
            if "INFO: async RouterL1 delay margin model complete" in text:
                break
            if "NO_JOB" in text and i > 2:
                if "NO_MARGIN_CSV" not in text:
                    break
                if "Exited" in text or "ERROR:" in text:
                    break

        sftp = c.open_sftp()
        local_dir = Path(__file__).resolve().parent / "timing" / "results"
        local_dir.mkdir(parents=True, exist_ok=True)
        for name in FETCH_NAMES:
            remote = "%s/reports/RouterL1/%s" % (P, name)
            ok, ex = sftp_get_retry(sftp, remote, local_dir / name)
            if ok:
                print("GET", remote)
            else:
                print("skip", name, ex)
        try:
            for ent in sftp.listdir("%s/reports/RouterL1" % P):
                if ent.startswith("delay_margin_model_") and ent.endswith(".rpt"):
                    remote = "%s/reports/RouterL1/%s" % (P, ent)
                    ok, ex = sftp_get_retry(sftp, remote, local_dir / ent, attempts=2, sleep_s=2)
                    if not ok:
                        print("skip", ent, ex)
                        continue
                    print("GET", remote)
        except Exception as ex:
            print("skip rpt glob", ex)
        sftp.close()

        summary = local_dir / "delay_margin_model_summary.txt"
        csv = local_dir / "delay_margin_model.csv"
        if summary.exists():
            print("=== local delay margin summary ===")
            print(summary.read_text(errors="replace"))
        if csv.exists():
            print("=== local delay margin csv ===")
            print(csv.read_text(errors="replace"))
    finally:
        c.close()


if __name__ == "__main__":
    main()
