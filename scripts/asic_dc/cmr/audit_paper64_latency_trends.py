#!/usr/bin/env python3
"""Audit load/latency trends without treating monotonicity as a pass gate."""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path


def ranks(values: list[float]) -> list[float]:
    order = sorted(range(len(values)), key=values.__getitem__)
    result = [0.0] * len(values)
    start = 0
    while start < len(order):
        end = start + 1
        while end < len(order) and values[order[end]] == values[order[start]]:
            end += 1
        rank = (start + end - 1) / 2.0 + 1.0
        for index in order[start:end]:
            result[index] = rank
        start = end
    return result


def spearman(xs: list[float], ys: list[float]) -> float:
    rx, ry = ranks(xs), ranks(ys)
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    numerator = sum((x - mx) * (y - my) for x, y in zip(rx, ry))
    denominator = math.sqrt(sum((x - mx) ** 2 for x in rx) * sum((y - my) ** 2 for y in ry))
    return numerator / denominator if denominator else 1.0


def audit_curve(rows: list[dict[str, str]], load_key: str, metric: str) -> dict:
    points = sorted(rows, key=lambda row: float(row[load_key]))
    decreases = []
    consecutive = 0
    max_consecutive = 0
    for previous, current in zip(points, points[1:]):
        old, new = float(previous[metric]), float(current[metric])
        if new < old:
            pct = 100.0 * (old - new) / old
            decreases.append({"from_load": previous[load_key], "to_load": current[load_key],
                              "from_value": old, "to_value": new, "decrease_percent": pct})
            consecutive += 1
            max_consecutive = max(max_consecutive, consecutive)
        else:
            consecutive = 0
    return {
        "points": len(points),
        "adjacent_decreases": len(decreases),
        "maximum_decrease_percent": max((row["decrease_percent"] for row in decreases), default=0.0),
        "maximum_consecutive_decreases": max_consecutive,
        "spearman_rho": spearman([float(row[load_key]) for row in points],
                                  [float(row[metric]) for row in points]),
        "soft_anomaly": any(row["decrease_percent"] > 5.0 for row in decreases) or max_consecutive >= 2,
        "decreases": decreases,
    }


def read(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ur", type=Path, required=True)
    parser.add_argument("--bc-hotspot", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    curves: dict[str, dict] = {}
    ur = read(args.ur)
    for design in sorted({row["design"] for row in ur}):
        selected = [row for row in ur if row["design"] == design and row["paper_latency_eligible"] == "True"]
        for metric in ("cohort_mean_ns", "cohort_p95_ns"):
            curves[f"TOPO-UR/{design}/{metric}"] = audit_curve(selected, "load_setpoint_mflit_per_port_s", metric)
    if args.bc_hotspot:
        other = read(args.bc_hotspot)
        for benchmark in sorted({row["benchmark"] for row in other}):
            for design in sorted({row["design"] for row in other if row["benchmark"] == benchmark}):
                selected = [row for row in other if row["benchmark"] == benchmark and
                            row["design"] == design and row["paper_latency_eligible"] == "True"]
                for metric in ("cohort_mean_ns", "cohort_p95_ns"):
                    curves[f"{benchmark}/{design}/{metric}"] = audit_curve(
                        selected, "load_setpoint_mflit_per_port_s", metric)
    result = {"contract": "trend_audit_not_acceptance_gate_v1", "soft_threshold_percent": 5.0,
              "curves": curves}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for name, row in curves.items():
        print("LATENCY_TREND", name, "points", row["points"], "decreases",
              row["adjacent_decreases"], "rho", f"{row['spearman_rho']:.6f}",
              "soft_anomaly", row["soft_anomaly"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
