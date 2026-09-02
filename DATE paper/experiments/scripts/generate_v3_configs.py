#!/usr/bin/env python3
"""Write frozen DATE V3.2.0 design / benchmark / seed / plan JSON files.

Machine identifiers are unchanged from V3.0.2. Display names are complete English.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from date_v3.display_names import attach_display  # noqa: E402

DESIGNS = ROOT / "configs" / "designs"
BENCHMARKS = ROOT / "configs" / "benchmarks"
SEEDS = ROOT / "configs" / "seeds"
PLANS = ROOT / "configs" / "plans"

LOCKED = {
    "rcu_steps": 1,
    "rcu_unit_ps": 50,
    "buf_stages": 0,
    "ackin_steps": 1,
    "ackin_unit_ps": 50,
    "ackin_use_buf": False,
}


def dump(path: Path, obj: dict) -> None:
    attach_display(obj)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def primitive(
    design_id: str,
    family: str,
    level: int,
    child: int,
    parent: int,
    *,
    mesh: bool,
    async_design: bool,
    adapters: int,
    ports: int,
    max_fanin: int,
    mutex: list[int],
    paper_role: str,
    adapter: str = "dc_cmr_router",
    clock_ns=None,
) -> dict:
    return {
        "schema": "date-v3-design-v1",
        "design_id": design_id,
        "kind": "router_primitive",
        "family": family,
        "nodes": None,
        "async": async_design,
        "routing": "mesh" if mesh else "quadtree",
        "lane_profile": "%d-%d" % (child, parent),
        "top_mesh_lanes": None,
        "cluster_grid": None,
        "router_primitives": [
            {
                "primitive_id": design_id.lower(),
                "level": level,
                "child_lanes": child,
                "parent_lanes": parent,
                "use_mesh_routing": mesh,
                "count": 1,
            }
        ],
        "expected_structure": {
            "routers": 1,
            "ports": ports,
            "adapters": adapters,
            "interlevel_fifos": 0,
            "top_ports": 0,
            "max_opm_fanin": max_fanin,
            "mutex_widths": mutex,
        },
        "flit_width_bits": 28,
        "buffer_slots": 5,
        "no_uturn": True,
        "interlevel_fifo": "n/a",
        "delay_recipe": dict(LOCKED),
        "clock_ns": clock_ns,
        "hrep_policy": False,
        "shares_netlist_with": None,
        "adapter": adapter,
        "paper_role": paper_role,
        "paper_eligible_default": True,
        "notes": "Table I / calibration primitive. Same CMR microarchitecture; geometry only.",
    }


def network(
    design_id: str,
    family: str,
    nodes: int,
    profile: str,
    routing: str,
    primitives: list,
    expected: dict,
    *,
    top_mesh_lanes=None,
    cluster_grid=None,
    hrep=False,
    shares=None,
    paper_role="",
    async_design=True,
    clock_ns=None,
    adapter=None,
    paired_trace_with=None,
    notes="",
    paper_eligible_default=True,
) -> dict:
    return {
        "schema": "date-v3-design-v1",
        "design_id": design_id,
        "kind": "network",
        "family": family,
        "nodes": nodes,
        "async": async_design,
        "routing": routing,
        "lane_profile": profile,
        "top_mesh_lanes": top_mesh_lanes,
        "cluster_grid": cluster_grid,
        "router_primitives": primitives,
        "expected_structure": expected,
        "flit_width_bits": 28,
        "buffer_slots": 5,
        "no_uturn": True,
        "interlevel_fifo": "bypass",
        "delay_recipe": dict(LOCKED),
        "clock_ns": clock_ns,
        "hrep_policy": hrep,
        "shares_netlist_with": shares,
        "paired_trace_with": paired_trace_with,
        "adapter": adapter,
        "paper_role": paper_role,
        "paper_eligible_default": paper_eligible_default,
        "notes": notes,
    }


def main() -> int:
    # V3.2 removes FPGA validation completely.  Delete stale generated inputs
    # so a repeated generator invocation cannot revive that experiment path.
    for stale in (
        DESIGNS / "fpga_async_prop64.json",
        DESIGNS / "fpga_sync_prop64.json",
        BENCHMARKS / "fpga_directed.json",
        BENCHMARKS / "fpga_ur.json",
        BENCHMARKS / "fpga_multicast.json",
    ):
        stale.unlink(missing_ok=True)
    designs = [
        primitive(
            "ASYNC_THIN_1X1", "THIN", 1, 1, 1, mesh=False, async_design=True,
            adapters=0, ports=5, max_fanin=4, mutex=[4],
            paper_role="Table I Thin / FM leaf",
        ),
        primitive(
            "SYNC_THIN_1X1", "SYNC", 1, 1, 1, mesh=False, async_design=False,
            adapters=0, ports=5, max_fanin=4, mutex=[],
            paper_role="Table I Sync Thin counterpart",
            adapter="dc_sync_router",
            clock_ns=1.0,
        ),
        primitive(
            "ASYNC_FAT_1X2", "PROP", 1, 1, 2, mesh=False, async_design=True,
            adapters=4, ports=6, max_fanin=5, mutex=[2, 4, 5],
            paper_role="Table I PROP L1",
        ),
        primitive(
            "ASYNC_PROP_2X2", "PROP", 2, 2, 2, mesh=False, async_design=True,
            adapters=40, ports=10, max_fanin=8, mutex=[2, 8],
            paper_role="Table I PROP L2/L3",
        ),
        primitive(
            "SYNC_PROP_2X2", "SYNC", 2, 2, 2, mesh=False, async_design=False,
            adapters=40, ports=10, max_fanin=8, mutex=[],
            paper_role="Table I Sync 2x2 counterpart",
            adapter="dc_sync_router",
            clock_ns=1.0,
        ),
        primitive(
            "ASYNC_PFAT_2X4", "PFAT", 2, 2, 4, mesh=False, async_design=True,
            adapters=48, ports=12, max_fanin=10, mutex=[2, 4, 8, 10],
            paper_role="Fig. A PFAT L2 cost",
        ),
        primitive(
            "ASYNC_PFAT_4X8", "PFAT", 3, 4, 8, mesh=False, async_design=True,
            adapters=96, ports=24, max_fanin=20, mutex=[4, 8, 16, 20],
            paper_role="Fig. A PFAT L3 cost",
        ),
        primitive(
            "ASYNC_TOPMESH_2X2", "PROP", 1, 2, 2, mesh=True, async_design=True,
            adapters=40, ports=10, max_fanin=8, mutex=[2, 8],
            paper_role="Table I TopMesh2",
        ),
        primitive(
            "ASYNC_FLATMESH_1X1", "FM", 1, 1, 1, mesh=True, async_design=True,
            adapters=0, ports=5, max_fanin=4, mutex=[4],
            paper_role="Table I / FM leaf",
        ),
        network(
            "THIN64", "THIN", 64, "1-1-1-1", "quadtree",
            [
                {"primitive_id": "async_thin_1x1", "level": 1, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_thin_1x1", "level": 2, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": False, "count": 4},
                {"primitive_id": "async_thin_1x1", "level": 3, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": False, "count": 1},
            ],
            {"routers": 21, "ports": 105, "adapters": 0, "interlevel_fifos": 0, "top_ports": 1, "max_opm_fanin": 4, "mutex_widths": [4]},
            top_mesh_lanes=1, cluster_grid=1,
            paper_role="Asynchronous narrow hierarchical network, 64 nodes; hierarchical-width ablation",
        ),
        network(
            "PROP64", "PROP", 64, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 4},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 1},
            ],
            {"routers": 21, "ports": 146, "adapters": 264, "interlevel_fifos": 0, "top_ports": 2, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=2, cluster_grid=1,
            paper_role="Asynchronous balanced hierarchical network, 64 nodes",
        ),
        network(
            "SYNC_THIN64", "SYNC", 64, "1-1-1-1", "quadtree",
            [
                {"primitive_id": "sync_thin_1x1", "level": 1, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "sync_thin_1x1", "level": 2, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": False, "count": 4},
                {"primitive_id": "sync_thin_1x1", "level": 3, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": False, "count": 1},
            ],
            {"routers": 21, "ports": 105, "adapters": 0, "interlevel_fifos": 0, "top_ports": 1, "max_opm_fanin": 4, "mutex_widths": [4]},
            top_mesh_lanes=1, cluster_grid=1,
            async_design=False, clock_ns=1.0, adapter="noc64_sync",
            paired_trace_with="THIN64",
            paper_role="Synchronous narrow hierarchical network, 64 nodes; same traces as the asynchronous narrow 64-node network",
            notes="Phase 2.5 one-cycle head; frozen clock 1.0 ns. Shares case format with the asynchronous narrow 64-node network.",
        ),
        network(
            "SYNC_PROP64", "SYNC", 64, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "sync_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "sync_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 4},
                {"primitive_id": "sync_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 1},
            ],
            {"routers": 21, "ports": 146, "adapters": 264, "interlevel_fifos": 0, "top_ports": 2, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=2, cluster_grid=1,
            async_design=False, clock_ns=1.0, adapter="noc64_sync",
            paired_trace_with="PROP64",
            paper_role="Synchronous balanced hierarchical network, 64 nodes; same traces as the asynchronous balanced 64-node network",
            notes="Phase 2.5 one-cycle head; frozen clock 1.0 ns. Shares case format with the asynchronous balanced 64-node network.",
        ),
        network(
            "PFAT64", "PFAT", 64, "1-2-4-8", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_pfat_2x4", "level": 2, "child_lanes": 2, "parent_lanes": 4, "use_mesh_routing": False, "count": 4},
                {"primitive_id": "async_pfat_4x8", "level": 3, "child_lanes": 4, "parent_lanes": 8, "use_mesh_routing": False, "count": 1},
            ],
            {"routers": 21, "ports": 168, "adapters": 352, "interlevel_fifos": 0, "top_ports": 8, "max_opm_fanin": 20, "mutex_widths": [2, 4, 5, 8, 10, 16, 20]},
            top_mesh_lanes=8, cluster_grid=1,
            paper_role="Asynchronous progressively widened hierarchical network, 64 nodes",
        ),
        network(
            "FM64", "FM", 64, "mesh-1", "mesh",
            [{"primitive_id": "async_flatmesh_1x1", "level": 1, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": True, "count": 64}],
            {"routers": 64, "ports": 320, "adapters": 0, "interlevel_fifos": 0, "top_ports": 0, "max_opm_fanin": 4, "mutex_widths": [4]},
            top_mesh_lanes=0, cluster_grid=None,
            paper_role="Asynchronous flat mesh network, 64 nodes",
        ),
        network(
            "FM256", "FM", 256, "mesh-1", "mesh",
            [{"primitive_id": "async_flatmesh_1x1", "level": 1, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": True, "count": 256}],
            {"routers": 256, "ports": 1280, "adapters": 0, "interlevel_fifos": 0, "top_ports": 0, "max_opm_fanin": 4, "mutex_widths": [4]},
            top_mesh_lanes=0,
            paper_role="Asynchronous flat mesh network, 256 nodes",
        ),
        network(
            "FM1024", "FM", 1024, "mesh-1", "mesh",
            [{"primitive_id": "async_flatmesh_1x1", "level": 1, "child_lanes": 1, "parent_lanes": 1, "use_mesh_routing": True, "count": 1024}],
            {"routers": 1024, "ports": 5120, "adapters": 0, "interlevel_fifos": 0, "top_ports": 0, "max_opm_fanin": 4, "mutex_widths": [4]},
            top_mesh_lanes=0,
            paper_role="Asynchronous flat mesh network, 1024 nodes",
        ),
        network(
            "PROP256", "PROP", 256, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 64},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 4},
                {"primitive_id": "async_topmesh_2x2", "level": 1, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": True, "count": 4},
            ],
            {"routers": 88, "ports": 624, "adapters": 1216, "interlevel_fifos": 0, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=2, cluster_grid=2,
            paper_role="Asynchronous balanced hierarchical network, 256 nodes",
        ),
        network(
            "PROP1024", "PROP", 1024, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 256},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 64},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_topmesh_2x2", "level": 1, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": True, "count": 16},
            ],
            {"routers": 352, "ports": 2496, "adapters": 4864, "interlevel_fifos": 0, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=2, cluster_grid=4,
            paper_role="Asynchronous balanced hierarchical network, 1024 nodes",
        ),
        network(
            "HREP1024", "HREP", 1024, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 256},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 64},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_topmesh_2x2", "level": 1, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": True, "count": 16},
            ],
            {"routers": 352, "ports": 2496, "adapters": 4864, "interlevel_fifos": 0, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=2, cluster_grid=4, hrep=True, shares="PROP1024",
            paper_role="Boundary packet-replication comparison; shares the 1024-node hierarchical netlist",
        ),
        network(
            "PROP1024_MESH1", "MESH_SANITY", 1024, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 256},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 64},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_topmesh_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": True, "count": 16},
            ],
            {"routers": 352, "ports": 2432, "adapters": 4288, "interlevel_fifos": 0, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=1, cluster_grid=4,
            paper_role="Single-lane top-mesh sanity; backup only, not a paper-matrix netlist",
            paper_eligible_default=False,
            notes="Backup only. Do not use as 1024-node paper evidence.",
        ),
        network(
            "PROP1024_MESH2", "MESH_SANITY", 1024, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 256},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 64},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
                {"primitive_id": "async_topmesh_2x2", "level": 1, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": True, "count": 16},
            ],
            {"routers": 352, "ports": 2496, "adapters": 4864, "interlevel_fifos": 0, "max_opm_fanin": 8, "mutex_widths": [2, 4, 5, 8]},
            top_mesh_lanes=2, cluster_grid=4, shares="PROP1024",
            paper_role="Two-lane top-mesh alias of the 1024-node hierarchical netlist; backup only",
            paper_eligible_default=False,
        ),
        network(
            "PROP1024_MESH4", "MESH_SANITY", 1024, "1-2-2-2", "quadtree_topmesh",
            [
                {"primitive_id": "async_fat_1x2", "level": 1, "child_lanes": 1, "parent_lanes": 2, "use_mesh_routing": False, "count": 256},
                {"primitive_id": "async_prop_2x2", "level": 2, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 64},
                {"primitive_id": "async_prop_2x2", "level": 3, "child_lanes": 2, "parent_lanes": 2, "use_mesh_routing": False, "count": 16},
            ],
            {"routers": 336, "interlevel_fifos": 0},
            top_mesh_lanes=4, cluster_grid=4,
            paper_role="Four-lane top-mesh variation; unsupported geometry, not elaborated",
            paper_eligible_default=False,
            notes="Unsupported. Do not fabricate logic-synthesis or delay-format results.",
        ),
    ]
    for design in designs:
        dump(DESIGNS / ("%s.json" % design["design_id"].lower()), design)

    saturation = {
        "enabled": True,
        "coarse_then_fine": True,
        "saturation_rule": "highest offered load with zero errors on all 3 seeds, drainable after measurement, no sustained backlog growth; report delivered throughput and mean latency; do not use 2x zero-load",
    }
    tmax = "last destination tail minus source header injection"
    dump(BENCHMARKS / "r_u5.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "R-U5",
        "title": "Isolated router 5-flit unicast, empty net, no contention",
        "traffic": "r_u5",
        "packet_flits": 5,
        "multicast": False,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": False,
        "fanout_F": None,
        "spread_S": None,
        "multicast_fraction": None,
        "destination_set_samples": None,
        "warmup_original_events": 0,
        "measurement_original_events": 1,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": {"enabled": False, "coarse_then_fine": False, "saturation_rule": "n/a"},
        "metrics": ["head_ns", "body_ns", "tail_ns", "cycle_ns", "mflit_s", "area_um2", "energy_j", "idle_w", "active_w"],
        "tmax_definition": tmax,
        "applies_to_designs": [
            "ASYNC_THIN_1X1", "SYNC_THIN_1X1", "ASYNC_FAT_1X2", "ASYNC_PROP_2X2",
            "SYNC_PROP_2X2", "ASYNC_TOPMESH_2X2", "ASYNC_FLATMESH_1X1",
            "ASYNC_PFAT_2X4", "ASYNC_PFAT_4X8",
        ],
        "paper_figures": ["Table I"],
        "notes": "Also run continuous 5-flit stream, idle window, and contention sanity. Not a network load sweep.",
    })
    dump(BENCHMARKS / "bf_stress64.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "BF-STRESS64",
        "title": "64-node hierarchical-width stress traffic: destination not in the same level-2 subtree",
        "traffic": "bf_stress64",
        "packet_flits": 5,
        "multicast": False,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": True,
        "fanout_F": None,
        "spread_S": None,
        "multicast_fraction": None,
        "destination_set_samples": None,
        "warmup_original_events": 1000,
        "measurement_original_events": 10000,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": saturation,
        "metrics": ["saturation_throughput", "mean_latency", "p50", "p95", "p99"],
        "tmax_definition": tmax,
        "applies_to_designs": ["THIN64", "PROP64", "PFAT64", "SYNC_THIN64", "SYNC_PROP64"],
        "paper_figures": ["Fig. A"],
        "notes": "Same 3 seeds and canonical traces across THIN/PROP/PFAT and Sync64 counterparts.",
    })
    dump(BENCHMARKS / "topo_ur.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "TOPO-UR",
        "title": "Uniform random single-destination traffic, source not equal to destination, same rule at 64/256/1024 nodes",
        "traffic": "topo_ur",
        "packet_flits": 5,
        "multicast": False,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": False,
        "fanout_F": None,
        "spread_S": None,
        "multicast_fraction": 0.0,
        "destination_set_samples": None,
        "warmup_original_events": 1000,
        "measurement_original_events": 10000,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": saturation,
        "metrics": ["router_count", "total_router_area", "lane_links", "channel_bits", "traversals", "zero_load_latency", "saturation_throughput"],
        "tmax_definition": tmax,
        "applies_to_designs": ["PROP64", "PROP256", "PROP1024", "FM64", "FM256", "FM1024", "SYNC_PROP64", "SYNC_THIN64", "THIN64"],
        "paper_figures": ["Fig. B"],
        "notes": "Unicast only. Traversal from routing events, not theoretical hop count.",
    })
    dump(BENCHMARKS / "xmc_f16.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "XMC-F16",
        "title": "1024-node fixed sixteen-destination cross-group multicast traffic, spread 1/4/16",
        "traffic": "xmc_f16",
        "packet_flits": 5,
        "multicast": True,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": False,
        "fanout_F": 16,
        "spread_S": [1, 4, 16],
        "multicast_fraction": 1.0,
        "destination_set_samples": 32,
        "warmup_original_events": 0,
        "measurement_original_events": 32,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": {"enabled": False, "coarse_then_fine": False, "saturation_rule": "n/a"},
        "metrics": ["top_mesh_injections", "top_mesh_link_traversals", "tmax", "energy_per_original_event"],
        "tmax_definition": tmax,
        "applies_to_designs": ["PROP1024", "HREP1024"],
        "paper_figures": ["Fig. C"],
        "notes": ">=32 paired destination-set samples. Bootstrap 95% CI allowed.",
    })
    dump(BENCHMARKS / "xmc10_g.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "XMC10-G",
        "title": "1024-node mixed load: 90 percent single-destination plus 10 percent sixteen-destination multicast",
        "traffic": "xmc10_g",
        "packet_flits": 5,
        "multicast": True,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": False,
        "fanout_F": 16,
        "spread_S": [4],
        "multicast_fraction": 0.10,
        "destination_set_samples": None,
        "warmup_original_events": 1000,
        "measurement_original_events": 10000,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": saturation,
        "metrics": ["tmax_at_0.25_hrep_saturation_load", "saturation_throughput", "mean_latency"],
        "tmax_definition": tmax,
        "applies_to_designs": ["PROP1024", "HREP1024"],
        "paper_figures": ["Fig. C"],
        "notes": "Tmax is read at 0.25 x H-REP saturation offered load for both designs. S=16 is backup.",
    })
    dump(BENCHMARKS / "mesh_intercluster_ur.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "MESH-INTERCLUSTER-UR",
        "title": "1024-node inter-cluster single-destination sanity traffic (backup only)",
        "traffic": "mesh_intercluster_ur",
        "packet_flits": 5,
        "multicast": False,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": False,
        "fanout_F": None,
        "spread_S": None,
        "multicast_fraction": 0.0,
        "destination_set_samples": None,
        "warmup_original_events": 1000,
        "measurement_original_events": 10000,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": saturation,
        "metrics": ["saturation_throughput", "topmesh_util"],
        "tmax_definition": tmax,
        "applies_to_designs": ["PROP1024_MESH1", "PROP1024_MESH2", "PROP1024_MESH4"],
        "paper_figures": ["backup"],
        "notes": "Default backup only.",
    })
    dump(BENCHMARKS / "snn_trace1024.json", {
        "schema": "date-v3-benchmark-v1",
        "benchmark_id": "SNN-TRACE1024",
        "title": "Frozen spiking-neural-network multicast trace replay, 1024 nodes (optional)",
        "traffic": "snn_trace1024",
        "packet_flits": 5,
        "multicast": True,
        "src_neq_dst": True,
        "dst_not_same_l2_subtree": False,
        "fanout_F": None,
        "spread_S": None,
        "multicast_fraction": None,
        "destination_set_samples": None,
        "warmup_original_events": 0,
        "measurement_original_events": 0,
        "seed_set_id": "v3_main_seeds",
        "paired_trace": True,
        "load_sweep": {"enabled": False, "coarse_then_fine": False, "saturation_rule": "trace replay"},
        "metrics": [
            "useful_destinations",
            "region_covered_destinations",
            "region_efficiency",
            "top_mesh_link_traversals",
            "tmax",
            "energy_per_original_event",
        ],
        "tmax_definition": tmax,
        "applies_to_designs": ["PROP1024", "HREP1024"],
        "paper_figures": ["optional_inset"],
        "notes": "Optional only after Gate F. Requires a frozen source trace, provenance, endpoint mapping, and preserved one-spike-to-one-multicast semantics.",
    })

    dump(SEEDS / "v3_main_seeds.json", {
        "schema": "date-v3-seeds-v1",
        "seed_set_id": "v3_main_seeds",
        "frozen": True,
        "seeds": [202701, 202702, 202703],
        "arb_seed_offset": 10007,
        "notes": "Traffic seeds are design-independent. Arbitration RNG is a separate recorded stream.",
    })

    hop_runs = [
        ("20260830_cmr_thin_l1_hop_del050_ackin050", "ASYNC_THIN_1X1", "Thin L1 hop MAXIMUM SDF"),
        ("20260830_cmr_thin_l2_hop_del050_ackin050", "ASYNC_THIN_1X1", "Thin L2 hop MAXIMUM SDF"),
        ("20260830_cmr_thin_l3_hop_del050_ackin050", "ASYNC_THIN_1X1", "Thin L3 hop MAXIMUM SDF"),
        ("20260830_cmr_fat_l1_hop_del050_ackin050", "ASYNC_FAT_1X2", "Fat L1 hop MAXIMUM SDF"),
        ("20260830_cmr_fat_l2_hop_del050_ackin050", "ASYNC_PROP_2X2", "PROP L2 hop MAXIMUM SDF"),
        ("20260830_cmr_fat_l3_hop_del050_ackin050", "ASYNC_PROP_2X2", "PROP L3 hop MAXIMUM SDF"),
    ]
    import_runs = [
        {
            "run_id": run_id,
            "design_id": design_id,
            "benchmark_id": "R-U5",
            "adapter": "import_readonly",
            "physical_class": "post-synthesis",
            "paper_eligible": False,
            "notes": "%s; paper-eligible as post-synthesis calibrated hop (DATE V3 does not replace with post-route)." % note,
        }
        for run_id, design_id, note in hop_runs
    ]
    import_runs.extend([
        {
            "run_id": "20260830_cmr_router_level_baseline_del050",
            "design_id": "ASYNC_THIN_1X1",
            "benchmark_id": "R-U5",
            "adapter": "import_readonly",
            "physical_class": "post-synthesis",
            "paper_eligible": False,
            "notes": "Hop PPA summary folder. Do not overwrite.",
        },
        {
            "run_id": "20260831_014622_cmr_sync_noc64_thin_p50",
            "design_id": "SYNC_THIN_1X1",
            "benchmark_id": None,
            "adapter": "import_readonly",
            "physical_class": "archive-only",
            "paper_eligible": False,
            "notes": "Phase 2 Thin SyncNoC64 1.0 ns, 2-cycle Head. Archive-only. Do not overwrite.",
        },
        {
            "run_id": "20260831_084457_cmr_sync_noc64_fat1222_p50",
            "design_id": "SYNC_PROP_2X2",
            "benchmark_id": None,
            "adapter": "import_readonly",
            "physical_class": "archive-only",
            "paper_eligible": False,
            "notes": "Phase 2 Fat 1-2-2-2 SyncNoC64 1.0 ns, 3-cycle Head path. Archive-only. Do not overwrite.",
        },
        {
            "run_id": "20260901_cmr_sync_noc64_thin_p50",
            "design_id": "SYNC_THIN_1X1",
            "benchmark_id": None,
            "adapter": "dc_sync_noc64",
            "physical_class": "post-synthesis",
            "paper_eligible": True,
            "notes": "Phase 2.5 1-cycle Head Thin SyncNoC64 1.0 ns MAXIMUM-SDF. Do not overwrite.",
        },
        {
            "run_id": "20260901_cmr_sync_noc64_fat1222_p50",
            "design_id": "SYNC_PROP_2X2",
            "benchmark_id": None,
            "adapter": "dc_sync_noc64",
            "physical_class": "post-synthesis",
            "paper_eligible": True,
            "notes": "Phase 2.5 1-cycle Head Fat 1-2-2-2 SyncNoC64 1.0 ns MAXIMUM-SDF. Do not overwrite.",
        },
        {
            "run_id": "cmr_mesh64_current",
            "design_id": "FM64",
            "benchmark_id": None,
            "adapter": "import_readonly",
            "physical_class": "unknown",
            "paper_eligible": False,
            "notes": "Placeholder for the in-flight mesh64 run. Replace run_id with CMR_MESH64_RUN_ID when DC/GLS finishes. Not curated.",
        },
        {
            "run_id": "20260830_095259_cmr_noc64_p50_1222",
            "design_id": "PROP64",
            "benchmark_id": None,
            "adapter": "import_readonly",
            "physical_class": "archive-only",
            "paper_eligible": False,
            "archive_only_reason": "Ackin DEL250 predecessor. Not the hop delay recipe. Archive-only.",
            "notes": "Must not enter curated or Table I/Fig A delay comparison.",
        },
        {
            "run_id": "20260828_cmr_cfifo_tp_nogrant_p50",
            "design_id": "THIN64",
            "benchmark_id": None,
            "adapter": "import_readonly",
            "physical_class": "archive-only",
            "paper_eligible": False,
            "archive_only_reason": "Thin NoC16 CFifo with RCU matched BUFFD0. Archive-only.",
            "notes": "CFifo/BUFFD0 laboratory netlist.",
        },
    ])
    dump(PLANS / "phase0_import.json", {
        "schema": "date-v3-plan-v1",
        "plan_id": "phase0_import",
        "title": "Read-only import of frozen DC/GLS runs",
        "runs": import_runs,
    })
    dump(PLANS / "pnr_pilot.json", {
        "schema": "date-v3-plan-v1",
        "plan_id": "pnr_pilot",
        "title": "Phase 1 P&R pilot closed: post-synthesis freeze (no tech LEF/NDM)",
        "runs": [
            {
                "run_id": "20260831_cmr_pnr_pilot_blocker",
                "design_id": "ASYNC_THIN_1X1",
                "benchmark_id": None,
                "adapter": "pnr_pilot",
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Closed. ICC2/Innovus licensed; no tech LEF/NDM; Galaxy-ICC unlicensed. Paper path is MAXIMUM-SDF only.",
            },
            {
                "run_id": "pnr_probe_env",
                "design_id": "ASYNC_THIN_1X1",
                "benchmark_id": None,
                "adapter": "pnr_probe",
                "physical_class": "unknown",
                "paper_eligible": False,
                "notes": "LSF license checkout + PDK listing. Not a paper result.",
            },
            {
                "run_id": "pnr_pilot_thin_icc2",
                "design_id": "ASYNC_THIN_1X1",
                "benchmark_id": "R-U5",
                "adapter": "pnr_pilot",
                "env": {
                    "CMR_PNR_TOOL": "icc2",
                    "CMR_PNR_DESIGN": "thin_1x1",
                    "CMR_PNR_NETLIST_RUN_ID": "20260830_cmr_thin_l1_hop_del050_ackin050",
                },
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Blocked: no tech LEF/NDM. Do not treat as post-layout.",
            },
            {
                "run_id": "pnr_pilot_thin_innovus",
                "design_id": "ASYNC_THIN_1X1",
                "benchmark_id": "R-U5",
                "adapter": "pnr_pilot",
                "env": {
                    "CMR_PNR_TOOL": "innovus",
                    "CMR_PNR_DESIGN": "thin_1x1",
                    "CMR_PNR_NETLIST_RUN_ID": "20260830_cmr_thin_l1_hop_del050_ackin050",
                },
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Blocked: no tech LEF/NDM. Do not treat as post-layout.",
            },
            {
                "run_id": "pnr_pilot_prop_icc2",
                "design_id": "ASYNC_PROP_2X2",
                "benchmark_id": "R-U5",
                "adapter": "pnr_pilot",
                "env": {
                    "CMR_PNR_TOOL": "icc2",
                    "CMR_PNR_DESIGN": "prop_2x2",
                    "CMR_PNR_NETLIST_RUN_ID": "20260830_cmr_fat_l2_hop_del050_ackin050",
                },
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Blocked: no tech LEF/NDM. Do not treat as post-layout.",
            },
            {
                "run_id": "pnr_pilot_prop_innovus",
                "design_id": "ASYNC_PROP_2X2",
                "benchmark_id": "R-U5",
                "adapter": "pnr_pilot",
                "env": {
                    "CMR_PNR_TOOL": "innovus",
                    "CMR_PNR_DESIGN": "prop_2x2",
                    "CMR_PNR_NETLIST_RUN_ID": "20260830_cmr_fat_l2_hop_del050_ackin050",
                },
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Blocked: no tech LEF/NDM. Do not treat as post-layout.",
            },
        ],
    })
    dump(PLANS / "primitive_matrix.json", {
        "schema": "date-v3-plan-v1",
        "plan_id": "primitive_matrix",
        "title": "Phase 2 Router primitives: DC + MAXIMUM-SDF R-U5 + PT-PX (no P&R)",
        "runs": [
            {
                "run_id": "20260831_cmr_primitive_matrix",
                "design_id": "ASYNC_THIN_1X1",
                "benchmark_id": "R-U5",
                "adapter": "primitive_matrix",
                "physical_class": "post-synthesis",
                "paper_eligible": True,
                "notes": (
                    "Emit all V3 primitives, geometry-check, DC new PFAT/TopMesh/"
                    "FlatMesh/Sync isolated routers, then 5-flit R-U5 hop GLS + PT-PX. "
                    "Reuses frozen 20260830 Thin/Fat/PROP hop netlists. No P&R."
                ),
            }
        ],
    })
    dump(PLANS / "phase4_traffic.json", {
        "schema": "date-v3-plan-v1",
        "plan_id": "phase4_traffic",
        "title": "Phase 4 V3 traffic infrastructure (local generator; not paper numbers)",
        "runs": [
            {
                "run_id": "20260901_v3_traffic_smoke",
                "design_id": "PROP64",
                "benchmark_id": "BF-STRESS64",
                "adapter": "v3_traffic",
                "argv": [
                    "--smoke", "--benchmark", "BF-STRESS64", "--materialize",
                    "--design", "THIN64", "--design", "PROP64",
                    "--design", "SYNC_THIN64", "--design", "SYNC_PROP64",
                ],
                "physical_class": "rtl",
                "paper_eligible": False,
                "notes": "Local canonical JSONL + paired .case smoke. Formal 11k-event maximum-delay gate-level scoreboard is Phase 6 Gates C-F.",
            }
        ],
    })
    dump(PLANS / "phase6_network_gates.json", {
        "schema": "date-v3-plan-v1",
        "plan_id": "phase6_network_gates",
        "title": "V3.1.0 whole-network logic synthesis and maximum-delay gate-level simulation",
        "runs": [
            {
                "run_id": "20260901_cmr_v31_gate_a_local",
                "design_id": "PROP64",
                "benchmark_id": None,
                "adapter": "v31_gates",
                "physical_class": "rtl",
                "paper_eligible": False,
                "notes": "Gate A local readiness. Not paper numbers.",
                "env": {"CMR_V31_GATE": "A"},
            },
            {
                "run_id": "20260901_cmr_v31_prop256_dc",
                "design_id": "PROP256",
                "benchmark_id": None,
                "adapter": "network_sdf",
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Gate C synthesis of the asynchronous balanced hierarchical network, 256 nodes. Paper-eligible only after representative and formal delay simulations pass.",
                "env": {
                    "CMR_NETWORK_DESIGN_ID": "PROP256",
                    "CMR_HIER_SKIP_GLS": "1",
                    "CMR_DESCAL_SUBMIT_ONLY": "1",
                },
            },
            {
                "run_id": "20260901_cmr_v31_fm256_dc",
                "design_id": "FM256",
                "benchmark_id": None,
                "adapter": "network_sdf",
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Gate C synthesis of the asynchronous flat mesh network, 256 nodes.",
                "env": {
                    "CMR_NETWORK_DESIGN_ID": "FM256",
                    "CMR_HIER_SKIP_GLS": "1",
                    "CMR_DESCAL_SUBMIT_ONLY": "1",
                },
            },
            {
                "run_id": "20260901_cmr_v31_prop1024_dc",
                "design_id": "PROP1024",
                "benchmark_id": None,
                "adapter": "network_sdf",
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Gate E synthesis of the asynchronous balanced hierarchical network, 1024 nodes. Submit only after Gate D.",
                "env": {
                    "CMR_NETWORK_DESIGN_ID": "PROP1024",
                    "CMR_HIER_SKIP_GLS": "1",
                    "CMR_DESCAL_SUBMIT_ONLY": "1",
                    "CMR_V31_REQUIRE_GATE": "D",
                },
            },
            {
                "run_id": "20260901_cmr_v31_fm1024_dc",
                "design_id": "FM1024",
                "benchmark_id": None,
                "adapter": "network_sdf",
                "physical_class": "post-synthesis",
                "paper_eligible": False,
                "notes": "Gate E synthesis of the asynchronous flat mesh network, 1024 nodes. Submit only after Gate D.",
                "env": {
                    "CMR_NETWORK_DESIGN_ID": "FM1024",
                    "CMR_HIER_SKIP_GLS": "1",
                    "CMR_DESCAL_SUBMIT_ONLY": "1",
                    "CMR_V31_REQUIRE_GATE": "D",
                },
            },
        ],
    })
    print("wrote designs", len(list(DESIGNS.glob('*.json'))), "benchmarks", len(list(BENCHMARKS.glob('*.json'))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
