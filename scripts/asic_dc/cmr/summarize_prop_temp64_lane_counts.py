#!/usr/bin/env python3
"""Summarize measured PROP_temp64 parent-lane handshake counts."""
from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    groups: dict[tuple[int, int], list[int]] = {}
    with args.input.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 128:
        raise SystemExit(f"lane counter rows={len(rows)}, expected 128")
    for row in rows:
        key = (int(row["level"]), int(row["router"]))
        groups.setdefault(key, []).append(int(row["accepted_flits"]))
    output = []
    for (level, router), counts in sorted(groups.items()):
        if len(counts) != 4 or any(value < 0 for value in counts):
            raise SystemExit(f"invalid lane vector L{level} R{router}: {counts}")
        total = sum(counts); mean = total / 4
        square_sum = sum(value * value for value in counts)
        jain = total * total / (4 * square_sum) if square_sum else 0.0
        cv = math.sqrt(sum((value - mean) ** 2 for value in counts) / 4) / mean if mean else 0.0
        output.append({"level": level, "router": router, "lane0": counts[0],
                       "lane1": counts[1], "lane2": counts[2], "lane3": counts[3],
                       "total": total, "jain": jain, "cv": cv,
                       "maximum_lane_share": max(counts) / total if total else 0.0,
                       "unused_lane_count": sum(value == 0 for value in counts)})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(output[0]))
        writer.writeheader(); writer.writerows(output)
    print(f"CMR_LANE_SUMMARY_PASS routers={len(output)} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
