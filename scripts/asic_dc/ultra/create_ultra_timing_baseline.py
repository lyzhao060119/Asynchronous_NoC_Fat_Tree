#!/usr/bin/env python3
"""Freeze the evidence needed to reproduce an Ultra timing-optimization run.

This script deliberately does *not* claim byte-identical DC output: that is
tool/seed dependent.  It records the inputs which make two mapped results
comparable, plus the previous regression summaries used as the rollback point.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "docs" / "timing_baselines"

INPUTS = (
    "generated_ultra/UltraRouter.v",
    "src/main/scala/Router_Architecture/ultra/UltraRouter.scala",
    "src/main/scala/Router_Architecture/ultra/AtomicMulticastArbiterV2.scala",
    "src/main/scala/tool/AsyncLib_ACG.scala",
    "src/main/resources/ASYNC/DelayElement_ASIC.v",
    "src/main/resources/ASYNC/DLatchBank.v",
    "src/main/resources/ASYNC/MullerC2.v",
    "src/main/resources/ASYNC/MullerC3.v",
    "src/main/resources/ASYNC/Mutex2_ASIC.v",
    "scripts/asic_dc/ultra/async_ultra_router.sdc",
    "scripts/asic_dc/ultra/run_dc_ultra_router.tcl",
    "scripts/asic_dc/ultra/run_sta_ultra_router.tcl",
    "scripts/asic_dc/ultra/run_gls_ultra_router.sh",
    "sim/AsyncRouterL1/testbench/tb_ultra_router_boundary_smoke.sv",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(command: list[str]) -> str:
    try:
        return subprocess.check_output(command, cwd=REPO, text=True, errors="replace").strip()
    except (OSError, subprocess.CalledProcessError):
        return "UNAVAILABLE"


def main() -> None:
    profile = os.environ.get("ASYNC_DELAY_PROFILE", "ULTRA_P250_PRS_ACG_OPM75")
    run_id = os.environ.get("ULTRA_TIMING_BASELINE_ID", "20260812_ack075_r5_core015")
    files = {}
    missing = []
    for relative in INPUTS:
        path = REPO / relative
        if path.is_file():
            files[relative] = sha256(path)
        else:
            missing.append(relative)
    manifest = {
        "schema": "ultra-timing-baseline-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_run_id": run_id,
        "delay_profile": profile,
        "library": os.environ.get("ULTRA_LIBRARY", "T28SS (remote tech_t28ss.tcl)"),
        "pvt": os.environ.get("ULTRA_PVT", "as configured by tech_t28ss.tcl"),
        "dc_seed": os.environ.get("ULTRA_DC_SEED", "N/A — deterministic synthesis flow"),
        "tool_version": os.environ.get("ULTRA_TOOL_VERSION", "collect remotely during DC"),
        "git_head": git(["git", "rev-parse", "HEAD"]),
        "git_status": git(["git", "status", "--short"]),
        "inputs_sha256": files,
        "missing_inputs": missing,
        "equivalence_policy": {
            "required": [
                "same source/constraint/profile/library/PVT/seed manifest",
                "same structured primitive counts",
                "QoR and paired-RTC values within recorded tolerance",
                "identical regression outcomes",
            ],
            "optional_if_tool_is_deterministic": "post-netlist and SDF SHA-256 equality",
        },
        "environment_note": "Structured sink Ack DEL075 is verification environment service delay; it is excluded from Router forward latency.",
    }
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / f"{run_id}_baseline_manifest.json"
    target.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(target)


if __name__ == "__main__":
    main()
