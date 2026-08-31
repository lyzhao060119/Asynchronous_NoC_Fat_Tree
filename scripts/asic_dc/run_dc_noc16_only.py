#!/usr/bin/env python3
"""Submit and poll NoC_16nodes DC only on SIC_C1."""
from __future__ import print_function

import os
import re
import time
from pathlib import Path

import paramiko

P = "/home/ghy19/Asynchronous_Router"
REPO = Path(__file__).resolve().parents[2]


def get_password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        text = doc.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"^[ \t-]*\u5bc6\u7801[:\uff1a][ \t]*(\S+)", text, re.M)
        if match:
            return match.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def main():
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
    wrapper = P + "/logs/run_dc_noc16_wrapper.sh"
    body = """#!/bin/bash
cd %s
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
exec dc_shell-t -64 -f scripts/run_dc_noc16_t28ss.tcl
""" % P
    sftp = c.open_sftp()
    with sftp.file(wrapper, "w") as f:
        f.write(body)
    sftp.close()
    _, o, e = c.exec_command(
        """
chmod +x {w}; sed -i 's/\\r$//' {w}
: > {P}/logs/dc_noc16.log; : > {P}/logs/dc_noc16.err
bsub -n 8 -o {P}/logs/dc_noc16.log -e {P}/logs/dc_noc16.err -J async_noc16_dc {w}
""".format(w=wrapper, P=P)
    )
    print(o.read().decode(errors="replace") + e.read().decode(errors="replace"))
    for i in range(80):
        _, o, e = c.exec_command(
            """
bjobs -J async_noc16_dc 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: async NoC_16nodes DC complete|ERROR: compile left unmapped|GTECH cell count after compile|final GTECH cell count' {P}/logs/dc_noc16.log 2>/dev/null | tail -8
echo -n DEL=; grep -cE 'DEL[0-9]+D1BWP' {P}/outputs/NoC_16nodes_post.v 2>/dev/null
ls -la --time-style=long-iso {P}/outputs/NoC_16nodes_post.v {P}/outputs/NoC_16nodes_dc.sdf {P}/outputs/NoC_16nodes.ddc {P}/outputs/NoC_16nodes_dc.sdc 2>/dev/null | awk '{{print $6,$7,$8,$9}}'
""".format(P=P)
        )
        text = o.read().decode(errors="replace") + e.read().decode(errors="replace")
        print("=== poll %d ===\n%s" % (i, text))
        if "INFO: async NoC_16nodes DC complete" in text:
            break
        if "ERROR: compile left unmapped" in text:
            break
        time.sleep(60)
    c.close()


if __name__ == "__main__":
    main()
