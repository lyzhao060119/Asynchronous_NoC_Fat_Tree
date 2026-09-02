"""Zero-load wormhole Tmax from post-synthesis hop times along the oracle path."""

from __future__ import annotations

from typing import Any

from date_v3.route_oracle import traversal_for_packet

from .timing import TimingTable
from .topology import Network


def path_tmax_ns(
    net: Network,
    timing: TimingTable,
    *,
    source: int,
    rect: list[int],
    routing: str,
    packet_flits: int = 5,
    case_tick_ns: float = 0.0,
) -> dict[str, Any]:
    trav = traversal_for_packet(source, rect, nodes=net.nodes, routing=routing)
    routers = list(trav.get("router_traversal") or [])
    if not routers:
        return {"tmax_ns": None, "routers": [], "error": "empty path"}
    heads = []
    tails = []
    last_body = last_tail = None
    for name in routers:
        spec = net.routers.get(name)
        if spec is None:
            return {"tmax_ns": None, "routers": routers, "error": "missing %s" % name}
        prim = timing.require(spec.primitive_id)
        heads.append(prim.head_ns)
        tails.append(prim.tail_ns)
        last_body = prim.body_ns
        last_tail = prim.tail_ns
    bodies = max(0, packet_flits - 2)
    if case_tick_ns > 1e-12:
        # TB spaces flits by CASE_TICK_NS.  At 20 ns the Head has already
        # drained the path, so Tail pays per-hop tail_ns after the last inject.
        tmax = (packet_flits - 1) * case_tick_ns + sum(tails)
    else:
        tmax = sum(heads) + bodies * float(last_body) + float(last_tail)
    return {
        "tmax_ns": tmax,
        "routers": routers,
        "sum_head_ns": sum(heads),
        "sum_tail_ns": sum(tails),
        "last_body_ns": last_body,
        "last_tail_ns": last_tail,
        "case_tick_ns": case_tick_ns,
        "traversal": trav,
    }
