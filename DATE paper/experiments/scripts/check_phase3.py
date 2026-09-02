#!/usr/bin/env python3
"""DATE V3 Phase 3 infrastructure gate.

Confirms network DUT Scala, inventory vs design JSON, DES topology counts,
and the Python route oracle.  64-node RTL directed exhaustive and FPGA
walks are Phase 11 / 6–9, not this gate.  Mesh4 is not elaborated.
"""
from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MODEL = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.designs import NETWORK_IDS, load_design  # noqa: E402
from date_v3.network_inventory import by_id  # noqa: E402
from date_v3.paths import REPO  # noqa: E402

SCALA = REPO / "src" / "main" / "scala" / "NoC" / "CMR"
DUT_FILES = (
    "CMRFatTree.scala",
    "CMRFatTreeNoC64.scala",
    "CMRTopMesh.scala",
    "CMRClusteredNoC.scala",
    "CMRMeshNoC.scala",
    "HrepBoundaryPolicy.scala",
    "CMRNetworkRouteOracle.scala",
    "CMRNetworkInventory.scala",
    "SyncCmrFatTree.scala",
)


def check_scala() -> None:
    for name in DUT_FILES:
        path = SCALA / name
        if not path.is_file():
            raise AssertionError("missing DUT %s" % path)
        text = path.read_text(encoding="utf-8")
        if name == "CMRClusteredNoC.scala" and "Mesh4" not in text:
            raise AssertionError("CMRClusteredNoC must reject Mesh4")
        if name == "HrepBoundaryPolicy.scala" and "originalEventId" not in text:
            raise AssertionError("H-REP must keep originalEventId")
    inventory_src = (SCALA / "CMRNetworkInventory.scala").read_text(encoding="utf-8")
    for design_id in ("THIN64", "PROP64", "PFAT64", "HREP1024", "SYNC_THIN64", "SYNC_PROP64"):
        if design_id not in inventory_src:
            raise AssertionError("Scala inventory missing %s" % design_id)
    print("PASS check_scala")


def check_inventory() -> None:
    from inventory_network_duts import main as inv_main

    rc = inv_main()
    if rc != 0:
        raise AssertionError("inventory_network_duts failed")
    rows = by_id()
    if "SYNC_THIN64" not in rows or "SYNC_PROP64" not in rows:
        raise AssertionError("SYNC64 missing from Python inventory")
    if rows["HREP1024"]["shares_netlist_with"] != "PROP1024":
        raise AssertionError("H-REP must share PROP1024 netlist")
    if rows["PROP1024_MESH4"]["elaborated"]:
        raise AssertionError("Mesh4 must not be elaborated")
    for design_id in NETWORK_IDS:
        design = load_design(design_id)
        if design_id not in rows:
            raise AssertionError("no inventory row for %s" % design_id)
        if design.get("hrep_policy") != rows[design_id]["hrep_policy"]:
            raise AssertionError("%s hrep_policy mismatch" % design_id)
    print("PASS check_inventory")


def check_topology() -> None:
    from des.timing import TimingTable
    from des.topology import build_network, inventory_delta

    table = TimingTable()
    for design_id in NETWORK_IDS:
        if design_id == "PROP1024_MESH4":
            try:
                build_network(load_design(design_id), timing=table)
            except ValueError:
                continue
            raise AssertionError("MESH4 elaborated in DES")
        net = build_network(load_design(design_id), timing=table)
        errors = inventory_delta(net)
        if errors:
            raise AssertionError("%s %s" % (design_id, errors))
    print("PASS check_topology")


def check_oracle() -> None:
    from test_traffic_v3 import test_route_oracle_64

    test_route_oracle_64()
    print("PASS check_oracle")


def main() -> int:
    check_scala()
    check_inventory()
    check_topology()
    check_oracle()
    print("PHASE3_GATE_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
