#!/usr/bin/env python3
"""Extract the observed Fig. 6 RCU relative-timing margin from a probe log."""
import argparse
import json
import re
from pathlib import Path


TRACE = re.compile(
    r"CMR_RCU_TRACE realtime_ns=([0-9.]+) dest=([0-9a-fA-FxX]+) "
    r"req_rc=([01xX]) ack_rc=([01xX]) matched_i=([01xX]) "
    r"bundling=([01xX]) mat=([01xX]+)"
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--target-rtm", type=float, default=10.0)
    args = parser.parse_args()

    events = []
    text = args.log.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        match = TRACE.search(line)
        if match:
            events.append((float(match[1]), *match.groups()[1:]))

    windows = []
    previous = None
    last_fall = 0.0
    for index, event in enumerate(events):
        time_ns, _dest, _req, _ack, _matched, bundling, mat = event
        if previous and previous[5] == "1" and bundling == "0":
            last_fall = time_ns
        if previous and previous[5] == "0" and bundling == "1" and time_ns > 1000.0:
            matched_index = index - 1
            while matched_index > 0 and events[matched_index][0] >= last_fall:
                if events[matched_index - 1][4] != events[matched_index][4] and events[matched_index][4] == "1":
                    break
                matched_index -= 1

            # Address and Req_rc latch outputs form a sub-100 ps launch cluster
            # in this post-DC SDF build.  Use its earliest observed transition
            # as the common data/control reference.
            launch_index = matched_index
            while (
                launch_index > 0
                and events[matched_index][0] - events[launch_index - 1][0] <= 0.100
                and events[launch_index - 1][0] >= last_fall
            ):
                launch_index -= 1

            mat_changes = [
                events[position][0]
                for position in range(max(1, launch_index), index + 1)
                if events[position][6] != events[position - 1][6]
            ]
            if mat_changes:
                launch = events[launch_index][0]
                mat_stable = mat_changes[-1]
                data_ps = (mat_stable - launch) * 1000.0
                control_ps = (time_ns - launch) * 1000.0
                margin_ps = (time_ns - mat_stable) * 1000.0
                windows.append({
                    "launch_ns": launch,
                    "mat_stable_ns": mat_stable,
                    "bundling_ns": time_ns,
                    "Tdata_ps": data_ps,
                    "Tcontrol_ps": control_ps,
                    "margin_ps": margin_ps,
                    "RTM_pct": 100.0 * margin_ps / data_ps,
                    "target_RTM_pct": args.target_rtm,
                })
        previous = event

    if not windows:
        raise SystemExit("no comparable RCU timing windows found")

    worst = min(windows, key=lambda row: row["RTM_pct"])
    result = {
        "source_log": str(args.log),
        "comparable_windows": len(windows),
        "worst_window": worst,
        "target_pass": worst["RTM_pct"] >= args.target_rtm,
        "tb_pass": "TB_RESULT PASS" in text,
    }
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
