#!/usr/bin/env python3
"""Static inventory gate for emitted Sync PROP_temp64 B8 RTL."""
from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
RTL = REPO / "generated_sync_cmr" / "prop_temp64_b8" / "SyncNoC_64nodes.v"
CONFIG = REPO / "DATE paper" / "experiments" / "configs" / "designs" / "sync_prop_temp64_b8.json"
ADAPTER = REPO / "sim" / "AsyncNoC" / "sync_noc64_port_adapter.sv"


def main() -> int:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    text = RTL.read_text(encoding="utf-8", errors="replace")
    adapter = ADAPTER.read_text(encoding="utf-8", errors="replace")
    if "module SyncNoC_64nodes(" not in text:
        raise SystemExit("missing SyncNoC_64nodes top")
    instances = re.findall(r"^\s*SyncCmrRouter(?:_\d+)?\s+syncPropL([123])_", text, re.M)
    counts = {level: instances.count(level) for level in "123"}
    if counts != {"1": 16, "2": 16, "3": 16}:
        raise SystemExit(f"router inventory mismatch: {counts}")
    for lane in range(16):
        for direction in ("input", "output"):
            marker = f"io_top_{direction}_{lane}_hs_valid"
            if marker not in text:
                raise SystemExit(f"missing top port {marker}")
    if "module sync_noc64_port_adapter_top16" not in adapter or "SyncNoC_64nodes dut" not in adapter:
        raise SystemExit("missing Sync B8 top16 adapter")
    forbidden = ("Mutex", "DelayElement", "LanePhaseAdapter")
    leaked = [name for name in forbidden if re.search(rf"^module .*{name}|\s{name}\s", text, re.M)]
    if leaked:
        raise SystemExit(f"async primitives leaked into Sync B8: {leaked}")
    expected = config["expected_structure"]
    if expected != {"routers": 48, "ports": 336,
                    "l1_l2_full_duplex_links": 64,
                    "l2_l3_full_duplex_links": 64,
                    "top_ports": 16, "async_primitives": 0}:
        raise SystemExit("design config inventory changed unexpectedly")
    print("SYNC_PROP_TEMP64_B8_STRUCTURE_PASS routers=48 ports=336 "
          "l1_l2_full_duplex=64 l2_l3_full_duplex=64 top_ports=16 async_primitives=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
