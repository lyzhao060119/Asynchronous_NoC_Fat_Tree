#!/usr/bin/env python3
"""Print the V3.2 status, including FPGA cancellation and SNN trace hold."""
from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.display_names import METHOD_DEFINITIONS, display_name  # noqa: E402
from date_v3.network_matrix import INDEPENDENT_NETLISTS, PAPER_MATRIX_NETWORKS  # noqa: E402
from date_v3.paths import EXPERIMENTS, MODEL  # noqa: E402


def main() -> int:
    print("DATE V3.2.0 status (complete English names)")
    print()
    for definition in METHOD_DEFINITIONS.values():
        print("-", definition)
    print()
    print("Required independent whole-network netlists")
    for design_id in INDEPENDENT_NETLISTS:
        print("  ", display_name(design_id))
    print()
    print("Field-programmable gate-array validation: CANCELLED")
    print("  Available lookup-table capacity cannot fit the complete 64-node networks.")
    print("  A 4-by-4 prototype is not accepted as 64-node evidence.")
    print()
    policy_path = EXPERIMENTS / "configs" / "application_traces" / "snn_trace_replay_policy.json"
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    print("Optional spiking-neural-network trace replay:", policy["status"])
    print("  Runs only after Gate %s on %s." % (
        policy["run_only_after_gate"],
        " and ".join(display_name(item) for item in policy["applies_to_designs"]),
    ))
    print()
    lock_path = MODEL / "calibration" / "locked.json"
    lock = json.loads(lock_path.read_text(encoding="utf-8")) if lock_path.is_file() else {}
    print("Software event model paper-matrix allowed:", bool(lock.get("paper_matrix_allowed")))
    print("Paper-matrix networks:", len(PAPER_MATRIX_NETWORKS))
    print("Current design document:", EXPERIMENTS / "setup" / "NoC_Experiment_Design_V3.2.0.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
