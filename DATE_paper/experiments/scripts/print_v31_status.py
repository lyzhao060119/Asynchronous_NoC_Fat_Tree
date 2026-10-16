#!/usr/bin/env python3
"""Print the V3.1.0 status list using complete English names only."""
from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.display_names import METHOD_DEFINITIONS, display_name  # noqa: E402
from date_v3.network_matrix import (  # noqa: E402
    INDEPENDENT_NETLISTS,
    PAPER_MATRIX_NETWORKS,
    SHARED_NETLISTS,
    UNSUPPORTED,
    dump_matrix,
)
from date_v3.paths import MODEL, REGISTRY, SCHEMA  # noqa: E402
from date_v3.registry import get_run  # noqa: E402


def _lock() -> dict:
    path = MODEL / "calibration" / "locked.json"
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    print("DATE V3.1.0 status (complete English names)")
    print()
    for text in METHOD_DEFINITIONS.values():
        print("-", text)
    print()
    print("Independent whole-network netlists")
    for design_id in INDEPENDENT_NETLISTS:
        print("  ", display_name(design_id))
    print()
    print("Shared netlists (injection or alias only)")
    for child, owner in SHARED_NETLISTS.items():
        print("  ", display_name(child), "->", display_name(owner))
    print()
    print("Unsupported (do not fabricate synthesis or delay-format results)")
    for design_id, reason in UNSUPPORTED.items():
        print("  ", display_name(design_id) + ":", reason)
    print()
    lock = _lock()
    print("Software event model paper-matrix allowed:", bool(lock.get("paper_matrix_allowed")))
    print("Synchronous 64-node signed runs:")
    for run_id in (
        "20260901_cmr_sync_noc64_thin_p50",
        "20260901_cmr_sync_noc64_fat1222_p50",
    ):
        manifest = get_run(run_id)
        status = manifest.get("status") if manifest else "missing"
        print("  ", run_id, status, display_name(manifest.get("design_id") if manifest else None))
    print()
    print("Paper-matrix networks")
    for design_id in PAPER_MATRIX_NETWORKS:
        print("  ", display_name(design_id))
    print()
    doc = SCHEMA.parent.parent / "setup" / "NoC_Experiment_Design_V3.1.0.md"
    print("Current design document:", doc)
    print("Registry:", REGISTRY)
    print("Matrix schema:", dump_matrix()["schema"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
