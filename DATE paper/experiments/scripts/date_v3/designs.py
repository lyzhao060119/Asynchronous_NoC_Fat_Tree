"""Load DATE V3 design JSON for network traffic materialize."""
from __future__ import annotations

import json
from typing import Any

from .paths import DESIGNS

from .display_names import display_name

ASYNC_NETWORK_IDS = (
    "THIN64",
    "PROP64",
    "PFAT64",
    "FM64",
    "PROP256",
    "FM256",
    "PROP1024",
    "HREP1024",
    "PROP1024_MESH1",
    "PROP1024_MESH2",
    "PROP1024_MESH4",
)

SYNC_NETWORK_IDS = (
    "SYNC_THIN64",
    "SYNC_PROP64",
)

NETWORK_IDS = ASYNC_NETWORK_IDS + SYNC_NETWORK_IDS

PAPER_NETWORK_IDS = (
    "THIN64",
    "PROP64",
    "PFAT64",
    "FM64",
    "SYNC_THIN64",
    "SYNC_PROP64",
    "PROP256",
    "FM256",
    "PROP1024",
    "HREP1024",
    "FM1024",
)

INDEPENDENT_NETLIST_IDS = (
    "THIN64",
    "PROP64",
    "PFAT64",
    "FM64",
    "SYNC_THIN64",
    "SYNC_PROP64",
    "PROP256",
    "FM256",
    "PROP1024",
    "FM1024",
)


def load_design(design_id: str) -> dict[str, Any]:
    path = DESIGNS / ("%s.json" % design_id.lower())
    if not path.is_file():
        raise KeyError("missing design %s" % design_id)
    return json.loads(path.read_text(encoding="utf-8"))


def design_display_name(design_id: str) -> str:
    try:
        design = load_design(design_id)
    except KeyError:
        return display_name(design_id)
    return design.get("display_name") or display_name(design_id)


def materialize_opts(design_id: str) -> dict[str, Any]:
    design = load_design(design_id)
    kind = design.get("kind")
    if kind != "network":
        raise ValueError("%s is %s, need a network DUT" % (design_id, kind))
    nodes = int(design["nodes"])
    routing = "mesh" if design.get("routing") == "mesh" else "quadtree"
    exposed_top = int(design.get("top_mesh_lanes") or 0)
    if nodes > 64:
        # Clustered and flat-mesh DUTs expose only core ports to the TB.
        exposed_top = 0
    return {
        "design_id": design_id,
        "nodes": nodes,
        "top_lanes": exposed_top,
        "hrep": bool(design.get("hrep_policy")),
        "routing": routing,
        "cluster_grid": design.get("cluster_grid") or (1 if routing != "mesh" else None),
        "async": bool(design.get("async", True)),
        "clock_ns": design.get("clock_ns"),
    }
