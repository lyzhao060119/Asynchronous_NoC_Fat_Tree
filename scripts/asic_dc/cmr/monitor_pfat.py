#!/usr/bin/env python3
"""Poll remote LSF for the PFAT experiment: DC synthesis + functional sim jobs.

Covers both phases of the PFAT campaign:
  * synthesis jobs  cmr_hier_child/stitch_..._pfat..._tt_r1  (grouped by run id)
  * simulation jobs pf_<case>[_<pattern>]_<seed>            (grouped by case)

One stdout line per notable change (consumed by the Monitor tool).
"""
import os
import re
import sys
import time
from collections import Counter, OrderedDict

import paramiko

REPO = os.path.dirname(os.path.abspath(__file__))  # scripts/asic_dc/cmr
sys.path.insert(0, REPO)
from run_remote_cmr_flow import password  # noqa: E402

POLL = int(os.environ.get("MONITOR_POLL_SECONDS", "120"))
MAX_POLLS = int(os.environ.get("MONITOR_MAX_POLLS", "15"))
HEARTBEAT = 6  # emit at least every HEARTBEAT polls

VALID = ("PEND", "RUN", "DONE", "EXIT", "PSUSP", "USUSP", "SSUSP", "WAIT", "ZOMBI", "UNKWN")
RUN_ID_RE = re.compile(r"(20\d{6}_\d{6}_.*?_tt_r1)")
SEED_RE = re.compile(r"_\d{6}$")


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
    # stdout only: the login shell's module-load errors land on stderr and
    # would otherwise pollute the bjobs parse (grep only filters stdout).
    _, o, _e = c.exec_command(cmd)
    return o.read().decode(errors="replace")


def snapshot(c):
    out = run(
        c,
        "bjobs -a -noheader -o 'stat job_name' 2>/dev/null | grep -E 'pf_|pfat' || true",
    )
    groups = OrderedDict()
    for line in out.splitlines():
        p = line.split()
        if len(p) < 2:
            continue
        st, name = p[0], " ".join(p[1:])
        if st not in VALID:
            continue
        if "cmr_hier" in name:  # synthesis child/stitch
            mm = RUN_ID_RE.search(name)
            key = mm.group(1) if mm else name
            g = groups.setdefault(key, {"syn": True, "c": Counter(), "stitch": None})
            if "stitch" in name.lower():
                g["stitch"] = st
            else:
                g["c"][st] += 1
        else:  # pf_* functional sim job
            key = SEED_RE.sub("", name)
            g = groups.setdefault(key, {"syn": False, "c": Counter(), "stitch": None})
            g["c"][st] += 1
    return groups


def summarize(groups):
    parts = []
    for key, g in groups.items():
        c = ",".join("%s=%d" % kv for kv in sorted(g["c"].items())) or "none"
        s = ("syn" if g["syn"] else "sim") + "[" + c + "]"
        if g["stitch"]:
            s += " stitch=%s" % g["stitch"]
        parts.append("%s %s" % (key, s))
    return " | ".join(parts) or "(no pf jobs)"


def main():
    c = connect()
    last = None
    last_emit = -HEARTBEAT
    for poll in range(MAX_POLLS):
        try:
            groups = snapshot(c)
        except Exception as exc:  # noqa: BLE001
            print("poll%d: [reconnect] %s" % (poll, type(exc).__name__), flush=True)
            try:
                c = connect()
            except Exception:  # noqa: BLE001
                pass
            time.sleep(POLL)
            continue
        sig = summarize(groups)
        if sig != last or poll - last_emit >= HEARTBEAT:
            print("poll%d %s" % (poll, sig), flush=True)
            last = sig
            last_emit = poll
        time.sleep(POLL)
    c.close()


if __name__ == "__main__":
    main()
