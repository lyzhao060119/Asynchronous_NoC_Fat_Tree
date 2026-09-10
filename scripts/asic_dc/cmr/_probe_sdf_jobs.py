#!/usr/bin/env python3
"""One-shot probe of remote LSF / SDF / GLS activity for ghy19."""
from __future__ import annotations

import re
import sys
from pathlib import Path

import paramiko

REPO = Path(__file__).resolve().parents[3]
DOC = REPO / "docs" / "远程编译限制说明.md"
ROOT = "/home/ghy19/Asynchronous_Router_CMR"


def password() -> str:
    if "C1_PASS" in __import__("os").environ:
        return __import__("os").environ["C1_PASS"]
    text = DOC.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"^[ \t-]*密码[:：][ \t]*(\S+)", text, re.M)
    if not match:
        raise SystemExit("no password in docs")
    return match.group(1)


def run(client: paramiko.SSHClient, command: str) -> str:
    _, stdout, stderr = client.exec_command(command)
    return (stdout.read() + stderr.read()).decode(errors="replace")


def main() -> int:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    pw = password()
    try:
        client.connect(
            "192.168.2.8",
            username="ghy19",
            password=pw,
            timeout=40,
            banner_timeout=90,
            allow_agent=False,
            look_for_keys=False,
        )
    except Exception as exc:
        print("AUTH_FAIL", type(exc).__name__, exc, flush=True)
        # Fall back to last known-working password for monitoring only.
        try:
            client.connect(
                "192.168.2.8",
                username="ghy19",
                password="ghy19@2608",
                timeout=40,
                banner_timeout=90,
                allow_agent=False,
                look_for_keys=False,
            )
            print("AUTH_FALLBACK ghy19@2608", flush=True)
        except Exception as exc2:
            print("AUTH_FALLBACK_FAIL", type(exc2).__name__, exc2, flush=True)
            return 1

    print("=== BJOBS ===", flush=True)
    print(run(client, "bjobs -u ghy19 -w 2>&1 || true"), flush=True)

    print("=== BJOBS DETAIL ===", flush=True)
    print(run(client, "bjobs -u ghy19 -l 2>&1 | head -n 160 || true"), flush=True)

    print("=== PROCESSES ===", flush=True)
    print(
        run(
            client,
            "ps -u ghy19 -o pid,etime,pcpu,pmem,cmd --sort=-etime 2>/dev/null "
            "| egrep -i 'sdf|simv|vcs|dc_shell|router_rate|gls|hop_serial|await|mutex|CMRRouter' "
            "| head -n 50 || true",
        ),
        flush=True,
    )

    print("=== RECENT ROUTER_RATE ===", flush=True)
    print(
        run(
            client,
            "ls -lt %s/logs/router_rate 2>/dev/null | head -n 20 || true" % ROOT,
        ),
        flush=True,
    )

    print("=== RECENT GLS ===", flush=True)
    print(
        run(client, "ls -lt %s/logs/gls 2>/dev/null | head -n 15 || true" % ROOT),
        flush=True,
    )

    print("=== RECENT DC ===", flush=True)
    print(
        run(client, "ls -lt %s/logs/dc 2>/dev/null | head -n 15 || true" % ROOT),
        flush=True,
    )

    print("=== TAIL ACTIVE RUNLOGS ===", flush=True)
    print(
        run(
            client,
            "for d in $(ls -1dt %s/logs/router_rate/* 2>/dev/null | head -n 4); do "
            "echo ---- $d ----; "
            "ls -la \"$d\" 2>/dev/null | head -n 20; "
            "tail -n 30 \"$d/run.log\" 2>/dev/null || true; "
            "tail -n 20 \"$d/lsf.out\" 2>/dev/null || true; "
            "done" % ROOT,
        ),
        flush=True,
    )

    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
