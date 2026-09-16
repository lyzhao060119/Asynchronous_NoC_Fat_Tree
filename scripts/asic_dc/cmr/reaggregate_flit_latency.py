#!/usr/bin/env python3
"""Recompute full-drain flit latency for the DATE measurement cohort.

The legacy TB summary required both offer and egress to fall inside the
measurement window.  That right-censors precisely the slow flits that drain
after the window.  Raw latency/events files contain the full-drain timestamps,
so publication metrics can be recovered without rerunning accepted GLS cases.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path


def percentile(values: list[float], percent: int) -> float:
    if not values:
        raise ValueError("percentile of empty cohort")
    ordered = sorted(values)
    rank = math.ceil(percent * len(ordered) / 100)
    return ordered[max(0, rank - 1)]


def packet_events(latency_csv: Path) -> dict[int, int]:
    mapping: dict[int, int] = {}
    with latency_csv.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            packet = int(row["pkt_seq"])
            event = int(row["original_event_id"])
            old = mapping.setdefault(packet, event)
            if old != event:
                raise ValueError(f"pkt_seq {packet} maps to both {old} and {event}")
    if not mapping:
        raise ValueError(f"empty packet latency file: {latency_csv}")
    return mapping


def reaggregate(
    latency_csv: Path,
    flit_latency_csv: Path,
    warmup_events: int = 1000,
    measurement_events: int = 10000,
    packet_flits: int = 5,
) -> dict[str, int | float | str]:
    events = packet_events(latency_csv)
    end_event = warmup_events + measurement_events
    selected_packets = {pkt: event for pkt, event in events.items()
                        if warmup_events <= event < end_event}
    if len(selected_packets) != measurement_events:
        raise ValueError(f"measurement cohort has {len(selected_packets)} packets, expected {measurement_events}")
    if len(set(selected_packets.values())) != measurement_events:
        raise ValueError("measurement original event maps to duplicate packets")
    values: list[float] = []
    flits_per_packet: dict[int, int] = {pkt: 0 for pkt in selected_packets}
    with flit_latency_csv.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            packet = int(row["pkt_seq"])
            if packet not in events:
                raise ValueError(f"flit pkt_seq {packet} has no packet/event mapping")
            if warmup_events <= events[packet] < end_event:
                value = float(row.get("lat_ns", row.get("latency_ns", "")))
                if not math.isfinite(value) or value < 0:
                    raise ValueError(f"invalid flit latency {value}")
                values.append(value)
                flits_per_packet[packet] += 1
    expected = measurement_events * packet_flits
    if len(values) != expected:
        raise ValueError(f"measurement cohort has {len(values)} flits, expected {expected}")
    bad_packets = {pkt: count for pkt, count in flits_per_packet.items() if count != packet_flits}
    if bad_packets:
        sample = list(bad_packets.items())[:5]
        raise ValueError(f"measurement packets do not have {packet_flits} flits: {sample}")
    return {
        "metric_contract": "full_drain_measurement_offer_cohort_v1",
        "warmup_original_events": warmup_events,
        "measurement_original_events": measurement_events,
        "measurement_packets": len(selected_packets),
        "measurement_flits": len(values),
        "flit_latency_mean_ns": sum(values) / len(values),
        "flit_latency_p50_ns": percentile(values, 50),
        "flit_latency_p95_ns": percentile(values, 95),
        "flit_latency_p99_ns": percentile(values, 99),
        "flit_latency_max_ns": max(values),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("latency_csv", type=Path)
    parser.add_argument("flit_latency_csv", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = reaggregate(args.latency_csv, args.flit_latency_csv)
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
