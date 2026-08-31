#!/usr/bin/env python3
"""Poll the remote CMR fat-tree NoC16 SDF jobs and emit one line per state change.

Each stdout line is an event (consumed by the Monitor tool).  The script exits
when every tracked job reaches a terminal LSF state (DONE/EXIT/UNKWN) or when
the poll budget is exhausted.
"""
import os
import re
import shlex
import sys
import time
from pathlib import Path

import paramiko

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID", "20260821_cmr_ft_noc16_addrbuf_p50_sdf"
)
CASES = tuple(
    c.strip()
    for c in os.environ.get(
        "CMR_NOC16_CASES", "TAB-NET-UR-3f-r0p50,VCTM-MC5-NM-3f-r0p50"
    ).split(",")
    if c.strip()
)
POLL_SECONDS = int(os.environ.get("MONITOR_POLL_SECONDS", "60"))
MAX_POLLS = int(os.environ.get("MONITOR_MAX_POLLS", "120"))


def password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        m = re.search(
            r"^[ \t-]*密码[:：][ \t]*(\S+)",
            doc.read_text(encoding="utf-8", errors="replace"),
            re.M,
        )
        if m:
            return m.group(1)
    raise SystemExit("Set C1_PASS or add docs password entry")


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
        compress=True,
    )
    return c


def run(c, cmd):
    _, o, e = c.exec_command(cmd)
    return (o.read() + e.read()).decode(errors="replace")


def job_states(client):
    """Return {case: (state, jobid_or_None)}.  `-a` keeps EXIT jobs visible so
    a terminated (rather than finished) job is reported instead of GONE."""
    out = run(
        client,
        "bjobs -a -noheader -o 'jobid stat job_name' 2>/dev/null "
        "| grep '%s' || true" % shlex.quote(RUN_ID),
    )
    result = {case: ("GONE", None) for case in CASES}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        jobid, state, name = parts[0], parts[1], parts[2]
        for case in CASES:
            if name.endswith("_" + case):
                result[case] = (state, jobid)
    return result


def summarize_run_log(client, case):
    """Extract the meaningful tail markers from a case's run.log."""
    base = "%s/logs/gls/%s/sdf/%s" % (ROOT, RUN_ID, case)
    text = run(client, "cat %s/run.log 2>/dev/null" % base)
    violation_paths = re.findall(r"Timing violation in (\S+)", text)
    summary = {
        "exists": bool(text.strip()),
        "annotation_done": "Doing SDF annotation ...... Done" in text,
        "violations": text.count("Timing violation"),
        "rcu_latch_violations": len(
            [p for p in violation_paths if "AddressRegister" in p or "resettable_latch" in p]
        ),
        "first_violation_path": violation_paths[0] if violation_paths else None,
        "tb_pass": "TB_RESULT PASS" in text,
        "tb_fail": "TB_RESULT FAIL" in text,
        "x_fail": "TB_X_FAIL" in text,
        "finished": "$finish" in text,
    }
    m = re.search(r"TB_RESULT (PASS|FAIL).*", text)
    summary["tb_line"] = m.group(0).strip() if m else None
    return summary


def main():
    client = connect()
    seen = {}
    print("MONITOR_START run_id=%s cases=%s" % (RUN_ID, ",".join(CASES)), flush=True)
    for poll in range(MAX_POLLS):
        try:
            states = job_states(client)
        except (OSError, EOFError, paramiko.SSHException):
            print("MONITOR_RECONNECT poll=%d" % poll, flush=True)
            try:
                client.close()
            except Exception:
                pass
            client = connect()
            continue

        all_terminal = True
        for case in CASES:
            state, jid = states[case]
            try:
                summ = summarize_run_log(client, case)
            except (OSError, EOFError, paramiko.SSHException):
                summ = {"exists": False}
            key = (
                state,
                summ.get("annotation_done"),
                summ.get("violations"),
                summ.get("rcu_latch_violations"),
                summ.get("tb_pass"),
                summ.get("tb_fail"),
                summ.get("finished"),
                summ.get("tb_line"),
            )
            if key != seen.get(case):
                seen[case] = key
                verdict = (
                    "PASS"
                    if summ.get("tb_pass")
                    else "FAIL"
                    if summ.get("tb_fail")
                    else "?"
                )
                print(
                    "CASE %s state=%s job=%s verdict=%s annot=%s violations=%d "
                    "rcu_latch_violations=%d finished=%s x_fail=%s"
                    % (
                        case,
                        state,
                        jid,
                        verdict,
                        summ.get("annotation_done"),
                        summ.get("violations") or 0,
                        summ.get("rcu_latch_violations") or 0,
                        summ.get("finished"),
                        summ.get("x_fail"),
                    ),
                    flush=True,
                )
                if summ.get("first_violation_path"):
                    print(
                        "CASE %s first_violation: %s" % (case, summ["first_violation_path"]),
                        flush=True,
                    )
                if summ.get("tb_line"):
                    print("CASE %s result_line: %s" % (case, summ["tb_line"]), flush=True)

            # A purged job (GONE) whose run.log already shows $finish is final.
            terminal = state in ("DONE", "EXIT", "UNKWN") or (
                state == "GONE" and bool(summ.get("finished"))
            )
            if not terminal:
                all_terminal = False

        if all_terminal:
            print(
                "MONITOR_DONE all terminal: %s"
                % ", ".join("%s=%s" % (c, states[c][0]) for c in CASES),
                flush=True,
            )
            client.close()
            return

        time.sleep(POLL_SECONDS)

    print(
        "MONITOR_TIMEOUT after %d polls; last states: %s"
        % (MAX_POLLS, ", ".join("%s=%s" % (c, states[c][0]) for c in CASES)),
        flush=True,
    )
    client.close()


if __name__ == "__main__":
    main()
