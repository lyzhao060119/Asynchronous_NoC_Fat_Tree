"""DATE V3 network DUT structure inventory (post-synthesis instance counts).

Mirrors `NoC.CMR.CMRNetworkInventory`.  PFAT L3 (4,8) hop PPA is signed.
Mesh4 is not elaborated: (4,2) is unsupported and 4-8 is not used as a stand-in.
"""
from __future__ import annotations

import json
from typing import Any

FLIT_WIDTH = 28
TILE = 8
L1, L2, L3 = 16, 4, 1
Q64 = L1 + L2 + L3


def port_count(child: int, parent: int) -> int:
    return 4 * child + parent


def adapters(child: int, parent: int) -> int:
    parent_dir = 4 * child if parent > 1 else 0
    child_dir = (4 * child * 3 + parent * 4) if child > 1 else 0
    return parent_dir + child_dir


def max_fanin(child: int, parent: int) -> int:
    return max(3 * child + parent, 4 * child)


def mutex_widths(child: int, parent: int) -> set[int]:
    lanes = {w for w in (child, parent) if w > 1}
    return {3 * child + parent, 4 * child} | lanes


def q64_links(l1_parent: int, l2_parent: int) -> int:
    return 2 * (L1 * l1_parent + L2 * l2_parent)


def geom(child: int, parent: int) -> dict[str, Any]:
    return {
        "child": child,
        "parent": parent,
        "ports": port_count(child, parent),
        "adapters": adapters(child, parent),
        "max_fanin": max_fanin(child, parent),
        "mutex": mutex_widths(child, parent),
    }


THIN = geom(1, 1)
FAT12 = geom(1, 2)
PROP22 = geom(2, 2)
PFAT24 = geom(2, 4)
PFAT48 = geom(4, 8)
TOP12 = geom(1, 2)
TOP22 = geom(2, 2)


def _q64(design_id: str, profile: str, l1: dict, l2: dict, l3: dict, notes: str = "") -> dict[str, Any]:
    ports = L1 * l1["ports"] + L2 * l2["ports"] + L3 * l3["ports"]
    adp = L1 * l1["adapters"] + L2 * l2["adapters"] + L3 * l3["adapters"]
    mutex = sorted(l1["mutex"] | l2["mutex"] | l3["mutex"])
    links = q64_links(l1["parent"], l2["parent"])
    return {
        "design_id": design_id,
        "nodes": 64,
        "lane_profile": profile,
        "routing": "quadtree",
        "cluster_grid": 1,
        "top_mesh_lanes": l3["parent"],
        "hrep_policy": False,
        "shares_netlist_with": None,
        "elaborated": True,
        "routers": Q64,
        "ipms": ports,
        "opms": ports,
        "ports": ports,
        "adapters": adp,
        "interlevel_fifos": 0,
        "core_ports": 64,
        "top_ports": l3["parent"],
        "inter_router_links": links,
        "channel_bits": links * FLIT_WIDTH,
        "max_opm_fanin": max(l1["max_fanin"], l2["max_fanin"], l3["max_fanin"]),
        "mutex_widths": mutex,
        "notes": notes,
    }


def clustered(cluster_grid: int, mesh_lanes: int, *, design_id: str, hrep: bool = False) -> dict[str, Any]:
    tiles = cluster_grid * cluster_grid
    nodes = tiles * 64
    if mesh_lanes == 2:
        top = TOP22
    elif mesh_lanes == 1:
        top = TOP12
    else:
        return {
            "design_id": design_id,
            "nodes": nodes,
            "lane_profile": "1-2-2-2",
            "routing": "quadtree_topmesh",
            "cluster_grid": cluster_grid,
            "top_mesh_lanes": mesh_lanes,
            "hrep_policy": hrep,
            "shares_netlist_with": "PROP1024" if hrep else None,
            "elaborated": False,
            "routers": tiles * Q64,
            "ipms": 0,
            "opms": 0,
            "ports": 0,
            "adapters": 0,
            "interlevel_fifos": 0,
            "core_ports": nodes,
            "top_ports": 0,
            "inter_router_links": 0,
            "channel_bits": 0,
            "max_opm_fanin": PROP22["max_fanin"],
            "mutex_widths": [],
            "notes": "Mesh%d needs TopMesh (%d,2), which is unsupported. Not elaborated." % (mesh_lanes, mesh_lanes),
        }
    l1, l2, l3 = FAT12, PROP22, PROP22
    tree_ports = tiles * (L1 * l1["ports"] + L2 * l2["ports"] + L3 * l3["ports"])
    ports = tree_ports + tiles * top["ports"]
    adp = tiles * (L1 * l1["adapters"] + L2 * l2["adapters"] + L3 * l3["adapters"]) + tiles * top["adapters"]
    links = (
        tiles * q64_links(l1["parent"], l2["parent"])
        + 4 * cluster_grid * (cluster_grid - 1) * mesh_lanes
        + 2 * tiles * 2
    )
    shares = None
    if hrep or design_id == "PROP1024_MESH2":
        shares = "PROP1024"
    return {
        "design_id": design_id,
        "nodes": nodes,
        "lane_profile": "1-2-2-2",
        "routing": "quadtree_topmesh",
        "cluster_grid": cluster_grid,
        "top_mesh_lanes": mesh_lanes,
        "hrep_policy": hrep,
        "shares_netlist_with": shares,
        "elaborated": True,
        "routers": tiles * Q64 + tiles,
        "ipms": ports,
        "opms": ports,
        "ports": ports,
        "adapters": adp,
        "interlevel_fifos": 0,
        "core_ports": nodes,
        "top_ports": 0,
        "inter_router_links": links,
        "channel_bits": links * FLIT_WIDTH,
        "max_opm_fanin": max(l1["max_fanin"], l2["max_fanin"], l3["max_fanin"], top["max_fanin"]),
        "mutex_widths": sorted(l1["mutex"] | l2["mutex"] | l3["mutex"] | top["mutex"]),
        "notes": "Same netlist as PROP1024; only the injection policy splits cross-cluster events." if hrep else "",
    }


def flat_mesh(n: int) -> dict[str, Any]:
    nodes = n * n
    ports = nodes * THIN["ports"]
    links = 4 * n * (n - 1)
    return {
        "design_id": "FM%d" % nodes,
        "nodes": nodes,
        "lane_profile": "mesh-1",
        "routing": "mesh",
        "cluster_grid": None,
        "top_mesh_lanes": 0,
        "hrep_policy": False,
        "shares_netlist_with": None,
        "elaborated": True,
        "routers": nodes,
        "ipms": ports,
        "opms": ports,
        "ports": ports,
        "adapters": 0,
        "interlevel_fifos": 0,
        "core_ports": nodes,
        "top_ports": 0,
        "inter_router_links": links,
        "channel_bits": links * FLIT_WIDTH,
        "max_opm_fanin": 4,
        "mutex_widths": [4],
        "notes": "",
    }


def all_duts() -> list[dict[str, Any]]:
    return [
        _q64("THIN64", "1-1-1-1", THIN, THIN, THIN),
        _q64("PROP64", "1-2-2-2", FAT12, PROP22, PROP22),
        _q64(
            "PFAT64",
            "1-2-4-8",
            FAT12,
            PFAT24,
            PFAT48,
            notes="L3 (4,8) hop PPA signed 20260831_cmr_pfat_l3_c4p8_del050_ackin050. Post-synthesis only.",
        ),
        flat_mesh(8),
        flat_mesh(16),
        flat_mesh(32),
        clustered(2, 2, design_id="PROP256"),
        clustered(4, 2, design_id="PROP1024"),
        clustered(4, 2, design_id="HREP1024", hrep=True),
        clustered(4, 1, design_id="PROP1024_MESH1"),
        clustered(4, 2, design_id="PROP1024_MESH2"),
        clustered(4, 4, design_id="PROP1024_MESH4"),
        _q64(
            "SYNC_THIN64",
            "1-1-1-1",
            THIN,
            THIN,
            THIN,
            notes="Sync Thin64; same instance counts as THIN64. Phase 2.5 1-cycle Head.",
        ),
        _q64(
            "SYNC_PROP64",
            "1-2-2-2",
            FAT12,
            PROP22,
            PROP22,
            notes="Sync PROP64; same instance counts as PROP64. Phase 2.5 1-cycle Head.",
        ),
    ]


def by_id() -> dict[str, dict[str, Any]]:
    return {row["design_id"]: row for row in all_duts()}


def dump_json() -> str:
    return json.dumps({"schema": "date-v3-network-inventory-v1", "duts": all_duts()}, indent=2) + "\n"
