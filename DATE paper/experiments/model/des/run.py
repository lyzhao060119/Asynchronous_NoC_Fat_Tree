"""Run a DATE V3 model-input trace through the calibrated DES."""

from __future__ import annotations

from typing import Any

from date_v3.designs import load_design, materialize_opts
from date_v3.hashutil import load_json

from .analytic import path_tmax_ns
from .compare import compare_event_to_oracle
from .sim import Simulator
from .timing import DEFAULT_CASE_TICK_NS, TimingTable, assert_locked_recipe
from .topology import build_network, inventory_delta


def simulate(
    design_id: str,
    packets: list[dict[str, Any]],
    *,
    timing: TimingTable | None = None,
    arb_seed: int = 1,
    case_tick_ns: float | None = None,
    wait_rx: bool = False,
) -> tuple[Simulator, dict[str, Any]]:
    design = load_design(design_id)
    assert_locked_recipe(design)
    table = timing or TimingTable()
    net = build_network(design, timing=table)
    tick = DEFAULT_CASE_TICK_NS if case_tick_ns is None else case_tick_ns
    sim = Simulator(net, table, arb_seed=arb_seed, case_tick_ns=tick, wait_rx=wait_rx)
    sim.load_packets(packets)
    result = sim.run()
    result["inventory_errors"] = inventory_delta(net)
    result["model_version"] = table.model_version
    return sim, result


def oracle_errors(design_id: str, packets: list[dict[str, Any]], records: list[dict[str, Any]]) -> list[str]:
    opts = materialize_opts(design_id)
    nodes = opts["nodes"]
    routing = opts["routing"]
    by_id = {rec["original_event_id"]: rec for rec in records}
    errors = []
    for packet in packets:
        rec = by_id.get(str(packet["original_event_id"]))
        if rec is None:
            errors.append("missing record %s" % packet["original_event_id"])
            continue
        errors.extend(
            compare_event_to_oracle(
                rec,
                nodes=nodes,
                routing=routing,
                source=int(packet["source"]),
                rect=list(packet["rect"]),
            )
        )
    return errors


def zero_load_analytic_errors(
    design_id: str,
    packets: list[dict[str, Any]],
    records: list[dict[str, Any]],
    *,
    timing: TimingTable,
    limit: float = 0.05,
    case_tick_ns: float = DEFAULT_CASE_TICK_NS,
) -> list[str]:
    from .topology import build_network
    from date_v3.designs import load_design, materialize_opts

    design = load_design(design_id)
    net = build_network(design, timing=timing)
    routing = materialize_opts(design_id)["routing"]
    by_id = {rec["original_event_id"]: rec for rec in records}
    errors = []
    for packet in packets:
        rec = by_id.get(str(packet["original_event_id"]))
        if rec is None or rec.get("tmax_ns") is None:
            errors.append("no tmax for %s" % packet["original_event_id"])
            continue
        pred = path_tmax_ns(
            net,
            timing,
            source=int(packet["source"]),
            rect=list(packet["rect"]),
            routing=routing,
            packet_flits=len(packet.get("flits") or [0] * 5),
            case_tick_ns=case_tick_ns,
        )
        if pred.get("tmax_ns") is None:
            errors.append(str(pred.get("error")))
            continue
        ref = float(pred["tmax_ns"])
        got = float(rec["tmax_ns"])
        if ref <= 0:
            continue
        if abs(got - ref) / ref > limit:
            errors.append(
                "%s tmax des=%.6f analytic=%.6f"
                % (packet["original_event_id"], got, ref)
            )
    return errors


def simulate_model_json(design_id: str, path, **kwargs: Any) -> dict[str, Any]:
    obj = load_json(path)
    packets = obj["packets"]
    sim, result = simulate(design_id, packets, **kwargs)
    result["oracle_errors"] = oracle_errors(design_id, packets, result["records"])
    result["trace_id"] = obj.get("trace_id")
    result["trace_hash"] = obj.get("trace_hash")
    del sim
    return result
