#!/usr/bin/env python3
"""DATE V3 Router-primitive geometries (post-synthesis DC + MAXIMUM-SDF + PT-PX).

Lane geometry and routing mode only.  Microarchitecture, DEL recipe, and the
Sync 1.0 ns clock are locked in CMR_Router_Structure_Freeze.md.  DATE V3 does
not run P&R.
"""
from __future__ import annotations

from typing import Any


def expected_adapters(child: int, parent: int) -> int:
    count = 0
    if parent > 1:
        count += 4 * child
    if child > 1:
        count += 4 * child * 3 + parent * 4
    return count


def expected_ports(child: int, parent: int) -> int:
    return 4 * child + parent


def expected_edges(child: int, parent: int) -> int:
    ports = expected_ports(child, parent)
    return ports * ports - (4 * child * child + parent * parent)


def max_opm_fanin(child: int, parent: int) -> int:
    child_fanin = 3 * child + parent
    parent_fanin = 4 * child
    return max(child_fanin, parent_fanin)


def emit_dirname(level: int, child: int, parent: int, *, mesh: bool) -> str:
    if mesh:
        return "router_l%d_c%d_p%d_mesh" % (level, child, parent)
    if (child, parent) == (1, 1):
        return "router_l%d" % level
    return "router_l%d_c%d_p%d" % (level, child, parent)


def emit_relpath(
    level: int,
    child: int,
    parent: int,
    *,
    mesh: bool,
    async_design: bool = True,
) -> str:
    root = "generated_cmr" if async_design else "generated_sync_cmr"
    return "%s/%s" % (root, emit_dirname(level, child, parent, mesh=mesh))


def vcs_define(child: int, parent: int) -> str:
    return "+define+GEOM_C%d_P%d" % (child, parent)


# V3 P0 / P0+ isolated Router ASIC targets.  Frozen 20260830 hop netlists are
# reused for Thin / Fat L1 / PROP 2x2; new run IDs are used for everything else.
PRIMITIVES: tuple[dict[str, Any], ...] = (
    {
        "kind": "async_thin_1x1",
        "aliases": ("thin_l1_1to1",),
        "design_id": "ASYNC_THIN_1X1",
        "async": True,
        "level": 1,
        "child": 1,
        "parent": 1,
        "mesh": False,
        "mutex_widths": frozenset({4}),
        "reuse_dc_id": "20260830_cmr_thin_l1_hop_del050_ackin050",
        "dc_id": "20260830_cmr_thin_l1_hop_del050_ackin050",
        "netlist_envs": ("CMR_THIN_L1_1TO1_NETLIST_RUN_ID", "CMR_THIN_NETLIST_RUN_ID"),
        "rx_default": "0.09",
        "dut": "CMRRouter",
        "paper_role": "Table I Thin / FM leaf datapath twin (quadtree Mat)",
    },
    {
        "kind": "async_flatmesh_1x1",
        "aliases": (),
        "design_id": "ASYNC_FLATMESH_1X1",
        "async": True,
        "level": 1,
        "child": 1,
        "parent": 1,
        "mesh": True,
        "mutex_widths": frozenset({4}),
        "reuse_dc_id": None,
        "dc_id": "20260831_cmr_flatmesh_c1p1_del050_ackin050",
        "netlist_envs": ("CMR_FLATMESH_NETLIST_RUN_ID",),
        "rx_default": "0.09",
        "dut": "CMRRouter",
        "paper_role": "Table I / FM leaf (mesh Mat)",
    },
    {
        "kind": "async_fat_1x2",
        "aliases": ("fat_l1_1to2",),
        "design_id": "ASYNC_FAT_1X2",
        "async": True,
        "level": 1,
        "child": 1,
        "parent": 2,
        "mesh": False,
        "mutex_widths": frozenset({2, 4, 5}),
        "reuse_dc_id": "20260830_cmr_fat_l1_hop_del050_ackin050",
        "dc_id": "20260830_cmr_fat_l1_hop_del050_ackin050",
        "netlist_envs": ("CMR_FAT_L1_1TO2_NETLIST_RUN_ID", "CMR_FAT_NETLIST_RUN_ID"),
        "rx_default": "0.1",
        "dut": "CMRRouter",
        "paper_role": "Table I PROP L1",
    },
    {
        "kind": "async_prop_2x2",
        "aliases": ("fat_l2_2to2",),
        "design_id": "ASYNC_PROP_2X2",
        "async": True,
        "level": 2,
        "child": 2,
        "parent": 2,
        "mesh": False,
        "mutex_widths": frozenset({2, 8}),
        "reuse_dc_id": "20260830_cmr_fat_l2_hop_del050_ackin050",
        "dc_id": "20260830_cmr_fat_l2_hop_del050_ackin050",
        "netlist_envs": ("CMR_FAT_L2_2TO2_NETLIST_RUN_ID", "CMR_PROP_2X2_NETLIST_RUN_ID"),
        "rx_default": "0.1",
        "dut": "CMRRouter",
        "paper_role": "Table I PROP L2/L3",
    },
    {
        "kind": "async_topmesh_2x2",
        "aliases": (),
        "design_id": "ASYNC_TOPMESH_2X2",
        "async": True,
        "level": 1,
        "child": 2,
        "parent": 2,
        "mesh": True,
        "mutex_widths": frozenset({2, 8}),
        "reuse_dc_id": None,
        "dc_id": "20260831_cmr_topmesh_c2p2_del050_ackin050",
        "netlist_envs": ("CMR_TOPMESH_NETLIST_RUN_ID",),
        "rx_default": "0.1",
        "dut": "CMRRouter",
        "paper_role": "Table I TopMesh2",
    },
    {
        "kind": "async_pfat_2x4",
        "aliases": ("fat_l2_2to4",),
        "design_id": "ASYNC_PFAT_2X4",
        "async": True,
        "level": 2,
        "child": 2,
        "parent": 4,
        "mesh": False,
        "mutex_widths": frozenset({2, 4, 8, 10}),
        "reuse_dc_id": None,
        "dc_id": "20260831_cmr_pfat_l2_c2p4_del050_ackin050",
        "netlist_envs": ("CMR_PFAT_2X4_NETLIST_RUN_ID",),
        "rx_default": "0.1",
        "dut": "CMRRouter",
        "paper_role": "Fig. A PFAT L2",
    },
    {
        "kind": "async_pfat_4x8",
        "aliases": ("fat_l3_4to8",),
        "design_id": "ASYNC_PFAT_4X8",
        "async": True,
        "level": 3,
        "child": 4,
        "parent": 8,
        "mesh": False,
        "mutex_widths": frozenset({4, 8, 16, 20}),
        "reuse_dc_id": None,
        "dc_id": "20260831_cmr_pfat_l3_c4p8_del050_ackin050",
        "netlist_envs": ("CMR_PFAT_4X8_NETLIST_RUN_ID",),
        "rx_default": "0.1",
        "dut": "CMRRouter",
        "paper_role": "Fig. A PFAT L3",
    },
    {
        "kind": "sync_thin_1x1",
        "aliases": (),
        "design_id": "SYNC_THIN_1X1",
        "async": False,
        "level": 1,
        "child": 1,
        "parent": 1,
        "mesh": False,
        "mutex_widths": frozenset(),
        "reuse_dc_id": None,
        "dc_id": "20260831_cmr_sync_thin_1x1_1p0ns",
        "netlist_envs": ("CMR_SYNC_THIN_NETLIST_RUN_ID",),
        "rx_default": "0.0",
        "dut": "SyncCmrRouter",
        "paper_role": "Table I Sync Thin counterpart",
    },
    {
        "kind": "sync_prop_2x2",
        "aliases": (),
        "design_id": "SYNC_PROP_2X2",
        "async": False,
        "level": 2,
        "child": 2,
        "parent": 2,
        "mesh": False,
        "mutex_widths": frozenset(),
        "reuse_dc_id": None,
        "dc_id": "20260831_cmr_sync_prop_2x2_1p0ns",
        "netlist_envs": ("CMR_SYNC_PROP_NETLIST_RUN_ID",),
        "rx_default": "0.0",
        "dut": "SyncCmrRouter",
        "paper_role": "Table I Sync 2x2 counterpart",
    },
)

# Extra emit-only aliases so L2/L3 Thin and PROP L3 stay geometry-checkable.
EMIT_ONLY: tuple[dict[str, Any], ...] = (
    {
        "kind": "async_thin_l2",
        "design_id": "ASYNC_THIN_1X1",
        "async": True,
        "level": 2,
        "child": 1,
        "parent": 1,
        "mesh": False,
        "mutex_widths": frozenset({4}),
        "dut": "CMRRouter",
    },
    {
        "kind": "async_thin_l3",
        "design_id": "ASYNC_THIN_1X1",
        "async": True,
        "level": 3,
        "child": 1,
        "parent": 1,
        "mesh": False,
        "mutex_widths": frozenset({4}),
        "dut": "CMRRouter",
    },
    {
        "kind": "async_prop_l3",
        "design_id": "ASYNC_PROP_2X2",
        "async": True,
        "level": 3,
        "child": 2,
        "parent": 2,
        "mesh": False,
        "mutex_widths": frozenset({2, 8}),
        "dut": "CMRRouter",
    },
)

KIND_INDEX: dict[str, dict[str, Any]] = {}
for _row in PRIMITIVES:
    KIND_INDEX[_row["kind"]] = _row
    for _alias in _row.get("aliases") or ():
        KIND_INDEX[_alias] = _row

HOP_PPA_RUN_ID = "20260831_cmr_primitive_hop_ppa_ru5"
DEFAULT_HOP_KINDS = tuple(row["kind"] for row in PRIMITIVES)


def enrich(row: dict[str, Any]) -> dict[str, Any]:
    child = int(row["child"])
    parent = int(row["parent"])
    filled = dict(row)
    filled["ports"] = expected_ports(child, parent)
    filled["adapters"] = expected_adapters(child, parent) if filled["async"] else 0
    filled["selectors"] = expected_adapters(child, parent) if not filled["async"] else 0
    filled["max_opm_fanin"] = max_opm_fanin(child, parent)
    filled["edges"] = expected_edges(child, parent)
    filled["emit_dir"] = emit_dirname(
        int(row["level"]), child, parent, mesh=bool(row["mesh"])
    )
    filled["emit_relpath"] = emit_relpath(
        int(row["level"]),
        child,
        parent,
        mesh=bool(row["mesh"]),
        async_design=bool(row["async"]),
    )
    filled["vcs_define"] = vcs_define(child, parent)
    filled["parent_base"] = 4 * child
    return filled


def all_primitives(*, include_emit_only: bool = False) -> list[dict[str, Any]]:
    rows = [enrich(dict(row)) for row in PRIMITIVES]
    if include_emit_only:
        rows.extend(enrich(dict(row)) for row in EMIT_ONLY)
    return rows


def lookup(kind: str) -> dict[str, Any]:
    if kind not in KIND_INDEX:
        raise KeyError("unknown primitive kind %s" % kind)
    return enrich(dict(KIND_INDEX[kind]))
