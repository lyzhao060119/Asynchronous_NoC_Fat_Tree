"""V3.1.0 human-facing English names.

Legacy design_id / benchmark_id / run_id strings stay as machine compatibility
keys.  Status output, figure titles, and documentation must use display_name.
Do not show DES, PROP, FM, H-REP, TOPO, XMC, or similar shorthand to users.
"""
from __future__ import annotations

from typing import Any

DISPLAY_NAMES: dict[str, str] = {
    "ASYNC_THIN_1X1": "Asynchronous narrow router primitive",
    "SYNC_THIN_1X1": "Synchronous narrow router primitive",
    "ASYNC_FAT_1X2": "Asynchronous balanced hierarchical level-1 router primitive",
    "ASYNC_PROP_2X2": "Asynchronous balanced hierarchical level-2/3 router primitive",
    "SYNC_PROP_2X2": "Synchronous balanced hierarchical router primitive",
    "ASYNC_PFAT_2X4": "Asynchronous progressively widened level-2 router primitive",
    "ASYNC_PFAT_4X8": "Asynchronous progressively widened level-3 router primitive",
    "ASYNC_TOPMESH_2X2": "Asynchronous two-lane top-mesh router primitive",
    "ASYNC_FLATMESH_1X1": "Asynchronous flat-mesh router primitive",
    "THIN64": "Asynchronous narrow hierarchical network, 64 nodes",
    "PROP64": "Asynchronous balanced hierarchical network, 64 nodes",
    "PFAT64": "Asynchronous progressively widened hierarchical network, 64 nodes",
    "FM64": "Asynchronous flat mesh network, 64 nodes",
    "SYNC_THIN64": "Synchronous narrow hierarchical network, 64 nodes",
    "SYNC_PROP64": "Synchronous balanced hierarchical network, 64 nodes",
    "FM256": "Asynchronous flat mesh network, 256 nodes",
    "PROP256": "Asynchronous balanced hierarchical network, 256 nodes",
    "FM1024": "Asynchronous flat mesh network, 1024 nodes",
    "PROP1024": "Asynchronous balanced hierarchical network, 1024 nodes",
    "HREP1024": (
        "Asynchronous balanced hierarchical network, 1024 nodes, "
        "boundary packet-replication comparison"
    ),
    "PROP1024_MESH1": (
        "Asynchronous balanced hierarchical network, 1024 nodes, "
        "single-lane top-mesh sanity (backup only)"
    ),
    "PROP1024_MESH2": (
        "Asynchronous balanced hierarchical network, 1024 nodes, "
        "two-lane top-mesh alias of the main 1024-node hierarchical netlist"
    ),
    "PROP1024_MESH4": (
        "Asynchronous balanced hierarchical network, 1024 nodes, "
        "four-lane top-mesh variation (unsupported)"
    ),
    "R-U5": "Isolated five-flit hop characterization",
    "BF-STRESS64": "64-node hierarchical-width stress traffic",
    "TOPO-UR": "Uniform random single-destination traffic, 64/256/1024 nodes",
    "XMC-F16": "1024-node fixed sixteen-destination cross-group multicast traffic",
    "XMC10-G": "1024-node mixed single-destination and multicast traffic",
    "MESH-INTERCLUSTER-UR": "1024-node inter-cluster single-destination sanity traffic (backup only)",
    "SNN-TRACE1024": "Frozen spiking-neural-network multicast trace replay, 1024 nodes (optional)",
}

DISPLAY_DESCRIPTIONS: dict[str, str] = {
    "THIN64": "64-node asynchronous hierarchical network with one lane on every tree level.",
    "PROP64": "64-node asynchronous hierarchical network with the locked 1-2-2-2 lane profile.",
    "PFAT64": "64-node asynchronous hierarchical network that widens upper-level lanes to 1-2-4-8.",
    "FM64": "8-by-8 asynchronous flat mesh of narrow routers.",
    "SYNC_THIN64": "Clocked 64-node narrow hierarchical counterpart of the asynchronous narrow 64-node network. Signed at 1.0 ns with a one-cycle head.",
    "SYNC_PROP64": "Clocked 64-node balanced hierarchical counterpart of the asynchronous balanced 64-node network. Signed at 1.0 ns with a one-cycle head.",
    "PROP256": "2-by-2 tiles of 64-node balanced hierarchical clusters plus a two-lane top mesh. No synchronous 256-node network is added.",
    "FM256": "16-by-16 asynchronous flat mesh. Compared with the 256-node hierarchical network at the same node count.",
    "PROP1024": "4-by-4 tiles of 64-node balanced hierarchical clusters plus a two-lane top mesh. No synchronous 1024-node network is added.",
    "FM1024": "32-by-32 asynchronous flat mesh. Compared with the 1024-node hierarchical network at the same node count.",
    "HREP1024": "Same gate netlist and delay file as the 1024-node balanced hierarchical network. Only the injection policy splits a cross-cluster multicast into unicast copies.",
    "PROP1024_MESH1": "Backup one-lane top-mesh sanity. Not a paper-matrix netlist.",
    "PROP1024_MESH2": "Alias of the main 1024-node balanced hierarchical netlist.",
    "PROP1024_MESH4": "Four-lane top mesh needs unsupported router geometry (4,2). Do not fabricate synthesis or delay-format results.",
    "BF-STRESS64": "64-node unicast whose destination is outside the source level-2 subtree, used to stress hierarchical width.",
    "TOPO-UR": "Uniform random unicast with source not equal to destination, applied at 64, 256, and 1024 nodes.",
    "XMC-F16": "Fixed fanout-16 multicast whose destinations cross cluster groups on the 1024-node hierarchical network.",
    "XMC10-G": "Mixed load: 90 percent unicast and 10 percent fanout-16 multicast on the 1024-node hierarchical network.",
    "SNN-TRACE1024": (
        "Optional replay of one frozen spiking-neural-network trace on the "
        "signed 1024-node hierarchical netlist and its boundary packet-replication policy."
    ),
}

# First-use definitions for method names that would otherwise appear as jargon.
METHOD_DEFINITIONS = {
    "logic_synthesis": (
        "Logic synthesis (Design Compiler) maps register-transfer-level Verilog "
        "to a standard-cell gate netlist and reports post-synthesis cell area and timing."
    ),
    "maximum_delay_sdf": (
        "Maximum-delay Standard Delay Format gate-level simulation annotates that "
        "netlist with the slow-corner maximum delays from synthesis. It does not "
        "prove place-and-route signoff."
    ),
    "software_event_model": (
        "The software event network simulator predicts load points and cross-checks "
        "delivery. It is not the source of 256-node or 1024-node paper numbers."
    ),
}

FORBIDDEN_DISPLAY_TOKENS = (
    "DES",
    "PROP",
    "PFAT",
    "H-REP",
    "HREP",
    "TOPO",
    "XMC",
    "FM64",
    "FM256",
    "FM1024",
    "SDF",
    "DC",
    "CMR",
    "Q64",
)


def display_name(key: str | None) -> str:
    if not key:
        return "-"
    return DISPLAY_NAMES.get(key, key)


def display_description(key: str | None) -> str:
    if not key:
        return ""
    return DISPLAY_DESCRIPTIONS.get(key, "")


def attach_display(obj: dict[str, Any]) -> dict[str, Any]:
    """Add display_name / display_description without changing machine ids."""
    key = obj.get("design_id") or obj.get("benchmark_id")
    if not key:
        return obj
    obj["display_name"] = display_name(key)
    description = display_description(key)
    if description:
        obj["display_description"] = description
    return obj


def format_status_row(manifest: dict[str, Any]) -> str:
    design_id = manifest.get("design_id")
    benchmark_id = manifest.get("benchmark_id")
    return "%s  %s  %s  paper=%s  class=%s" % (
        manifest.get("run_id"),
        display_name(design_id),
        display_name(benchmark_id) if benchmark_id else "-",
        manifest.get("paper_eligible"),
        manifest.get("physical_class"),
    )
