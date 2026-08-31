#!/usr/bin/env python3
"""Fetch one diagnostic log without starting a new remote job."""
import sys

from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: fetch_remote_cmr_log.py REMOTE_PATH")
    client = connect()
    try:
        print(remote_run(client, "cat " + sys.argv[1]))
    finally:
        client.close()


if __name__ == "__main__":
    main()
