#!/usr/bin/env python3
"""Upload and run RouterL1 reqGen segment timing on SIC_C1."""
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
    / "run_dc_routerl1_reqgen_segment_timing.tcl"
)

FETCH_NAMES = (
    "reqgen_segment_timing.csv",
    "reqgen_segment_destmask_bits.csv",
    "reqgen_segment_summary.txt",
    "reqgen_segment_object_counts.txt",
    "reqgen_segment_name_hints.txt",
    "reqgen_segment_check_timing.rpt",
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
        with sftp.file("%s/scripts/timing/run_dc_routerl1_reqgen_segment_timing.tcl" % P, "wb") as f:
            f.write(LOCAL_TCL.read_bytes().replace(b"\r\n", b"\n"))

        wrapper = "%s/logs/run_dc_r1_reqgen_segments.sh" % P
        body = """#!/bin/bash
set -o pipefail
cd {P}
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
echo START_WRAPPER
which dc_shell-t || {{ echo NO_DC; exit 1; }}
exec dc_shell-t -64 -f scripts/timing/run_dc_routerl1_reqgen_segment_timing.tcl
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
chmod +x {w}; sed -i 's/\\r$//' {w} {P}/scripts/timing/run_dc_routerl1_reqgen_segment_timing.tcl
: > {P}/logs/dc_r1_reqgen_segments.log; : > {P}/logs/dc_r1_reqgen_segments.err
ls -la {P}/outputs/RouterL1.ddc {P}/outputs/RouterL1_dc.sdc
bsub -n 4 -o {P}/logs/dc_r1_reqgen_segments.log -e {P}/logs/dc_r1_reqgen_segments.err \
  -J async_r1_reqgen_segments {w}
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
bjobs -J async_r1_reqgen_segments 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: async RouterL1 reqGen segment timing complete|ERROR:|WARN:|MISSING|NO_PATH|object counts|delay rank|wrote' \
  {P}/logs/dc_r1_reqgen_segments.log 2>/dev/null | tail -60
echo '=== segment csv ==='
cat {P}/reports/RouterL1/reqgen_segment_timing.csv 2>/dev/null || echo NO_SEGMENT_CSV
echo '=== segment summary ==='
cat {P}/reports/RouterL1/reqgen_segment_summary.txt 2>/dev/null || echo NO_SEGMENT_SUMMARY
tail -10 {P}/logs/dc_r1_reqgen_segments.err 2>/dev/null
""".format(
                    P=P
                ),
            )
            print("=== poll %d ===" % i)
            print(text[-5000:])
            if "INFO: async RouterL1 reqGen segment timing complete" in text:
                break
            if "NO_JOB" in text and i > 2:
                if "NO_SEGMENT_CSV" not in text:
                    break
                if "ERROR:" in text:
                    break

        sftp = c.open_sftp()
        local_dir = Path(__file__).resolve().parent / "timing" / "results"
        local_dir.mkdir(parents=True, exist_ok=True)
        for name in FETCH_NAMES:
            remote = "%s/reports/RouterL1/%s" % (P, name)
            for attempt in range(3):
                try:
                    sftp.stat(remote)
                    sftp.get(remote, str(local_dir / name))
                    print("GET", remote)
                    break
                except Exception as ex:
                    if attempt == 2:
                        print("skip", name, ex)
                    else:
                        time.sleep(2)
        try:
            for ent in sftp.listdir("%s/reports/RouterL1" % P):
                if ent.startswith("reqgen_segment_") and ent.endswith(".rpt"):
                    remote = "%s/reports/RouterL1/%s" % (P, ent)
                    sftp.get(remote, str(local_dir / ent))
                    print("GET", remote)
        except Exception as ex:
            print("skip rpt glob", ex)
        sftp.close()

        summary = local_dir / "reqgen_segment_summary.txt"
        if summary.exists():
            print("=== local reqgen segment summary ===")
            print(summary.read_text(errors="replace"))
    finally:
        c.close()


if __name__ == "__main__":
    main()
