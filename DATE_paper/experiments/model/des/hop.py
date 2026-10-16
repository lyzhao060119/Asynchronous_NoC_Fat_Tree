"""Isolated R-U5 hop: empty router, wait-for-rx, compare to MAXIMUM-SDF H/B/T."""

from __future__ import annotations

from typing import Any

from .sim import Simulator, packets_from_unicast
from .timing import KIND_GEOM, TimingTable
from .topology import isolated_hop_network

HOP_TOL_NS = 1e-9


def hop_rect(mesh: bool) -> tuple[int, int]:
    return (1, 0) if mesh else (8, 8)


def run_isolated_hop(kind: str, timing: TimingTable) -> dict[str, Any]:
    child, parent, mesh = KIND_GEOM[kind]
    async_design = not kind.startswith("sync_")
    net = isolated_hop_network(
        child=child,
        parent=parent,
        mesh=mesh,
        primitive_id=kind,
        async_design=async_design,
    )
    dx, dy = hop_rect(mesh)
    dest = dx + 8 * dy
    packets = packets_from_unicast(0, dest, 8, ready_cycle=0, flits=5)
    packets[0]["rect"] = [dx, dy, dx, dy]
    sim = Simulator(net, timing, arb_seed=1, case_tick_ns=0.0, wait_rx=True, t_limit=1e5)
    sim.load_packets(packets)
    result = sim.run()
    hops = [row for row in sim.hop_log if row["router"] == net.routers[next(iter(net.routers))].id]
    if len(hops) < 5:
        hops = sim.hop_log
    prim = timing.require(kind)
    measured = [None, None, None]
    if hops:
        measured[0] = hops[0]["hop_ns"]
        bodies = [row["hop_ns"] for row in hops[1:4]]
        measured[1] = sum(bodies) / len(bodies) if bodies else None
        if len(hops) >= 5:
            measured[2] = hops[4]["hop_ns"]
    expected = (prim.head_ns, prim.body_ns, prim.tail_ns)
    errors = list(result["errors"])
    leaked = sim.grants_leaked()
    if leaked:
        errors.extend(leaked)
    for name, got, exp in zip(("head", "body", "tail"), measured, expected):
        if got is None or abs(got - exp) > HOP_TOL_NS:
            errors.append("%s %s got %s expected %s" % (kind, name, got, exp))
    return {
        "kind": kind,
        "physical_class": prim.physical_class,
        "expected_ns": {"head": expected[0], "body": expected[1], "tail": expected[2]},
        "measured_ns": {"head": measured[0], "body": measured[1], "tail": measured[2]},
        "n_hops": len(hops),
        "errors": errors,
        "pass": not errors,
    }


def run_all_hops(timing: TimingTable | None = None) -> dict[str, Any]:
    table = timing or TimingTable()
    rows = []
    failed = []
    for kind in table.by_kind:
        if kind not in KIND_GEOM:
            continue
        row = run_isolated_hop(kind, table)
        rows.append(row)
        if not row["pass"]:
            failed.append(kind)
    return {
        "calibration_hash": table.file_hash,
        "physical_class": table.physical_class,
        "rows": rows,
        "failed": failed,
        "pass": not failed,
    }
