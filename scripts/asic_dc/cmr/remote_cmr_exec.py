#!/usr/bin/env python3
"""Run one read-only remote diagnostic command."""
import sys

from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run


if len(sys.argv) < 2:
    raise SystemExit("usage: remote_cmr_exec.py COMMAND")
command = " ".join(sys.argv[1:])
client = connect()
try:
    print(remote_run(client, command))
finally:
    client.close()
