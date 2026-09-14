#!/usr/bin/env python3
"""Parse CMR WritePointer STA reports into SDC-ready nanosecond bounds."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SUMMARY = re.compile(
    r"CMR_WP_RTM ptr_max_ns=(\S+) ptr_min_ns=(\S+) "
    r"req_to_ck_max_ns=(\S+) req_to_ck_min_ns=(\S+) "
    r"ack_to_ck_max_ns=(\S+) ack_to_ck_min_ns=(\S+) "
    r"head_to_d_max_ns=(\S+)"
)
ARRIVAL = re.compile(r"data arrival time\s+([0-9.]+)")
PULSE_FLOOR_NS = 0.080
TREQ_INTERNAL_NS = 1.0


def _num(value: str) -> float | None:
    if value in ("NA", "inf", "") or value.startswith("$"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _arrivals(path: Path) -> list[float]:
    if not path.is_file():
        return []
    return [float(match) for match in ARRIVAL.findall(path.read_text(encoding="utf-8", errors="replace"))]


def recommend(ptr_max: float | None, req_min: float | None, ack_max: float | None) -> dict:
    # Keep the pointer from getting slower than the measured worst path, with
    # an 80 ps library floor.  Do not aggressively cut an already-short path.
    if ptr_max is None:
        ptr_max_ns = 0.200
    else:
        ptr_max_ns = max(ptr_max, PULSE_FLOOR_NS)
    # Stretch complete falling: Reqin must reach CK after Ackout, plus pulse.
    ack = ack_max if ack_max is not None else 0.0
    req_to_ck_min_ns = max(ack + PULSE_FLOOR_NS, req_min or 0.0, PULSE_FLOOR_NS)
    ptr_ok = ptr_max is not None and (ptr_max + PULSE_FLOOR_NS) < TREQ_INTERNAL_NS
    primary = "HS-02" if ptr_ok else "WP-01"
    return {
        "WP_PTR_MAX_NS": round(ptr_max_ns, 4),
        "WP_REQ_TO_CK_MIN_NS": round(req_to_ck_min_ns, 4),
        "WP_PULSE_NS": PULSE_FLOOR_NS,
        "primary_rtc": primary,
        "ptr_plus_setup_lt_1ns": ptr_ok,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report_dir", type=Path)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    summary = {}
    log_text = ""
    if args.log and args.log.is_file():
        log_text = args.log.read_text(encoding="utf-8", errors="replace")
        for match in SUMMARY.finditer(log_text):
            keys = (
                "ptr_max_ns", "ptr_min_ns", "req_to_ck_max_ns", "req_to_ck_min_ns",
                "ack_to_ck_max_ns", "ack_to_ck_min_ns", "head_to_d_max_ns",
            )
            parsed = {key: _num(value) for key, value in zip(keys, match.groups())}
            if parsed["ptr_max_ns"] is not None:
                summary = parsed

    report_arrivals = {
        "ptr_max": _arrivals(args.report_dir / "ptr_max.rpt"),
        "ptr_min": _arrivals(args.report_dir / "ptr_min.rpt"),
        "req_to_ck_max": _arrivals(args.report_dir / "req_to_ck_max.rpt"),
        "req_to_ck_min": _arrivals(args.report_dir / "req_to_ck_min.rpt"),
        "ack_to_ck_max": _arrivals(args.report_dir / "ack_to_ck_max.rpt"),
        "ack_to_ck_min": _arrivals(args.report_dir / "ack_to_ck_min.rpt"),
        "head_to_d_max": _arrivals(args.report_dir / "hs01_head_to_d_max.rpt"),
    }

    def pick(summary_key: str, report_key: str, how) -> float | None:
        values = report_arrivals[report_key]
        if values:
            return how(values)
        return summary.get(summary_key)

    measured = {
        "ptr_max_ns": pick("ptr_max_ns", "ptr_max", max),
        "ptr_min_ns": pick("ptr_min_ns", "ptr_min", min),
        "req_to_ck_max_ns": pick("req_to_ck_max_ns", "req_to_ck_max", max),
        "req_to_ck_min_ns": pick("req_to_ck_min_ns", "req_to_ck_min", min),
        "ack_to_ck_max_ns": pick("ack_to_ck_max_ns", "ack_to_ck_max", max),
        "ack_to_ck_min_ns": pick("ack_to_ck_min_ns", "ack_to_ck_min", min),
        "head_to_d_max_ns": pick("head_to_d_max_ns", "head_to_d_max", max),
    }
    bounds = recommend(
        measured["ptr_max_ns"],
        measured["req_to_ck_min_ns"],
        measured["ack_to_ck_max_ns"],
    )
    result = {
        "report_dir": str(args.report_dir),
        "measured_ns": measured,
        "sdc": bounds,
        "treq_internal_ns": TREQ_INTERNAL_NS,
        "structure": next(
            (line.strip() for line in log_text.splitlines() if line.startswith("CMR_WP_RTM_STRUCTURE")),
            "",
        ),
    }
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
