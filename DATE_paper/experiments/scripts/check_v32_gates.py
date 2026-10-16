#!/usr/bin/env python3
"""V3.2 consistency checks: no FPGA path and optional SNN replay only post-Gate-F."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.hashutil import load_json  # noqa: E402
from date_v3.paths import BENCHMARKS, DESIGNS, EXPERIMENTS, REPO  # noqa: E402
from date_v3.registry import iter_manifests  # noqa: E402


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def check_current_docs() -> None:
    current = EXPERIMENTS / "setup" / "NoC_Experiment_Design_V3.2.0.md"
    previous = EXPERIMENTS / "setup" / "NoC_Experiment_Design_V3.1.0.md"
    _require(current.is_file(), "missing V3.2.0 design document")
    _require(
        "NoC_Experiment_Design_V3.2.0.md" in previous.read_text(encoding="utf-8"),
        "V3.1.0 must point to V3.2.0",
    )
    text = current.read_text(encoding="utf-8")
    for needle in (
        "cannot fit either complete",
        "4-by-4 prototype",
        "optional",
        "one spike event as one multicast injection",
    ):
        _require(needle in text, "V3.2 document missing %r" % needle)
    print("PASS v32_docs")


def check_no_fpga_current_matrix() -> None:
    forbidden_designs = []
    for path in DESIGNS.glob("*.json"):
        design = load_json(path)
        if design.get("kind") == "fpga" or design.get("design_id", "").startswith("FPGA_"):
            forbidden_designs.append(path.name)
    forbidden_benchmarks = []
    for path in BENCHMARKS.glob("*.json"):
        benchmark = load_json(path)
        if str(benchmark.get("traffic", "")).startswith("fpga_"):
            forbidden_benchmarks.append(path.name)
    _require(not forbidden_designs, "active FPGA design configs remain: %s" % forbidden_designs)
    _require(not forbidden_benchmarks, "active FPGA benchmarks remain: %s" % forbidden_benchmarks)
    for manifest in iter_manifests():
        if manifest.get("paper_eligible") and (
            str(manifest.get("design_id", "")).startswith("FPGA_")
            or str(manifest.get("benchmark_id", "")).startswith("FPGA-")
        ):
            raise AssertionError("FPGA manifest is paper eligible: %s" % manifest["run_id"])
    print("PASS no_fpga_current_matrix")


def check_snn_contract() -> None:
    policy_path = EXPERIMENTS / "configs" / "application_traces" / "snn_trace_replay_policy.json"
    schema_path = EXPERIMENTS / "configs" / "schema" / "snn_trace.schema.json"
    policy = load_json(policy_path)
    schema = load_json(schema_path)
    _require(policy["optional"] is True, "SNN trace must remain optional")
    _require(policy["run_only_after_gate"] == "F", "SNN trace must wait for Gate F")
    _require(policy["applies_to_designs"] == ["PROP1024", "HREP1024"], "SNN pair drifted")
    _require(policy["flat_mesh_included"] is False, "flat mesh must not gain unmatched multicast semantics")
    _require(policy["status"] == "unselected", "no trace should be claimed selected yet")
    _require(schema["properties"]["preserves_original_multicast"]["const"] is True, "trace must retain multicast")
    benchmark = load_json(BENCHMARKS / "snn_trace1024.json")
    _require(benchmark["paper_figures"] == ["optional_inset"], "SNN result cannot occupy a required figure")
    print("PASS snn_optional_contract")


def check_snn_manifest_exclusion() -> None:
    """Reject optional trace data until the selection and Gate F are explicit."""
    policy_path = EXPERIMENTS / "configs" / "application_traces" / "snn_trace_replay_policy.json"
    policy = load_json(policy_path)
    for manifest in iter_manifests():
        if manifest.get("benchmark_id") != "SNN-TRACE1024":
            continue
        if not manifest.get("paper_eligible"):
            continue
        _require(policy["status"] == "frozen", "paper-eligible SNN trace without frozen policy")
        _require(bool(manifest.get("trace_hash")), "paper-eligible SNN trace missing trace_hash")
        _require(bool(manifest.get("netlist_hash")), "paper-eligible SNN trace missing netlist_hash")
        _require(bool(manifest.get("sdf_hash")), "paper-eligible SNN trace missing sdf_hash")
        _require(
            "Gate F" in (manifest.get("notes") or ""),
            "paper-eligible SNN trace does not record Gate F authorization",
        )
    print("PASS snn_manifest_exclusion")


def main() -> int:
    parser = argparse.ArgumentParser(description="V3.2 plan consistency checker")
    parser.add_argument("--include-v31-gate-a", action="store_true")
    args = parser.parse_args()
    try:
        check_current_docs()
        check_no_fpga_current_matrix()
        check_snn_contract()
        check_snn_manifest_exclusion()
        if args.include_v31_gate_a:
            completed = subprocess.run(
                [sys.executable, str(SCRIPTS / "check_v31_gates.py"), "--gate", "A"],
                cwd=REPO,
                check=False,
            )
            _require(completed.returncode == 0, "underlying Gate A failed")
    except AssertionError as exc:
        print("FAIL", exc, flush=True)
        return 1
    print("V32_GATE PASS", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
