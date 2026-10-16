"""DATE V3 multicast completion: Tmax = last dest tail - source header inject.

Tmin/Tavg are retained in raw records but are not paper-facing.
Warm-up original events are dropped before the measurement Tmax.
"""
from __future__ import annotations

import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable


def tmax_ns(t_last_tail: float, t_head_inject: float) -> float:
    return t_last_tail - t_head_inject


def tmax_by_original_event(
    rows: Iterable[dict[str, Any]],
    *,
    include_warmup: bool = False,
) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[str(row["original_event_id"])].append(row)
    out = []
    for event_id, items in grouped.items():
        phase = items[0].get("phase", "measurement")
        if phase == "warmup" and not include_warmup:
            continue
        heads = [float(item["t_head_inject"]) for item in items if item.get("t_head_inject") is not None]
        tails = [float(item["t_last_tail"]) for item in items if item.get("t_last_tail") is not None]
        if not heads or not tails:
            continue
        t_head = min(heads)
        t_last = max(tails)
        out.append(
            {
                "original_event_id": event_id,
                "phase": phase,
                "t_head_inject": t_head,
                "t_last_tail": t_last,
                "tmax_ns": tmax_ns(t_last, t_head),
                "destination_count": len(items),
            }
        )
    out.sort(key=lambda row: row["original_event_id"])
    return out


def summarize_tmax(records: list[dict[str, Any]]) -> dict[str, float | None]:
    values = sorted(row["tmax_ns"] for row in records)
    if not values:
        return {"count": 0, "mean": None, "p50": None, "p95": None, "p99": None, "max": None}
    def pct(p: float) -> float:
        idx = min(len(values) - 1, max(0, int(round(p * (len(values) - 1)))))
        return values[idx]
    return {
        "count": len(values),
        "mean": sum(values) / len(values),
        "p50": pct(0.50),
        "p95": pct(0.95),
        "p99": pct(0.99),
        "max": values[-1],
    }


def rows_from_latency_csv(
    latency_csv: Path,
    packets_json: Path,
    *,
    intended_only: bool = True,
) -> list[dict[str, Any]]:
    packets = json.loads(packets_json.read_text(encoding="utf-8"))["packets"]
    by_seq = {int(row["pkt_seq"]): row for row in packets}
    rows = []
    with latency_csv.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for line in reader:
            pkt_seq = int(line["pkt_seq"])
            meta = by_seq.get(pkt_seq)
            if meta is None:
                continue
            port = int(line["port"])
            if intended_only and port not in set(meta.get("intended_destinations") or []):
                continue
            t_head = line.get("head_inject_req_ps") or line.get("head_ingress_ack_ps")
            t_tail = line.get("tail_egress_req_ps")
            rows.append(
                {
                    "original_event_id": meta["original_event_id"],
                    "phase": meta.get("phase", "measurement"),
                    "port": port,
                    "t_head_inject": float(t_head) / 1000.0 if t_head not in (None, "") else None,
                    "t_last_tail": float(t_tail) / 1000.0 if t_tail not in (None, "") else None,
                }
            )
    return rows
