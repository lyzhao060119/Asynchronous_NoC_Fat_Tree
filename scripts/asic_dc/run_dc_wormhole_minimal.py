#!/usr/bin/env python3
"""Upload and run RouterL1WormholeMinimal DC on SIC_C1.

Generate RTL locally before running this script, for example:
  ASYNC_PRIMITIVES=asic ASYNC_DELAY_PROFILE=STAGE1_SAFE \
    sbt "runMain Router_Architecture.instantiation.RouterL1WormholeMinimal"
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
GEN = REPO / "generated"
ASYNC = REPO / "src" / "main" / "resources" / "ASYNC"


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
    sftp = c.open_sftp()
    uploads = [
        (ASYNC / "DelayElement_ASIC.v", "%s/rtl/DelayElement_ASIC.v" % P),
        (ASYNC / "Mutex2_ASIC.v", "%s/rtl/Mutex2_ASIC.v" % P),
        (GEN / "RouterL1WormholeMinimal.v", "%s/rtl/RouterL1WormholeMinimal.v" % P),
        (ASIC_DC / "tech_t28ss.tcl", "%s/scripts/tech_t28ss.tcl" % P),
        (ASIC_DC / "async_primitives.tcl", "%s/scripts/async_primitives.tcl" % P),
        (ASIC_DC / "async_routerl1_t28.sdc", "%s/scripts/async_routerl1_t28.sdc" % P),
        (ASIC_DC / "assert_no_gtech.tcl", "%s/scripts/assert_no_gtech.tcl" % P),
        (ASIC_DC / "run_dc_wormhole_minimal_t28ss.tcl", "%s/scripts/run_dc_wormhole_minimal_t28ss.tcl" % P),
    ]
    for local, remote in uploads:
        if not Path(local).exists():
            raise SystemExit("missing local file: %s" % local)
        put(sftp, local, remote)
    sftp.close()
    print(run(c, "sed -i 's/\\r$//' {0}/scripts/*.tcl; ls -la {0}/rtl/RouterL1WormholeMinimal.v {0}/scripts/run_dc_wormhole_minimal_t28ss.tcl".format(P)))


def main():
    profile = os.environ.get("ASYNC_DELAY_PROFILE", "UNKNOWN")
    c = connect()
    try:
      upload(c)
      wrapper = P + "/logs/run_dc_wormhole_minimal_wrapper.sh"
      body = """#!/bin/bash
cd {P}
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
echo "INFO: local-generated ASYNC_DELAY_PROFILE={profile}"
exec dc_shell-t -64 -f scripts/run_dc_wormhole_minimal_t28ss.tcl
""".format(P=P, profile=profile)
      sftp = c.open_sftp()
      with sftp.file(wrapper, "w") as f:
          f.write(body)
      sftp.close()
      print(run(c, """
chmod +x {w}; sed -i 's/\\r$//' {w}
: > {P}/logs/dc_wormhole_minimal.log; : > {P}/logs/dc_wormhole_minimal.err
rm -f {P}/outputs/RouterL1WormholeMinimal_post_func.v {P}/outputs/RouterL1WormholeMinimal_post_sdf.v
bsub -n 8 -o {P}/logs/dc_wormhole_minimal.log -e {P}/logs/dc_wormhole_minimal.err -J async_wormhole_dc {w}
""".format(w=wrapper, P=P)))
      for i in range(90):
          time.sleep(20)
          text = run(c, """
bjobs -J async_wormhole_dc 2>/dev/null | head -3 || echo NO_JOB
grep -E 'INFO: async RouterL1WormholeMinimal DC complete|ERROR: compile left unmapped|final GTECH|local-generated ASYNC_DELAY_PROFILE' {P}/logs/dc_wormhole_minimal.log 2>/dev/null | tail -8
echo -n DEL=; grep -cE 'DEL[0-9]+D1BWP' {P}/outputs/RouterL1WormholeMinimal_post.v 2>/dev/null
echo -n DEL075=; grep -cE 'DEL075D1BWP' {P}/outputs/RouterL1WormholeMinimal_post.v 2>/dev/null
echo -n DEL100=; grep -cE 'DEL100D1BWP' {P}/outputs/RouterL1WormholeMinimal_post.v 2>/dev/null
echo -n DEL150=; grep -cE 'DEL150D1BWP' {P}/outputs/RouterL1WormholeMinimal_post.v 2>/dev/null
echo -n DEL250=; grep -cE 'DEL250D1BWP' {P}/outputs/RouterL1WormholeMinimal_post.v 2>/dev/null
ls -la --time-style=long-iso {P}/outputs/RouterL1WormholeMinimal_post.v {P}/outputs/RouterL1WormholeMinimal_dc.sdf {P}/outputs/RouterL1WormholeMinimal.ddc {P}/outputs/RouterL1WormholeMinimal_dc.sdc 2>/dev/null | awk '{{print $6,$7,$8,$9}}'
""".format(P=P))
          print("=== poll %d ===" % i)
          print(text[-1600:])
          if "INFO: async RouterL1WormholeMinimal DC complete" in text:
              break
          if "ERROR: compile left unmapped" in text and "NO_JOB" in text:
              break
    finally:
      c.close()


if __name__ == "__main__":
    main()
