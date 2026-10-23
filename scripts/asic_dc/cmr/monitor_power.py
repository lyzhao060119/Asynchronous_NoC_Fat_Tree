#!/usr/bin/env python3
"""Monitor the formal64 power "supplement" campaign on the remote LSF cluster.

Campaign root: /prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1
Three designs:
  FM64      = 64-node mesh        -> ALL-BROADCAST s202703 m5 re-measure (1 case)
  PROP_M16  = proposed M16        -> ALL-BROADCAST s202703 m5 re-measure (1 case)
  SYNC_M16  = synchronous baseline -> full 8-bench x 3-seed re-measure (24 cases)

Per-case pipeline and its ground-truth completion markers:
  act     activity.sh   -> activity/<tag>/stdout.log gets FORMAL64_POWER_ACTIVITY_PASS
  px      ptpx.py       -> logs/<tag>/ptpx.log gets FORMAL64_PTPX_CASE_PASS
  archive archive.py    -> activity/<tag>/measurement.vcd.archive.json appears

Emit one stdout line per notable change / heartbeat (consumed by the Monitor
tool).  Also surfaces the two hierarchical synthesis stitches that are still
running, since the user left them in place.
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

CAMP = "/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1"

# totals per design (derived from manifest.json jobs list)
TOTALS = {
    "FM64": int(os.environ.get("POWER_TOTAL_FM64", "1")),
    "PROP_M16": int(os.environ.get("POWER_TOTAL_PROP_M16", "1")),
    "SYNC_M16": int(os.environ.get("POWER_TOTAL_SYNC_M16", "24")),
}
TOTAL = sum(TOTALS.values())

DESIGNS = ("FM64", "PROP_M16", "SYNC_M16")


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


def tag_of(path):
    # .../activity/<tag>/<file> -> <tag>
    return path.rstrip("/").split("/")[-2]


def tags_of(lines):
    return sorted({tag_of(l) for l in lines.splitlines() if l.strip()})


def stage_counts(tags):
    by_design = {d: 0 for d in DESIGNS}
    for t in tags:
        for d in DESIGNS:
            if t.startswith(d + "_"):
                by_design[d] += 1
                break
    return by_design


def snapshot(c):
    # bjobs: power jobs by status (context only; history is purged)
    bj = run(
        c,
        "bjobs -a -noheader -o 'stat job_name' 2>/dev/null "
        "| grep -E 'p64|nr_gz|nr_px|sq_mesh_stitch|sq_m16_stitch' ",
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

    # ground-truth markers
    act = tags_of(
        run(c, "grep -rl 'FORMAL64_POWER_ACTIVITY_PASS' %s/activity/*/ 2>/dev/null" % CAMP)
    )
    px = tags_of(
        run(c, "grep -rl 'FORMAL64_PTPX_CASE_PASS' %s/logs/*/ 2>/dev/null" % CAMP)
    )
    arch = tags_of(
        run(c, "ls %s/activity/*/measurement.vcd.archive.json 2>/dev/null" % CAMP)
    )
    fail = tags_of(
        run(
            c,
            "grep -rl 'FORMAL64_POWER_ACTIVITY_FAIL' %s/activity/*/ %s/logs/*/ 2>/dev/null"
            % (CAMP, CAMP),
        )
    )
    return cnt, stitch, act, px, arch, fail


def fmt_cnt(cnt):
    return ",".join("%s=%d" % kv for kv in sorted(cnt.items())) or "none"


def fmt_stages(act, px, arch):
    return "act=%d/%d px=%d/%d arch=%d/%d" % (
        len(act), TOTAL, len(px), TOTAL, len(arch), TOTAL)


def main():
    if "--once" in sys.argv:
        c = connect()
        cnt, stitch, act, px, arch, fail = snapshot(c)
        print("%s jobs[%s] %s fail=%d"
              % (fmt_stages(act, px, arch), fmt_cnt(cnt),
                 " ".join("%s=%s" % kv for kv in sorted(stitch.items())) or "stitch=none",
                 len(fail)), flush=True)
        if fail:
            print("FAIL: " + ", ".join(fail), flush=True)
        c.close()
        return

    c = connect()
    last = None
    last_emit = -HEARTBEAT
    for poll in range(MAX_POLLS):
        try:
            cnt, stitch, act, px, arch, fail = snapshot(c)
        except Exception as exc:  # noqa: BLE001
            print("poll%d: [reconnect] %s" % (poll, type(exc).__name__), flush=True)
            try:
                c = connect()
            except Exception:  # noqa: BLE001
                pass
            time.sleep(POLL)
            continue
        sig = (tuple(sorted(cnt.items())), tuple(sorted(stitch.items())),
               tuple(act), tuple(px), tuple(arch), tuple(fail))
        if sig != last or poll - last_emit >= HEARTBEAT:
            print("poll%d %s jobs[%s] %s fail=%d"
                  % (poll, fmt_stages(act, px, arch), fmt_cnt(cnt),
                     " ".join("%s=%s" % kv for kv in sorted(stitch.items())) or "stitch=none",
                     len(fail)), flush=True)
            if fail:
                print("poll%d FAIL: %s" % (poll, ", ".join(fail)), flush=True)
            last = sig
            last_emit = poll
        time.sleep(POLL)
    c.close()


if __name__ == "__main__":
    main()
