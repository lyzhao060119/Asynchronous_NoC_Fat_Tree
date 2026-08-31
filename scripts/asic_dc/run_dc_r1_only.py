#!/usr/bin/env python3
"""Submit and poll RouterL1 DC only."""
from __future__ import print_function
import os
import time
import paramiko

P = "/home/ghy19/Asynchronous_Router"


def main():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("192.168.2.8", username="ghy19", password=os.environ["C1_PASS"],
              timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False)
    wrapper = P + "/logs/run_dc_routerl1_wrapper.sh"
    body = """#!/bin/bash
cd %s
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
exec dc_shell-t -64 -f scripts/run_dc_routerl1_t28ss.tcl
""" % P
    sftp = c.open_sftp()
    with sftp.file(wrapper, "w") as f:
        f.write(body)
    sftp.close()
    _, o, e = c.exec_command("""
chmod +x {w}; sed -i 's/\\r$//' {w}
: > {P}/logs/dc_routerl1.log; : > {P}/logs/dc_routerl1.err
bsub -n 8 -o {P}/logs/dc_routerl1.log -e {P}/logs/dc_routerl1.err -J async_routerl1_dc {w}
""".format(w=wrapper, P=P))
    print(o.read().decode() + e.read().decode())
    for i in range(90):
        time.sleep(20)
        _, o, _ = c.exec_command("""
bjobs -J async_routerl1_dc 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: async RouterL1 DC complete|ERROR: compile left unmapped|GTECH cell count after compile' {P}/logs/dc_routerl1.log 2>/dev/null | tail -5
echo -n DEL=; grep -cE 'DEL[0-9]+D1BWP' {P}/outputs/RouterL1_post.v 2>/dev/null
echo -n DEL075=; grep -cE 'DEL075D1BWP' {P}/outputs/RouterL1_post.v 2>/dev/null
echo -n DEL100=; grep -cE 'DEL100D1BWP' {P}/outputs/RouterL1_post.v 2>/dev/null
echo -n DEL150=; grep -cE 'DEL150D1BWP' {P}/outputs/RouterL1_post.v 2>/dev/null
echo -n DEL250=; grep -cE 'DEL250D1BWP' {P}/outputs/RouterL1_post.v 2>/dev/null
ls -la --time-style=long-iso {P}/outputs/RouterL1_post.v 2>/dev/null | awk '{{print $6,$7,$8}}'
""".format(P=P))
        text = o.read().decode(errors="replace")
        print("=== poll %d ===" % i)
        print(text[-800:])
        # Success line is unique; do not match TCL source "abort before write" string.
        if "INFO: async RouterL1 DC complete" in text:
            break
        if "ERROR: compile left unmapped" in text and "NO_JOB" in text:
            break
    c.close()


if __name__ == "__main__":
    main()
