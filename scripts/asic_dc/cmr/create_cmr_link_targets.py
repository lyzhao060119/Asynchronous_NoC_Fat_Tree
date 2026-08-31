#!/usr/bin/env python3
"""Build step-G NoC link windows from paired STA.

Tctrl_min = Tdata_max * (1 + RTM)
Tctrl_max = Tctrl_min + extra_slack

Missing / near-floor Tdata stays 0 so the overlay measures on the seed and
skips.  Does not write production numbers by itself.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


NEAR_FLOOR_NS = 0.020
LINK_IDS = (
    "CMR-LINK-FWD-01",
    "CMR-LINK-ENQ-01",
    "CMR-LINK-ACK-01",
    "CMR-LINK-IO-01",
    "TCF-RD-01",
    "TCF-HS-02",
)


def _round_ns(value: float) -> float:
    return round(value, 3)


def _window(tdata: float, rtm: float, extra: float) -> tuple[float, float, bool]:
    if tdata <= 0.0 or tdata < NEAR_FLOOR_NS:
        return 0.0, 0.0, True
    tmin = _round_ns(tdata * (1.0 + rtm))
    tmax = _round_ns(tmin + extra)
    return tmin, tmax, False


def _tdata(summary: dict, rtc_id: str) -> float:
    info = summary.get("ids", {}).get(rtc_id, {})
    value = info.get("tdata_max_ns")
    if value is None:
        return 0.0
    return float(value)


def build_targets(summary: dict, rtm: float, extra: float, phase: str) -> dict:
    windows = {}
    for rtc_id in LINK_IDS:
        tdata = _tdata(summary, rtc_id)
        tmin, tmax, skip = _window(tdata, rtm, extra)
        windows[rtc_id] = {
            "tdata_max_ns": tdata,
            "required_min_ns": tmin,
            "required_max_ns": tmax,
            "measure_on_seed": skip or tdata <= 0.0,
            "near_floor": skip and tdata > 0.0,
        }
    return {
        "rtm_target": rtm,
        "extra_slack_ns": _round_ns(extra),
        "near_floor_ns": NEAR_FLOOR_NS,
        "phase": phase,
        "baseline_run": summary.get("baseline"),
        "sta_run": summary.get("run_id"),
        "windows": windows,
        "data_max_scale": 1.0,
        "note": (
            "Data max-delay freezes the measured cone (scale 1.0). "
            "Req min-delay uses 5% RTM. Ack is a separate control class."
        ),
    }


def emit_tcl(targets: dict) -> str:
    w = targets["windows"]
    lines = [
        "# Generated; do not edit. Step-G link data max / Req min windows.",
        "# RTM=%.3f extra_slack=%.3f ns phase=%s."
        % (targets["rtm_target"], targets["extra_slack_ns"], targets["phase"]),
        "# Source STA %s on %s."
        % (targets.get("sta_run"), targets.get("baseline_run")),
        "set CMR_LINK_RTM %.6f" % targets["rtm_target"],
        "set CMR_LINK_EXTRA_SLACK_NS %.3f" % targets["extra_slack_ns"],
        "set CMR_LINK_NEAR_FLOOR_NS %.3f" % targets["near_floor_ns"],
        "set CMR_LINK_PHASE %s" % targets["phase"],
    ]
    for rtc_id, info in w.items():
        key = rtc_id.replace("CMR-LINK-", "LINK_").replace("TCF-", "TCF_").replace("-", "_")
        lines.append("set CMR_%s_TDATA_NS %.6f" % (key, info["tdata_max_ns"]))
        lines.append("set CMR_%s_MIN_NS %.3f" % (key, info["required_min_ns"]))
        lines.append("set CMR_%s_MAX_NS %.3f" % (key, info["required_max_ns"]))
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sta-summary", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--rtm", type=float, default=0.05)
    parser.add_argument("--extra-slack", type=float, default=0.100)
    parser.add_argument(
        "--phase",
        default="all",
        choices=("datapath", "req", "ack", "all"),
    )
    args = parser.parse_args()
    if args.rtm < 0.0:
        raise SystemExit("rtm must be >= 0")
    if args.extra_slack < 0.0:
        raise SystemExit("extra-slack must be >= 0")
    summary = {}
    if args.sta_summary.is_file():
        summary = json.loads(args.sta_summary.read_text(encoding="utf-8"))
    targets = build_targets(summary, args.rtm, args.extra_slack, args.phase)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(emit_tcl(targets), encoding="utf-8")
    args.out.with_suffix(args.out.suffix + ".json").write_text(
        json.dumps(targets, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(targets, indent=2))


if __name__ == "__main__":
    main()
