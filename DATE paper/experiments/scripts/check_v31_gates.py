#!/usr/bin/env python3
"""V3.1.0 staged gates. Failures stop the next size and keep evidence.

Never substitute the software event model for a missing whole-network
maximum-delay gate-level result.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.display_names import (  # noqa: E402
    FORBIDDEN_DISPLAY_TOKENS,
    display_name,
)
from date_v3.hashutil import load_json  # noqa: E402
from date_v3.network_matrix import (  # noqa: E402
    INDEPENDENT_NETLISTS,
    PAPER_MATRIX_NETWORKS,
    SHARED_NETLISTS,
    UNSUPPORTED,
    dump_matrix,
)
from date_v3.paths import (  # noqa: E402
    BENCHMARKS,
    CMR_SCRIPTS,
    DESIGNS,
    EXPERIMENTS,
    INTERMEDIATE,
    REPO,
    SCHEMA,
)
from date_v3.registry import get_run, iter_manifests  # noqa: E402

SYNC64_SIGNED = {
    "SYNC_THIN64": "20260901_cmr_sync_noc64_thin_p50",
    "SYNC_PROP64": "20260901_cmr_sync_noc64_fat1222_p50",
}
SCALE_DESIGNS = {
    64: ("THIN64", "PROP64", "PFAT64", "FM64", "SYNC_THIN64", "SYNC_PROP64"),
    256: ("PROP256", "FM256"),
    1024: ("PROP1024", "FM1024"),
}


def _ok(name: str) -> None:
    print("PASS", name, flush=True)


def _fail(message: str) -> None:
    raise AssertionError(message)


def check_naming() -> None:
    doc = EXPERIMENTS / "setup" / "NoC_Experiment_Design_V3.1.0.md"
    if not doc.is_file():
        _fail("missing V3.1.0 design document")
    header = (EXPERIMENTS / "setup" / "NoC_Experiment_Design_V3.0.2.md").read_text(encoding="utf-8")
    if "NoC_Experiment_Design_V3.1.0.md" not in header:
        _fail("V3.0.2 must point at V3.1.0")
    schema = load_json(SCHEMA / "design.schema.json")
    if "display_name" not in schema["properties"]:
        _fail("design schema missing display_name")
    for path in sorted(DESIGNS.glob("*.json")):
        design = load_json(path)
        name = design.get("display_name") or display_name(design["design_id"])
        if not name or name == design["design_id"]:
            _fail("%s missing English display_name" % path.name)
        for token in FORBIDDEN_DISPLAY_TOKENS:
            if token in name.split() or name == token:
                _fail("%s display_name contains forbidden token %s: %s" % (path.name, token, name))
    for path in sorted(BENCHMARKS.glob("*.json")):
        bench = load_json(path)
        name = bench.get("display_name") or display_name(bench["benchmark_id"])
        if not name or name == bench["benchmark_id"]:
            _fail("%s missing English display_name" % path.name)
    _ok("naming")


def check_matrix() -> None:
    matrix = dump_matrix()
    if matrix["no_synchronous_256_or_1024"] is not True:
        _fail("matrix must refuse synchronous 256/1024")
    if "PROP1024_MESH4" not in matrix["unsupported"]:
        _fail("four-lane top mesh must be unsupported")
    if SHARED_NETLISTS.get("HREP1024") != "PROP1024":
        _fail("boundary packet-replication must share the 1024-node hierarchical netlist")
    path = EXPERIMENTS / "configs" / "inventory" / "v31_network_matrix.json"
    if not path.is_file():
        _fail("missing frozen matrix JSON")
    frozen = load_json(path)
    if frozen.get("independent_netlists") != list(INDEPENDENT_NETLISTS):
        _fail("frozen independent netlist list drifted")
    _ok("network_matrix")


def check_driver_inputs() -> None:
    script = CMR_SCRIPTS / "run_remote_cmr_network_sdf.py"
    completed = subprocess.run(
        [sys.executable, str(script), "--design", "PROP256", "--check-inputs"],
        cwd=REPO,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        print(completed.stdout, completed.stderr, flush=True)
        _fail("network driver --check-inputs failed")
    gls = (CMR_SCRIPTS / "run_gls_cmr_network.sh").read_text(encoding="utf-8")
    if "MODE=sdf" not in gls:
        _fail("network GLS must be maximum-delay mode")
    if "notimingcheck is forbidden" not in gls:
        _fail("network GLS must refuse +notimingcheck")
    completed = subprocess.run(
        [sys.executable, str(script), "--design", "PROP1024_MESH4", "--check-inputs"],
        cwd=REPO,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode == 0:
        _fail("unsupported four-lane design must be refused")
    _ok("driver_inputs")


def check_gate_a(*, skip_scala: bool, skip_traffic: bool) -> None:
    check_naming()
    check_matrix()
    from inventory_network_duts import main as inv_main
    from check_phase3 import check_inventory, check_scala, check_topology

    if inv_main() != 0:
        _fail("inventory rewrite failed")
    check_scala()
    check_inventory()
    check_topology()
    check_driver_inputs()
    tb = REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc_async_keycase.sv"
    text = tb.read_text(encoding="utf-8")
    for needle in ("V3_METRICS_CSV", "head_inject_req_ps", "warmup_original_events"):
        if needle not in text:
            _fail("unified testbench missing %s" % needle)
    if not skip_traffic:
        from test_traffic_v3 import main as traffic_main

        if traffic_main() != 0:
            _fail("five-flit traffic tests failed")
    if not skip_scala:
        sbt = "sbt.bat" if os_is_windows() else "sbt"
        completed = subprocess.run(
            [sbt, "testOnly NoC.CMR.CMRNetworkDutSpec"],
            cwd=REPO,
            check=False,
        )
        if completed.returncode != 0:
            _fail("Scala network DUT spec failed")
    _ok("gate_A")


def os_is_windows() -> bool:
    return sys.platform.startswith("win")


def _signed_whole_network(design_id: str) -> dict[str, Any] | None:
    forced = SYNC64_SIGNED.get(design_id)
    if forced:
        manifest = get_run(forced)
        if manifest and manifest.get("status") == "pass" and manifest.get("physical_class") == "post-synthesis":
            return manifest
    matches = []
    for manifest in iter_manifests():
        if manifest.get("design_id") != design_id:
            continue
        if manifest.get("status") != "pass":
            continue
        if manifest.get("physical_class") != "post-synthesis":
            continue
        if manifest.get("archive_only_reason"):
            continue
        if not (manifest.get("netlist_hash") and manifest.get("sdf_hash")):
            continue
        matches.append(manifest)
    return matches[-1] if matches else None


def check_gate_b() -> dict[str, Any]:
    missing = []
    found = {}
    for design_id in SCALE_DESIGNS[64]:
        manifest = _signed_whole_network(design_id)
        if not manifest:
            missing.append(display_name(design_id))
        else:
            found[design_id] = manifest["run_id"]
    status = {"found": found, "missing": missing, "pass": not missing}
    if missing:
        print("GATE_B_FAIL missing 64-node whole-network delay evidence:")
        for name in missing:
            print("  ", name)
        print("Do not start 256-node synthesis. Do not substitute the software event model.")
        return status
    _ok("gate_B")
    return status


def check_scale_pair(nodes: int, *, label: str) -> dict[str, Any]:
    missing = []
    found = {}
    for design_id in SCALE_DESIGNS[nodes]:
        manifest = _signed_whole_network(design_id)
        if not manifest:
            missing.append(display_name(design_id))
        else:
            found[design_id] = manifest["run_id"]
    status = {"found": found, "missing": missing, "pass": not missing}
    if missing:
        print("%s_FAIL missing whole-network delay evidence:" % label)
        for name in missing:
            print("  ", name)
        print("Stop. Keep logs, netlist hashes, and delay-file hashes. Do not use the software event model as paper data.")
        return status
    _ok(label)
    return status


def paper_point_errors(manifest: dict[str, Any]) -> list[str]:
    errors = []
    design_id = manifest.get("design_id") or ""
    nodes = 0
    path = DESIGNS / ("%s.json" % design_id.lower())
    if path.is_file():
        design = load_json(path)
        nodes = int(design.get("nodes") or 0)
        if design.get("kind") != "network":
            return errors
    if not manifest.get("paper_eligible"):
        return errors
    if nodes < 256 and design_id not in PAPER_MATRIX_NETWORKS:
        return errors
    if nodes >= 256 or design_id in ("PROP256", "FM256", "PROP1024", "HREP1024", "FM1024"):
        if manifest.get("physical_class") != "post-synthesis":
            errors.append("256/1024 paper point is not post-synthesis")
        if not manifest.get("netlist_hash"):
            errors.append("missing whole-network netlist_hash")
        if not manifest.get("sdf_hash"):
            errors.append("missing whole-network delay-file hash")
        notes = (manifest.get("notes") or "") + " " + (manifest.get("adapter") or "")
        if "des" in notes.lower() and "network_sdf" not in notes.lower():
            errors.append("software event model cannot source a 256/1024 paper point")
        owner = SHARED_NETLISTS.get(design_id, design_id)
        if owner in UNSUPPORTED:
            errors.append("unsupported geometry cannot be paper-eligible")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="V3.1.0 staged gate checker")
    parser.add_argument("--gate", default="A", choices=["A", "B", "C", "D", "E", "F", "naming", "all"])
    parser.add_argument("--skip-scala", action="store_true")
    parser.add_argument("--skip-traffic", action="store_true")
    args = parser.parse_args()
    out_dir = INTERMEDIATE / "v31_gates"
    out_dir.mkdir(parents=True, exist_ok=True)
    result: dict[str, Any] = {
        "gate": args.gate,
        "pass": False,
        "do_not_substitute_software_event_model": True,
    }
    code = 1
    try:
        if args.gate in ("A", "naming", "all"):
            if args.gate == "naming":
                check_naming()
                check_matrix()
            else:
                check_gate_a(skip_scala=args.skip_scala, skip_traffic=args.skip_traffic)
        if args.gate in ("B", "all"):
            status = check_gate_b()
            result["gate_B"] = status
            if not status["pass"] and args.gate != "all":
                raise SystemExit(1)
        if args.gate in ("C", "D", "all"):
            b = check_gate_b()
            result["gate_B"] = b
            if not b["pass"]:
                raise SystemExit(1)
            c = check_scale_pair(256, label="gate_C")
            result["gate_C"] = c
            if args.gate in ("C", "D", "all") and not c["pass"]:
                raise SystemExit(1)
            if args.gate in ("D", "all"):
                _ok("gate_D_requires_formal_traffic_on_signed_256_netlists")
        if args.gate in ("E", "F", "all"):
            if not check_gate_b()["pass"] or not check_scale_pair(256, label="gate_C")["pass"]:
                print("GATE_E blocked until 256-node formal gate is green")
                raise SystemExit(1)
            e = check_scale_pair(1024, label="gate_E")
            result["gate_E"] = e
            if not e["pass"]:
                raise SystemExit(1)
            _ok("gate_F_requires_formal_traffic_on_signed_1024_netlists")
        print("V31_GATE", args.gate, "PASS", flush=True)
        result["pass"] = True
        code = 0
    except AssertionError as exc:
        print("FAIL", exc, flush=True)
        result["error"] = str(exc)
        code = 1
    except SystemExit as exc:
        code = int(exc.code) if exc.code is not None else 1
        result["pass"] = code == 0
    (out_dir / "status.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
