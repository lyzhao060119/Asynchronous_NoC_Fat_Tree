#!/usr/bin/env python3
"""Monitor remote M16 (PROPtemp1024M16) hierarchical DC synthesis.

The scaled-M16 flow synthesizes 352 unique router children (1024-node design,
routers deduplicated by the split emit), then a link-only top stitch.  The
mesh1024 phase (1024 children) is already complete and its stitch may still be
running, so we also surface stitch jobs for both kinds.

Progress = completed m16_c* output dirs (monotonic ground truth, not purged
like bjobs history).  Emits one stdout line per notable change / heartbeat.
"""
import os
import sys
import time
from collections import Counter

import paramiko

REPO = os.path.dirname(os.path.abspath(__file__))  # scripts/asic_dc/cmr
sys.path.insert(0, REPO)
from run_remote_cmr_flow import password  # noqa: E402

POLL = int(os.environ.get("MONITOR_POLL_SECONDS", "120"))
MAX_POLLS = int(os.environ.get("MONITOR_MAX_POLLS", "15"))
HEARTBEAT = 6
TOTAL = int(os.environ.get("MONITOR_M16_TOTAL", "352"))

CAMP = "~/Asynchronous_Router_CMR/campaigns/20261020_split1024_tt_r1"


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    return c


def run(c, cmd):
    _, o, _e = c.exec_command(cmd)
    return o.read().decode(errors="replace")


def snapshot(c):
    done = int(
        run(c, "ls %s/outputs/ 2>/dev/null | grep -cE 'm16_c'" % CAMP).strip() or 0
    )
    mx = run(
        c,
        "ls %s/outputs/ 2>/dev/null | grep -oE 'm16_c[0-9]+' "
        "| grep -oE '[0-9]+' | sort -n | tail -1" % CAMP,
    ).strip()
    max_c = int(mx) if mx.isdigit() else -1

    bj = run(
        c,
        "bjobs -a -noheader -o 'stat job_name' 2>/dev/null "
        "| grep -E 'sq_m16|stitch' ",
    )
    cnt = Counter()
    stitch = {}
    for line in bj.splitlines():
        p = line.split()
        if len(p) < 2:
            continue
        st, name = p[0], " ".join(p[1:])
        if "stitch" in name.lower():
            key = "m16_stitch" if "m16" in name.lower() else "mesh_stitch"
            stitch[key] = st
        else:
            cnt[st] += 1
    return done, max_c, cnt, stitch


def fmt_cnt(cnt):
    return ",".join("%s=%d" % kv for kv in sorted(cnt.items())) or "none"


def main():
    if "--once" in sys.argv:
        c = connect()
        done, max_c, cnt, stitch = snapshot(c)
        st = " ".join("%s=%s" % kv for kv in sorted(stitch.items())) or "stitch=none"
        print("m16_done=%d/%d (%.1f%%) max_c=%d jobs[%s] %s"
              % (done, TOTAL, 100.0 * done / TOTAL, max_c, fmt_cnt(cnt), st),
              flush=True)
        c.close()
        return

    c = connect()
    last = None
    last_emit = -HEARTBEAT
    for poll in range(MAX_POLLS):
        try:
            done, max_c, cnt, stitch = snapshot(c)
        except Exception as exc:  # noqa: BLE001
            print("poll%d: [reconnect] %s" % (poll, type(exc).__name__), flush=True)
            try:
                c = connect()
            except Exception:  # noqa: BLE001
                pass
            time.sleep(POLL)
            continue
        st = " ".join("%s=%s" % kv for kv in sorted(stitch.items())) or "stitch=none"
        sig = (done, max_c, tuple(sorted(cnt.items())), tuple(sorted(stitch.items())))
        if sig != last or poll - last_emit >= HEARTBEAT:
            print("poll%d m16_done=%d/%d (%.1f%%) max_c=%d jobs[%s] %s"
                  % (poll, done, TOTAL, 100.0 * done / TOTAL, max_c,
                     fmt_cnt(cnt), st), flush=True)
            last = sig
            last_emit = poll
        time.sleep(POLL)
    c.close()


if __name__ == "__main__":
    main()
