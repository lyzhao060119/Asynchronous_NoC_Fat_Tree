#!/usr/bin/env python3
"""Normalize a PT-PX CMR Mesh report against TB_METRICS_V2 CSV data."""
from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


def watts(report: str, label: str) -> float:
    match = re.search(r"^\s*" + re.escape(label) + r"\s*=\s*([0-9.eE+-]+)\s*W", report, re.M)
    if not match:
        raise ValueError("missing %s in PT-PX report" % label)
    return float(match.group(1))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--result-csv", type=Path, required=True)
    ap.add_argument("--power-report", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    row = next(csv.DictReader(args.result_csv.open(encoding="utf-8")))
    start, end = int(row["measurement_start_ps"]), int(row["measurement_end_ps"])
    delivered = int(row["measurement_delivered_flits"])
    if end <= start:
        raise SystemExit("invalid TB_METRICS_V2 window")
    text = args.power_report.read_text(encoding="utf-8", errors="replace")
    internal = watts(text, "Cell Internal Power")
    switching = watts(text, "Net Switching Power")
    leakage = watts(text, "Cell Leakage Power")
    total = watts(text, "Total Power")
    seconds = (end - start) * 1e-12
    dynamic = internal + switching
    args.out.parent.mkdir(parents=True, exist_ok=True)
    copies = int(row.get("measurement_delivered_copies", "0"))
    events = int(row.get("measurement_original_events", "0"))
    with args.out.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=["window_start_ps", "window_end_ps", "delivered_flits", "delivered_copies", "original_events", "internal_w", "switching_w", "leakage_w", "dynamic_w", "total_w", "energy_dynamic_j_per_delivered_flit", "energy_total_j_per_delivered_flit", "energy_dynamic_j_per_delivered_copy", "energy_total_j_per_delivered_copy", "energy_dynamic_j_per_original_event", "energy_total_j_per_original_event"])
        writer.writeheader()
        def per(count: int, power: float) -> str | float:
            return power * seconds / count if count > 0 else ""
        writer.writerow({"window_start_ps": start, "window_end_ps": end, "delivered_flits": delivered, "delivered_copies": copies, "original_events": events, "internal_w": internal, "switching_w": switching, "leakage_w": leakage, "dynamic_w": dynamic, "total_w": total, "energy_dynamic_j_per_delivered_flit": per(delivered, dynamic), "energy_total_j_per_delivered_flit": per(delivered, total), "energy_dynamic_j_per_delivered_copy": per(copies, dynamic), "energy_total_j_per_delivered_copy": per(copies, total), "energy_dynamic_j_per_original_event": per(events, dynamic), "energy_total_j_per_original_event": per(events, total)})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
