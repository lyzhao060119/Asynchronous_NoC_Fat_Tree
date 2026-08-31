#!/usr/bin/env python3
"""Emit L2/L3 Fat-64 router geometries, check ADAPTER/Mutex widths, emit NoC64."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def run(cmd: list[str], env: dict[str, str] | None = None) -> None:
    print("+", " ".join(cmd))
    merged = os.environ.copy()
    if env:
        merged.update(env)
    subprocess.check_call(cmd, cwd=REPO, env=merged)


def main() -> None:
    skip_noc64 = "--routers-only" in sys.argv
    run(["sbt", "runMain Router_Architecture.CMR.CMRFat64GeometryEmitMain"])
    run(
        [
            sys.executable,
            str(REPO / "scripts" / "asic_dc" / "cmr" / "check_cmr_router_geometry.py"),
        ]
    )
    if skip_noc64:
        return
    for profile in ("1248", "1222"):
        run(
            ["sbt", "runMain NoC.CMR.CMRFatTreeNoC64Main"],
            env={"CMR_FAT_LANE_PROFILE": profile},
        )
    run(
        [
            sys.executable,
            str(REPO / "scripts" / "asic_dc" / "cmr" / "check_cmr_router_geometry.py"),
            "--noc64",
        ]
    )
    run(
        [
            sys.executable,
            str(REPO / "sim" / "AsyncNoC" / "testbench" / "gen_noc64_port_adapter.py"),
        ]
    )


if __name__ == "__main__":
    main()
