#!/usr/bin/env python3
"""Monitor remote 1024-node mesh (32x32, split1024) hierarchical DC synthesis.

Progress = completed router output dirs in the campaign outputs/ dir
(ground truth, not purged like bjobs history).  Emits one stdout line per
notable change / heartbeat, consumed by the Monitor tool.
"""
import os
import re
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
TOTAL = int(os.environ.get("MONITOR_MESH_TOTAL", "1024"))

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
    # stdout only: login-shell module-load errors land on stderr.
    _, o, _e = c.exec_command(cmd)
    return o.read().decode(errors="replace")


def snapshot(c):
    # completed routers (monotonic ground truth)
    n = run(c, "ls %s/outputs/ 2>/dev/null | grep -cE 'mesh_c'" % CAMP).strip()
    done = int(n) if n.isdigit() else 0
    mx = run(
        c,
        "ls %s/outputs/ 2>/dev/null | grep -oE 'mesh_c[0-9]+' "
        "| grep -oE '[0-9]+' | sort -n | tail -1" % CAMP,
    ).strip()
    max_c = int(mx) if mx.isdigit() else -1

    # recent job statuses (bjobs history, best-effort context only)
    bj = run(
        c,
        "bjobs -a -noheader -o 'stat job_name' 2>/dev/null "
        "| grep -E 'sq_mesh|cmr_hier' ",
    )
    cnt = Counter()
    stitch = None
    for line in bj.splitlines():
        p = line.split()
        if len(p) < 2:
            continue
        st, name = p[0], " ".join(p[1:])
        if "stitch" in name.lower():
            stitch = st
        else:
            cnt[st] += 1
    return done, max_c, cnt, stitch


def fmt_cnt(cnt):
    return ",".join("%s=%d" % kv for kv in sorted(cnt.items())) or "none"


def main():
    if "--once" in sys.argv:
        c = connect()
        done, max_c, cnt, stitch = snapshot(c)
        print("done=%d/%d (%.1f%%) max_c=%d jobs[%s]%s"
              % (done, TOTAL, 100.0 * done / TOTAL, max_c, fmt_cnt(cnt),
                 (" stitch=%s" % stitch) if stitch else ""), flush=True)
        c.close()
        return
    c = connect()
    last_done = -1
    last_cnt = None
    last_stitch = None
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

        pct = 100.0 * done / TOTAL
        cnt_s = fmt_cnt(cnt)
        emit = False
        if last_done < 0:  # baseline
            emit = True
        if done > last_done:  # progress
            emit = True
        if cnt_s != last_cnt:
            emit = True
        if stitch != last_stitch:
            emit = True
        if poll - last_emit >= HEARTBEAT:
            emit = True

        if emit:
            last_emit = poll
            parts = [
                "poll%d" % poll,
                "done=%d/%d (%.1f%%)" % (done, TOTAL, pct),
                "max_c=%d" % max_c,
                "jobs[%s]" % cnt_s,
            ]
            if stitch:
                parts.append("stitch=%s" % stitch)
            print(" ".join(parts), flush=True)
            last_done = done
            last_cnt = cnt_s
            last_stitch = stitch
        time.sleep(POLL)
    c.close()


if __name__ == "__main__":
    main()
