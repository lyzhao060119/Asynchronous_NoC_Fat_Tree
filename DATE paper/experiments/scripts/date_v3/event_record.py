"""Assemble DATE V3 unified event records from 64/256 TB CSVs.

Tmax = last *intended* destination tail - source header injection.
Rectangle-fill extras (HW bounding box) are recorded as deliveries but
do not move Tmax.  Warm-up original events are dropped before paper
metrics.  Per-packet max latency is never used as Tmax.
H-REP split packets of one original event are merged: Top-Mesh
injection/link counts are summed; router/link sets are unioned.
"""
from __future__ import annotations

import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

from .tmax import summarize_tmax, tmax_ns

EVENT_RECORD_KEYS = (
    "original_event_id",
    "packet_id",
    "source",
    "destination_set",
    "t_offer",
    "t_head_inject",
    "t_last_tail",
    "delivered_destinations",
)


def _ps_to_ns(value: Any) -> float | None:
    if value in (None, "", "-1"):
        return None
    return float(value) / 1000.0


def _load_packets(packets_json: Path) -> dict[int, dict[str, Any]]:
    obj = json.loads(packets_json.read_text(encoding="utf-8"))
    return {int(row["pkt_seq"]): row for row in obj["packets"]}


def _tx_by_packet(event_csv: Path | None) -> dict[int, dict[str, Any]]:
    out: dict[int, dict[str, Any]] = {}
    if event_csv is None or not event_csv.is_file():
        return out
    with event_csv.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            if row.get("kind") != "TX":
                continue
            pkt = int(row["pkt_seq"])
            rec = out.setdefault(pkt, {"t_offer": None, "source": int(row["port"])})
            offer = _ps_to_ns(row.get("offer_ps"))
            if offer is not None and (rec["t_offer"] is None or offer < rec["t_offer"]):
                rec["t_offer"] = offer
    return out


def _unique_packets(metas: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    seen: set[int] = set()
    for meta in metas:
        key = int(meta["pkt_seq"])
        if key in seen:
            continue
        seen.add(key)
        out.append(meta)
    return out


def _merge_traversal(packets: list[dict[str, Any]]) -> dict[str, Any]:
    routers: list[str] = []
    links: list[str] = []
    seen_r: set[str] = set()
    seen_l: set[str] = set()
    inject = 0
    mesh_links = 0
    occupancy: dict[str, Any] = {}
    for meta in packets:
        tr = meta.get("traversal") or {}
        for name in tr.get("router_traversal") or []:
            if name not in seen_r:
                seen_r.add(name)
                routers.append(name)
        for name in tr.get("link_traversal") or []:
            if name not in seen_l:
                seen_l.add(name)
                links.append(name)
        inject += int(tr.get("top_mesh_injection") or 0)
        mesh_links += int(tr.get("top_mesh_link_traversal") or 0)
        for key, value in (meta.get("queue_occupancy") or {}).items():
            prev = occupancy.get(key)
            if prev is None:
                occupancy[key] = value
            else:
                try:
                    occupancy[key] = max(prev, value)
                except TypeError:
                    occupancy[key] = value
    return {
        "router_traversal": routers,
        "link_traversal": links,
        "top_mesh_injection": inject,
        "top_mesh_link_traversal": mesh_links,
        "queue_occupancy": occupancy,
    }


def assemble_event_records(
    *,
    packets_json: Path,
    latency_csv: Path | None = None,
    event_csv: Path | None = None,
    deliveries: Iterable[dict[str, Any]] | None = None,
    errors: Iterable[str] | None = None,
    include_warmup: bool = False,
) -> list[dict[str, Any]]:
    packets = _load_packets(packets_json)
    tx = _tx_by_packet(event_csv)
    by_event: dict[str, list[dict[str, Any]]] = defaultdict(list)
    dest_times: dict[str, dict[int, float]] = defaultdict(dict)
    head_inject: dict[str, float] = {}
    offer: dict[str, float] = {}

    rows = list(deliveries or [])
    if latency_csv is not None and latency_csv.is_file():
        with latency_csv.open(encoding="utf-8", newline="") as handle:
            rows.extend(csv.DictReader(handle))

    for row in rows:
        pkt_seq = int(row["pkt_seq"])
        meta = packets.get(pkt_seq)
        if meta is None:
            continue
        event_id = str(meta["original_event_id"])
        if (not include_warmup) and meta.get("phase") == "warmup":
            continue
        port = int(row["port"])
        if row.get("t_head_inject") not in (None, ""):
            t_head = float(row["t_head_inject"])
        else:
            t_head = _ps_to_ns(row.get("head_inject_req_ps"))
        if row.get("t_last_tail") not in (None, ""):
            t_tail = float(row["t_last_tail"])
        else:
            t_tail = _ps_to_ns(row.get("tail_egress_req_ps"))
        if t_head is not None:
            head_inject[event_id] = min(t_head, head_inject.get(event_id, t_head))
        if t_tail is not None:
            dest_times[event_id][port] = t_tail
        if pkt_seq in tx and tx[pkt_seq]["t_offer"] is not None:
            prev = offer.get(event_id)
            offer[event_id] = tx[pkt_seq]["t_offer"] if prev is None else min(prev, tx[pkt_seq]["t_offer"])
        by_event[event_id].append(meta)

    records = []
    for event_id, metas in sorted(by_event.items()):
        packets = _unique_packets(metas)
        meta0 = packets[0]
        intended = list(meta0.get("intended_destinations") or meta0.get("destinations") or [])
        arrived = dest_times[event_id]
        delivered = sorted(arrived)
        t_head = head_inject.get(event_id)
        if intended:
            tails = [arrived[port] for port in intended if port in arrived]
        else:
            tails = list(arrived.values())
        t_last = max(tails) if tails else None
        packet_ids = [m.get("packet_id") or ("%s#%s" % (event_id, m["pkt_seq"])) for m in packets]
        traversal = _merge_traversal(packets)
        rec = {
            "original_event_id": event_id,
            "packet_id": packet_ids[0] if len(packet_ids) == 1 else packet_ids,
            "source": int(meta0["source"]),
            "destination_set": intended,
            "t_offer": offer.get(event_id),
            "t_head_inject": t_head,
            "t_last_tail": t_last,
            "delivered_destinations": delivered,
            "router_traversal": traversal["router_traversal"],
            "link_traversal": traversal["link_traversal"],
            "top_mesh_injection": traversal["top_mesh_injection"],
            "top_mesh_link_traversal": traversal["top_mesh_link_traversal"],
            "queue_occupancy": traversal["queue_occupancy"],
            "errors": list(errors or []),
            "phase": meta0.get("phase", "measurement"),
            "tmax_ns": tmax_ns(t_last, t_head) if t_head is not None and t_last is not None else None,
        }
        missing = [d for d in intended if d not in arrived]
        if missing:
            rec["errors"] = list(rec["errors"]) + ["missing_dest:%s" % d for d in missing]
        records.append(rec)
    return records


def validate_event_record(rec: dict[str, Any], *, label: str = "event") -> None:
    missing = [key for key in EVENT_RECORD_KEYS if key not in rec]
    if missing:
        raise ValueError("%s missing %s" % (label, ", ".join(missing)))
    if rec.get("tmax_ns") is not None:
        expected = tmax_ns(rec["t_last_tail"], rec["t_head_inject"])
        if abs(float(rec["tmax_ns"]) - expected) > 1e-9:
            raise ValueError("%s tmax is not last_tail - head_inject" % label)


def dump_event_jsonl(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps(rec, sort_keys=True) for rec in records]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def measurement_records(records: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    return [rec for rec in records if rec.get("phase", "measurement") != "warmup"]


def _as_int(value: Any, default: int = 0) -> int:
    if value in (None, ""):
        return default
    return int(value)


def _as_bool(value: Any, default: bool = False) -> bool:
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    return str(value).strip().lower() not in ("0", "false", "no")


def run_metrics(
    records: list[dict[str, Any]],
    *,
    v3_summary: dict[str, Any] | None = None,
) -> dict[str, Any]:
    measured = measurement_records(records)
    tmax_rows = [
        {
            "original_event_id": rec["original_event_id"],
            "phase": rec.get("phase", "measurement"),
            "t_head_inject": rec.get("t_head_inject"),
            "t_last_tail": rec.get("t_last_tail"),
            "tmax_ns": rec.get("tmax_ns"),
        }
        for rec in measured
        if rec.get("tmax_ns") is not None
    ]
    summary = v3_summary or {}
    errors = _as_int(summary.get("errors"))
    for rec in measured:
        errors += len(rec.get("errors") or [])
    timed_out = _as_bool(summary.get("timeout"))
    missing = _as_int(summary.get("missing_flits"))
    drainable = _as_bool(summary.get("drainable"), default=errors == 0 and not timed_out)
    backlog_growth = _as_bool(summary.get("backlog_growth"))
    if timed_out or missing > 0:
        drainable = False
        backlog_growth = True
    heads = [rec["t_head_inject"] for rec in measured if rec.get("t_head_inject") is not None]
    tails = [rec["t_last_tail"] for rec in measured if rec.get("t_last_tail") is not None]
    window = (max(tails) - min(heads)) if heads and tails else None
    delivered = len(measured)
    return {
        "measurement_events": len(measured),
        "tmax": summarize_tmax(tmax_rows) if tmax_rows else summarize_tmax([]),
        "errors": errors,
        "drainable": drainable,
        "backlog_growth": backlog_growth,
        "delivered_throughput": (delivered / window) if window and window > 0 else 0.0,
        "mean_latency": summarize_tmax(tmax_rows)["mean"] if tmax_rows else None,
        "inflight_end": _as_int(summary.get("inflight_end")),
        "warmup_original_events": _as_int(summary.get("warmup_original_events")),
        "measurement_original_events": _as_int(summary.get("measurement_original_events")),
        "timeout": timed_out,
    }
