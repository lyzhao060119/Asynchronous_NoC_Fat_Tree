"""Compare DES records to route-oracle / RTL MAXIMUM-SDF with V3.0.2 thresholds."""

from __future__ import annotations

from typing import Any

from date_v3.event_record import measurement_records, run_metrics
from date_v3.route_oracle import traversal_for_packet
from date_v3.tmax import summarize_tmax

ZERO_LOAD_MEDIAN = 0.05
LOADED_MEAN = 0.10
SATURATION = 0.10
# 256 keycase is DelayElement_sim, not MAXIMUM-SDF.  Zero-load 5% Tmax
# vs post-synth hop tails is not applicable; delivery + loaded 10% still are.
RTL_KEYCASE_DESIGNS = frozenset({"PROP256", "FM256"})


def _as_set(values: Any) -> set[str]:
    return {str(item) for item in (values or [])}


def compare_event_to_oracle(
    rec: dict[str, Any],
    *,
    nodes: int,
    routing: str,
    source: int,
    rect: list[int],
) -> list[str]:
    trav = traversal_for_packet(source, rect, nodes=nodes, routing=routing)
    errors = []
    got_dest = set(rec.get("delivered_destinations") or [])
    exp_dest = set(trav.get("destinations") or [])
    if got_dest != exp_dest:
        errors.append("dest %s != oracle %s" % (sorted(got_dest), sorted(exp_dest)))
    if _as_set(rec.get("router_traversal")) != _as_set(trav.get("router_traversal")):
        errors.append(
            "routers %s != oracle %s"
            % (rec.get("router_traversal"), trav.get("router_traversal"))
        )
    exp_inj = int(trav.get("top_mesh_injection") or 0)
    got_inj = int(rec.get("top_mesh_injection") or 0)
    if got_inj != exp_inj:
        errors.append("top_mesh_injection %s != %s" % (got_inj, exp_inj))
    exp_links = int(trav.get("top_mesh_link_traversal") or 0)
    got_links = int(rec.get("top_mesh_link_traversal") or 0)
    if got_links != exp_links:
        errors.append("top_mesh_link_traversal %s != %s" % (got_links, exp_links))
    if trav.get("duplicate") or trav.get("loss") or trav.get("cycle"):
        errors.append("oracle flags duplicate/loss/cycle")
    return errors


def compare_delivery(des_records: list[dict[str, Any]], rtl_records: list[dict[str, Any]]) -> dict[str, Any]:
    """Event-exact destination sets (V3.0.2 §21). Traversal is compared via oracle on DES."""
    rtl_by = {str(rec["original_event_id"]): rec for rec in measurement_records(rtl_records)}
    errors = []
    matched = 0
    for rec in measurement_records(des_records):
        event_id = str(rec["original_event_id"])
        ref = rtl_by.get(event_id)
        if ref is None:
            errors.append("missing rtl event %s" % event_id)
            continue
        got = set(rec.get("delivered_destinations") or [])
        exp = set(ref.get("delivered_destinations") or rec.get("destination_set") or [])
        if got != exp:
            errors.append("dest %s des=%s rtl=%s" % (event_id, sorted(got), sorted(exp)))
        else:
            matched += 1
    return {
        "matched": matched,
        "rtl_events": len(rtl_by),
        "errors": errors,
        "pass": not errors,
    }


def rel_err(got: float | None, ref: float | None) -> float | None:
    if got is None or ref is None:
        return None
    if abs(ref) < 1e-15:
        return 0.0 if abs(got) < 1e-15 else float("inf")
    return abs(got - ref) / abs(ref)


def compare_tmax(
    des_records: list[dict[str, Any]],
    ref_records: list[dict[str, Any]],
    *,
    zero_load: bool,
) -> dict[str, Any]:
    des = summarize_tmax(
        [
            {"tmax_ns": rec["tmax_ns"]}
            for rec in measurement_records(des_records)
            if rec.get("tmax_ns") is not None
        ]
    )
    ref = summarize_tmax(
        [
            {"tmax_ns": rec["tmax_ns"]}
            for rec in measurement_records(ref_records)
            if rec.get("tmax_ns") is not None
        ]
    )
    limit = ZERO_LOAD_MEDIAN if zero_load else LOADED_MEAN
    key = "p50" if zero_load else "mean"
    err = rel_err(des.get(key), ref.get(key))
    return {
        "des": des,
        "ref": ref,
        "metric": key,
        "rel_err": err,
        "limit": limit,
        "pass": err is not None and err <= limit,
    }


def compare_throughput(des_metrics: dict[str, Any], rtl_metrics: dict[str, Any]) -> dict[str, Any]:
    err = rel_err(des_metrics.get("delivered_throughput"), rtl_metrics.get("delivered_throughput"))
    return {
        "des": des_metrics.get("delivered_throughput"),
        "ref": rtl_metrics.get("delivered_throughput"),
        "rel_err": err,
        "limit": LOADED_MEAN,
        "pass": err is not None and err <= LOADED_MEAN,
    }


def rtl_metrics_from_records(records: list[dict[str, Any]], summary: dict[str, Any] | None = None) -> dict[str, Any]:
    return run_metrics(records, v3_summary=summary)


def saturation_close(des_load: float | None, rtl_load: float | None, *, fine_step: float = 0.01) -> dict[str, Any]:
    if des_load is None or rtl_load is None:
        return {"pass": False, "reason": "missing saturation"}
    step_ok = abs(des_load - rtl_load) <= fine_step + 1e-12
    rel_ok = rel_err(des_load, rtl_load) is not None and rel_err(des_load, rtl_load) <= SATURATION
    return {
        "des": des_load,
        "ref": rtl_load,
        "pass": bool(step_ok or rel_ok),
        "limit_step": fine_step,
        "limit_rel": SATURATION,
    }
