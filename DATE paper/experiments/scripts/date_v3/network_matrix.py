"""V3.1.0 independent whole-network netlist matrix.

Machine keys stay in design_id.  Human-facing names come from display_names.
Four-lane top mesh is unsupported: do not emit, synthesize, or fake delay files.
"""
from __future__ import annotations

from typing import Any

from .display_names import display_description, display_name
from .network_inventory import by_id

# Independent whole-network netlists that must each produce a synthesis netlist,
# maximum-delay file, area/timing/structure reports, hashes, and a manifest.
INDEPENDENT_NETLISTS: tuple[str, ...] = (
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

PAPER_MATRIX_NETWORKS: tuple[str, ...] = (
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

SHARED_NETLISTS: dict[str, str] = {
    "HREP1024": "PROP1024",
    "PROP1024_MESH2": "PROP1024",
}

BACKUP_ONLY: tuple[str, ...] = (
    "PROP1024_MESH1",
    "PROP1024_MESH2",
)

UNSUPPORTED: dict[str, str] = {
    "PROP1024_MESH4": (
        "Four-lane top mesh requires router geometry (4,2), which is not in the "
        "supported lane set. Do not elaborate, synthesize, or fabricate a delay file."
    ),
}

NO_SYNC_AT_SCALE: tuple[int, ...] = (256, 1024)

EMIT: dict[str, dict[str, Any]] = {
    "THIN64": {
        "main": "NoC.CMR.CMRFatTreeNoC64Main",
        "sbt_args": "",
        "env": {"CMR_Q64_PROFILE": "thin"},
        "gen_dir": "generated_cmr/fat_tree_noc64_thin",
        "dut_file": "NoC_64nodes.v",
        "top": "NoC_64nodes",
        "hier_kind": "thin",
        "legacy_adapter": "noc64_async",
        "gls_shell": "legacy_noc64",
    },
    "PROP64": {
        "main": "NoC.CMR.CMRFatTreeNoC64Main",
        "sbt_args": "",
        "env": {"CMR_Q64_PROFILE": "1222", "CMR_FAT_LANE_PROFILE": "1222"},
        "gen_dir": "generated_cmr/fat_tree_noc64_1222",
        "dut_file": "NoC_64nodes.v",
        "top": "NoC_64nodes",
        "hier_kind": "1222",
        "legacy_adapter": "noc64_async",
        "gls_shell": "legacy_noc64",
    },
    "PFAT64": {
        "main": "NoC.CMR.CMRFatTreeNoC64Main",
        "sbt_args": "",
        "env": {"CMR_Q64_PROFILE": "1248", "CMR_FAT_LANE_PROFILE": "1248"},
        "gen_dir": "generated_cmr/fat_tree_noc64_1248",
        "dut_file": "NoC_64nodes.v",
        "top": "NoC_64nodes",
        "hier_kind": "1248",
        "legacy_adapter": "noc64_async",
        "gls_shell": "legacy_noc64",
    },
    "FM64": {
        "main": "NoC.CMR.CMRMeshNoCMain",
        "sbt_args": "8 1 1",
        "env": {},
        "gen_dir": "generated_cmr/mesh_noc64_11",
        "dut_file": "CMRMeshNoC.v",
        "top": "CMRMeshNoC",
        "hier_kind": "mesh",
        "legacy_adapter": "mesh64",
        "gls_shell": "legacy_mesh64",
    },
    "SYNC_THIN64": {
        "main": "NoC.CMR.SyncCmrFatTreeNoC64Main",
        "sbt_args": "",
        "env": {},
        "gen_dir": "generated_sync_cmr/fat_tree_noc64_thin",
        "dut_file": "SyncNoC_64nodes.v",
        "top": "SyncNoC_64nodes",
        "hier_kind": None,
        "legacy_adapter": "noc64_sync",
        "gls_shell": "legacy_sync64",
        "signed_run_id": "20260901_cmr_sync_noc64_thin_p50",
    },
    "SYNC_PROP64": {
        "main": "NoC.CMR.SyncCmrFatTreeNoC64Fat1222Main",
        "sbt_args": "",
        "env": {},
        "gen_dir": "generated_sync_cmr/fat_tree_noc64_1222",
        "dut_file": "SyncNoC_64nodes.v",
        "top": "SyncNoC_64nodes",
        "hier_kind": None,
        "legacy_adapter": "noc64_sync",
        "gls_shell": "legacy_sync64",
        "signed_run_id": "20260901_cmr_sync_noc64_fat1222_p50",
    },
    "PROP256": {
        "main": "NoC.CMR.CMRClusteredNoCMain",
        "sbt_args": "2 2",
        "env": {},
        "gen_dir": "generated_cmr/clustered_noc_g2_m2",
        "dut_file": "NoC_256nodes.v",
        "top": "NoC_256nodes",
        "hier_kind": "prop256",
        "legacy_adapter": "network_sdf",
        "gls_shell": "network",
        "kind": "hierarchical",
    },
    "FM256": {
        "main": "NoC.CMR.CMRMeshNoCMain",
        "sbt_args": "16 1 1",
        "env": {},
        "gen_dir": "generated_cmr/mesh_noc256_11",
        "dut_file": "CMRMeshNoC.v",
        "top": "CMRMeshNoC",
        "hier_kind": "mesh256",
        "legacy_adapter": "network_sdf",
        "gls_shell": "network",
        "kind": "mesh",
    },
    "PROP1024": {
        "main": "NoC.CMR.CMRClusteredNoCMain",
        "sbt_args": "4 2",
        "env": {},
        "gen_dir": "generated_cmr/clustered_noc_g4_m2",
        "dut_file": "NoC_1024nodes.v",
        "top": "NoC_1024nodes",
        "hier_kind": "prop1024",
        "legacy_adapter": "network_sdf",
        "gls_shell": "network",
        "kind": "hierarchical",
    },
    "FM1024": {
        "main": "NoC.CMR.CMRMeshNoCMain",
        "sbt_args": "32 1 1",
        "env": {},
        "gen_dir": "generated_cmr/mesh_noc1024_11",
        "dut_file": "CMRMeshNoC.v",
        "top": "CMRMeshNoC",
        "hier_kind": "mesh1024",
        "legacy_adapter": "network_sdf",
        "gls_shell": "network",
        "kind": "mesh",
    },
}

SYNC64_SIGNED = {
    "SYNC_THIN64": "20260901_cmr_sync_noc64_thin_p50",
    "SYNC_PROP64": "20260901_cmr_sync_noc64_fat1222_p50",
}

GATE_ORDER: tuple[str, ...] = ("A", "B", "C", "D", "E", "F")

REPRESENTATIVE_CASE_CLASSES: tuple[str, ...] = (
    "directed",
    "zero_load",
    "medium_load",
    "near_saturation",
)

FORMAL_SEEDS: tuple[int, ...] = (202701, 202702, 202703)


def netlist_owner(design_id: str) -> str:
    return SHARED_NETLISTS.get(design_id, design_id)


def is_unsupported(design_id: str) -> bool:
    return design_id in UNSUPPORTED


def is_paper_matrix(design_id: str) -> bool:
    return design_id in PAPER_MATRIX_NETWORKS


def matrix_row(design_id: str) -> dict[str, Any]:
    inventory = by_id().get(design_id) or {}
    owner = netlist_owner(design_id)
    unsupported = is_unsupported(design_id)
    return {
        "design_id": design_id,
        "display_name": display_name(design_id),
        "display_description": display_description(design_id),
        "nodes": inventory.get("nodes"),
        "independent_netlist": design_id in INDEPENDENT_NETLISTS,
        "shares_netlist_with": SHARED_NETLISTS.get(design_id),
        "netlist_owner": owner,
        "paper_matrix": is_paper_matrix(design_id),
        "backup_only": design_id in BACKUP_ONLY,
        "synthesis_supported": (not unsupported) and bool(inventory.get("elaborated", True)),
        "unsupported_reason": UNSUPPORTED.get(design_id),
        "emit": EMIT.get(owner),
        "expected": {
            "routers": inventory.get("routers"),
            "ports": inventory.get("ports") or inventory.get("ipms"),
            "adapters": inventory.get("adapters"),
        },
    }


def dump_matrix() -> dict[str, Any]:
    inventory_ids = list(by_id())
    rows = [matrix_row(design_id) for design_id in inventory_ids]
    return {
        "schema": "date-v3.1-network-matrix-v1",
        "logic_synthesis": (
            "Design Compiler maps register-transfer-level Verilog to a standard-cell "
            "gate netlist (post-synthesis, zero wire load). It is not place-and-route."
        ),
        "maximum_delay_standard_delay_format": (
            "Slow-corner MAXIMUM delay annotation on that netlist. Gate-level simulation "
            "must complete annotation with zero errors, zero timing violations, no unknown "
            "values, and no loss, duplication, deadlock, or timeout."
        ),
        "no_synchronous_256_or_1024": True,
        "independent_netlists": list(INDEPENDENT_NETLISTS),
        "paper_matrix": list(PAPER_MATRIX_NETWORKS),
        "shared_netlists": dict(SHARED_NETLISTS),
        "unsupported": dict(UNSUPPORTED),
        "backup_only": list(BACKUP_ONLY),
        "representative_case_classes": list(REPRESENTATIVE_CASE_CLASSES),
        "formal_seeds": list(FORMAL_SEEDS),
        "gate_order": list(GATE_ORDER),
        "duts": rows,
    }
