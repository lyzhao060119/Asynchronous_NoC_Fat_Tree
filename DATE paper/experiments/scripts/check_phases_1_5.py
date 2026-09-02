#!/usr/bin/env python3
"""Audit DATE V3 Phases 0–5: local gates, freeze, and known omissions."""
from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MODEL_DIR = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL_DIR):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.hashutil import load_json  # noqa: E402
from date_v3.paths import EXPERIMENTS, MODEL, PLANS, PNR_SCRIPTS, REPO, SCHEMA  # noqa: E402

ASYNC_PRIMITIVES = (
    "async_thin_1x1",
    "async_flatmesh_1x1",
    "async_fat_1x2",
    "async_prop_2x2",
    "async_topmesh_2x2",
    "async_pfat_2x4",
    "async_pfat_4x8",
)
SYNC_PRIMITIVES = ("sync_thin_1x1", "sync_prop_2x2")


def _ok(name: str) -> None:
    print("PASS", name, flush=True)


def check_phase0() -> None:
    orch = EXPERIMENTS / "scripts" / "run_experiment.py"
    if not orch.is_file():
        raise AssertionError("missing orchestrator")
    for name in (
        "design.schema.json",
        "canonical_trace.schema.json",
        "canonical_event.schema.json",
        "des_lock.schema.json",
    ):
        if not (SCHEMA / name).is_file():
            raise AssertionError("missing schema %s" % name)
    gitignore = (REPO / ".gitignore").read_text(encoding="utf-8")
    if "DATE paper/experiments/raw/" not in gitignore:
        raise AssertionError("raw/ not gitignored")
    _ok("phase0")


def check_phase1() -> None:
    lock = load_json(PNR_SCRIPTS / "locked_tool.json")
    if lock.get("freeze") != "post-synthesis-only":
        raise AssertionError("P&R freeze is %s" % lock.get("freeze"))
    if lock.get("physical_class") == "post-layout":
        raise AssertionError("Phase 1 lock claims post-layout")
    plan = load_json(PLANS / "pnr_pilot.json")
    for run in plan["runs"]:
        if run.get("paper_eligible"):
            raise AssertionError("pnr plan run is paper_eligible: %s" % run["run_id"])
        if run.get("physical_class") == "post-layout":
            raise AssertionError("pnr plan claims post-layout")
    adapters = (EXPERIMENTS / "scripts" / "date_v3" / "adapters.py").read_text(encoding="utf-8")
    if "DATE V3 does not run P&R" not in adapters:
        raise AssertionError("adapters must refuse P&R on the paper path")
    _ok("phase1_closed_post_synthesis")


def check_phase2() -> None:
    cal = load_json(MODEL / "calibration" / "20260901_primitive_ru5_post_synthesis.json")
    if cal.get("physical_class") != "post-synthesis":
        raise AssertionError("calibration class %s" % cal.get("physical_class"))
    kinds = {row["kind"] for row in cal.get("primitives") or []}
    missing = [k for k in ASYNC_PRIMITIVES + SYNC_PRIMITIVES if k not in kinds]
    if missing:
        raise AssertionError("calibration missing %s" % missing)
    sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))
    import cmr_frozen_run_ids as frozen

    if frozen.FROZEN_PRIMITIVE_HOP_PPA_RUN_ID != "20260901_cmr_primitive_hop_ppa_ru5":
        raise AssertionError("frozen hop PPA id drifted")
    _ok("phase2_async_primitives")


def check_phase25() -> None:
    cal = load_json(MODEL / "calibration" / "20260901_primitive_ru5_post_synthesis.json")
    by_kind = {row["kind"]: row for row in cal["primitives"]}
    for kind in SYNC_PRIMITIVES:
        for field in ("head_ns", "body_ns", "tail_ns"):
            if abs(float(by_kind[kind][field]) - 1.0) > 1e-9:
                raise AssertionError("%s %s=%s" % (kind, field, by_kind[kind][field]))
    sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))
    import cmr_frozen_run_ids as frozen

    if abs(float(frozen.FROZEN_SYNC64_CLOCK_NS) - 1.0) > 1e-12:
        raise AssertionError("Sync64 clock must stay 1.0 ns")
    if "0.90" in str(frozen.FROZEN_SYNC64_CLOCK_NS):
        raise AssertionError("0.90 ns clock is forbidden")
    _ok("phase25_sync_1cycle")


def _run(mod_name: str, label: str) -> None:
    mod = __import__(mod_name)
    rc = mod.main()
    if rc != 0:
        raise SystemExit("%s failed rc=%s" % (label, rc))
    _ok(label)


def main() -> int:
    check_phase0()
    check_phase1()
    check_phase2()
    check_phase25()
    _run("check_phase3", "phase3")
    _run("check_phase4", "phase4")
    _run("check_phase5", "phase5")
    lock_path = MODEL / "calibration" / "locked.json"
    lock = load_json(lock_path) if lock_path.is_file() else {}
    audit = {
        "phase0": "complete",
        "phase1": "closed_fail_post_synthesis_only",
        "phase2": "pass_async_post_synthesis",
        "phase2_5": "pass_sync_1cycle_1p0ns",
        "phase3": "infra_pass",
        "phase4": "infra_pass",
        "phase5_infra": "pass" if lock.get("hop_self_check") == "pass" else "unknown",
        "phase5_network_rtl": lock.get("network_rtl_64") or "pending",
        "paper_matrix_allowed": bool(lock.get("paper_matrix_allowed")),
        "omissions": [
            "V3.1.0: 256/1024 paper numbers require whole-network logic synthesis and maximum-delay gate-level simulation (Gates C-F).",
            "No V3 5-flit 64/256/1024 asynchronous whole-network maximum-delay traces yet; software event model paper-matrix remains false.",
            "DES-side pack seed 900001 exists; do not treat it as 256/1024 paper data.",
            "Formal 11k-event delay-format scoreboards are Phase 6 Gates C-F.",
            "64 RTL directed exhaustive is FPGA/Phase 11, not Phase 3 infra.",
            "Four-lane top-mesh variation is not elaborated. Do not fabricate synthesis or delay-format results.",
            "Table I can use isolated-router evidence; network figures wait for Gate D/F.",
        ],
    }
    print(json.dumps(audit, indent=2), flush=True)
    print("PHASES_1_5_AUDIT_DONE", flush=True)
    if lock.get("paper_matrix_allowed"):
        print("PHASES_1_5_COMPLETE", flush=True)
    else:
        print("PHASES_1_5_INFRA_COMPLETE_RTL_CAL_PENDING", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
