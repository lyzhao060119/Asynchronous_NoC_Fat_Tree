#!/usr/bin/env python3
from __future__ import annotations

import paramiko

ROOT = "/home/ghy19/Asynchronous_Router_CMR"


def main() -> int:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        "192.168.2.8",
        username="ghy19",
        password="ghy19@2608",
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    cmd = r"""
set -e
echo === NET ===
ls -la %(root)s/outputs/20260910_c1p2_awaitack_del150_dc/ | head
echo === TB ===
wc -l %(root)s/sim/tb/tb_cmr_router_rate_scan.sv
grep -nE 'probe_adapt|module tb|GEOM_C1|SEL_WAVE|EN_WAVE' %(root)s/sim/tb/tb_cmr_router_rate_scan.sv | head -n 100
echo === COMPILE_TAIL ===
tail -n 80 %(root)s/logs/router_rate/20260910_185400_c1p2_awaitack_probe2_m100/compile.log
echo === RUN_SH ===
cat %(root)s/logs/router_rate/20260910_185400_c1p2_awaitack_probe2_m100/run_sdf.sh
echo === LAST_RESULT ===
grep -E 'TB_RESULT|TB_FIRST|PPA_INFO|SIM_RC|TB_RATE|TB_INFO' %(root)s/logs/router_rate/20260910_184200_c1p2_awaitack_m100/run.log | head -n 50
echo === WORK_TB_ERR ===
sed -n '430,470p' %(root)s/sim/work/router_rate/20260910_185400_c1p2_awaitack_probe2_m100/tb_cmr_router_rate_scan.sv 2>/dev/null || true
""" % {
        "root": ROOT
    }
    _, out, err = client.exec_command(cmd)
    print((out.read() + err.read()).decode(errors="replace"))
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
