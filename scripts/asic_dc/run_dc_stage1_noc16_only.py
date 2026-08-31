#!/usr/bin/env python3
"""Upload and run Stage1 NoC_16nodes DC on SIC_C1.

Generate RTL locally before running:
  ASYNC_PRIMITIVES=asic ASYNC_DELAY_PROFILE=STAGE1_SAFE \
    sbt "runMain NoC.NoC_16nodesWormholeMinimal"
"""
from __future__ import print_function

import os
import re
import time
from pathlib import Path

import paramiko

P = "/home/ghy19/Asynchronous_Router"
REPO = Path(__file__).resolve().parents[2]
ASIC_DC = Path(__file__).resolve().parent
GEN_STAGE1 = REPO / "generated_stage1"
ASYNC = REPO / "src" / "main" / "resources" / "ASYNC"


def password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    doc = REPO / "docs" / "远程编译限制说明.md"
    if doc.exists():
        text = doc.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"密码[:：]\s*(\S+)", text)
        if m:
            return m.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def get_password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        text = doc.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"^[ \t-]*\u5bc6\u7801[:\uff1a][ \t]*(\S+)", text, re.M)
        if m:
            return m.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=get_password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    return c


def run(c, cmd):
    _, o, e = c.exec_command(cmd)
    return o.read().decode(errors="replace") + e.read().decode(errors="replace")


def put(sftp, local, remote):
    data = Path(local).read_bytes().replace(b"\r\n", b"\n")
    with sftp.file(remote, "wb") as f:
        f.write(data)


def upload(c):
    run(c, "mkdir -p {0}/rtl {0}/scripts {0}/logs {0}/outputs {0}/reports".format(P))
    uploads = [
        (ASYNC / "DelayElement_ASIC.v", "%s/rtl/DelayElement_ASIC.v" % P),
        (ASYNC / "Mutex2_ASIC.v", "%s/rtl/Mutex2_ASIC.v" % P),
        (GEN_STAGE1 / "NoC_16nodes.v", "%s/rtl/NoC_16nodes.v" % P),
        (ASIC_DC / "tech_t28ss.tcl", "%s/scripts/tech_t28ss.tcl" % P),
        (ASIC_DC / "async_primitives.tcl", "%s/scripts/async_primitives.tcl" % P),
        (ASIC_DC / "async_noc16_t28.sdc", "%s/scripts/async_noc16_t28.sdc" % P),
        (ASIC_DC / "assert_no_gtech.tcl", "%s/scripts/assert_no_gtech.tcl" % P),
        (ASIC_DC / "run_dc_noc16_t28ss.tcl", "%s/scripts/run_dc_noc16_t28ss.tcl" % P),
    ]
    sftp = c.open_sftp()
    try:
        for local, remote in uploads:
            if not Path(local).exists():
                raise SystemExit("missing local file: %s" % local)
            put(sftp, local, remote)
    finally:
        sftp.close()

    print(run(c, """
sed -i 's/\\r$//' {P}/scripts/*.tcl
echo "INFO: Stage1 NoC16 RTL marker check"
grep -E 'module RouterL1WormholeMinimal|module RouterL2WormholeMinimal|module NoC_16nodes' {P}/rtl/NoC_16nodes.v | head -8
if grep -q 'module RouterL1(' {P}/rtl/NoC_16nodes.v; then echo 'ERROR: old RouterL1 module found'; fi
ls -la {P}/rtl/NoC_16nodes.v {P}/scripts/run_dc_noc16_t28ss.tcl
""".format(P=P)))


def main():
    profile = os.environ.get("ASYNC_DELAY_PROFILE", "UNKNOWN")
    c = connect()
    try:
        upload(c)
        wrapper = P + "/logs/run_dc_stage1_noc16_wrapper.sh"
        body = """#!/bin/bash
cd {P}
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
echo "INFO: Stage1 NoC16 DC"
echo "INFO: local-generated ASYNC_DELAY_PROFILE={profile}"
grep -q 'module RouterL1WormholeMinimal' rtl/NoC_16nodes.v || {{ echo "ERROR: Stage1 RouterL1WormholeMinimal missing"; exit 1; }}
grep -q 'module RouterL2WormholeMinimal' rtl/NoC_16nodes.v || {{ echo "ERROR: Stage1 RouterL2WormholeMinimal missing"; exit 1; }}
rm -f outputs/NoC_16nodes_post_func.v outputs/NoC_16nodes_post_sdf.v
exec dc_shell-t -64 -f scripts/run_dc_noc16_t28ss.tcl
""".format(P=P, profile=profile)
        sftp = c.open_sftp()
        with sftp.file(wrapper, "w") as f:
            f.write(body)
        sftp.close()
        print(run(c, """
chmod +x {w}; sed -i 's/\\r$//' {w}
: > {P}/logs/dc_stage1_noc16.log; : > {P}/logs/dc_stage1_noc16.err
bsub -n 8 -o {P}/logs/dc_stage1_noc16.log -e {P}/logs/dc_stage1_noc16.err -J async_stage1_noc16_dc {w}
""".format(w=wrapper, P=P)))
        for i in range(90):
            time.sleep(60)
            text = run(c, """
bjobs -J async_stage1_noc16_dc 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: Stage1 NoC16 DC|INFO: async NoC_16nodes DC complete|ERROR: compile left unmapped|final GTECH|local-generated ASYNC_DELAY_PROFILE' {P}/logs/dc_stage1_noc16.log 2>/dev/null | tail -10
echo -n DEL=; grep -cE 'DEL[0-9]+D1BWP' {P}/outputs/NoC_16nodes_post.v 2>/dev/null
echo -n DEL250=; grep -cE 'DEL250D1BWP' {P}/outputs/NoC_16nodes_post.v 2>/dev/null
grep -E 'RouterL1WormholeMinimal|RouterL2WormholeMinimal' {P}/outputs/NoC_16nodes_post.v 2>/dev/null | head -4
ls -la --time-style=long-iso {P}/outputs/NoC_16nodes_post.v {P}/outputs/NoC_16nodes_dc.sdf {P}/outputs/NoC_16nodes.ddc {P}/outputs/NoC_16nodes_dc.sdc 2>/dev/null | awk '{{print $6,$7,$8,$9}}'
""".format(P=P))
            print("=== poll %d ===\n%s" % (i, text[-2000:]))
            if "INFO: async NoC_16nodes DC complete" in text:
                break
            if "ERROR: compile left unmapped" in text and "NO_JOB" in text:
                break
    finally:
        c.close()


if __name__ == "__main__":
    main()
