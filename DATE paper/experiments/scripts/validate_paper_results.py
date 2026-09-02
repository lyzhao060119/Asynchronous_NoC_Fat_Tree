#!/usr/bin/env python3
"""Refuse paper numbers that violate V3.2.0 curated gates."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.hashutil import load_json  # noqa: E402
from date_v3.paths import CURATED, PNR_SCRIPTS  # noqa: E402
from date_v3.registry import curated_gate, iter_manifests  # noqa: E402
from check_v31_gates import paper_point_errors  # noqa: E402

ARCHIVE_MARKERS = (
    "Ackin DEL250",
    "BUFFD0",
    "CFifo",
    "RouterTop",
    "UltraRouter",
)


def main() -> int:
    errors = 0
    lock_path = PNR_SCRIPTS / "locked_tool.json"
    lock = load_json(lock_path) if lock_path.is_file() else {}
    if lock.get("physical_class") == "post-synthesis":
        print("PNR_LOCK post-synthesis-only", lock.get("pilot_run_id"))
    for manifest in iter_manifests():
        if manifest.get("paper_eligible") and (
            str(manifest.get("design_id") or "").startswith("FPGA_")
            or str(manifest.get("benchmark_id") or "").startswith("FPGA-")
        ):
            print("FAIL field-programmable gate-array result is removed in V3.2.0", manifest["run_id"])
            errors += 1
        if manifest.get("paper_eligible") and manifest.get("benchmark_id") == "SNN-TRACE1024":
            if not (manifest.get("trace_hash") and manifest.get("netlist_hash") and manifest.get("sdf_hash")):
                print("FAIL optional SNN trace lacks trace/netlist/delay-file hashes", manifest["run_id"])
                errors += 1
            if "Gate F" not in (manifest.get("notes") or ""):
                print("FAIL optional SNN trace lacks Gate F authorization", manifest["run_id"])
                errors += 1
            gate_f = subprocess.run(
                [sys.executable, str(SCRIPTS / "check_v31_gates.py"), "--gate", "F"],
                cwd=SCRIPTS.parents[2],
                check=False,
                capture_output=True,
                text=True,
            )
            if gate_f.returncode != 0:
                print("FAIL optional SNN trace submitted before required Gate F", manifest["run_id"])
                errors += 1
        if (
            manifest.get("paper_eligible")
            and manifest.get("physical_class") == "post-layout"
            and lock.get("physical_class") == "post-synthesis"
        ):
            print("FAIL post-layout claim while P&R lock is post-synthesis", manifest["run_id"])
            errors += 1
        notes = manifest.get("notes") or ""
        reason = manifest.get("archive_only_reason") or ""
        if manifest.get("paper_eligible") and (
            manifest.get("physical_class") == "archive-only"
            or any(marker in notes or marker in reason for marker in ARCHIVE_MARKERS)
        ):
            print("FAIL archive-tagged run marked paper_eligible", manifest["run_id"])
            errors += 1
        gate = curated_gate(
            manifest,
            has_traffic=bool(manifest.get("benchmark_id")) and manifest.get("benchmark_id") != "R-U5",
        )
        if manifest.get("paper_eligible") and gate:
            print("FAIL", manifest["run_id"], "; ".join(gate))
            errors += 1
        for err in paper_point_errors(manifest):
            print("FAIL", manifest["run_id"], err)
            errors += 1
    for banned in ("table_i_implementation.csv", "fig_a_bounded_fat.csv", "fig_b_scalability.csv", "fig_c_cross_tier_multicast.csv"):
        path = CURATED / banned
        if path.is_file() and path.stat().st_size > 0:
            print("WARN curated table present", path.name, "must trace to a pass manifest")
    print("VALIDATE_PAPER errors=%d" % errors)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
