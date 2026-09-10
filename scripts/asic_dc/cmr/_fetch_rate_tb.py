#!/usr/bin/env python3
"""Download remote rate-scan TB for local repair."""
from __future__ import annotations

from pathlib import Path

import paramiko

HERE = Path(__file__).resolve().parent
OUT = HERE / "tb_cmr_router_rate_scan.sv"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/sim/tb/tb_cmr_router_rate_scan.sv"


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
    sftp = client.open_sftp()
    sftp.get(REMOTE, str(OUT))
    sftp.close()
    client.close()
    text = OUT.read_text(encoding="utf-8", errors="replace")
    print("DOWNLOADED", OUT, "lines", text.count("\n") + 1, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
