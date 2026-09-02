#!/usr/bin/env python3
"""Emit DATE V3 network DUT structure JSON and check design configs."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from date_v3.display_names import attach_display  # noqa: E402
from date_v3.network_inventory import all_duts, by_id  # noqa: E402
from date_v3.network_matrix import dump_matrix  # noqa: E402
from date_v3.paths import DESIGNS  # noqa: E402


def main() -> int:
    duts = [attach_display(dict(row)) for row in all_duts()]
    out = ROOT / "configs" / "inventory" / "network_duts.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {"schema": "date-v3-network-inventory-v1", "duts": duts}
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print("wrote", out)

    matrix_path = ROOT / "configs" / "inventory" / "v31_network_matrix.json"
    matrix_path.write_text(json.dumps(dump_matrix(), indent=2) + "\n", encoding="utf-8")
    print("wrote", matrix_path)

    inventory = by_id()
    errors: list[str] = []
    for path in sorted(DESIGNS.glob("*.json")):
        design = json.loads(path.read_text(encoding="utf-8"))
        if design.get("kind") != "network":
            continue
        design_id = design["design_id"]
        if design_id not in inventory:
            errors.append("%s: missing inventory row" % design_id)
            continue
        row = inventory[design_id]
        expected = design.get("expected_structure") or {}
        for key in ("routers", "adapters", "interlevel_fifos", "max_opm_fanin", "ports", "top_ports"):
            if key in expected and row.get(key) != expected[key]:
                errors.append(
                    "%s: %s inventory=%s config=%s"
                    % (design_id, key, row.get(key), expected[key])
                )
        if design.get("hrep_policy") != row["hrep_policy"]:
            errors.append("%s: hrep_policy mismatch" % design_id)
        if design.get("shares_netlist_with") != row["shares_netlist_with"]:
            errors.append(
                "%s: shares_netlist_with inventory=%s config=%s"
                % (design_id, row["shares_netlist_with"], design.get("shares_netlist_with"))
            )
        if not row["elaborated"] and design_id != "PROP1024_MESH4":
            errors.append("%s: inventory marked not elaborated" % design_id)
    if errors:
        print("INVENTORY_CHECK FAIL")
        for err in errors:
            print(err)
        return 1
    print("INVENTORY_CHECK PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
